describe("multiverse_factory make", function()
	local multiverse_factory = require("multiverse.factory.multiverse_factory")
	local json = require("multiverse.repositories.json")
	local log = require("multiverse.log")
	local stub = require("luassert.stub")

	describe("a happy path multiverse with one universe", function()
		local universeUuid = "8d1f9c2a-1111-4a2b-9c3d-000000000001"

		local multiverseTable = {
			universes = {
				{
					directory = "/home/foo",
					uuid = universeUuid,
					name = "example",
					lastExplored = 42,
				},
			},
		}

		local jsonString = json.encode(multiverseTable)

		local multiverse = multiverse_factory.make(jsonString)

		it("should return a non-nil multiverse", function()
			assert.is_not.Nil(multiverse)
		end)

		it("should have one universe", function()
			assert.are.equal(1, #multiverse.universes)
		end)

		it("should have the correct universe directory", function()
			assert.are.equal("/home/foo", multiverse.universes[1].directory)
		end)

		it("should have the correct universe uuid", function()
			assert.are.equal(universeUuid, multiverse.universes[1].uuid)
		end)

		it("should have the correct universe name", function()
			assert.are.equal("example", multiverse.universes[1].name)
		end)

		it("should have the correct universe lastExplored", function()
			assert.are.equal(42, multiverse.universes[1].lastExplored)
		end)
	end)

	describe("a multiverse json payload with an empty universes array", function()
		local jsonString = json.encode({ universes = {} })

		it("should not throw when the universes array is empty", function()
			assert.has_no.errors(function()
				multiverse_factory.make(jsonString)
			end)
		end)

		it("should return a non-nil multiverse with zero universes", function()
			local multiverse = multiverse_factory.make(jsonString)
			assert.is_not.Nil(multiverse)
			assert.are.equal(0, #multiverse.universes)
		end)
	end)

	describe("a malformed json payload", function()
		it("should not throw when the json string is malformed", function()
			assert.has_no.errors(function()
				multiverse_factory.make("not valid json")
			end)
		end)

		it("should return nil for a malformed json string", function()
			local multiverse = multiverse_factory.make("not valid json")
			assert.is.Nil(multiverse)
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
				multiverse_factory.make("not valid json")
				assert.stub(log_error_stub).was.called()
			end)
		end)
	end)

	describe("a valid json payload that is not a table", function()
		it("should not throw when the decoded json is a number", function()
			assert.has_no.errors(function()
				multiverse_factory.make("42")
			end)
		end)

		it("should return nil when the decoded json is a number", function()
			local multiverse = multiverse_factory.make("42")
			assert.is.Nil(multiverse)
		end)

		describe("log.warn behavior", function()
			local log_warn_stub

			before_each(function()
				log_warn_stub = stub(log, "warn")
			end)

			after_each(function()
				log_warn_stub:revert()
			end)

			it("should call log.warn when the decoded json is not a table", function()
				multiverse_factory.make("42")
				assert.stub(log_warn_stub).was.called()
			end)
		end)
	end)

	describe("a multiverse json payload missing the universes field", function()
		it("should not throw when universes is missing", function()
			assert.has_no.errors(function()
				multiverse_factory.make("{}")
			end)
		end)

		it("should return nil when universes is missing", function()
			local multiverse = multiverse_factory.make("{}")
			assert.is.Nil(multiverse)
		end)

		describe("log.warn behavior", function()
			local log_warn_stub

			before_each(function()
				log_warn_stub = stub(log, "warn")
			end)

			after_each(function()
				log_warn_stub:revert()
			end)

			it("should call log.warn when universes is missing", function()
				multiverse_factory.make("{}")
				assert.stub(log_warn_stub).was.called()
			end)
		end)
	end)

	describe("a multiverse json payload where universes is not a table", function()
		local jsonString = '{"universes":"oops"}'

		it("should not throw when universes is a string", function()
			assert.has_no.errors(function()
				multiverse_factory.make(jsonString)
			end)
		end)

		it("should return nil when universes is a string", function()
			local multiverse = multiverse_factory.make(jsonString)
			assert.is.Nil(multiverse)
		end)

		describe("log.warn behavior", function()
			local log_warn_stub

			before_each(function()
				log_warn_stub = stub(log, "warn")
			end)

			after_each(function()
				log_warn_stub:revert()
			end)

			it("should call log.warn when universes is not a table", function()
				multiverse_factory.make(jsonString)
				assert.stub(log_warn_stub).was.called()
			end)
		end)
	end)

	describe("a multiverse json payload with a non-table universe entry", function()
		local jsonString = '{"universes":[1]}'

		it("should not throw when a universe entry is not a table", function()
			assert.has_no.errors(function()
				multiverse_factory.make(jsonString)
			end)
		end)

		it("should return nil when a universe entry is not a table", function()
			local multiverse = multiverse_factory.make(jsonString)
			assert.is.Nil(multiverse)
		end)

		describe("log.warn behavior", function()
			local log_warn_stub

			before_each(function()
				log_warn_stub = stub(log, "warn")
			end)

			after_each(function()
				log_warn_stub:revert()
			end)

			it("should call log.warn when a universe entry is not a table", function()
				multiverse_factory.make(jsonString)
				assert.stub(log_warn_stub).was.called()
			end)
		end)
	end)

	describe("a multiverse json payload with a universe entry missing required fields", function()
		local jsonString = '{"universes":[{}]}'

		it("should not throw when a universe entry is missing required fields", function()
			assert.has_no.errors(function()
				multiverse_factory.make(jsonString)
			end)
		end)

		it("should return nil when a universe entry is missing required fields", function()
			local multiverse = multiverse_factory.make(jsonString)
			assert.is.Nil(multiverse)
		end)

		describe("log.warn behavior", function()
			local log_warn_stub

			before_each(function()
				log_warn_stub = stub(log, "warn")
			end)

			after_each(function()
				log_warn_stub:revert()
			end)

			it("should call log.warn when a universe entry is missing required fields", function()
				multiverse_factory.make(jsonString)
				assert.stub(log_warn_stub).was.called()
			end)
		end)
	end)

	describe("a multiverse json payload with one valid and one invalid universe entry", function()
		local jsonString = '{"universes":[{"directory":"/d","uuid":"u1","name":"n1"}, {}]}'

		it("should not throw", function()
			assert.has_no.errors(function()
				multiverse_factory.make(jsonString)
			end)
		end)

		it("should return nil, invalidating the whole payload", function()
			local multiverse = multiverse_factory.make(jsonString)
			assert.is.Nil(multiverse)
		end)

		describe("log.warn behavior", function()
			local log_warn_stub

			before_each(function()
				log_warn_stub = stub(log, "warn")
			end)

			after_each(function()
				log_warn_stub:revert()
			end)

			it("should call log.warn when a mix of valid and invalid universe entries is given", function()
				multiverse_factory.make(jsonString)
				assert.stub(log_warn_stub).was.called()
			end)
		end)
	end)
end)
