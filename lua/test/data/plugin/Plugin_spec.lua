local stub = require("luassert.stub")

local Plugin = require("multiverse.data.plugin.Plugin")
local PluginContext = require("multiverse.data.plugin.PluginContext")
local log = require("multiverse.log")

describe("Plugin", function()
	describe("new", function()
		describe("with a valid ctx", function()
			local rawCtx = {
				name = "my-plugin",
				beforeDehydrate = function() end,
			}
			local plugin = Plugin:new(rawCtx)

			it("should have a non-nil context", function()
				assert.is_not.Nil(plugin.context)
			end)

			it("should have a context with the correct name", function()
				assert.are.equal("my-plugin", plugin.context.name)
			end)

			it("should have a name matching the validated context", function()
				assert.are.equal("my-plugin", plugin.name)
			end)

			it("should have a context validated as a PluginContext", function()
				assert.are.equal(PluginContext, getmetatable(plugin.context))
			end)

			it("should have a context that is not the raw input table", function()
				assert.are_not.equal(rawCtx, plugin.context)
			end)
		end)

		describe("with an invalid ctx (missing name)", function()
			local log_warn_stub

			before_each(function()
				log_warn_stub = stub(log, "warn")
			end)

			after_each(function()
				log_warn_stub:revert()
			end)

			it("should return nil rather than a Plugin with a nil context", function()
				local plugin = Plugin:new({})

				assert.is.Nil(plugin)
			end)
		end)
	end)
end)
