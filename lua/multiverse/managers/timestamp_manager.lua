local M = {}

---@return number
M.now = function()
  return os.time()
end

return M
