-- Regression test for GitHub issue #101 (crash when opening nvim directly on
-- a directory).
--
-- This is NOT a busted-style spec. It exercises real `vim.api` calls
-- (buffers, windows, options) that busted/luarocks cannot provide, so it
-- must be run inside an actual nvim instance rather than via the busted
-- test runner used by the other files under lua/test/**/*.spec.lua.
--
-- Run from the repository root with:
--   nvim --headless -u NONE -l lua/test/managers/dehydration_manager.spec.lua
--
-- The script prints "PASS" and exits 0 on success, or raises a Lua error
-- (via `assert`) and exits non-zero on failure.

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local Universe = require("multiverse.data.Universe")
local dehydration_manager = require("multiverse.managers.dehydration_manager")

-- Build a normal, real-file buffer so window_manager will pick it up as a
-- visible window (buftype="", buflisted=true, modifiable=true, real name).
local normal_buf = vim.api.nvim_create_buf(false, false)
vim.api.nvim_buf_set_name(normal_buf, "/tmp/multiverse_test_dehydration_manager_normal_buf.txt")
vim.api.nvim_set_option_value("buftype", "", { buf = normal_buf })
vim.api.nvim_set_option_value("modifiable", true, { buf = normal_buf })
vim.api.nvim_set_option_value("buflisted", true, { buf = normal_buf })

vim.api.nvim_win_set_buf(0, normal_buf)

-- Monkeypatch Universe:getBufferById to always return nil, simulating a
-- window whose buffer is not tracked in universe.buffers, even though
-- buffer_manager.get_all_buffers() picked it up and window_manager sees it
-- as a visible window. This reproduces the reported crash deterministically.
local original_getBufferById = Universe.getBufferById
Universe.getBufferById = function(self, bufferId)
  return nil
end

local summary = {
  uuid = "test-universe-uuid",
  name = "test-universe",
  directory = "/tmp",
}

local ok, err = pcall(dehydration_manager.dehydrate, summary)

-- restore original for hygiene, even though this is a one-shot process
Universe.getBufferById = original_getBufferById

assert(ok == true, "expected dehydrate to not crash when getBufferById returns nil, but got error: " .. tostring(err))

print("PASS")
os.exit(0)
