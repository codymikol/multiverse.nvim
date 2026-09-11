local WindowLayout = require("multiverse.data.layout.WindowLayout")
local Column = require("multiverse.data.layout.Column")
local Row = require("multiverse.data.layout.Row")
local Leaf = require("multiverse.data.layout.Leaf")

local M = {}

-- Single source of truth for container type strings: adding a type here also makes
-- isContainerNode recognize it, so the two can't drift out of sync.
local containerConstructors = {
	row = function()
		return Row:new()
	end,
	column = function()
		return Column:new()
	end,
}

--- @param nodeType string
local function isContainerNode(nodeType)
	return containerConstructors[nodeType] ~= nil
end

--- @param nodeType string
local function isLeafNode(nodeType)
	return nodeType == "leaf"
end

-- Shared BFS-over-worklist traversal for both the neovim winlayout() shape and the
-- persisted JSON manifest shape, with the shape differences pushed into a per-shape
-- adapter. isContainerNode/isLeafNode are shape-independent (getNodeType already
-- normalizes "col"->"column"), so they live here rather than per adapter.
--- @param rootNode table the raw root node of the tree to traverse (e.g. neovimWindowLayout or manifestFirstRow)
--- @param adapter table getNodeType, getNodeChildren, addLeaf
--- @param context any optional context passed through to adapter.addLeaf (e.g. the universe)
--- @return WindowLayout
local function buildWindowLayout(rootNode, adapter, context)
	local windowLayout = WindowLayout:new()

	local unexplored_nodes = {
		{
			cursor = windowLayout,
			node = rootNode,
		},
	}

	while #unexplored_nodes > 0 do
		local worklistNode = table.remove(unexplored_nodes, 1) -- BFS: pop the front

		local node = worklistNode.node

		if node == nil then
			goto continue
		end

		local type = adapter.getNodeType(node)

		if isContainerNode(type) then
			local children = adapter.getNodeChildren(node)

			local layout = containerConstructors[type]()

			worklistNode.cursor:addChild(layout)

			for _, child in ipairs(children) do
				local unexplored = {
					cursor = layout,
					node = child,
				}

				table.insert(unexplored_nodes, unexplored)
			end
		end

		if isLeafNode(type) then
			adapter.addLeaf(worklistNode.cursor, node, context)
		end

		::continue::
	end

	return windowLayout
end

-- Adapter for the neovim winlayout() shape: { type, ... } tuples
local neovimLayoutAdapter = {
	-- Normalizes neovim's "col" to the plugin's "column" here at the input boundary,
	-- so nothing downstream needs to know winlayout() and the JSON manifest disagree.
	getNodeType = function(node)
		local nodeType = node[1]
		if nodeType == "col" then
			return "column"
		end
		return nodeType
	end,
	getNodeChildren = function(node)
		return node[2]
	end,
	-- Leaf-drop asymmetry (must preserve, see issue #130): a leaf whose windowId has
	-- no corresponding universe window is silently dropped rather than added.
	addLeaf = function(cursor, node, universe)
		local windowId = node[2]
		local window = universe:getWindowById(windowId)

		if window ~= nil then
			local leaf = Leaf:new(window.uuid, windowId)
			cursor:addChild(leaf)
		end
	end,
}

-- Adapter for the persisted JSON manifest shape: { type = ..., ... } tables
local jsonManifestAdapter = {
	getNodeType = function(node)
		return node.type
	end,
	getNodeChildren = function(node)
		return node.children
	end,
	-- Always adds the leaf, even when windowUuid is nil (unlike the neovim adapter,
	-- which drops the leaf when the universe window lookup itself fails).
	addLeaf = function(cursor, node, _context)
		local leaf = Leaf:new(node.windowUuid, nil)
		cursor:addChild(leaf)
	end,
}

--- @param neovimWindowLayout table
--- @param universe Universe
--- @return WindowLayout
M.make = function(neovimWindowLayout, universe)
	return buildWindowLayout(neovimWindowLayout, neovimLayoutAdapter, universe)
end

--- @param jsonManifest table
--- @return WindowLayout
M.makeFromJson = function(jsonManifest)
	local manifestFirstRow = jsonManifest.children[1] -- The root node of the manifest

	return buildWindowLayout(manifestFirstRow, jsonManifestAdapter)
end

return M
