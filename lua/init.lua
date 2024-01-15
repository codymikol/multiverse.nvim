local M = {}

M.setup = function()
	local WorkspacesIntegration = require("integrations.workspaces")
	WorkspacesIntegration.registerHooks()
end

return M
