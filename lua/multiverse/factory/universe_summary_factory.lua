local M = {}

local json = require("multiverse.repositories.json")
local UniverseSummary = require("multiverse.data.UniverseSummary")
local log = require("multiverse.log")

--- @param data string|nil
--- @return UniverseSummary|nil
M.make = function(data)
  local ok, decoded = pcall(json.decode, data)
  if not ok then
    log.error("Error decoding universe summary json, error details: %s", decoded)
    return nil
  end
  if type(decoded) ~= "table" then
    log.warn("Decoded universe summary json was not a table, got: %s", type(decoded))
    return nil
  end

  local ok_summary, summary = pcall(UniverseSummary.new, UniverseSummary, {
    directory = decoded.directory,
    uuid = decoded.uuid,
    name = decoded.name,
    lastExplored = decoded.lastExplored,
  })
  if not ok_summary then
    log.warn("Invalid universe summary json, error details: %s", summary)
    return nil
  end
  return summary
end

return M
