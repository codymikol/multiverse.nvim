local M = {}

local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local universe_repository = require("multiverse.repositories.universe_repository")
local hydration_manager = require("multiverse.managers.hydration_manager")
local dehydration_manager = require("multiverse.managers.dehydration_manager")
local cleanup_manager = require("multiverse.managers.cleanup_manager")
local plugin_manager = require("multiverse.managers.plugin_manager")
local log            = require("multiverse.log")
local state_store    = require("multiverse.store.state_store")
local profiler       = require("multiverse.profiler")

--- Defense in depth on top of profiler.flush()'s own internal pcall: even if
--- profiling misbehaves in some unforeseen way, it must never prevent the
--- caller's state-machine reset to IDLE that follows this call.
local function flush_profiler_trace(span, label)
  local ok, err = pcall(function()
    profiler.end_span(span)
    profiler.flush()
  end)
  if not ok then
    log.error("Profiler error during %s: %s", label, err)
  end
end

M.save = function()

  local save_span = profiler.start_span("save")

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

      local before_dehydrate_span = profiler.start_span("beforeDehydrate")
      plugin_manager.beforeDehydrate({
        universe = current_universe
      })
      profiler.end_span(before_dehydrate_span)

      local dehydrate_span = profiler.start_span("dehydrate")
      local dehydrated_universe = dehydration_manager.dehydrate(current_universe_summary)
      profiler.end_span(dehydrate_span)

      local after_dehydrate_span = profiler.start_span("afterDehydrate")
      plugin_manager.afterDehydrate({
        universe = current_universe
      })
      profiler.end_span(after_dehydrate_span)

      universe_repository.save_universe(dehydrated_universe)
    end
  end)

  if not success then
    log.error("Error saving universe: %s", err)
    vim.notify("Error saving universe, check MultiverseLog for more information", vim.log.levels.ERROR)
  end

  flush_profiler_trace(save_span, "save")

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

  local load_span = profiler.start_span("load_universe")

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

    local cleanup_span = profiler.start_span("cleanup")
    cleanup_manager.cleanup()
    profiler.end_span(cleanup_span)

    state_store.set_current_state(state_store.STATES.HYDRATION)

    local before_hydrate_span = profiler.start_span("beforeHydrate")
    plugin_manager.beforeHydrate({ universe = current_universe })
    profiler.end_span(before_hydrate_span)

    local hydrate_span = profiler.start_span("hydrate")
    hydration_manager.hydrate(selected_universe_summary)
    profiler.end_span(hydrate_span)

    local after_hydrate_span = profiler.start_span("afterHydrate")
    plugin_manager.afterHydrate({ universe = current_universe })
    profiler.end_span(after_hydrate_span)

  end)

  if not success then
    log.error("Error loading universe: " .. selected_universe_summary.name .. ", error details: " .. vim.json.encode(err))
    vim.notify("Error loading universe: " .. selected_universe_summary.name, vim.log.levels.ERROR)
  end

  flush_profiler_trace(load_span, "load")

  state_store.set_current_state(state_store.STATES.IDLE)

end

return M
