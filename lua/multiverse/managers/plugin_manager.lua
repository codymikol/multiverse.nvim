local NeoTreePlugin = require("plugins.neotree_plugin")
local Plugin = require("multiverse.data.plugin.Plugin")

local M = {}

--- This plugin registration system allows users to register their own plugins that
--- have lifecycle hooks.

--- @type Plugin[] this is a list of out of the box plugins that are supported by default.
local plugins = {
	NeoTreePlugin,
}

--- @param plugin PluginContext --- The plugin to register and handle lifecycle events with.
--- @return nil
M.register = function(plugin)
	table.insert(plugins, plugin)
end

--- The first lifecycle event called. This is called before the state of the universe
--- is saved into persistence. Here when required is a good time to drive the related plugin to saves its own
--- state, or clean up any resources.
--- @return nil
M.beforeDehydrate = function()
	for _, plugin in ipairs(plugins) do
		if plugin.context.beforeDehydrate then
			plugin.context.beforeDehydrate()
		end
	end
end

--- `afterDehydrate` is the second lifecycle event called. This is called after the state of the universe
--- is saved into persistence.
--- @return nil
M.afterDehydrate = function()
	for _, plugin in ipairs(plugins) do
		if plugin.context.afterDehydrate then
			plugin.context.afterDehydrate()
		end
	end
end

--- The third lifecycle event called. This is called after all tabpages, windows, and buffers
--- have been purged, and the universe is about to be hydrated. This can be used to prepare any resources that
--- may need to be rendered in the universe.
M.beforeHydrate = function()
	for _, plugin in ipairs(plugins) do
		if plugin.context.beforeHydrate then
			plugin.context.beforeHydrate()
		end
	end
end

--- The final lifecycle event called. This is called after the universe has been hydrated.
--- This can be used to interact with the now existing tabpages, windows, and buffers.
M.afterHydrate = function()
	for _, plugin in ipairs(plugins) do
		if plugin.context.afterHydrate then
			plugin.context.afterHydrate()
		end
	end
end

return M
