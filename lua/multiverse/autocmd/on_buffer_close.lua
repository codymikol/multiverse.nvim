
local M = {}

local multiverse_manager = require("multiverse.managers.multiverse_manager")
local current_universe_store = require("multiverse.store.state_store")

M.register = function()
  vim.api.nvim_create_autocmd("BufDelete", {
    callback = function()
      vim.notify("saving...")
      -- We don't want to save dfuring the cleanup / transitioning phase as it will save after every deleted buffer during cleanup.
      if current_universe_store.get_current_state() == current_universe_store.STATES.IDLE then
        multiverse_manager.save()
      end
    end,
  })
end

return M
