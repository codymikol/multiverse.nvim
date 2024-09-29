local M = {}

local Multiverse = require("multiverse.data.Multiverse")
local UniverseSummary = require("multiverse.data.UniverseSummary")
local json = require("multiverse.repositories.json")

---@param jsonString string
---@return Multiverse
M.make = function (jsonString)

  local multiverse_json = json.decode(jsonString)

  local multiverse = Multiverse:new({})

  for _, universe_json in pairs(multiverse_json.universes) do

   local universeSummary = UniverseSummary:new(
      universe_json.directory,
      universe_json.uuid,
      universe_json.name,
      universe_json.lastExplored
    )

    multiverse:addUniverse(universeSummary)

  end

  return multiverse

end

return M
