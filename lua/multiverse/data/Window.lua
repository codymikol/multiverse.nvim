local Window = {}
Window.__index = Window

--- @class Window
--- @field windowId number
--- @field buffers Buffer[]
--- @field setBuffer (Buffer) -> nil

--- @param id number
function Window:new(id)
  local self = setmetatable({}, Window)
  self.id = id
  self.buffer = nil
  return self
end

--- @param buffer Buffer
function Window:setBuffer(buffer)
  self.buffer = buffer
end

return Window
