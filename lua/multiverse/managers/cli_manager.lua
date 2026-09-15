local M = {}

local addNewUniverseUsecase = require("multiverse.usecases.addNewUniverseUsecase")
local promptSelectUniverseUsecase = require("multiverse.usecases.promptSelectUniverseUsecase")
local removeUniverseUsecase = require("multiverse.usecases.removeUniverseUsecase")
local openUniverseUsecase = require("multiverse.usecases.openUniverseUsecase")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local zellij_manager = require("multiverse.managers.zellij_manager")
local log = require("multiverse.log")

local function complete_universe(arglead, cmdline, cursorpos)

  local multiverse = multiverse_repository.getMultiverse()

	local universes = multiverse.universes

	local completions = {}
	for _, universe in ipairs(universes) do
		if universe.name:find(arglead, 1, true) then
			table.insert(completions, universe.name)
		end
	end

	return completions
end

M.registerCommands = function()
	vim.api.nvim_create_user_command("MultiverseAdd", function(opts)
		addNewUniverseUsecase.run(opts.fargs[1], opts.fargs[2])
	end, {
		nargs = '*',
		complete = "file",
	})

	vim.api.nvim_create_user_command("MultiverseOpen", function(opts)
		openUniverseUsecase.run(opts.fargs[1])
	end, {
		nargs = 1,
		complete = complete_universe,
	})

	vim.api.nvim_create_user_command("MultiverseRemove", function(opts)
		removeUniverseUsecase.run(opts.fargs[1])
	end, {
		nargs = 1,
		complete = complete_universe,
	})

	vim.api.nvim_create_user_command("MultiverseList", function()
		promptSelectUniverseUsecase.run()
	end, { nargs = 0 })

	vim.api.nvim_create_user_command("MultiverseLog", function()
		vim.cmd.split(vim.fn.fnameescape(log.get_log_file()))
		vim.bo.modifiable = false
	end, { nargs = 0 })

	vim.api.nvim_create_user_command("MultiverseTerminal", function()
		if not zellij_manager.is_available() then
			vim.notify("zellij is not installed", vim.log.levels.WARN)
			return
		end

		local session_name = zellij_manager.session_name_for(vim.fn.getcwd())
		zellij_manager.open_floating_terminal(session_name)
	end, { nargs = 0 })
end

return M
