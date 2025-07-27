local M = {}

local debug = true

local log_file = vim.fn.stdpath("cache") .. "/multiverse.log"

vim.notify("Multiverse logging initialized at " .. log_file, vim.log.levels.INFO)

local function log(message, level)

  local f = io.open(log_file, "a")
  if not f then
    vim.notify("Failed to open log file: " .. log_file, vim.log.levels.ERROR)
    return
  end

  local log_entry = {
    ts = os.date("!%Y-%m-%dT%H:%M:%SZ"), -- ISO 8601 UTC
    level = level,
    msg = message,
    logger = "multiverse",
  }

  f:write(vim.fn.json_encode(log_entry) .. "\n")
  f:close()

end

function M.get_log_file()
  return log_file
end

function M.set_debug(value)
  debug = value
end

function M.info(message)
  log(message, "info")
end

function M.warn(message)
    log(message, "warn")
end

function M.error(message)
    log(message, "error")
end

function M.debug(message)
  if debug then
    log(message, "debug")
  end
end


return M
