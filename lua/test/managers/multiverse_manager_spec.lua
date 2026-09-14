local stub = require("luassert.stub")
local match = require("luassert.match")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local universe_repository = require("multiverse.repositories.universe_repository")
local dehydration_manager = require("multiverse.managers.dehydration_manager")
local hydration_manager = require("multiverse.managers.hydration_manager")
local cleanup_manager = require("multiverse.managers.cleanup_manager")
local plugin_manager = require("multiverse.managers.plugin_manager")
local profiler = require("multiverse.profiler")
local state_store = require("multiverse.store.state_store")
local log = require("multiverse.log")
local multiverse_manager = require("multiverse.managers.multiverse_manager")

describe("multiverse_manager.save", function()
	describe("when saving raises an error", function()
		local get_multiverse_stub
		local log_error_stub
		local notify_stub
		local start_span_stub
		local end_span_stub
		local flush_stub

		before_each(function()
			state_store.set_current_state(state_store.STATES.IDLE)
			get_multiverse_stub = stub(multiverse_repository, "getMultiverse", function()
				error("boom")
			end)
			log_error_stub = stub(log, "error")
			notify_stub = stub(vim, "notify")
			start_span_stub = stub(profiler, "start_span", function(name)
				return { name = name }
			end)
			end_span_stub = stub(profiler, "end_span")
			flush_stub = stub(profiler, "flush")
		end)

		after_each(function()
			get_multiverse_stub:revert()
			log_error_stub:revert()
			notify_stub:revert()
			start_span_stub:revert()
			end_span_stub:revert()
			flush_stub:revert()
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

		it("still closes the save span and flushes the trace despite the error", function()
			multiverse_manager.save()

			assert.stub(start_span_stub).was.called_with("save")
			assert.stub(end_span_stub).was.called(1)
			assert.stub(flush_stub).was.called(1)
		end)
	end)

	describe("when saving succeeds", function()
		local get_multiverse_stub
		local get_universe_by_uuid_stub
		local dehydrate_stub
		local save_universe_stub
		local before_dehydrate_stub
		local after_dehydrate_stub
		local start_span_stub
		local end_span_stub
		local flush_stub

		before_each(function()
			state_store.set_current_state(state_store.STATES.IDLE)

			local universe_summary = { uuid = "uuid-1" }
			local multiverse = {
				getUniverseByDirectory = function(_, _)
					return universe_summary
				end,
			}

			get_multiverse_stub = stub(multiverse_repository, "getMultiverse", function()
				return multiverse
			end)
			get_universe_by_uuid_stub = stub(universe_repository, "get_universe_by_uuid", function()
				return { uuid = "uuid-1" }
			end)
			dehydrate_stub = stub(dehydration_manager, "dehydrate", function()
				return { uuid = "uuid-1" }
			end)
			save_universe_stub = stub(universe_repository, "save_universe")
			before_dehydrate_stub = stub(plugin_manager, "beforeDehydrate")
			after_dehydrate_stub = stub(plugin_manager, "afterDehydrate")
			start_span_stub = stub(profiler, "start_span", function(name)
				return { name = name }
			end)
			end_span_stub = stub(profiler, "end_span")
			flush_stub = stub(profiler, "flush")
		end)

		after_each(function()
			get_multiverse_stub:revert()
			get_universe_by_uuid_stub:revert()
			dehydrate_stub:revert()
			save_universe_stub:revert()
			before_dehydrate_stub:revert()
			after_dehydrate_stub:revert()
			start_span_stub:revert()
			end_span_stub:revert()
			flush_stub:revert()
			state_store.set_current_state(state_store.STATES.IDLE)
		end)

		it("opens and closes a span for save and each dehydration stage, then flushes once", function()
			multiverse_manager.save()

			assert.stub(start_span_stub).was.called_with("save")
			assert.stub(start_span_stub).was.called_with("beforeDehydrate")
			assert.stub(start_span_stub).was.called_with("dehydrate")
			assert.stub(start_span_stub).was.called_with("afterDehydrate")
			assert.stub(end_span_stub).was.called(4)
			assert.stub(flush_stub).was.called(1)
		end)
	end)
end)

describe("multiverse_manager.save when profiler.flush throws", function()
	local get_multiverse_stub
	local get_universe_by_uuid_stub
	local dehydrate_stub
	local save_universe_stub
	local before_dehydrate_stub
	local after_dehydrate_stub
	local flush_stub

	before_each(function()
		state_store.set_current_state(state_store.STATES.IDLE)

		local universe_summary = { uuid = "uuid-1" }
		local multiverse = {
			getUniverseByDirectory = function(_, _)
				return universe_summary
			end,
		}

		get_multiverse_stub = stub(multiverse_repository, "getMultiverse", function()
			return multiverse
		end)
		get_universe_by_uuid_stub = stub(universe_repository, "get_universe_by_uuid", function()
			return { uuid = "uuid-1" }
		end)
		dehydrate_stub = stub(dehydration_manager, "dehydrate", function()
			return { uuid = "uuid-1" }
		end)
		save_universe_stub = stub(universe_repository, "save_universe")
		before_dehydrate_stub = stub(plugin_manager, "beforeDehydrate")
		after_dehydrate_stub = stub(plugin_manager, "afterDehydrate")
		flush_stub = stub(profiler, "flush", function()
			error("boom")
		end)
	end)

	after_each(function()
		get_multiverse_stub:revert()
		get_universe_by_uuid_stub:revert()
		dehydrate_stub:revert()
		save_universe_stub:revert()
		before_dehydrate_stub:revert()
		after_dehydrate_stub:revert()
		flush_stub:revert()
		state_store.set_current_state(state_store.STATES.IDLE)
	end)

	it("still resets state to IDLE even when profiler.flush throws", function()
		multiverse_manager.save()

		assert.equals(state_store.STATES.IDLE, state_store.get_current_state())
	end)
end)

describe("multiverse_manager.load_universe", function()
	describe("when loading succeeds", function()
		local selected_universe_summary
		local multiverse
		local save_multiverse_stub
		local cleanup_stub
		local hydrate_stub
		local before_hydrate_stub
		local after_hydrate_stub
		local start_span_stub
		local end_span_stub
		local flush_stub

		before_each(function()
			state_store.set_current_state(state_store.STATES.IDLE)

			selected_universe_summary = {
				name = "target-universe",
				setLastExploredToNow = function() end,
			}
			multiverse = {}

			save_multiverse_stub = stub(multiverse_repository, "save_multiverse")
			cleanup_stub = stub(cleanup_manager, "cleanup")
			hydrate_stub = stub(hydration_manager, "hydrate")
			before_hydrate_stub = stub(plugin_manager, "beforeHydrate")
			after_hydrate_stub = stub(plugin_manager, "afterHydrate")
			start_span_stub = stub(profiler, "start_span", function(name)
				return { name = name }
			end)
			end_span_stub = stub(profiler, "end_span")
			flush_stub = stub(profiler, "flush")
		end)

		after_each(function()
			save_multiverse_stub:revert()
			cleanup_stub:revert()
			hydrate_stub:revert()
			before_hydrate_stub:revert()
			after_hydrate_stub:revert()
			start_span_stub:revert()
			end_span_stub:revert()
			flush_stub:revert()
			state_store.set_current_state(state_store.STATES.IDLE)
		end)

		it("opens and closes a span for load_universe and each hydration stage, then flushes once", function()
			multiverse_manager.load_universe(multiverse, selected_universe_summary, true)

			assert.stub(start_span_stub).was.called_with("load_universe")
			assert.stub(start_span_stub).was.called_with("cleanup")
			assert.stub(start_span_stub).was.called_with("beforeHydrate")
			assert.stub(start_span_stub).was.called_with("hydrate")
			assert.stub(start_span_stub).was.called_with("afterHydrate")
			assert.stub(end_span_stub).was.called(5)
			assert.stub(flush_stub).was.called(1)
		end)
	end)

	describe("when loading raises an error", function()
		local selected_universe_summary
		local multiverse
		local save_multiverse_stub
		local cleanup_stub
		local log_error_stub
		local notify_stub
		local start_span_stub
		local end_span_stub
		local flush_stub

		before_each(function()
			state_store.set_current_state(state_store.STATES.IDLE)

			selected_universe_summary = {
				name = "target-universe",
				setLastExploredToNow = function() end,
			}
			multiverse = {}

			save_multiverse_stub = stub(multiverse_repository, "save_multiverse")
			cleanup_stub = stub(cleanup_manager, "cleanup", function()
				error("boom")
			end)
			log_error_stub = stub(log, "error")
			notify_stub = stub(vim, "notify")
			start_span_stub = stub(profiler, "start_span", function(name)
				return { name = name }
			end)
			end_span_stub = stub(profiler, "end_span")
			flush_stub = stub(profiler, "flush")
		end)

		after_each(function()
			save_multiverse_stub:revert()
			cleanup_stub:revert()
			log_error_stub:revert()
			notify_stub:revert()
			start_span_stub:revert()
			end_span_stub:revert()
			flush_stub:revert()
			state_store.set_current_state(state_store.STATES.IDLE)
		end)

		it("still closes the load_universe span and flushes the trace despite the error", function()
			multiverse_manager.load_universe(multiverse, selected_universe_summary, true)

			assert.stub(start_span_stub).was.called_with("load_universe")
			assert.stub(end_span_stub).was.called(1)
			assert.stub(flush_stub).was.called(1)
		end)
	end)
end)

describe("multiverse_manager.load_universe when profiler.flush throws", function()
	local selected_universe_summary
	local multiverse
	local save_multiverse_stub
	local cleanup_stub
	local hydrate_stub
	local before_hydrate_stub
	local after_hydrate_stub
	local flush_stub

	before_each(function()
		state_store.set_current_state(state_store.STATES.IDLE)

		selected_universe_summary = {
			name = "target-universe",
			setLastExploredToNow = function() end,
		}
		multiverse = {}

		save_multiverse_stub = stub(multiverse_repository, "save_multiverse")
		cleanup_stub = stub(cleanup_manager, "cleanup")
		hydrate_stub = stub(hydration_manager, "hydrate")
		before_hydrate_stub = stub(plugin_manager, "beforeHydrate")
		after_hydrate_stub = stub(plugin_manager, "afterHydrate")
		flush_stub = stub(profiler, "flush", function()
			error("boom")
		end)
	end)

	after_each(function()
		save_multiverse_stub:revert()
		cleanup_stub:revert()
		hydrate_stub:revert()
		before_hydrate_stub:revert()
		after_hydrate_stub:revert()
		flush_stub:revert()
		state_store.set_current_state(state_store.STATES.IDLE)
	end)

	it("still resets state to IDLE even when profiler.flush throws", function()
		multiverse_manager.load_universe(multiverse, selected_universe_summary, true)

		assert.equals(state_store.STATES.IDLE, state_store.get_current_state())
	end)
end)
