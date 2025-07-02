local M = {}

local window_layout_factory = require("multiverse.factory.window_layout_factory")

--- @param tabpageId number
--- @param universe Universe
--- @return WindowLayout
M.getWindowLayout = function(tabpageId, universe)
	local layout = vim.fn.winlayout(tabpageId)
	vim.notify(vim.inspect(layout))
	return window_layout_factory.make(layout, universe)
end

--- @param universe Universe
--- @param tabpage Tabpage
local function hydrateTabpage(universe, tabpage)
	vim.api.nvim_set_current_tabpage(tabpage.tabpageId)

	local layout = tabpage.layout

	local unexplored_layout = { layout.children[1] } -- start at the first row rather than the window layout root

	while #unexplored_layout > 0 do
		local node = table.remove(unexplored_layout, 1)

		if node.windowId ~= nil then
			vim.api.nvim_set_current_win(node.windowId)
		end

		if nil == node.children then
			vim.notify("Node has no children: " .. vim.inspect(node))
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
              vim.notify("Found window buffer with uuid: " .. vim.inspect(buffer.bufferUuid))
						  vim.api.nvim_set_current_buf(buffer.bufferId)
					  else
						  vim.notify("Buffer uuid: " .. vim.inspect(window.bufferUuid) .. "not found in universe buffers, available buffers: " .. vim.inspect(universe.buffers))
					  end

            else
            vim.notify("Window has no buffer uuid: " .. vim.inspect(window))
          end

				else
					vim.notify("Could not find window with uuid: " .. vim.inspect(child.windowUuid))
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
