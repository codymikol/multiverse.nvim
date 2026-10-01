-- Regression test for GitHub issue #332 (hydration restores focus to
-- whichever tabpage happens to be last in iteration order, rather than the
-- tabpage that was actually focused at dehydrate time).
--
-- This is NOT a busted-style spec, and is deliberately NOT named
-- `*_spec.lua` so Plenary's busted runner (which globs `*_spec.lua`) never
-- collects it: it exercises real `vim.api` tabpage/window calls that
-- busted/luarocks cannot provide, calls `os.exit()`, and must be run inside
-- an actual nvim instance rather than via the busted test runner used by
-- the other files under lua/test/**/*_spec.lua.
--
-- Run from the repository root with:
--   nvim --headless -u NONE -l lua/test/managers/window_layout_manager.hydrate_tabpage_focus.headless.lua
--
-- The script prints "PASS" and exits 0 on success, or raises a Lua error
-- (via `assert`) and exits non-zero on failure.

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path
local dehydration_manager = require("multiverse.managers.dehydration_manager")
local tabpage_manager = require("multiverse.managers.tabpage_manager")
local window_layout_manager = require("multiverse.managers.window_layout_manager")
local helpers = require("test.managers.window_layout_headless_helpers")
local make_buf = helpers.make_buf

-- Build three tabs: tab 1, tab 2, tab 3 (in creation order), each with a
-- distinct buffer so dehydrate/hydrate have something real to carry across.
vim.api.nvim_win_set_buf(0, make_buf("/tmp/332-a.txt"))
vim.cmd("tabnew")
vim.api.nvim_win_set_buf(0, make_buf("/tmp/332-b.txt"))
vim.cmd("tabnew")
vim.api.nvim_win_set_buf(0, make_buf("/tmp/332-c.txt"))

-- Focus the middle tab (not last in iteration order) before dehydrating, so
-- a correct fix must specifically restore focus here rather than wherever
-- the per-tabpage hydrate loop happens to land.
vim.cmd("tabnext 2")
local focused_tabpageId_at_dehydrate = vim.api.nvim_get_current_tabpage()

local universe = dehydration_manager.dehydrate({ uuid = "u", name = "u", directory = "/tmp" })

assert(
  universe.currentTabpage ~= nil and universe.currentTabpage ~= "",
  "expected dehydrate to record a non-empty currentTabpage uuid"
)

local focused_tabpage
for _, tabpage in ipairs(universe.tabpages) do
  if tabpage.tabpageId == focused_tabpageId_at_dehydrate then
    focused_tabpage = tabpage
    break
  end
end
assert(focused_tabpage ~= nil, "expected to find the dehydrated Tabpage for the originally-focused tab")
assert(
  universe.currentTabpage == focused_tabpage.uuid,
  "expected universe.currentTabpage to be the uuid of the originally-focused tabpage"
)
assert(focused_tabpage ~= universe.tabpages[#universe.tabpages],
  "test setup error: the focused tabpage must not be the last one, or this test can't distinguish a fix from the bug")

tabpage_manager.hydrate(universe)
window_layout_manager.hydrate(universe)

-- tabpage_manager.hydrate() overwrites every Tabpage.tabpageId with a fresh
-- id from :tabnew, so re-resolve the expected tabpageId by uuid rather than
-- trusting the (now stale) id captured at dehydrate time.
local rehydrated_focused_tabpage
for _, tabpage in ipairs(universe.tabpages) do
  if tabpage.uuid == universe.currentTabpage then
    rehydrated_focused_tabpage = tabpage
    break
  end
end
assert(rehydrated_focused_tabpage ~= nil, "expected to find the rehydrated Tabpage matching universe.currentTabpage")

local actual = vim.api.nvim_get_current_tabpage()
assert(
  actual == rehydrated_focused_tabpage.tabpageId,
  "expected focus to land on the originally-active tabpage (" .. vim.inspect(rehydrated_focused_tabpage.tabpageId)
    .. ") after hydrate, got " .. vim.inspect(actual)
)

print("PASS")
os.exit(0)
