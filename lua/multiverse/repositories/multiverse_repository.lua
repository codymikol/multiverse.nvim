local M = {}

local persistance = require("multiverse.repositories.persistance")
local json = require("multiverse.repositories.json")
local multiverse_factory = require("multiverse.factory.multiverse_factory")

local cache = nil

local function getMultiverseFile()
  return persistance.getDir() .. "/multiverse.json"
end

---@param multiverse Multiverse
---@return Multiverse | nil
M.save_multiverse = function(multiverse)

  local multiverse_file = getMultiverseFile()

  local file, _ = io.open(multiverse_file, "w")
  if file == nil then
    vim.notify("Failed to open multiverse.json")
    return nil
  end

  file:write(json.encode(multiverse))
  file:close()

end

---@return Multiverse
M.getMultiverse = function()

  if cache ~= nil then return cache end

  local multiverse_file = getMultiverseFile()

  local file, _ = io.open(multiverse_file, "r")

  local multiverse = nil

  if file == nil then
    multiverse = multiverse_factory.make('{"universes": [] }')
  else
    local multiverse_text = file:read("*a")
    multiverse = multiverse_factory.make(multiverse_text)
    file:close()
  end

  cache = multiverse

  return multiverse

end

return M

