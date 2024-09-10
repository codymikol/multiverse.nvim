local dlog = require("integrations.dlog")
local log = dlog.logger("windows")
local Window = require("multiverse.data.Window")

local M = {}

-- This will find all open windows and persist their positioning
-- and buffer contents into a file which will be used for rehydration.
M.closeAll = function()
  local windows = vim.api.nvim_list_wins()

  for _, window in ipairs(windows) do

    local buf = vim.api.nvim_win_get_buf(window)
    local window_is_empty = not vim.api.nvim_buf_is_valid(buf)

    if window_is_empty then

      local status, err = pcall(vim.api.nvim_win_close, window, true)

      if status then
        log("successfully closed window " .. window)
      else
        log("error closing window " .. window .. ", error: " .. err)
      end

    end
  end
end

-- This will close all open windows.
M.saveAll = function()
  -- TODO: save current open windows
end

M.hydrate = function()
  -- TODO: load saved windows
end

--- @param tabpageId number
M.getAllVisibleWindowsForTabpage = function(tabpageId)
  local editableWindows = {}

  local windows = vim.api.nvim_tabpage_list_wins(tabpageId)

  for _, window in ipairs(windows) do
    local buf = vim.api.nvim_win_get_buf(window)
    local bufType = vim.api.nvim_get_option_value("buftype", { buf = buf })
    local isEditable = bufType == ""
    if isEditable then
      local newWindow = Window:new(window)
      table.insert(editableWindows, newWindow)
    end
  end

  return editableWindows
end


return M
