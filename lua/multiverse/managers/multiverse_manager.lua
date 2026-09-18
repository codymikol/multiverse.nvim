local M = {}

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

    local current_multiverse_summary = multiverse:getUniverseByDirectory(current_directory)
    if current_multiverse_summary == nil then
      current_multiverse_summary = multiverse:getUniverseByDirectory(current_directory .. "/")
    end

    if current_multiverse_summary == nil then
      vim.notify("No universe found for current directory: " .. current_directory)
      state_store.set_current_state(state_store.STATES.IDLE)
      return
    end

    local current_universe_summary = multiverse:getUniverseByDirectory(current_directory)

    if current_universe_summary ~= nil then

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
    end
  end)

  if not success then
    log.error("Error saving universe: %s", err)
    vim.notify("Error saving universe, check MultiverseLog for more information", vim.log.levels.ERROR)
  end


  state_store.set_current_state(state_store.STATES.IDLE)

end

--- @param multiverse Multiverse
--- @param selected_universe_summary UniverseSummary
--- @param skip_save boolean | nil  when true, unconditionally skips saving/dehydrating whatever is currently
--- open before hydrating the selected universe. When the current directory's registered universe is the same
--- universe being loaded, load_universe already skips the save automatically (to avoid clobbering its
--- just-persisted session), so skip_save is only needed for callers with nothing meaningful to save at all
--- (e.g. on VimEnter, where the current buffer is just the empty/startup state, not a prior session).
M.load_universe = function(multiverse, selected_universe_summary, skip_save)

  log.debug("Loading universe: " .. selected_universe_summary.name)

  local success, err = pcall(function()

    selected_universe_summary:setLastExploredToNow()
    multiverse_repository.save_multiverse(multiverse)

    local current_universe = nil

    if not skip_save then

      local current_directory = vim.fn.getcwd()

      local current_universe_summary = multiverse:getUniverseByDirectory(current_directory)
      if current_universe_summary == nil then
        current_universe_summary = multiverse:getUniverseByDirectory(current_directory .. "/")
      end

      if current_universe_summary ~= nil then

        -- deliberately shadowed: keeps beforeHydrate/afterHydrate's
        -- `current_universe` argument at its pre-existing value (nil) here,
        -- matching MultiverseOpen's behavior prior to this file's skip_save
        -- change instead of silently altering it.
        local current_universe, err = universe_repository.get_universe_by_uuid(current_universe_summary.uuid)

        -- This abort guard must run whether or not the current directory's
        -- universe is the one being loaded: bailing out here (before
        -- cleanup_manager.cleanup() runs below) is what keeps a missing/
        -- corrupt universe file from wiping the user's open buffers.
        if current_universe == nil then
          log.error("Error dehydrating universe: " .. current_universe_summary.uuid .. ", error details: " .. vim.inspect(err))
          return
        end

        if current_universe_summary.uuid ~= selected_universe_summary.uuid then

          log.debug("load universe searching multiverse for matching directory and found: %s", current_universe_summary)

          M.save()

        else

          log.debug(
            "Current directory's universe is the same universe being loaded (%s), skipping dehydration "
              .. "to avoid clobbering its just-persisted session.",
            selected_universe_summary.uuid
          )

        end

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
