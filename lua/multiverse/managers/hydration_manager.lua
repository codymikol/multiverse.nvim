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

	local hydrated_windows = nil

	local success, hydrate_err = pcall(function()
		setCwd(universe)

		buffer_manager.hydrateBuffersForUniverse(universe)

		tabpage_manager.hydrate(universe)

		hydrated_windows = window_layout_manager.hydrate(universe)

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
	if hydrated_windows ~= nil and #hydrated_windows > 0 then
		vim.schedule(function()
			-- Dedupe by windowId, not bufferId: nvim_buf_call(bufferId, fn) only
			-- reuses a buffer's REAL window if that window belongs to the CURRENT
			-- tabpage, falling back to a temporary/hidden autocmd window for any
			-- other tabpage's window -- so a late listener setting window-scoped
			-- options (conceallevel, foldmethod, ...) would silently write them to
			-- a throwaway window instead of the one the user sees. A single buffer
			-- could also in principle be shown in more than one window, and each
			-- real window needs its own re-emission regardless.
			local seen_window_ids = {}
			for _, hydrated_window in ipairs(hydrated_windows) do
				local bufferId = hydrated_window.bufferId
				local windowId = hydrated_window.windowId
				if
					not seen_window_ids[windowId]
					and vim.api.nvim_win_is_valid(windowId)
					and vim.api.nvim_win_get_buf(windowId) == bufferId
					and vim.api.nvim_buf_is_valid(bufferId)
				then
					seen_window_ids[windowId] = true
					local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufferId })
					if filetype ~= "" then
						-- nvim_exec_autocmds already isolates a throwing FileType callback
						-- (reported to :messages, not propagated here), so this pcall only
						-- guards nvim_win_call/nvim_exec_autocmds itself failing structurally
						-- (e.g. the window closing between the validity check above and this
						-- call) -- it stops that from aborting the loop for every later window.
						local reemit_ok, reemit_err = pcall(function()
							-- nvim_win_call makes the REAL window (and thus its buffer)
							-- current for the duration of the real, pattern-matched FileType
							-- dispatch, so both window-scoped and buffer-scoped/pattern
							-- listeners land on the window the user actually sees, matching
							-- how :doautocmd FileType <ft> behaves for a visible window.
							vim.api.nvim_win_call(windowId, function()
								vim.api.nvim_exec_autocmds("FileType", { pattern = filetype, modeline = false })
							end)
						end)

						if not reemit_ok then
							log.error("Error re-emitting FileType for window %s (buffer %s): %s", windowId, bufferId, reemit_err)
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
