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
--- @param beforeDehydrateContext BeforeDehydrateContext
--- @return nil
M.beforeDehydrate = function(beforeDehydrateContext)
	for _, plugin in ipairs(plugins) do
		if plugin.context.beforeDehydrate then
			plugin.context.beforeDehydrate(beforeDehydrateContext)
		end
	end
end

--- `afterDehydrate` is the second lifecycle event called. This is called after the state of the universe
--- is saved into persistence.
--- @param afterDehydrateContext AfterDehydrateContext
--- @return nil
M.afterDehydrate = function(afterDehydrateContext)
	for _, plugin in ipairs(plugins) do
		if plugin.context.afterDehydrate then
			plugin.context.afterDehydrate(afterDehydrateContext)
		end
	end
end

--- The third lifecycle event called. This is called after all tabpages, windows, and buffers
--- have been purged, and the universe is about to be hydrated. This can be used to prepare any resources that
--- may need to be rendered in the universe.
--- @param beforeHydrateContext BeforeHydrateContext
--- @return nil
M.beforeHydrate = function(beforeHydrateContext)
	for _, plugin in ipairs(plugins) do
		if plugin.context.beforeHydrate then
			plugin.context.beforeHydrate(beforeHydrateContext)
		end
	end
end

--- The final lifecycle event called. This is called after the universe has been hydrated.
--- This can be used to interact with the now existing tabpages, windows, and buffers.
--- @param afterHydrateContext AfterHydrateContext
--- @return nil
M.afterHydrate = function(afterHydrateContext)
	for _, plugin in ipairs(plugins) do
		if plugin.context.afterHydrate then
			plugin.context.afterHydrate(afterHydrateContext)
		end
	end
end

return M
