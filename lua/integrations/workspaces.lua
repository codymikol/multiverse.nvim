local WorkspaceManager = require("multiverse.multiverse")

local M = {}

M.registerHooks = function()
	local workspaces = require("workspaces")

	workspaces.setup({
		hooks = {
			open_pre = {
				WorkspaceManager.save,
				WorkspaceManager.clear,
			},
			open = {
				WorkspaceManager.hydrate,
			},
		},
	})
end

return M
