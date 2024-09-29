local Workspace       = require "multiverse.data.Universe"
local window_manager  = require "multiverse.managers.window_manager"
local buffer_manager  = require "multiverse.managers.buffer_manager"
local tabpage_manager = require "multiverse.managers.tabpage_manager"
local json            = require "multiverse.repositories.json"

local M = {}

--- Dehydrates all open tabpages, windows, and buffers into a Workspace object.

--- @return Workspace
M.dehydrate = function(workspaceName, workingDirectory)
  local workspace = Workspace:new(workspaceName, workingDirectory)

  local tabpages = tabpage_manager.getTabpages()

  workspace:addAllTabpages(tabpages)

  for _, tabpage in pairs(tabpages) do
    local windows = window_manager.getAllVisibleWindowsForTabpage(tabpage.id)

    tabpage:addAllWindows(windows)

    for _, window in pairs(windows) do
      local buffer = buffer_manager.getBufferForWindow(window.id)
      window:setBuffer(buffer)
    end
  end

  return workspace
end

return M

-- todo(mikol): program a new hydration method that can take a workspace and load everything into view.
