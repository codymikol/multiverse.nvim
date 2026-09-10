local stub = require("luassert.stub")

local PluginContext = require("multiverse.data.plugin.PluginContext")
local log = require("multiverse.log")

describe("PluginContext", function()
	describe("new", function()
		local log_warn_stub

		before_each(function()
			log_warn_stub = stub(log, "warn")
		end)

		after_each(function()
			log_warn_stub:revert()
		end)

		describe("with a valid name only", function()
			it("should return a non-nil context with the correct name", function()
				local context = PluginContext:new({ name = "my-plugin" })

				assert.is_not.Nil(context)
				assert.are.equal("my-plugin", context.name)
			end)
		end)

		describe("with a valid name and all four valid hooks", function()
			local beforeDehydrate = function() end
			local afterDehydrate = function() end
			local beforeHydrate = function() end
			local afterHydrate = function() end

			local context = PluginContext:new({
				name = "my-plugin",
				beforeDehydrate = beforeDehydrate,
				afterDehydrate = afterDehydrate,
				beforeHydrate = beforeHydrate,
				afterHydrate = afterHydrate,
			})

			it("should return a non-nil context with the correct name", function()
				assert.is_not.Nil(context)
				assert.are.equal("my-plugin", context.name)
			end)

			it("should have the correct beforeDehydrate hook", function()
				assert.are.equal(beforeDehydrate, context.beforeDehydrate)
			end)

			it("should have the correct afterDehydrate hook", function()
				assert.are.equal(afterDehydrate, context.afterDehydrate)
			end)

			it("should have the correct beforeHydrate hook", function()
				assert.are.equal(beforeHydrate, context.beforeHydrate)
			end)

			it("should have the correct afterHydrate hook", function()
				assert.are.equal(afterHydrate, context.afterHydrate)
			end)
		end)

		describe("with a missing name", function()
			it("should return nil", function()
				local context = PluginContext:new({})

				assert.is.Nil(context)
			end)

			it("should call log.warn", function()
				PluginContext:new({})
				assert.stub(log_warn_stub).was.called()
			end)
		end)

		describe("with an empty string name", function()
			it("should return nil", function()
				local context = PluginContext:new({ name = "" })

				assert.is.Nil(context)
			end)

			it("should call log.warn", function()
				PluginContext:new({ name = "" })
				assert.stub(log_warn_stub).was.called()
			end)
		end)

		describe("with a non-string name", function()
			it("should return nil", function()
				local context = PluginContext:new({ name = 5 })

				assert.is.Nil(context)
			end)

			it("should call log.warn", function()
				PluginContext:new({ name = 5 })
				assert.stub(log_warn_stub).was.called()
			end)
		end)

		describe("with non-table opts", function()
			it("should return nil", function()
				local context = PluginContext:new(42)

				assert.is.Nil(context)
			end)

			it("should call log.warn", function()
				PluginContext:new(42)
				assert.stub(log_warn_stub).was.called()
			end)
		end)

		describe("with a hook field present but not a function", function()
			it("should still construct a context with the valid name", function()
				local context = PluginContext:new({ name = "my-plugin", beforeDehydrate = "not-a-function" })

				assert.is_not.Nil(context)
				assert.are.equal("my-plugin", context.name)
			end)

			it("should omit the invalid hook from the constructed context", function()
				local context = PluginContext:new({ name = "my-plugin", beforeDehydrate = "not-a-function" })

				assert.is.Nil(context.beforeDehydrate)
			end)

			it("should call log.warn naming the field", function()
				PluginContext:new({ name = "my-plugin", beforeDehydrate = "not-a-function" })
				assert.stub(log_warn_stub).was.called()
			end)
		end)
	end)
end)
