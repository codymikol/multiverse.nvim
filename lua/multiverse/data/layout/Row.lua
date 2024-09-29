local Row = {}
Row.__index = Row

--- @class Row
--- @field type string
--- @field windowId number | nil
--- @field children (Row | Column)[]
--- @field addChild fun(child: Row | Column | Leaf)
--- @field setWindowId fun(windowId: number)

function Row:new()
  local self = setmetatable({}, Row)
  self.type = "row"
  self.children = {}
  return self
end

--- @param windowId number
function Row: setWindowId(windowId)
  self.windowId = windowId
end

--- @param child Row | Column | Leaf
function Row:addChild(child)
  table.insert(self.children, child)
end

return Row
