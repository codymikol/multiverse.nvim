local WindowLayout = require("multiverse.data.layout.WindowLayout")
local Column = require("multiverse.data.layout.Column")
local Row = require("multiverse.data.layout.Row")
local Leaf = require("multiverse.data.layout.Leaf")
local json = require("multiverse.repositories.json")

local M = {}

--- @param nodeType string
local function makeLayout(nodeType)
	if nodeType == "row" then
		return Row:new()
	end
	if nodeType == "col" then
		return Column:new()
	end
	if nodeType == "column" then
		return Column:new()
	end -- todo(mikol): gross, both make fn's are using this, refactor later.
end

-- todo(mikol): the fact that I need to do this dance twice for
--
-- json -> WindowLayout
-- neovim layout -> WindowLayout
--
-- tells me this could use some thinkin...

--- @param neovimWindowLayout table
--- @param universe Universe
--- @return WindowLayout
M.make = function(neovimWindowLayout, universe)
	local windowLayout = WindowLayout:new()

	local unexplored_nodes = {
		{
			cursor = windowLayout,
			layout = neovimWindowLayout,
		},
	}

	while #unexplored_nodes > 0 do
		local node = table.remove(unexplored_nodes, 1) -- pulls from the end

		local type = node.layout[1]

		if type == "row" or type == "col" then
			local children = node.layout[2]

			local layout = makeLayout(type)

			node.cursor:addChild(layout)

			for _, child in ipairs(children) do
				local unexplored = {
					cursor = layout,
					layout = child,
				}

				table.insert(unexplored_nodes, unexplored)
			end
		end

		if type == "leaf" then
			local windowId = node.layout[2]
			local window = universe:getWindowById(windowId)

			local windowUuid = nil

			if window ~= nil then
				windowUuid = window.uuid
        local leaf = Leaf:new(windowUuid, windowId)
        node.cursor:addChild(leaf)
			end

		end
	end

	return windowLayout
end

--- @param jsonManifest table
--- @return WindowLayout
M.makeFromJson = function(jsonManifest)
	local windowLayout = WindowLayout:new()

	local manifestFirstRow = jsonManifest.children[1] -- The root node of the manifest

	local unexplored_nodes = {
		{
			cursor = windowLayout,
			manifest = manifestFirstRow,
		},
	}

	while #unexplored_nodes > 0 do
		local node = table.remove(unexplored_nodes, 1) -- pulls from the end

    local manifest = node.manifest

    if manifest == nil then
      -- Node manifest is nil, skipping node...
      goto continue
    end

		local type = node.manifest.type

		if type == "row" or type == "column" then -- todo(mikol): refactor column -> col so the neovim format and our format are the same...
			local children = node.manifest.children

			local layout = makeLayout(type)

			node.cursor:addChild(layout)

			for _, child in ipairs(children) do
				local unexplored = {
					cursor = layout,
					manifest = child,
				}

				table.insert(unexplored_nodes, unexplored)
			end
		end

		if type == "leaf" then
			local leaf = Leaf:new(node.manifest.windowUuid, nil)
			node.cursor:addChild(leaf)
		end
	    ::continue::
	end

	return windowLayout
end

return M
