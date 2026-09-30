local Plugin = require("multiverse.data.plugin.Plugin")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")

local function resolve_current_universe_name()
	local multiverse = multiverse_repository.getMultiverse()
	if multiverse == nil then
		return nil
	end

	local cwd = vim.fn.getcwd()

	local summary = multiverse:getUniverseByDirectory(cwd)
	if summary == nil then
		summary = multiverse:getUniverseByDirectory(cwd .. "/")
	end

	return summary and summary.name
end

-- titlestring expands '%' items like 'statusline' (e.g. '%{expr}' evaluates
-- expr), and single-byte ASCII control characters (C0 0x00-0x1F plus DEL
-- 0x7F) reach the terminal's OSC title-set sequence unfiltered — both must
-- be stripped from a user-supplied Universe name. Bytes >= 0x80 are left
-- untouched: in this UTF-8 terminal context they only ever occur as parts
-- of multi-byte UTF-8 sequences, never as standalone control codes, and
-- stripping any subset of them corrupts otherwise-valid non-ASCII names.
local function sanitize_for_titlestring(value)
	local without_control_bytes = value:gsub("[%z\1-\31\127]", "")
	return (without_control_bytes:gsub("%%", "%%%%"))
end

return Plugin:new({

	name = "TitleSync",

	-- No beforeDehydrate handler: that hook fires on every routine checkpoint
	-- save (e.g. closing a buffer), not only on an actual universe switch, so
	-- resetting titlestring there would revert the title almost immediately.
	afterHydrate = function(_)
		if vim.g.multiverse_title_enabled ~= true then
			return
		end

		local name = resolve_current_universe_name()
		if name == nil then
			return
		end

		vim.o.title = true
		vim.o.titlestring = sanitize_for_titlestring(name)
	end,

})
