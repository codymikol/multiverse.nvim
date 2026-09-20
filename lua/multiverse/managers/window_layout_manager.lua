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

--- Hydrates a single leaf layout node: looks up its window/buffer by uuid,
--- records `activeWindowId` (the window the caller has already made current)
--- on it, and sets its buffer as the current buffer. Shared by the
--- single-window (root-is-leaf) case and the main traversal loop's per-child
--- leaf branch below.
--- @param universe Universe
--- @param tabpage Tabpage
--- @param leaf Leaf
--- @param activeWindowId number the window, already current, that this leaf represents
--- @return number|nil bufferId the buffer id set current, or nil if nothing was hydrated
--- @return number|nil windowId the real window id the buffer was set current in, or nil if nothing was hydrated
local function hydrateLeaf(universe, tabpage, leaf, activeWindowId)
	local window = tabpage:getWindowByUuid(leaf.windowUuid)

	if window == nil then
		log.warn("Could not find window with uuid " .. vim.inspect(leaf.windowUuid) .. " in tabpage " .. vim.inspect(tabpage.tabpageId))
		return nil
	end

	window:setWindowId(activeWindowId)

	if nil == window.bufferUuid then
		log.warn("Window " .. vim.inspect(window.uuid) .. " has no associated buffer")
		return nil
	end

	local buffer = universe:getBufferByUuid(window.bufferUuid)
	if nil == buffer then
		log.warn("Could not find buffer with uuid " .. vim.inspect(window.bufferUuid) .. " for window " .. vim.inspect(window.uuid))
		return nil
	end

	log.debug("Setting window " .. vim.inspect(activeWindowId) .. " to buffer " .. vim.inspect(buffer.bufferId) .. " (" .. vim.inspect(buffer.bufferName) .. ")")
	vim.api.nvim_set_current_buf(buffer.bufferId)
	return buffer.bufferId, activeWindowId
end

--- @param universe Universe
--- @param tabpage Tabpage
--- @return { bufferId: number, windowId: number }[] hydrated_windows buffer/window id pairs set current via nvim_set_current_buf
local function hydrateTabpage(universe, tabpage)
	local hydrated_windows = {}

	vim.api.nvim_set_current_tabpage(tabpage.tabpageId)

  log.debug("Hydrating tabpage " .. vim.inspect(tabpage.tabpageId) .. " with layout " .. vim.inspect(tabpage.layout))

	local layout = tabpage.layout

	local root = layout.children[1] -- start at the first row/column/leaf rather than the window layout root

  if root == nil then
    log.warn("Tabpage " .. vim.inspect(tabpage.tabpageId) .. " has no layout children to hydrate")
    return hydrated_windows
  end

  -- vim.fn.winlayout() returns a bare "leaf" node (no row/column wrapper)
  -- for a tabpage with no splits, so the root here can itself be a Leaf.
  -- The traversal below only sets a buffer for *children* of a row/column
  -- node, so handle this single-window case directly instead.
  if root.type == "leaf" then
    if root.windowId ~= nil then
      vim.api.nvim_set_current_win(root.windowId)
    else
      log.warn("No windowId set for layout node " .. vim.inspect(root.windowUuid) .. "; setting current window to tabpage's current window")
    end

    local activeWindowId = vim.api.nvim_get_current_win()
    local bufferId, windowId = hydrateLeaf(universe, tabpage, root, activeWindowId)
    if bufferId ~= nil then
      table.insert(hydrated_windows, { bufferId = bufferId, windowId = windowId })
    end

    return hydrated_windows
  end

  local unexplored_layout = { root }

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
				-- belowright forces the new window after/right of the current one
				-- regardless of 'splitbelow'/'splitright', so siblings append in order.
				if node.type == "column" then
					vim.cmd("belowright split")
				end
				if node.type == "row" then
					vim.cmd("belowright vsplit")
				end
			end

			local activeWindowId = vim.api.nvim_get_current_win()

			if child.type == "leaf" then
				local bufferId, windowId = hydrateLeaf(universe, tabpage, child, activeWindowId)
				if bufferId ~= nil then
					table.insert(hydrated_windows, { bufferId = bufferId, windowId = windowId })
				end
			else
				-- Leaf has no setWindowId; only container (Row/Column) children need it here.
				child:setWindowId(activeWindowId)
				table.insert(unexplored_layout, child)
			end
		end

		::continue::
	end

	return hydrated_windows
end

--- @param universe Universe
--- @return { bufferId: number, windowId: number }[] hydrated_windows buffer/window id pairs set current across all tabpages
M.hydrate = function(universe)
	local hydrated_windows = {}

	for _, tabpage in ipairs(universe.tabpages) do
		for _, hydrated_window in ipairs(hydrateTabpage(universe, tabpage)) do
			table.insert(hydrated_windows, hydrated_window)
		end
	end

	return hydrated_windows
end

return M
