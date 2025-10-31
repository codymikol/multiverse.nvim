local M = {}

local current_universe = nil

M.get_current_universe = function()
  return vim.g.multiverse_current_universe
end

M.set_current_universe = function(universe)
  vim.g.multiverse_current_universe = universe
end

M.in_universe = function()
  return M.get_current_universe() ~= nil
end

return M
