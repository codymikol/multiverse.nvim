
local M = {}

local workspaces_plugin = require("workspaces")
local persistance = require("multiverse.repositories.persistance")
local Universe = require("multiverse.data.Universe")
local Buffer = require("multiverse.data.Buffer")
local Tabpage = require("multiverse.data.Tabpage")
local Window = require("multiverse.data.Window")
local UniverseSummary = require("multiverse.data.UniverseSummary")
local uuid_manager = require("multiverse.managers.uuid_manager")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local universe_repository = require("multiverse.repositories.universe_repository")

-- This guy I'm making to support anyone who may be using this plugin ( mostly me ) when it was dependant on the `workspaces.nvim` plugin.
-- This will migrate all of the workspaces into the new format, persist them, and write a .migrated file to signal that the migration has completed.

local function migrate_workspace(workspace, multiverse)

  local workspace_buffer_sha_256 = vim.fn.sha256(workspace.name)

  local fully_quialified_path = persistance.getDir() .. "/" .. workspace_buffer_sha_256 .. "/buffer.txt"

  local workspace_file = io.open(fully_quialified_path, "r")
  if not workspace_file then
    vim.notify("Failed to open workspace file: " .. workspace.path, vim.log.levels.ERROR)
    return
  end

  local workspace_content = workspace_file:read("*a")

  local new_universe_uuid = uuid_manager.create()

  local new_universe = Universe:new(new_universe_uuid, workspace.name, workspace.path)

  local new_buffers = {}

  for line in workspace_content:gmatch("[^\n]+") do
    local new_buffer_uuid = uuid_manager.create()
    local buffer = Buffer:new(new_buffer_uuid, nil, line)
    new_universe:addBuffer(buffer)
    table.insert(new_buffers, buffer)
  end

  for _, buffer in ipairs(new_buffers) do
    new_universe:addBuffer(buffer)
  end

  local new_window_uuid = uuid_manager.create()

  local new_window_buffer_uuid = nil
  if #new_buffers ~= 0 then
   new_window_buffer_uuid = new_buffers[1].buffer_uuid
  end

  local new_window = Window:new(new_window_uuid, new_window_buffer_uuid, nil)

  local new_tabpage_uuid = uuid_manager.create()

  local new_tabpage = Tabpage:new(new_tabpage_uuid, nil, new_window_uuid)

  new_tabpage:addWindow(new_window)

  new_universe:addTabpage(new_tabpage)

  local seconds_since_epoch = os.time(os.date("!*t"))

  local new_universe_summary = UniverseSummary:new(workspace.path, new_universe_uuid, workspace.name, seconds_since_epoch)

  multiverse:addUniverse(new_universe_summary)
  multiverse_repository.save_multiverse(multiverse)
  universe_repository.save_universe(new_universe)

end

local function isAlreadyMigrated()
  local migrated = io.open(persistance.getDir() .. "/.migrated", "r")
  if migrated then
    migrated:close()
    return true
  end
  return false
end

local function markAsMigrated()
  local migrated_file = io.open(persistance.getDir() .. "/.migrated", "w")
  if migrated_file then
    migrated_file:write("This file indicates that the migration has been completed.\n")
    migrated_file:close()
  else
    vim.notify("Failed to create migration marker file.", vim.log.levels.ERROR)
  end
end

M.run = function()

  if isAlreadyMigrated() then
    -- Migration already done, nothing to do :V)
    return
  end

  local multiverse = multiverse_repository.getMultiverse()

  local workspaces = workspaces_plugin.get()

  for _, workspace in ipairs(workspaces) do
    migrate_workspace(workspace, multiverse)
  end

  vim.notify("Migrated workspaces to new Multiverse format, you can now remove workspaces.nvim as a repository and switch to the Multiverse keybinds.", vim.log.levels.INFO)

  markAsMigrated()

end



return M
