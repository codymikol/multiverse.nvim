local universe_repository = require "multiverse.repositories.universe_repository"
local M = {}

---@param selected_universe UniverseSummary
M.hydrate = function(selected_universe)

  local _, universe = universe_repository.getUniverseByUuid(selected_universe.uuid)

  if universe == nil then
    vim.notify("Universe not found")
    return
  end

  vim.notify("Universe found " .. vim.inspect(universe))

  

end

return M

-- todo(mikol): Open a new tabpage for each tabpage in the universe.
-- todo(mikol): Open a new window for each window in each tabpage.
-- todo(mikol): Open a new buffer for each buffer in each window.
