local M = {}

---@return number
M.now = function()
  return os.time(os.date("!*t"))
end

return M
