local PluginContext = require("multiverse.data.plugin.PluginContext")

local Plugin = {}
Plugin.__index = Plugin

--- @class Plugin
--- @field name string
--- @field context PluginContext

--- @param ctx table
--- @return Plugin|nil
function Plugin:new(ctx)
	local context = PluginContext:new(ctx)

	if not context then
		return nil
	end

	local self = setmetatable({}, Plugin)
	self.name = context.name
	self.context = context
	return self
end

return Plugin
