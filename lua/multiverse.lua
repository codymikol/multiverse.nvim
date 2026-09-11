local initialize = require("multiverse.usecases.initialize")
local cli = require("multiverse.managers.cli_manager")
local plugin_manager = require("multiverse.managers.plugin_manager")
local on_exit = require("multiverse.autocmd.on_exit")
local on_buffer_close = require("multiverse.autocmd.on_buffer_close")
local on_vim_enter = require("multiverse.autocmd.on_vim_enter")
local log = require("multiverse.log")

local Multiverse = {}

--- Registers every non-nil entry in a plugin list, including ones that follow a nil
--- hole (e.g. left by a `Plugin:new` call that returned nil). ipairs alone would stop
--- at the first hole and silently skip every valid entry after it.
--- @param plugins_list table
--- @return nil
local function register_plugins(plugins_list)
  local max_index = 0
  for k in pairs(plugins_list) do
    if type(k) == "number" and k > max_index then
      max_index = k
    end
  end

  for i = 1, max_index do
    local plugin = plugins_list[i]
    if plugin ~= nil then
      plugin_manager.register(plugin)
    end
  end
end

--- @param opts? { plugins?: Plugin[] }
Multiverse.setup = function(opts)
  opts = (type(opts) == "table") and opts or {}

  initialize.run()

  if opts.plugins then
    if type(opts.plugins) ~= "table" then
      log.warn(
        "opts.plugins should be a list of plugins, e.g. { plugins = { myPlugin } }, got: "
          .. type(opts.plugins)
      )
    -- A single Plugin/PluginContext-shaped table (not wrapped in a list) has plugin-shaped
    -- keys of its own but no integer keys, so register_plugins would silently register nothing.
    elseif opts.plugins.context ~= nil or opts.plugins.name ~= nil then
      log.warn(
        "opts.plugins should be a list of plugins, e.g. { plugins = { myPlugin } }, got a single plugin instead"
      )
    else
      register_plugins(opts.plugins)
    end
  end

  cli.registerCommands()
  on_exit.register()
  on_buffer_close.register()
  on_vim_enter.register()
end

return Multiverse
