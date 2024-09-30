local Plugin = {}
Plugin.__index = Plugin

--- @class Plugin
--- @field name string
--- @field context PluginContext

--- @param ctx PluginContext
--- @return Plugin
function Plugin:new(ctx)
	local self = setmetatable({}, Plugin)
	self.context = ctx
	return self
end

return Plugin
