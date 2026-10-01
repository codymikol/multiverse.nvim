local M = {}

local multiverse_repository = require("multiverse.repositories.multiverse_repository")

--- @return UniverseSummary | nil
M.resolve_current_universe_summary = function(cwd)
  local multiverse = multiverse_repository.getMultiverse()
  if multiverse == nil then
    return nil
  end

  local summary = multiverse:getUniverseByDirectory(cwd)
  if summary == nil then
    summary = multiverse:getUniverseByDirectory(cwd .. "/")
  end

  return summary
end

return M
