
local M = {}

local multiverse_manager = require("multiverse.managers.multiverse_manager")
local current_universe_store = require("multiverse.store.state_store")
local log = require("multiverse.log")

local DEBOUNCE_MS = 10

M.register = function()
  local augroup = vim.api.nvim_create_augroup("multiverse_on_buffer_close", { clear = true })
  local save_timer

  vim.api.nvim_create_autocmd("BufDelete", {
    group = augroup,
    callback = function()
      -- We don't want to save during the cleanup / transitioning phase as it will save after every deleted buffer during cleanup.
      if current_universe_store.get_current_state() == current_universe_store.STATES.IDLE then
        -- Cancel any pending timer so a burst of BufDelete events collapses into one save.
        if save_timer and not save_timer:is_closing() then
          save_timer:stop()
          save_timer:close()
        end
        save_timer = vim.defer_fn(function()
          -- Re-check IDLE: state may have changed since this timer was armed.
          if current_universe_store.get_current_state() == current_universe_store.STATES.IDLE then
            log.debug("on_buffer_close: saving")
            multiverse_manager.save()
          end
        end, DEBOUNCE_MS)
      end
    end,
  })
end

return M
