local M = {}

local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local universe_repository = require("multiverse.repositories.universe_repository")
local hydration_manager = require("multiverse.managers.hydration_manager")
local uuid_manager = require("multiverse.managers.uuid_manager")
local UniverseSummary = require("multiverse.data.UniverseSummary")
local Universe = require("multiverse.data.Universe")

local function normalizeDirectory(directory)
	local expanded = vim.fn.expand(directory)
	local trailing_slash_removed = string.gsub(expanded, "/$", "")
	return trailing_slash_removed
end

---@param name string
---@param directory string
M.run = function(name, directory)
	local seconds_since_epoch = os.time(os.date("!*t"))

	local normalized_directory = normalizeDirectory(directory)

	local new_uuid = uuid_manager.create()

	local multiverse = multiverse_repository.getMultiverse()

	local existing_universe = multiverse:getUniverseByDirectory(normalized_directory)

	if nil ~= existing_universe then
		vim.notify("Universe already exists with that directory under the name: " .. existing_universe.name)
		return
	end

	local new_universe = UniverseSummary:new(normalized_directory, new_uuid, name, seconds_since_epoch)

	print("Adding a new universe ." .. vim.inspect(new_universe))

	multiverse:addUniverse(new_universe)

	multiverse_repository.save_multiverse(multiverse)

	local new_universe = Universe:new(new_uuid, name, normalized_directory)

	universe_repository.save_universe(new_universe)

	hydration_manager.hydrate(new_universe)
end

return M
