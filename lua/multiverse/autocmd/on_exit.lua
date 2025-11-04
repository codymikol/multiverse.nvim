
local M = {}

local multiverse_manager = require("multiverse.managers.multiverse_manager")

M.register = function()
  vim.api.nvim_create_autocmd("QuitPre", {
    callback = function()
      multiverse_manager.save()
    end,
  })
end

return M
