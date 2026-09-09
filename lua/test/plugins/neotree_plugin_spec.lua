local stub = require("luassert.stub")

describe("neotree_plugin", function()
	describe("afterHydrate", function()
		local neotree_plugin
		local nvim_get_current_win_stub
		local nvim_win_set_width_stub
		local vim_cmd_stub
		local getcwd_stub
		local original_multiverse_neotree_width

		before_each(function()
			original_multiverse_neotree_width = vim.g.multiverse_neotree_width

			nvim_get_current_win_stub = stub(vim.api, "nvim_get_current_win")
			nvim_get_current_win_stub.returns(1234)

			nvim_win_set_width_stub = stub(vim.api, "nvim_win_set_width")
			vim_cmd_stub = stub(vim, "cmd")
			getcwd_stub = stub(vim.fn, "getcwd")
			getcwd_stub.returns("/some/dir")

			neotree_plugin = require("plugins.neotree_plugin")
		end)

		after_each(function()
			vim.g.multiverse_neotree_width = original_multiverse_neotree_width

			nvim_get_current_win_stub:revert()
			nvim_win_set_width_stub:revert()
			vim_cmd_stub:revert()
			getcwd_stub:revert()

			package.loaded["plugins.neotree_plugin"] = nil
		end)

		describe("when vim.g.multiverse_neotree_width is not set", function()
			before_each(function()
				vim.g.multiverse_neotree_width = nil
			end)

			it("sets the neotree window width to the default of 36", function()
				neotree_plugin.context.afterHydrate({})

				assert.stub(nvim_win_set_width_stub).was.called_with(1234, 36)
			end)
		end)

		describe("when vim.g.multiverse_neotree_width is set", function()
			before_each(function()
				vim.g.multiverse_neotree_width = 50
			end)

			it("sets the neotree window width to the custom value", function()
				neotree_plugin.context.afterHydrate({})

				assert.stub(nvim_win_set_width_stub).was.called_with(1234, 50)
			end)
		end)
	end)
end)
