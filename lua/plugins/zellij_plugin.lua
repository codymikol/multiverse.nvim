local Plugin = require("multiverse.data.plugin.Plugin")
local zellij_manager = require("multiverse.managers.zellij_manager")

return Plugin:new({

	name = "Zellij",

	beforeDehydrate = function(_)
		if zellij_manager.is_available() and zellij_manager.is_floating_terminal_open() then
			zellij_manager.close_floating_terminal()
		end
	end,

	afterHydrate = function(_)
		if zellij_manager.is_available() then
			zellij_manager.reattach_if_running(zellij_manager.session_name_for(vim.fn.getcwd()))
		end
	end,

})
