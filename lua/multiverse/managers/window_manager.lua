local Window = require("multiverse.data.Window")
local uuid_manager = require("multiverse.managers.uuid_manager")
local buffer_manager = require("multiverse.managers.buffer_manager")

local M = {}

--- @param tabpageId number
M.getAllVisibleWindowsForTabpage = function(tabpageId)
  local editableWindows = {}

  local windows = vim.api.nvim_tabpage_list_wins(tabpageId)

  for _, windowId in ipairs(windows) do
    local buf = vim.api.nvim_win_get_buf(windowId)
    local isEditable = buffer_manager.isUniverseBuffer(buf)
    if isEditable then
      local windowUuid = uuid_manager.create()
      -- todo(mikol): I think we can just do this here, not in the external loop, come back to this...
      local newWindow = Window:new(windowUuid, nil, windowId)
      table.insert(editableWindows, newWindow)
    end
  end

  return editableWindows
end

return M
