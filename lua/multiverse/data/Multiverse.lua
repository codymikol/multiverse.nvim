
local Multiverse = {}
Multiverse.__index = Multiverse

--- @class Multiverse
--- @field universes UniverseSummary[]  the known universes in this multiverse
--- @field getUniverseByDirectory fun(directory: string): UniverseSummary | nil
--- @field addUniverse fun(universe: UniverseSummary): nil
--- @field getUniverseByName fun(name: string): UniverseSummary | nil
---
--- @param universes UniverseSummary[]  the initial set of known universes
function Multiverse:new(universes)
  local self = setmetatable({}, Multiverse)
  self.universes = universes
  return self
end

--- @param universe UniverseSummary
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
