local initialize = require("multiverse.usecases.initialize")
local cli = require("multiverse.managers.cli_manager")
local on_exit = require("multiverse.autocmd.on_exit")
local on_buffer_close = require("multiverse.autocmd.on_buffer_close")
local on_vim_enter = require("multiverse.autocmd.on_vim_enter")
local multiverse_manager = require("multiverse.managers.multiverse_manager")
local sanitize_statusline = require("multiverse.util.sanitize_statusline")

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

  if opts.title ~= nil and type(opts.title) ~= "boolean" then
    vim.notify("multiverse.setup: opts.title must be a boolean, got: " .. type(opts.title), vim.log.levels.WARN)
  end
  vim.g.multiverse_title_enabled = opts.title == true

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

--- Plain, statusline-agnostic accessor for the active Universe's name.
--- @return string the active universe's name, or "" when not currently in a universe
Multiverse.status = function()
  local name = multiverse_manager.get_current_universe_name()
  if name == nil then
    return ""
  end
  return sanitize_statusline.sanitize(name)
end

return Multiverse
