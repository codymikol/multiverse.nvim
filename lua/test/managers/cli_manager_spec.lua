local stub = require("luassert.stub")
local match = require("luassert.match")

-- Inject a fake telescope integration before requiring cli_manager so that
-- its transitive require of "integrations.telescope" never reaches the real
-- telescope.nvim modules, which are not available in CI.
package.loaded["integrations.telescope"] = { prompt_select_universe = function() end }

local cli_manager = require("multiverse.managers.cli_manager")
local log = require("multiverse.log")
local zellij_manager = require("multiverse.managers.zellij_manager")

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
			pcall(vim.cmd, "bdelete!")
			if #vim.api.nvim_list_wins() > 1 then
				vim.cmd("only")
			end
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
			assert.is_false(vim.bo.modifiable)
		end)
	end)

	describe("MultiverseTerminal", function()
		local create_user_command_stub
		local is_available_stub
		local session_name_for_stub
		local open_floating_terminal_stub
		local close_floating_terminal_stub
		local is_floating_terminal_open_stub
		local notify_stub

		before_each(function()
			create_user_command_stub = stub(vim.api, "nvim_create_user_command")
			is_available_stub = stub(zellij_manager, "is_available")
			session_name_for_stub = stub(zellij_manager, "session_name_for")
			open_floating_terminal_stub = stub(zellij_manager, "open_floating_terminal")
			close_floating_terminal_stub = stub(zellij_manager, "close_floating_terminal")
			is_floating_terminal_open_stub = stub(zellij_manager, "is_floating_terminal_open")
			is_floating_terminal_open_stub.returns(false)
			notify_stub = stub(vim, "notify")
		end)

		after_each(function()
			create_user_command_stub:revert()
			is_available_stub:revert()
			session_name_for_stub:revert()
			open_floating_terminal_stub:revert()
			close_floating_terminal_stub:revert()
			is_floating_terminal_open_stub:revert()
			notify_stub:revert()
		end)

		local function get_callback()
			cli_manager.registerCommands()

			for _, call in ipairs(create_user_command_stub.calls) do
				if call.refs[1] == "MultiverseTerminal" then
					return call.refs[2]
				end
			end
		end

		it("registers a MultiverseTerminal user command", function()
			cli_manager.registerCommands()

			assert.stub(create_user_command_stub).was.called_with(
				"MultiverseTerminal",
				match._,
				match._
			)
		end)

		it("opens a floating terminal for the session derived from the current cwd when zellij is available", function()
			is_available_stub.returns(true)
			session_name_for_stub.returns("multiverse-abc")

			local callback = get_callback()
			callback()

			assert.stub(open_floating_terminal_stub).was_called_with("multiverse-abc")
			assert.stub(notify_stub).was_not_called()
		end)

		it("warns and does not open a terminal when zellij is not available", function()
			is_available_stub.returns(false)

			local callback = get_callback()
			callback()

			assert.stub(open_floating_terminal_stub).was_not_called()
			assert.stub(notify_stub).was_called_with("zellij is not installed", vim.log.levels.WARN)
		end)

		it("closes floating terminal when already open", function()
			is_available_stub.returns(true)
			is_floating_terminal_open_stub.returns(true)

			local callback = get_callback()
			callback()

			assert.stub(close_floating_terminal_stub).was_called(1)
			assert.stub(close_floating_terminal_stub).was_called_with()
			assert.stub(session_name_for_stub).was_not_called()
			assert.stub(open_floating_terminal_stub).was_not_called()
			assert.stub(notify_stub).was_not_called()
		end)
	end)
end)
