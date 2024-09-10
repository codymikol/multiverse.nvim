local Tabpage = {}
Tabpage.__index = Tabpage

--- @class Tabpage
--- @field id number
--- @field activeWindowId number
--- @field windows Window[]
--- @field addWindow (Window) -> nil
--- @field addAllWindows (Window[]) -> nil

--- @param id number
--- @param activeWindowId number
function Tabpage:new(id, activeWindowId)
  local self = setmetatable({}, Tabpage)
  self.id = id
  self.activeWindowId = activeWindowId
  self.windows = {}
  return self
end

--- @param window Window
--- @return nil
function Tabpage:addWindow(window)
  table.insert(self.windows, window)
end

--- @param windows Window[]
--- @return nil
function Tabpage:addAllWindows(windows)
  for _, window in pairs(windows) do
    self:addWindow(window)
  end
end

return Tabpage
