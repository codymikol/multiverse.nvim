local stub = require("luassert.stub")
local match = require("luassert.match")

-- Inject a fake telescope integration before requiring cli_manager so that
-- its transitive require of "integrations.telescope" never reaches the real
-- telescope.nvim modules, which are not available in CI.
package.loaded["integrations.telescope"] = { prompt_select_universe = function() end }

local cli_manager = require("multiverse.managers.cli_manager")
local log = require("multiverse.log")

describe("cli_manager.registerCommands", function()
	describe("MultiverseLog", function()
		local create_user_command_stub

		local get_log_file_stub

		before_each(function()
			create_user_command_stub = stub(vim.api, "nvim_create_user_command")
			get_log_file_stub = stub(log, "get_log_file")
		end)

		after_each(function()
			create_user_command_stub:revert()
			get_log_file_stub:revert()
		end)

		it("registers a MultiverseLog user command", function()
			cli_manager.registerCommands()

			assert.stub(create_user_command_stub).was.called_with(
				"MultiverseLog",
				match._,
				match._
			)
		end)

		it("opens a log path containing '%' without mangling it via cmdline expansion", function()
			local log_path = vim.fn.tempname() .. "_a%b.log"
			get_log_file_stub.returns(log_path)

			cli_manager.registerCommands()

			local callback
			for _, call in ipairs(create_user_command_stub.calls) do
				if call.refs[1] == "MultiverseLog" then
					callback = call.refs[2]
				end
			end

			assert.has_no.errors(callback)
			assert.are.equal(log_path, vim.api.nvim_buf_get_name(0))

			vim.cmd("bdelete!")
			vim.cmd("only")
		end)
	end)
end)
