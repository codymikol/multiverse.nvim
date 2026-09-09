-- Stub out the telescope.nvim third-party modules required transitively via
-- promptSelectUniverseUsecase -> integrations.telescope, so cli_manager can
-- be required without telescope.nvim being installed.
package.loaded["telescope.actions"] = {}
package.loaded["telescope.pickers"] = {}
package.loaded["telescope.finders"] = {}
package.loaded["telescope.sorters"] = {}
package.loaded["telescope.previewers"] = {}
package.loaded["telescope.actions.state"] = {}
package.loaded["telescope.previewers.utils"] = {}

local stub = require("luassert.stub")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local Multiverse = require("multiverse.data.Multiverse")
local UniverseSummary = require("multiverse.data.UniverseSummary")
local cli_manager = require("multiverse.managers.cli_manager")

describe("cli_manager.complete_universe", function()
	describe("when a universe has a nil name", function()
		local multiverse
		local get_multiverse_stub

		before_each(function()
			multiverse = Multiverse:new({
				UniverseSummary:new("/tmp/foo", "uuid-1", nil, 0),
				UniverseSummary:new("/tmp/bar", "uuid-2", "bar", 0),
			})
			get_multiverse_stub = stub(multiverse_repository, "getMultiverse", function()
				return multiverse
			end)
		end)

		after_each(function()
			get_multiverse_stub:revert()
		end)

		it("does not crash and skips the universe with a nil name", function()
			local completions = cli_manager.complete_universe("", "", 0)

			assert.are.same({ "bar" }, completions)
		end)
	end)
end)
