local stub = require("luassert.stub")

describe("neotree.hydrate", function()
	local neotree = require("integrations.neotree")
	local exists_stub
	local cmd_stub
	local getcwd_stub

	before_each(function()
		exists_stub = stub(vim.fn, "exists")
		cmd_stub = stub(vim, "cmd")
		getcwd_stub = stub(vim.fn, "getcwd")
		getcwd_stub.returns("/home/test/project")
	end)

	after_each(function()
		exists_stub:revert()
		cmd_stub:revert()
		getcwd_stub:revert()
	end)

	it("does not call vim.cmd when the :Neotree command does not exist", function()
		exists_stub.returns(0)

		neotree.hydrate()

		assert.stub(exists_stub).was_called_with(":Neotree")
		assert.stub(cmd_stub).was_not_called()
	end)

	it("calls vim.cmd with the Neotree command when the :Neotree command exists", function()
		exists_stub.returns(2)

		neotree.hydrate()

		assert.stub(exists_stub).was_called_with(":Neotree")
		assert.stub(cmd_stub).was_called(1)
		assert.stub(cmd_stub).was_called_with("Neotree /home/test/project")
	end)

	it("escapes special characters in the cwd before passing it to vim.cmd", function()
		exists_stub.returns(2)
		getcwd_stub.returns("/tmp/some|dir")

		neotree.hydrate()

		assert.stub(cmd_stub).was_called(1)
		assert.stub(cmd_stub).was_called_with("Neotree /tmp/some\\|dir")
	end)
end)
