local stub = require("luassert.stub")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local universe_repository = require("multiverse.repositories.universe_repository")
local zellij_manager = require("multiverse.managers.zellij_manager")
local persistance = require("multiverse.repositories.persistance")
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
		local mark_closed_stub

		before_each(function()
			multiverse = Multiverse:new({
				UniverseSummary:new({ directory = "/tmp/foo", uuid = "uuid-1", name = "foo", lastExplored = 0 }),
			})
			get_multiverse_stub = stub(multiverse_repository, "getMultiverse", function()
				return multiverse
			end)
			save_multiverse_stub = stub(multiverse_repository, "save_multiverse")
			delete_universe_stub = stub(universe_repository, "deleteUniverse")
			notify_stub = stub(vim, "notify")
			confirm_stub = stub(vim.fn, "confirm")
			mark_closed_stub = stub(zellij_manager, "mark_closed")
		end)

		after_each(function()
			get_multiverse_stub:revert()
			save_multiverse_stub:revert()
			delete_universe_stub:revert()
			notify_stub:revert()
			confirm_stub:revert()
			mark_closed_stub:revert()
		end)

		it("notifies an ERROR and does not attempt to delete or save", function()
			removeUniverseUsecase.run("does-not-exist")

			assert.stub(notify_stub).was.called_with("Universe not found: does-not-exist", vim.log.levels.ERROR)
			assert.stub(confirm_stub).was_not_called()
			assert.stub(delete_universe_stub).was_not_called()
			assert.stub(save_multiverse_stub).was_not_called()
			assert.stub(mark_closed_stub).was_not_called()
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
		local mark_closed_stub
		local getDir_stub
		local temp_dir

		before_each(function()
			target_universe = UniverseSummary:new({ directory = "/tmp/foo", uuid = "uuid-1", name = "foo", lastExplored = 0 })
			multiverse = Multiverse:new({
				target_universe,
				UniverseSummary:new({ directory = "/tmp/bar", uuid = "uuid-2", name = "bar", lastExplored = 0 }),
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
			mark_closed_stub = stub(zellij_manager, "mark_closed")
			temp_dir = vim.fn.tempname()
			getDir_stub = stub(persistance, "getDir", function()
				return temp_dir
			end)
		end)

		after_each(function()
			get_multiverse_stub:revert()
			save_multiverse_stub:revert()
			delete_universe_stub:revert()
			notify_stub:revert()
			confirm_stub:revert()
			mark_closed_stub:revert()
			getDir_stub:revert()
			vim.fn.delete(temp_dir, "rf")
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

		it("cleans up the orphaned zellij open-flag for the removed universe's directory", function()
			removeUniverseUsecase.run("foo")

			assert.stub(mark_closed_stub).was.called_with(zellij_manager.session_name_for(target_universe.directory))
		end)

		it("actually deletes the on-disk zellij open-flag file for the removed universe", function()
			mark_closed_stub:revert()
			local session_name = zellij_manager.session_name_for(target_universe.directory)
			zellij_manager.mark_open(session_name)
			assert.is_true(zellij_manager.was_open(session_name))

			removeUniverseUsecase.run("foo")

			assert.is_false(zellij_manager.was_open(session_name))
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
		local mark_closed_stub
		local delete_err = "Failed to delete universe file: /tmp/foo/universe-uuid-1.json, os returned error - permission denied"

		before_each(function()
			target_universe = UniverseSummary:new({ directory = "/tmp/foo", uuid = "uuid-1", name = "foo", lastExplored = 0 })
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
			mark_closed_stub = stub(zellij_manager, "mark_closed")
		end)

		after_each(function()
			get_multiverse_stub:revert()
			save_multiverse_stub:revert()
			delete_universe_stub:revert()
			notify_stub:revert()
			confirm_stub:revert()
			mark_closed_stub:revert()
		end)

		it("notifies an ERROR with the delete error, does not save and does not remove the entry", function()
			removeUniverseUsecase.run("foo")

			assert.stub(notify_stub).was.called_with(delete_err, vim.log.levels.ERROR)
			assert.stub(confirm_stub).was.called()
			assert.stub(save_multiverse_stub).was_not_called()
			assert.are.equal(1, #multiverse.universes)
			assert.are.equal(target_universe, multiverse.universes[1])
			assert.stub(mark_closed_stub).was_not_called()
		end)
	end)

	describe("when the user does not confirm the removal", function()
		local multiverse
		local target_universe
		local get_multiverse_stub
		local save_multiverse_stub
		local delete_universe_stub
		local notify_stub
		local confirm_stub
		local confirm_choice
		local mark_closed_stub

		before_each(function()
			target_universe = UniverseSummary:new({ directory = "/tmp/foo", uuid = "uuid-1", name = "foo", lastExplored = 0 })
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
			confirm_choice = 2
			confirm_stub = stub(vim.fn, "confirm", function()
				return confirm_choice
			end)
			mark_closed_stub = stub(zellij_manager, "mark_closed")
		end)

		after_each(function()
			get_multiverse_stub:revert()
			save_multiverse_stub:revert()
			delete_universe_stub:revert()
			notify_stub:revert()
			confirm_stub:revert()
			mark_closed_stub:revert()
		end)

		it("does not delete, remove or save the universe", function()
			removeUniverseUsecase.run("foo")

			assert.stub(notify_stub).was_not_called()
			assert.stub(delete_universe_stub).was_not_called()
			assert.stub(save_multiverse_stub).was_not_called()
			assert.are.equal(1, #multiverse.universes)
			assert.are.equal(target_universe, multiverse.universes[1])
			assert.stub(mark_closed_stub).was_not_called()
		end)

		it("also aborts when the prompt is dismissed instead of explicitly declined", function()
			confirm_choice = 0

			removeUniverseUsecase.run("foo")

			assert.stub(delete_universe_stub).was_not_called()
			assert.stub(save_multiverse_stub).was_not_called()
			assert.stub(mark_closed_stub).was_not_called()
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
