
local Multiverse = {}
Multiverse.__index = Multiverse

--- @class Multiverse
--- @field universes table<string, UniverseSummary>  a list of universes
--- @field getUniverseByDirectory (string): UniverseSummary | nil
--- @field getUniverseByName (string): UniverseSummary | nil
---
--- @param universes number the last time the universe was explored
function Multiverse:new(universes)
  local self = setmetatable({}, Multiverse)
  self.universes = universes
  return self
end

--- @param universe Universe
--- @return nil
function Multiverse:addUniverse(universe)
  table.insert(self.universes, universe)
end

--- @param directory string
--- @return UniverseSummary | nil
function Multiverse:getUniverseByDirectory(directory)
  for _, universe in ipairs(self.universes) do
    if universe.directory == directory then
      return universe
    end
  end
  return nil
end

--- @param name string
--- @return UniverseSummary | nil
function Multiverse:getUniverseByName(name)
  for _, universe in ipairs(self.universes) do
    if universe.name == name then
      return universe
    end
  end
  return nil
end

return Multiverse
