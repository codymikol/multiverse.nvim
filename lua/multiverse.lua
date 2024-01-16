local Workspaces = require("integrations.workspaces")
local Multiverse = {}

Multiverse.setup = function(config)
	config = config or {} -- todo: do I need this for LazyVim to recognize this?
	Workspaces.registerHooks()
end

return Multiverse
