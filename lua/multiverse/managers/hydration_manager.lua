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

	local hydrated_buffer_ids = nil

	local success, hydrate_err = pcall(function()
		setCwd(universe)

		buffer_manager.hydrateBuffersForUniverse(universe)

		tabpage_manager.hydrate(universe)

		hydrated_buffer_ids = window_layout_manager.hydrate(universe)

		neotree_integration.hydrate()
	end)

	if not success then
		vim.notify("Error hydrating universe, check MultiverseLog for more information", vim.log.levels.ERROR)
		log.error("Error hydrating universe: %s", hydrate_err)
	end

	buffer_manager.close_generated_nofile_scratch_buffers()

	-- Hydration sets these buffers current (and fires FileType) synchronously,
	-- before plugins that register their own FileType autocmds later in the
	-- same VimEnter dispatch (e.g. lazily-configured highlighters) get a
	-- chance to register. Re-firing FileType one tick later via vim.schedule
	-- lets those late listeners attach without deferring hydration itself.
	if hydrated_buffer_ids ~= nil and #hydrated_buffer_ids > 0 then
		vim.schedule(function()
			local seen_buffer_ids = {}
			for _, bufferId in ipairs(hydrated_buffer_ids) do
				if not seen_buffer_ids[bufferId] and vim.api.nvim_buf_is_valid(bufferId) then
					seen_buffer_ids[bufferId] = true
					local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufferId })
					if filetype ~= "" then
						-- Re-emission runs per-buffer inside its own pcall so a third-party
						-- FileType handler throwing for one buffer (e.g. a highlighter) can't
						-- abort the whole loop and silently skip re-emission for every later
						-- buffer too.
						local reemit_ok, reemit_err = pcall(function()
							-- `buffer` only matches buffer-local (`<buffer=N>`) autocmds and is
							-- mutually exclusive with `pattern`, so it can't re-fire listeners
							-- registered with a string pattern like "lua"; nvim_buf_call makes
							-- this buffer current for the duration of the real, pattern-matched
							-- FileType dispatch, matching how :doautocmd FileType <ft> behaves.
							vim.api.nvim_buf_call(bufferId, function()
								vim.api.nvim_exec_autocmds("FileType", { pattern = filetype, modeline = false })
							end)
						end)

						if not reemit_ok then
							log.error("Error re-emitting FileType for buffer %s: %s", bufferId, reemit_err)
						end
					end
				end
			end
		end)
	end
end

return M

-- todo(mikol): Add an adapter layer that allows developers who wish to add support for external plugins to create adapters and have a configuration that allows you to enable/disable them.
-- todo(mikol): before v1.0.0, we should check to see if these plugins have been loaded before trying to hydrate them. :D realted ^^ (done for neotree, other integrations still unguarded)
