local Workspaces = require("integrations.workspaces")
local Listeners = require("multiverse.listeners")
local cli = require("multiverse.managers.cli_manager")

local Multiverse = {}

Multiverse.setup = function(config)
	-- Workspaces.registerHooks()
	-- Listeners.register()
  cli.registerCommands()
end

return Multiverse
