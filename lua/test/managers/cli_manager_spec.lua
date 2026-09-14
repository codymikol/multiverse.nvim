local stub = require("luassert.stub")
local match = require("luassert.match")

-- Inject a fake telescope integration before requiring cli_manager so that
-- its transitive require of "integrations.telescope" never reaches the real
-- telescope.nvim modules, which are not available in CI.
package.loaded["integrations.telescope"] = { prompt_select_universe = function() end }

local cli_manager = require("multiverse.managers.cli_manager")

describe("cli_manager.registerCommands", function()
	describe("MultiverseLog", function()
		local create_user_command_stub

		before_each(function()
			create_user_command_stub = stub(vim.api, "nvim_create_user_command")
		end)

		after_each(function()
			create_user_command_stub:revert()
		end)

		it("registers a MultiverseLog user command", function()
			cli_manager.registerCommands()

			assert.stub(create_user_command_stub).was.called_with(
				"MultiverseLog",
				match._,
				match._
			)
		end)
	end)
end)
