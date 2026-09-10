local universe_repository = require("multiverse.repositories.universe_repository")
local buffer_manager = require("multiverse.managers.buffer_manager")
local neotree_integration = require("integrations.neotree")
local tabpage_manager = require("multiverse.managers.tabpage_manager")
local window_layout_manager = require("multiverse.managers.window_layout_manager")
local log = require("multiverse.log")
local M = {}

---@param universe Universe
local function setCwd(universe)
	vim.api.nvim_command("cd " .. vim.fn.fnameescape(universe.workingDirectory))
end

--- Hydrates the current neovim environment with the contents of a given universe.
---@param selected_universe UniverseSummary
M.hydrate = function(selected_universe)
	local universe, err = universe_repository.get_universe_by_uuid(selected_universe.uuid)

	if universe == nil then
		vim.notify("Universe not found: " .. tostring(err or "unknown error"))
		return
	end

	local success, hydrate_err = pcall(function()
		setCwd(universe)

		buffer_manager.hydrateBuffersForUniverse(universe)

		tabpage_manager.hydrate(universe)

		window_layout_manager.hydrate(universe)

		neotree_integration.hydrate()
	end)

	if not success then
		local message = "Error hydrating universe: " .. vim.inspect(hydrate_err)
		log.error("%s", message)
		vim.notify(message, vim.log.levels.ERROR)
	end

	buffer_manager.close_generated_nofile_scratch_buffers()
end

return M

-- todo(mikol): Add an adapter layer that allows developers who wish to add support for external plugins to create adapters and have a configuration that allows you to enable/disable them.
-- todo(mikol): before v1.0.0, we should check to see if these plugins have been loaded before trying to hydrate them. :D realted ^^ (done for neotree, other integrations still unguarded)
