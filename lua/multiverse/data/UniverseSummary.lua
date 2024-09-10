local UniverseSummary = {}
UniverseSummary.__index = UniverseSummary

--- @class UniverseSummary
--- @field name string 
--- @field uuid string
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

return UniverseSummary
