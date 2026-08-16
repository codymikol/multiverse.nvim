describe("universe_factory make", function()
	local universe_factory = require("multiverse.factory.universe_factory")
	local json = require("multiverse.repositories.json")
	local log = require("multiverse.log")
	local stub = require("luassert.stub")

	describe("a happy path universe with a buffer, tabpage, window and explicit layout", function()
		local universeUuid = "8d1f9c2a-1111-4a2b-9c3d-000000000001"
		local bufferUuid = "8d1f9c2a-2222-4a2b-9c3d-000000000002"
		local tabpageUuid = "8d1f9c2a-3333-4a2b-9c3d-000000000003"
		local windowUuid = "8d1f9c2a-4444-4a2b-9c3d-000000000004"

		local universeTable = {
			uuid = universeUuid,
			name = "example",
			workingDirectory = "/home/foo",
			buffers = {
				{
					uuid = bufferUuid,
					bufferName = "foo.lua",
				},
			},
			tabpages = {
				{
					uuid = tabpageUuid,
					layout = {
						type = "horizontal",
						children = {},
					},
					windows = {
						{
							uuid = windowUuid,
							bufferUuid = bufferUuid,
						},
					},
				},
			},
		}

		local jsonString = json.encode(universeTable)

		local universe = universe_factory.make(jsonString)

		it("should return a non-nil universe", function()
			assert.is_not.Nil(universe)
		end)

		it("should have the correct uuid", function()
			assert.are.equal(universeUuid, universe.uuid)
		end)

		it("should have the correct name", function()
			assert.are.equal("example", universe.name)
		end)

		it("should have the correct workingDirectory", function()
			assert.are.equal("/home/foo", universe.workingDirectory)
		end)

		it("should have one buffer", function()
			assert.are.equal(1, #universe.buffers)
		end)

		it("should have the correct buffer uuid", function()
			assert.are.equal(bufferUuid, universe.buffers[1].uuid)
		end)

		it("should have the correct buffer name", function()
			assert.are.equal("foo.lua", universe.buffers[1].bufferName)
		end)

		it("should have one tabpage", function()
			assert.are.equal(1, #universe.tabpages)
		end)

		local tabpage = universe.tabpages[1]

		it("should have the correct tabpage uuid", function()
			assert.are.equal(tabpageUuid, tabpage.uuid)
		end)

		it("should have a non-nil layout on the tabpage", function()
			assert.is_not.Nil(tabpage.layout)
		end)

		it("should have one window on the tabpage", function()
			assert.are.equal(1, #tabpage.windows)
		end)

		it("should have the correct window uuid", function()
			assert.are.equal(windowUuid, tabpage.windows[1].uuid)
		end)

		it("should have the correct bufferUuid on the window", function()
			assert.are.equal(bufferUuid, tabpage.windows[1].bufferUuid)
		end)
	end)

	describe("a tabpage json payload with a valid non-trivial layout manifest", function()
		local universeUuid = "8d1f9c2a-dddd-4a2b-9c3d-00000000000d"
		local tabpageUuid = "8d1f9c2a-eeee-4a2b-9c3d-00000000000e"
		local windowUuid = "8d1f9c2a-ffff-4a2b-9c3d-00000000000f"

		local universeTable = {
			uuid = universeUuid,
			name = "example",
			workingDirectory = "/home/foo",
			tabpages = {
				{
					uuid = tabpageUuid,
					layout = {
						children = {
							{
								type = "row",
								children = {
									{
										type = "leaf",
										windowUuid = windowUuid,
									},
								},
							},
						},
					},
				},
			},
		}

		local jsonString = json.encode(universeTable)

		local universe = universe_factory.make(jsonString)
		local tabpage = universe.tabpages[1]

		it("should return a non-nil layout on the tabpage", function()
			assert.is_not.Nil(tabpage.layout)
		end)

		it("should not fall back to the default empty layout", function()
			assert.are.equal(1, #tabpage.layout.children)
		end)

		local firstChild = tabpage.layout.children[1]

		it("should have a row as the first child", function()
			assert.are.equal("row", firstChild.type)
		end)

		it("should have one child on the row", function()
			assert.are.equal(1, #firstChild.children)
		end)

		local leaf = firstChild.children[1]

		it("should have a leaf as the row's child", function()
			assert.are.equal("leaf", leaf.type)
		end)

		it("should have the correct windowUuid on the leaf", function()
			assert.are.equal(windowUuid, leaf.windowUuid)
		end)
	end)

	describe("a tabpage json payload with no windows key", function()
		local universeUuid = "8d1f9c2a-7777-4a2b-9c3d-000000000007"
		local tabpageUuid = "8d1f9c2a-8888-4a2b-9c3d-000000000008"

		local universeTable = {
			uuid = universeUuid,
			name = "example",
			workingDirectory = "/home/foo",
			tabpages = {
				{
					uuid = tabpageUuid,
					layout = {
						type = "horizontal",
						children = {},
					},
				},
			},
		}

		local jsonString = json.encode(universeTable)

		it("should not throw when a tabpage's windows key is missing", function()
			assert.has_no.errors(function()
				universe_factory.make(jsonString)
			end)
		end)

		it("should return a universe with a tabpage that has an empty windows table", function()
			local universe = universe_factory.make(jsonString)
			assert.are.equal(0, #universe.tabpages[1].windows)
		end)
	end)

	describe("a universe json payload with no tabpages key", function()
		local universeUuid = "8d1f9c2a-5555-4a2b-9c3d-000000000005"
		local bufferUuid = "8d1f9c2a-6666-4a2b-9c3d-000000000006"

		local universeTable = {
			uuid = universeUuid,
			name = "example",
			workingDirectory = "/home/foo",
			buffers = {
				{
					uuid = bufferUuid,
					bufferName = "foo.lua",
				},
			},
		}

		local jsonString = json.encode(universeTable)

		it("should not throw when tabpages is missing", function()
			assert.has_no.errors(function()
				universe_factory.make(jsonString)
			end)
		end)

		it("should return a universe with an empty tabpages table", function()
			local universe = universe_factory.make(jsonString)
			assert.are.equal(0, #universe.tabpages)
		end)
	end)

	describe("a malformed json payload", function()
		it("should not throw when the json string is malformed", function()
			assert.has_no.errors(function()
				universe_factory.make("not valid json")
			end)
		end)

		it("should return nil for a malformed json string", function()
			local universe = universe_factory.make("not valid json")
			assert.is.Nil(universe)
		end)

		describe("log.error behavior", function()
			local log_error_stub

			before_each(function()
				log_error_stub = stub(log, "error")
			end)

			after_each(function()
				log_error_stub:revert()
			end)

			it("should call log.error when the json string fails to decode", function()
				universe_factory.make("not valid json")
				assert.stub(log_error_stub).was.called()
			end)
		end)
	end)

	describe("a universe json payload where tabpages is not a table", function()
		it("should not throw when tabpages is a number", function()
			assert.has_no.errors(function()
				universe_factory.make('{"uuid":"a","name":"example","workingDirectory":"/home/foo","tabpages":5}')
			end)
		end)

		it("should return a universe with an empty tabpages table when tabpages is a number", function()
			local universe =
				universe_factory.make('{"uuid":"a","name":"example","workingDirectory":"/home/foo","tabpages":5}')
			assert.is_not.Nil(universe)
			assert.are.equal(0, #universe.tabpages)
		end)
	end)

	describe("a universe json payload where buffers is not a table", function()
		it("should not throw when buffers is a string", function()
			assert.has_no.errors(function()
				universe_factory.make('{"uuid":"a","name":"example","workingDirectory":"/home/foo","buffers":"x"}')
			end)
		end)

		it("should return a universe with an empty buffers table when buffers is a string", function()
			local universe =
				universe_factory.make('{"uuid":"a","name":"example","workingDirectory":"/home/foo","buffers":"x"}')
			assert.is_not.Nil(universe)
			assert.are.equal(0, #universe.buffers)
		end)
	end)

	describe("a tabpage json payload where windows is not a table", function()
		it("should not throw when windows is a number", function()
			assert.has_no.errors(function()
				universe_factory.make(
					'{"uuid":"a","name":"example","workingDirectory":"/home/foo","tabpages":[{"uuid":"a","windows":7}]}'
				)
			end)
		end)

		it("should return a universe with a tabpage that has an empty windows table when windows is a number", function()
			local universe = universe_factory.make(
				'{"uuid":"a","name":"example","workingDirectory":"/home/foo","tabpages":[{"uuid":"a","windows":7}]}'
			)
			assert.is_not.Nil(universe)
			assert.are.equal(0, #universe.tabpages[1].windows)
		end)
	end)

	describe("a universe json payload where tabpages contains non-table elements", function()
		it("should not throw when tabpages contains non-table elements", function()
			assert.has_no.errors(function()
				universe_factory.make('{"uuid":"a","name":"example","workingDirectory":"/home/foo","tabpages":[1,2]}')
			end)
		end)

		it("should skip non-table tabpage elements", function()
			local universe =
				universe_factory.make('{"uuid":"a","name":"example","workingDirectory":"/home/foo","tabpages":[1,2]}')
			assert.is_not.Nil(universe)
			assert.are.equal(0, #universe.tabpages)
		end)
	end)

	describe("a universe json payload where buffers contains non-table elements", function()
		it("should not throw when buffers contains non-table elements", function()
			assert.has_no.errors(function()
				universe_factory.make('{"uuid":"a","name":"example","workingDirectory":"/home/foo","buffers":[1,2]}')
			end)
		end)

		it("should skip non-table buffer elements", function()
			local universe =
				universe_factory.make('{"uuid":"a","name":"example","workingDirectory":"/home/foo","buffers":[1,2]}')
			assert.is_not.Nil(universe)
			assert.are.equal(0, #universe.buffers)
		end)
	end)

	describe("a tabpage json payload where windows contains non-table elements", function()
		it("should not throw when windows contains non-table elements", function()
			assert.has_no.errors(function()
				universe_factory.make(
					'{"uuid":"a","name":"example","workingDirectory":"/home/foo","tabpages":[{"uuid":"a","windows":[1,2]}]}'
				)
			end)
		end)

		it("should skip non-table window elements", function()
			local universe = universe_factory.make(
				'{"uuid":"a","name":"example","workingDirectory":"/home/foo","tabpages":[{"uuid":"a","windows":[1,2]}]}'
			)
			assert.is_not.Nil(universe)
			assert.are.equal(0, #universe.tabpages[1].windows)
		end)
	end)

	describe("a tabpage json payload where layout is not a table", function()
		it("should not throw when layout is a number", function()
			assert.has_no.errors(function()
				universe_factory.make(
					'{"uuid":"a","name":"example","workingDirectory":"/home/foo","tabpages":[{"layout":5}]}'
				)
			end)
		end)

		it("should default to a layout with no children when layout is a number", function()
			local universe = universe_factory.make(
				'{"uuid":"a","name":"example","workingDirectory":"/home/foo","tabpages":[{"layout":5}]}'
			)
			assert.is_not.Nil(universe)
			local tabpage = universe.tabpages[1]
			assert.is_not.Nil(tabpage.layout)
			assert.are.equal(0, #tabpage.layout.children)
		end)
	end)

	describe("a malformed json payload containing a percent sign", function()
		it("should not throw when the malformed json string contains a percent sign", function()
			assert.has_no.errors(function()
				universe_factory.make("%s bad json")
			end)
		end)

		it("should return nil for a malformed json string containing a percent sign", function()
			local universe = universe_factory.make("%s bad json")
			assert.is.Nil(universe)
		end)
	end)

	describe("a universe json payload missing identity fields", function()
		it("should return nil when the payload is an empty table", function()
			local universe = universe_factory.make("{}")
			assert.is.Nil(universe)
		end)

		it("should return nil when uuid is missing", function()
			local universe = universe_factory.make('{"name":"example","workingDirectory":"/home/foo"}')
			assert.is.Nil(universe)
		end)

		it("should return nil when name is missing", function()
			local universe = universe_factory.make('{"uuid":"a","workingDirectory":"/home/foo"}')
			assert.is.Nil(universe)
		end)

		it("should return nil when workingDirectory is missing", function()
			local universe = universe_factory.make('{"uuid":"a","name":"example"}')
			assert.is.Nil(universe)
		end)

		it("should return nil when uuid is an empty string", function()
			local universe = universe_factory.make('{"uuid":"","name":"example","workingDirectory":"/home/foo"}')
			assert.is.Nil(universe)
		end)

		it("should return nil when workingDirectory is not a string", function()
			local universe = universe_factory.make('{"uuid":"a","name":"example","workingDirectory":5}')
			assert.is.Nil(universe)
		end)

		describe("log.warn behavior", function()
			local log_warn_stub

			before_each(function()
				log_warn_stub = stub(log, "warn")
			end)

			after_each(function()
				log_warn_stub:revert()
			end)

			it("should call log.warn when identity fields are missing", function()
				universe_factory.make("{}")
				assert.stub(log_warn_stub).was.called()
			end)
		end)
	end)

	describe("a nil json string", function()
		it("should not throw when the json string is nil", function()
			assert.has_no.errors(function()
				universe_factory.make(nil)
			end)
		end)

		it("should return nil when the json string is nil", function()
			local universe = universe_factory.make(nil)
			assert.is.Nil(universe)
		end)
	end)

	describe("a json payload that decodes to the JSON null value", function()
		it("should not throw when the json string is 'null'", function()
			assert.has_no.errors(function()
				universe_factory.make("null")
			end)
		end)

		it("should return nil for a json string of 'null'", function()
			local universe = universe_factory.make("null")
			assert.is.Nil(universe)
		end)

		describe("log.error behavior", function()
			local log_error_stub

			before_each(function()
				log_error_stub = stub(log, "error")
			end)

			after_each(function()
				log_error_stub:revert()
			end)

			it("should not call log.error when the json string is 'null'", function()
				universe_factory.make("null")
				assert.stub(log_error_stub).was_not_called()
			end)
		end)
	end)

	describe("a json payload that decodes to a non-table scalar value", function()
		it("should not throw when the json string is '42'", function()
			assert.has_no.errors(function()
				universe_factory.make("42")
			end)
		end)

		it("should return nil for a json string of '42'", function()
			local universe = universe_factory.make("42")
			assert.is.Nil(universe)
		end)

		describe("log.error behavior", function()
			local log_error_stub

			before_each(function()
				log_error_stub = stub(log, "error")
			end)

			after_each(function()
				log_error_stub:revert()
			end)

			it("should not call log.error when the json string is '42'", function()
				universe_factory.make("42")
				assert.stub(log_error_stub).was_not_called()
			end)
		end)
	end)

	describe("a universe json payload with no buffers key", function()
		local universeUuid = "8d1f9c2a-9999-4a2b-9c3d-000000000009"
		local tabpageUuid = "8d1f9c2a-aaaa-4a2b-9c3d-00000000000a"

		local universeTable = {
			uuid = universeUuid,
			name = "example",
			workingDirectory = "/home/foo",
			tabpages = {
				{
					uuid = tabpageUuid,
					layout = {
						type = "horizontal",
						children = {},
					},
				},
			},
		}

		local jsonString = json.encode(universeTable)

		it("should not throw when buffers is missing", function()
			assert.has_no.errors(function()
				universe_factory.make(jsonString)
			end)
		end)

		it("should return a universe with an empty buffers table", function()
			local universe = universe_factory.make(jsonString)
			assert.are.equal(0, #universe.buffers)
		end)
	end)

	describe("a tabpage json payload where layout is an empty table", function()
		it("should not throw when layout is an empty table missing a children key", function()
			assert.has_no.errors(function()
				universe_factory.make(
					'{"uuid":"a","name":"example","workingDirectory":"/home/foo","tabpages":[{"layout":{}}]}'
				)
			end)
		end)

		it("should default to a layout with no children when layout is missing a children key", function()
			local universe = universe_factory.make(
				'{"uuid":"a","name":"example","workingDirectory":"/home/foo","tabpages":[{"layout":{}}]}'
			)
			assert.is_not.Nil(universe)
			local tabpage = universe.tabpages[1]
			assert.is_not.Nil(tabpage.layout)
			assert.are.equal(0, #tabpage.layout.children)
		end)
	end)

	describe("a tabpage json payload where layout has a type but no children key", function()
		it("should not throw when layout has a type but is missing a children key", function()
			assert.has_no.errors(function()
				universe_factory.make(
					'{"uuid":"a","name":"example","workingDirectory":"/home/foo","tabpages":[{"layout":{"type":"row"}}]}'
				)
			end)
		end)

		it("should default to a layout with no children when layout is missing a children key", function()
			local universe = universe_factory.make(
				'{"uuid":"a","name":"example","workingDirectory":"/home/foo","tabpages":[{"layout":{"type":"row"}}]}'
			)
			assert.is_not.Nil(universe)
			local tabpage = universe.tabpages[1]
			assert.is_not.Nil(tabpage.layout)
			assert.are.equal(0, #tabpage.layout.children)
		end)
	end)

	describe("a tabpage json payload where layout children contains non-well-formed nodes", function()
		it("should not throw when layout children contains non-well-formed elements", function()
			assert.has_no.errors(function()
				universe_factory.make(
					'{"uuid":"a","name":"example","workingDirectory":"/home/foo","tabpages":[{"layout":{"type":"row","children":[1,2]}}]}'
				)
			end)
		end)

		it("should default to a layout with no children when layout children are malformed", function()
			local universe = universe_factory.make(
				'{"uuid":"a","name":"example","workingDirectory":"/home/foo","tabpages":[{"layout":{"type":"row","children":[1,2]}}]}'
			)
			assert.is_not.Nil(universe)
			local tabpage = universe.tabpages[1]
			assert.is_not.Nil(tabpage.layout)
			assert.are.equal(0, #tabpage.layout.children)
		end)
	end)

	describe("a tabpage json payload with a nil layout", function()
		local universeUuid = "8d1f9c2a-bbbb-4a2b-9c3d-00000000000b"
		local tabpageUuid = "8d1f9c2a-cccc-4a2b-9c3d-00000000000c"

		local universeTable = {
			uuid = universeUuid,
			name = "example",
			workingDirectory = "/home/foo",
			tabpages = {
				{
					uuid = tabpageUuid,
				},
			},
		}

		local jsonString = json.encode(universeTable)

		it("should not throw when a tabpage's layout key is missing", function()
			assert.has_no.errors(function()
				universe_factory.make(jsonString)
			end)
		end)

		it("should default to a layout with no children", function()
			local universe = universe_factory.make(jsonString)
			local tabpage = universe.tabpages[1]
			assert.is_not.Nil(tabpage.layout)
			assert.are.equal(0, #tabpage.layout.children)
		end)
	end)
end)
