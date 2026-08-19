-- Coverage test for GitHub issue #138 (hydration_manager.lua had no test
-- coverage at all).
--
-- This file IS collected and run by CI's PlenaryBustedDirectory as a normal
-- `*_spec.lua` file (each spec file is spawned as its own `nvim --headless`
-- subprocess by plenary, so it can safely exercise real `vim.api` calls,
-- monkeypatch modules, and call `os.exit()` without affecting other specs).
-- It isn't written against the busted DSL (describe/it) though, so for
-- standalone/manual runs outside of plenary it still needs the direct
-- `-u NONE -l <path>` invocation documented below.
--
-- Run from the repository root with:
--   nvim --headless -u NONE -l lua/test/managers/hydration_manager.headless_spec.lua
--
-- The script prints "PASS" and exits 0 on success, or raises a Lua error
-- (via `assert`) and exits non-zero on failure.
--
-- Note: `universe_repository.getUniverseByUuid` is monkeypatched to hand
-- back an in-memory fake `Universe` so this test never touches disk, and
-- `integrations.neotree`'s `hydrate` is monkeypatched to a no-op recording
-- stub, since neo-tree is not installed in this headless environment (a
-- crash there is a separately tracked concern, see issue #241, and is not
-- what this test is exercising).

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local Universe = require("multiverse.data.Universe")
local Tabpage = require("multiverse.data.Tabpage")
local Window = require("multiverse.data.Window")
local Buffer = require("multiverse.data.Buffer")
local WindowLayout = require("multiverse.data.layout.WindowLayout")
local Row = require("multiverse.data.layout.Row")
local Leaf = require("multiverse.data.layout.Leaf")

local hydration_manager = require("multiverse.managers.hydration_manager")
local universe_repository = require("multiverse.repositories.universe_repository")
local neotree_integration = require("integrations.neotree")

-- Use a freshly-created, unique temp directory per run (rather than a
-- hardcoded /tmp path), and explicitly disable swapfiles for this process,
-- so a leftover swapfile from a previous run can never collide with this
-- one. This matters because each spec file is spawned as its own
-- `nvim --headless` subprocess under CI's PlenaryBustedDirectory, which does
-- not inherit ci/minimal_config.lua's `vim.o.swapfile = false`.
vim.o.swapfile = false

-- Build a fake, in-memory Universe: one working directory (no spaces, so
-- the ":cd" call in hydration_manager's setCwd doesn't need escaping --
-- exercising the escaping case itself is deferred to issue #240), one
-- Buffer, and two Tabpages (each with a single Window pointing at that
-- Buffer), giving hydration_manager.hydrate an observable pipeline (cwd,
-- buffers, tabpages, windows) to assert on.
local workingDirectory = vim.fn.tempname()
vim.fn.mkdir(workingDirectory, "p")

local bufferUuid = "test-hydration-manager-buffer-uuid"
local bufferName = workingDirectory .. "/multiverse_test_hydration_manager_buf.txt"

local universe = Universe:new(
  "test-hydration-manager-universe-uuid",
  "test-hydration-manager-universe",
  workingDirectory
)

local buffer = Buffer:new(bufferUuid, nil, bufferName)
universe:addBuffer(buffer)

local function makeTabpage(tabpageUuid, windowUuid)
  local window = Window:new(windowUuid, bufferUuid, nil)

  local tabpage = Tabpage:new(tabpageUuid, nil, windowUuid)
  tabpage:addWindow(window)

  local layout = WindowLayout:new()
  local row = Row:new()
  row:addChild(Leaf:new(windowUuid, nil))
  layout:addChild(row)
  tabpage:setLayout(layout)

  return tabpage
end

universe:addTabpage(makeTabpage("test-hydration-manager-tabpage-1-uuid", "test-hydration-manager-window-1-uuid"))
universe:addTabpage(makeTabpage("test-hydration-manager-tabpage-2-uuid", "test-hydration-manager-window-2-uuid"))

local summary = {
  uuid = universe.uuid,
  name = universe.name,
  directory = universe.workingDirectory,
}

-- Monkeypatch universe_repository.getUniverseByUuid so hydration reads our
-- in-memory fake Universe instead of hitting disk. Success shape is
-- (nil, universe), per the function's own doc comment.
local original_getUniverseByUuid = universe_repository.getUniverseByUuid
universe_repository.getUniverseByUuid = function(_)
  return nil, universe
end

-- Monkeypatch neotree_integration.hydrate to a no-op recording stub; see
-- header comment above.
local neotree_hydrate_called = false
local original_neotree_hydrate = neotree_integration.hydrate
neotree_integration.hydrate = function()
  neotree_hydrate_called = true
end

local initial_tabpage_count = #vim.api.nvim_list_tabpages()

local ok, err = pcall(hydration_manager.hydrate, summary)

-- restore originals for hygiene, even though this is a one-shot process
universe_repository.getUniverseByUuid = original_getUniverseByUuid
neotree_integration.hydrate = original_neotree_hydrate

assert(ok == true, "expected hydrate to not crash, but got error: " .. tostring(err))

assert(
  vim.fn.resolve(vim.fn.getcwd()) == vim.fn.resolve(workingDirectory),
  "expected cwd to be set to the universe's workingDirectory " .. vim.inspect(workingDirectory)
    .. " but got " .. vim.inspect(vim.fn.getcwd())
)

-- Resolve the hydrated buffer by an exact name match (vim.fn.bufnr() does
-- partial/regex-ish matching against buffer names, which could ambiguously
-- match an unintended buffer), reusing the same loop to also confirm the
-- buffer is tracked in nvim_list_bufs().
local hydrated_bufnr = nil
for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_get_name(bufnr) == bufferName then
    hydrated_bufnr = bufnr
    break
  end
end
assert(
  hydrated_bufnr ~= nil,
  "expected buffer " .. vim.inspect(bufferName) .. " to have been opened during hydration"
)
assert(vim.api.nvim_buf_is_valid(hydrated_bufnr), "expected the hydrated buffer to be a valid buffer")

local final_tabpage_count = #vim.api.nvim_list_tabpages()
assert(
  final_tabpage_count == initial_tabpage_count + 1,
  "expected hydration to create a new tabpage for the universe's second tabpage, initial count: "
    .. vim.inspect(initial_tabpage_count) .. ", final count: " .. vim.inspect(final_tabpage_count)
)

-- Assert on the window layer too, so hydration's overall effect on window
-- state is observed directly rather than only inferred incidentally through
-- tabpage count: the current tabpage should have exactly one window, and
-- that window should be showing the hydrated buffer.
local current_tab_wins = vim.api.nvim_tabpage_list_wins(0)
assert(
  #current_tab_wins == 1,
  "expected the current tabpage to have exactly 1 window, but got " .. vim.inspect(#current_tab_wins)
)

local current_win_bufnr = vim.api.nvim_win_get_buf(vim.api.nvim_get_current_win())
assert(
  current_win_bufnr == hydrated_bufnr,
  "expected the current window's buffer to be the hydrated buffer " .. vim.inspect(hydrated_bufnr)
    .. " but got " .. vim.inspect(current_win_bufnr)
)

-- Also check tab 1's window/buffer state directly: hydration lands you on
-- the last tabpage, so without this the assertions above would only ever
-- observe tab 2, and a regression confined to the first tabpage would pass
-- silently.
local all_tabpages = vim.api.nvim_list_tabpages()
vim.api.nvim_set_current_tabpage(all_tabpages[1])

local tab1_wins = vim.api.nvim_tabpage_list_wins(0)
assert(
  #tab1_wins == 1,
  "expected tab 1 to have exactly 1 window, but got " .. vim.inspect(#tab1_wins)
)

local tab1_win_bufnr = vim.api.nvim_win_get_buf(vim.api.nvim_get_current_win())
assert(
  tab1_win_bufnr == hydrated_bufnr,
  "expected tab 1's current window's buffer to be the hydrated buffer " .. vim.inspect(hydrated_bufnr)
    .. " but got " .. vim.inspect(tab1_win_bufnr)
)

vim.api.nvim_set_current_tabpage(all_tabpages[#all_tabpages])

assert(neotree_hydrate_called == true, "expected neotree_integration.hydrate stub to have been invoked during hydration")

vim.fn.delete(workingDirectory, "rf")

print("PASS")
os.exit(0)
