local M = {}

M.saveAll = function()
  local tabs = vim.api.nvim_list_tabpages()

  for _, tab in ipairs(tabs) do
  end
end

M.closeAll = function()
  -- TODO
end

M.hydrate = function()
  -- TODO
end

return M
