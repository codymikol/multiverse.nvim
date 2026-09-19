-- Regression test for GitHub issue #297 (opening `nvim <universe-dir>`
-- directly hydrates a universe synchronously during `VimEnter`, firing
-- `FileType` for the restored buffer before other plugins that configure
-- themselves lazily -- e.g. treesitter/highlighter setups registered via
-- their own `FileType` autocmds -- have had a chance to register those
-- autocmds. Because hydration only fires `FileType` once, synchronously,
-- any listener registered afterwards never sees it, so the highlighter (or
-- similar) never attaches to the restored buffer.
--
-- This is NOT a busted-style spec, and is deliberately NOT named
-- `*_spec.lua` so Plenary's busted runner (which globs `*_spec.lua`) never
-- collects it: it exercises real `vim.api` autocmd/event-loop ordering
-- (registering a `FileType` autocmd *after* hydration has already run, and
-- pumping the event loop via `vim.wait` to give any deferred work a chance
-- to fire it) that busted/luarocks cannot provide, calls `os.exit()`, and
-- must be run inside an actual nvim instance rather than via the busted
-- test runner used by the other files under lua/test/**/*_spec.lua.
--
-- Run from the repository root with:
--   nvim --headless -u NONE -l lua/test/managers/hydration_manager.late_filetype_listener.headless.lua
--
-- The script prints "PASS" and exits 0 on success, or raises a Lua error
-- (via `assert`) and exits non-zero on failure.
--
-- Before the fix for #297, this fails at the final assertions: `*_fired`
-- flags stay false because hydration fires `FileType` synchronously once,
-- before the late listeners below are registered, and nothing re-fires it.
--
-- Both scenarios below go through a real dehydrate/hydrate round trip on
-- disk, using real files edited via `:edit` (rather than manually stamping
-- `vim.bo[buf].filetype`), and delete the original buffer object before
-- hydrating so nvim's own `:badd` + ftdetect path is exercised for real --
-- there is no leftover buffer around for hydration to coast on.

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local dehydration_manager = require("multiverse.managers.dehydration_manager")
local hydration_manager = require("multiverse.managers.hydration_manager")
local universe_repository = require("multiverse.repositories.universe_repository")

-- `-u NONE` skips user config, but filetype detection (ftdetect/ftplugin) is
-- runtime, not user config, and must be turned on explicitly for `:edit` to
-- assign a real filetype below -- otherwise every buffer's filetype stays
-- empty and both scenarios' assertions would be vacuous.
vim.cmd("filetype plugin indent on")

local original_get_universe_by_uuid = universe_repository.get_universe_by_uuid

--- Monkeypatches universe_repository.get_universe_by_uuid to hand back
--- `universe` directly (rather than hitting disk) for the duration of `fn`,
--- then restores the original implementation.
local function with_universe(universe, fn)
  universe_repository.get_universe_by_uuid = function(uuid)
    if uuid == universe.uuid then
      return universe, nil
    end
    return original_get_universe_by_uuid(uuid)
  end

  local ok, err = pcall(fn)

  universe_repository.get_universe_by_uuid = original_get_universe_by_uuid

  if not ok then
    error(err, 0)
  end
end

local function write_file(path, contents)
  local file = assert(io.open(path, "w"))
  file:write(contents)
  file:close()
end

-- Registers a "late" FileType autocmd for `pattern`, simulating a
-- lazily-configured plugin (e.g. a highlighter) registering its own
-- FileType autocmd *after* multiverse's VimEnter-time hydration has already
-- run and fired FileType once for the restored buffer. Only counts as fired
-- for `expected_bufnr` specifically -- a real highlighter attaches per-buffer
-- via `args.buf`, so a re-emission that fires for the wrong buffer must not
-- pass this check. Returns a function reporting whether it has fired yet.
local function register_late_listener(pattern, expected_bufnr)
  local fired = false
  vim.api.nvim_create_autocmd("FileType", {
    pattern = pattern,
    callback = function(args)
      if args.buf == expected_bufnr then
        fired = true
      end
    end,
  })
  return function()
    return fired
  end
end

----------------------------------------------------------------------------
-- Scenario A: single-window tabpage. `vim.fn.winlayout()` returns a bare
-- "leaf" node (not wrapped in a row/column) for a tabpage with no splits, so
-- this exercises hydrateTabpage's leaf-root special case directly.
----------------------------------------------------------------------------

write_file("/tmp/regression297_a.lua", "local function greet()\n  return \"hello\"\nend\n\nreturn greet\n")

vim.cmd("only")
vim.cmd("edit /tmp/regression297_a.lua")

local bufnr_a = vim.api.nvim_get_current_buf()

local universe_a = dehydration_manager.dehydrate({ uuid = "u297a", name = "u297a", directory = "/tmp" })

-- Delete the just-dehydrated buffer so hydration cannot pass by silently
-- reusing a leftover buffer object that already carries stale `filetype`
-- state left over from before hydration ran; `:badd` + real ftdetect must
-- (re)create the buffer for this assertion to mean anything.
vim.api.nvim_buf_delete(bufnr_a, { force = true })

-- Reset the editor state, simulating hydration running against a fresh
-- nvim instance (as it would at VimEnter), rather than reusing the window
-- that was just dehydrated.
vim.cmd("only")
vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(false, true))

with_universe(universe_a, function()
  -- This is the synchronous, VimEnter-time hydration call: it restores the
  -- buffer and fires `FileType` for it immediately, before any "late"
  -- listener below has been registered.
  hydration_manager.hydrate({ uuid = universe_a.uuid })
end)

-- Prove the window is actually displaying the restored buffer -- not just
-- that some unrelated buffer, somewhere, still carries a leftover filetype.
local restored_bufnr_a = vim.api.nvim_win_get_buf(0)
local restored_name_a = vim.api.nvim_buf_get_name(restored_bufnr_a)
assert(
  restored_name_a == "/tmp/regression297_a.lua",
  "expected the current window to display the restored buffer /tmp/regression297_a.lua after hydrate, got "
    .. vim.inspect(restored_name_a)
)

local lua_single_fired = register_late_listener("lua", restored_bufnr_a)

-- Pump the event loop so any deferred (vim.schedule'd) re-emission work has
-- a chance to run.
vim.wait(100, lua_single_fired)

assert(
  lua_single_fired(),
  "expected the late-registered FileType listener to eventually fire for the single-window buffer "
    .. "restored by hydration, demonstrating issue #297 is fixed for the leaf-root (no-split) case"
)

----------------------------------------------------------------------------
-- Scenario B: split (multi-window) tabpage. This exercises hydrateTabpage's
-- main `while #unexplored_layout > 0` traversal loop rather than the
-- leaf-root special case, so its `table.insert(hydrated_buffer_ids, ...)`
-- call for multiple windows in one tabpage is actually exercised too, not
-- just the single-window case above.
----------------------------------------------------------------------------

write_file("/tmp/regression297_b1.lua", "local function greet()\n  return \"hello\"\nend\n\nreturn greet\n")
write_file("/tmp/regression297_b2.py", "def greet():\n    return \"hello\"\n")

vim.cmd("only")
vim.cmd("edit /tmp/regression297_b1.lua")
local bufnr_b1 = vim.api.nvim_get_current_buf()

vim.cmd("vsplit")
vim.cmd("edit /tmp/regression297_b2.py")
local bufnr_b2 = vim.api.nvim_get_current_buf()

local universe_b = dehydration_manager.dehydrate({ uuid = "u297b", name = "u297b", directory = "/tmp" })

vim.api.nvim_buf_delete(bufnr_b1, { force = true })
vim.api.nvim_buf_delete(bufnr_b2, { force = true })

vim.cmd("only")
vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(false, true))

with_universe(universe_b, function()
  hydration_manager.hydrate({ uuid = universe_b.uuid })
end)

local restored_bufnrs_b = {}
for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
  local bufnr = vim.api.nvim_win_get_buf(win)
  restored_bufnrs_b[vim.api.nvim_buf_get_name(bufnr)] = bufnr
end

assert(
  restored_bufnrs_b["/tmp/regression297_b1.lua"] ~= nil,
  "expected /tmp/regression297_b1.lua to be restored to a window after hydrate"
)
assert(
  restored_bufnrs_b["/tmp/regression297_b2.py"] ~= nil,
  "expected /tmp/regression297_b2.py to be restored to a window after hydrate"
)

local lua_split_fired = register_late_listener("lua", restored_bufnrs_b["/tmp/regression297_b1.lua"])
local python_split_fired = register_late_listener("python", restored_bufnrs_b["/tmp/regression297_b2.py"])

vim.wait(100, function()
  return lua_split_fired() and python_split_fired()
end)

assert(
  lua_split_fired(),
  "expected the late-registered lua FileType listener to fire for /tmp/regression297_b1.lua after hydrate"
)
assert(
  python_split_fired(),
  "expected the late-registered python FileType listener to fire for /tmp/regression297_b2.py after hydrate"
)

os.remove("/tmp/regression297_a.lua")
os.remove("/tmp/regression297_b1.lua")
os.remove("/tmp/regression297_b2.py")

print("PASS")
os.exit(0)
