local stub = require("luassert.stub")

local multiverse_manager = require("multiverse.managers.multiverse_manager")
local plugin_manager = require("multiverse.managers.plugin_manager")
local universe_repository = require("multiverse.repositories.universe_repository")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local hydration_manager = require("multiverse.managers.hydration_manager")
local cleanup_manager = require("multiverse.managers.cleanup_manager")
local dehydration_manager = require("multiverse.managers.dehydration_manager")
local state_store = require("multiverse.store.state_store")
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
	local fake_current_universe

	before_each(function()
		fake_current_universe = { uuid = "current-uuid", name = "current-universe" }

		save_multiverse_stub = stub(multiverse_repository, "save_multiverse")
		get_universe_by_uuid_stub = stub(universe_repository, "get_universe_by_uuid")
		get_universe_by_uuid_stub.invokes(function(uuid)
			if uuid == fake_current_universe.uuid then
				return fake_current_universe
			end
			return nil, "unexpected uuid: " .. tostring(uuid)
		end)
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

			assert.are.equal(fake_current_universe, beforeHydrate_stub.calls[1].refs[1].universe)
			assert.are.equal(fake_current_universe, afterHydrate_stub.calls[1].refs[1].universe)
		end)
	end)

	describe("when skip_save is true", function()
		it("should call beforeHydrate/afterHydrate with universe = nil, without looking up a current universe", function()
			local selected_universe_summary = UniverseSummary:new("/tmp/multiverse-selected-dir", "selected-uuid", "selected-universe", 2)
			local multiverse = Multiverse:new({ selected_universe_summary })

			multiverse_manager.load_universe(multiverse, selected_universe_summary, true)

			assert.stub(get_universe_by_uuid_stub).was_not.called()

			assert.stub(beforeHydrate_stub).was.called(1)
			assert.stub(afterHydrate_stub).was.called(1)

			assert.is_nil(beforeHydrate_stub.calls[1].refs[1].universe)
			assert.is_nil(afterHydrate_stub.calls[1].refs[1].universe)
		end)
	end)

	describe("when the current working directory is not part of any universe", function()
		it("should call beforeHydrate/afterHydrate with universe = nil", function()
			local selected_universe_summary = UniverseSummary:new("/tmp/multiverse-selected-dir", "selected-uuid", "selected-universe", 2)
			local multiverse = Multiverse:new({ selected_universe_summary })

			multiverse_manager.load_universe(multiverse, selected_universe_summary, false)

			assert.stub(get_universe_by_uuid_stub).was_not.called()

			assert.stub(beforeHydrate_stub).was.called(1)
			assert.stub(afterHydrate_stub).was.called(1)

			assert.is_nil(beforeHydrate_stub.calls[1].refs[1].universe)
			assert.is_nil(afterHydrate_stub.calls[1].refs[1].universe)
		end)
	end)
end)

describe("multiverse_manager.save", function()
	local getMultiverse_stub
	local get_universe_by_uuid_stub
	local beforeDehydrate_stub
	local afterDehydrate_stub
	local dehydrate_stub
	local save_universe_stub
	local getcwd_stub
	local getUniverseByDirectory_stub

	local test_directory = "/tmp/multiverse-test-save-dir"
	local fake_universe
	local fake_dehydrated_universe
	local current_universe_summary

	before_each(function()
		state_store.set_current_state(state_store.STATES.IDLE)

		fake_universe = { uuid = "current-uuid", name = "current-universe" }
		fake_dehydrated_universe = { uuid = "current-uuid", name = "current-universe", dehydrated = true }

		current_universe_summary = UniverseSummary:new(test_directory, "current-uuid", "current-universe", 1)
		local multiverse = Multiverse:new({ current_universe_summary })

		getMultiverse_stub = stub(multiverse_repository, "getMultiverse")
		getMultiverse_stub.returns(multiverse)

		getUniverseByDirectory_stub = stub(multiverse, "getUniverseByDirectory")
		getUniverseByDirectory_stub.returns(current_universe_summary)

		get_universe_by_uuid_stub = stub(universe_repository, "get_universe_by_uuid")
		get_universe_by_uuid_stub.returns(fake_universe)

		beforeDehydrate_stub = stub(plugin_manager, "beforeDehydrate")
		afterDehydrate_stub = stub(plugin_manager, "afterDehydrate")

		dehydrate_stub = stub(dehydration_manager, "dehydrate")
		dehydrate_stub.returns(fake_dehydrated_universe)

		save_universe_stub = stub(universe_repository, "save_universe")

		getcwd_stub = stub(vim.fn, "getcwd")
		getcwd_stub.returns(test_directory)
	end)

	after_each(function()
		getMultiverse_stub:revert()
		getUniverseByDirectory_stub:revert()
		get_universe_by_uuid_stub:revert()
		beforeDehydrate_stub:revert()
		afterDehydrate_stub:revert()
		dehydrate_stub:revert()
		save_universe_stub:revert()
		getcwd_stub:revert()

		state_store.set_current_state(state_store.STATES.IDLE)
	end)

	describe("when the current working directory matches an existing universe in the multiverse", function()
		it("should look up the current universe by directory only once, then dehydrate and save it", function()
			multiverse_manager.save()

			assert.stub(getUniverseByDirectory_stub).was.called(1)

			assert.stub(dehydrate_stub).was.called(1)
			assert.are.equal(current_universe_summary, dehydrate_stub.calls[1].refs[1])

			assert.stub(save_universe_stub).was.called(1)
			assert.are.equal(fake_dehydrated_universe, save_universe_stub.calls[1].refs[1])

			assert.are.equal(fake_universe, beforeDehydrate_stub.calls[1].refs[1].universe)
			assert.are.equal(fake_universe, afterDehydrate_stub.calls[1].refs[1].universe)
		end)
	end)
end)
