local uuid_manager = require("multiverse.managers.uuid_manager")

local Window = {}
Window.__index = Window

--- @class Window
--- @field new fun(uuid: string): Window
--- @field uuid number A unique immutable identifier for this window that is persisted and rehydrated.
--- @field bufferId number | nil The neovim id for the buffer on this window that is NOT persisted.
--- @field bufferUuid string The neovim id for the buffer on this window that is NOT persisted.
--- @field windowId number | nil The neovim id for this window that is NOT persisted.
--- @param uuid string
--- @param bufferUuid string The uuid of the buffer that this window is displaying.
--- @param windowId number | nil
function Window:new(uuid, bufferUuid, windowId)
	local self = setmetatable({}, Window)
	self.uuid = uuid
	self.windowId = windowId
	self.bufferUuid = bufferUuid
	self.bufferId = nil
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

--- @param bufferId number
function Window:setBufferId(bufferId)
	self.bufferId = bufferId
end

return Window
