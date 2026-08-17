
local M = {}

local multiverse_manager = require("multiverse.managers.multiverse_manager")

M.register = function()
  -- clear = true wipes any autocmd already attached to this named group
  -- (including ones a user may have added directly), not just the ones this
  -- module created. That's intentional here since it's what prevents this
  -- function from registering duplicate QuitPre autocmds when called more
  -- than once, but worth flagging since "multiverse_on_exit" is a shared,
  -- named group and therefore effectively public/internal surface.
  local augroup = vim.api.nvim_create_augroup("multiverse_on_exit", { clear = true })

  vim.api.nvim_create_autocmd("QuitPre", {
    group = augroup,
    callback = function()
      multiverse_manager.save()
    end,
  })
end

return M
