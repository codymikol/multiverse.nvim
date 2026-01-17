local M = {}

local telescope_integration = require("integrations.telescope")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local multiverse_manager = require("multiverse.managers.multiverse_manager")
local log = require("multiverse.log")


M.run = function()
	local success, err = pcall(function()

		local multiverse = multiverse_repository.getMultiverse()

		if #multiverse.universes == 0 then
			vim.notify(
				"You don't have any universes to explore!\nTry adding a universe with MultiverseAdd <name> <directory>"
			)
			return
		end

    table.sort(multiverse.universes, function(a, b)
      return a.lastExplored > b.lastExplored
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
	if not success then
		vim.notify("Failed to open universe, check MultiverseLog for more information", vim.log.levels.ERROR)
		log.error("Error opening universe: " .. vim.inspect(err))
	end
end

return M
