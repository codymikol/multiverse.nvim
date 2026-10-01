local Plugin = require("multiverse.data.plugin.Plugin")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local sanitize_statusline = require("multiverse.util.sanitize_statusline")

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
		vim.o.titlestring = sanitize_statusline.sanitize(name)
	end,

})
