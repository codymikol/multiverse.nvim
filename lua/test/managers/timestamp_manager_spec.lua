local timestamp_manager = require("multiverse.managers.timestamp_manager")

describe("timestamp_manager", function()
	describe("now", function()
		it("should return a number", function()
			local result = timestamp_manager.now()

			assert.is_true(type(result) == "number")
		end)

		it("should return a timezone-agnostic unix epoch matching os.time()", function()
			local result = timestamp_manager.now()

			-- os.time() with no argument already returns the current epoch seconds
			-- regardless of the host's timezone. timestamp_manager.now() should match
			-- it within a couple seconds of tick drift between the two calls. If
			-- now() instead round-trips through os.date("!*t"), the values will
			-- diverge by the host's UTC offset on any non-UTC host.
			assert.is_true(math.abs(result - os.time()) <= 2)
		end)
	end)
end)
