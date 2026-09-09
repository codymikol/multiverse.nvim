local stub = require("luassert.stub")

local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local multiverse_manager = require("multiverse.managers.multiverse_manager")
local openUniverseUsecase = require("multiverse.usecases.openUniverseUsecase")

describe("openUniverseUsecase.run", function()
	local getMultiverse_stub
	local load_universe_stub
	local save_multiverse_stub
	local notify_stub

	before_each(function()
		getMultiverse_stub = stub(multiverse_repository, "getMultiverse")
		load_universe_stub = stub(multiverse_manager, "load_universe")
		save_multiverse_stub = stub(multiverse_repository, "save_multiverse")
		notify_stub = stub(vim, "notify")
	end)

	after_each(function()
		getMultiverse_stub:revert()
		load_universe_stub:revert()
		save_multiverse_stub:revert()
		notify_stub:revert()
	end)

	describe("when the universe is found", function()
		local multiverse
		local universe_summary

		before_each(function()
			universe_summary = { name = "some-name", lastExplored = 111 }
			multiverse = {
				getUniverseByName = function(_, name)
					if name == "some-name" then
						return universe_summary
					end
					return nil
				end,
			}
			getMultiverse_stub.returns(multiverse)
		end)

		it("should load the universe exactly once and not save the multiverse directly", function()
			openUniverseUsecase.run("some-name")

			assert.stub(load_universe_stub).was.called(1)
			assert.stub(load_universe_stub).was.called_with(multiverse, universe_summary)
			assert.stub(save_multiverse_stub).was_not.called()
			assert.stub(notify_stub).was_not.called()
			assert.are.equal(111, universe_summary.lastExplored)
		end)
	end)

	describe("when the universe is not found", function()
		before_each(function()
			local multiverse = {
				getUniverseByName = function()
					return nil
				end,
			}
			getMultiverse_stub.returns(multiverse)
		end)

		it("should notify the user and not load a universe", function()
			openUniverseUsecase.run("missing-name")

			assert.stub(notify_stub).was.called_with(
				"Universe with name 'missing-name' not found.",
				vim.log.levels.INFO
			)
			assert.stub(load_universe_stub).was_not.called()
		end)
	end)

	describe("when getMultiverse throws", function()
		before_each(function()
			getMultiverse_stub.invokes(function()
				error("boom")
			end)
		end)

		it("should notify a generic failure and not load a universe", function()
			openUniverseUsecase.run("some-name")

			assert.stub(notify_stub).was.called_with(
				"Failed to open universe, check MultiverseLog for more information",
				vim.log.levels.ERROR
			)
			assert.stub(load_universe_stub).was_not.called()
		end)
	end)
end)
