-- Regression test for GitHub issue #104 (VimEnter auto-hydrate destroying a
-- universe's persisted session).
--
-- Unlike lua/test/managers/on_vim_enter.headless.lua, this test does NOT
-- monkeypatch multiverse_manager.load_universe -- it exercises the real
-- save/cleanup/hydrate pipeline that `:autocmd VimEnter` triggers, which is
-- exactly the interaction that let the bug ship untested.
--
-- Scenario reproduced: `cd ~/project && nvim .` where `~/project` is already
-- a registered universe with a real saved session. Before the fix,
-- `on_vim_enter` -> `multiverse_manager.load_universe` would notice
-- `getcwd()` matches the universe being loaded and call `M.save()`, which
-- dehydrates the empty/near-empty startup buffer state and clobbers the
-- universe's already-persisted session on disk before hydration even reads
-- it back. This test asserts the persisted universe file is untouched by a
-- fresh-startup `on_vim_enter()` call.
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
--   nvim --headless -u NONE -l lua/test/managers/on_vim_enter_data_loss.headless.lua
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
local on_vim_enter = require("multiverse.autocmd.on_vim_enter")

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

-- A real directory on disk, standing in for `~/project` -- a registered
-- universe's working directory.
local test_dir = vim.fn.tempname()
vim.fn.mkdir(test_dir, "p")

local universe_uuid = "test-universe-uuid-104"
local marker = "IMPORTANT_NON_TRIVIAL_SESSION_MARKER_important_file.lua"

-- Register the universe in the multiverse.
local universe_summary = UniverseSummary:new(test_dir, universe_uuid, "test-universe", 0)

local multiverse = multiverse_repository.getMultiverse()
table.insert(multiverse.universes, universe_summary)
multiverse_repository.save_multiverse(multiverse)

-- Persist a real, non-trivial session for that universe: a buffer that is
-- very clearly NOT the empty/near-empty state a fresh `nvim .` startup
-- buffer would produce.
local universe = Universe:new(universe_uuid, "test-universe", test_dir)
universe:addBuffer(Buffer:new("test-buffer-uuid-104", nil, marker))
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
    .. "on_vim_enter() was even called")

-- Simulate a fresh nvim startup: `cd ~/project && nvim .` -- shell cwd and
-- the startup buffer's directory both match the registered universe.
vim.api.nvim_command("cd " .. vim.fn.fnameescape(test_dir))
vim.api.nvim_buf_set_name(0, test_dir)

state_store.set_current_state(state_store.STATES.IDLE)

-- Call the REAL on_vim_enter -> multiverse_manager.load_universe pipeline;
-- nothing here is monkeypatched.
on_vim_enter.on_vim_enter()

state_store.set_current_state(state_store.STATES.IDLE)

local contents_after = read_universe_file()

assert(contents_after:find(marker, 1, true) ~= nil,
  "REGRESSION (GH #104): the persisted universe file was clobbered by a fresh-startup on_vim_enter() call -- "
    .. "the non-trivial session marker is gone. on_vim_enter() must not save/dehydrate the startup buffer state "
    .. "over an existing universe's session.")

-- restore originals for hygiene, even though this is a one-shot process
persistance.getDir = original_getDir
neotree_integration.hydrate = original_neotree_hydrate
neotree_plugin.context.beforeDehydrate = original_neotree_beforeDehydrate
neotree_plugin.context.afterHydrate = original_neotree_afterHydrate

print("PASS")
os.exit(0)
