local Workspace = require("multiverse.managers.workspace_manager")

local M = {}

M.registerHooks = function()
  local workspaces = require("workspaces")

  workspaces.setup({
    hooks = {
      open_pre = {
        Workspace.save,
        Workspace.clear,
      },
      open = {
        Workspace.hydrate,
      },
    },
  })
end

return M
