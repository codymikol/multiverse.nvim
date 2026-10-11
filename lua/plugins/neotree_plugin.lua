local Plugin = require("multiverse.data.plugin.Plugin")
local persistance = require("multiverse.repositories.persistance")
local json = require("multiverse.repositories.json")
local log = require("multiverse.log")

--- A pure hash of the given cwd string (mirrors
--- `zellij_manager.session_name_for`), so the same directory always maps to
--- the same on-disk state file across the dehydrate/hydrate boundary.
--- @param cwd string
--- @return string
local function hash_cwd(cwd)
	return "neotree-" .. vim.fn.sha256(cwd):sub(1, 16)
end

--- @param cwd string
--- @return string path to the on-disk JSON file persisting this cwd's neotree state
local function state_path(cwd)
	return persistance.getDir() .. "/neotree-state-" .. hash_cwd(cwd) .. ".json"
end

--- Persists `state` (e.g. `{ expanded_dirs = {...}, highlighted_path = "..." }`)
--- for `cwd` to disk, so a later `read_state` call -- even from a fresh nvim
--- process -- can restore it. Never throws: a failure to create the
--- persistance dir or open the file is logged and swallowed, since losing
--- this state should never break hydration.
--- @param cwd string
--- @param state table
local function write_state(cwd, state)
	vim.fn.mkdir(persistance.getDir(), "p")

	local path = state_path(cwd)
	local file, err = io.open(path, "w")
	if not file then
		log.error("error opening neotree state file " .. vim.inspect(path) .. " for writing, error: " .. vim.inspect(err))
		return
	end

	file:write(json.encode(state))
	file:close()
end

--- @param cwd string
--- @return table|nil the state previously persisted by `write_state` for this
--- cwd, or nil when no file exists yet or its contents aren't valid JSON
local function read_state(cwd)
	local path = state_path(cwd)
	if vim.fn.filereadable(path) ~= 1 then
		return nil
	end

	local file, err = io.open(path, "r")
	if not file then
		log.error("error opening neotree state file " .. vim.inspect(path) .. " for reading, error: " .. vim.inspect(err))
		return nil
	end

	local contents = file:read("*a")
	file:close()

	local ok, decoded = pcall(json.decode, contents)
	if not ok then
		return nil
	end

	return decoded
end

--- Reads neo-tree's own Lua API to build `{ expanded_dirs, highlighted_path }`
--- for the currently open filesystem tree. Neo-tree isn't vendored in this
--- repo (plenary-only in CI), so its API shape here is unverified -- every
--- call into it is pcall-wrapped and any failure degrades to `nil` rather
--- than propagating and breaking dehydration.
--- @return table|nil
local function capture_neotree_state()
	local ok, manager = pcall(require, "neo-tree.sources.manager")
	if not ok or not manager or not manager.get_state then
		return nil
	end

	local ok2, state = pcall(manager.get_state, "filesystem")
	if not ok2 or not state or not state.tree then
		return nil
	end

	local expanded_dirs = {}
	local function walk(node)
		if node.is_expanded and node:is_expanded() then
			table.insert(expanded_dirs, node:get_id())
		end
		if node.get_child_ids then
			for _, child_id in ipairs(node:get_child_ids()) do
				local child = state.tree:get_node(child_id)
				if child then
					walk(child)
				end
			end
		end
	end

	local ok3 = pcall(function()
		for _, node in ipairs(state.tree:get_nodes()) do
			walk(node)
		end
	end)
	if not ok3 then
		return nil
	end

	local highlighted_path = nil
	pcall(function()
		local cursor_node = state.tree:get_node()
		if cursor_node and cursor_node.get_id then
			highlighted_path = cursor_node:get_id()
		end
	end)

	return { expanded_dirs = expanded_dirs, highlighted_path = highlighted_path }
end

local function restore_neotree_state(captured)
	if not captured then
		return
	end

	local expanded_dirs = captured.expanded_dirs
	local highlighted_path = captured.highlighted_path

	if (not expanded_dirs or #expanded_dirs == 0) and not highlighted_path then
		return
	end

	if expanded_dirs and #expanded_dirs > 0 then
		local ok, manager = pcall(require, "neo-tree.sources.manager")
		if ok and manager and manager.get_state then
			local ok2, state = pcall(manager.get_state, "filesystem")
			if ok2 and state and state.tree then
				for _, id in ipairs(expanded_dirs) do
					pcall(function()
						local node = state.tree:get_node(id)
						if node and node.expand and not (node.is_expanded and node:is_expanded()) then
							node:expand()
						end
					end)
				end
			end
		end
	end

	if highlighted_path then
		pcall(function()
			vim.cmd("Neotree reveal_file=" .. vim.fn.fnameescape(highlighted_path))
		end)
	end
end

local plugin = Plugin:new({

  name = "Neotree",

	beforeDehydrate = function(ctx)
		local cwd = ctx and ctx.universe and ctx.universe.workingDirectory
		if cwd then
			local captured = capture_neotree_state()
			if captured then
				write_state(cwd, captured)
			end
		end

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

    -- Set the window width
    vim.api.nvim_win_set_width(win_id, 36)

    -- This reveal/close/show sequence looks redundant (`reveal` already
    -- opens Neotree), but simplifying it needs headless/manual verification
    -- that window focus and width still behave correctly -- left as-is
    -- until that's confirmed.
		vim.cmd("Neotree reveal current " .. cwd)

    vim.cmd("Neotree close")

    vim.cmd("Neotree show")

		local captured = read_state(cwd)
		if captured then
			restore_neotree_state(captured)
		end

	end,

})

return plugin
