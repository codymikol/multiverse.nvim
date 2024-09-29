
local Multiverse = {}
Multiverse.__index = Multiverse

--- @class Multiverse
--- @field universes table<string, UniverseSummary>  a list of universes
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
    vim.notify(vim.inspect(universe))
    vim.notify("comparing " .. universe.directory .. " with " .. directory)
    if universe.directory == directory then
      return universe
    end
  end
  return nil
end

return Multiverse
