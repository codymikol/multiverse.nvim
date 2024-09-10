local M = {}

local json = require("multiverse.repositories.json")
local UniverseSummary = require("multiverse.data.UniverseSummary")

--- @param data string
--- @return UniverseSummary
M.make = function(data)

  local universeSummaryJson = json.decode(data)

  local universe = UniverseSummary.new(
    universeSummaryJson.uuid,
    universeSummaryJson.name,
    universeSummaryJson.lastExplored
  )

  return universe

end

return M
