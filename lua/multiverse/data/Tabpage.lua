local Tabpage = {}
Tabpage.__index = Tabpage

local function isNonEmptyString(value)
  return type(value) == "string" and value ~= ""
end

--- @class Tabpage
--- @field new (table): Tabpage
--- @field setLayout (WindowLayout) -> nil
--- @field uuid string -- A unique identifier for this tabpage that is persisted and rehydrated.
--- @field tabpageId number | nil -- The neovim id for this tabpage that is NOT persisted and is to be set during hydration.
--- @field activeWindowUuid string | nil -- The immutable identifier for the active window in this tabpage.
--- @field windows Window[]
--- @field layout WindowLayout
--- @field addWindow (Window) -> nil
--- @field addAllWindows (Window[]) -> nil
--- @field getWindowByUuid (string): Window | nil

--- @param opts table
--- @param opts.uuid string
--- @param opts.tabpageId number|nil
--- @param opts.activeWindowUuid string|nil
function Tabpage:new(opts)
  opts = opts or {}
  if type(opts) ~= "table" then
    error("Tabpage:new requires a table argument", 2)
  end
  if not isNonEmptyString(opts.uuid) then
    error("Tabpage:new requires opts.uuid to be a non-empty string", 2)
  end

  local self = setmetatable({}, Tabpage)
  self.uuid = opts.uuid
  self.tabpageId = opts.tabpageId
  self.activeWindowUuid = opts.activeWindowUuid
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
