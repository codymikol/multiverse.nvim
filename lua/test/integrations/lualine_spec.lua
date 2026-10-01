local stub = require("luassert.stub")

-- Inject a fake telescope integration before requiring multiverse (transitively
-- requires cli_manager -> integrations.telescope), which is not available in CI.
package.loaded["integrations.telescope"] = { prompt_select_universe = function() end }

describe("lualine.component", function()
	local lualine = require("integrations.lualine")
	local multiverse = require("multiverse")
	local status_stub

	after_each(function()
		if status_stub then
			status_stub:revert()
			status_stub = nil
		end
	end)

	it("returns the active universe's name when in a universe", function()
		status_stub = stub(multiverse, "status")
		status_stub.returns("test-universe")

		assert.are.equal("test-universe", lualine.component())
	end)

	it("returns an empty string when not in a universe", function()
		status_stub = stub(multiverse, "status")
		status_stub.returns("")

		assert.are.equal("", lualine.component())
	end)
end)
