local Buffer = {}
Buffer.__index = Buffer

local function isNonEmptyString(value)
	return type(value) == "string" and value ~= ""
end

--- @class Buffer
--- @field uuid string -- A unique immutable identifier for this buffer that is persisted and rehydrated.
--- @field bufferId number | nil -- The neovim id for this buffer, this will NOT be persisted and is to be set after hydration.
--- @field bufferName string
---
--- @param opts table
--- @param opts.uuid string  a unique immutable identifier for the buffer
--- @param opts.bufferId number | nil  the neovim id for this buffer
--- @param opts.bufferName string  the name of the buffer
function Buffer:new(opts)
	opts = opts or {}
	if type(opts) ~= "table" then
		error("Buffer:new requires a table argument", 2)
	end
	if not isNonEmptyString(opts.uuid) then
		error("Buffer:new requires opts.uuid to be a non-empty string", 2)
	end
	if not isNonEmptyString(opts.bufferName) then
		error("Buffer:new requires opts.bufferName to be a non-empty string", 2)
	end

	local self = setmetatable({}, Buffer)
	self.uuid = opts.uuid
	self.bufferId = opts.bufferId
	self.bufferName = opts.bufferName
	return self
end

return Buffer
