local M = {}

local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local universe_repository = require("multiverse.repositories.universe_repository")
local zellij_manager = require("multiverse.managers.zellij_manager")
local log = require("multiverse.log")

M.run = function(name)
	local success, err = pcall(function()
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

		-- Deletes the orphaned zellij-open-<hash> flag file this universe's
		-- directory is keyed to. Unconditional, not behind is_available(): it's a
		-- plain file delete with no zellij binary dependency.
		zellij_manager.mark_closed(zellij_manager.session_name_for(universe.directory))
	end)
	if not success then
		vim.notify("Failed to remove universe, check MultiverseLog for more information", vim.log.levels.ERROR)
		log.error("Error removing universe: " .. vim.inspect(err))
	end
end

return M
