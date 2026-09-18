local Universe = {}
Universe.__index = Universe

local function isNonEmptyString(value)
	return type(value) == "string" and value ~= ""
end

--- @class Universe
--- @field uuid string
--- @field name string
--- @field workingDirectory string
--- @field tabpages Tabpage[]
--- @field buffers Buffer[]
--- @field currentTabpage Tabpage
--- @field addTabpage (Tabpage) -> nil
--- @field addAllTabpages (Tabpage[]) -> nil
--- @field addBuffer (Buffer) -> nil
--- @field addAllBuffers (Buffer[]) -> nil
--- @field getBufferById (number) -> Buffer
--- @field getBufferByUuid (string) -> Buffer

--- @param opts table
--- @param opts.uuid string  a unique identifier for the universe
--- @param opts.name string  the name of the universe
--- @param opts.workingDirectory string  the working directory of the universe
--- @return Universe
function Universe:new(opts)
	opts = opts or {}
	if type(opts) ~= "table" then
		error("Universe:new requires a table argument", 2)
	end
	if not isNonEmptyString(opts.uuid) then
		error("Universe:new requires opts.uuid to be a non-empty string", 2)
	end
	if not isNonEmptyString(opts.name) then
		error("Universe:new requires opts.name to be a non-empty string", 2)
	end
	if not isNonEmptyString(opts.workingDirectory) then
		error("Universe:new requires opts.workingDirectory to be a non-empty string", 2)
	end

	local self = setmetatable({}, Universe)
	self.uuid = opts.uuid
	self.name = opts.name
	self.workingDirectory = opts.workingDirectory
	self.currentTabpage = nil
	self.buffers = {}
	self.tabpages = {}
	return self
end

--- @param buffer Buffer
--- @return nil
function Universe:addBuffer(buffer)
	table.insert(self.buffers, buffer)
end

--- @param buffers Buffer[]
--- @return nil
function Universe:addAllBuffers(buffers)
	for _, buffer in pairs(buffers) do
		self:addBuffer(buffer)
	end
end

--- @param tabpage Tabpage
--- @return nil
function Universe:addTabpage(tabpage)
	table.insert(self.tabpages, tabpage)
end

--- @param tabpages Tabpage[]
--- @return nil
function Universe:addAllTabpages(tabpages)
	for _, tabpage in pairs(tabpages) do
		self:addTabpage(tabpage)
	end
end

--- @param bufferId number
function Universe:getBufferById(bufferId)
	for _, buffer in pairs(self.buffers) do
		if buffer.bufferId == bufferId then
			return buffer
		end
	end
	return nil
end

--- @param bufferUuid string
--- @return Buffer | nil
function Universe:getBufferByUuid(bufferUuid)
  for _, buffer in pairs(self.buffers) do
    if buffer.uuid == bufferUuid then
      return buffer
    end
  end
  return nil
end

--- @param windowId number
function Universe:getWindowById(windowId)
	for _, tabpage in pairs(self.tabpages) do
		for _, window in pairs(tabpage.windows) do
			if window.windowId == windowId then
				return window
			end
		end
	end
	return nil
end

return Universe
