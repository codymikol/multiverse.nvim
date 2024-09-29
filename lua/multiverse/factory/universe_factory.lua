local Universe = require("multiverse.data.Universe")
local Tabpage = require("multiverse.data.Tabpage")
local Window = require("multiverse.data.Window")
local Buffer = require("multiverse.data.Buffer")
local json = require("multiverse.repositories.json")
local uuid_manager = require("multiverse.managers.uuid_manager")
local window_layout_factory = require("multiverse.factory.window_layout_factory")

local M = {}

function M.make(jsonString)
	local universe_json = json.decode(jsonString)

	local universe = Universe:new(universe_json.uuid, universe_json.name, universe_json.workingDirectory)

	if universe_json.buffers ~= nil then
		for _, buffer_json in pairs(universe_json.buffers) do
			local uuid = uuid_manager.create()
			local buffer = Buffer:new(uuid, nil, buffer_json.bufferName)
			universe:addBuffer(buffer)
		end
	end

	for _, tabpage_json in pairs(universe_json.tabpages) do
		local tabpage = Tabpage:new(tabpage_json.uuid, nil, 0) -- todo(mikol): we need to hydrate the active window uuid here.

		tabpage.layout = window_layout_factory.makeFromJson(tabpage_json.layout)

		universe:addTabpage(tabpage)

		for _, window_json in pairs(tabpage_json.windows) do
			local window = Window:new(window_json.uuid, nil)
			tabpage:addWindow(window)
		end
	end

	return universe
end

return M
