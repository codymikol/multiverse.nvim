local buffer_manager = require("multiverse.managers.buffer_manager")
local window_manager = require("multiverse.managers.window_manager")
local tabpage_manager= require("multiverse.managers.tabpage_manager")

local M = {}

M.cleanup = function()
  buffer_manager.closeAll()
  window_manager.closeAll()
  tabpage_manager.closeAll()
end

return M
