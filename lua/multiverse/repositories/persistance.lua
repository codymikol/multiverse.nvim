local M = {}

M.getDir = function()
  return vim.fn.stdpath("data") .. "/workspace-persistance"
end

return M
