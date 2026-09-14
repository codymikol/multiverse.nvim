-- Regression test for GitHub issue #175 (hydrateTabpage assigns a
-- freshly-created window id to the wrong layout node on nested Row/Column
-- layouts, causing a buffer to go missing after hydrate).
--
-- This is NOT a busted-style spec, and is deliberately NOT named
-- `*_spec.lua` so Plenary's busted runner (which globs `*_spec.lua`) never
-- collects it: it exercises real `vim.api` calls (buffers, windows,
-- options) that busted/luarocks cannot provide, calls `os.exit()`, and must
-- be run inside an actual nvim instance rather than via the busted test
-- runner used by the other files under lua/test/**/*_spec.lua.
--
-- Run from the repository root with:
--   nvim --headless -u NONE -l lua/test/managers/window_layout_manager.hydrate_nested.headless.lua
--
-- The script prints "PASS" and exits 0 on success, or raises a Lua error
-- (via `assert`) and exits non-zero on failure.

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path
local dehydration_manager = require("multiverse.managers.dehydration_manager")
local window_layout_manager = require("multiverse.managers.window_layout_manager")
local helpers = require("test.managers.window_layout_headless_helpers")
local make_buf = helpers.make_buf

vim.api.nvim_win_set_buf(0, make_buf("/tmp/a.txt"))
vim.cmd("split")
vim.api.nvim_win_set_buf(0, make_buf("/tmp/b.txt"))
vim.cmd("vsplit")
vim.api.nvim_win_set_buf(0, make_buf("/tmp/c.txt"))

local universe = dehydration_manager.dehydrate({ uuid = "u", name = "u", directory = "/tmp" })

vim.cmd("only")
vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(false, true))

window_layout_manager.hydrate(universe)

local presentNames = {}
for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
  local bufname = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w))
  presentNames[bufname] = true
end

assert(presentNames["/tmp/a.txt"], "expected /tmp/a.txt to be present among windows after hydrate, but it was missing")
assert(presentNames["/tmp/b.txt"], "expected /tmp/b.txt to be present among windows after hydrate, but it was missing")
assert(presentNames["/tmp/c.txt"], "expected /tmp/c.txt to be present among windows after hydrate, but it was missing")

print("PASS")
os.exit(0)
