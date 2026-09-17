local Window = {}
Window.__index = Window

local function isNonEmptyString(value)
	return type(value) == "string" and value ~= ""
end

--- @class Window
--- @field new fun(opts: { uuid: string, bufferUuid: string | nil, windowId: number | nil }): Window
--- @field uuid string A unique immutable identifier for this window that is persisted and rehydrated.
--- @field bufferUuid string | nil A unique immutable identifier for the buffer displayed in this window that is persisted and rehydrated.
--- @field windowId number | nil The neovim id for this window that is NOT persisted.
--- @param opts { uuid: string, bufferUuid: string | nil, windowId: number | nil }
function Window:new(opts)
	opts = opts or {}
	if type(opts) ~= "table" then
		error("Window:new requires a table argument", 2)
	end
	if not isNonEmptyString(opts.uuid) then
		error("Window:new requires opts.uuid to be a non-empty string", 2)
	end

	local self = setmetatable({}, Window)
	self.uuid = opts.uuid
	self.windowId = opts.windowId
	self.bufferUuid = opts.bufferUuid
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
