local Leaf = {}
Leaf.__index = Leaf

--- @class Leaf
--- @field type string
--- @field windowUuid string
--- @field windowId number
--- @field setWindowId fun(windowId: number)

--- @param windowUuid string
--- @param windowId number
function Leaf:new(windowUuid, windowId)
  local self = setmetatable({}, Leaf)
  self.type = "leaf"
  self.windowUuid = windowUuid
  self.windowId = windowId
  return self
end

--- @param windowId number
function Leaf:setWindowId(windowId)
  self.windowId = windowId
end

return Leaf
