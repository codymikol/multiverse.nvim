local Tabpage = require "multiverse.data.Tabpage"
local uuid_manager = require "multiverse.managers.uuid_manager"

local M = {}

M.closeAll = function()

  local tabpages = vim.api.nvim_list_tabpages()

  for _, tab in ipairs(tabpages) do
    vim.api.nvim_set_current_tabpage(tab)
    vim.cmd('tabclose')
  end

end

--- @return Tabpage[]
M.getTabpages = function()
  local tabpages = {}
  local tabpageIds = vim.api.nvim_list_tabpages()
  for _, tabpageId in ipairs(tabpageIds) do
    local tabpageUuid = uuid_manager.create()
    local newTabPage = Tabpage:new(tabpageUuid, tabpageId, "") -- todo(mikol): We need to find the active windowId for this tabpage and assign it here.
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
