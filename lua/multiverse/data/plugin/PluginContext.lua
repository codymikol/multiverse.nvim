local PluginContext = {}
PluginContext.__index = PluginContext

--- @class PluginContext
--- @field beforeDehydrate fun(): nil
--- @field afterDehydrate fun(): nil
--- @field beforeHydrate fun(): nil
--- @field afterHydrate fun(): nil

--- @return PluginContext
function PluginContext:new()
	local self = setmetatable({}, PluginContext)
	return self
end

return PluginContext
