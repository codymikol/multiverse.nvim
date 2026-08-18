local multiverse_manager = require("multiverse.managers.multiverse_manager")
local on_exit = require("multiverse.autocmd.on_exit")
local stub = require("luassert.stub")

local augroup_name = "multiverse_on_exit"

describe("on_exit", function()
	describe("register", function()
		local save_stub

		before_each(function()
			save_stub = stub(multiverse_manager, "save")
		end)

		after_each(function()
			save_stub:revert()
			pcall(vim.api.nvim_del_augroup_by_name, augroup_name)
		end)

		it("should only register a single QuitPre autocmd when called multiple times", function()
			on_exit.register()
			on_exit.register()

			local autocmds = vim.api.nvim_get_autocmds({ group = augroup_name, event = "QuitPre" })

			assert.equals(1, #autocmds)
			assert.equals("QuitPre", autocmds[1].event)
		end)
	end)

	describe("QuitPre autocmd", function()
		local save_stub

		before_each(function()
			save_stub = stub(multiverse_manager, "save")
		end)

		after_each(function()
			save_stub:revert()
			pcall(vim.api.nvim_del_augroup_by_name, augroup_name)
		end)

		it("should invoke multiverse_manager.save() exactly once", function()
			on_exit.register()

			vim.api.nvim_exec_autocmds("QuitPre", { group = augroup_name })

			assert.stub(save_stub).was.called(1)
		end)

		it("should invoke multiverse_manager.save() exactly once even when register() is called multiple times", function()
			on_exit.register()
			on_exit.register()

			vim.api.nvim_exec_autocmds("QuitPre", { group = augroup_name })

			assert.stub(save_stub).was.called(1)
		end)
	end)
end)
