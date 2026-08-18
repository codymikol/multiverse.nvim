
local M = {}

local multiverse_manager = require("multiverse.managers.multiverse_manager")
local state_store = require("multiverse.store.state_store")

M.register = function()
  vim.api.nvim_create_autocmd("BufDelete", {
    callback = function()
      -- We don't want to save dfuring the cleanup / transitioning phase as it will save after every deleted buffer during cleanup.
      if state_store.get_current_state() == state_store.STATES.IDLE then
        vim.notify("saving...")
        multiverse_manager.save()
      end
    end,
  })
end

return M
