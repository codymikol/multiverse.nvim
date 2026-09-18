local M = {}

local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local multiverse_manager = require("multiverse.managers.multiverse_manager")
local universe_repository = require("multiverse.repositories.universe_repository")
local uuid_manager = require("multiverse.managers.uuid_manager")
local timestamp_manager = require("multiverse.managers.timestamp_manager")
local UniverseSummary = require("multiverse.data.UniverseSummary")
local Universe = require("multiverse.data.Universe")
local log = require("multiverse.log")

local function normalizeDirectory(directory)
	-- vim.fn.expand executes backtick-quoted shell commands (injection risk); vim.fs.normalize does not.
	local expanded = vim.fs.normalize(directory)
	local trailing_slash_removed = string.gsub(expanded, "/$", "")
	return trailing_slash_removed
end

---@param name string
---@param directory string
M.run = function(name, directory)
	local success, err = pcall(function()
		local seconds_since_epoch = timestamp_manager.now()

		local normalized_directory = normalizeDirectory(directory)

		local new_uuid = uuid_manager.create()

		local multiverse = multiverse_repository.getMultiverse()

		local existing_universe = multiverse:getUniverseByDirectory(normalized_directory)

		if nil ~= existing_universe then
			vim.notify("Universe already exists with that directory under the name: " .. existing_universe.name)
			return
		end

		local new_universe_summary = UniverseSummary:new({
			directory = normalized_directory,
			uuid = new_uuid,
			name = name,
			lastExplored = seconds_since_epoch,
		})

		log.debug("Adding a new universe: %s", new_universe_summary)

		multiverse:addUniverse(new_universe_summary)

		multiverse_repository.save_multiverse(multiverse)

		local new_universe = Universe:new(new_uuid, name, normalized_directory)

		universe_repository.save_universe(new_universe)

		-- Adding a universe for the CURRENT directory needs an explicit save
		-- here: load_universe's same-uuid skip (#313) would otherwise treat
		-- the still-empty file above as this universe's real session and
		-- never capture the currently-open buffers into it.
		if normalized_directory == vim.fn.getcwd() then
			multiverse_manager.save()
		end

		multiverse_manager.load_universe(multiverse, new_universe_summary)
	end)
  if not success then
    vim.notify("Failed to add new universe, check MultiverseLog for more information", vim.log.levels.ERROR)
    log.error("Error adding new universe: %s", err)
  end
end

return M
