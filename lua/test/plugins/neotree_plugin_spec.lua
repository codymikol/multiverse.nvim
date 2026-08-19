local neotree_plugin = require("plugins.neotree_plugin")
local stub = require("luassert.stub")

describe("neotree_plugin", function()
	describe("beforeDehydrate", function()
		local vim_cmd_stub

		before_each(function()
			vim_cmd_stub = stub(vim, "cmd")
		end)

		after_each(function()
			vim_cmd_stub:revert()
		end)

		it("should close Neotree exactly once", function()
			neotree_plugin.context.beforeDehydrate({ universe = {} })

			assert.stub(vim_cmd_stub).was.called(1)
			assert.stub(vim_cmd_stub).was.called_with("Neotree close")
		end)
	end)

	describe("afterHydrate", function()
		local vim_cmd_stub
		local getcwd_stub
		local nvim_get_current_win_stub
		local nvim_win_set_width_stub

		before_each(function()
			vim_cmd_stub = stub(vim, "cmd")
			getcwd_stub = stub(vim.fn, "getcwd")
			-- deliberately space/pipe-free: a cwd with ex-command-meaningful characters
			-- would expose the unescaped interpolation tracked separately by #233
			getcwd_stub.returns("/home/foo/bar")
			nvim_get_current_win_stub = stub(vim.api, "nvim_get_current_win")
			nvim_get_current_win_stub.returns(1234)
			nvim_win_set_width_stub = stub(vim.api, "nvim_win_set_width")
		end)

		after_each(function()
			vim_cmd_stub:revert()
			getcwd_stub:revert()
			nvim_get_current_win_stub:revert()
			nvim_win_set_width_stub:revert()
		end)

		it("should issue the expected vim.cmd calls in order", function()
			neotree_plugin.context.afterHydrate({ universe = {} })

			local calls = {}
			for i, call in ipairs(vim_cmd_stub.calls) do
				calls[i] = call.vals[1]
			end

			assert.are.same({
				"wincmd H",
				"vsplit",
				"wincmd h",
				"Neotree reveal current /home/foo/bar",
				"Neotree close",
				"Neotree show",
			}, calls)
		end)

		it("should set the width of the window returned by nvim_get_current_win to 36", function()
			neotree_plugin.context.afterHydrate({ universe = {} })

			assert.stub(nvim_win_set_width_stub).was.called_with(1234, 36)
			assert.stub(nvim_win_set_width_stub).was.called(1)
		end)
	end)

	it("should be named Neotree", function()
		assert.are.equal("Neotree", neotree_plugin.context.name)
	end)

	it("should not implement beforeHydrate or afterDehydrate", function()
		assert.is_nil(neotree_plugin.context.beforeHydrate)
		assert.is_nil(neotree_plugin.context.afterDehydrate)
	end)
end)
