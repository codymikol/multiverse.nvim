local Universe = require("multiverse.data.Universe")
local Tabpage = require("multiverse.data.Tabpage")
local Window = require("multiverse.data.Window")
local Buffer = require("multiverse.data.Buffer")
local json = require("multiverse.repositories.json")
local window_layout_factory = require("multiverse.factory.window_layout_factory")
local log = require("multiverse.log")

local M = {}

local function defaultLayout()
	return { children = {} }
end

local function isNonEmptyString(value)
	return type(value) == "string" and value ~= ""
end

---@param jsonString string | nil
---@return Universe | nil
function M.make(jsonString)
	local ok, universe_json_or_err = pcall(json.decode, jsonString)

	if not ok then
		log.error("Error decoding universe json, error details: %s", universe_json_or_err)
		return nil
	end

	if type(universe_json_or_err) ~= "table" then
		log.warn("Decoded universe json was not a table, got: %s", type(universe_json_or_err))
		return nil
	end

	local uuid = universe_json_or_err.uuid
	local name = universe_json_or_err.name
	local workingDirectory = universe_json_or_err.workingDirectory

	if not isNonEmptyString(uuid) then
		log.warn("Universe json was missing a valid uuid, got: %s", uuid)
		return nil
	end

	if not isNonEmptyString(name) then
		log.warn("Universe json was missing a valid name, got: %s", name)
		return nil
	end

	if not isNonEmptyString(workingDirectory) then
		log.warn("Universe json was missing a valid workingDirectory, got: %s", workingDirectory)
		return nil
	end

	local universe = Universe:new(uuid, name, workingDirectory)

	if type(universe_json_or_err.buffers) == "table" then
		for _, buffer_json in pairs(universe_json_or_err.buffers) do
			if type(buffer_json) == "table" then
				local buffer_uuid = buffer_json.uuid
				local buffer = Buffer:new(buffer_uuid, nil, buffer_json.bufferName)
				universe:addBuffer(buffer)
			end
		end
	end

	if type(universe_json_or_err.tabpages) == "table" then
		for _, tabpage_json in pairs(universe_json_or_err.tabpages) do
			if type(tabpage_json) == "table" then
				local tabpage = Tabpage:new(tabpage_json.uuid, nil, 0) -- todo(mikol): we need to hydrate the active window uuid here.

				local layout = tabpage_json.layout

				if type(layout) ~= "table" then
					-- Tabpage layout is missing or not a table; fall back to an empty layout.
					layout = defaultLayout()
				end

				local layout_ok, made_layout = pcall(window_layout_factory.makeFromJson, layout)

				if not layout_ok then
					-- Tabpage layout was a table but not shaped like a valid layout manifest, falling back to the default empty layout.
					made_layout = window_layout_factory.makeFromJson(defaultLayout())
				end

				tabpage.layout = made_layout

				universe:addTabpage(tabpage)

				if type(tabpage_json.windows) == "table" then
					for _, window_json in pairs(tabpage_json.windows) do
						if type(window_json) == "table" then
							local window = Window:new(window_json.uuid, window_json.bufferUuid, nil)
							tabpage:addWindow(window)
						end
					end
				end
			end
		end
	end

	return universe
end

return M
