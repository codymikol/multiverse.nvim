local log = require("multiverse.log")
local persistance = require("multiverse.repositories.persistance")

local M = {}

--- @param session_name string
--- @return string the path to the on-disk flag file tracking whether the
--- floating terminal for this session was open the last time this
--- directory was dehydrated
local function open_flag_path(session_name)
  return persistance.getDir() .. "/zellij-open-" .. session_name
end

-- Tracks the single floating terminal this module may currently have open, so
-- `close_floating_terminal()` can be called with no arguments (e.g. from a
-- plugin's beforeDehydrate hook) without the caller having to thread ids through.
local floating_terminal = { win_id = nil, buf_id = nil }

--- @return boolean true when the zellij binary is on PATH
M.is_available = function()
  return vim.fn.executable("zellij") == 1
end

--- A pure hash of the given directory string, with no other input. Because
--- it's a pure function of the directory, calling it with the same directory
--- always produces the same session name, which is what lets a zellij
--- session survive across the dehydrate/hydrate boundary (e.g. `afterHydrate`
--- calling this with `vim.fn.getcwd()`) without needing any shared persistence.
---
--- Truncated to 16 hex chars (64 bits, plenty to avoid collisions across a
--- user's directories): the full 64-char sha256 digest pushes zellij's IPC
--- socket path (~/run/user/<uid>/zellij/contract_version_1/<name>) past the
--- AF_UNIX sun_path limit (108 bytes), which makes `zellij attach --create`
--- fail after it has already sent alt-screen/terminal-query escape codes,
--- leaving the terminal cleared with leftover query-response garbage printed
--- into the shell.
--- @param working_directory string
--- @return string
M.session_name_for = function(working_directory)
  return "multiverse-" .. vim.fn.sha256(working_directory):sub(1, 16)
end

--- Opens a centered floating window over a new scratch buffer and attaches
--- (or creates, via `--create`) the given zellij session inside it.
--- @param session_name string
--- @return number win_id
--- @return number buf_id
M.open_floating_terminal = function(session_name)
  -- Close any floating terminal already tracked before opening a new one, so
  -- repeated calls (e.g. afterHydrate firing again after a universe switch)
  -- never orphan the previous window/buffer on screen (regression of #70/#75).
  M.close_floating_terminal()

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

  vim.fn.jobstart("zellij attach --create " .. vim.fn.shellescape(session_name), { term = true })

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
      log.debug("successfully closed zellij floating window %s", win_id)
    else
      log.error("error closing zellij floating window %s, error: %s", win_id, err)
    end
  end

  if buf_id and vim.api.nvim_buf_is_valid(buf_id) then
    local status, err = pcall(vim.api.nvim_buf_delete, buf_id, { force = true })
    if status then
      log.debug("successfully deleted zellij terminal buffer %s", buf_id)
    else
      log.error("error deleting zellij terminal buffer %s, error: %s", buf_id, err)
    end
  end

  if win_id == floating_terminal.win_id then
    floating_terminal.win_id = nil
  end
  if buf_id == floating_terminal.buf_id then
    floating_terminal.buf_id = nil
  end
end

--- @return boolean true when a floating terminal opened via `open_floating_terminal` is currently tracked
--- as open AND its window/buffer are still valid (e.g. not manually closed by the user since)
M.is_floating_terminal_open = function()
  return floating_terminal.win_id ~= nil
    and floating_terminal.buf_id ~= nil
    and vim.api.nvim_win_is_valid(floating_terminal.win_id)
    and vim.api.nvim_buf_is_valid(floating_terminal.buf_id)
end

--- Persists that the floating terminal for the given session was open, so a
--- later `was_open` call (e.g. from a fresh nvim process on `afterHydrate`)
--- knows to reattach. Survives across full Neovim restarts, unlike an
--- in-memory flag.
--- @param session_name string
M.mark_open = function(session_name)
  vim.fn.mkdir(persistance.getDir(), "p")

  local path = open_flag_path(session_name)
  local status, file_or_err = pcall(io.open, path, "w")
  if not status or file_or_err == nil then
    log.error("error opening zellij open-flag file %s for writing, error: %s", path, file_or_err)
    return
  end

  file_or_err:close()
  log.debug("marked zellij session %s as open", session_name)
end

--- Clears the on-disk flag set by `mark_open`, so a later `was_open` call
--- returns false. A harmless no-op if the flag was never set.
--- @param session_name string
M.mark_closed = function(session_name)
  vim.fn.delete(open_flag_path(session_name))
  log.debug("marked zellij session %s as closed", session_name)
end

--- @param session_name string
--- @return boolean true when the floating terminal for this session was open
--- the last time this directory was dehydrated (per `mark_open`/`mark_closed`)
M.was_open = function(session_name)
  return vim.fn.filereadable(open_flag_path(session_name)) == 1
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

  local command = "zellij list-sessions --short"
  local sessions = vim.fn.systemlist(command)

  if vim.v.shell_error ~= 0 then
    log.error("error running %s, exit code: %s", command, vim.v.shell_error)
    return false
  end

  for _, session in ipairs(sessions) do
    if vim.trim(session) == session_name then
      M.open_floating_terminal(session_name)
      return true
    end
  end

  return false
end

return M
