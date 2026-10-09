local M = {}

local Multiverse = require("multiverse.data.Multiverse")
local UniverseSummary = require("multiverse.data.UniverseSummary")
local json = require("multiverse.repositories.json")
local log = require("multiverse.log")

---@param jsonString string | nil
---@return Multiverse | nil
M.make = function (jsonString)

  local ok, multiverse_json_or_err = pcall(json.decode, jsonString)

  if not ok then
    log.error("Error decoding multiverse json, error details: %s", multiverse_json_or_err)
    return nil
  end

  if type(multiverse_json_or_err) ~= "table" then
    log.warn("Decoded multiverse json was not a table, got: %s", type(multiverse_json_or_err))
    return nil
  end

  if type(multiverse_json_or_err.universes) ~= "table" then
    log.warn("Decoded multiverse json was missing a table 'universes' field, got: %s", type(multiverse_json_or_err.universes))
    return nil
  end

  local multiverse = Multiverse:new({})

  for _, universe_json in pairs(multiverse_json_or_err.universes) do

    if type(universe_json) ~= "table" then
      log.warn("Discarding multiverse json: universe entry was not a table, got: %s", type(universe_json))
      return nil
    end

    local ok_summary, universeSummary_or_err = pcall(UniverseSummary.new, UniverseSummary, {
      directory = universe_json.directory,
      uuid = universe_json.uuid,
      name = universe_json.name,
      lastExplored = universe_json.lastExplored,
    })

    if not ok_summary then
      log.warn("Discarding multiverse json: invalid universe entry, error details: %s", universeSummary_or_err)
      return nil
    end

    multiverse:addUniverse(universeSummary_or_err)

  end

  return multiverse

end

return M
