-- Test for GitHub issue #104 (load universe when entering a universe
-- directory).
--
-- This is NOT a busted-style spec, and is deliberately NOT named
-- `*.spec.lua` so a busted runner globbing this tree never collects it: it
-- exercises real `vim.api` calls (buffers, windows) that busted/luarocks
-- cannot provide, calls `os.exit()`, and must be run inside an actual nvim
-- instance rather than via the busted test runner used by the other files
-- under lua/test/**/*.spec.lua.
--
-- Run from the repository root with:
--   nvim --headless -u NONE -l lua/test/managers/on_vim_enter.headless.lua
--
-- The script prints "PASS" and exits 0 on success, or raises a Lua error
-- (via `assert`) and exits non-zero on failure.

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local Multiverse = require("multiverse.data.Multiverse")
local UniverseSummary = require("multiverse.data.UniverseSummary")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local multiverse_manager = require("multiverse.managers.multiverse_manager")
local state_store = require("multiverse.store.state_store")

-- Build a real directory on disk, and point the current buffer's name at
-- it, simulating nvim having been started as `nvim <dir>`.
local test_dir = vim.fn.tempname()
vim.fn.mkdir(test_dir, "p")

vim.api.nvim_buf_set_name(0, test_dir)

-- Build a fake universe whose directory matches the buffer's directory.
local universe_summary =
	UniverseSummary:new({ directory = test_dir, uuid = "test-universe-uuid", name = "test-universe", lastExplored = 0 })

local multiverse = Multiverse:new({ universe_summary })

-- Monkeypatch multiverse_repository.getMultiverse to return our fake
-- multiverse rather than hitting disk.
local original_getMultiverse = multiverse_repository.getMultiverse
multiverse_repository.getMultiverse = function()
  return multiverse
end

-- Monkeypatch multiverse_manager.load_universe to just record the call,
-- rather than let the real, heavy-side-effect implementation run.
local original_load_universe = multiverse_manager.load_universe
local load_universe_calls = {}
multiverse_manager.load_universe = function(m, summary, skip_save)
  table.insert(load_universe_calls, { multiverse = m, universe_summary = summary, skip_save = skip_save })
end

-- Ensure we exercise the "no hydration/dehydration currently in flight"
-- branch.
state_store.set_current_state(state_store.STATES.IDLE)

local on_vim_enter = require("multiverse.autocmd.on_vim_enter")

on_vim_enter.on_vim_enter()

assert(#load_universe_calls == 1,
  "expected load_universe to be called exactly once, but was called " .. #load_universe_calls .. " times")

assert(load_universe_calls[1].universe_summary == universe_summary,
  "expected load_universe to be called with the matching universe summary")

assert(load_universe_calls[1].skip_save == true,
  "expected load_universe to be called with skip_save = true, since there is nothing meaningful "
    .. "to save at VimEnter and saving would clobber the target universe's persisted session")

-- Case: current buffer is a regular file (not a directory) → load_universe
-- must NOT be called.
load_universe_calls = {}

local regular_file = test_dir .. "/regular_file.txt"
local fh = io.open(regular_file, "w")
fh:write("not a directory")
fh:close()

vim.api.nvim_buf_set_name(0, regular_file)

on_vim_enter.on_vim_enter()

assert(#load_universe_calls == 0,
  "expected load_universe NOT to be called when the buffer is a regular file, but was called "
    .. #load_universe_calls .. " times")

-- Case: current buffer's directory does not match any registered universe
-- → load_universe must NOT be called.
load_universe_calls = {}

local unregistered_dir = vim.fn.tempname()
vim.fn.mkdir(unregistered_dir, "p")

vim.api.nvim_buf_set_name(0, unregistered_dir)

on_vim_enter.on_vim_enter()

assert(#load_universe_calls == 0,
  "expected load_universe NOT to be called when the buffer's directory does not match any "
    .. "registered universe, but was called " .. #load_universe_calls .. " times")

-- Case: state_store.get_current_state() is not IDLE (e.g. HYDRATION), even
-- though the directory matches a universe → load_universe must NOT be
-- called. This guards against double-firing alongside the existing
-- BufRead → save() listener.
load_universe_calls = {}

vim.api.nvim_buf_set_name(0, test_dir)
state_store.set_current_state(state_store.STATES.HYDRATION)

on_vim_enter.on_vim_enter()

state_store.set_current_state(state_store.STATES.IDLE)

assert(#load_universe_calls == 0,
  "expected load_universe NOT to be called when state_store is not IDLE, but was called "
    .. #load_universe_calls .. " times")

-- restore originals for hygiene, even though this is a one-shot process
multiverse_repository.getMultiverse = original_getMultiverse
multiverse_manager.load_universe = original_load_universe

print("PASS")
os.exit(0)
