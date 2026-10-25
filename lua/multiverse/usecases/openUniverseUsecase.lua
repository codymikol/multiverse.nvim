local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local multiverse_manager = require("multiverse.managers.multiverse_manager")
local usecases_helper = require("multiverse.usecases.usecases_helper")
local M = {}

M.run = function(name)
	usecases_helper.run_safely("open universe", "opening universe", function()
		local multiverse = multiverse_repository.getMultiverse()

    local universe_summary = multiverse:getUniverseByName(name)

    if nil == universe_summary then
      vim.notify("Universe with name '" .. name .. "' not found.", vim.log.levels.INFO)
      return
    end

    multiverse_manager.load_universe(multiverse, universe_summary)

	end)
end

return M
