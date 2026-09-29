local stub = require("luassert.stub")
local match = require("luassert.match")

describe("plugin_manager", function()
	local plugin_manager
	local log
	local log_error_stub

	before_each(function()
		package.loaded["multiverse.managers.plugin_manager"] = nil
		log = require("multiverse.log")
		log_error_stub = stub(log, "error")
		plugin_manager = require("multiverse.managers.plugin_manager")
	end)

	after_each(function()
		log_error_stub:revert()
		package.loaded["multiverse.managers.plugin_manager"] = nil
	end)

	local hook_names = { "beforeDehydrate", "afterDehydrate", "beforeHydrate", "afterHydrate" }

	for _, hookName in ipairs(hook_names) do
		describe(hookName, function()
			it("should continue calling later plugins' hooks when an earlier plugin's hook throws", function()
				local plugin_two_called_with

				local plugin_one = {
					name = "plugin_one",
					context = {
						[hookName] = function()
							error("boom")
						end,
					},
				}

				local plugin_two = {
					name = "plugin_two",
					context = {
						[hookName] = function(ctx)
							plugin_two_called_with = ctx
						end,
					},
				}

				plugin_manager.register(plugin_one)
				plugin_manager.register(plugin_two)

				local ctx = { some = "context" }

				assert.has_no.errors(function()
					plugin_manager[hookName](ctx)
				end)

				assert.equal(ctx, plugin_two_called_with)
				-- log_error_stub may also fire for the real built-in plugins' hooks,
				-- which throw for some lifecycle events in this headless test env, so
				-- the call count is not asserted here.
				assert.stub(log_error_stub).was.called_with(
					"Error running %s hook for plugin %s: %s",
					hookName,
					"plugin_one",
					match._
				)
			end)

			it("should not log an error when the plugin's hook does not throw", function()
				local plugin_called_with

				local plugin = {
					name = "plugin_one",
					context = {
						[hookName] = function(ctx)
							plugin_called_with = ctx
						end,
					},
				}

				plugin_manager.register(plugin)

				local ctx = { some = "context" }

				plugin_manager[hookName](ctx)

				assert.equal(ctx, plugin_called_with)
				assert.stub(log_error_stub).was.not_called_with(match._, hookName, "plugin_one", match._)
			end)
		end)
	end
end)
