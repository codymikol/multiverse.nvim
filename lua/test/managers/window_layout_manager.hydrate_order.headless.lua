-- Regression test for GitHub issue #279 (hydrateTabpage reverses sibling
-- order within Row/Column layout nodes because container nodes reuse the
-- window id of their first-processed descendant, and nvim's default
-- `nosplitbelow`/`nosplitright` options place freshly-created split windows
-- before, not after, the window they were split from).
--
-- This is NOT a busted-style spec, and is deliberately NOT named
-- `*_spec.lua` so Plenary's busted runner (which globs `*_spec.lua`) never
-- collects it: it exercises real `vim.api` calls (buffers, windows,
-- options) that busted/luarocks cannot provide, calls `os.exit()`, and must
-- be run inside an actual nvim instance rather than via the busted test
-- runner used by the other files under lua/test/**/*_spec.lua.
--
-- Run from the repository root with:
--   nvim --headless -u NONE -l lua/test/managers/window_layout_manager.hydrate_order.headless.lua
--
-- The script prints "PASS" and exits 0 on success, or raises a Lua error
-- (via `assert`) and exits non-zero on failure.

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path
local dehydration_manager = require("multiverse.managers.dehydration_manager")
local window_layout_manager = require("multiverse.managers.window_layout_manager")
local helpers = require("test.managers.window_layout_headless_helpers")
local make_buf = helpers.make_buf
local layout_by_bufname = helpers.layout_by_bufname

-- Pin these explicitly (rather than relying on the documented `-u NONE`
-- invocation leaving them at nvim's defaults) so this test's ability to
-- catch a prepend-instead-of-append regression doesn't silently depend on
-- how it's invoked.
vim.o.splitbelow = false
vim.o.splitright = false

vim.api.nvim_win_set_buf(0, make_buf("/tmp/a.txt"))
vim.cmd("split")
vim.api.nvim_win_set_buf(0, make_buf("/tmp/b.txt"))
vim.cmd("vsplit")
vim.api.nvim_win_set_buf(0, make_buf("/tmp/c.txt"))

local pre = layout_by_bufname(vim.fn.winlayout())

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
