local Tabpage = require "multiverse.data.Tabpage"
local uuid_manager = require "multiverse.managers.uuid_manager"

local M = {}

--- @return Tabpage[]
M.getTabpages = function()
  local tabpages = {}
  local tabpageIds = vim.api.nvim_list_tabpages()
  for _, tabpageId in ipairs(tabpageIds) do
    local tabpageUuid = uuid_manager.create()
    -- activeWindowUuid can't be resolved here: window uuids don't exist yet, they're
    -- minted later in dehydration_manager.dehydrate. Capture the raw window id now so
    -- dehydration can correlate it to a uuid once windows are built.
    local newTabPage = Tabpage:new(tabpageUuid, tabpageId, "")
    newTabPage.activeWindowId = vim.api.nvim_tabpage_get_win(tabpageId)
    table.insert(tabpages, newTabPage)
  end
  return tabpages
end

---@param universe Universe
M.hydrate = function(universe)
  for idx, tabpage in ipairs(universe.tabpages) do
    if idx ~= 1 then
      vim.cmd("tabnew")
    end
    tabpage.tabpageId = vim.api.nvim_get_current_tabpage()
  end
end

return M
