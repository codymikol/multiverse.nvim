local workspace = require("multiverse.managers.workspace_manager")
local multiverse_manager = require("multiverse.managers.multiverse_manager")
local log                = require("multiverse.log")

local M = {}

M.onFileOpened = function()
  log.debug("on file open handler called")
  multiverse_manager.save()
end

M.onFileClosed = function()
  log.debug("on file close handler called")
  -- todo(mikol): is there a better way to wait for the buffer marked for deletion to actually be deleted?
  vim.defer_fn(multiverse_manager.save, 10)
end

M.register = function()
  vim.api.nvim_exec2(
    [[
augroup multiverse
autocmd!
autocmd BufRead * lua require("multiverse.listeners").onFileOpened()
autocmd BufDelete * lua require("multiverse.listeners").onFileClosed()
augroup END
]],
  { output = false }
  )
end

return M
