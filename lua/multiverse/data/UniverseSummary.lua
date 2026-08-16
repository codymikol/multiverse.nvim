local UniverseSummary = {}
UniverseSummary.__index = UniverseSummary

-- :new below is a positional constructor with no arg validation —
-- transposing any two args (e.g. calling with directory/name swapped) does
-- not raise here; it silently returns a corrupted instance whose symptom
-- may only surface much later, at an unrelated call site once persisted
-- (e.g. a bad lastExplored breaking the preview date formatting in the
-- telescope picker). See #188.
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

return UniverseSummary
