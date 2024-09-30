local Plugin = require("multiverse.data.plugin.Plugin")

return Plugin:new({

	beforeDehydrate = function()
		vim.cmd("Neotree close")
	end,

	afterHydrate = function()
		local cwd = vim.fn.getcwd()
		vim.cmd("Neotree " .. cwd)
	end,
})
