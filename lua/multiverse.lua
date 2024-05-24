local Workspaces = require("integrations.workspaces")
local Listeners = require("multiverse.listeners")
local Multiverse = {}

Multiverse.setup = function(config)
	Workspaces.registerHooks()
	Listeners.register()
end

return Multiverse
