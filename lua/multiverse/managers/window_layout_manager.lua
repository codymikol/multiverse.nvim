local M = {}

local log = require("multiverse.log")
local window_layout_factory = require("multiverse.factory.window_layout_factory")

--- @param tabpageId number
--- @param universe Universe
--- @return WindowLayout
M.getWindowLayout = function(tabpageId, universe)
	local layout = vim.fn.winlayout(tabpageId)
	return window_layout_factory.make(layout, universe)
end

--- @param universe Universe
--- @param tabpage Tabpage
local function hydrateTabpage(universe, tabpage)
	vim.api.nvim_set_current_tabpage(tabpage.tabpageId)

  log.debug("Hydrating tabpage " .. vim.inspect(tabpage.tabpageId) .. " with layout " .. vim.inspect(tabpage.layout))

	local layout = tabpage.layout

	local unexplored_layout = { layout.children[1] } -- start at the first row rather than the window layout root

  if #unexplored_layout == 0 then
    log.warn("Tabpage " .. vim.inspect(tabpage.tabpageId) .. " has no layout children to hydrate")
    return
  end

	while #unexplored_layout > 0 do
		local node = table.remove(unexplored_layout, 1)

		if node.windowId ~= nil then
			vim.api.nvim_set_current_win(node.windowId)
    else
      log.warn("No windowId set for layout node " .. vim.inspect(node.uuid) .. "; setting current window to tabpage's current window")
		end

		if nil == node.children then
			goto continue
		end

		for idx, child in ipairs(node.children) do
			if idx ~= 1 then
				if node.type == "column" then
					vim.cmd("split")
				end
				if node.type == "row" then
 					vim.cmd("vsplit")
				end
			end

			local activeWindowId = vim.api.nvim_get_current_win()

			node:setWindowId(activeWindowId)

			if child.type == "leaf" then
				local window = tabpage:getWindowByUuid(child.windowUuid)

				if window ~= nil then
					window:setWindowId(activeWindowId)

          if nil ~= window.bufferUuid then
            local buffer = universe:getBufferByUuid(window.bufferUuid)
					  if nil ~= buffer then
              log.debug("Setting window " .. vim.inspect(activeWindowId) .. " to buffer " .. vim.inspect(buffer.bufferId) .. " (" .. vim.inspect(buffer.bufferName) .. ")")
						  vim.api.nvim_set_current_buf(buffer.bufferId)
					  else
              log.warn("Could not find buffer with uuid " .. vim.inspect(window.bufferUuid) .. " for window " .. vim.inspect(window.uuid))
					  end
          else
            log.warn("Window " .. vim.inspect(window.uuid) .. " has no associated buffer")
          end
				else
          log.warn("Could not find window with uuid " .. vim.inspect(child.windowUuid) .. " in tabpage " .. vim.inspect(tabpage.tabpageId))
				end
			else
				table.insert(unexplored_layout, child)
			end
		end

		::continue::
	end
end

--- @param universe Universe
M.hydrate = function(universe)
	for _, tabpage in ipairs(universe.tabpages) do
		hydrateTabpage(universe, tabpage)
	end
end

return M
