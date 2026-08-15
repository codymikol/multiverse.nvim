-- Regression test for GitHub issue #101 (crash when opening nvim directly on
-- a directory).
--
-- This is NOT a busted-style spec, and is deliberately NOT named
-- `*.spec.lua` so a busted runner globbing this tree never collects it: it
-- exercises real `vim.api` calls (buffers, windows, options) that
-- busted/luarocks cannot provide, calls `os.exit()`, and must be run inside
-- an actual nvim instance rather than via the busted test runner used by
-- the other files under lua/test/**/*.spec.lua.
--
-- Run from the repository root with:
--   nvim --headless -u NONE -l lua/test/managers/window_manager.headless.lua
--
-- The script prints "PASS" and exits 0 on success, or raises a Lua error
-- (via `assert`) and exits non-zero on failure.

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local window_manager = require("multiverse.managers.window_manager")

local tabpageId = vim.api.nvim_get_current_tabpage()

-- Scenario 1: a buffer with the option combination netrw's directory
-- listing exhibits when unlisted and non-modifiable (buftype="",
-- buflisted=false, modifiable=false) should be excluded from the visible
-- windows for the tabpage. Reuse the current window by pointing it at this
-- buffer. (Real netrw buffers are typically buftype="nofile"; buftype=""
-- here isolates the buflisted/modifiable exclusion this test targets.)
local netrw_buf = vim.api.nvim_create_buf(false, false)
vim.api.nvim_set_option_value("buftype", "", { buf = netrw_buf })
vim.api.nvim_set_option_value("modifiable", false, { buf = netrw_buf })
vim.api.nvim_set_option_value("buflisted", false, { buf = netrw_buf })

vim.api.nvim_win_set_buf(0, netrw_buf)

local windowsWithNetrwBuffer = window_manager.getAllVisibleWindowsForTabpage(tabpageId)

assert(#windowsWithNetrwBuffer == 0,
  "expected 0 windows for netrw-like (unlisted, non-modifiable) buffer, got " .. #windowsWithNetrwBuffer)

-- Scenario 2: normal buffer (buftype="", buflisted=true, modifiable=true,
-- real name) should be included in the visible windows for the tabpage.
local normal_buf = vim.api.nvim_create_buf(false, false)
vim.api.nvim_buf_set_name(normal_buf, "/tmp/multiverse_test_window_manager_normal_buf.txt")
vim.api.nvim_set_option_value("buftype", "", { buf = normal_buf })
vim.api.nvim_set_option_value("modifiable", true, { buf = normal_buf })
vim.api.nvim_set_option_value("buflisted", true, { buf = normal_buf })

vim.api.nvim_win_set_buf(0, normal_buf)

local windowsWithNormalBuffer = window_manager.getAllVisibleWindowsForTabpage(tabpageId)

assert(#windowsWithNormalBuffer == 1,
  "expected 1 window for normal (listed, modifiable) buffer, got " .. #windowsWithNormalBuffer)

print("PASS")
os.exit(0)
