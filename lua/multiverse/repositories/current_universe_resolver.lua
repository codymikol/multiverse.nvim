local M = {}

local multiverse_repository = require("multiverse.repositories.multiverse_repository")

--- @return UniverseSummary | nil
M.resolve_current_universe_summary = function()
  local multiverse = multiverse_repository.getMultiverse()
  if multiverse == nil then
    return nil
  end

  local cwd = vim.fn.getcwd()

  local summary = multiverse:getUniverseByDirectory(cwd)
  if summary == nil then
    summary = multiverse:getUniverseByDirectory(cwd .. "/")
  end

  return summary
end

return M
