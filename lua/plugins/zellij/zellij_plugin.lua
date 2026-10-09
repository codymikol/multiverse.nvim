local Plugin = require("multiverse.data.plugin.Plugin")
local zellij_manager = require("plugins.zellij.zellij_manager")

return Plugin:new({

	name = "Zellij",

	beforeDehydrate = function(ctx)
		if zellij_manager.is_available() then
			local was_open = zellij_manager.is_floating_terminal_open()

			if was_open then
				zellij_manager.close_floating_terminal()
			end

			local session_name = zellij_manager.session_name_for(ctx.universe.workingDirectory)
			if was_open then
				zellij_manager.mark_open(session_name)
			else
				zellij_manager.mark_closed(session_name)
			end
		end
	end,

	afterHydrate = function(_)
		if zellij_manager.is_available() then
			local session_name = zellij_manager.session_name_for(vim.fn.getcwd())
			if zellij_manager.was_open(session_name) then
				zellij_manager.reattach_if_running(session_name)
			end
		end
	end,

	setupCommands = function()
		vim.api.nvim_create_user_command("MultiverseTerminal", function()
			if not zellij_manager.is_available() then
				vim.notify("zellij is not installed", vim.log.levels.WARN)
				return
			end

			if zellij_manager.is_floating_terminal_open() then
				zellij_manager.close_floating_terminal()
				return
			end

			local session_name = zellij_manager.session_name_for(vim.fn.getcwd())
			zellij_manager.open_floating_terminal(session_name)
		end, { nargs = 0 })
	end,

})
