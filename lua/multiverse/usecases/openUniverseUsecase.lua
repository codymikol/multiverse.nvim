local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local timestamp_manager = require("multiverse.managers.timestamp_manager")
local multiverse_manager = require("multiverse.managers.multiverse_manager")
local log = require("multiverse.log")
local M = {}

M.run = function(name)
	local success, err = pcall(function()
		local multiverse = multiverse_repository.getMultiverse()

		for _, universe_summary in ipairs(multiverse.universes) do
			if universe_summary.name == name then
				universe_summary.lastExplored = timestamp_manager.now()
				multiverse_repository.save_multiverse(multiverse)
				multiverse_manager.load_universe(multiverse, universe_summary)
				return
			end
		end

		vim.notify("Universe with name '" .. name .. "' not found.", vim.log.levels.INFO)
	end)
	if not success then
		vim.notify("Failed to open universe, check MultiverseLog for more information", vim.log.levels.ERROR)
		log.error("Error opening universe: " .. vim.inspect(err))
	end
end

return M
