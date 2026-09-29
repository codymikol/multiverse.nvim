local initialize = require("multiverse.usecases.initialize")
local cli = require("multiverse.managers.cli_manager")
local on_exit = require("multiverse.autocmd.on_exit")
local on_buffer_close = require("multiverse.autocmd.on_buffer_close")
local on_vim_enter = require("multiverse.autocmd.on_vim_enter")

local Multiverse = {}

-- needs_input commands take a required/meaningful argument (universe name,
-- directory) that a keymap can't supply, so their mapping drops the user
-- into cmdline mode (with completion) instead of executing immediately.
local KEYMAP_COMMANDS = {
  list = { command = "MultiverseList", needs_input = false },
  add = { command = "MultiverseAdd", needs_input = true },
  open = { command = "MultiverseOpen", needs_input = true },
  remove = { command = "MultiverseRemove", needs_input = true },
  log = { command = "MultiverseLog", needs_input = false },
  terminal = { command = "MultiverseTerminal", needs_input = false },
}

Multiverse.setup = function(opts)
  opts = opts or {}

  initialize.run()
  cli.registerCommands()
  on_exit.register()
  on_buffer_close.register()
  on_vim_enter.register()

  for key, mapping in pairs(type(opts.keymaps) == "table" and opts.keymaps or {}) do
    local entry = KEYMAP_COMMANDS[key]
    if entry and type(mapping) == "string" then
      local rhs = entry.needs_input and (":" .. entry.command .. " ") or ("<cmd>" .. entry.command .. "<cr>")
      local desc = entry.needs_input and (entry.command .. " (prompt)") or entry.command
      vim.keymap.set("n", mapping, rhs, { desc = desc })
    elseif entry == nil then
      vim.notify("multiverse.setup: unknown keymaps key '" .. key .. "'", vim.log.levels.WARN)
    end
  end
end

return Multiverse
