local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local multiverse_manager = require("multiverse.managers.multiverse_manager")
local current_universe_store = require("multiverse.store.current_universe_store")
local log = require("multiverse.log")
local M = {}

M.run = function()
	local success, err = pcall(function()
    local previous_name = current_universe_store.get_previous_universe()

    if nil == previous_name then
      vim.notify("No previous universe to alternate to.", vim.log.levels.INFO)
      return
    end

    local multiverse = multiverse_repository.getMultiverse()

    local universe_summary = multiverse:getUniverseByName(previous_name)

    if nil == universe_summary then
      vim.notify("Universe with name '" .. previous_name .. "' not found.", vim.log.levels.INFO)
      return
    end

    multiverse_manager.load_universe(multiverse, universe_summary)

	end)
	if not success then
		vim.notify("Failed to alternate universe, check MultiverseLog for more information", vim.log.levels.ERROR)
		log.error("Error alternating universe: " .. vim.inspect(err))
	end
end

return M
