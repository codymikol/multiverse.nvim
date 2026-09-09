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
	local load_universe_stub
	local uuid_stub
	local now_stub
	local notify_stub

	local marker_path = vim.fn.tempname() .. "_multiverse_pwned_marker"

	before_each(function()
		multiverse = Multiverse:new({})
		get_multiverse_stub = stub(multiverse_repository, "getMultiverse", function()
			return multiverse
		end)
		save_multiverse_stub = stub(multiverse_repository, "save_multiverse")
		save_universe_stub = stub(universe_repository, "save_universe")
		load_universe_stub = stub(multiverse_manager, "load_universe")
		uuid_stub = stub(uuid_manager, "create", function()
			return "uuid-1"
		end)
		now_stub = stub(timestamp_manager, "now", function()
			return 0
		end)
		notify_stub = stub(vim, "notify")
		os.remove(marker_path)
	end)

	after_each(function()
		get_multiverse_stub:revert()
		save_multiverse_stub:revert()
		save_universe_stub:revert()
		load_universe_stub:revert()
		uuid_stub:revert()
		now_stub:revert()
		notify_stub:revert()
		os.remove(marker_path)
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
