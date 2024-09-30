local Buffer = {}
Buffer.__index = Buffer

--- @class Buffer
--- @field new fun(id: number, bufferName: string): Buffer
--- @field uuid string -- A unique immutable identifier for this buffer that is persisted and rehydrated.
--- @field bufferId number | nil -- The neovim id for this buffer, this will NOT be persisted and is to be set after hydration.
--- @field bufferName string

--- @param uuid string
--- @param bufferId number
--- @param bufferName string
function Buffer:new(uuid, bufferId, bufferName)
	local self = setmetatable({}, Buffer)
	self.uuid = uuid
	self.bufferId = bufferId
	self.bufferName = bufferName
	return self
end

return Buffer
