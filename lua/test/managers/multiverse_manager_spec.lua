local stub = require("luassert.stub")
local match = require("luassert.match")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local universe_repository = require("multiverse.repositories.universe_repository")
local cleanup_manager = require("multiverse.managers.cleanup_manager")
local hydration_manager = require("multiverse.managers.hydration_manager")
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
			assert.are.same(state_store.STATES.IDLE, state_store.get_current_state())
		end)
	end)

	describe("when state_store is not IDLE (another operation is in-flight)", function()
		local notify_stub

		before_each(function()
			state_store.set_current_state(state_store.STATES.IDLE)
			notify_stub = stub(vim, "notify")
		end)

		after_each(function()
			notify_stub:revert()
			state_store.set_current_state(state_store.STATES.IDLE)
		end)

		it("leaves the in-flight state untouched instead of resetting it to IDLE", function()
			state_store.set_current_state(state_store.STATES.HYDRATION)

			multiverse_manager.save()

			assert.are.same(state_store.STATES.HYDRATION, state_store.get_current_state())
			assert.stub(notify_stub).was.called_with(match.matches("Cannot save universe while in state"))
		end)
	end)

	describe("when no universe is found for the current directory", function()
		local get_multiverse_stub
		local notify_stub

		before_each(function()
			state_store.set_current_state(state_store.STATES.IDLE)
			get_multiverse_stub = stub(multiverse_repository, "getMultiverse", function()
				return Multiverse:new({})
			end)
			notify_stub = stub(vim, "notify")
		end)

		after_each(function()
			get_multiverse_stub:revert()
			notify_stub:revert()
			state_store.set_current_state(state_store.STATES.IDLE)
		end)

		it("resets state back to IDLE after taking the early-return branch", function()
			multiverse_manager.save()

			assert.stub(notify_stub).was.called_with(match.matches("No universe found for current directory"))
			assert.are.same(state_store.STATES.IDLE, state_store.get_current_state())
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
			assert.are.same(state_store.STATES.IDLE, state_store.get_current_state())
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
			assert.are.same(state_store.STATES.IDLE, state_store.get_current_state())
		end)
	end)

	describe("when the current directory's universe's file is missing or corrupt", function()
		it("aborts before cleanup/hydrate run, logs the error, and leaves in-flight state untouched", function()
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

			state_store.set_current_state(state_store.STATES.HYDRATION)

			multiverse_manager.load_universe(multiverse, selected_universe_summary)

			assert.stub(cleanup_stub).was_not.called()
			assert.stub(hydrate_stub).was_not.called()
			assert.stub(log_error_stub).was.called()
			assert.are.same(state_store.STATES.HYDRATION, state_store.get_current_state())
		end)
	end)

	describe("when cleanup raises an error after CLEANUP has begun", function()
		local notify_stub

		before_each(function()
			cleanup_stub:revert()
			cleanup_stub = stub(cleanup_manager, "cleanup", function()
				error("cleanup boom")
			end)
			notify_stub = stub(vim, "notify")
		end)

		after_each(function()
			notify_stub:revert()
		end)

		it("still resets state back to IDLE", function()
			local selected_universe_summary =
				UniverseSummary:new({ directory = "/tmp/multiverse-manager-spec/skip", uuid = "skip-uuid", name = "skip-universe" })
			local multiverse = Multiverse:new({})

			multiverse_manager.load_universe(multiverse, selected_universe_summary, true)

			assert.stub(log_error_stub).was.called_with(match.matches("Error loading universe: skip%-universe"))
			assert.stub(notify_stub).was.called_with(
				"Error loading universe: skip-universe",
				vim.log.levels.ERROR
			)
			assert.are.same(state_store.STATES.IDLE, state_store.get_current_state())
		end)
	end)
end)
