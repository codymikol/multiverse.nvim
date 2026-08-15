local tabpage_manager = require("multiverse.managers.tabpage_manager")
local Universe = require("multiverse.data.Universe")
local Tabpage = require("multiverse.data.Tabpage")
local stub = require("luassert.stub")

--- Builds a Universe with `n` freshly created Tabpages appended, for use in hydrate tests.
--- @param n number
--- @return Universe
local function makeUniverseWithTabpages(n)
	local universe = Universe:new("", "example", "/home/foo")
	for i = 1, n do
		universe:addTabpage(Tabpage:new("uuid" .. i, nil, ""))
	end
	return universe
end

describe("tabpage_manager", function()
	describe("getTabpages", function()
		local nvim_list_tabpages_stub

		before_each(function()
			nvim_list_tabpages_stub = stub(vim.api, "nvim_list_tabpages")
			nvim_list_tabpages_stub.returns({ 1000, 1001 })
		end)

		after_each(function()
			nvim_list_tabpages_stub:revert()
		end)

		it("should return one Tabpage per entry returned by nvim_list_tabpages", function()
			local tabpages = tabpage_manager.getTabpages()

			assert.are.equal(2, #tabpages)
		end)

		it("should return an empty table when nvim_list_tabpages returns none", function()
			nvim_list_tabpages_stub.returns({})

			local tabpages = tabpage_manager.getTabpages()

			assert.are.same({}, tabpages)
		end)

		it("should assign the correct tabpageId to each Tabpage", function()
			local tabpages = tabpage_manager.getTabpages()

			assert.are.equal(1000, tabpages[1].tabpageId)
			assert.are.equal(1001, tabpages[2].tabpageId)
		end)

		it("should default activeWindowUuid to an empty string", function()
			local tabpages = tabpage_manager.getTabpages()

			-- This intentionally documents the current placeholder behavior of the
			-- `-- todo(mikol): We need to find the active windowId for this tabpage and assign it here.`
			-- comment in tabpage_manager.lua, and will need updating once that TODO is resolved.
			assert.are.equal("", tabpages[1].activeWindowUuid)
			assert.are.equal("", tabpages[2].activeWindowUuid)
		end)

		it("should assign each Tabpage a non-empty uuid", function()
			local tabpages = tabpage_manager.getTabpages()

			assert.is_true(type(tabpages[1].uuid) == "string" and #tabpages[1].uuid > 0)
			assert.is_true(type(tabpages[2].uuid) == "string" and #tabpages[2].uuid > 0)
		end)

		it("should assign distinct uuids to each Tabpage", function()
			local tabpages = tabpage_manager.getTabpages()

			assert.are_not.equal(tabpages[1].uuid, tabpages[2].uuid)
		end)
	end)

	describe("hydrate", function()
		local vim_cmd_stub
		local nvim_get_current_tabpage_stub

		before_each(function()
			vim_cmd_stub = stub(vim, "cmd")
			nvim_get_current_tabpage_stub = stub(vim.api, "nvim_get_current_tabpage")
			nvim_get_current_tabpage_stub.returns(2000)
		end)

		after_each(function()
			vim_cmd_stub:revert()
			nvim_get_current_tabpage_stub:revert()
		end)

		it("should open a new tabpage for every tabpage after the first", function()
			local universe = makeUniverseWithTabpages(3)

			tabpage_manager.hydrate(universe)

			assert.stub(vim_cmd_stub).was.called(2)
			assert.stub(vim_cmd_stub).was.called_with("tabnew")
		end)

		it("should not open a new tabpage for the first tabpage", function()
			local universe = makeUniverseWithTabpages(1)

			tabpage_manager.hydrate(universe)

			assert.stub(vim_cmd_stub).was_not_called()
		end)

		it("should be a no-op when universe.tabpages is empty", function()
			local universe = makeUniverseWithTabpages(0)

			tabpage_manager.hydrate(universe)

			assert.stub(vim_cmd_stub).was_not_called()
		end)

		it("should set tabpageId for every tabpage from nvim_get_current_tabpage", function()
			local universe = makeUniverseWithTabpages(2)

			local nextId = 2000
			nvim_get_current_tabpage_stub.invokes(function()
				nextId = nextId + 1
				return nextId
			end)

			tabpage_manager.hydrate(universe)

			assert.are.equal(2001, universe.tabpages[1].tabpageId)
			assert.are.equal(2002, universe.tabpages[2].tabpageId)
			assert.are_not.equal(universe.tabpages[1].tabpageId, universe.tabpages[2].tabpageId)
		end)
	end)

	it("should not expose a closeAll function", function()
		assert.is_nil(tabpage_manager.closeAll)
	end)
end)
