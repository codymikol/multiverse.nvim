local M = {}

local actions = require("telescope.actions")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local sorters = require("telescope.sorters")
local previewers = require("telescope.previewers")
local action_state = require("telescope.actions.state")
local utils = require("telescope.previewers.utils")
local universe_repository = require("multiverse.repositories.universe_repository")
local log = require("multiverse.log")

local ns_id = vim.api.nvim_create_namespace("Multiverse")

vim.api.nvim_set_hl(ns_id, "MyCustomGroup", { fg = "#ff0000", bg = "#000000", bold = true })
-- Custom highlight groups
vim.api.nvim_set_hl(0, "MultiverseFilename", { fg = "#7BAAF7" }) -- blue for filenames
vim.api.nvim_set_hl(0, "MultiverseRowCol", { fg = "#6C757D", italic = true }) -- grey for rows/columns
vim.api.nvim_set_hl(0, "MultiverseDate", { fg = "#32CD32", bold = true }) -- Lime green for dates
vim.api.nvim_set_hl(0, "MultiverseUniverse", { fg = "#FFA3D1", underline = true }) -- Hot pink for universe names

-- Looks like shit, but just want something working and we can clean it up later
local function apply_markup_highlighting(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	for i, line in ipairs(lines) do
		local col_tag_start, col_tag_end = line:find("col")

    if i == 1 then
      local last_space = line:match(".* ()")
      if last_space then

			vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, 0, {
				end_col = last_space - 2,
				hl_group = "MultiverseUniverse",
			})

			vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, last_space - 2, {
				end_col = #line,
				hl_group = "MultiverseDate",
			})

      end

      goto continue
    end

		if col_tag_start and col_tag_end then
			vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, col_tag_start - 1, {
				end_col = col_tag_end,
				hl_group = "MultiverseRowCol",
			})
			goto continue
		end

		local row_tag_start, row_tag_end = line:find("row")

		if row_tag_start and row_tag_end then
			vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, row_tag_start - 1, {
				end_col = row_tag_end,
				hl_group = "MultiverseRowCol",
			})
			goto continue
		end

		local filename_tag_start, filename_tag_end = line:find("├─")

		if filename_tag_start and filename_tag_end then
			vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, filename_tag_end, {
				end_col = #line,
				hl_group = "MultiverseFilename",
			})
			goto continue
		end

		local filename_bottom_tag_start, filename_bottom_tag_end = line:find("└─")

		if filename_bottom_tag_start and filename_bottom_tag_end then
			vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, filename_bottom_tag_end, {
				end_col = #line,
				hl_group = "MultiverseFilename",
			})
			goto continue
		end

		::continue::
	end
end
local function get_universe_preview(universe_summary)
	local lines = {
		"" .. universe_summary.name .. " " .. universe_summary.directory,
		"last explored: " .. os.date("%Y-%m-%d %H:%M:%S", universe_summary.lastExplored),
		"",
	}

	local err, universe = universe_repository.getUniverseByUuid(universe_summary.uuid)

	if err then
		vim.notify("Error fetching universe for preview: " .. err, vim.log.levels.ERROR)
		log.error("Error fetching universe preview: " .. vim.inspect(err))
		return lines
	end

	if not universe then
		vim.notify("Error: Universe not found for UUID: " .. universe_summary.uuid)
		log.debug("Error: Universe not found for UUID: " .. vim.inspect(universe_summary))
		return lines
	end

	local get_node_indent = function(node, is_last)
		if node == nil then
			log.error("get_node_indent called with nil node")
			return ""
		end

		if node.depth == nil then
			log.error("get_node_indent called with node without depth: " .. vim.inspect(node))
			return ""
		end

		local indent = ""
		for i = 1, node.depth - 1 do
			indent = indent .. "   " -- Vertical line for intermediate levels
		end

		if node.depth > 0 then
			if is_last then
				indent = indent .. "└─ " -- Last child
			else
				indent = indent .. "├─ " -- Intermediate child
			end
		end

		return indent
	end

	local shown_buffers = {}

	for i, tabpage in ipairs(universe.tabpages) do
		local tabpage_text = "tabpage " .. i

		table.insert(lines, tabpage_text)

		local layout = tabpage.layout

		local unexplored_layout = { layout.children[1] } -- start at the first row rather than the window layout root

    if #unexplored_layout == 0 then
      return lines
    end

		unexplored_layout[1].depth = 0 -- initialize depth for the root node

		while #unexplored_layout > 0 do
			local node = table.remove(unexplored_layout, 1)

			if nil == node.children then
				goto continue
			end

			for idx, child in ipairs(node.children) do
				local is_last_child = (idx == #node.children)

				child.depth = node.depth + 1

				if idx ~= 1 then
					if child.type == "column" then
						local column_line = string.sub(get_node_indent(child, is_last_child), 1, -2) .. "─┐  col"
						table.insert(lines, column_line)
					end
					if child.type == "row" then
						local row_line = string.sub(get_node_indent(child, is_last_child), 1, -2) .. "─┐  " .. "row"
						table.insert(lines, row_line)
					end
				end

				if child.type == "leaf" then

          if child.windowUuid == nil then
            log.warn("Leaf node without window UUID: " .. vim.inspect(child))
            goto continue
          end

					local window = tabpage:getWindowByUuid(child.windowUuid)

					local window_description = "no buffer"

          if window == nil then
            log.error("Window not found for UUID: " .. child.windowUuid)
            goto continue
          end

					if window.bufferUuid then
						local buffer = universe:getBufferByUuid(window.bufferUuid)
						if buffer then
							shown_buffers[buffer.bufferName] = true -- Track shown buffers
							local filename = string.match(buffer.bufferName, ".*/(.*)$") -- Get the filename from the path
							window_description = filename or buffer.bufferName
						end
					end

					local leaf_line = get_node_indent(child, is_last_child) .. window_description
					table.insert(lines, leaf_line)

					local window = tabpage:getWindowByUuid(child.windowUuid)

					if window ~= nil then
						if nil ~= window.bufferUuid then
							local buffer = universe:getBufferByUuid(window.bufferUuid)
							if nil ~= buffer then
							end
						end
					end
				else
					table.insert(unexplored_layout, child)
				end
			end

			::continue::
		end
	end

	local buffers_not_displayed = {}
	for _, buffer in ipairs(universe.buffers) do
		if not shown_buffers[buffer.bufferName] then
			table.insert(buffers_not_displayed, buffer)
		end
	end

	if #buffers_not_displayed > 0 then
		table.insert(lines, "")
		table.insert(lines, "buffers not displayed in layout:")
		table.insert(lines, "")
		for _, buffer in ipairs(buffers_not_displayed) do
			local filename = string.match(buffer.bufferName, ".*/(.*)$") -- Get the filename from the path
			local buffer_display_name = filename or buffer.bufferName
			table.insert(lines, buffer_display_name)
		end
	end

	return lines
end

---@param universe_summaries UniverseSummary[]
---@param callback fun(selected_universe: UniverseSummary | nil)
---@return nil
M.prompt_select_universe = function(universe_summaries, callback)
	pickers
		.new({}, {
			prompt_title = "Universes",
			finder = finders.new_table({
				results = universe_summaries,
				entry_maker = function(entry)
					return {
						value = entry,
						display = entry.name,
						ordinal = entry.name,
					}
				end,
			}),
			sorter = sorters.get_generic_fuzzy_sorter(), -- todo(mikol): this should sort by LRU
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					callback(selection.value)
				end)
				return true
			end,
			previewer = previewers.new_buffer_previewer({
				define_preview = function(self, entry, _status)
					local universe = entry.value

					local lines = get_universe_preview(universe)

					vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)

					apply_markup_highlighting(self.state.bufnr)

				end,
			}),
		})
		:find()
end

return M
