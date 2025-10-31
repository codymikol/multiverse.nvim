local M = {}

local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local multiverse_manager = require("multiverse.managers.multiverse_manager")
local universe_repository = require("multiverse.repositories.universe_repository")
local uuid_manager = require("multiverse.managers.uuid_manager")
local UniverseSummary = require("multiverse.data.UniverseSummary")
local Universe = require("multiverse.data.Universe")
local log = require("multiverse.log")

local function normalizeDirectory(directory)
	local expanded = vim.fn.expand(directory)
	local trailing_slash_removed = string.gsub(expanded, "/$", "")
	return trailing_slash_removed
end

---@param name string
---@param directory string
M.run = function(name, directory)
	local success, err = pcall(function()
		local seconds_since_epoch = os.time(os.date("!*t"))

		local normalized_directory = normalizeDirectory(directory)

		local new_uuid = uuid_manager.create()

		local multiverse = multiverse_repository.getMultiverse()

		local existing_universe = multiverse:getUniverseByDirectory(normalized_directory)

		if nil ~= existing_universe then
			vim.notify("Universe already exists with that directory under the name: " .. existing_universe.name)
			return
		end

		local new_universe_summary = UniverseSummary:new(normalized_directory, new_uuid, name, seconds_since_epoch)

		print("Adding a new universe ." .. vim.inspect(new_universe_summary))

		multiverse:addUniverse(new_universe_summary)

		multiverse_repository.save_multiverse(multiverse)

		local new_universe = Universe:new(new_uuid, name, normalized_directory)

		universe_repository.save_universe(new_universe)

		multiverse_manager.load_universe(multiverse, new_universe_summary)
	end)
  if not success then
    vim.notify("Failed to add new universe, check MultiverseLog for more information", vim.log.levels.ERROR)
    log.error("Error adding new universe: " .. vim.inspect(err))
  end
end

return M
