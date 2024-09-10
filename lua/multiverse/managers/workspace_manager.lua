local M = {}

-- When activating a workspace, all buffers and windows that
-- were previously active should re-hydrate.
--
-- Plugin Integations
-- Neotree
--
-- Telescope

-- Our persistance structure will look something like this.
-- /worksapces
--   /hydration
--     /workspace-a
--       buffers.txt
--       windows.txt
--
--  buffers.txt will be a line indexed list of buffers that
--  should be loaded into memory upon hydration.
--
--  windows.txt will be a line indexed list of active windows
--  and their positioning metatdata (todo) that should be opened
--  and populated with their corresponding buffer pointers upon
--  hydration.
--

local data = {
  tabs = {
    {
      tab_id = 3223,
      windows = {
        {
          win_id = 1298,
          buffers = {
            {
              buf_id = 123
            }
          }
        }
      }
    }
  }
}

local Buffers = require("multiverse.managers.buffer_manager")
local Windows = require("multiverse.managers.window_manager")
local Neotree = require("integrations.neotree")

local function isInWorkspace()
  return nil ~= require("workspaces").name()
end

M.clear = function()
  Windows.closeAll()
  Buffers.closeAll()
end

M.save = function()
  if isInWorkspace() then
    Buffers.saveAll()
    Windows.saveAll()
  end
end

M.hydrate = function()
  Neotree.hydrate()
  Buffers.hydrate()
  Windows.hydrate()
end

return M
