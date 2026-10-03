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

		it("should run a lower-priority plugin's hook before a default-priority plugin's hook", function()
			local call_order = {}

			plugin_manager.register({
				name = "plugin_a",
				context = {
					afterHydrate = function()
						table.insert(call_order, "plugin_a")
					end,
				},
			})

			plugin_manager.register({
				name = "plugin_b",
				priority = 1,
				context = {
					afterHydrate = function()
						table.insert(call_order, "plugin_b")
					end,
				},
			})

			plugin_manager.afterHydrate({})

			assert.same({ "plugin_b", "plugin_a" }, call_order)
		end)

		it("should run a lower-priority plugin's hook before a default-priority plugin's hook, for every lifecycle hook", function()
			for _, hookName in ipairs(hook_names) do
				package.loaded["multiverse.managers.plugin_manager"] = nil
				plugin_manager = require("multiverse.managers.plugin_manager")

				local call_order = {}

				plugin_manager.register({
					name = "plugin_a",
					context = {
						[hookName] = function()
							table.insert(call_order, "plugin_a")
						end,
					},
				})

				plugin_manager.register({
					name = "plugin_b",
					priority = 1,
					context = {
						[hookName] = function()
							table.insert(call_order, "plugin_b")
						end,
					},
				})

				plugin_manager[hookName]({})

				assert.same({ "plugin_b", "plugin_a" }, call_order)
			end
		end)

		it("should run a lower-priority plugin's hook before a default-priority plugin's hook regardless of registration order", function()
			local call_order = {}

			plugin_manager.register({
				name = "plugin_a",
				priority = 1,
				context = {
					afterHydrate = function()
						table.insert(call_order, "plugin_a")
					end,
				},
			})

			plugin_manager.register({
				name = "plugin_b",
				context = {
					afterHydrate = function()
						table.insert(call_order, "plugin_b")
					end,
				},
			})

			plugin_manager.afterHydrate({})

			assert.same({ "plugin_a", "plugin_b" }, call_order)
		end)

		it("should preserve registration order for two plugins that both use the default priority", function()
			local call_order = {}

			plugin_manager.register({
				name = "plugin_a",
				context = {
					afterHydrate = function()
						table.insert(call_order, "plugin_a")
					end,
				},
			})

			plugin_manager.register({
				name = "plugin_b",
				context = {
					afterHydrate = function()
						table.insert(call_order, "plugin_b")
					end,
				},
			})

			plugin_manager.afterHydrate({})

			assert.same({ "plugin_a", "plugin_b" }, call_order)
		end)

		it("should re-sort by the new priority when re-registering a plugin with a changed priority", function()
			local call_order = {}

			plugin_manager.register({
				name = "plugin_a",
				priority = 1,
				context = {
					afterHydrate = function()
						table.insert(call_order, "plugin_a")
					end,
				},
			})

			-- Re-register plugin_a with a much higher (later-running) priority.
			plugin_manager.register({
				name = "plugin_a",
				priority = 500,
				context = {
					afterHydrate = function()
						table.insert(call_order, "plugin_a")
					end,
				},
			})

			plugin_manager.register({
				name = "plugin_b",
				priority = 200,
				context = {
					afterHydrate = function()
						table.insert(call_order, "plugin_b")
					end,
				},
			})

			plugin_manager.afterHydrate({})

			assert.same({ "plugin_b", "plugin_a" }, call_order)
		end)

		it("should preserve a plugin's position when re-registering with the same priority", function()
			local call_order = {}

			plugin_manager.register({
				name = "plugin_a",
				context = {
					afterHydrate = function()
						table.insert(call_order, "plugin_a")
					end,
				},
			})

			plugin_manager.register({
				name = "plugin_b",
				context = {
					afterHydrate = function()
						table.insert(call_order, "plugin_b")
					end,
				},
			})

			-- Re-register plugin_a with a new hook closure but still no explicit priority.
			plugin_manager.register({
				name = "plugin_a",
				context = {
					afterHydrate = function()
						table.insert(call_order, "plugin_a")
					end,
				},
			})

			plugin_manager.afterHydrate({})

			assert.same({ "plugin_a", "plugin_b" }, call_order)
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

		it("should not re-run or skip plugins when a hook registers a lower-priority plugin mid-dispatch", function()
			local call_order = {}

			plugin_manager.register({
				name = "a",
				context = {
					afterHydrate = function()
						table.insert(call_order, "a")

						plugin_manager.register({
							name = "early",
							priority = 1,
							context = {
								afterHydrate = function()
									table.insert(call_order, "early")
								end,
							},
						})
					end,
				},
			})

			plugin_manager.afterHydrate({})

			-- "a" must fire exactly once (not twice) during this dispatch; the plugin it
			-- registers mid-dispatch ("early") does not retroactively cut into the pass
			-- already in flight.
			assert.same({ "a" }, call_order)

			plugin_manager.afterHydrate({})

			-- "early" now has a slot and, thanks to its lower priority, runs before "a"
			-- starting from this next dispatch.
			assert.same({ "a", "early", "a" }, call_order)
		end)

		it("should not re-run or skip plugins when a hook re-registers an already-registered plugin with a changed priority mid-dispatch", function()
			local call_order = {}

			plugin_manager.register({
				name = "a",
				priority = 10,
				context = {
					afterHydrate = function()
						table.insert(call_order, "a")

						plugin_manager.register({
							name = "b",
							priority = 5,
							context = {
								afterHydrate = function()
									table.insert(call_order, "b")
								end,
							},
						})
					end,
				},
			})

			plugin_manager.register({
				name = "b",
				priority = 20,
				context = {
					afterHydrate = function()
						table.insert(call_order, "b")
					end,
				},
			})

			plugin_manager.afterHydrate({})

			-- "a" must fire exactly once during this dispatch; "b"'s re-registration with a
			-- lower priority (which does a `table.remove` then re-insert earlier in the
			-- list) does not retroactively cut into the pass already in flight — it takes
			-- effect starting next dispatch, same snapshot invariant as above.
			assert.same({ "a", "b" }, call_order)
		end)
	end)
end)
