local workspace = require("multiverse.workspace")

local M = {}

M.onFileOpened = function()
	workspace.save()
end

M.onFileClosed = function()
	-- todo(mikol): is there a better way to wait for the buffer marked for deletion to actually be deleted?
	vim.defer_fn(workspace.save, 10)
end

M.register = function()
	vim.api.nvim_exec(
		[[
augroup multiverse
autocmd!
autocmd BufRead * lua require("multiverse.listeners").onFileOpened()
autocmd BufDelete * lua require("multiverse.listeners").onFileClosed()
augroup END
]],
		false
	)
end

return M
