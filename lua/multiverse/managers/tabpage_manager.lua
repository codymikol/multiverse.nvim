local Tabpage = require "multiverse.data.Tabpage"

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
    -- todo(mikol): We need to find the active windowId for this tabpage and assign it here.
    local newTabPage = Tabpage:new(tabpageId, 0)
    table.insert(tabpages, newTabPage)
  end
  return tabpages
end

return M
