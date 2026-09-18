-- Regression test for GitHub issue #313 (re-opening/reselecting the SAME
-- universe you're already sitting in clobbers its just-persisted session).
--
-- Like lua/test/managers/on_vim_enter_data_loss.headless.lua, this test does
-- NOT monkeypatch multiverse_manager.load_universe -- it exercises the real
-- save/cleanup/hydrate pipeline, but this time via the REAL
-- `openUniverseUsecase.run(name)` entrypoint (what `:MultiverseOpen <name>`
-- and the telescope picker call), reproducing the reported scenario:
-- reopening/reselecting the SAME universe already open at the current
-- working directory.
--
-- Scenario reproduced: cwd is already a registered universe's directory with
-- a real saved session. Before the fix, `openUniverseUsecase.run(name)` ->
-- `multiverse_manager.load_universe` would notice `getcwd()` matches a
-- registered universe and unconditionally call `M.save()` -- even though the
-- universe about to be saved-over (`current_universe_summary`) is the exact
-- same universe about to be (re)loaded (`selected_universe_summary`). That
-- save dehydrates the near-empty pre-hydration state and clobbers the
-- universe's already-persisted session on disk before hydration even reads
-- it back. This test asserts the persisted universe file is untouched by a
-- same-universe `openUniverseUsecase.run(name)` call.
--
-- This is NOT a busted-style spec, and is deliberately NOT named
-- `*.spec.lua` so a busted runner globbing this tree never collects it: it
-- exercises real `vim.api` calls (buffers, windows, cwd) and real
-- filesystem persistence that busted/luarocks cannot provide, calls
-- `os.exit()`, and must be run inside an actual nvim instance rather than
-- via the busted test runner used by the other files under
-- lua/test/**/*.spec.lua.
--
-- Run from the repository root with:
--   nvim --headless -u NONE -l lua/test/managers/openUniverseUsecase_data_loss.headless.lua
--
-- The script prints "PASS" and exits 0 on success, or raises a Lua error
-- (via `assert`) and exits non-zero on failure.

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local persistance = require("multiverse.repositories.persistance")

-- Redirect all persisted state to a throwaway temp directory rather than the
-- real `stdpath("data")/workspace-persistance` location.
local persistance_dir = vim.fn.tempname()
vim.fn.mkdir(persistance_dir, "p")

local original_getDir = persistance.getDir
persistance.getDir = function()
  return persistance_dir
end

local Universe = require("multiverse.data.Universe")
local UniverseSummary = require("multiverse.data.UniverseSummary")
local Buffer = require("multiverse.data.Buffer")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local universe_repository = require("multiverse.repositories.universe_repository")
local state_store = require("multiverse.store.state_store")
local neotree_integration = require("integrations.neotree")
local neotree_plugin = require("plugins.neotree_plugin")
-- Require this now (before `cd`-ing below), since package.path is set up
-- with relative paths resolved against the process cwd at require-time.
local openUniverseUsecase = require("multiverse.usecases.openUniverseUsecase")

-- Stub out the Neotree integration/plugin hooks so save/dehydrate/hydrate
-- don't attempt to run `:Neotree ...` ex commands, which don't exist in this
-- `-u NONE` headless session (and would otherwise short-circuit `M.save()`
-- via its own pcall before it ever reaches the destructive
-- `universe_repository.save_universe` write we're trying to catch). Real
-- load_universe/save wrap these in a pcall regardless, but stubbing them
-- keeps the test deterministic and focused on the save/hydrate data-loss
-- interaction rather than incidental plugin-command errors.
local original_neotree_hydrate = neotree_integration.hydrate
neotree_integration.hydrate = function() end

local original_neotree_beforeDehydrate = neotree_plugin.context.beforeDehydrate
local original_neotree_afterHydrate = neotree_plugin.context.afterHydrate
neotree_plugin.context.beforeDehydrate = function() end
neotree_plugin.context.afterHydrate = function() end

-- A real directory on disk, standing in for the universe's working
-- directory that is already registered AND already the current cwd.
local test_dir = vim.fn.tempname()
vim.fn.mkdir(test_dir, "p")

local universe_uuid = "test-universe-uuid-313"
local universe_name = "test-universe-313"
local marker = "IMPORTANT_NON_TRIVIAL_SESSION_MARKER_important_file.lua"

-- Register the universe in the multiverse.
local universe_summary =
	UniverseSummary:new({ directory = test_dir, uuid = universe_uuid, name = universe_name, lastExplored = 0 })

local multiverse = multiverse_repository.getMultiverse()
table.insert(multiverse.universes, universe_summary)
multiverse_repository.save_multiverse(multiverse)

-- Persist a real, non-trivial session for that universe: a buffer that is
-- very clearly NOT the empty/near-empty state a fresh reopen would produce.
local universe = Universe:new(universe_uuid, universe_name, test_dir)
universe:addBuffer(Buffer:new("test-buffer-uuid-313", nil, marker))
universe_repository.save_universe(universe)

-- Sanity check (this is the "confirm setup worked" step, not the
-- regression assertion): the persisted universe file on disk should
-- contain our marker.
local function read_universe_file()
  local path = persistance_dir .. "/universe-" .. universe_uuid .. ".json"
  local file = io.open(path, "r")
  assert(file ~= nil, "expected universe file to exist at " .. path)
  local contents = file:read("*a")
  file:close()
  return contents
end

local contents_before = read_universe_file()
assert(contents_before:find(marker, 1, true) ~= nil,
  "setup sanity check failed: persisted universe file does not contain the non-trivial session marker before "
    .. "openUniverseUsecase.run() was even called")

-- Simulate the reported scenario: cwd is already the universe's directory
-- (e.g. the user is already inside the universe they're about to reopen),
-- and they reopen/reselect the SAME universe via `:MultiverseOpen
-- test-universe-313` or the telescope picker.
vim.api.nvim_command("cd " .. vim.fn.fnameescape(test_dir))
vim.api.nvim_buf_set_name(0, test_dir)

state_store.set_current_state(state_store.STATES.IDLE)

-- Call the REAL openUniverseUsecase.run -> multiverse_manager.load_universe
-- pipeline; nothing here is monkeypatched.
openUniverseUsecase.run(universe_name)

state_store.set_current_state(state_store.STATES.IDLE)

local contents_after = read_universe_file()

assert(contents_after:find(marker, 1, true) ~= nil,
  "REGRESSION (GH #313): the persisted universe file was clobbered by reopening/reselecting the SAME universe "
    .. "already at the current working directory -- the non-trivial session marker is gone. "
    .. "openUniverseUsecase.run() must not save/dehydrate over a universe's own session when the universe being "
    .. "loaded is the same one currently registered at cwd.")

-- restore originals for hygiene, even though this is a one-shot process
persistance.getDir = original_getDir
neotree_integration.hydrate = original_neotree_hydrate
neotree_plugin.context.beforeDehydrate = original_neotree_beforeDehydrate
neotree_plugin.context.afterHydrate = original_neotree_afterHydrate

print("PASS")
os.exit(0)
