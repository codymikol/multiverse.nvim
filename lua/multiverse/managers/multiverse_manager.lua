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
	local current_directory = vim.fn.getcwd()

	local current_universe_summary = multiverse:getUniverseByDirectory(current_directory)

	plugin_manager.beforeDehydrate()

	if current_universe_summary ~= nil then
		local dehydrated_universe = dehydration_manager.dehydrate(current_universe_summary)
		universe_repository.save_universe(dehydrated_universe)
	end

	plugin_manager.afterDehydrate()

	cleanup_manager.cleanup()

	plugin_manager.beforeHydrate()

	hydration_manager.hydrate(selected_universe)

	plugin_manager.afterHydrate()
end

return M
