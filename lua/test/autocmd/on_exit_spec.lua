local multiverse_manager = require("multiverse.managers.multiverse_manager")
local on_exit = require("multiverse.autocmd.on_exit")
local stub = require("luassert.stub")

describe("on_exit", function()
	describe("register", function()
		after_each(function()
			pcall(vim.api.nvim_del_augroup_by_name, "multiverse_on_exit")
		end)

		it("should only register a single QuitPre autocmd when called multiple times", function()
			on_exit.register()
			on_exit.register()

			local autocmds = vim.api.nvim_get_autocmds({ group = "multiverse_on_exit", event = "QuitPre" })

			assert.equals(1, #autocmds)
		end)
	end)

	describe("QuitPre autocmd", function()
		local save_stub

		before_each(function()
			save_stub = stub(multiverse_manager, "save")
		end)

		after_each(function()
			save_stub:revert()
			pcall(vim.api.nvim_del_augroup_by_name, "multiverse_on_exit")
		end)

		it("should invoke multiverse_manager.save() exactly once", function()
			on_exit.register()

			vim.api.nvim_exec_autocmds("QuitPre", {})

			assert.stub(save_stub).was.called(1)
		end)

		it("should invoke multiverse_manager.save() exactly once even when register() is called multiple times", function()
			on_exit.register()
			on_exit.register()

			vim.api.nvim_exec_autocmds("QuitPre", {})

			assert.stub(save_stub).was.called(1)
		end)
	end)
end)
