local stub = require("luassert.stub")

describe("multiverse setup", function()
	describe("Multiverse.setup with opts.plugins", function()
		local Plugin
		local log
		local initialize_stub
		local cli_stub
		local on_exit_stub
		local on_buffer_close_stub
		local on_vim_enter_stub
		local vim_cmd_stub
		local log_warn_stub

		before_each(function()
			-- plugin_manager registers NeoTreePlugin by default, whose beforeDehydrate
			-- shells out to the (unavailable in this headless test env) Neotree command.
			vim_cmd_stub = stub(vim, "cmd")

			package.loaded["multiverse"] = nil
			package.loaded["multiverse.managers.plugin_manager"] = nil
			package.loaded["multiverse.data.plugin.Plugin"] = nil
			package.loaded["multiverse.data.plugin.PluginContext"] = nil
			package.loaded["multiverse.log"] = nil

			-- cli_manager transitively requires the telescope integration, which is
			-- not installed in the test environment; replace it wholesale so
			-- requiring "multiverse" doesn't pull in a missing runtime dependency.
			package.loaded["multiverse.managers.cli_manager"] = { registerCommands = function() end }

			initialize_stub = stub(require("multiverse.usecases.initialize"), "run")
			cli_stub = stub(package.loaded["multiverse.managers.cli_manager"], "registerCommands")
			on_exit_stub = stub(require("multiverse.autocmd.on_exit"), "register")
			on_buffer_close_stub = stub(require("multiverse.autocmd.on_buffer_close"), "register")
			on_vim_enter_stub = stub(require("multiverse.autocmd.on_vim_enter"), "register")

			log = require("multiverse.log")
			log_warn_stub = stub(log, "warn")

			Plugin = require("multiverse.data.plugin.Plugin")
		end)

		after_each(function()
			vim_cmd_stub:revert()
			initialize_stub:revert()
			cli_stub:revert()
			on_exit_stub:revert()
			on_buffer_close_stub:revert()
			on_vim_enter_stub:revert()
			log_warn_stub:revert()

			package.loaded["multiverse"] = nil
			package.loaded["multiverse.managers.plugin_manager"] = nil
			package.loaded["multiverse.managers.cli_manager"] = nil
			package.loaded["multiverse.data.plugin.Plugin"] = nil
			package.loaded["multiverse.data.plugin.PluginContext"] = nil
			package.loaded["multiverse.log"] = nil
		end)

		it("registers a user plugin so its lifecycle hooks are invoked", function()
			local beforeDehydrate_calls = {}
			local myPlugin = Plugin:new({
				name = "TestPlugin",
				beforeDehydrate = function(ctx)
					table.insert(beforeDehydrate_calls, ctx)
				end,
			})

			local Multiverse = require("multiverse")
			Multiverse.setup({ plugins = { myPlugin } })

			local plugin_manager = require("multiverse.managers.plugin_manager")
			plugin_manager.beforeDehydrate({ universe = {} })

			assert.equals(1, #beforeDehydrate_calls)
		end)

		it("does not error when called with no opts", function()
			local Multiverse = require("multiverse")

			assert.has_no.errors(function()
				Multiverse.setup()
			end)
		end)

		it("warns and does not error when opts.plugins is a single Plugin instead of a list", function()
			local myPlugin = Plugin:new({
				name = "TestPlugin",
				beforeDehydrate = function() end,
			})

			local Multiverse = require("multiverse")

			assert.has_no.errors(function()
				Multiverse.setup({ plugins = myPlugin })
			end)

			assert.stub(log_warn_stub).was.called()
		end)

		it("warns and does not error when opts.plugins is a non-table value", function()
			local Multiverse = require("multiverse")

			assert.has_no.errors(function()
				Multiverse.setup({ plugins = "not-a-table" })
			end)

			assert.stub(log_warn_stub).was.called()
			assert.stub(cli_stub).was.called()
			assert.stub(on_exit_stub).was.called()
			assert.stub(on_buffer_close_stub).was.called()
			assert.stub(on_vim_enter_stub).was.called()
		end)

		it("registers a plugin that follows a nil hole in opts.plugins", function()
			-- A hole at an earlier index (e.g. from a Plugin:new call that returned nil)
			-- must not stop registration from reaching later, valid entries.
			local beforeDehydrate_calls = {}
			local myPlugin = Plugin:new({
				name = "TestPlugin",
				beforeDehydrate = function(ctx)
					table.insert(beforeDehydrate_calls, ctx)
				end,
			})

			local plugins_with_hole = {}
			plugins_with_hole[1] = nil
			plugins_with_hole[2] = myPlugin

			local Multiverse = require("multiverse")
			Multiverse.setup({ plugins = plugins_with_hole })

			local plugin_manager = require("multiverse.managers.plugin_manager")
			plugin_manager.beforeDehydrate({ universe = {} })

			assert.equals(1, #beforeDehydrate_calls)
		end)

		it("does not error and still completes setup when opts is a non-table value", function()
			local Multiverse = require("multiverse")

			assert.has_no.errors(function()
				Multiverse.setup(42)
			end)

			assert.stub(cli_stub).was.called()
			assert.stub(on_exit_stub).was.called()
			assert.stub(on_buffer_close_stub).was.called()
			assert.stub(on_vim_enter_stub).was.called()
		end)

		it("also invokes afterHydrate for a setup-registered plugin", function()
			local afterHydrate_calls = {}
			local myPlugin = Plugin:new({
				name = "TestPlugin",
				afterHydrate = function(ctx)
					table.insert(afterHydrate_calls, ctx)
				end,
			})

			local Multiverse = require("multiverse")
			Multiverse.setup({ plugins = { myPlugin } })

			local plugin_manager = require("multiverse.managers.plugin_manager")
			plugin_manager.afterHydrate({ universe = nil })

			assert.equals(1, #afterHydrate_calls)
		end)
	end)
end)
