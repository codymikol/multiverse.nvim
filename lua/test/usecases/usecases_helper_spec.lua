local stub = require("luassert.stub")
local spy = require("luassert.spy")

local log = require("multiverse.log")
local usecases_helper = require("multiverse.usecases.usecases_helper")

describe("usecases_helper.run_safely", function()
	local notify_stub
	local log_error_stub

	before_each(function()
		notify_stub = stub(vim, "notify")
		log_error_stub = stub(log, "error")
	end)

	after_each(function()
		notify_stub:revert()
		log_error_stub:revert()
	end)

	describe("when fn succeeds", function()
		it("does not notify or log, and runs fn's side effects", function()
			local called = false

			usecases_helper.run_safely("do thing", "doing thing", function()
				called = true
			end)

			assert.is_true(called)
			assert.stub(notify_stub).was_not.called()
			assert.stub(log_error_stub).was_not.called()
		end)
	end)

	describe("when fn throws", function()
		it("notifies a generic failure and logs the error", function()
			usecases_helper.run_safely("do thing", "doing thing", function()
				error("boom")
			end)

			assert.stub(notify_stub).was.called_with(
				"Failed to do thing, check MultiverseLog for more information",
				vim.log.levels.ERROR
			)

			assert.stub(log_error_stub).was.called(1)
			local log_format = log_error_stub.calls[1].vals[1]
			local log_err = log_error_stub.calls[1].vals[2]
			assert.is_true(log_format:find("Error doing thing: ", 1, true) ~= nil)
			assert.is_true(tostring(log_err):find("boom", 1, true) ~= nil)
		end)

	end)
end)

describe("usecases_helper.run_safely - error message with a literal '%' character", function()
	-- This describe is a sibling (not nested) of the block above so that log.error
	-- is NOT pre-stubbed by an outer before_each: the bug this guards against lives
	-- inside log.lua's real string.format call, so log.error must actually run.
	local notify_stub
	local log_error_spy

	before_each(function()
		notify_stub = stub(vim, "notify")
		log_error_spy = spy.on(log, "error")
	end)

	after_each(function()
		notify_stub:revert()
		log_error_spy:revert()
	end)

	it("does not throw, and still logs the error", function()
		assert.has_no.errors(function()
			usecases_helper.run_safely("do thing", "doing thing", function()
				error("bad dir /tmp/100%s/x")
			end)
		end)

		assert.spy(log_error_spy).was.called(1)
	end)
end)
