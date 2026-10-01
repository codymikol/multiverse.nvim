local M = {}

M.component = function()
  return require("multiverse").status()
end

return M
