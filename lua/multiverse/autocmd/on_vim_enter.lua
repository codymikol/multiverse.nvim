local M = {}

local multiverse_manager = require("multiverse.managers.multiverse_manager")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local state_store = require("multiverse.store.state_store")
local log = require("multiverse.log")

M.on_vim_enter = function()
  local success, err = pcall(function()
    if state_store.get_current_state() ~= state_store.STATES.IDLE then
      return
    end

    local buffer_name = vim.api.nvim_buf_get_name(0)

    if buffer_name == "" or vim.fn.isdirectory(buffer_name) == 0 then
      return
    end

    local directory = vim.fn.fnamemodify(buffer_name, ":p"):gsub("/$", "")

    local multiverse = multiverse_repository.getMultiverse()

    local universe_summary = multiverse:getUniverseByDirectory(directory)
    if universe_summary == nil then
      universe_summary = multiverse:getUniverseByDirectory(directory .. "/")
    end

    if universe_summary == nil then
      return
    end

    -- skip_save = true: at VimEnter there is no meaningful prior session in
    -- the current (empty/netrw) buffer to save, and saving here would
    -- clobber the target universe's already-persisted session (GH #104).
    multiverse_manager.load_universe(multiverse, universe_summary, true)
  end)

  if not success then
    log.error("Error loading universe on startup: " .. vim.inspect(err))
  end
end

M.register = function()
  vim.api.nvim_create_autocmd("VimEnter", {
    callback = M.on_vim_enter,
  })
end

return M
