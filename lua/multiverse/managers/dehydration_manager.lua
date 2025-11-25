local Universe = require("multiverse.data.Universe")
local window_manager = require("multiverse.managers.window_manager")
local buffer_manager = require("multiverse.managers.buffer_manager")
local tabpage_manager = require("multiverse.managers.tabpage_manager")
local window_layout_manager = require("multiverse.managers.window_layout_manager")
local log                   = require("multiverse.log")

local M = {}

--- Dehydrates all open tabpages, windows, and buffers into a universe object.

--- @param summary UniverseSummary
--- @return Universe
M.dehydrate = function(summary)

	local universe = Universe:new(summary.uuid, summary.name, summary.directory)

	local tabpages = tabpage_manager.getTabpages()
	local buffers = buffer_manager.get_all_buffers()

	universe:addAllBuffers(buffers)
	universe:addAllTabpages(tabpages)

	for _, tabpage in pairs(tabpages) do
		local windows = window_manager.getAllVisibleWindowsForTabpage(tabpage.tabpageId)

		tabpage:addAllWindows(windows)

		for _, window in pairs(windows) do
			local windowBufferId = vim.api.nvim_win_get_buf(window.windowId)
			local windowBuffer = universe:getBufferById(windowBufferId)

      if not windowBuffer then
        vim.notify("Error: Buffer with ID " .. windowBufferId .. " not found in universe " .. universe.uuid .. vim.inspect(universe), vim.log.levels.ERROR)
      end

			local windowBufferUuid = windowBuffer.uuid
			window:setBufferUuid(windowBufferUuid)
		end

		local layout = window_layout_manager.getWindowLayout(tabpage.tabpageId, universe)

		tabpage:setLayout(layout)
	end

  for i, tabpage in ipairs(universe.tabpages) do
    log.debug("Tabpage: " .. vim.inspect(i))
    for j, window in ipairs(tabpage.windows) do
      log.debug("  Window: " .. vim.inspect(j) .. " Buffer UUID: " .. vim.inspect(window.bufferUuid))
      local buffer = universe:getBufferByUuid(window.bufferUuid)
      if buffer then
        log.debug("    Buffer: " .. vim.inspect(buffer.bufferId) .. " Name: " .. vim.inspect(buffer.bufferName))
      else
        log.debug("    Buffer not found for UUID: " .. vim.inspect(window.bufferUuid))
      end
    end
  end

	return universe
end

return M
