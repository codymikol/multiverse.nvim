local M = {}

local telescope_integration = require("integrations.telescope")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local multiverse_manager = require("multiverse.managers.multiverse_manager")
local log = require("multiverse.log")
local usecases_helper = require("multiverse.usecases.usecases_helper")


local function lastExplored(universe)
	return type(universe.lastExplored) == "number" and universe.lastExplored or 0
end

M.run = function()
	usecases_helper.run_safely("open universe", "opening universe", function()

		local multiverse = multiverse_repository.getMultiverse()

		if #multiverse.universes == 0 then
			vim.notify(
				"You don't have any universes to explore!\nTry adding a universe with MultiverseAdd <name> <directory>"
			)
			return
		end

		table.sort(multiverse.universes, function(a, b)
			return lastExplored(a) > lastExplored(b)
		end)

		telescope_integration.prompt_select_universe(multiverse.universes, function(selected_universe)
			if selected_universe == nil then
				log.error("No selected universe was returned by telescope.")
				return
			end

			log.debug("universe selected" .. selected_universe.directory)

			multiverse_manager.load_universe(multiverse, selected_universe)
		end)
	end)
end

return M
