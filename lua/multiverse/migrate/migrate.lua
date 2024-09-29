-- Imagine being as lazy as I am

local workspaces_plugin = require("workspaces")

local workspaces = workspaces_plugin.get()

local test_workspace = workspaces[1]

local test_workspace_buffer_sha_256 = vim.fn.sha256(test_workspace.name)

vim.notify(vim.inspect(test_workspace_buffer))


-- vim.notify(workspaces[0])
