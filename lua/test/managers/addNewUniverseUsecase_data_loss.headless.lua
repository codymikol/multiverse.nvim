-- Regression test for the addNewUniverseUsecase data-loss bug introduced by
-- the #313 fix.
--
-- Like lua/test/managers/openUniverseUsecase_data_loss.headless.lua, this
-- test does NOT monkeypatch multiverse_manager.load_universe -- it exercises
-- the real save/cleanup/hydrate pipeline, but this time via the REAL
-- `addNewUniverseUsecase.run(name, directory)` entrypoint (what
-- `:MultiverseAdd` calls), reproducing the reported scenario: running
-- `:MultiverseAdd` for the CURRENT directory while a real buffer is open in
-- it.
--
-- Scenario reproduced: cwd has open work (a real, named buffer) and is not
-- yet part of any universe. Before the #313 fix landed, addNewUniverseUsecase
-- registered a brand new EMPTY universe for that directory, then
-- multiverse_manager.load_universe noticed getcwd() now matched the
-- newly-added universe (they're the same one) and unconditionally called
-- M.save(), which captured the still-open buffer into that universe's file
-- before cleanup/hydrate ran -- so the round trip was a no-op from the
-- user's perspective. After the #313 fix's same-uuid skip landed (and before
-- this file's fix), that M.save() call was skipped, so the just-created
-- empty universe file was never overwritten with the open buffer's state:
-- cleanup_manager.cleanup() then wiped the buffer, and hydration_manager.
-- hydrate read back the still-empty universe file, permanently losing the
-- user's open work. This test asserts the persisted universe file for the
-- newly-added universe reflects the buffer that was open when
-- `:MultiverseAdd` ran, and that the buffer is still open (hydrated back)
-- afterward.
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
--   nvim --headless -u NONE -l lua/test/managers/addNewUniverseUsecase_data_loss.headless.lua
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

local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local state_store = require("multiverse.store.state_store")
local neotree_integration = require("integrations.neotree")
local neotree_plugin = require("plugins.neotree_plugin")
-- Require this now (before `cd`-ing below), since package.path is set up
-- with relative paths resolved against the process cwd at require-time.
local addNewUniverseUsecase = require("multiverse.usecases.addNewUniverseUsecase")

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

-- A real directory on disk, standing in for the directory the user runs
-- `:MultiverseAdd` from -- not yet registered as a universe.
local test_dir = vim.fn.tempname()
vim.fn.mkdir(test_dir, "p")

local universe_name = "test-universe-addnew"
local marker = "IMPORTANT_NON_TRIVIAL_SESSION_MARKER_wip.lua"
local marker_path = test_dir .. "/" .. marker

-- Simulate the reported scenario: cwd is the (not-yet-registered) directory
-- the user is about to `:MultiverseAdd`, with real open work in it.
vim.api.nvim_command("cd " .. vim.fn.fnameescape(test_dir))

-- A real, named, listed buffer standing in for the user's currently-open
-- work before running `:MultiverseAdd` -- very clearly NOT the
-- empty/near-empty state a freshly-created universe's file would start with.
vim.api.nvim_command("edit " .. vim.fn.fnameescape(marker_path))

state_store.set_current_state(state_store.STATES.IDLE)

-- Call the REAL addNewUniverseUsecase.run -> multiverse_manager.load_universe
-- pipeline; aside from the stubs above, nothing here is monkeypatched.
addNewUniverseUsecase.run(universe_name, test_dir)

state_store.set_current_state(state_store.STATES.IDLE)

-- Find the uuid of the universe that was just registered for test_dir, so we
-- can inspect its persisted file.
local multiverse = multiverse_repository.getMultiverse()
local new_universe_summary = multiverse:getUniverseByDirectory(test_dir)
assert(new_universe_summary ~= nil,
  "setup sanity check failed: no universe was registered for " .. test_dir .. " after addNewUniverseUsecase.run()")

local function read_universe_file(uuid)
  local path = persistance_dir .. "/universe-" .. uuid .. ".json"
  local file = io.open(path, "r")
  assert(file ~= nil, "expected universe file to exist at " .. path)
  local contents = file:read("*a")
  file:close()
  return contents
end

local contents_after = read_universe_file(new_universe_summary.uuid)

assert(contents_after:find(marker, 1, true) ~= nil,
  "REGRESSION: the newly-added universe's persisted file does not contain the buffer that was open when "
    .. "`:MultiverseAdd` ran -- addNewUniverseUsecase.run() must capture the user's currently-open buffers into "
    .. "the new universe before load_universe cleans up/hydrates it.")

-- Beyond "the file wasn't left empty", confirm hydration actually ran
-- against the captured data: a change that made load_universe bail out
-- entirely before reaching hydration would also leave the buffer's own
-- (still-open, never-cleaned-up) state around and could pass the assertion
-- above without actually exercising the full save -> cleanup -> hydrate
-- round trip.
local hydrated_marker_buffer_found = false
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_get_name(buf):find(marker, 1, true) ~= nil then
    hydrated_marker_buffer_found = true
    break
  end
end

assert(hydrated_marker_buffer_found,
  "addNewUniverseUsecase.run() did not hydrate the marker buffer back after cleanup -- the user's open work was "
    .. "lost.")

-- restore originals for hygiene, even though this is a one-shot process
persistance.getDir = original_getDir
neotree_integration.hydrate = original_neotree_hydrate
neotree_plugin.context.beforeDehydrate = original_neotree_beforeDehydrate
neotree_plugin.context.afterHydrate = original_neotree_afterHydrate

print("PASS")
os.exit(0)
