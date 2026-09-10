local stub = require("luassert.stub")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local universe_repository = require("multiverse.repositories.universe_repository")
local Multiverse = require("multiverse.data.Multiverse")
local UniverseSummary = require("multiverse.data.UniverseSummary")
local removeUniverseUsecase = require("multiverse.usecases.removeUniverseUsecase")

describe("removeUniverseUsecase.run", function()
	describe("when the universe is not found", function()
		local multiverse
		local get_multiverse_stub
		local save_multiverse_stub
		local delete_universe_stub
		local notify_stub
		local confirm_stub

		before_each(function()
			multiverse = Multiverse:new({
				UniverseSummary:new("/tmp/foo", "uuid-1", "foo", 0),
			})
			get_multiverse_stub = stub(multiverse_repository, "getMultiverse", function()
				return multiverse
			end)
			save_multiverse_stub = stub(multiverse_repository, "save_multiverse")
			delete_universe_stub = stub(universe_repository, "deleteUniverse")
			notify_stub = stub(vim, "notify")
			confirm_stub = stub(vim.fn, "confirm")
		end)

		after_each(function()
			get_multiverse_stub:revert()
			save_multiverse_stub:revert()
			delete_universe_stub:revert()
			notify_stub:revert()
			confirm_stub:revert()
		end)

		it("notifies an ERROR and does not attempt to delete or save", function()
			removeUniverseUsecase.run("does-not-exist")

			assert.stub(notify_stub).was.called_with("Universe not found: does-not-exist", vim.log.levels.ERROR)
			assert.stub(confirm_stub).was_not_called()
			assert.stub(delete_universe_stub).was_not_called()
			assert.stub(save_multiverse_stub).was_not_called()
		end)
	end)

	describe("when the universe is found and delete succeeds", function()
		local multiverse
		local target_universe
		local get_multiverse_stub
		local save_multiverse_stub
		local delete_universe_stub
		local notify_stub
		local confirm_stub

		before_each(function()
			target_universe = UniverseSummary:new("/tmp/foo", "uuid-1", "foo", 0)
			multiverse = Multiverse:new({
				target_universe,
				UniverseSummary:new("/tmp/bar", "uuid-2", "bar", 0),
			})
			get_multiverse_stub = stub(multiverse_repository, "getMultiverse", function()
				return multiverse
			end)
			save_multiverse_stub = stub(multiverse_repository, "save_multiverse")
			delete_universe_stub = stub(universe_repository, "deleteUniverse", function()
				return true, nil
			end)
			notify_stub = stub(vim, "notify")
			confirm_stub = stub(vim.fn, "confirm", function()
				return 1
			end)
		end)

		after_each(function()
			get_multiverse_stub:revert()
			save_multiverse_stub:revert()
			delete_universe_stub:revert()
			notify_stub:revert()
			confirm_stub:revert()
		end)

		it("prompts for confirmation, calls deleteUniverse with the matching universe, removes it and saves", function()
			removeUniverseUsecase.run("foo")

			assert.stub(confirm_stub).was.called_with("Remove universe 'foo'? This cannot be undone.", "&Yes\n&No", 2)
			assert.stub(delete_universe_stub).was.called_with(target_universe)
			assert.are.equal(1, #multiverse.universes)
			assert.are.equal("bar", multiverse.universes[1].name)
			assert.stub(save_multiverse_stub).was.called_with(multiverse)
			assert.stub(notify_stub).was_not_called()
		end)
	end)

	describe("when the universe is found and delete fails", function()
		local multiverse
		local target_universe
		local get_multiverse_stub
		local save_multiverse_stub
		local delete_universe_stub
		local notify_stub
		local confirm_stub
		local delete_err = "Failed to delete universe file: /tmp/foo/universe-uuid-1.json, os returned error - permission denied"

		before_each(function()
			target_universe = UniverseSummary:new("/tmp/foo", "uuid-1", "foo", 0)
			multiverse = Multiverse:new({
				target_universe,
			})
			get_multiverse_stub = stub(multiverse_repository, "getMultiverse", function()
				return multiverse
			end)
			save_multiverse_stub = stub(multiverse_repository, "save_multiverse")
			delete_universe_stub = stub(universe_repository, "deleteUniverse", function()
				return false, delete_err
			end)
			notify_stub = stub(vim, "notify")
			confirm_stub = stub(vim.fn, "confirm", function()
				return 1
			end)
		end)

		after_each(function()
			get_multiverse_stub:revert()
			save_multiverse_stub:revert()
			delete_universe_stub:revert()
			notify_stub:revert()
			confirm_stub:revert()
		end)

		it("notifies an ERROR with the delete error, does not save and does not remove the entry", function()
			removeUniverseUsecase.run("foo")

			assert.stub(notify_stub).was.called_with(delete_err, vim.log.levels.ERROR)
			assert.stub(save_multiverse_stub).was_not_called()
			assert.are.equal(1, #multiverse.universes)
			assert.are.equal(target_universe, multiverse.universes[1])
		end)
	end)

	describe("when the user declines the confirmation prompt", function()
		local multiverse
		local target_universe
		local get_multiverse_stub
		local save_multiverse_stub
		local delete_universe_stub
		local notify_stub
		local confirm_stub

		before_each(function()
			target_universe = UniverseSummary:new("/tmp/foo", "uuid-1", "foo", 0)
			multiverse = Multiverse:new({
				target_universe,
			})
			get_multiverse_stub = stub(multiverse_repository, "getMultiverse", function()
				return multiverse
			end)
			save_multiverse_stub = stub(multiverse_repository, "save_multiverse")
			delete_universe_stub = stub(universe_repository, "deleteUniverse", function()
				return true, nil
			end)
			notify_stub = stub(vim, "notify")
			confirm_stub = stub(vim.fn, "confirm", function()
				return 2
			end)
		end)

		after_each(function()
			get_multiverse_stub:revert()
			save_multiverse_stub:revert()
			delete_universe_stub:revert()
			notify_stub:revert()
			confirm_stub:revert()
		end)

		it("does not delete, remove or save the universe", function()
			removeUniverseUsecase.run("foo")

			assert.stub(notify_stub).was_not_called()
			assert.stub(delete_universe_stub).was_not_called()
			assert.stub(save_multiverse_stub).was_not_called()
			assert.are.equal(1, #multiverse.universes)
			assert.are.equal(target_universe, multiverse.universes[1])
		end)
	end)

	describe("when getting or deleting the universe raises an error", function()
		local get_multiverse_stub
		local log_error_stub
		local notify_stub
		local log = require("multiverse.log")

		before_each(function()
			get_multiverse_stub = stub(multiverse_repository, "getMultiverse", function()
				error("boom")
			end)
			log_error_stub = stub(log, "error")
			notify_stub = stub(vim, "notify")
		end)

		after_each(function()
			get_multiverse_stub:revert()
			log_error_stub:revert()
			notify_stub:revert()
		end)

		it("notifies a generic ERROR and logs the underlying error", function()
			removeUniverseUsecase.run("foo")

			assert.stub(notify_stub).was.called_with(
				"Failed to remove universe, check MultiverseLog for more information",
				vim.log.levels.ERROR
			)
			assert.stub(log_error_stub).was.called(1)
		end)
	end)
end)
