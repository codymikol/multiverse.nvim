local cli = require("multiverse.managers.cli_manager")
local on_exit = require("multiverse.autocmd.on_exit")
local on_buffer_close = require("multiverse.autocmd.on_buffer_close")

local Multiverse = {}

Multiverse.setup = function()
  cli.registerCommands()
  on_exit.register()
  on_buffer_close.register()
end

return Multiverse
