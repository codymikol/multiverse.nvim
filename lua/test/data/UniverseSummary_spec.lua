local UniverseSummary = require("multiverse.data.UniverseSummary")

describe("UniverseSummary.lastExploredOrZero", function()
	it("returns 0 when universe_summary is nil", function()
		assert.are.equal(0, UniverseSummary.lastExploredOrZero(nil))
	end)

	it("returns 0 when lastExplored is nil", function()
		assert.are.equal(0, UniverseSummary.lastExploredOrZero({ lastExplored = nil }))
	end)

	it("returns 0 when lastExplored is non-numeric", function()
		assert.are.equal(0, UniverseSummary.lastExploredOrZero({ lastExplored = "garbage" }))
	end)

	it("returns 0 when lastExplored is NaN", function()
		assert.are.equal(0, UniverseSummary.lastExploredOrZero({ lastExplored = 0 / 0 }))
	end)

	it("returns 0 when lastExplored is negative", function()
		assert.are.equal(0, UniverseSummary.lastExploredOrZero({ lastExplored = -5 }))
	end)

	it("returns the value when lastExplored is a valid positive number", function()
		assert.are.equal(42, UniverseSummary.lastExploredOrZero({ lastExplored = 42 }))
	end)

	it("returns 0 when universe_summary is not a table (number)", function()
		assert.are.equal(0, UniverseSummary.lastExploredOrZero(42))
	end)

	it("returns 0 when universe_summary is not a table (boolean)", function()
		assert.are.equal(0, UniverseSummary.lastExploredOrZero(true))
	end)
end)
