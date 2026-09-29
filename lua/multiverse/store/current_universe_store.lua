local M = {}

--- @return string | nil  the name of the currently active universe, if any
M.get_current_universe = function()
  return vim.g.multiverse_current_universe
end

--- @param name string  the name of the universe to mark as currently active
M.set_current_universe = function(name)
  vim.g.multiverse_current_universe = name
end

M.in_universe = function()
  return M.get_current_universe() ~= nil
end

--- @return string | nil  the name of the universe that was active before the current one, if any
M.get_previous_universe = function()
  return vim.g.multiverse_previous_universe
end

--- @param name string  the name of the universe to remember as previously active
M.set_previous_universe = function(name)
  vim.g.multiverse_previous_universe = name
end

return M
