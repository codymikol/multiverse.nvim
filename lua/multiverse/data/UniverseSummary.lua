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

--- Returns a sanitized lastExplored value: 0 for anything that isn't a
--- non-negative number (nil, non-numeric, NaN, negative).
--- @param universe_summary UniverseSummary | nil
--- @return number
function UniverseSummary.lastExploredOrZero(universe_summary)
  if type(universe_summary) ~= "table" then
    return 0
  end
  local value = universe_summary.lastExplored
  if type(value) ~= "number" or value ~= value then -- value ~= value is the standard NaN check
    return 0
  end
  return math.max(0, value)
end

return UniverseSummary
