-- Integration test for GitHub issue #274 (slice 3): proves the "hydrating
-- the universe" flow works end-to-end -- a fresh vim session state being
-- restored from a real persisted Universe JSON file via the real
-- hydration_manager.hydrate() entry point (buffer_manager.hydrateBuffersForUniverse
-- et al.), rather than calling any of those internal functions directly on
-- hand-rolled data.
--
-- To produce genuine fixture data without hand-rolling JSON, this reuses the
-- real save pipeline proven by save_on_exit.headless.lua (slice 2): a real
-- universe is created via addNewUniverseUsecase.run(), a real buffer is
-- opened, and a real QuitPre autocmd is fired so multiverse_manager.save()
-- dehydrates and persists real buffer state to universe-<uuid>.json. Only
-- then is the live vim state reset to simulate a fresh session, and the real
-- hydration_manager.hydrate() entry point is called to restore it -- the
-- actual regression assertion is that the tracked buffer comes back and the
-- working directory is restored.
--
-- Headless script, not a busted spec -- see support.lua's header for why.
--
-- Run from the repository root with:
--   nvim --headless -u NONE -l lua/test/integration/hydrate_universe.headless.lua
--
-- The script prints "PASS" and exits 0 on success, or raises a Lua error
-- (via `assert`) and exits non-zero on failure.

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

-- Require everything up front, before any `cd` happens (addNewUniverseUsecase
-- transitively reaches multiverse_manager.load_universe() ->
-- hydration_manager.hydrate(), which `cd`s into the universe's working
-- directory -- multiverse_manager.save() itself never changes cwd, it only
-- reads it) -- package.path's relative entries resolve against the process
-- cwd at require-time, so requiring after a `cd` would break.
local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local hydration_manager = require("multiverse.managers.hydration_manager")
local support = require("test.integration.support")

local ctx = support.setup()

local universe_name = "hydrate-universe-universe"

-- Wrapped in pcall so ctx.restore() (below) always runs, even if an
-- assertion fails partway through -- otherwise a failure here would leak
-- both temp directories and leave persistance.getDir/the Neotree hooks
-- monkeypatched for the rest of this (about-to-exit) process.
local ok, err = pcall(function()
	-- Create + register a real universe, opening a real buffer and firing the
	-- real QuitPre -> multiverse_manager.save() autocmd, producing genuine
	-- fixture data on disk for the hydration assertion below (see
	-- save_on_exit.headless.lua for this pipeline's own dedicated regression
	-- coverage).
	local tracked_file_path, universe_uuid = support.create_and_save_universe(ctx, universe_name)

	-- Simulate a fresh vim session: wipe out every buffer (leaving vim to fall
	-- back to a single blank one, as it always does when the last buffer is
	-- removed). Plain `:bdelete` only unloads a buffer and does *not* clear it
	-- from the buffer list when it's the sole/current buffer (bufexists() stays
	-- 1) -- `:bwipeout` is what actually removes it, confirmed by manual testing
	-- against a real headless instance.
	--
	-- Note: hydration_manager.hydrate() never reads state_store (only its
	-- caller, multiverse_manager.load_universe(), does), so state_store is not
	-- touched here.
	vim.cmd("silent! %bwipeout!")

	assert(vim.fn.bufexists(tracked_file_path) == 0,
		"setup sanity check failed: expected no buffer for " .. vim.inspect(tracked_file_path)
			.. " to exist after resetting session state, but one was found")

	-- Fetch the real UniverseSummary for the universe just created -- reuses
	-- the same multiverse_repository cache already populated by
	-- addNewUniverseUsecase.run()/multiverse_manager.save() above, rather than
	-- hand-rolling a UniverseSummary.
	local multiverse = multiverse_repository.getMultiverse()
	local selected_universe_summary = multiverse:getUniverseByName(universe_name)
	assert(selected_universe_summary ~= nil,
		"expected to find a UniverseSummary named " .. vim.inspect(universe_name) .. " in the multiverse")
	assert(selected_universe_summary.uuid == universe_uuid,
		"expected the fetched UniverseSummary's uuid to match the one created above")

	-- Exercise the real hydration entry point directly: hydration_manager.hydrate()
	-- is the single-purpose function that actually restores buffer/tabpage/window
	-- state from a persisted Universe (unlike multiverse_manager.load_universe,
	-- which additionally saves/dehydrates whatever was previously open first).
	hydration_manager.hydrate(selected_universe_summary)

	-- The actual regression assertion: the tracked file's buffer must have
	-- been reopened by hydration, restoring real vim.api state from the
	-- persisted universe -- not just the working directory.
	assert(vim.fn.bufexists(tracked_file_path) == 1,
		"expected hydration to reopen a buffer for " .. vim.inspect(tracked_file_path)
			.. ", but vim.fn.bufexists() reported it does not exist. Open buffers: "
			.. vim.inspect(vim.api.nvim_list_bufs()))

	local found_tracked_buffer_after_hydrate = false
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_get_name(bufnr) == tracked_file_path then
			found_tracked_buffer_after_hydrate = true
			break
		end
	end

	assert(found_tracked_buffer_after_hydrate,
		"expected vim.api.nvim_list_bufs() to contain a buffer named " .. vim.inspect(tracked_file_path)
			.. " after hydration, but it did not")

	-- hydration_manager.hydrate() wraps setCwd (and everything else) in a
	-- pcall that only notifies+logs on failure, so a real cwd regression
	-- could otherwise still print PASS -- assert the working directory was
	-- actually restored to the universe's directory.
	assert(vim.fn.getcwd() == ctx.universe_directory,
		"expected cwd to be " .. vim.inspect(ctx.universe_directory) .. " after hydration, but was "
			.. vim.inspect(vim.fn.getcwd()))
end)

ctx.restore()

if not ok then
	error(err)
end

print("PASS")
os.exit(0)
