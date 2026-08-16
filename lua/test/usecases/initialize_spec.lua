local stub = require("luassert.stub")
local persistance = require("multiverse.repositories.persistance")
local initialize = require("multiverse.usecases.initialize")

local function stub_fs(stat_return, mkdir_ok, mkdir_err)
	if mkdir_ok == nil then
		mkdir_ok = true
	end
	local fs_stat_stub = stub(vim.loop, "fs_stat", function()
		return stat_return
	end)
	local mkdir_called_with = nil
	local fs_mkdir_stub = stub(vim.loop, "fs_mkdir", function(path, mode)
		mkdir_called_with = { path = path, mode = mode }
		if mkdir_ok then
			return true
		end
		return nil, mkdir_err
	end)
	return fs_stat_stub, fs_mkdir_stub, function()
		return mkdir_called_with
	end
end

describe("initialize.run", function()
	describe("when the multiverse directory does not exist", function()
		local fs_stat_stub
		local fs_mkdir_stub
		local get_mkdir_called_with

		before_each(function()
			fs_stat_stub, fs_mkdir_stub, get_mkdir_called_with = stub_fs(nil)
		end)

		after_each(function()
			fs_stat_stub:revert()
			fs_mkdir_stub:revert()
		end)

		it("should not error", function()
			assert.has_no.errors(function()
				initialize.run()
			end)
		end)

		it("should create the multiverse directory at persistance.getDir() with mode 0755", function()
			initialize.run()
			assert.stub(fs_mkdir_stub).was.called(1)
			local mkdir_called_with = get_mkdir_called_with()
			assert.are.equal(persistance.getDir(), mkdir_called_with.path)
			assert.are.equal(493, mkdir_called_with.mode)
		end)
	end)

	describe("when the multiverse directory already exists", function()
		local fs_stat_stub
		local fs_mkdir_stub

		before_each(function()
			fs_stat_stub, fs_mkdir_stub = stub_fs({ type = "directory" })
		end)

		after_each(function()
			fs_stat_stub:revert()
			fs_mkdir_stub:revert()
		end)

		it("should not error", function()
			assert.has_no.errors(function()
				initialize.run()
			end)
		end)

		it("should not attempt to create the directory again", function()
			initialize.run()
			assert.stub(fs_mkdir_stub).was_not_called()
			assert.stub(fs_stat_stub).was.called_with(persistance.getDir())
		end)
	end)

	describe("when fs_mkdir fails", function()
		local fs_stat_stub
		local fs_mkdir_stub
		local notify_stub
		local mkdir_err = "permission denied"

		before_each(function()
			fs_stat_stub, fs_mkdir_stub = stub_fs(nil, false, mkdir_err)
			notify_stub = stub(vim, "notify")
		end)

		after_each(function()
			fs_stat_stub:revert()
			fs_mkdir_stub:revert()
			notify_stub:revert()
		end)

		it("should not error", function()
			assert.has_no.errors(function()
				initialize.run()
			end)
		end)

		it("should notify with an error level", function()
			initialize.run()
			assert.stub(notify_stub).was.called(1)
			assert.stub(notify_stub).was.called_with("Failed to create multiverse directory: " .. mkdir_err, vim.log.levels.ERROR)
		end)
	end)
end)
