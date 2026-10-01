local NeoTreePlugin = require("plugins.neotree_plugin")
local CopilotChatPlugin = require("plugins.copilot_chat_plugin")
local ZellijPlugin = require("plugins.zellij_plugin")
local TitleSyncPlugin = require("plugins.title_sync_plugin")
local log = require("multiverse.log")

local M = {}

--- This plugin registration system allows users to register their own plugins that
--- have lifecycle hooks.

--- @type Plugin[] this is a list of out of the box plugins that are supported by default.
local plugins = {
	NeoTreePlugin,
	ZellijPlugin,
	TitleSyncPlugin,
}

--- Priority used for a plugin that doesn't declare a numeric `priority`. Lower priority
--- values run earlier. This matches the built-in plugins' own (implicit) priority tier,
--- so unprioritized user plugins run after all built-ins by default.
local DEFAULT_PRIORITY = 100

--- @param plugin Plugin
--- @return number
local function effective_priority(plugin)
	if type(plugin.priority) == "number" then
		return plugin.priority
	end

	return DEFAULT_PRIORITY
end

--- @param plugin Plugin|nil --- The plugin to register and handle lifecycle events with.
--- @return nil
M.register = function(plugin)
	if not plugin then
		return
	end

	local new_priority = effective_priority(plugin)

	if plugin.name ~= nil then
		for i, p in ipairs(plugins) do
			if p.name ~= nil and p.name == plugin.name then
				log.debug("Replacing existing registration for plugin %s", plugin.name)
				if effective_priority(p) == new_priority then
					-- Same priority: keep its current slot instead of moving it to the
					-- end of its priority tier (e.g. overriding a built-in plugin's hooks).
					plugins[i] = plugin
					return
				end
				table.remove(plugins, i)
				break
			end
		end
	end

	for i, p in ipairs(plugins) do
		if effective_priority(p) > new_priority then
			table.insert(plugins, i, plugin)
			return
		end
	end

	table.insert(plugins, plugin)
end

--- Runs `hookName` on every registered plugin that defines it, isolating each call in its
--- own pcall so a throwing plugin hook can't skip later plugins or abort the caller.
--- @param hookName string
--- @param ctx table
--- @return nil
local function dispatch_hook(hookName, ctx)
	-- Snapshot before iterating: a hook can register a new plugin mid-dispatch, and
	-- `M.register`'s mid-list insert/remove would otherwise shift indices out from under
	-- a live `ipairs(plugins)` loop, causing a plugin to run twice or be skipped. Any
	-- registration made during this dispatch takes effect starting next time, not here.
	local snapshot = vim.list_slice(plugins)

	for _, plugin in ipairs(snapshot) do
		local hook = plugin.context[hookName]
		if hook then
			local success, err = pcall(hook, ctx)
			if not success then
				log.error("Error running %s hook for plugin %s: %s", hookName, plugin.name, err)
			end
		end
	end
end

--- The first lifecycle event called. This is called before the state of the universe
--- is saved into persistence. Here when required is a good time to drive the related plugin to saves its own
--- state, or clean up any resources.
--- @param beforeDehydrateContext BeforeDehydrateContext
--- @return nil
M.beforeDehydrate = function(beforeDehydrateContext)
	dispatch_hook("beforeDehydrate", beforeDehydrateContext)
end

--- `afterDehydrate` is the second lifecycle event called. This is called after the state of the universe
--- is saved into persistence.
--- @param afterDehydrateContext AfterDehydrateContext
--- @return nil
M.afterDehydrate = function(afterDehydrateContext)
	dispatch_hook("afterDehydrate", afterDehydrateContext)
end

--- The third lifecycle event called. This is called after all tabpages, windows, and buffers
--- have been purged, and the universe is about to be hydrated. This can be used to prepare any resources that
--- may need to be rendered in the universe.
--- @param beforeHydrateContext BeforeHydrateContext
--- @return nil
M.beforeHydrate = function(beforeHydrateContext)
	dispatch_hook("beforeHydrate", beforeHydrateContext)
end

--- The final lifecycle event called. This is called after the universe has been hydrated.
--- This can be used to interact with the now existing tabpages, windows, and buffers.
--- @param afterHydrateContext AfterHydrateContext
--- @return nil
M.afterHydrate = function(afterHydrateContext)
	dispatch_hook("afterHydrate", afterHydrateContext)
end

return M
