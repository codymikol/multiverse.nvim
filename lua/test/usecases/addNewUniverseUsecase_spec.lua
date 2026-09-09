local stub = require("luassert.stub")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local universe_repository = require("multiverse.repositories.universe_repository")
local multiverse_manager = require("multiverse.managers.multiverse_manager")
local uuid_manager = require("multiverse.managers.uuid_manager")
local timestamp_manager = require("multiverse.managers.timestamp_manager")
local Multiverse = require("multiverse.data.Multiverse")
local addNewUniverseUsecase = require("multiverse.usecases.addNewUniverseUsecase")

describe("addNewUniverseUsecase.run", function()
	local multiverse
	local get_multiverse_stub
	local save_multiverse_stub
	local save_universe_stub
	local notify_stub

	before_each(function()
		multiverse = Multiverse:new({})
		get_multiverse_stub = stub(multiverse_repository, "getMultiverse", function()
			return multiverse
		end)
		save_multiverse_stub = stub(multiverse_repository, "save_multiverse")
		save_universe_stub = stub(universe_repository, "save_universe")
		notify_stub = stub(vim, "notify")
	end)

	after_each(function()
		get_multiverse_stub:revert()
		save_multiverse_stub:revert()
		save_universe_stub:revert()
		notify_stub:revert()
	end)

	for _, case in ipairs({
		{ description = "when name is nil", name = nil },
		{ description = "when name is an empty string", name = "" },
	}) do
		describe(case.description, function()
			it("notifies an ERROR and does not save the universe or multiverse", function()
				addNewUniverseUsecase.run(case.name, "/tmp/foo")

				assert.stub(notify_stub).was.called_with("Universe name is required", vim.log.levels.ERROR)
				assert.stub(save_multiverse_stub).was_not_called()
				assert.stub(save_universe_stub).was_not_called()
			end)
		end)
	end

	describe("when name is valid", function()
		local load_universe_stub
		local uuid_create_stub
		local timestamp_now_stub

		before_each(function()
			load_universe_stub = stub(multiverse_manager, "load_universe")
			uuid_create_stub = stub(uuid_manager, "create", function()
				return "uuid-1"
			end)
			timestamp_now_stub = stub(timestamp_manager, "now", function()
				return 0
			end)
		end)

		after_each(function()
			load_universe_stub:revert()
			uuid_create_stub:revert()
			timestamp_now_stub:revert()
		end)

		it("saves the multiverse and universe and does not notify the name-required error", function()
			addNewUniverseUsecase.run("foo", "/tmp/foo")

			assert.stub(save_multiverse_stub).was.called()
			assert.stub(save_universe_stub).was.called()
			assert.stub(notify_stub).was_not.called_with("Universe name is required", vim.log.levels.ERROR)
		end)
	end)
end)
