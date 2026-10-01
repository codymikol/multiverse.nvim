local stub = require("luassert.stub")

-- Inject a fake telescope integration before requiring cli_manager (transitively
-- required by multiverse.lua) so it never reaches the real telescope.nvim modules,
-- which are not available in CI.
package.loaded["integrations.telescope"] = { prompt_select_universe = function() end }

local Multiverse = require("multiverse")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local MultiverseData = require("multiverse.data.Multiverse")
local UniverseSummary = require("multiverse.data.UniverseSummary")

describe("Multiverse.status", function()
	local getMultiverse_stub
	local getcwd_stub

	after_each(function()
		if getMultiverse_stub then
			getMultiverse_stub:revert()
			getMultiverse_stub = nil
		end
		if getcwd_stub then
			getcwd_stub:revert()
			getcwd_stub = nil
		end
	end)

	it("returns the active universe's name when cwd resolves to a registered universe", function()
		local cwd = "/tmp/multiverse-spec/status-active"
		local universe_summary =
			UniverseSummary:new({ directory = cwd, uuid = "status-uuid", name = "status-universe" })
		local multiverse = MultiverseData:new({ universe_summary })

		getMultiverse_stub = stub(multiverse_repository, "getMultiverse")
		getMultiverse_stub.returns(multiverse)

		getcwd_stub = stub(vim.fn, "getcwd")
		getcwd_stub.returns(cwd)

		assert.are.equal("status-universe", Multiverse.status())
	end)

	it("returns an empty string when cwd does not resolve to any registered universe", function()
		local universe_summary =
			UniverseSummary:new({ directory = "/tmp/multiverse-spec/other", uuid = "other-uuid", name = "other-universe" })
		local multiverse = MultiverseData:new({ universe_summary })

		getMultiverse_stub = stub(multiverse_repository, "getMultiverse")
		getMultiverse_stub.returns(multiverse)

		getcwd_stub = stub(vim.fn, "getcwd")
		getcwd_stub.returns("/tmp/multiverse-spec/unmatched")

		assert.are.equal("", Multiverse.status())
	end)

	it("returns an empty string when no multiverse is loaded", function()
		getMultiverse_stub = stub(multiverse_repository, "getMultiverse")
		getMultiverse_stub.returns(nil)

		assert.are.equal("", Multiverse.status())
	end)

	it("doubles '%' in the universe name so statusline/winbar renderers don't expand it", function()
		local cwd = "/tmp/multiverse-spec/status-percent"
		local universe_summary = UniverseSummary:new({ directory = cwd, uuid = "percent-uuid", name = "50% done" })
		local multiverse = MultiverseData:new({ universe_summary })

		getMultiverse_stub = stub(multiverse_repository, "getMultiverse")
		getMultiverse_stub.returns(multiverse)

		getcwd_stub = stub(vim.fn, "getcwd")
		getcwd_stub.returns(cwd)

		assert.are.equal("50%% done", Multiverse.status())
	end)

	it("strips control bytes from the universe name", function()
		local cwd = "/tmp/multiverse-spec/status-control"
		local universe_summary =
			UniverseSummary:new({ directory = cwd, uuid = "control-uuid", name = "a\027b" })
		local multiverse = MultiverseData:new({ universe_summary })

		getMultiverse_stub = stub(multiverse_repository, "getMultiverse")
		getMultiverse_stub.returns(multiverse)

		getcwd_stub = stub(vim.fn, "getcwd")
		getcwd_stub.returns(cwd)

		assert.are.equal("ab", Multiverse.status())
	end)
end)
