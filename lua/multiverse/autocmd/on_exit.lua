
local M = {}

local multiverse_manager = require("multiverse.managers.multiverse_manager")

M.register = function()
  local augroup = vim.api.nvim_create_augroup("multiverse_on_exit", { clear = true })

  vim.api.nvim_create_autocmd("QuitPre", {
    group = augroup,
    callback = function()
      multiverse_manager.save()
    end,
  })
end

return M
