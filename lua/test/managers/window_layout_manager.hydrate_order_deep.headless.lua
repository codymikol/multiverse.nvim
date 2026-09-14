-- Additional regression coverage for GitHub issue #279 (hydrateTabpage used
-- plain `split`/`vsplit`, which prepends a newly-created sibling window
-- before the window it split from, reordering dehydrated siblings on
-- rehydrate). Unlike the sibling `hydrate_order.headless.lua` test, the PRE
-- fixture here is built with 'splitright'/'splitbelow' enabled so the nested
-- container lands as a non-first child one level deeper (see the reset
-- below for why that doesn't affect what's actually under test).
--
-- This is NOT a busted-style spec, and is deliberately NOT named
-- `*_spec.lua` so Plenary's busted runner (which globs `*_spec.lua`) never
-- collects it: it exercises real `vim.api` calls (buffers, windows,
-- options) that busted/luarocks cannot provide, calls `os.exit()`, and must
-- be run inside an actual nvim instance rather than via the busted test
-- runner used by the other files under lua/test/**/*_spec.lua.
--
-- Run from the repository root with:
--   nvim --headless -u NONE -l lua/test/managers/window_layout_manager.hydrate_order_deep.headless.lua
--
-- The script prints "PASS" and exits 0 on success, or raises a Lua error
-- (via `assert`) and exits non-zero on failure.

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path
local dehydration_manager = require("multiverse.managers.dehydration_manager")
local window_layout_manager = require("multiverse.managers.window_layout_manager")
local helpers = require("test.managers.window_layout_headless_helpers")
local make_buf = helpers.make_buf
local layout_by_bufname = helpers.layout_by_bufname

-- Force new windows to land after (right of / below) the window they split
-- from, so the nested containers below end up as non-first children.
vim.o.splitright = true
vim.o.splitbelow = true

vim.api.nvim_win_set_buf(0, make_buf("/tmp/a.txt"))
vim.cmd("vsplit")
vim.api.nvim_win_set_buf(0, make_buf("/tmp/b.txt"))
vim.cmd("split")
vim.api.nvim_win_set_buf(0, make_buf("/tmp/c.txt"))
vim.cmd("vsplit")
vim.api.nvim_win_set_buf(0, make_buf("/tmp/d.txt"))

local pre = layout_by_bufname(vim.fn.winlayout())

-- Reset to nvim's defaults so hydrate() below is exercised under default
-- split options, regardless of how the PRE fixture above was built.
vim.o.splitright = false
vim.o.splitbelow = false

local universe = dehydration_manager.dehydrate({ uuid = "u", name = "u", directory = "/tmp" })

vim.cmd("only")
vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(false, true))

window_layout_manager.hydrate(universe)

local post = layout_by_bufname(vim.fn.winlayout())

assert(
  vim.deep_equal(pre, post),
  "expected layout order to be preserved after hydrate, got pre=" .. vim.inspect(pre) .. " post=" .. vim.inspect(post)
)

print("PASS")
os.exit(0)
