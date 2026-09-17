
local M = {}

local multiverse_manager = require("multiverse.managers.multiverse_manager")

M.register = function()
  local augroup = vim.api.nvim_create_augroup("multiverse_on_exit", { clear = true })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = augroup,
    callback = function()
      -- Not debounced (unlike on_buffer_close.lua's BufDelete): on VimLeavePre a
      -- deferred timer would fire after Neovim has already torn down, so the save
      -- must happen synchronously here.
      multiverse_manager.save()
    end,
  })
end

return M
