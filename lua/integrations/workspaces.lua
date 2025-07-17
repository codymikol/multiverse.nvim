local Workspace = require("multiverse.managers.workspace_manager")

local M = {}

  local function deprecation_warning()
    vim.notify(
      "The integration with workspaces.nvim is deprecated and will be removed in a future version, please use the MultiverseList, command instead.",
      vim.log.levels.WARN
    )
  end

M.registerHooks = function()
  local workspaces = require("workspaces")

workspaces.setup({
    hooks = {
      open_pre = {
        Workspace.save,
        Workspace.clear,
        deprecation_warning,
      },
      open = {
        Workspace.hydrate,
      },
    },
  })
end

return M
