local M = {}

local timestamp_manager = require("multiverse.managers.timestamp_manager")
local Universe = require("multiverse.data.Universe")
local UniverseSummary = require("multiverse.data.UniverseSummary")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local universe_repository = require("multiverse.repositories.universe_repository")
local hydration_manager = require("multiverse.managers.hydration_manager")
local dehydration_manager = require("multiverse.managers.dehydration_manager")
local cleanup_manager = require("multiverse.managers.cleanup_manager")
local plugin_manager = require("multiverse.managers.plugin_manager")
local log            = require("multiverse.log")

-- We need to not save data from triggers while we are loading a multiverse.
local is_loading_multiverse = false

M.save = function()

  if is_loading_multiverse then
    vim.notify("Cannot save while loading a multiverse.")
    return
  end

  local multiverse = multiverse_repository.getMultiverse()

	local current_directory = vim.fn.getcwd()

  local current_multiverse_summary = multiverse:getUniverseByDirectory(current_directory)
  if current_multiverse_summary == nil then
    current_multiverse_summary = multiverse:getUniverseByDirectory(current_directory .. "/")
  end

  if current_multiverse_summary == nil then
    vim.notify("No universe found for current directory: " .. current_directory)
    return
  end

	local current_universe_summary = multiverse:getUniverseByDirectory(current_directory)

	if current_universe_summary ~= nil then
		local dehydrated_universe = dehydration_manager.dehydrate(current_universe_summary)
		universe_repository.save_universe(dehydrated_universe)
	end

end

M.add_new_universe = function(name, directory)
	local multiverse = multiverse_repository.getMultiverse()

	local current_utc_timestamp = timestamp_manager.now()

	local universe_summary = UniverseSummary:new(current_utc_timestamp, name, directory)

	table.insert(multiverse.universes, universe_summary)

	multiverse_repository.saveMultiverse(multiverse)

	local universe = Universe:new(universe_summary.name, universe_summary.directory)

	universe_repository.addUniverse(universe)
end

--- @param multiverse Multiverse
--- @param selected_universe UniverseSummary
M.load_universe = function(multiverse, selected_universe)

  log.debug("Loading universe: " .. selected_universe.name)

  is_loading_multiverse = true

  local success, _ = pcall(function()

    local current_directory = vim.fn.getcwd()

    log.debug("load universe current directory: " .. current_directory)

    local current_universe_summary = multiverse:getUniverseByDirectory(current_directory)

    log.debug("load universe searching multiverse for matching directory and found: " .. vim.inspect(current_universe_summary))

    plugin_manager.beforeDehydrate()

    if current_universe_summary ~= nil then

      log.debug("Working directory is part of a universe, proceeding with dehydration.")

      if current_universe_summary ~= nil then
        local dehydrated_universe = dehydration_manager.dehydrate(current_universe_summary)
        log.debug("Dehydrated universe successfully, now saving.")
        universe_repository.save_universe(dehydrated_universe)
      end

    else
      log.debug("Working directory is not part of a universe, proceeding with loading the selected universe and skipping dehydration.")
    end

    plugin_manager.afterDehydrate()

    cleanup_manager.cleanup()

    plugin_manager.beforeHydrate()

    hydration_manager.hydrate(selected_universe)

    plugin_manager.afterHydrate()

  end)

  if not success then
    vim.notify("Error loading universe: " .. selected_universe.name, vim.log.levels.ERROR)
  end

  is_loading_multiverse = false

end

return M
