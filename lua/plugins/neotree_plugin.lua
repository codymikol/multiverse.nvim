local Plugin = require("multiverse.data.plugin.Plugin")

return Plugin:new({

  name = "Neotree",

	beforeDehydrate = function(_)
		vim.cmd("Neotree close")
	end,

	afterHydrate = function(_)

    -- This is a hack to work around Neotree using the multiverse window for itself

		local cwd = vim.fn.getcwd()
    vim.cmd('wincmd H')

    -- Open a vertical split (now at the far left)
    vim.cmd('vsplit')

    -- Focus the new leftmost window
    vim.cmd('wincmd h')

    -- Get the current window ID
    local win_id = vim.api.nvim_get_current_win()

    -- Calculate 30% of the total columns

    -- Set the window width
    vim.api.nvim_win_set_width(win_id, 36)

		vim.cmd("Neotree reveal current " .. cwd)

    vim.cmd("Neotree close")

    vim.cmd("Neotree show")

	end,

})
