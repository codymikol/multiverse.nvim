local stub = require("luassert.stub")

-- Inject a fake telescope integration before requiring anything else so that
-- no transitive require (this spec's or the usecase module's) ever reaches
-- the real "integrations.telescope" module, which itself requires real
-- telescope.nvim modules that are not available in CI.
local telescope_integration = { prompt_select_universe = function() end }
package.loaded["integrations.telescope"] = telescope_integration

local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local promptSelectUniverseUsecase = require("multiverse.usecases.promptSelectUniverseUsecase")

local function makeUniverseSummary(directory, lastExplored)
	return { directory = directory, lastExplored = lastExplored }
end

describe("promptSelectUniverseUsecase.run", function()
	local getMultiverse_stub
	local prompt_select_universe_stub
	local notify_stub

	before_each(function()
		getMultiverse_stub = stub(multiverse_repository, "getMultiverse")
		prompt_select_universe_stub = stub(telescope_integration, "prompt_select_universe")
		notify_stub = stub(vim, "notify")
	end)

	after_each(function()
		getMultiverse_stub:revert()
		prompt_select_universe_stub:revert()
		notify_stub:revert()
	end)

	describe("when one of the universes has a nil lastExplored", function()
		before_each(function()
			getMultiverse_stub.returns({
				universes = {
					makeUniverseSummary("/home/foo", nil),
					makeUniverseSummary("/home/bar", 100),
				},
			})
		end)

		it("should not crash sorting and should still prompt the user to select a universe", function()
			promptSelectUniverseUsecase.run()

			assert.stub(prompt_select_universe_stub).was.called(1)
			assert.stub(notify_stub).was_not.called_with(
				"Failed to open universe, check MultiverseLog for more information",
				vim.log.levels.ERROR
			)
		end)
	end)

	describe("when one of the universes has a non-numeric lastExplored", function()
		before_each(function()
			getMultiverse_stub.returns({
				universes = {
					makeUniverseSummary("/home/foo", "not-a-number"),
					makeUniverseSummary("/home/bar", 100),
				},
			})
		end)

		it("should not crash sorting and should still prompt the user to select a universe", function()
			promptSelectUniverseUsecase.run()

			assert.stub(prompt_select_universe_stub).was.called(1)
			assert.stub(notify_stub).was_not.called_with(
				"Failed to open universe, check MultiverseLog for more information",
				vim.log.levels.ERROR
			)
		end)
	end)

	describe("when all universes have a numeric lastExplored", function()
		before_each(function()
			getMultiverse_stub.returns({
				universes = {
					makeUniverseSummary("/home/oldest", 100),
					makeUniverseSummary("/home/newest", 300),
					makeUniverseSummary("/home/middle", 200),
				},
			})
		end)

		it("should sort universes descending by lastExplored before prompting", function()
			promptSelectUniverseUsecase.run()

			assert.stub(prompt_select_universe_stub).was.called(1)

			local sorted_universes = prompt_select_universe_stub.calls[1].refs[1]

			assert.are.equal("/home/newest", sorted_universes[1].directory)
			assert.are.equal("/home/middle", sorted_universes[2].directory)
			assert.are.equal("/home/oldest", sorted_universes[3].directory)
		end)
	end)
end)
