local Column = {}
Column.__index = Column

--- @class Column
--- @field type string
--- @field windowId number | nil
--- @field children (Column | Row | Leaf)[]
--- @field addChild fun(child: Row | Column | Leaf)
--- @field setWindowId fun(windowId: number)

function Column:new()
  local self = setmetatable({}, Column)
  self.type = "column"
  self.children = {}
  self.windowId = nil
  return self
end

function Column: setWindowId(windowId)
  self.windowId = windowId
end

--- @param child Row | Column | Leaf
function Column:addChild(child)
  table.insert(self.children, child)
end

return Column
