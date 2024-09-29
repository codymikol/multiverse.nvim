local M = {}

local dehydration_manager = require "multiverse.managers.dehydration_manager"
local json = require("multiverse.repositories.json")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local universe_repository = require("multiverse.repositories.universe_repository")
local Universe = require("multiverse.data.Universe")
local UniverseSummary = require("multiverse.data.UniverseSummary")

-- todo(mikol): get the unique id of this multiverse from the workspaces list
-- todo(mikol): update the json representation of this multiverse in the represented by miniverse_${workspace_uuid}

M.save_muliverse = function()

  -- local universe_uuid = selected_universe.uuid

  local universe = dehydration_manager.dehydrate()

  local universe_json = json.encode(universe)

end

M.add_new_universe = function(name, directory)

  local uuid = vim.fn.uuid()

  local multiverse = multiverse_repository.getMultiverse()

  local current_utc_timestamp = os.time(os.date("!*t"))

  local universe_summary = UniverseSummary:new(
    current_utc_timestamp,
    name,
    directory
  )

  table.insert(multiverse.universes, universe_summary)

  multiverse_repository.saveMultiverse(multiverse)

  local universe = Universe:new(
    universe_summary.name,
    universe_summary.directory
  )

  universe_repository.addUniverse(universe)

end

M.save_muliverse()

return M
