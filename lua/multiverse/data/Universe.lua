local json = require("multiverse.repositories.json")
local Universe = {}
Universe.__index = Universe

--- @class Universe
--- @field uuid string
--- @field name string
--- @field tabpages Tabpage[]
--- @field currentTabpage Tabpage
--- @field addTabpage (Tabpage) -> nil
--- @field addAllTabpages (Tabpage[]) -> nil

--- @param uuid string
--- @param name string
--- @param workingDirectory string
--- @return Universe
function Universe:new(uuid, name, workingDirectory)
  local self = setmetatable({}, Universe)
  self.uuid = uuid
  self.name = name
  self.workingDirectory = workingDirectory
  self.currentTabpage = nil
  self.tabpages = {}
  return self
end

--- @param tabpage Tabpage
--- @return nil
function Universe:addTabpage(tabpage)
  table.insert(self.tabpages, tabpage)
end

--- @param tabpages Tabpage[]
--- @return nil
function Universe:addAllTabpages(tabpages)
  for _, tabpage in pairs(tabpages) do
    self:addTabpage(tabpage)
  end
end

function Universe:toJsonString()
  return json.encode(self)
end

return Universe
