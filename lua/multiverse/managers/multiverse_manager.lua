local M = {}

local timestamp_manager = require("multiverse.managers.timestamp_manager")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local universe_repository = require("multiverse.repositories.universe_repository")
local hydration_manager = require("multiverse.managers.hydration_manager")
local dehydration_manager = require("multiverse.managers.dehydration_manager")
local cleanup_manager = require("multiverse.managers.cleanup_manager")
local plugin_manager = require("multiverse.managers.plugin_manager")
local log            = require("multiverse.log")
local state_store    = require("multiverse.store.state_store")

M.save = function()

  local success, err = pcall(function()

    if state_store.get_current_state() ~= state_store.STATES.IDLE then
      vim.notify("Cannot save universe while in state: " .. state_store.get_current_state())
      return
    end

    state_store.set_current_state(state_store.STATES.DEHYDRATION)

    local multiverse = multiverse_repository.getMultiverse()

    local current_directory = vim.fn.getcwd()

    local current_universe_summary = multiverse:getUniverseByDirectory(current_directory)
    if current_universe_summary == nil then
      current_universe_summary = multiverse:getUniverseByDirectory(current_directory .. "/")
    end

    if current_universe_summary == nil then
      vim.notify("No universe found for current directory: " .. current_directory)
      state_store.set_current_state(state_store.STATES.IDLE)
      return
    end

    local current_universe, err = universe_repository.get_universe_by_uuid(current_universe_summary.uuid)

    if current_universe == nil then
      log.error("Error dehydrating universe: " .. current_universe_summary.uuid .. ", error details: " .. vim.inspect(err))
      state_store.set_current_state(state_store.STATES.IDLE)
      return
    end

    plugin_manager.beforeDehydrate({
      universe = current_universe
    })

    local dehydrated_universe = dehydration_manager.dehydrate(current_universe_summary)

    plugin_manager.afterDehydrate({
      universe = current_universe
    })

    universe_repository.save_universe(dehydrated_universe)
  end)

  if not success then
    log.error("Error saving universe: " .. vim.inspect(err))
    vim.notify("Error saving universe: " .. vim.inspect(err), vim.log.levels.ERROR)
  end


  state_store.set_current_state(state_store.STATES.IDLE)

end

--- @param multiverse Multiverse
--- @param selected_universe_summary UniverseSummary
--- @param skip_save boolean | nil  when true, skips saving/dehydrating whatever is currently open before
--- hydrating the selected universe. Callers should pass true when there is nothing meaningful to save (e.g.
--- on VimEnter, where the current buffer is just the empty/startup state, not a prior session), since saving
--- in that case would clobber the target universe's already-persisted session.
M.load_universe = function(multiverse, selected_universe_summary, skip_save)

  log.debug("Loading universe: " .. selected_universe_summary.name)

  local success, err = pcall(function()

    selected_universe_summary.lastExplored = timestamp_manager.now()
    multiverse_repository.save_multiverse(multiverse)

    local current_universe = nil

    if not skip_save then

      local current_directory = vim.fn.getcwd()

      local current_universe_summary = multiverse:getUniverseByDirectory(current_directory)
      if current_universe_summary == nil then
        current_universe_summary = multiverse:getUniverseByDirectory(current_directory .. "/")
      end

      if current_universe_summary ~= nil then

        -- must assign the outer `current_universe`/`err` here, not `local`
        -- redeclare them, so beforeHydrate/afterHydrate below receive the
        -- resolved universe instead of always seeing nil.
        local err
        current_universe, err = universe_repository.get_universe_by_uuid(current_universe_summary.uuid)

        if current_universe == nil then
          log.error("Error dehydrating universe: " .. current_universe_summary.uuid .. ", error details: " .. vim.inspect(err))
          return
        end

        log.debug("load universe searching multiverse for matching directory and found: " .. vim.inspect(current_universe_summary))

        M.save()

      else
        log.debug("Working directory is not part of a universe, proceeding with loading the selected universe and skipping dehydration.")
      end

    else
      log.debug("skip_save is true, proceeding with loading the selected universe and skipping dehydration.")
    end

    state_store.set_current_state(state_store.STATES.CLEANUP)

    cleanup_manager.cleanup()

    state_store.set_current_state(state_store.STATES.HYDRATION)

    plugin_manager.beforeHydrate({ universe = current_universe })

    hydration_manager.hydrate(selected_universe_summary)

    plugin_manager.afterHydrate({ universe = current_universe })

  end)

  if not success then
    log.error("Error loading universe: " .. selected_universe_summary.name .. ", error details: " .. vim.json.encode(err))
    vim.notify("Error loading universe: " .. selected_universe_summary.name, vim.log.levels.ERROR)
  end

  state_store.set_current_state(state_store.STATES.IDLE)

end

return M
