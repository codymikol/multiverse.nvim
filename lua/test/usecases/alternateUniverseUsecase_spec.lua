local stub = require("luassert.stub")

local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local multiverse_manager = require("multiverse.managers.multiverse_manager")
local current_universe_store = require("multiverse.store.current_universe_store")
local alternateUniverseUsecase = require("multiverse.usecases.alternateUniverseUsecase")

describe("alternateUniverseUsecase.run", function()
	local getMultiverse_stub
	local load_universe_stub
	local get_previous_universe_stub
	local notify_stub

	before_each(function()
		getMultiverse_stub = stub(multiverse_repository, "getMultiverse")
		load_universe_stub = stub(multiverse_manager, "load_universe")
		get_previous_universe_stub = stub(current_universe_store, "get_previous_universe")
		notify_stub = stub(vim, "notify")
	end)

	after_each(function()
		getMultiverse_stub:revert()
		load_universe_stub:revert()
		get_previous_universe_stub:revert()
		notify_stub:revert()
	end)

	describe("when there is no previous universe tracked", function()
		before_each(function()
			get_previous_universe_stub.returns(nil)
		end)

		it("should notify the user and not load a universe or fetch the multiverse", function()
			alternateUniverseUsecase.run()

			assert.stub(notify_stub).was.called_with("No previous universe to alternate to.", vim.log.levels.INFO)
			assert.stub(getMultiverse_stub).was_not.called()
			assert.stub(load_universe_stub).was_not.called()
		end)
	end)

	describe("when the previous universe is tracked but no longer exists", function()
		before_each(function()
			get_previous_universe_stub.returns("gone-name")
			local multiverse = {
				getUniverseByName = function()
					return nil
				end,
			}
			getMultiverse_stub.returns(multiverse)
		end)

		it("should notify the user and not load a universe", function()
			alternateUniverseUsecase.run()

			assert.stub(notify_stub).was.called_with(
				"Universe with name 'gone-name' not found.",
				vim.log.levels.INFO
			)
			assert.stub(load_universe_stub).was_not.called()
		end)
	end)

	describe("when the previous universe is tracked and found", function()
		local multiverse
		local universe_summary

		before_each(function()
			get_previous_universe_stub.returns("some-name")
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

		it("should load the universe exactly once", function()
			alternateUniverseUsecase.run()

			assert.stub(load_universe_stub).was.called(1)
			assert.stub(load_universe_stub).was.called_with(multiverse, universe_summary)
			assert.stub(notify_stub).was_not.called()
		end)
	end)

	describe("when getMultiverse throws", function()
		before_each(function()
			get_previous_universe_stub.returns("some-name")
			getMultiverse_stub.invokes(function()
				error("boom")
			end)
		end)

		it("should notify a generic failure and not load a universe", function()
			alternateUniverseUsecase.run()

			assert.stub(notify_stub).was.called_with(
				"Failed to alternate universe, check MultiverseLog for more information",
				vim.log.levels.ERROR
			)
			assert.stub(load_universe_stub).was_not.called()
		end)
	end)
end)
