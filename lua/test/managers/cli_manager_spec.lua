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
		local edit_stub

		before_each(function()
			create_user_command_stub = stub(vim.api, "nvim_create_user_command")
			get_log_file_stub = stub(log, "get_log_file")
			edit_stub = stub(vim.cmd, "edit")
		end)

		after_each(function()
			create_user_command_stub:revert()
			get_log_file_stub:revert()
			edit_stub:revert()
		end)

		it("registers a MultiverseLog user command", function()
			cli_manager.registerCommands()

			assert.stub(create_user_command_stub).was.called_with(
				"MultiverseLog",
				match._,
				match._
			)
		end)

		it("opens the log file path as-is, with no Ex command string-building", function()
			get_log_file_stub.returns("/tmp/a%b.log")

			cli_manager.registerCommands()

			local callback
			for _, call in ipairs(create_user_command_stub.calls) do
				if call.refs[1] == "MultiverseLog" then
					callback = call.refs[2]
				end
			end
			callback()

			assert.stub(edit_stub).was.called_with("/tmp/a%b.log")
		end)
	end)
end)
