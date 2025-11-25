
local M = {}

M.STATES = {
  DEHYDRATION = "DEHYDRATION",
  CLEANUP = "CLEANUP",
  HYDRATION = "HYDRATION",
  IDLE = "IDLE",
}

local current_state = M.STATES.IDLE

M.get_current_state = function()
  return current_state
end

M.set_current_state = function(state)
  if not vim.tbl_contains(vim.tbl_values(M.STATES), state) then
    error("Invalid state: " .. tostring(state))
  end
  current_state = state
end

return M
