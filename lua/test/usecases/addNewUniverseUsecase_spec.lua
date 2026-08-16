local stub = require("luassert.stub")
local match = require("luassert.match")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local universe_repository = require("multiverse.repositories.universe_repository")
local multiverse_manager = require("multiverse.managers.multiverse_manager")
local uuid_manager = require("multiverse.managers.uuid_manager")
local timestamp_manager = require("multiverse.managers.timestamp_manager")
local Multiverse = require("multiverse.data.Multiverse")
local UniverseSummary = require("multiverse.data.UniverseSummary")
local log = require("multiverse.log")
local addNewUniverseUsecase = require("multiverse.usecases.addNewUniverseUsecase")

describe("addNewUniverseUsecase.run", function()
	describe("when the directory does not already have a universe", function()
		local uuid_create_stub
		local getMultiverse_stub
		local save_multiverse_stub
		local save_universe_stub
		local load_universe_stub
		local save_stub
		local timestamp_now_stub
		local log_debug_stub
		local print_stub

		local save_multiverse_called_with
		local save_universe_called_with
		local load_universe_called_with

		before_each(function()
			save_multiverse_called_with = nil
			save_universe_called_with = nil
			load_universe_called_with = nil

			uuid_create_stub = stub(uuid_manager, "create", function()
				return "fixed-uuid-123"
			end)

			getMultiverse_stub = stub(multiverse_repository, "getMultiverse", function()
				return Multiverse:new({})
			end)

			save_multiverse_stub = stub(multiverse_repository, "save_multiverse", function(multiverse)
				save_multiverse_called_with = multiverse
			end)

			save_universe_stub = stub(universe_repository, "save_universe", function(universe)
				save_universe_called_with = universe
			end)

			load_universe_stub = stub(multiverse_manager, "load_universe", function(multiverse, summary)
				load_universe_called_with = { multiverse = multiverse, summary = summary }
			end)

			save_stub = stub(multiverse_manager, "save")

			timestamp_now_stub = stub(timestamp_manager, "now", function()
				return 123456789
			end)

			log_debug_stub = stub(log, "debug")
			print_stub = stub(_G, "print")
		end)

		after_each(function()
			uuid_create_stub:revert()
			getMultiverse_stub:revert()
			save_multiverse_stub:revert()
			save_universe_stub:revert()
			load_universe_stub:revert()
			save_stub:revert()
			timestamp_now_stub:revert()
			log_debug_stub:revert()
			print_stub:revert()
		end)

		it("should not error", function()
			assert.has_no.errors(function()
				addNewUniverseUsecase.run("myname", "/some/dir")
			end)
		end)

		it("should add the new universe summary to the multiverse and save it once", function()
			addNewUniverseUsecase.run("myname", "/some/dir")

			assert.stub(save_multiverse_stub).was.called(1)
			assert.is_not_nil(save_multiverse_called_with)
			assert.are.equal(1, #save_multiverse_called_with.universes)

			local saved_summary = save_multiverse_called_with.universes[1]
			assert.are.equal("myname", saved_summary.name)
			assert.are.equal("/some/dir", saved_summary.directory)
			assert.are.equal("fixed-uuid-123", saved_summary.uuid)
		end)

		it("should use timestamp_manager.now() for the lastExplored timestamp", function()
			addNewUniverseUsecase.run("myname", "/some/dir")

			assert.is_not_nil(save_multiverse_called_with)
			local saved_summary = save_multiverse_called_with.universes[1]
			assert.are.equal(123456789, saved_summary.lastExplored)
		end)

		it("should save a new universe once with the expected uuid, name and working directory", function()
			addNewUniverseUsecase.run("myname", "/some/dir")

			assert.stub(save_universe_stub).was.called(1)
			assert.is_not_nil(save_universe_called_with)
			assert.are.equal("fixed-uuid-123", save_universe_called_with.uuid)
			assert.are.equal("myname", save_universe_called_with.name)
			assert.are.equal("/some/dir", save_universe_called_with.workingDirectory)
		end)

		it("should load the universe once with the multiverse and new universe summary", function()
			addNewUniverseUsecase.run("myname", "/some/dir")

			assert.stub(load_universe_stub).was.called(1)
			assert.is_not_nil(load_universe_called_with)
			assert.are.equal(save_multiverse_called_with, load_universe_called_with.multiverse)
			assert.are.equal("fixed-uuid-123", load_universe_called_with.summary.uuid)
			assert.are.equal("myname", load_universe_called_with.summary.name)
			assert.are.equal("/some/dir", load_universe_called_with.summary.directory)
		end)

		it("should log a debug message about adding the new universe instead of printing it", function()
			addNewUniverseUsecase.run("myname", "/some/dir")

			assert.stub(log_debug_stub).was.called_with(match.matches("Adding a new universe"), match.is_table())
			assert.stub(print_stub).was_not.called()
		end)

		it("should strip a trailing slash from a user-supplied directory", function()
			addNewUniverseUsecase.run("myname", "/some/dir/")

			assert.is_not_nil(save_multiverse_called_with)
			local saved_summary = save_multiverse_called_with.universes[1]
			assert.are.equal("/some/dir", saved_summary.directory)
		end)

		it("should expand a ~ user-supplied directory to an absolute path", function()
			addNewUniverseUsecase.run("myname", "~/some/dir")

			assert.is_not_nil(save_multiverse_called_with)
			local saved_summary = save_multiverse_called_with.universes[1]

			assert.are.equal(1, string.find(saved_summary.directory, "/", 1, true))
			assert.is_nil(string.find(saved_summary.directory, "~", 1, true))
			assert.is_true(vim.endswith(saved_summary.directory, "/some/dir"))
		end)

		it("should expand $HOME-style environment variables", function()
			addNewUniverseUsecase.run("myname", "$HOME/some/dir")

			assert.is_not_nil(save_multiverse_called_with)
			local saved_summary = save_multiverse_called_with.universes[1]
			assert.are.equal(vim.env.HOME .. "/some/dir", saved_summary.directory)
		end)

		local marker_path = vim.fn.tempname() .. "_multiverse_pwned_marker"

		it("does not execute backtick-quoted shell commands embedded in the directory", function()
			os.remove(marker_path)
			local malicious_directory = "`touch " .. marker_path .. "`"

			addNewUniverseUsecase.run("foo", malicious_directory)

			assert.stub(save_universe_stub).was.called(1)
			assert.are.equal(malicious_directory, save_universe_called_with.workingDirectory)
			assert.is_nil(vim.loop.fs_stat(marker_path))
			os.remove(marker_path)
		end)
	end)

	describe("when adding a universe for the currently-open directory", function()
		local get_multiverse_stub
		local save_multiverse_stub
		local save_universe_stub
		local load_universe_stub
		local save_stub
		local uuid_stub
		local now_stub
		local log_debug_stub
		local getcwd_stub
		local multiverse

		before_each(function()
			multiverse = Multiverse:new({})
			get_multiverse_stub = stub(multiverse_repository, "getMultiverse", function()
				return multiverse
			end)
			save_multiverse_stub = stub(multiverse_repository, "save_multiverse")
			save_universe_stub = stub(universe_repository, "save_universe")
			load_universe_stub = stub(multiverse_manager, "load_universe")
			save_stub = stub(multiverse_manager, "save")
			uuid_stub = stub(uuid_manager, "create", function()
				return "uuid-1"
			end)
			now_stub = stub(timestamp_manager, "now", function()
				return 0
			end)
			log_debug_stub = stub(log, "debug")
		end)

		after_each(function()
			get_multiverse_stub:revert()
			save_multiverse_stub:revert()
			save_universe_stub:revert()
			load_universe_stub:revert()
			save_stub:revert()
			uuid_stub:revert()
			now_stub:revert()
			log_debug_stub:revert()
			if getcwd_stub then
				getcwd_stub:revert()
				getcwd_stub = nil
			end
		end)

		it("captures the currently-open session into the new universe before loading it, when adding for the current directory", function()
			local directory = "/tmp/some/project"
			getcwd_stub = stub(vim.fn, "getcwd", function() return directory end)

			local call_order = {}
			save_stub.invokes(function() table.insert(call_order, "save") end)
			load_universe_stub.invokes(function() table.insert(call_order, "load_universe") end)

			addNewUniverseUsecase.run("foo", directory)

			assert.stub(save_universe_stub).was.called(1)
			assert.stub(save_stub).was.called(1)
			assert.stub(load_universe_stub).was.called(1)
			assert.are.same({ "save", "load_universe" }, call_order)

			local load_universe_call = load_universe_stub.calls[1]
			assert.are.equal(multiverse, load_universe_call.refs[1])
		end)

		it("does not capture the current session when adding a universe for a different directory", function()
			local directory = "/tmp/some/other/project"
			getcwd_stub = stub(vim.fn, "getcwd", function() return "/tmp/some/unrelated/cwd" end)

			addNewUniverseUsecase.run("foo", directory)

			assert.stub(save_universe_stub).was.called(1)
			assert.stub(save_stub).was_not.called()
			assert.stub(load_universe_stub).was.called(1)
		end)
	end)

	describe("when directory is omitted", function()
		local uuid_create_stub
		local getMultiverse_stub
		local save_multiverse_stub
		local save_universe_stub
		local load_universe_stub
		local save_stub
		local getcwd_stub

		local save_multiverse_called_with
		local save_universe_called_with

		before_each(function()
			save_multiverse_called_with = nil
			save_universe_called_with = nil

			uuid_create_stub = stub(uuid_manager, "create", function()
				return "fixed-uuid-123"
			end)

			getMultiverse_stub = stub(multiverse_repository, "getMultiverse", function()
				return Multiverse:new({})
			end)

			save_multiverse_stub = stub(multiverse_repository, "save_multiverse", function(multiverse)
				save_multiverse_called_with = multiverse
			end)

			save_universe_stub = stub(universe_repository, "save_universe", function(universe)
				save_universe_called_with = universe
			end)

			load_universe_stub = stub(multiverse_manager, "load_universe")
			save_stub = stub(multiverse_manager, "save")

			getcwd_stub = stub(vim.fn, "getcwd", function()
				return "/fake/cwd"
			end)
		end)

		after_each(function()
			uuid_create_stub:revert()
			getMultiverse_stub:revert()
			save_multiverse_stub:revert()
			save_universe_stub:revert()
			load_universe_stub:revert()
			save_stub:revert()
			getcwd_stub:revert()
		end)

		it("should default the directory to the current working directory", function()
			addNewUniverseUsecase.run("myname")

			assert.stub(save_multiverse_stub).was.called(1)
			assert.is_not_nil(save_multiverse_called_with)

			local saved_summary = save_multiverse_called_with.universes[1]
			assert.are.equal("/fake/cwd", saved_summary.directory)

			assert.is_not_nil(save_universe_called_with)
			assert.are.equal("/fake/cwd", save_universe_called_with.workingDirectory)
		end)
	end)

	describe("when a universe already exists for the directory", function()
		local uuid_create_stub
		local getMultiverse_stub
		local save_multiverse_stub
		local save_universe_stub
		local load_universe_stub
		local notify_stub
		local log_debug_stub

		before_each(function()
			uuid_create_stub = stub(uuid_manager, "create", function()
				return "fixed-uuid-123"
			end)

			local existing_summary = UniverseSummary:new({
				directory = "/some/dir",
				uuid = "existing-uuid",
				name = "existing-name",
				lastExplored = 0,
			})

			getMultiverse_stub = stub(multiverse_repository, "getMultiverse", function()
				return Multiverse:new({ existing_summary })
			end)

			save_multiverse_stub = stub(multiverse_repository, "save_multiverse")
			save_universe_stub = stub(universe_repository, "save_universe")
			load_universe_stub = stub(multiverse_manager, "load_universe")
			notify_stub = stub(vim, "notify")
			log_debug_stub = stub(log, "debug")
		end)

		after_each(function()
			uuid_create_stub:revert()
			getMultiverse_stub:revert()
			save_multiverse_stub:revert()
			save_universe_stub:revert()
			load_universe_stub:revert()
			notify_stub:revert()
			log_debug_stub:revert()
		end)

		it("should not error", function()
			assert.has_no.errors(function()
				addNewUniverseUsecase.run("myname", "/some/dir")
			end)
		end)

		it("should notify that a universe already exists with that directory", function()
			addNewUniverseUsecase.run("myname", "/some/dir")

			assert.stub(notify_stub).was.called(1)
			assert.stub(notify_stub).was.called_with(
				"Universe already exists with that directory under the name: existing-name"
			)
		end)

		it("should not save the multiverse, save the universe or load the universe", function()
			addNewUniverseUsecase.run("myname", "/some/dir")

			assert.stub(save_multiverse_stub).was_not_called()
			assert.stub(save_universe_stub).was_not_called()
			assert.stub(load_universe_stub).was_not_called()
		end)
	end)

	describe("when a collaborator errors", function()
		local uuid_create_stub
		local notify_stub
		local log_error_stub
		local getMultiverse_stub
		local save_multiverse_stub
		local save_universe_stub
		local load_universe_stub

		before_each(function()
			uuid_create_stub = stub(uuid_manager, "create", function()
				error("uuid generation exploded")
			end)
			notify_stub = stub(vim, "notify")
			log_error_stub = stub(log, "error")

			getMultiverse_stub = stub(multiverse_repository, "getMultiverse", function()
				return Multiverse:new({})
			end)
			save_multiverse_stub = stub(multiverse_repository, "save_multiverse")
			save_universe_stub = stub(universe_repository, "save_universe")
			load_universe_stub = stub(multiverse_manager, "load_universe")
		end)

		after_each(function()
			uuid_create_stub:revert()
			notify_stub:revert()
			log_error_stub:revert()
			getMultiverse_stub:revert()
			save_multiverse_stub:revert()
			save_universe_stub:revert()
			load_universe_stub:revert()
		end)

		it("should not raise an error out of run", function()
			assert.has_no.errors(function()
				addNewUniverseUsecase.run("myname", "/some/dir")
			end)
		end)

		it("should notify with an error level", function()
			addNewUniverseUsecase.run("myname", "/some/dir")

			assert.stub(notify_stub).was.called(1)
			assert.stub(notify_stub).was.called_with(
				"Failed to add new universe, check MultiverseLog for more information",
				vim.log.levels.ERROR
			)
		end)

		it("should log the error", function()
			addNewUniverseUsecase.run("myname", "/some/dir")

			assert.stub(log_error_stub).was.called(1)
		end)
	end)
end)
