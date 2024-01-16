local Multiverse = {}

Multiverse.setup = function(config)
	config = config or {} -- todo: do I need this for LazyVim to recognize this?
	local WorkspacesIntegration = require("integrations.workspaces")
	WorkspacesIntegration.registerHooks()
end

return Multiverse
