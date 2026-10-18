-- Integration test for GitHub issue #274 (slice 1): proves the "creating a
-- universe" flow works end-to-end against the real filesystem, rather than
-- against stubbed repositories (see addNewUniverseUsecase_spec.lua for the
-- stubbed unit-test coverage of the same usecase).

local persistance_module_name = "multiverse.repositories.persistance"
local usecase_module_name = "multiverse.usecases.addNewUniverseUsecase"

local json = require("multiverse.repositories.json")

-- multiverse_manager, universe_repository, and hydration_manager (all
-- required transitively by addNewUniverseUsecase) keep their own references
-- to whatever multiverse_repository (and other multiverse.* modules) were
-- loaded at their own require-time. Clearing only
-- multiverse.repositories.multiverse_repository and the usecase itself would
-- leave those other modules holding stale module tables/caches, so a second
-- `it()` block would silently exercise a stale module graph. Evict
-- everything under the `multiverse.` namespace instead, so each test gets a
-- fully fresh module graph.
local function evict_multiverse_modules()
	for module_name in pairs(package.loaded) do
		if module_name:match("^multiverse%.") then
			package.loaded[module_name] = nil
		end
	end
end

describe("create universe (integration)", function()
	local persistance
	local original_cwd
	local persistance_dir
	local universe_directory
	local addNewUniverseUsecase

	local neotree_plugin
	local original_neotree_beforeDehydrate
	local original_neotree_afterHydrate

	before_each(function()
		original_cwd = vim.fn.getcwd()

		persistance_dir = vim.fn.tempname()
		vim.fn.mkdir(persistance_dir, "p")

		universe_directory = vim.fn.tempname()
		vim.fn.mkdir(universe_directory, "p")
		local expanded = vim.fs.normalize(universe_directory)
		universe_directory = (expanded:gsub("/$", ""))

		-- Evict the whole multiverse.* module graph before (re-)requiring
		-- persistance so the getDir monkeypatch below lands on the exact
		-- module table addNewUniverseUsecase's dependencies will resolve to,
		-- rather than a stale copy the monkeypatch never reaches.
		evict_multiverse_modules()
		persistance = require(persistance_module_name)
		persistance.getDir = function()
			return persistance_dir
		end

		-- Stub out the Neotree plugin hooks so afterHydrate doesn't attempt to
		-- run `:Neotree ...` ex commands, which don't exist in this test's
		-- minimal config (see support.lua's M.setup() for the same stub, used
		-- by the headless integration scripts for the same reason).
		neotree_plugin = require("plugins.neotree_plugin")
		original_neotree_beforeDehydrate = neotree_plugin.context.beforeDehydrate
		original_neotree_afterHydrate = neotree_plugin.context.afterHydrate
		neotree_plugin.context.beforeDehydrate = function() end
		neotree_plugin.context.afterHydrate = function() end

		addNewUniverseUsecase = require(usecase_module_name)
	end)

	after_each(function()
		-- addNewUniverseUsecase.run() -> multiverse_manager.load_universe() ->
		-- hydration_manager.hydrate() runs `:cd <universe_directory>`, so the
		-- process cwd must be restored before universe_directory is deleted
		-- out from under it.
		vim.api.nvim_command("cd " .. vim.fn.fnameescape(original_cwd))

		neotree_plugin.context.beforeDehydrate = original_neotree_beforeDehydrate
		neotree_plugin.context.afterHydrate = original_neotree_afterHydrate

		vim.fn.delete(persistance_dir, "rf")
		vim.fn.delete(universe_directory, "rf")

		evict_multiverse_modules()
	end)

	it("persists a new universe's summary and full state to real JSON files on disk", function()
		addNewUniverseUsecase.run("my-new-universe", universe_directory)

		local multiverse_path = persistance_dir .. "/multiverse.json"
		local multiverse_file = io.open(multiverse_path, "r")
		assert.is_not_nil(multiverse_file, "expected multiverse.json to exist at " .. multiverse_path)
		local multiverse_json = json.decode(multiverse_file:read("*a"))
		multiverse_file:close()

		assert.are.equal(1, #multiverse_json.universes)
		local summary = multiverse_json.universes[1]
		assert.are.equal("my-new-universe", summary.name)
		assert.are.equal(universe_directory, summary.directory)
		assert.is_not_nil(summary.uuid)

		local universe_path = persistance_dir .. "/universe-" .. summary.uuid .. ".json"
		local universe_file = io.open(universe_path, "r")
		assert.is_not_nil(universe_file, "expected universe-<uuid>.json to exist at " .. universe_path)
		local universe_json = json.decode(universe_file:read("*a"))
		universe_file:close()

		assert.are.equal(summary.uuid, universe_json.uuid)
		assert.are.equal("my-new-universe", universe_json.name)
		assert.are.equal(universe_directory, universe_json.workingDirectory)
	end)
end)
