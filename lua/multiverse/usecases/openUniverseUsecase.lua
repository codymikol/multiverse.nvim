local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local timestamp_manager = require("multiverse.managers.timestamp_manager")
local multiverse_manager = require("multiverse.managers.multiverse_manager")
local log = require("multiverse.log")
local M = {}

M.run = function(name)
	local success, err = pcall(function()
		local multiverse = multiverse_repository.getMultiverse()

    local universe_summary = multiverse:getUniverseByName(name)

    if nil == universe_summary then
      vim.notify("Universe with name '" .. name .. "' not found.", vim.log.levels.INFO)
      return
    end

    universe_summary.lastExplored = timestamp_manager.now()
    vim.notify("Updating last explored for universe '" .. name .. "' to " .. universe_summary.lastExplored)
    multiverse_repository.save_multiverse(multiverse)
    multiverse_manager.load_universe(multiverse, universe_summary)

	end)
	if not success then
		vim.notify("Failed to open universe, check MultiverseLog for more information", vim.log.levels.ERROR)
		log.error("Error opening universe: " .. vim.inspect(err))
	end
end

return M
