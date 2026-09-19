local stub = require("luassert.stub")
local match = require("luassert.match")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local universe_repository = require("multiverse.repositories.universe_repository")
local multiverse_manager = require("multiverse.managers.multiverse_manager")
local uuid_manager = require("multiverse.managers.uuid_manager")
local timestamp_manager = require("multiverse.managers.timestamp_manager")
local Multiverse = require("multiverse.data.Multiverse")
local log = require("multiverse.log")
local addNewUniverseUsecase = require("multiverse.usecases.addNewUniverseUsecase")

describe("addNewUniverseUsecase.run", function()
	local multiverse
	local get_multiverse_stub
	local save_multiverse_stub
	local save_universe_stub
	local load_universe_stub
	local save_stub
	local uuid_stub
	local now_stub
	local notify_stub
	local log_debug_stub
	local print_stub
	local getcwd_stub

	local marker_path = vim.fn.tempname() .. "_multiverse_pwned_marker"

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
		notify_stub = stub(vim, "notify")
		log_debug_stub = stub(log, "debug")
		print_stub = stub(_G, "print")
		os.remove(marker_path)
	end)

	after_each(function()
		get_multiverse_stub:revert()
		save_multiverse_stub:revert()
		save_universe_stub:revert()
		load_universe_stub:revert()
		save_stub:revert()
		uuid_stub:revert()
		now_stub:revert()
		notify_stub:revert()
		log_debug_stub:revert()
		print_stub:revert()
		if getcwd_stub then
			getcwd_stub:revert()
			getcwd_stub = nil
		end
		os.remove(marker_path)
	end)

	it("logs the new universe summary via log.debug instead of printing it", function()
		addNewUniverseUsecase.run("foo", "/tmp/some/project")

		assert.stub(log_debug_stub).was.called_with("Adding a new universe: %s", match._)
		local summary_arg
		for _, call in ipairs(log_debug_stub.calls) do
			if call.refs[1] == "Adding a new universe: %s" then
				summary_arg = call.refs[2]
			end
		end
		assert.are.equal("foo", summary_arg.name)
		assert.stub(print_stub).was_not.called()
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

	it("does not execute backtick-quoted shell commands embedded in the directory", function()
		local malicious_directory = "`touch " .. marker_path .. "`"

		addNewUniverseUsecase.run("foo", malicious_directory)

		assert.stub(save_universe_stub).was.called(1)
		local saved_universe = save_universe_stub.calls[1].refs[1]

		assert.are.equal(malicious_directory, saved_universe.workingDirectory)
		assert.is_nil(vim.loop.fs_stat(marker_path))
	end)

	it("still expands a leading ~ to the home directory", function()
		local directory = "~/some/project"

		addNewUniverseUsecase.run("foo", directory)

		assert.stub(save_universe_stub).was.called(1)
		local saved_universe = save_universe_stub.calls[1].refs[1]

		assert.are.equal(vim.env.HOME .. "/some/project", saved_universe.workingDirectory)
	end)

	it("still expands $HOME-style environment variables", function()
		local directory = "$HOME/some/project"

		addNewUniverseUsecase.run("foo", directory)

		assert.stub(save_universe_stub).was.called(1)
		local saved_universe = save_universe_stub.calls[1].refs[1]

		assert.are.equal(vim.env.HOME .. "/some/project", saved_universe.workingDirectory)
	end)

	it("still strips a trailing slash from the directory", function()
		addNewUniverseUsecase.run("foo", "/tmp/some/project/")

		assert.stub(save_universe_stub).was.called(1)
		local saved_universe = save_universe_stub.calls[1].refs[1]

		assert.are.equal("/tmp/some/project", saved_universe.workingDirectory)
	end)
end)
