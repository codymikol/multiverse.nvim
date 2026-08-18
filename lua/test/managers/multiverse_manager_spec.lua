local stub = require("luassert.stub")

local multiverse_manager = require("multiverse.managers.multiverse_manager")
local plugin_manager = require("multiverse.managers.plugin_manager")
local universe_repository = require("multiverse.repositories.universe_repository")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local hydration_manager = require("multiverse.managers.hydration_manager")
local cleanup_manager = require("multiverse.managers.cleanup_manager")
local Multiverse = require("multiverse.data.Multiverse")
local UniverseSummary = require("multiverse.data.UniverseSummary")

describe("multiverse_manager.load_universe", function()
	local save_multiverse_stub
	local get_universe_by_uuid_stub
	local hydrate_stub
	local cleanup_stub
	local beforeHydrate_stub
	local afterHydrate_stub
	local save_stub
	local getcwd_stub

	local test_directory = "/tmp/multiverse-test-dir"
	local fake_universe

	before_each(function()
		fake_universe = { uuid = "current-uuid", name = "current-universe" }

		save_multiverse_stub = stub(multiverse_repository, "save_multiverse")
		get_universe_by_uuid_stub = stub(universe_repository, "get_universe_by_uuid")
		get_universe_by_uuid_stub.returns(fake_universe)
		hydrate_stub = stub(hydration_manager, "hydrate")
		cleanup_stub = stub(cleanup_manager, "cleanup")
		beforeHydrate_stub = stub(plugin_manager, "beforeHydrate")
		afterHydrate_stub = stub(plugin_manager, "afterHydrate")
		save_stub = stub(multiverse_manager, "save")
		getcwd_stub = stub(vim.fn, "getcwd")
		getcwd_stub.returns(test_directory)
	end)

	after_each(function()
		save_multiverse_stub:revert()
		get_universe_by_uuid_stub:revert()
		hydrate_stub:revert()
		cleanup_stub:revert()
		beforeHydrate_stub:revert()
		afterHydrate_stub:revert()
		save_stub:revert()
		getcwd_stub:revert()
	end)

	describe("when the current working directory matches an existing universe in the multiverse", function()
		it("should call beforeHydrate/afterHydrate with the real current universe, not nil", function()
			local current_universe_summary = UniverseSummary:new(test_directory, "current-uuid", "current-universe", 1)
			local selected_universe_summary = UniverseSummary:new("/tmp/multiverse-selected-dir", "selected-uuid", "selected-universe", 2)

			local multiverse = Multiverse:new({ current_universe_summary, selected_universe_summary })

			multiverse_manager.load_universe(multiverse, selected_universe_summary, false)

			assert.stub(beforeHydrate_stub).was.called(1)
			assert.stub(afterHydrate_stub).was.called(1)

			assert.are.equal(fake_universe, beforeHydrate_stub.calls[1].refs[1].universe)
			assert.are.equal(fake_universe, afterHydrate_stub.calls[1].refs[1].universe)
		end)
	end)
end)
