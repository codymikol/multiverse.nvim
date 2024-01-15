local M = {}

M.hydrate = function()
  local cwd = vim.fn.getcwd()
  vim.cmd("Neotree " .. cwd)
end

return M
