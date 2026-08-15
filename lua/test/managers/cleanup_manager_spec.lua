local buffer_manager = require("multiverse.managers.buffer_manager")
local cleanup_manager = require("multiverse.managers.cleanup_manager")
local stub = require("luassert.stub")

describe("cleanup_manager", function()
	describe("cleanup", function()
		local closeAllBuffers_stub

		before_each(function()
			closeAllBuffers_stub = stub(buffer_manager, "closeAllBuffers")
		end)

		after_each(function()
			closeAllBuffers_stub:revert()
		end)

		it("should close all buffers", function()
			cleanup_manager.cleanup()

			assert.stub(closeAllBuffers_stub).was.called_with()
			assert.stub(closeAllBuffers_stub).was.called(1)
		end)
	end)

	it("should not leak close_terminal_buffer or close_editable_buffer as globals", function()
		assert.is_nil(_G.close_terminal_buffer)
		assert.is_nil(_G.close_editable_buffer)
	end)
end)
