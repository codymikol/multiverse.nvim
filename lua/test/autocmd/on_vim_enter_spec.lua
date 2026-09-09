local on_vim_enter = require("multiverse.autocmd.on_vim_enter")

local augroup_name = "multiverse_on_vim_enter"

describe("on_vim_enter", function()
	describe("register", function()
		after_each(function()
			pcall(vim.api.nvim_del_augroup_by_name, augroup_name)
		end)

		it("should only register a single VimEnter autocmd when called multiple times", function()
			on_vim_enter.register()
			on_vim_enter.register()

			local autocmds = vim.api.nvim_get_autocmds({ group = augroup_name, event = "VimEnter" })

			assert.equals(1, #autocmds)
			assert.equals("VimEnter", autocmds[1].event)
		end)
	end)

	describe("VimEnter autocmd", function()
		local original_on_vim_enter
		local call_count

		-- luassert.stub's callable table crashes nvim_create_autocmd
		-- ("Invalid 'callback': Lua failed to grow stack") when used as the
		-- callback, so swap the function directly instead of stubbing it.
		before_each(function()
			original_on_vim_enter = on_vim_enter.on_vim_enter
			call_count = 0
			on_vim_enter.on_vim_enter = function()
				call_count = call_count + 1
			end
		end)

		after_each(function()
			on_vim_enter.on_vim_enter = original_on_vim_enter
			pcall(vim.api.nvim_del_augroup_by_name, augroup_name)
		end)

		it("should invoke on_vim_enter exactly once", function()
			on_vim_enter.register()

			vim.api.nvim_exec_autocmds("VimEnter", { group = augroup_name })

			assert.equals(1, call_count)
		end)

		it("should invoke on_vim_enter exactly once even when register() is called multiple times", function()
			on_vim_enter.register()
			on_vim_enter.register()

			vim.api.nvim_exec_autocmds("VimEnter", { group = augroup_name })

			assert.equals(1, call_count)
		end)
	end)
end)
