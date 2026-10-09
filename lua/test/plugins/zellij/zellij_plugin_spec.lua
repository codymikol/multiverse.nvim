local stub = require("luassert.stub")
local match = require("luassert.match")

describe("plugins.zellij.zellij_plugin", function()
	describe("context.beforeDehydrate", function()
		local zellij_plugin
		local zellij_manager
		local is_available_stub
		local is_floating_terminal_open_stub
		local close_floating_terminal_stub
		local session_name_for_stub
		local mark_open_stub
		local mark_closed_stub
		local ctx

		before_each(function()
			package.loaded["plugins.zellij.zellij_plugin"] = nil
			package.loaded["plugins.zellij.zellij_manager"] = nil
			zellij_manager = require("plugins.zellij.zellij_manager")

			is_available_stub = stub(zellij_manager, "is_available")
			is_floating_terminal_open_stub = stub(zellij_manager, "is_floating_terminal_open")
			close_floating_terminal_stub = stub(zellij_manager, "close_floating_terminal")
			session_name_for_stub = stub(zellij_manager, "session_name_for")
			session_name_for_stub.returns("multiverse-abc")
			mark_open_stub = stub(zellij_manager, "mark_open")
			mark_closed_stub = stub(zellij_manager, "mark_closed")

			zellij_plugin = require("plugins.zellij.zellij_plugin")

			ctx = { universe = { workingDirectory = "/some/dir" } }
		end)

		after_each(function()
			is_available_stub:revert()
			is_floating_terminal_open_stub:revert()
			close_floating_terminal_stub:revert()
			session_name_for_stub:revert()
			mark_open_stub:revert()
			mark_closed_stub:revert()
			package.loaded["plugins.zellij.zellij_plugin"] = nil
			package.loaded["plugins.zellij.zellij_manager"] = nil
		end)

		it("closes the tracked floating terminal when zellij is available and one is open", function()
			is_available_stub.returns(true)
			is_floating_terminal_open_stub.returns(true)

			zellij_plugin.context.beforeDehydrate(ctx)

			assert.stub(close_floating_terminal_stub).was_called(1)
		end)

		it("does nothing when zellij is not available", function()
			is_available_stub.returns(false)
			is_floating_terminal_open_stub.returns(true)

			zellij_plugin.context.beforeDehydrate(ctx)

			assert.stub(close_floating_terminal_stub).was_not_called()
			assert.stub(mark_open_stub).was_not_called()
			assert.stub(mark_closed_stub).was_not_called()
		end)

		it("does nothing when no floating terminal is currently tracked as open", function()
			is_available_stub.returns(true)
			is_floating_terminal_open_stub.returns(false)

			zellij_plugin.context.beforeDehydrate(ctx)

			assert.stub(close_floating_terminal_stub).was_not_called()
		end)

		it("marks the session open when a floating terminal was open and zellij is available", function()
			is_available_stub.returns(true)
			is_floating_terminal_open_stub.returns(true)

			zellij_plugin.context.beforeDehydrate(ctx)

			assert.stub(session_name_for_stub).was_called_with("/some/dir")
			assert.stub(mark_open_stub).was_called_with("multiverse-abc")
			assert.stub(mark_closed_stub).was_not_called()
		end)

		it("marks the session closed when zellij is available but nothing was open", function()
			is_available_stub.returns(true)
			is_floating_terminal_open_stub.returns(false)

			zellij_plugin.context.beforeDehydrate(ctx)

			assert.stub(mark_closed_stub).was_called_with("multiverse-abc")
			assert.stub(mark_open_stub).was_not_called()
		end)
	end)

	describe("context.afterHydrate", function()
		local zellij_plugin
		local zellij_manager
		local is_available_stub
		local session_name_for_stub
		local reattach_if_running_stub
		local was_open_stub
		local getcwd_stub

		before_each(function()
			package.loaded["plugins.zellij.zellij_plugin"] = nil
			package.loaded["plugins.zellij.zellij_manager"] = nil
			zellij_manager = require("plugins.zellij.zellij_manager")

			is_available_stub = stub(zellij_manager, "is_available")
			session_name_for_stub = stub(zellij_manager, "session_name_for")
			reattach_if_running_stub = stub(zellij_manager, "reattach_if_running")
			was_open_stub = stub(zellij_manager, "was_open")
			getcwd_stub = stub(vim.fn, "getcwd")

			zellij_plugin = require("plugins.zellij.zellij_plugin")
		end)

		after_each(function()
			is_available_stub:revert()
			session_name_for_stub:revert()
			reattach_if_running_stub:revert()
			was_open_stub:revert()
			getcwd_stub:revert()
			package.loaded["plugins.zellij.zellij_plugin"] = nil
			package.loaded["plugins.zellij.zellij_manager"] = nil
		end)

		it("reattaches using the session name derived from the current cwd when zellij is available and was_open is true", function()
			is_available_stub.returns(true)
			getcwd_stub.returns("/some/dir")
			session_name_for_stub.returns("multiverse-abc")
			was_open_stub.returns(true)

			zellij_plugin.context.afterHydrate({})

			assert.stub(session_name_for_stub).was_called_with("/some/dir")
			assert.stub(was_open_stub).was_called_with("multiverse-abc")
			assert.stub(reattach_if_running_stub).was_called_with("multiverse-abc")
		end)

		it("does not reattach when zellij is available but was_open returns false", function()
			is_available_stub.returns(true)
			getcwd_stub.returns("/some/dir")
			session_name_for_stub.returns("multiverse-abc")
			was_open_stub.returns(false)

			zellij_plugin.context.afterHydrate({})

			assert.stub(reattach_if_running_stub).was_not_called()
		end)

		it("does nothing and never consults was_open when zellij is not available", function()
			is_available_stub.returns(false)

			zellij_plugin.context.afterHydrate({})

			assert.stub(was_open_stub).was_not_called()
			assert.stub(reattach_if_running_stub).was_not_called()
		end)
	end)

	describe("context.setupCommands", function()
		local zellij_plugin
		local zellij_manager
		local create_user_command_stub
		local is_available_stub
		local session_name_for_stub
		local open_floating_terminal_stub
		local close_floating_terminal_stub
		local is_floating_terminal_open_stub
		local notify_stub

		before_each(function()
			package.loaded["plugins.zellij.zellij_plugin"] = nil
			package.loaded["plugins.zellij.zellij_manager"] = nil
			zellij_manager = require("plugins.zellij.zellij_manager")

			create_user_command_stub = stub(vim.api, "nvim_create_user_command")
			is_available_stub = stub(zellij_manager, "is_available")
			session_name_for_stub = stub(zellij_manager, "session_name_for")
			open_floating_terminal_stub = stub(zellij_manager, "open_floating_terminal")
			close_floating_terminal_stub = stub(zellij_manager, "close_floating_terminal")
			is_floating_terminal_open_stub = stub(zellij_manager, "is_floating_terminal_open")
			is_floating_terminal_open_stub.returns(false)
			notify_stub = stub(vim, "notify")

			zellij_plugin = require("plugins.zellij.zellij_plugin")
		end)

		after_each(function()
			create_user_command_stub:revert()
			is_available_stub:revert()
			session_name_for_stub:revert()
			open_floating_terminal_stub:revert()
			close_floating_terminal_stub:revert()
			is_floating_terminal_open_stub:revert()
			notify_stub:revert()
			package.loaded["plugins.zellij.zellij_plugin"] = nil
			package.loaded["plugins.zellij.zellij_manager"] = nil
		end)

		local function get_callback()
			zellij_plugin.context.setupCommands()

			for _, call in ipairs(create_user_command_stub.calls) do
				if call.refs[1] == "MultiverseTerminal" then
					return call.refs[2]
				end
			end
		end

		it("registers a MultiverseTerminal user command", function()
			zellij_plugin.context.setupCommands()

			assert.stub(create_user_command_stub).was.called_with(
				"MultiverseTerminal",
				match._,
				{ nargs = 0 }
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
