local cwd = vim.fn.getcwd()
vim.o.runtimepath = cwd .. ',' .. vim.o.runtimepath

vim.o.swapfile = false
vim.o.backup = false
vim.o.writebackup = false

pcall(vim.cmd, 'packadd plenary.nvim')
pcall(vim.cmd, 'packadd multiverse.nvim')
pcall(vim.cmd, 'packadd multiverse')
