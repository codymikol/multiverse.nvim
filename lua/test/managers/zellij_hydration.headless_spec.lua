-- Regression test for terminal session preservation (GitHub issue #276).
--
-- This is NOT a busted-style spec, and is deliberately NOT named
-- `*.spec.lua` alone so a busted runner globbing this tree never collects
-- it: it exercises real `vim.api` calls (buffers, windows, files) that
-- busted/luarocks cannot provide, calls `os.exit()`, and must be run inside
-- an actual nvim instance rather than via the busted test runner used by
-- the other files under lua/test/**/*.spec.lua.
--
-- Its job is narrow: prove a full dehydrate -> hydrate cycle does not crash
-- (regression coverage in the spirit of #70/#75) when a terminal-buftype
-- buffer/window is present, and that the zellij plugin's hooks no-op
-- cleanly when zellij isn't installed (acceptance criterion "no-op
-- gracefully when zellij isn't installed" from #276) -- since zellij is
-- almost certainly not installed in this CI/test environment, that no-op
-- path is exercised for real rather than via a stub. zellij CLI behavior
-- itself (session listing/reattach) is covered by zellij_manager_spec.lua's
-- stubbed unit tests, not here.
--
-- Deliberately exercises the zellij plugin's own hooks directly rather than
-- plugin_manager.beforeDehydrate/afterHydrate: the latter also drives
-- NeoTreePlugin, whose hooks call `:Neotree ...` unconditionally (no
-- `:Neotree` existence guard), which errors in any headless environment
-- that hasn't loaded neo-tree.nvim (this repo's own ci/minimal_config.lua
-- included) -- a pre-existing gap unrelated to this slice's zellij work.
--
-- Run from the repository root with:
--   nvim --headless -u NONE -l lua/test/managers/zellij_hydration.headless_spec.lua

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

-- This file is spawned by PlenaryBustedDirectory as its own nvim subprocess
-- using nvim's default config (not ci/minimal_config.lua), so 'swapfile'
-- defaults on; hydrateBuffersForUniverse below runs a real `:badd` against a
-- file on disk, which would otherwise prompt on a stale/concurrent swap file
-- and hang this "headless" run.
vim.o.swapfile = false

local zellij_plugin = require("plugins.zellij_plugin")
local plugin_manager = require("multiverse.managers.plugin_manager")
local dehydration_manager = require("multiverse.managers.dehydration_manager")
local hydration_manager = require("multiverse.managers.hydration_manager")
local cleanup_manager = require("multiverse.managers.cleanup_manager")
local universe_repository = require("multiverse.repositories.universe_repository")
local persistance = require("multiverse.repositories.persistance")
local UniverseSummary = require("multiverse.data.UniverseSummary")
local zellij_manager = require("multiverse.managers.zellij_manager")

assert(zellij_manager.is_available() == false,
  "expected zellij to not be installed in this test environment; if it is, this test's no-op-path coverage no longer applies")

local test_dir = "/tmp/multiverse_test_zellij_hydration"
vim.fn.mkdir(test_dir, "p")
vim.api.nvim_command("cd " .. vim.fn.fnameescape(test_dir))

-- A normal, real-file buffer in the "base" window, so the dehydrate/hydrate
-- cycle has real universe state to carry across in addition to the terminal
-- buffer below.
local normal_buf_path = test_dir .. "/normal_buf.txt"
local normal_file = io.open(normal_buf_path, "w")
normal_file:write("hello")
normal_file:close()

local base_win = vim.api.nvim_get_current_win()
local normal_buf = vim.api.nvim_create_buf(false, false)
vim.api.nvim_buf_set_name(normal_buf, normal_buf_path)
vim.api.nvim_set_option_value("buftype", "", { buf = normal_buf })
vim.api.nvim_set_option_value("modifiable", true, { buf = normal_buf })
vim.api.nvim_set_option_value("buflisted", true, { buf = normal_buf })
vim.api.nvim_win_set_buf(base_win, normal_buf)

-- Simulate a floating terminal window (the kind zellij_manager.open_floating_terminal
-- creates), without depending on the zellij binary actually being present.
-- 'buftype' can't be set to "terminal" directly (nvim rejects it with
-- E474); nvim_open_term is what actually turns a scratch buffer into a real
-- terminal buffer, same as termopen() does under the hood.
local term_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_open_term(term_buf, {})
vim.api.nvim_open_win(term_buf, true, {
  relative = "editor",
  width = 40,
  height = 10,
  row = 1,
  col = 1,
  style = "minimal",
})

local function count_terminal_buffers()
  local count = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_get_option_value("buftype", { buf = buf }) == "terminal" then
      count = count + 1
    end
  end
  return count
end

local terminal_buffers_before = count_terminal_buffers()
assert(terminal_buffers_before == 1,
  "expected exactly 1 terminal buffer to be set up before the cycle, got " .. terminal_buffers_before)

local summary = UniverseSummary:new(test_dir, "test-zellij-hydration-uuid", "test-zellij-hydration-universe", 0)

-- beforeDehydrate: zellij plugin should no-op (is_available() is false) rather than raise.
local before_dehydrate_ok, before_dehydrate_err = pcall(zellij_plugin.context.beforeDehydrate, {})
assert(before_dehydrate_ok,
  "expected the zellij plugin's beforeDehydrate to not crash with a terminal buffer present, got error: " .. tostring(before_dehydrate_err))

local dehydrate_ok, universe = pcall(dehydration_manager.dehydrate, summary)
assert(dehydrate_ok,
  "expected dehydrate to not crash with a terminal buffer present, got error: " .. tostring(universe))

local after_dehydrate_ok, after_dehydrate_err = pcall(plugin_manager.afterDehydrate, { universe = nil })
assert(after_dehydrate_ok,
  "expected plugin_manager.afterDehydrate to not crash, got error: " .. tostring(after_dehydrate_err))

vim.fn.mkdir(persistance.getDir(), "p")
local _, save_err = universe_repository.save_universe(universe)
assert(save_err == nil, "expected to save the dehydrated universe, got error: " .. tostring(save_err))

local before_hydrate_ok, before_hydrate_err = pcall(plugin_manager.beforeHydrate, { universe = nil })
assert(before_hydrate_ok,
  "expected plugin_manager.beforeHydrate to not crash, got error: " .. tostring(before_hydrate_err))

local cleanup_ok, cleanup_err = pcall(cleanup_manager.cleanup)
assert(cleanup_ok, "expected cleanup_manager.cleanup to not crash, got error: " .. tostring(cleanup_err))

local hydrate_ok, hydrate_err = pcall(hydration_manager.hydrate, summary)
assert(hydrate_ok,
  "expected hydrate to not crash with a terminal buffer present, got error: " .. tostring(hydrate_err))

-- afterHydrate: exercises the zellij plugin's new afterHydrate hook, which
-- should also no-op cleanly since zellij isn't installed.
local after_hydrate_ok, after_hydrate_err = pcall(zellij_plugin.context.afterHydrate, {})
assert(after_hydrate_ok,
  "expected the zellij plugin's afterHydrate to not crash, got error: " .. tostring(after_hydrate_err))

local terminal_buffers_after = count_terminal_buffers()
assert(terminal_buffers_after == terminal_buffers_before,
  "expected the terminal buffer to survive the cycle without being duplicated or orphaned, expected "
    .. terminal_buffers_before .. " terminal buffer(s), got " .. terminal_buffers_after)

print("PASS")
os.exit(0)
