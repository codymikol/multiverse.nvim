local M = {}

M.setup = function(opts)
	opts = opts or {} -- todo: do I need this for LazyVim to recognize this?
	local WorkspacesIntegration = require("integrations.workspaces")
	WorkspacesIntegration.registerHooks()
end

return M
