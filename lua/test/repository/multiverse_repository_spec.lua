local stub = require("luassert.stub")
local persistance = require("multiverse.repositories.persistance")
local json = require("multiverse.repositories.json")

local module_name = "multiverse.repositories.multiverse_repository"

local function fresh_repository()
	package.loaded[module_name] = nil
	return require(module_name)
end

local function make_mock_file(fake_json, on_close)
	return {
		read = function()
			return fake_json
		end,
		close = function()
			if on_close then on_close() end
			return true
		end,
	}
end

describe("multiverse_repository", function()

	local io_open_stub

	after_each(function()
		if io_open_stub then
			io_open_stub:revert()
			io_open_stub = nil
		end
		package.loaded[module_name] = nil
	end)

	describe("getMultiverse", function()

		it("should return an empty multiverse when no file exists", function()
			io_open_stub = stub(io, "open", function() return nil end)

			local multiverse_repository = fresh_repository()
			local multiverse = multiverse_repository.getMultiverse()

			assert.are.same({ universes = {} }, multiverse)
		end)

		it("should decode and return universes from a file when one exists", function()
			local mock_file = make_mock_file(
				'{"universes": [{"directory": "/tmp/foo", "uuid": "u1", "name": "n", "lastExplored": 1}]}'
			)

			io_open_stub = stub(io, "open", function()
				return mock_file, nil
			end)

			local multiverse_repository = fresh_repository()
			local multiverse = multiverse_repository.getMultiverse()

			assert.are.equal(1, #multiverse.universes)
			assert.are.equal("/tmp/foo", multiverse.universes[1].directory)
		end)

		it("should not strip trailing slashes or re-save the file on load", function()
			local mock_file = make_mock_file(
				'{"universes": [{"directory": "/tmp/foo/", "uuid": "u1", "name": "n", "lastExplored": 1}]}'
			)

			local open_call_count = 0

			io_open_stub = stub(io, "open", function()
				open_call_count = open_call_count + 1
				return mock_file, nil
			end)

			local multiverse_repository = fresh_repository()
			local multiverse = multiverse_repository.getMultiverse()

			assert.are.equal("/tmp/foo/", multiverse.universes[1].directory)
			assert.are.equal(1, open_call_count)
		end)

		it("should not call io.open again on a second call (module-level cache)", function()
			local mock_file = make_mock_file(
				'{"universes": [{"directory": "/tmp/foo", "uuid": "u1", "name": "n", "lastExplored": 1}]}'
			)

			local open_call_count = 0

			io_open_stub = stub(io, "open", function()
				open_call_count = open_call_count + 1
				return mock_file, nil
			end)

			local multiverse_repository = fresh_repository()
			local first = multiverse_repository.getMultiverse()
			local second = multiverse_repository.getMultiverse()

			assert.are.equal(1, open_call_count)
			assert.are.equal(first, second)
		end)

		it("should call file:close() when a file exists", function()
			local close_call_count = 0
			local mock_file = make_mock_file(
				'{"universes": [{"directory": "/tmp/foo", "uuid": "u1", "name": "n", "lastExplored": 1}]}',
				function() close_call_count = close_call_count + 1 end
			)

			io_open_stub = stub(io, "open", function()
				return mock_file, nil
			end)

			local multiverse_repository = fresh_repository()
			multiverse_repository.getMultiverse()

			assert.are.equal(1, close_call_count)
		end)

	end)

	describe("save_multiverse", function()

		local notify_stub

		after_each(function()
			if notify_stub then
				notify_stub:revert()
				notify_stub = nil
			end
		end)

		it("should write the encoded multiverse to the multiverse.json path", function()
			local written_content = nil
			local opened_path = nil
			local opened_mode = nil

			local mock_file = {
				write = function(_, content)
					written_content = content
				end,
				close = function()
					return true
				end,
			}

			io_open_stub = stub(io, "open", function(path, mode)
				opened_path = path
				opened_mode = mode
				return mock_file, nil
			end)

			local multiverse_repository = fresh_repository()
			local multiverse = { universes = {} }

			multiverse_repository.save_multiverse(multiverse)

			assert.are.equal(persistance.getDir() .. "/multiverse.json", opened_path)
			assert.are.equal("w", opened_mode)
			assert.are.equal(json.encode(multiverse), written_content)
		end)

		it("should return nil and notify with an error level when io.open returns nil", function()
			notify_stub = stub(vim, "notify")

			io_open_stub = stub(io, "open", function() return nil end)

			local multiverse_repository = fresh_repository()
			local result = multiverse_repository.save_multiverse({ universes = {} })

			assert.is_nil(result)
			assert.stub(notify_stub).was.called(1)
			assert.stub(notify_stub).was.called_with("Failed to open multiverse.json", vim.log.levels.ERROR)
		end)

	end)

end)
