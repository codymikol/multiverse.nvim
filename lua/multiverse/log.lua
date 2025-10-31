local M = {}

local debug = true

local log_file = vim.fn.stdpath("cache") .. "/multiverse.log"

local function log(message, level, ...)

  local parts = {}

  for i = 1, select("#", ...) do
    local substitution = select(i, ...)
    table.insert(parts, vim.inspect(substitution))
  end

  local formatted_message = string.format(message, unpack(parts))

  local f = io.open(log_file, "a")
  if not f then
    vim.notify("Failed to open log file: " .. log_file, vim.log.levels.ERROR)
    return
  end

  local log_message = string.format("%s %s %s",
    os.date("!%Y-%m-%dT%H:%M:%SZ"), -- ISO 8601 UTC
    level:upper(),
    formatted_message
  )

  f:write(log_message .. "\n")
  f:close()

end

function M.get_log_file()
  return log_file
end

function M.set_debug(value)
  debug = value
end

---@param message string message to log, can be formatted with string.format
---@return nil
---@param ... any varags that will be sent to string.format
function M.info(message, ...)
  log(message, "info", ...)
end

---@param message string message to log, can be formatted with string.format
---@return nil
---@param ... any varags that will be sent to string.format
function M.warn(message, ...)
    log(message, "warn", ...)
end

---@param message string message to log, can be formatted with string.format
---@return nil
---@param ... any varags that will be sent to string.format
function M.error(message, ...)
    log(message, "error", ...)
end

---@param message string message to log, can be formatted with string.format
---@return nil
---@param ... any varags that will be sent to string.format
function M.debug(message, ...)
  if debug then
    log(message, "debug", ...)
  end
end

return M
