local M = {}

local Buffer = require("multiverse.data.Buffer")
local uuid_manager = require("multiverse.managers.uuid_manager")
local log = require("multiverse.log")

--- @param universe Universe
M.hydrateBuffersForUniverse = function(universe)

  log.debug("Hydrating buffers for universe: " .. vim.inspect(universe.uuid))

  for _, buffer in ipairs(universe.buffers) do

    log.debug("Hydrating buffer: " .. vim.inspect(buffer.bufferName))

    if buffer.bufferName == "" or buffer.bufferName == nil then
      log.debug("Buffer name is empty, assuming it's a scratch buffer and not opening: " .. vim.inspect(buffer.bufferId))
    else
      vim.api.nvim_command("badd " .. buffer.bufferName)
      local buffer_number = vim.fn.bufnr(buffer.bufferName, true)
      buffer.bufferId = buffer_number
    end

  end

end

--- @param name string
local function isScratchBuffer(name)
  return name == ""
end

--- @param buffer_id number
local function isModifiableBuffer(buffer_id)
 return vim.api.nvim_get_option_value("modifiable", { buf = buffer_id })
end

--- @param buffer_id number
local function isReadOnlyBuffer(buffer_id)
  return vim.api.nvim_get_option_value("readonly", { buf = buffer_id })
end

--- @param buffer_id number
local function isNormalBuffer(buffer_id)
  return vim.api.nvim_get_option_value("buftype", { buf = buffer_id }) == ""
end

local function get_buf_desc(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr })

  return vim.inspect(name) .. " (" .. vim.inspect(buftype) .. ") " .. vim.inspect(bufnr)

end

--- @param buffer_id number assumed valid; callers must check nvim_buf_is_valid first (see isUniverseBuffer)
local function isDesiredUniverseBuffer(buffer_id)

  -- buffers can be unloaded, but still a part of the universe, they aren't "loaded" until the user clicks on that buffer.

  if not isModifiableBuffer(buffer_id) then
    log.debug("buffer " .. get_buf_desc(buffer_id) .. " is not modifiable, not closing...")
    return false
  end

  if isReadOnlyBuffer(buffer_id) then
    log.debug("buffer " .. get_buf_desc(buffer_id) .. " is read only, not closing...")
    return false
  end

  if not isNormalBuffer(buffer_id) then
    log.debug("buffer " .. get_buf_desc(buffer_id) .. " is not a normal buffer, not closing...")
    return false
  end

  return true
end

--- @param buffer_id number
--- @return boolean
M.isUniverseBuffer = function(buffer_id)
  if not vim.api.nvim_buf_is_valid(buffer_id) then
    return false
  end

  if not isDesiredUniverseBuffer(buffer_id) then
    return false
  end

  if not vim.api.nvim_get_option_value("buflisted", { buf = buffer_id }) then
    return false
  end

  if isScratchBuffer(vim.api.nvim_buf_get_name(buffer_id)) then
    return false
  end

  return true
end

M.closeAllBuffers = function()
  local buffersToClose = M.get_all_buffers()
  for _, buffer in ipairs(buffersToClose) do
    local status, err = pcall(vim.api.nvim_buf_delete, buffer.bufferId, {})
    if status then
      log.debug("successfully closed buffer " .. vim.inspect(buffer.bufferId))
    else
      log.error("error deleting buffer " .. vim.inspect(buffer.bufferId) .. ", error: " .. err)
    end
  end
end

M.get_all_buffers = function()
  local bufferList = {}
  local buffers = vim.fn.getbufinfo({buflisted = 1})
  for _, buf in ipairs(buffers) do

    local buffer_id = buf.bufnr

    if M.isUniverseBuffer(buffer_id) then

      local name = vim.api.nvim_buf_get_name(buffer_id)
      local bufferUuid = uuid_manager.create()
      local buffer = Buffer:new(bufferUuid, buffer_id, name)

      table.insert(bufferList, buffer)

    end
  end
  return bufferList
end

M.close_generated_nofile_scratch_buffers = function()

  log.debug("Closing generated scratch buffers...")

  local buffers = vim.fn.getbufinfo({buflisted = 1})
  for _, buf in ipairs(buffers) do

    local buffer_id = buf.bufnr
    local name = vim.api.nvim_buf_get_name(buffer_id)

    log.debug("Checking buffer: " .. vim.inspect(buffer_id) .. ", name: " .. vim.inspect(name) .. " nofile: " .. vim.inspect(vim.api.nvim_get_option_value("buftype", { buf = buffer_id })))

    local is_generated_buffer = name == "" and vim.api.nvim_get_option_value("buftype", { buf = buffer_id }) == ""

    if is_generated_buffer then
      local wins = vim.fn.win_findbuf(buffer_id)
      log.debug("Found windows for generated buffer " .. vim.inspect(buffer_id) .. ": " .. vim.inspect(wins))
      log.debug("Closing generated scratch buffer: " .. vim.inspect(buffer_id))
      local old_switchbuf = vim.o.switchbuf

      vim.o.switchbuf = "useopen"

      local status, err = pcall(vim.api.nvim_buf_delete, buffer_id, { force = true })
      if status then
        log.debug("successfully closed generated scratch buffer " .. vim.inspect(buffer_id))
      else
        log.error("error deleting generated scratch buffer " .. vim.inspect(buffer_id) .. ", error: " .. err)
      end

      vim.o.switchbuf = old_switchbuf
    end

  end
end

return M
