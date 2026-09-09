local Plugin = require("multiverse.data.plugin.Plugin")

local DEFAULT_NEOTREE_WIDTH = 36

-- Rejects anything nvim_win_set_width would reject (non-numbers, floats,
-- zero, negatives) up front; the call site also wraps the API call in
-- pcall as a second line of defense for values this check can't catch
-- (e.g. math.huge).
local function resolve_neotree_width()
  local width = vim.g.multiverse_neotree_width

  if type(width) == "number" and width == math.floor(width) and width > 0 then
    return width
  end

  return DEFAULT_NEOTREE_WIDTH
end

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

    local width_applied_ok = pcall(vim.api.nvim_win_set_width, win_id, resolve_neotree_width())

    if not width_applied_ok then
      vim.api.nvim_win_set_width(win_id, DEFAULT_NEOTREE_WIDTH)
    end

		vim.cmd("Neotree reveal current " .. cwd)

    vim.cmd("Neotree close")

    vim.cmd("Neotree show")

	end,

})
