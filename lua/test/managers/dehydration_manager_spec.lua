local stub = require("luassert.stub")

local Tabpage = require("multiverse.data.Tabpage")
local Window = require("multiverse.data.Window")
local tabpage_manager = require("multiverse.managers.tabpage_manager")
local buffer_manager = require("multiverse.managers.buffer_manager")
local window_manager = require("multiverse.managers.window_manager")
local window_layout_manager = require("multiverse.managers.window_layout_manager")
local log = require("multiverse.log")
local dehydration_manager = require("multiverse.managers.dehydration_manager")

describe("dehydration_manager.dehydrate", function()
	local getTabpages_stub
	local get_all_buffers_stub
	local getAllVisibleWindowsForTabpage_stub
	local getWindowLayout_stub
	local nvim_win_get_buf_stub
	local notify_stub
	local log_error_stub
	local log_debug_stub

	local summary = { uuid = "universe-uuid", name = "some-name", directory = "/tmp" }
	local tabpage
	local window

	before_each(function()
		tabpage = Tabpage:new("tabpage-uuid", 1, "window-uuid")
		window = Window:new("window-uuid", nil, 42)

		getTabpages_stub = stub(tabpage_manager, "getTabpages", function()
			return { tabpage }
		end)
		get_all_buffers_stub = stub(buffer_manager, "get_all_buffers", function()
			return {}
		end)
		getAllVisibleWindowsForTabpage_stub = stub(window_manager, "getAllVisibleWindowsForTabpage", function()
			return { window }
		end)
		getWindowLayout_stub = stub(window_layout_manager, "getWindowLayout", function()
			return nil
		end)
		nvim_win_get_buf_stub = stub(vim.api, "nvim_win_get_buf", function()
			return 999
		end)
		notify_stub = stub(vim, "notify")
		log_error_stub = stub(log, "error")
		-- Stubbed (not asserted) to silence dehydration_manager's unrelated
		-- log.debug calls further down in dehydrate().
		log_debug_stub = stub(log, "debug")
	end)

	after_each(function()
		getTabpages_stub:revert()
		get_all_buffers_stub:revert()
		getAllVisibleWindowsForTabpage_stub:revert()
		getWindowLayout_stub:revert()
		nvim_win_get_buf_stub:revert()
		notify_stub:revert()
		log_error_stub:revert()
		log_debug_stub:revert()
	end)

	it("notifies a short message without dumping the universe object, and logs the details", function()
		dehydration_manager.dehydrate(summary)

		assert.stub(notify_stub).was.called_with(
			"Error: Buffer with ID 999 not found in universe universe-uuid",
			vim.log.levels.ERROR
		)

		assert.stub(log_error_stub).was.called_with(
			"Buffer mismatch: buffer id %s not found in universe %s",
			999,
			"universe-uuid"
		)
	end)
end)
