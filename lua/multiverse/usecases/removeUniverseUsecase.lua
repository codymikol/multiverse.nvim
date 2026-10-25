local M = {}

local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local universe_repository = require("multiverse.repositories.universe_repository")
local usecases_helper = require("multiverse.usecases.usecases_helper")

M.run = function(name)
	usecases_helper.run_safely("remove universe", "removing universe", function()
		local multiverse = multiverse_repository.getMultiverse()

		local universe = multiverse:getUniverseByName(name)

		if universe == nil then
			vim.notify("Universe not found: " .. name, vim.log.levels.ERROR)
			return
		end

		local confirmed = vim.fn.confirm("Remove universe '" .. name .. "'? This cannot be undone.", "&Yes\n&No", 2)
		if confirmed ~= 1 then
			return
		end

		local ok, del_err = universe_repository.deleteUniverse(universe)
		if not ok then
			vim.notify(del_err, vim.log.levels.ERROR)
			return
		end

		multiverse:removeUniverse(name)

		multiverse_repository.save_multiverse(multiverse)
	end)
end

return M
