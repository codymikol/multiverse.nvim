local Tabpage = {}
Tabpage.__index = Tabpage

--- @class Tabpage
--- @field new (string, number, number): Tabpage
--- @field setLayout (WindowLayout) -> nil
--- @field uuid string -- A unique identifier for this tabpage that is persisted and rehydrated.
--- @field tabpageId number | nil -- The neovim id for this tabpage that is NOT persisted and is to be set during hydration.
--- @field activeWindowUuid string -- The immutable identifier for the active window in this tabpage.
--- @field windows Window[]
--- @field layout WindowLayout
--- @field addWindow (Window) -> nil
--- @field addAllWindows (Window[]) -> nil
--- @field getWindowByUuid (string): Window | nil

--- @param uuid string
--- @param tabpageId number | nil
--- @param activeWindowUuid string
function Tabpage:new(uuid, tabpageId, activeWindowUuid)
  local self = setmetatable({}, Tabpage)
  self.uuid = uuid
  self.tabpageId = tabpageId
  self.activeWindowUuid = activeWindowUuid
  self.windows = {}
  self.layout = nil
  return self
end

--- @param layout WindowLayout
--- @return nil
function Tabpage:setLayout(layout)
  self.layout = layout
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

--- @param uuid string
--- @return Window | nil
function Tabpage:getWindowByUuid(uuid)
  for _, window in pairs(self.windows) do
    if window.uuid == uuid then
      return window
    end
  end
end

return Tabpage
