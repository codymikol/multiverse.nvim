local stub = require("luassert.stub")

local window_layout_manager = require("multiverse.managers.window_layout_manager")
local log = require("multiverse.log")

describe("window_layout_manager", function()
	describe("hydrate", function()
		local nvim_set_current_tabpage_stub
		local log_debug_stub
		local log_warn_stub

		before_each(function()
			nvim_set_current_tabpage_stub = stub(vim.api, "nvim_set_current_tabpage")
			log_debug_stub = stub(log, "debug")
			log_warn_stub = stub(log, "warn")
		end)

		after_each(function()
			nvim_set_current_tabpage_stub:revert()
			log_debug_stub:revert()
			log_warn_stub:revert()
		end)

		-- Each tabpage's empty `children` makes hydrateTabpage's own
		-- "no layout children to hydrate" guard return immediately, so these
		-- fixtures exercise hydrate()'s post-loop focus restoration without
		-- needing real windows/buffers.
		local function make_universe()
			return {
				tabpages = {
					{ uuid = "tab-1", tabpageId = 101, layout = { children = {} } },
					{ uuid = "tab-2", tabpageId = 102, layout = { children = {} } },
					{ uuid = "tab-3", tabpageId = 103, layout = { children = {} } },
				},
			}
		end

		describe("when universe.currentTabpage matches a tabpage that is not last in the list", function()
			it("should finish hydration focused on that tabpage, not the last iterated one", function()
				local universe = make_universe()
				universe.currentTabpage = "tab-2"

				window_layout_manager.hydrate(universe)

				local last_call = nvim_set_current_tabpage_stub.calls[#nvim_set_current_tabpage_stub.calls]
				assert.are.equal(102, last_call.refs[1])
			end)
		end)

		describe("when universe.currentTabpage is nil", function()
			it("should leave focus on the last tabpage in the list (existing fallback behavior)", function()
				local universe = make_universe()
				universe.currentTabpage = nil

				window_layout_manager.hydrate(universe)

				local last_call = nvim_set_current_tabpage_stub.calls[#nvim_set_current_tabpage_stub.calls]
				assert.are.equal(103, last_call.refs[1])
			end)
		end)

		describe("when universe.currentTabpage does not match any tabpage uuid", function()
			it("should leave focus on the last tabpage in the list (existing fallback behavior)", function()
				local universe = make_universe()
				universe.currentTabpage = "stale-uuid-from-a-deleted-tabpage"

				window_layout_manager.hydrate(universe)

				local last_call = nvim_set_current_tabpage_stub.calls[#nvim_set_current_tabpage_stub.calls]
				assert.are.equal(103, last_call.refs[1])
			end)
		end)
	end)
end)
