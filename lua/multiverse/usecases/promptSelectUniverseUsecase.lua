local M = {}

local telescope_integration = require("integrations.telescope")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local universe_repository = require("multiverse.repositories.universe_repository")
local hydration_manager = require("multiverse.managers.hydration_manager")
local dehydration_manager = require("multiverse.managers.dehydration_manager")
local cleanup_manager = require("multiverse.managers.cleanup_manager")

M.run = function()
	local multiverse = multiverse_repository.getMultiverse()

	if #multiverse.universes == 0 then
		vim.notify(
			"You don't have any universes to explore!\nTry adding a universe with MultiverseAdd <name> <directory>"
		)
		return
	end

	telescope_integration.prompt_select_universe(multiverse.universes, function(selected_universe)
		if selected_universe == nil then
			vim.notify("Error: No universe was returned by telescope.")
			return
		end

		local current_directory = vim.fn.getcwd()

		local current_universe_summary = multiverse:getUniverseByDirectory(current_directory)

		vim.cmd("Neotree close") -- This must happen prior to dehydration `beforeDehyrate`...

		if current_universe_summary ~= nil then
			local dehydrated_universe = dehydration_manager.dehydrate(current_universe_summary)
			universe_repository.save_universe(dehydrated_universe)
		end

		cleanup_manager.cleanup()

		hydration_manager.hydrate(selected_universe)
	end)
end

return M
