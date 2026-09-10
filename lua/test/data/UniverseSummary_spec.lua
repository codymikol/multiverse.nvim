local stub = require("luassert.stub")

local UniverseSummary = require("multiverse.data.UniverseSummary")
local timestamp_manager = require("multiverse.managers.timestamp_manager")

describe("UniverseSummary", function()
	describe("setLastExploredToNow", function()
		local now_stub

		before_each(function()
			now_stub = stub(timestamp_manager, "now").returns(1234)
		end)

		after_each(function()
			now_stub:revert()
		end)

		it("should set lastExplored to the current timestamp and return self", function()
			local universe = UniverseSummary:new("/dir-1", "uuid-1", "name-1", 1)
			local result = universe:setLastExploredToNow()

			assert.are.equal(1234, universe.lastExplored)
			assert.are.equal(universe, result)
		end)
	end)
end)
