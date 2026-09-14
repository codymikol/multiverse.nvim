-- Integration test for GitHub issue #274 (slice 2): proves the "saving the
-- universe by exiting" flow works end-to-end -- the real QuitPre autocmd
-- firing multiverse_manager.save() -> dehydration_manager.dehydrate() ->
-- universe_repository.save_universe(), writing real JSON to a real
-- filesystem, rather than calling any of those internal functions directly.
--
-- Headless script, not a busted spec -- see support.lua's header for why.
--
-- Run from the repository root with:
--   nvim --headless -u NONE -l lua/test/integration/save_on_exit.headless.lua
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
local json = require("multiverse.repositories.json")
local support = require("test.integration.support")

local ctx = support.setup()

-- Wrapped in pcall so ctx.restore() (below) always runs, even if an
-- assertion fails partway through -- otherwise a failure here would leak
-- both temp directories and leave persistance.getDir/the Neotree hooks
-- monkeypatched for the rest of this (about-to-exit) process.
local ok, err = pcall(function()
	-- Create + register + hydrate a real universe via the same usecase
	-- exercised by create_universe_spec.lua, opening a real buffer and firing
	-- the real QuitPre -> multiverse_manager.save() autocmd.
	local tracked_file_path, universe_uuid = support.create_and_save_universe(ctx, "save-on-exit-universe")

	local universe_file_path = ctx.persistance_dir .. "/universe-" .. universe_uuid .. ".json"
	local universe_json_after = json.decode(support.read_file(universe_file_path))

	local found_tracked_buffer = false
	for _, buffer in ipairs(universe_json_after.buffers) do
		if buffer.bufferName == tracked_file_path then
			found_tracked_buffer = true
			break
		end
	end

	assert(found_tracked_buffer,
		"expected the persisted universe file to contain a buffer with bufferName == " .. vim.inspect(tracked_file_path)
			.. ", but got buffers: " .. vim.inspect(universe_json_after.buffers))
end)

ctx.restore()

if not ok then
	error(err)
end

print("PASS")
os.exit(0)
