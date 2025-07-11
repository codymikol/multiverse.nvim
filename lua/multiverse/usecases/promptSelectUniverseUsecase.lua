local M = {}

local telescope_integration = require("integrations.telescope")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local multiverse_manager = require("multiverse.managers.multiverse_manager")

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

		multiverse_manager.load_universe(multiverse, selected_universe)
	end)
end

return M
