local Buffer = {}
Buffer.__index = Buffer

--- @class Buffer
--- @field id number
--- @field bufferName string

--- @param id number
--- @param bufferName string
function Buffer:new(id, bufferName)
  local self = setmetatable({}, Buffer)
  self.id = id
  self.bufferName = bufferName
  return self
end

return Buffer
