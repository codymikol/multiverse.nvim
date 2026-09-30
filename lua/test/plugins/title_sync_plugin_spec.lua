local stub = require("luassert.stub")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local Multiverse = require("multiverse.data.Multiverse")
local UniverseSummary = require("multiverse.data.UniverseSummary")

describe("plugins.title_sync_plugin", function()
	local title_sync_plugin
	local original_titlestring
	local original_title
	local original_enabled

	local getMultiverse_stub
	local getcwd_stub
	local multiverse
	local getUniverseByDirectory_stub

	local test_directory = "/some/universe/dir"
	local universe_summary

	before_each(function()
		package.loaded["plugins.title_sync_plugin"] = nil

		original_titlestring = vim.o.titlestring
		original_title = vim.o.title
		original_enabled = vim.g.multiverse_title_enabled

		vim.o.titlestring = "original-title"
		vim.o.title = false
		vim.g.multiverse_title_enabled = nil

		universe_summary =
			UniverseSummary:new({ directory = test_directory, uuid = "some-uuid", name = "MyUniverse", lastExplored = 1 })
		multiverse = Multiverse:new({ universe_summary })

		getMultiverse_stub = stub(multiverse_repository, "getMultiverse")
		getMultiverse_stub.returns(multiverse)

		getUniverseByDirectory_stub = stub(multiverse, "getUniverseByDirectory")
		getUniverseByDirectory_stub.returns(universe_summary)

		getcwd_stub = stub(vim.fn, "getcwd")
		getcwd_stub.returns(test_directory)

		title_sync_plugin = require("plugins.title_sync_plugin")
	end)

	after_each(function()
		getMultiverse_stub:revert()
		getUniverseByDirectory_stub:revert()
		getcwd_stub:revert()

		vim.o.titlestring = original_titlestring
		vim.o.title = original_title
		vim.g.multiverse_title_enabled = original_enabled
		package.loaded["plugins.title_sync_plugin"] = nil
	end)

	describe("context.afterHydrate", function()
		it("sets titlestring to the universe name resolved from cwd when enabled and cwd matches a known universe", function()
			vim.g.multiverse_title_enabled = true

			title_sync_plugin.context.afterHydrate({})

			assert.are.equal("MyUniverse", vim.o.titlestring)
			assert.is_true(vim.o.title)
		end)

		it("resolves the universe via the trailing-slash fallback lookup when the exact cwd doesn't match", function()
			vim.g.multiverse_title_enabled = true
			getUniverseByDirectory_stub.returns(nil)
			getUniverseByDirectory_stub.on_call_with(multiverse, test_directory .. "/").returns(universe_summary)

			title_sync_plugin.context.afterHydrate({})

			assert.are.equal("MyUniverse", vim.o.titlestring)
		end)

		it("does nothing when multiverse_title_enabled is not true", function()
			vim.g.multiverse_title_enabled = false

			title_sync_plugin.context.afterHydrate({})

			assert.are.equal("original-title", vim.o.titlestring)
			assert.is_false(vim.o.title)

			vim.g.multiverse_title_enabled = nil

			title_sync_plugin.context.afterHydrate({})

			assert.are.equal("original-title", vim.o.titlestring)
			assert.is_false(vim.o.title)
		end)

		it("does nothing when cwd doesn't match any known universe", function()
			vim.g.multiverse_title_enabled = true
			getUniverseByDirectory_stub.returns(nil)

			title_sync_plugin.context.afterHydrate({})

			assert.are.equal("original-title", vim.o.titlestring)
		end)

		it("escapes a % in the universe name so it isn't evaluated as a statusline expression", function()
			vim.g.multiverse_title_enabled = true
			local percent_universe = UniverseSummary:new({
				directory = test_directory,
				uuid = "percent-uuid",
				name = "50% done",
				lastExplored = 1,
			})
			getUniverseByDirectory_stub.returns(percent_universe)

			title_sync_plugin.context.afterHydrate({})

			assert.are.equal("50%% done", vim.o.titlestring)
		end)

		it("strips control bytes from the universe name before setting titlestring", function()
			vim.g.multiverse_title_enabled = true
			local control_byte_universe = UniverseSummary:new({
				directory = test_directory,
				uuid = "control-uuid",
				name = "My\27Universe",
				lastExplored = 1,
			})
			getUniverseByDirectory_stub.returns(control_byte_universe)

			title_sync_plugin.context.afterHydrate({})

			assert.are.equal("MyUniverse", vim.o.titlestring)
		end)

		it("passes a multi-byte UTF-8 universe name through untouched", function()
			vim.g.multiverse_title_enabled = true
			local utf8_universe = UniverseSummary:new({
				directory = test_directory,
				uuid = "utf8-uuid",
				name = "日本語",
				lastExplored = 1,
			})
			getUniverseByDirectory_stub.returns(utf8_universe)

			title_sync_plugin.context.afterHydrate({})

			assert.are.equal("日本語", vim.o.titlestring)
		end)

		it("does nothing when multiverse_repository.getMultiverse() returns nil", function()
			vim.g.multiverse_title_enabled = true
			getMultiverse_stub.returns(nil)

			title_sync_plugin.context.afterHydrate({})

			assert.are.equal("original-title", vim.o.titlestring)
		end)
	end)
end)
