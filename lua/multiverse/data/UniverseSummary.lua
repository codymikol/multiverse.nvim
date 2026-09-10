local timestamp_manager = require("multiverse.managers.timestamp_manager")

local UniverseSummary = {}
UniverseSummary.__index = UniverseSummary

--- @class UniverseSummary
--- @field directory string
--- @field uuid string
--- @field name string 
--- @field lastExplored number
---
--- @param directory string  the directory of the universe
--- @param uuid string  a unique identifier for the universe
--- @param name string  the name of the universe
--- @param lastExplored number the last time the universe was explored
function UniverseSummary:new(
  directory,
  uuid,
  name,
  lastExplored
)
  local self = setmetatable({}, UniverseSummary)
  self.directory = directory
  self.uuid = uuid
  self.name = name
  self.lastExplored = lastExplored
  return self
end

--- Sets lastExplored to the current timestamp.
--- @return UniverseSummary self
function UniverseSummary:setLastExploredToNow()
  self.lastExplored = timestamp_manager.now()
  return self
end

return UniverseSummary
