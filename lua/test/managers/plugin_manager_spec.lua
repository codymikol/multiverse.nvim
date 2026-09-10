local stub = require("luassert.stub")

describe("multiverse.managers.plugin_manager", function()
	local plugin_manager
	local Plugin
	local log
	local log_warn_stub
	local vim_cmd_stub

	before_each(function()
		-- plugin_manager registers NeoTreePlugin by default, whose beforeDehydrate
		-- shells out to the (unavailable in this headless test env) Neotree command.
		vim_cmd_stub = stub(vim, "cmd")

		package.loaded["multiverse.managers.plugin_manager"] = nil
		package.loaded["multiverse.data.plugin.Plugin"] = nil
		package.loaded["multiverse.data.plugin.PluginContext"] = nil
		package.loaded["multiverse.log"] = nil

		log = require("multiverse.log")
		log_warn_stub = stub(log, "warn")

		plugin_manager = require("multiverse.managers.plugin_manager")
		Plugin = require("multiverse.data.plugin.Plugin")
	end)

	after_each(function()
		vim_cmd_stub:revert()
		log_warn_stub:revert()

		package.loaded["multiverse.managers.plugin_manager"] = nil
		package.loaded["multiverse.data.plugin.Plugin"] = nil
		package.loaded["multiverse.data.plugin.PluginContext"] = nil
		package.loaded["multiverse.log"] = nil
	end)

	describe("register", function()
		it("does not invoke a plugin's hooks twice when the same plugin instance is registered twice", function()
			local call_count = 0
			local myPlugin = Plugin:new({
				name = "TestPlugin",
				beforeDehydrate = function()
					call_count = call_count + 1
				end,
			})

			plugin_manager.register(myPlugin)
			plugin_manager.register(myPlugin)

			plugin_manager.beforeDehydrate({ universe = {} })

			assert.equals(1, call_count)
		end)

		it("logs a warning and does not insert a malformed plugin missing a context table", function()
			local malformed = {
				name = "Malformed",
				beforeDehydrate = function() end,
			}

			assert.has_no.errors(function()
				plugin_manager.register(malformed)
			end)

			assert.stub(log_warn_stub).was.called()

			assert.has_no.errors(function()
				plugin_manager.beforeDehydrate({ universe = {} })
			end)
		end)

		it("logs a warning and does not insert a non-table plugin", function()
			assert.has_no.errors(function()
				plugin_manager.register("not-a-table")
			end)

			assert.stub(log_warn_stub).was.called()

			assert.has_no.errors(function()
				plugin_manager.beforeDehydrate({ universe = {} })
			end)
		end)
	end)
end)
