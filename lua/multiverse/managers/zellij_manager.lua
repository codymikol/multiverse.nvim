local log = require("multiverse.log")

local M = {}

-- Tracks the single floating terminal this module may currently have open, so
-- `close_floating_terminal()` can be called with no arguments (e.g. from a
-- plugin's beforeDehydrate hook) without the caller having to thread ids through.
local floating_terminal = { win_id = nil, buf_id = nil }

--- @return boolean true when the zellij binary is on PATH
M.is_available = function()
  return vim.fn.executable("zellij") == 1
end

--- Deterministically derives a zellij session name from a working directory.
--- Hashing the directory (rather than a per-universe id) is what lets this be
--- recomputed identically at dehydrate time (from a Universe's workingDirectory)
--- and at hydrate time (from vim.fn.getcwd()) without any shared persistence.
--- @param working_directory string
--- @return string
M.session_name_for = function(working_directory)
  return "multiverse-" .. vim.fn.sha256(working_directory)
end

--- Opens a centered floating window over a new scratch buffer and attaches
--- (or creates, via `--create`) the given zellij session inside it.
--- @param session_name string
--- @return number win_id
--- @return number buf_id
M.open_floating_terminal = function(session_name)
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf_id = vim.api.nvim_create_buf(false, true)

  local win_id = vim.api.nvim_open_win(buf_id, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  })

  vim.fn.termopen("zellij attach --create " .. session_name)

  floating_terminal.win_id = win_id
  floating_terminal.buf_id = buf_id

  return win_id, buf_id
end

--- Closes a floating terminal window/buffer previously returned by
--- `open_floating_terminal`. Called with no arguments, it closes whichever
--- one is currently tracked (a no-op if none is open). The zellij session
--- itself lives on in the zellij server process, so force-deleting the
--- nvim-side buffer here loses nothing.
--- @param win_id number|nil
--- @param buf_id number|nil
M.close_floating_terminal = function(win_id, buf_id)
  win_id = win_id or floating_terminal.win_id
  buf_id = buf_id or floating_terminal.buf_id

  if win_id and vim.api.nvim_win_is_valid(win_id) then
    local status, err = pcall(vim.api.nvim_win_close, win_id, true)
    if status then
      log.debug("successfully closed zellij floating window " .. vim.inspect(win_id))
    else
      log.error("error closing zellij floating window " .. vim.inspect(win_id) .. ", error: " .. vim.inspect(err))
    end
  end

  if buf_id and vim.api.nvim_buf_is_valid(buf_id) then
    local status, err = pcall(vim.api.nvim_buf_delete, buf_id, { force = true })
    if status then
      log.debug("successfully deleted zellij terminal buffer " .. vim.inspect(buf_id))
    else
      log.error("error deleting zellij terminal buffer " .. vim.inspect(buf_id) .. ", error: " .. vim.inspect(err))
    end
  end

  if win_id == floating_terminal.win_id then
    floating_terminal.win_id = nil
  end
  if buf_id == floating_terminal.buf_id then
    floating_terminal.buf_id = nil
  end
end

--- @return boolean true when a floating terminal opened via `open_floating_terminal` is currently tracked as open
M.is_floating_terminal_open = function()
  return floating_terminal.win_id ~= nil and floating_terminal.buf_id ~= nil
end

--- Reattaches to an already-running zellij session for the given name, if one
--- exists on the zellij server. This is what lets a terminal session survive
--- a universe switch: closing the floating terminal (e.g. via beforeDehydrate)
--- only tears down the nvim-side window/buffer, the zellij session itself
--- keeps running, so on the way back in we just re-open a window onto it
--- instead of creating a fresh one.
--- @param session_name string
--- @return boolean true when a matching running session was found and reattached to
M.reattach_if_running = function(session_name)
  if not M.is_available() then
    return false
  end

  local sessions = vim.fn.systemlist("zellij list-sessions --short")

  for _, session in ipairs(sessions) do
    if vim.trim(session) == session_name then
      M.open_floating_terminal(session_name)
      return true
    end
  end

  return false
end

return M
