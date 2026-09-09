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

			package.loaded["plugins.neotree_plugin"] = nil
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

		describe("when vim.g.multiverse_neotree_width is a non-integer float", function()
			before_each(function()
				vim.g.multiverse_neotree_width = 48.7
			end)

			it("falls back to the default of 36", function()
				neotree_plugin.context.afterHydrate({})

				assert.stub(nvim_win_set_width_stub).was.called_with(1234, 36)
			end)
		end)

		describe("when vim.g.multiverse_neotree_width is 0", function()
			before_each(function()
				vim.g.multiverse_neotree_width = 0
			end)

			it("falls back to the default of 36", function()
				neotree_plugin.context.afterHydrate({})

				assert.stub(nvim_win_set_width_stub).was.called_with(1234, 36)
			end)
		end)

		describe("when vim.g.multiverse_neotree_width is negative", function()
			before_each(function()
				vim.g.multiverse_neotree_width = -10
			end)

			it("falls back to the default of 36", function()
				neotree_plugin.context.afterHydrate({})

				assert.stub(nvim_win_set_width_stub).was.called_with(1234, 36)
			end)
		end)

		describe("when vim.g.multiverse_neotree_width is a string", function()
			before_each(function()
				vim.g.multiverse_neotree_width = "40"
			end)

			it("falls back to the default of 36", function()
				neotree_plugin.context.afterHydrate({})

				assert.stub(nvim_win_set_width_stub).was.called_with(1234, 36)
			end)
		end)

		describe("when vim.g.multiverse_neotree_width is a table", function()
			before_each(function()
				vim.g.multiverse_neotree_width = {}
			end)

			it("falls back to the default of 36", function()
				neotree_plugin.context.afterHydrate({})

				assert.stub(nvim_win_set_width_stub).was.called_with(1234, 36)
			end)
		end)

		describe("when vim.g.multiverse_neotree_width is a non-finite number that passes validation but nvim rejects", function()
			before_each(function()
				vim.g.multiverse_neotree_width = math.huge

				-- Simulate nvim_win_set_width's real behavior: it raises for
				-- non-integral/out-of-range widths like math.huge, even though
				-- resolve_neotree_width()'s own guard lets it through.
				nvim_win_set_width_stub.invokes(function(_, width)
					if width == math.huge or width ~= width then
						error("Invalid 'width': Number is not integral")
					end
				end)
			end)

			it("falls back to the default of 36 after the initial call fails", function()
				neotree_plugin.context.afterHydrate({})

				assert.stub(nvim_win_set_width_stub).was.called_with(1234, 36)
			end)
		end)
	end)
end)
