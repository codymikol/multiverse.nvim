local stub = require("luassert.stub")
local match = require("luassert.match")

describe("plugin_manager", function()
	local plugin_manager
	local log
	local log_error_stub
	local log_debug_stub

	before_each(function()
		package.loaded["multiverse.managers.plugin_manager"] = nil
		log = require("multiverse.log")
		log_error_stub = stub(log, "error")
		log_debug_stub = stub(log, "debug")
		plugin_manager = require("multiverse.managers.plugin_manager")
	end)

	after_each(function()
		log_error_stub:revert()
		log_debug_stub:revert()
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

	describe("register", function()
		it("should append plugins with distinct names so both of their hooks fire", function()
			local plugin_one_called = false
			local plugin_two_called = false

			plugin_manager.register({
				name = "plugin_one",
				context = {
					afterHydrate = function()
						plugin_one_called = true
					end,
				},
			})

			plugin_manager.register({
				name = "plugin_two",
				context = {
					afterHydrate = function()
						plugin_two_called = true
					end,
				},
			})

			plugin_manager.afterHydrate({})

			assert.is_true(plugin_one_called)
			assert.is_true(plugin_two_called)
		end)

		it("should be a no-op when given a nil plugin", function()
			local call_count = 0

			plugin_manager.register({
				name = "plugin_one",
				context = {
					afterHydrate = function()
						call_count = call_count + 1
					end,
				},
			})

			assert.has_no.errors(function()
				plugin_manager.register(nil)
			end)

			plugin_manager.afterHydrate({})

			assert.equal(1, call_count)
		end)

		it("should not duplicate a plugin registered again with the same name", function()
			local call_count = 0

			local plugin = {
				name = "duplicate_plugin",
				context = {
					afterHydrate = function()
						call_count = call_count + 1
					end,
				},
			}

			plugin_manager.register(plugin)
			plugin_manager.register(plugin)

			plugin_manager.afterHydrate({})

			assert.equal(1, call_count)
		end)

		it("should append rather than collapse two plugins that both lack a name", function()
			local plugin_one_called = false
			local plugin_two_called = false

			plugin_manager.register({
				context = {
					afterHydrate = function()
						plugin_one_called = true
					end,
				},
			})

			plugin_manager.register({
				context = {
					afterHydrate = function()
						plugin_two_called = true
					end,
				},
			})

			plugin_manager.afterHydrate({})

			assert.is_true(plugin_one_called)
			assert.is_true(plugin_two_called)
		end)

		it("should use the newest hook implementation when re-registering a plugin with the same name", function()
			local original_called = false
			local updated_called = false

			local original_plugin = {
				name = "duplicate_plugin",
				context = {
					afterHydrate = function()
						original_called = true
					end,
				},
			}

			local updated_plugin = {
				name = "duplicate_plugin",
				context = {
					afterHydrate = function()
						updated_called = true
					end,
				},
			}

			plugin_manager.register(original_plugin)
			plugin_manager.register(updated_plugin)

			plugin_manager.afterHydrate({})

			assert.is_false(original_called)
			assert.is_true(updated_called)
		end)
	end)
end)
