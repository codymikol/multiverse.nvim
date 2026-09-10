local M = {}

M.hydrate = function()
  if vim.fn.exists(":Neotree") ~= 2 then
    return
  end
  local cwd = vim.fn.getcwd()
  vim.cmd("Neotree " .. cwd)
end

return M
