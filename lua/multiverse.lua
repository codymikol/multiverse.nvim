local Workspaces = require("integrations.workspaces")
local Multiverse = {}

Multiverse.setup = function(config)
	Workspaces.registerHooks()
end

return Multiverse
