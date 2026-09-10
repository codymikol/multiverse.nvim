
local M = {}

local multiverse_manager = require("multiverse.managers.multiverse_manager")

M.register = function()
  local augroup = vim.api.nvim_create_augroup("multiverse_on_exit", { clear = true })

  vim.api.nvim_create_autocmd("QuitPre", {
    group = augroup,
    callback = function()
      -- Not debounced (unlike on_buffer_close.lua's BufDelete): a deferred save here
      -- risks Neovim exiting before the timer fires, silently dropping the save.
      multiverse_manager.save()
    end,
  })
end

return M
