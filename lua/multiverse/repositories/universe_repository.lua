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
  local tmp_file = universe_file .. ".tmp"

  local json_string = json.encode(universe)

  local file, err = io.open(tmp_file, "w")

  if not file then
    return universe, "Failed to open temp file for universe: " .. tmp_file .. ", os returned error - " .. tostring(err)
  end

  local write_ok, write_err = file:write(json_string)

  if not write_ok then
    file:close()
    os.remove(tmp_file)
    return universe, "Failed to write temp file for universe: " .. tmp_file .. ", os returned error - " .. tostring(write_err)
  end

  local close_ok, close_err = file:close()

  if not close_ok then
    os.remove(tmp_file)
    return universe, "Failed to close temp file for universe: " .. tmp_file .. ", os returned error - " .. tostring(close_err)
  end

  -- Same filesystem as tmp_file (both under persistance.getDir()), so this rename is atomic.
  local ok, rename_err = os.rename(tmp_file, universe_file)

  if not ok then
    os.remove(tmp_file)
    return universe, "Failed to rename universe file: " .. tmp_file .. " to " .. universe_file .. ", os returned error - " .. tostring(rename_err)
  end

  return universe, nil

end


---@param universe Universe | UniverseSummary
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
---@return Universe | nil, string | nil
M.get_universe_by_uuid = function(uuid)

  local universe_file = getFilename(uuid)

  local file, err = io.open(universe_file, "r")

  if not file then
    return nil, "Failed to open universe file: " .. universe_file .. ", os returned error - " .. err
  end

  local json_string = file:read("*a")

  file:close()

  local universe = universe_factory.make(json_string)

  return universe, nil

end


return M
