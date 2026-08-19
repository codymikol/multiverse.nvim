-- Regression test for GitHub issue #140 (dead `M.register` export on
-- plugin_manager), plus dispatch coverage for the four lifecycle hooks:
-- each is called with the given context exactly once, and skipped without
-- error when a plugin's hook is nil. Does NOT cover fan-out across
-- multiple registered plugins (NeoTreePlugin is the list's only entry
-- today) -- a plugin silently missing from the list (see #237) is not
-- caught here.
--
-- `require("plugins.neotree_plugin")` returns the SAME cached module
-- table `plugin_manager.lua` holds internally (Lua caches modules by
-- require path), so overwriting fields on `NeoTreePlugin.context` in
-- `before_each` intercepts what `plugin_manager` actually dispatches to.
-- `afterDehydrate`/`beforeHydrate` aren't defined by NeoTreePlugin out of
-- the box, so plain tracking functions are assigned directly rather than
-- via `luassert.stub` (which requires an existing function to wrap).

local plugin_manager = require("multiverse.managers.plugin_manager")
local NeoTreePlugin = require("plugins.neotree_plugin")

describe("plugin_manager", function()
	it("should no longer expose register (dead code with zero callers repo-wide)", function()
		-- Update or delete this assertion when #238 reintroduces a wired-up
		-- `register`/setup-time registration entry point.
		assert.is_nil(plugin_manager.register)
	end)

	describe("lifecycle dispatch", function()
		local original_beforeDehydrate
		local original_afterDehydrate
		local original_beforeHydrate
		local original_afterHydrate

		before_each(function()
			original_beforeDehydrate = NeoTreePlugin.context.beforeDehydrate
			original_afterDehydrate = NeoTreePlugin.context.afterDehydrate
			original_beforeHydrate = NeoTreePlugin.context.beforeHydrate
			original_afterHydrate = NeoTreePlugin.context.afterHydrate
		end)

		after_each(function()
			NeoTreePlugin.context.beforeDehydrate = original_beforeDehydrate
			NeoTreePlugin.context.afterDehydrate = original_afterDehydrate
			NeoTreePlugin.context.beforeHydrate = original_beforeHydrate
			NeoTreePlugin.context.afterHydrate = original_afterHydrate
		end)

		it("beforeDehydrate calls context.beforeDehydrate with the context, once", function()
			local calls = {}
			NeoTreePlugin.context.beforeDehydrate = function(ctx)
				table.insert(calls, ctx)
			end

			local context = { some = "beforeDehydrateContext" }
			plugin_manager.beforeDehydrate(context)

			assert.are.equal(1, #calls)
			assert.are.equal(context, calls[1])
		end)

		it("afterDehydrate calls context.afterDehydrate with the context when defined", function()
			local calls = {}
			NeoTreePlugin.context.afterDehydrate = function(ctx)
				table.insert(calls, ctx)
			end

			local context = { some = "afterDehydrateContext" }
			plugin_manager.afterDehydrate(context)

			assert.are.equal(1, #calls)
			assert.are.equal(context, calls[1])
		end)

		it("beforeHydrate calls context.beforeHydrate with the context when defined", function()
			local calls = {}
			NeoTreePlugin.context.beforeHydrate = function(ctx)
				table.insert(calls, ctx)
			end

			local context = { some = "beforeHydrateContext" }
			plugin_manager.beforeHydrate(context)

			assert.are.equal(1, #calls)
			assert.are.equal(context, calls[1])
		end)

		it("afterHydrate calls context.afterHydrate with the context, once", function()
			local calls = {}
			NeoTreePlugin.context.afterHydrate = function(ctx)
				table.insert(calls, ctx)
			end

			local context = { some = "afterHydrateContext" }
			plugin_manager.afterHydrate(context)

			assert.are.equal(1, #calls)
			assert.are.equal(context, calls[1])
		end)

		it("does not error and skips the hook when a plugin's context hook is nil for a dispatched lifecycle event", function()
			-- beforeDehydrate/afterHydrate are the two hooks NeoTreePlugin defines
			-- by default; nil-ing them out here (rather than the already-nil
			-- afterDehydrate/beforeHydrate) actually exercises the
			-- `if plugin.context.X then` guard branch instead of passing vacuously.
			NeoTreePlugin.context.beforeDehydrate = nil
			NeoTreePlugin.context.afterHydrate = nil

			assert.has_no.errors(function()
				plugin_manager.beforeDehydrate({})
				plugin_manager.afterHydrate({})
			end)
		end)
	end)
end)
