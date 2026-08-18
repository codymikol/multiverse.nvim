local stub = require("luassert.stub")
local match = require("luassert.match")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local universe_repository = require("multiverse.repositories.universe_repository")
local cleanup_manager = require("multiverse.managers.cleanup_manager")
local hydration_manager = require("multiverse.managers.hydration_manager")
local dehydration_manager = require("multiverse.managers.dehydration_manager")
local plugin_manager = require("multiverse.managers.plugin_manager")
local state_store = require("multiverse.store.state_store")
local log = require("multiverse.log")
local multiverse_manager = require("multiverse.managers.multiverse_manager")
local Multiverse = require("multiverse.data.Multiverse")
local UniverseSummary = require("multiverse.data.UniverseSummary")

describe("multiverse_manager.save", function()
	describe("when saving raises an error", function()
		local get_multiverse_stub
		local log_error_stub
		local notify_stub

		before_each(function()
			state_store.set_current_state(state_store.STATES.IDLE)
			get_multiverse_stub = stub(multiverse_repository, "getMultiverse", function()
				error("boom")
			end)
			log_error_stub = stub(log, "error")
			notify_stub = stub(vim, "notify")
		end)

		after_each(function()
			get_multiverse_stub:revert()
			log_error_stub:revert()
			notify_stub:revert()
			state_store.set_current_state(state_store.STATES.IDLE)
		end)

		it("notifies a generic ERROR and logs the detailed error separately", function()
			multiverse_manager.save()

			assert.stub(notify_stub).was.called_with(
				"Error saving universe, check MultiverseLog for more information",
				vim.log.levels.ERROR
			)
			assert.stub(log_error_stub).was.called(1)
			assert.stub(log_error_stub).was.called_with("Error saving universe: %s", match._)
			local log_detail = log_error_stub.calls[1].refs[2]
			assert.is_not_nil(tostring(log_detail):find("boom", 1, true))
		end)
	end)
end)

describe("multiverse_manager.load_universe", function()
	local save_multiverse_stub
	local cleanup_stub
	local hydrate_stub
	local beforeHydrate_stub
	local afterHydrate_stub
	local get_universe_by_uuid_stub
	local getcwd_stub
	local save_stub
	local log_error_stub
	local log_debug_stub

	before_each(function()
		state_store.set_current_state(state_store.STATES.IDLE)
		save_multiverse_stub = stub(multiverse_repository, "save_multiverse")
		cleanup_stub = stub(cleanup_manager, "cleanup")
		hydrate_stub = stub(hydration_manager, "hydrate")
		beforeHydrate_stub = stub(plugin_manager, "beforeHydrate")
		afterHydrate_stub = stub(plugin_manager, "afterHydrate")
		get_universe_by_uuid_stub = stub(universe_repository, "get_universe_by_uuid")
		log_error_stub = stub(log, "error")
		log_debug_stub = stub(log, "debug")
	end)

	after_each(function()
		save_multiverse_stub:revert()
		cleanup_stub:revert()
		hydrate_stub:revert()
		beforeHydrate_stub:revert()
		afterHydrate_stub:revert()
		get_universe_by_uuid_stub:revert()
		log_error_stub:revert()
		log_debug_stub:revert()
		if getcwd_stub then
			getcwd_stub:revert()
			getcwd_stub = nil
		end
		if save_stub then
			save_stub:revert()
			save_stub = nil
		end
		state_store.set_current_state(state_store.STATES.IDLE)
	end)

	describe("when the current directory's universe is the SAME universe being loaded", function()
		it("does not call M.save and still hydrates the selected universe", function()
			local cwd = "/tmp/multiverse-manager-spec/same"
			local shared_uuid = "same-universe-uuid"

			local current_universe_summary =
				UniverseSummary:new({ directory = cwd, uuid = shared_uuid, name = "same-universe" })
			local selected_universe_summary =
				UniverseSummary:new({ directory = cwd, uuid = shared_uuid, name = "same-universe" })
			local multiverse = Multiverse:new({ current_universe_summary })

			getcwd_stub = stub(vim.fn, "getcwd", function() return cwd end)
			get_universe_by_uuid_stub.returns({ uuid = shared_uuid })
			save_stub = stub(multiverse_manager, "save")

			multiverse_manager.load_universe(multiverse, selected_universe_summary)

			assert.stub(save_stub).was_not.called()
			assert.stub(hydrate_stub).was.called_with(selected_universe_summary)
		end)
	end)

	describe("when the current directory's universe has a DIFFERENT uuid than the one being loaded", function()
		it("calls M.save and still hydrates the selected universe", function()
			local cwd = "/tmp/multiverse-manager-spec/different"

			local current_universe_summary =
				UniverseSummary:new({ directory = cwd, uuid = "current-universe-uuid", name = "current-universe" })
			local selected_universe_summary =
				UniverseSummary:new({ directory = cwd, uuid = "selected-universe-uuid", name = "selected-universe" })
			local multiverse = Multiverse:new({ current_universe_summary })

			getcwd_stub = stub(vim.fn, "getcwd", function() return cwd end)
			get_universe_by_uuid_stub.returns({ uuid = "current-universe-uuid" })
			save_stub = stub(multiverse_manager, "save")

			multiverse_manager.load_universe(multiverse, selected_universe_summary)

			assert.stub(save_stub).was.called(1)
			assert.stub(hydrate_stub).was.called_with(selected_universe_summary)
		end)
	end)

	describe("when the current directory's universe's file is missing or corrupt", function()
		it("aborts before cleanup/hydrate run and logs the error", function()
			local cwd = "/tmp/multiverse-manager-spec/corrupt"
			local shared_uuid = "corrupt-universe-uuid"

			local current_universe_summary =
				UniverseSummary:new({ directory = cwd, uuid = shared_uuid, name = "corrupt-universe" })
			local selected_universe_summary =
				UniverseSummary:new({ directory = cwd, uuid = shared_uuid, name = "corrupt-universe" })
			local multiverse = Multiverse:new({ current_universe_summary })

			getcwd_stub = stub(vim.fn, "getcwd", function() return cwd end)
			get_universe_by_uuid_stub.returns(nil, "some error")
			save_stub = stub(multiverse_manager, "save")

			multiverse_manager.load_universe(multiverse, selected_universe_summary)

			assert.stub(cleanup_stub).was_not.called()
			assert.stub(hydrate_stub).was_not.called()
			assert.stub(log_error_stub).was.called()
		end)
	end)

	describe("when the current directory's universe matches an existing universe in the multiverse", function()
		it("calls beforeHydrate/afterHydrate with the real current universe, not nil", function()
			local cwd = "/tmp/multiverse-manager-spec/real-universe"
			local shared_uuid = "current-uuid"
			local fake_universe = { uuid = shared_uuid, name = "current-universe" }

			local current_universe_summary =
				UniverseSummary:new({ directory = cwd, uuid = shared_uuid, name = "current-universe" })
			local selected_universe_summary =
				UniverseSummary:new({ directory = "/tmp/multiverse-manager-spec/selected", uuid = "selected-uuid", name = "selected-universe" })
			local multiverse = Multiverse:new({ current_universe_summary, selected_universe_summary })

			getcwd_stub = stub(vim.fn, "getcwd", function() return cwd end)
			get_universe_by_uuid_stub.returns(fake_universe)
			save_stub = stub(multiverse_manager, "save")

			multiverse_manager.load_universe(multiverse, selected_universe_summary, false)

			assert.stub(beforeHydrate_stub).was.called(1)
			assert.stub(afterHydrate_stub).was.called(1)

			assert.are.equal(fake_universe, beforeHydrate_stub.calls[1].refs[1].universe)
			assert.are.equal(fake_universe, afterHydrate_stub.calls[1].refs[1].universe)
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

	before_each(function()
		state_store.set_current_state(state_store.STATES.IDLE)

		fake_universe = { uuid = "current-uuid", name = "current-universe" }
		fake_dehydrated_universe = { uuid = "current-uuid", name = "current-universe" }

		local current_universe_summary =
			UniverseSummary:new({ directory = test_directory, uuid = "current-uuid", name = "current-universe", lastExplored = 1 })
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
		get_universe_by_uuid_stub:revert()
		beforeDehydrate_stub:revert()
		afterDehydrate_stub:revert()
		dehydrate_stub:revert()
		save_universe_stub:revert()
		getcwd_stub:revert()

		state_store.set_current_state(state_store.STATES.IDLE)
	end)

	describe("when the current working directory matches an existing universe in the multiverse", function()
		it("should only look up the current universe by directory once", function()
			multiverse_manager.save()

			assert.stub(getUniverseByDirectory_stub).was.called(1)
		end)
	end)
end)
