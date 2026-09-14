local zellij_manager = require("multiverse.managers.zellij_manager")
local persistance = require("multiverse.repositories.persistance")
local stub = require("luassert.stub")

-- vim.v.shell_error is read-only from Lua, so it can't be stubbed directly;
-- capture the real systemlist here (before any test stubs it) so the
-- reattach_if_running failure test can run a real failing shell command to
-- set v:shell_error as a side effect.
local real_systemlist = vim.fn.systemlist

describe("zellij_manager", function()
	describe("is_available", function()
		local executable_stub

		after_each(function()
			if executable_stub then
				executable_stub:revert()
				executable_stub = nil
			end
		end)

		it("returns false when the zellij binary is not on PATH", function()
			executable_stub = stub(vim.fn, "executable")
			executable_stub.returns(0)

			assert.is_false(zellij_manager.is_available())
			assert.stub(executable_stub).was_called_with("zellij")
		end)

		it("returns true when the zellij binary is on PATH", function()
			executable_stub = stub(vim.fn, "executable")
			executable_stub.returns(1)

			assert.is_true(zellij_manager.is_available())
			assert.stub(executable_stub).was_called_with("zellij")
		end)
	end)

	describe("session_name_for", function()
		it("returns the same value for the same directory across calls", function()
			local first = zellij_manager.session_name_for("/a/b")
			local second = zellij_manager.session_name_for("/a/b")

			assert.are.equal(first, second)
		end)

		it("returns different values for different directories", function()
			local first = zellij_manager.session_name_for("/a/b")
			local second = zellij_manager.session_name_for("/a/c")

			assert.are_not.equal(first, second)
		end)

		it("prefixes the session name with 'multiverse-'", function()
			local name = zellij_manager.session_name_for("/a/b")

			assert.is_not_nil(name:find("^multiverse%-"))
		end)
	end)

	describe("open_floating_terminal", function()
		local nvim_create_buf_stub
		local nvim_open_win_stub
		local termopen_stub

		before_each(function()
			nvim_create_buf_stub = stub(vim.api, "nvim_create_buf")
			nvim_create_buf_stub.returns(11)

			nvim_open_win_stub = stub(vim.api, "nvim_open_win")
			nvim_open_win_stub.returns(22)

			termopen_stub = stub(vim.fn, "termopen")
		end)

		after_each(function()
			nvim_create_buf_stub:revert()
			nvim_open_win_stub:revert()
			termopen_stub:revert()

			-- Stub validity to false so this cleanup call can never reach a real
			-- window/buffer id that happens to collide with the fabricated ones
			-- used above (e.g. 22/11/33/44) elsewhere in the test process.
			local win_valid_stub = stub(vim.api, "nvim_win_is_valid")
			win_valid_stub.returns(false)
			local buf_valid_stub = stub(vim.api, "nvim_buf_is_valid")
			buf_valid_stub.returns(false)

			zellij_manager.close_floating_terminal()

			win_valid_stub:revert()
			buf_valid_stub:revert()
		end)

		it("opens a scratch buffer in a floating editor-relative window", function()
			zellij_manager.open_floating_terminal("multiverse-abc")

			assert.stub(nvim_create_buf_stub).was_called_with(false, true)

			local win_config = nvim_open_win_stub.calls[1].refs[3]
			assert.are.equal(11, nvim_open_win_stub.calls[1].refs[1])
			assert.are.equal(true, nvim_open_win_stub.calls[1].refs[2])
			assert.are.equal("editor", win_config.relative)
		end)

		it("runs 'zellij attach --create <session_name>' inside the new buffer", function()
			zellij_manager.open_floating_terminal("multiverse-abc")

			assert.stub(termopen_stub).was_called_with("zellij attach --create " .. vim.fn.shellescape("multiverse-abc"))
		end)

		it("shellescapes the session name before interpolating it into the command", function()
			zellij_manager.open_floating_terminal("multiverse abc")

			assert.stub(termopen_stub).was_called_with(
				"zellij attach --create " .. vim.fn.shellescape("multiverse abc")
			)
		end)

		it("returns the new window id and buffer id", function()
			local win_id, buf_id = zellij_manager.open_floating_terminal("multiverse-abc")

			assert.are.equal(22, win_id)
			assert.are.equal(11, buf_id)
		end)

		it("closes the previously tracked floating terminal before opening a new one", function()
			local nvim_win_is_valid_stub = stub(vim.api, "nvim_win_is_valid")
			nvim_win_is_valid_stub.returns(true)
			local nvim_buf_is_valid_stub = stub(vim.api, "nvim_buf_is_valid")
			nvim_buf_is_valid_stub.returns(true)
			local nvim_win_close_stub = stub(vim.api, "nvim_win_close")
			local nvim_buf_delete_stub = stub(vim.api, "nvim_buf_delete")

			nvim_create_buf_stub.returns(11)
			nvim_open_win_stub.returns(22)
			zellij_manager.open_floating_terminal("multiverse-first")

			nvim_create_buf_stub.returns(33)
			nvim_open_win_stub.returns(44)
			zellij_manager.open_floating_terminal("multiverse-second")

			assert.stub(nvim_win_close_stub).was_called_with(22, true)
			assert.stub(nvim_buf_delete_stub).was_called_with(11, { force = true })

			nvim_win_is_valid_stub:revert()
			nvim_buf_is_valid_stub:revert()
			nvim_win_close_stub:revert()
			nvim_buf_delete_stub:revert()
		end)
	end)

	describe("close_floating_terminal", function()
		local nvim_win_is_valid_stub
		local nvim_buf_is_valid_stub
		local nvim_win_close_stub
		local nvim_buf_delete_stub

		before_each(function()
			nvim_win_is_valid_stub = stub(vim.api, "nvim_win_is_valid")
			nvim_win_is_valid_stub.returns(true)

			nvim_buf_is_valid_stub = stub(vim.api, "nvim_buf_is_valid")
			nvim_buf_is_valid_stub.returns(true)

			nvim_win_close_stub = stub(vim.api, "nvim_win_close")
			nvim_buf_delete_stub = stub(vim.api, "nvim_buf_delete")
		end)

		after_each(function()
			nvim_win_is_valid_stub:revert()
			nvim_buf_is_valid_stub:revert()
			nvim_win_close_stub:revert()
			nvim_buf_delete_stub:revert()
		end)

		it("closes the given window and force-deletes the given buffer when both are valid", function()
			zellij_manager.close_floating_terminal(22, 11)

			assert.stub(nvim_win_close_stub).was_called_with(22, true)
			assert.stub(nvim_buf_delete_stub).was_called_with(11, { force = true })
		end)

		it("does not attempt to close an invalid window or delete an invalid buffer", function()
			nvim_win_is_valid_stub.returns(false)
			nvim_buf_is_valid_stub.returns(false)

			zellij_manager.close_floating_terminal(22, 11)

			assert.stub(nvim_win_close_stub).was_not_called()
			assert.stub(nvim_buf_delete_stub).was_not_called()
		end)

		it("closes the currently tracked floating terminal when called with no arguments", function()
			local nvim_create_buf_stub = stub(vim.api, "nvim_create_buf")
			nvim_create_buf_stub.returns(33)
			local nvim_open_win_stub = stub(vim.api, "nvim_open_win")
			nvim_open_win_stub.returns(44)
			local termopen_stub = stub(vim.fn, "termopen")

			zellij_manager.open_floating_terminal("multiverse-abc")

			nvim_create_buf_stub:revert()
			nvim_open_win_stub:revert()
			termopen_stub:revert()

			zellij_manager.close_floating_terminal()

			assert.stub(nvim_win_close_stub).was_called_with(44, true)
			assert.stub(nvim_buf_delete_stub).was_called_with(33, { force = true })
			assert.is_false(zellij_manager.is_floating_terminal_open())
		end)

		it("is a no-op when nothing is currently tracked and no arguments are given", function()
			zellij_manager.close_floating_terminal()

			assert.stub(nvim_win_close_stub).was_not_called()
			assert.stub(nvim_buf_delete_stub).was_not_called()
		end)
	end)

	describe("reattach_if_running", function()
		local executable_stub
		local systemlist_stub
		local nvim_create_buf_stub
		local nvim_open_win_stub
		local termopen_stub

		before_each(function()
			executable_stub = stub(vim.fn, "executable")
			systemlist_stub = stub(vim.fn, "systemlist")

			nvim_create_buf_stub = stub(vim.api, "nvim_create_buf")
			nvim_create_buf_stub.returns(11)
			nvim_open_win_stub = stub(vim.api, "nvim_open_win")
			nvim_open_win_stub.returns(22)
			termopen_stub = stub(vim.fn, "termopen")
		end)

		after_each(function()
			executable_stub:revert()
			systemlist_stub:revert()
			nvim_create_buf_stub:revert()
			nvim_open_win_stub:revert()
			termopen_stub:revert()
			-- Reset v:shell_error (read-only, so it can't be assigned directly)
			-- in case the shell_error test below left it non-zero.
			real_systemlist("exit 0")

			-- Stub validity to false so this cleanup call can never reach a real
			-- window/buffer id that happens to collide with a fabricated one.
			local win_valid_stub = stub(vim.api, "nvim_win_is_valid")
			win_valid_stub.returns(false)
			local buf_valid_stub = stub(vim.api, "nvim_buf_is_valid")
			buf_valid_stub.returns(false)

			zellij_manager.close_floating_terminal()

			win_valid_stub:revert()
			buf_valid_stub:revert()
		end)

		it("returns false without listing sessions when zellij is not available", function()
			executable_stub.returns(0)

			local result = zellij_manager.reattach_if_running("multiverse-abc")

			assert.is_false(result)
			assert.stub(systemlist_stub).was_not_called()
			assert.stub(termopen_stub).was_not_called()
		end)

		it("opens a floating terminal and returns true when the session is running", function()
			executable_stub.returns(1)
			systemlist_stub.returns({ "other-session", "multiverse-abc" })

			local result = zellij_manager.reattach_if_running("multiverse-abc")

			assert.is_true(result)
			assert.stub(termopen_stub).was_called_with(
				"zellij attach --create " .. vim.fn.shellescape("multiverse-abc")
			)
		end)

		it("does nothing and returns false when the session is not running", function()
			executable_stub.returns(1)
			systemlist_stub.returns({ "other-session" })

			local result = zellij_manager.reattach_if_running("multiverse-abc")

			assert.is_false(result)
			assert.stub(termopen_stub).was_not_called()
		end)

		it("returns false and does not iterate sessions when listing sessions fails", function()
			executable_stub.returns(1)
			systemlist_stub.invokes(function()
				-- Run a real failing shell command so v:shell_error is set the
				-- same way it would be after a real "zellij list-sessions"
				-- failure (v:shell_error can't be stubbed/assigned directly).
				real_systemlist("exit 1")
				return { "garbage output" }
			end)

			local result = zellij_manager.reattach_if_running("multiverse-abc")

			assert.is_false(result)
			assert.stub(termopen_stub).was_not_called()
		end)
	end)

	describe("mark_open / mark_closed / was_open", function()
		local original_getDir
		local temp_dir

		before_each(function()
			original_getDir = persistance.getDir
			temp_dir = vim.fn.tempname()
			persistance.getDir = function()
				return temp_dir
			end
		end)

		after_each(function()
			persistance.getDir = original_getDir
			vim.fn.delete(temp_dir, "rf")
		end)

		it("returns false from was_open before anything has been marked", function()
			assert.is_false(zellij_manager.was_open("multiverse-abc"))
		end)

		it("returns true from was_open after mark_open is called", function()
			zellij_manager.mark_open("multiverse-abc")

			assert.is_true(zellij_manager.was_open("multiverse-abc"))
		end)

		it("returns false from was_open after mark_closed following mark_open", function()
			zellij_manager.mark_open("multiverse-abc")
			zellij_manager.mark_closed("multiverse-abc")

			assert.is_false(zellij_manager.was_open("multiverse-abc"))
		end)

		it("is a harmless no-op to call mark_closed when nothing was ever marked", function()
			assert.has_no.errors(function()
				zellij_manager.mark_closed("multiverse-never-marked")
			end)
			assert.is_false(zellij_manager.was_open("multiverse-never-marked"))
		end)
	end)

	describe("is_floating_terminal_open", function()
		after_each(function()
			-- Stub validity to false so this cleanup call can never reach a real
			-- window/buffer id that happens to collide with a fabricated one.
			local win_valid_stub = stub(vim.api, "nvim_win_is_valid")
			win_valid_stub.returns(false)
			local buf_valid_stub = stub(vim.api, "nvim_buf_is_valid")
			buf_valid_stub.returns(false)

			zellij_manager.close_floating_terminal()

			win_valid_stub:revert()
			buf_valid_stub:revert()
		end)

		it("returns false when nothing has been opened", function()
			assert.is_false(zellij_manager.is_floating_terminal_open())
		end)

		it("returns true after open_floating_terminal is called", function()
			local nvim_create_buf_stub = stub(vim.api, "nvim_create_buf")
			nvim_create_buf_stub.returns(11)
			local nvim_open_win_stub = stub(vim.api, "nvim_open_win")
			nvim_open_win_stub.returns(22)
			local termopen_stub = stub(vim.fn, "termopen")
			local nvim_win_is_valid_stub = stub(vim.api, "nvim_win_is_valid")
			nvim_win_is_valid_stub.returns(true)
			local nvim_buf_is_valid_stub = stub(vim.api, "nvim_buf_is_valid")
			nvim_buf_is_valid_stub.returns(true)

			zellij_manager.open_floating_terminal("multiverse-abc")

			nvim_create_buf_stub:revert()
			nvim_open_win_stub:revert()
			termopen_stub:revert()

			assert.is_true(zellij_manager.is_floating_terminal_open())

			nvim_win_is_valid_stub:revert()
			nvim_buf_is_valid_stub:revert()
		end)

		it("returns false when the tracked window or buffer is no longer valid", function()
			local nvim_create_buf_stub = stub(vim.api, "nvim_create_buf")
			nvim_create_buf_stub.returns(11)
			local nvim_open_win_stub = stub(vim.api, "nvim_open_win")
			nvim_open_win_stub.returns(22)
			local termopen_stub = stub(vim.fn, "termopen")
			local nvim_win_is_valid_stub = stub(vim.api, "nvim_win_is_valid")
			nvim_win_is_valid_stub.returns(true)
			local nvim_buf_is_valid_stub = stub(vim.api, "nvim_buf_is_valid")
			nvim_buf_is_valid_stub.returns(true)

			zellij_manager.open_floating_terminal("multiverse-abc")

			nvim_create_buf_stub:revert()
			nvim_open_win_stub:revert()
			termopen_stub:revert()

			-- Simulate the user manually closing the floating window themselves
			-- (e.g. `:q`), without going through close_floating_terminal().
			nvim_win_is_valid_stub.returns(false)
			nvim_buf_is_valid_stub.returns(false)

			assert.is_false(zellij_manager.is_floating_terminal_open())

			nvim_win_is_valid_stub:revert()
			nvim_buf_is_valid_stub:revert()
		end)
	end)
end)
