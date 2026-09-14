local stub = require("luassert.stub")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local state_store = require("multiverse.store.state_store")
local log = require("multiverse.log")
local multiverse_manager = require("multiverse.managers.multiverse_manager")

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
			local log_message = log_error_stub.calls[1].refs[1]
			assert.is_not_nil(log_message:find("boom", 1, true))
		end)
	end)
end)
