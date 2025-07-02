local json = require "multiverse.repositories.json"
local universe_factory = require "multiverse.factory.universe_factory"
local persistance = require "multiverse.repositories.persistance"
local M = {}

--- This repository is responsible for persisting files in the format of universe-${uuid}.json
--- these contain all of the hydration information for a given universe.

---@param uuid string
local function getFilename(uuid)
  return persistance.getDir() .. "/universe-" .. uuid .. ".json"
end

---@param universe Universe
---@return Universe, string | nil
M.save_universe = function(universe)

  local universe_file = getFilename(universe.uuid)

  local json_string = json.encode(universe)

  local file, err = io.open(universe_file, "w")

  if not file then
    return universe, "Failed to open universe file: " .. universe_file .. ", os returned error - " .. err
  end

  file:write(json_string)
  file:close()

  return universe, nil

end


---@param universe Universe
---
---@return boolean, string | nil
M.deleteUniverse = function(universe)

  local universe_file = getFilename(universe.uuid)

  local _, err = os.remove(universe_file)

  if err then
    return false, "Failed to delete universe file: " .. universe_file .. ", os returned error - " .. err
  end

  return true, nil

end

---@param uuid string
---@return string | nil, Universe | nil
M.getUniverseByUuid = function(uuid)
  
local universe_file = getFilename(uuid)

local file, err = io.open(universe_file, "r")

if not file then
  return "Failed to open universe file: " .. universe_file .. ", os returned error - " .. err, nil
end

local json_string = file:read("*a")

file:close()

local universe = universe_factory.make(json_string)

return nil, universe
-- todo(mikol): We need to build a Universe from the json table containing universe data.

end

return M
