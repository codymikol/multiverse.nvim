local Plugin = require("multiverse.data.plugin.Plugin")
local current_universe_resolver = require("multiverse.repositories.current_universe_resolver")
local sanitize_statusline = require("multiverse.util.sanitize_statusline")

local function resolve_current_universe_name()
	local summary = current_universe_resolver.resolve_current_universe_summary()
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
