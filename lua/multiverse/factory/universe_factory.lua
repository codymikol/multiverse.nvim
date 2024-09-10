local Universe = require "multiverse.data.Universe"
local Tabpage = require "multiverse.data.Tabpage"
local Window = require "multiverse.data.Window"
local Buffer = require "multiverse.data.Buffer"
local json = require "multiverse.repositories.json"

local M = {}

function M.make(jsonString)

  local universe_json = json.decode(jsonString)

  local universe = Universe:new(
    universe_json.uuid,
    universe_json.name,
    universe_json.directory
  )

  vim.notify(vim.inspect(universe_json.uuid))

  for _, tabpage_json in pairs(universe_json.tabpages) do
    local tabpage = Tabpage:new(tabpage_json.id)
    universe:addTabpage(tabpage)
    for _, window_json in pairs(tabpage_json.windows) do
      local window = Window:new(window_json.id)
      tabpage:addWindow(window)
      local buffer = Buffer:new(window_json.buffer.id)
      window:setBuffer(buffer)
    end
  end

  return universe

end

return M
