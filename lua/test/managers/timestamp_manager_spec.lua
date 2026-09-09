local timestamp_manager = require("multiverse.managers.timestamp_manager")

local MAX_TICK_DRIFT_SECONDS = 2
-- POSIX-format TZ string: forces a non-UTC offset without requiring a
-- zoneinfo database, so this is deterministic regardless of the ambient
-- host timezone (e.g. CI runners default to UTC, which would otherwise
-- mask a timezone-sensitive bug in now()).
local NON_UTC_TZ = "EST5EDT,M3.2.0,M11.1.0"

describe("timestamp_manager", function()
	describe("now", function()
		it("should return a number", function()
			local result = timestamp_manager.now()

			assert.are.equal("number", type(result))
		end)

		describe("under a forced non-UTC TZ", function()
			local original_tz

			before_each(function()
				original_tz = vim.env.TZ
				vim.env.TZ = NON_UTC_TZ
			end)

			after_each(function()
				-- Restores the epoch offset (os.time round-trips back to the
				-- ambient TZ correctly), but glibc can keep NON_UTC_TZ's zone
				-- cached for os.date's string formatting afterwards. Keep this
				-- describe block last in the file so no later test relies on
				-- os.date formatting under the restored "original" TZ.
				vim.env.TZ = original_tz
			end)

			it("actually forces a non-UTC offset for this process", function()
				-- Self-verifying: if the forced TZ never reached libc (e.g. a
				-- non-glibc host), os.time(os.date("!*t")) and os.time() would
				-- be equal here and the regression test below would pass
				-- vacuously without catching anything.
				local buggy = os.time(os.date("!*t"))
				local correct = os.time()

				assert.is_true(buggy ~= correct, string.format(
					"expected NON_UTC_TZ to produce a nonzero offset, but os.time(os.date('!*t'))=%d matched os.time()=%d",
					buggy, correct
				))
			end)

			it("should return a timezone-agnostic unix epoch matching os.time()", function()
				-- Both calls happen under the same forced TZ, so this isolates
				-- whether now()'s implementation is timezone-sensitive. A buggy
				-- implementation like os.time(os.date("!*t")) would diverge
				-- from os.time() by the forced TZ's offset; a correct
				-- implementation using plain os.time() will match within a
				-- couple seconds of tick drift between the two calls.
				local result = timestamp_manager.now()
				local expected = os.time()

				assert.is_true(math.abs(result - expected) <= MAX_TICK_DRIFT_SECONDS, string.format(
					"expected now()=%d to be within %ds of os.time()=%d",
					result, MAX_TICK_DRIFT_SECONDS, expected
				))
			end)
		end)
	end)
end)
