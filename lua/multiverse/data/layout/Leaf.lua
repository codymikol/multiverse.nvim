local Leaf = {}
Leaf.__index = Leaf

--- @class Leaf
--- @field type string
--- @field windowUuid string
--- @field windowId number | nil

--- @param windowUuid string
--- @param windowId number | nil
function Leaf:new(windowUuid, windowId)
  local self = setmetatable({}, Leaf)
  self.type = "leaf"
  self.windowUuid = windowUuid
  self.windowId = windowId
  return self
end

return Leaf
