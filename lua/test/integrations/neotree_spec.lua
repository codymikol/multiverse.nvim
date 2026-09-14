local stub = require("luassert.stub")

describe("neotree.hydrate", function()
	local neotree = require("integrations.neotree")
	local exists_stub
	local cmd_stub

	before_each(function()
		exists_stub = stub(vim.fn, "exists")
		cmd_stub = stub(vim, "cmd")
	end)

	after_each(function()
		exists_stub:revert()
		cmd_stub:revert()
	end)

	it("does not call vim.cmd when the :Neotree command does not exist", function()
		exists_stub.returns(0)

		neotree.hydrate()

		assert.stub(exists_stub).was_called_with(":Neotree")
		assert.stub(cmd_stub).was_not_called()
	end)

	it("calls vim.cmd with the Neotree command when the :Neotree command exists", function()
		local getcwd_stub = stub(vim.fn, "getcwd")
		getcwd_stub.returns("/some/plain/dir")
		exists_stub.returns(2)

		neotree.hydrate()

		assert.stub(exists_stub).was_called_with(":Neotree")
		assert.stub(cmd_stub).was_called(1)
		assert.stub(cmd_stub).was_called_with("Neotree /some/plain/dir")

		getcwd_stub:revert()
	end)

	describe("when the current working directory contains characters that require escaping", function()
		local getcwd_stub

		before_each(function()
			getcwd_stub = stub(vim.fn, "getcwd")
			getcwd_stub.returns("/some/dir with spaces")
		end)

		after_each(function()
			getcwd_stub:revert()
		end)

		it("escapes the working directory before passing it to the :Neotree command", function()
			exists_stub.returns(2)

			neotree.hydrate()

			assert.stub(cmd_stub).was_called_with("Neotree /some/dir\\ with\\ spaces")
		end)
	end)

	describe("when the current working directory contains an Ex command separator", function()
		local getcwd_stub

		before_each(function()
			getcwd_stub = stub(vim.fn, "getcwd")
			getcwd_stub.returns("/some/dir|qall!")
		end)

		after_each(function()
			getcwd_stub:revert()
		end)

		it("escapes Ex-meaningful characters in the working directory", function()
			exists_stub.returns(2)

			neotree.hydrate()

			assert.stub(cmd_stub).was_called_with("Neotree /some/dir\\|qall\\!")
		end)
	end)
end)
