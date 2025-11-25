local M = {}

local Persistance = require("multiverse.repositories.persistance")
local Buffer = require("multiverse.data.Buffer")
local uuid_manager = require("multiverse.managers.uuid_manager")
local log = require("multiverse.log")

local function getCurrentBufferDirLocation()
  return Persistance.getDir() .. "/" .. vim.fn.sha256(require("workspaces").name())
end

local function getCurrentBufferFileLocation()
  return getCurrentBufferDirLocation() .. "/buffer.txt"
end

M.closeAll = function()

  local buffers = vim.api.nvim_list_bufs()

  for _, buffer in ipairs(buffers) do
    local is_terminal = vim.api.nvim_get_option_value("buftype", { buf = buffer }) == "terminal"
    if is_terminal then
      local status, err = pcall(vim.api.nvim_buf_delete, buffer, { force = true })
      if status then
        log.debug("successfully deleted terminal buffer " .. vim.inspect(buffer))
      else
        log.error("error deleting terminal buffer " .. vim.inspect(buffer) .. ", error: " .. vim.inspect(err))
      end
    else
      local status, err = pcall(vim.api.nvim_buf_delete, buffer, {})
      if status then
        log.info("successfully closed buffer " .. vim.inspect(buffer))
      else
        log.error("error deleting non terminal buffer " .. vim.inspect(buffer) .. ", error: " .. vim.inspect(err))
      end
    end
  end

end

-- This will find all buffers that are currently open and persist
-- them into a file which will be used for rehydration.
M.saveAll = function()
  local workspaces = require("workspaces")

  local currentWorkspace = workspaces.name()

  local bufferDirLocation = getCurrentBufferDirLocation()

  vim.fn.mkdir(bufferDirLocation, "p")

  local bufferFileLocation = getCurrentBufferFileLocation()

  local bufferFile = io.open(bufferFileLocation, "w")

  if nil == bufferFile then
    log.error(
      "Error hydrating workspace state for: "
      .. vim.inspect(currentWorkspace)
      .. ", buffer file could not be opened at: "
      .. vim.inspect(bufferFileLocation)
    )
    return
  end

  local buffers = vim.api.nvim_list_bufs()

  for _, buffer in ipairs(buffers) do
    if
        vim.api.nvim_buf_is_loaded(buffer)
        and vim.api.nvim_buf_is_valid(buffer)
        and vim.api.nvim_buf_get_option(buffer, "modifiable")
    then
      local filename = vim.api.nvim_buf_get_name(buffer)
      log.debug("workspace: " .. vim.inspect(currentWorkspace) .. ", saving buffer: " .. vim.inspect(filename))
      if vim.fn.filereadable(filename) == 1 then
        bufferFile:write(filename .. "\n")
      end
    end
  end
  io.close(bufferFile)
end

M.hydrate = function()
  local currentBufferFileLocation = getCurrentBufferFileLocation()

  log.debug("hydrating from location: " .. vim.inspect(currentBufferFileLocation))

  local buffer = io.open(currentBufferFileLocation)

  if buffer ~= nil then
    for bufferFileLocation in buffer:lines() do
      log.debug("hydrating buffer from" .. log.inspect(bufferFileLocation))
      vim.api.nvim_command("edit " .. bufferFileLocation)
    end
    buffer:close()
  else
    log.debug("Found no lines when trying to hdrate windows")
  end
end

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

--- @param buffer Buffer
local function isScratchBuffer(buffer)
  return buffer.bufferName == ""
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

--- @param buffer_id number
local function isDesiredUniverseBuffer(buffer_id)

  -- buffers can be unloaded, but still a part of the universe, they aren't "loaded" until the user clicks on that buffer.

  --[[ if not vim.api.nvim_buf_is_loaded(buffer_id) then
    log.debug("buffer " .. get_buf_desc(buffer_id) .. " is not loaded, not closing...")
    return false
  end
]]
  if not vim.api.nvim_buf_is_valid(buffer_id) then
    log.debug("buffer " .. get_buf_desc(buffer_id) .. " is not valid, not closing...")
    return false
  end

  if not isModifiableBuffer(buffer_id) then
    log.debug("buffer " .. get_buf_desc(buffer_id) .. " is not modifiable, not closing...")
    return false
  end

  if isReadOnlyBuffer(buffer_id) then
    log.debug("buffer " .. get_buf_desc(buffer_id) .. " is read only, not closing...")
    return true
  end

  if not isNormalBuffer(buffer_id) then
    log.debug("buffer " .. get_buf_desc(buffer_id) .. " is not a normal buffer, not closing...")
    return false
  end

  return true

  --[[ return vim.api.nvim_buf_is_loaded(buffer_id)
    and vim.api.nvim_buf_is_valid(buffer_id)
    and isModifiableBuffer(buffer_id)
    and not isReadOnlyBuffer(buffer_id)
    and isNormalBuffer(buffer_id) ]]
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

    if isDesiredUniverseBuffer(buffer_id) then

      local name = vim.api.nvim_buf_get_name(buffer_id)
      local bufferUuid = uuid_manager.create()
      local buffer = Buffer:new(bufferUuid, buffer_id, name)

      if not isScratchBuffer(buffer) then
        table.insert(bufferList, buffer)
      end

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
