local cli = require("multiverse.managers.cli_manager")
local on_exit = require("multiverse.autocmd.on_exit")

local Multiverse = {}

Multiverse.setup = function()
  cli.registerCommands()
  on_exit.register()
end

return Multiverse
