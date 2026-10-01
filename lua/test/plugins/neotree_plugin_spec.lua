local stub = require("luassert.stub")

local spec_path = debug.getinfo(1, "S").source:sub(2)
local source_path = spec_path:gsub("test/plugins/neotree_plugin_spec%.lua$", "plugins/neotree_plugin.lua")

local function read_source()
	local file = io.open(source_path, "r")
	assert.is_not_nil(file, "expected to find " .. source_path)

	local contents = file:read("*a")
	file:close()

	return contents
end

describe("plugins.neotree_plugin", function()
	describe("source file contents", function()
		it("does not contain the stale '30% of the total columns' comment", function()
			assert.is_nil(read_source():find("Calculate 30% of the total columns", 1, true))
		end)

		it("notes that the reveal/close/show sequence is unverified before simplifying", function()
			assert.is_not_nil(read_source():find("left as-is", 1, true))
		end)
	end)

	describe("context.beforeDehydrate", function()
		local neotree_plugin
		local vim_cmd_stub

		before_each(function()
			package.loaded["plugins.neotree_plugin"] = nil
			neotree_plugin = require("plugins.neotree_plugin")
			vim_cmd_stub = stub(vim, "cmd")
		end)

		after_each(function()
			vim_cmd_stub:revert()
			package.loaded["plugins.neotree_plugin"] = nil
		end)

		it("closes Neotree", function()
			neotree_plugin.context.beforeDehydrate({})

			assert.stub(vim_cmd_stub).was.called(1)
			assert.stub(vim_cmd_stub).was.called_with("Neotree close")
		end)
	end)

	describe("context.afterHydrate", function()
		local neotree_plugin
		-- shared log so call order across vim.cmd and nvim_win_set_width can be asserted together
		local call_log
		local vim_cmd_stub
		local nvim_win_set_width_stub
		local getcwd_stub
		local nvim_get_current_win_stub

		before_each(function()
			package.loaded["plugins.neotree_plugin"] = nil
			neotree_plugin = require("plugins.neotree_plugin")

			call_log = {}

			vim_cmd_stub = stub(vim, "cmd", function(command)
				table.insert(call_log, { name = "cmd", arg = command })
			end)

			nvim_win_set_width_stub = stub(vim.api, "nvim_win_set_width", function(win_id, width)
				table.insert(call_log, { name = "nvim_win_set_width", win_id = win_id, width = width })
			end)

			getcwd_stub = stub(vim.fn, "getcwd")
			getcwd_stub.returns("/home/test/project")

			nvim_get_current_win_stub = stub(vim.api, "nvim_get_current_win")
			nvim_get_current_win_stub.returns(4242)
		end)

		after_each(function()
			vim_cmd_stub:revert()
			nvim_win_set_width_stub:revert()
			getcwd_stub:revert()
			nvim_get_current_win_stub:revert()
			package.loaded["plugins.neotree_plugin"] = nil
		end)

		local function expected_call_log(reveal_arg)
			return {
				{ name = "cmd", arg = "wincmd H" },
				{ name = "cmd", arg = "vsplit" },
				{ name = "cmd", arg = "wincmd h" },
				{ name = "nvim_win_set_width", win_id = 4242, width = 36 },
				{ name = "cmd", arg = "Neotree reveal current " .. reveal_arg },
				{ name = "cmd", arg = "Neotree close" },
				{ name = "cmd", arg = "Neotree show" },
			}
		end

		it("pins the exact call sequence used to work around Neotree hijacking the multiverse window", function()
			neotree_plugin.context.afterHydrate({})

			assert.same(expected_call_log("/home/test/project"), call_log)
		end)

		it("escapes special characters in cwd before building the reveal ex command", function()
			getcwd_stub.returns("/home/test/proj|ect")

			neotree_plugin.context.afterHydrate({})

			assert.same(expected_call_log("/home/test/proj\\|ect"), call_log)
		end)
	end)
end)
