local Window = {}
Window.__index = Window

--- @class Window
--- @field new fun(uuid: string, bufferUuid: string | nil, windowId: number | nil): Window
--- @field uuid string A unique immutable identifier for this window that is persisted and rehydrated.
--- @field bufferUuid string | nil A unique immutable identifier for the buffer displayed in this window that is persisted and rehydrated.
--- @field windowId number | nil The neovim id for this window that is NOT persisted.
--- @param uuid string
--- @param bufferUuid string | nil The uuid of the buffer that this window is displaying.
--- @param windowId number | nil
function Window:new(uuid, bufferUuid, windowId)
	local self = setmetatable({}, Window)
	self.uuid = uuid
	self.windowId = windowId
	self.bufferUuid = bufferUuid
	return self
end

--- @param windowId number
--- @return nil
function Window:setWindowId(windowId)
	self.windowId = windowId
end

--- @param bufferUuid string
function Window:setBufferUuid(bufferUuid)
	self.bufferUuid = bufferUuid
end

return Window
