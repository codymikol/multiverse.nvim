local stub = require("luassert.stub")
local universe_repository = require("multiverse.repositories.universe_repository")
local Universe = require("multiverse.data.Universe")
local json = require("multiverse.repositories.json")
local persistance = require("multiverse.repositories.persistance")
local log = require("multiverse.log")

local FIXED_DIR = "/tmp/universe-repository-spec-data"

local function expectedFilename(uuid)
	return FIXED_DIR .. "/universe-" .. uuid .. ".json"
end

describe("universe_repository", function()
	local persistance_getDir_stub

	before_each(function()
		persistance_getDir_stub = stub(persistance, "getDir", function()
			return FIXED_DIR
		end)
	end)

	after_each(function()
		persistance_getDir_stub:revert()
	end)

	describe("save_universe", function()
		describe("when io.open succeeds", function()
			local universe
			local io_open_stub
			local write_stub
			local close_stub
			local mock_file

			before_each(function()
				universe = Universe:new("uuid-1", "foo", "/tmp/foo")
				write_stub = stub.new()
				close_stub = stub.new()
				mock_file = {
					write = write_stub,
					close = close_stub,
				}
				io_open_stub = stub(io, "open", function()
					return mock_file
				end)
			end)

			after_each(function()
				io_open_stub:revert()
			end)

			it("writes the json-encoded universe to the file and returns the universe with no error", function()
				local returned_universe, err = universe_repository.save_universe(universe)

				assert.are.equal(universe, returned_universe)
				assert.is_nil(err)
				assert.stub(io_open_stub).was.called_with(expectedFilename(universe.uuid), "w")
				assert.stub(write_stub).was.called_with(mock_file, json.encode(universe))
				assert.stub(close_stub).was.called_with(mock_file)
			end)
		end)

		describe("when io.open fails", function()
			local universe
			local io_open_stub

			before_each(function()
				universe = Universe:new("uuid-1", "foo", "/tmp/foo")
				io_open_stub = stub(io, "open", function()
					return nil, "some os error"
				end)
			end)

			after_each(function()
				io_open_stub:revert()
			end)

			it("returns the universe and a descriptive error", function()
				local returned_universe, err = universe_repository.save_universe(universe)

				assert.are.equal(universe, returned_universe)
				assert.are.equal(
					"Failed to open universe file: " .. expectedFilename(universe.uuid) .. ", os returned error - some os error",
					err
				)
				assert.stub(io_open_stub).was.called_with(expectedFilename(universe.uuid), "w")
			end)
		end)
	end)

	describe("get_universe_by_uuid", function()
		describe("when io.open succeeds", function()
			local uuid
			local io_open_stub
			local read_stub
			local close_stub
			local mock_file
			local json_string

			before_each(function()
				uuid = "uuid-1"
				json_string = json.encode({ uuid = uuid, name = "foo", workingDirectory = "/tmp/foo" })
				read_stub = stub.new()
				read_stub.returns(json_string)
				close_stub = stub.new()
				mock_file = {
					read = read_stub,
					close = close_stub,
				}
				io_open_stub = stub(io, "open", function()
					return mock_file
				end)
			end)

			after_each(function()
				io_open_stub:revert()
			end)

			it("returns the hydrated universe with no error", function()
				local universe, err = universe_repository.get_universe_by_uuid(uuid)

				assert.is_nil(err)
				assert.are.equal(uuid, universe.uuid)
				assert.are.equal("foo", universe.name)
				assert.are.equal("/tmp/foo", universe.workingDirectory)
				assert.stub(io_open_stub).was.called_with(expectedFilename(uuid), "r")
				assert.stub(read_stub).was.called_with(mock_file, "*a")
				assert.stub(close_stub).was.called_with(mock_file)
			end)
		end)

		describe("when io.open succeeds but the file contains malformed json", function()
			local uuid
			local io_open_stub
			local log_error_stub
			local mock_file

			before_each(function()
				uuid = "uuid-1"
				mock_file = {
					read = function()
						return "not valid json"
					end,
					close = function() end,
				}
				io_open_stub = stub(io, "open", function()
					return mock_file
				end)
				-- universe_factory.make logs the decode failure via log.error, which
				-- would otherwise open the real log file through the io.open stub
				-- above and crash trying to call :write() on our read-only mock_file.
				log_error_stub = stub(log, "error")
			end)

			after_each(function()
				io_open_stub:revert()
				log_error_stub:revert()
			end)

			it("returns nil with no error", function()
				local universe, err = universe_repository.get_universe_by_uuid(uuid)

				assert.is_nil(universe)
				assert.is_nil(err)
			end)
		end)

		describe("when io.open fails", function()
			local uuid
			local io_open_stub

			before_each(function()
				uuid = "uuid-1"
				io_open_stub = stub(io, "open", function()
					return nil, "some os error"
				end)
			end)

			after_each(function()
				io_open_stub:revert()
			end)

			it("returns nil and a descriptive error", function()
				local universe, err = universe_repository.get_universe_by_uuid(uuid)

				assert.is_nil(universe)
				assert.are.equal(
					"Failed to open universe file: " .. expectedFilename(uuid) .. ", os returned error - some os error",
					err
				)
				assert.stub(io_open_stub).was.called_with(expectedFilename(uuid), "r")
			end)
		end)
	end)

	describe("deleteUniverse", function()
		describe("when os.remove succeeds", function()
			local os_remove_stub

			before_each(function()
				os_remove_stub = stub(os, "remove", function()
					return true, nil
				end)
			end)

			after_each(function()
				os_remove_stub:revert()
			end)

			it("returns true with no error", function()
				local ok, err = universe_repository.deleteUniverse({ uuid = "uuid-1" })

				assert.is_true(ok)
				assert.is_nil(err)
				assert.stub(os_remove_stub).was.called_with(expectedFilename("uuid-1"))
			end)
		end)

		describe("when os.remove fails with a non-ENOENT error", function()
			local os_remove_stub

			before_each(function()
				os_remove_stub = stub(os, "remove", function()
					return nil, "some os error", 13
				end)
			end)

			after_each(function()
				os_remove_stub:revert()
			end)

			it("returns false and a descriptive error", function()
				local ok, err = universe_repository.deleteUniverse({ uuid = "uuid-1" })

				assert.is_false(ok)
				assert.are.equal(
					"Failed to delete universe file: " .. expectedFilename("uuid-1") .. ", os returned error - some os error",
					err
				)
				assert.stub(os_remove_stub).was.called_with(expectedFilename("uuid-1"))
			end)
		end)

		describe("when os.remove fails because the file is already missing", function()
			local os_remove_stub

			before_each(function()
				os_remove_stub = stub(os, "remove", function()
					return nil, "some_path: No such file or directory", 2
				end)
			end)

			after_each(function()
				os_remove_stub:revert()
			end)

			it("returns true with no error", function()
				local ok, err = universe_repository.deleteUniverse({ uuid = "uuid-1" })

				assert.is_true(ok)
				assert.is_nil(err)
				assert.stub(os_remove_stub).was.called_with(expectedFilename("uuid-1"))
			end)
		end)
	end)
end)
