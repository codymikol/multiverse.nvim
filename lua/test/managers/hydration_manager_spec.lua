local hydration_manager = require("multiverse.managers.hydration_manager")
local universe_repository = require("multiverse.repositories.universe_repository")
local buffer_manager = require("multiverse.managers.buffer_manager")
local tabpage_manager = require("multiverse.managers.tabpage_manager")
local window_layout_manager = require("multiverse.managers.window_layout_manager")
local Universe = require("multiverse.data.Universe")
local UniverseSummary = require("multiverse.data.UniverseSummary")
local stub = require("luassert.stub")

describe("hydration_manager", function()
	describe("hydrate", function()
		local getUniverseByUuid_stub
		local nvim_command_stub
		local hydrateBuffersForUniverse_stub
		local tabpage_hydrate_stub
		local window_layout_hydrate_stub
		local close_generated_nofile_scratch_buffers_stub
		local vim_cmd_stub
		local notify_stub

		local selected_universe
		local universe

		before_each(function()
			universe = Universe:new("uuid-1", "example", "/home/foo")
			selected_universe = UniverseSummary:new("/home/foo", "uuid-1", "example", 0)

			getUniverseByUuid_stub = stub(universe_repository, "getUniverseByUuid")
			getUniverseByUuid_stub.returns(nil, universe)

			nvim_command_stub = stub(vim.api, "nvim_command")
			hydrateBuffersForUniverse_stub = stub(buffer_manager, "hydrateBuffersForUniverse")
			tabpage_hydrate_stub = stub(tabpage_manager, "hydrate")
			window_layout_hydrate_stub = stub(window_layout_manager, "hydrate")
			close_generated_nofile_scratch_buffers_stub = stub(buffer_manager, "close_generated_nofile_scratch_buffers")
			vim_cmd_stub = stub(vim, "cmd")
			notify_stub = stub(vim, "notify")
		end)

		after_each(function()
			getUniverseByUuid_stub:revert()
			nvim_command_stub:revert()
			hydrateBuffersForUniverse_stub:revert()
			tabpage_hydrate_stub:revert()
			window_layout_hydrate_stub:revert()
			close_generated_nofile_scratch_buffers_stub:revert()
			vim_cmd_stub:revert()
			notify_stub:revert()
		end)

		it("should not invoke vim.cmd (regression guard: the removed Neotree integration was its only caller)", function()
			hydration_manager.hydrate(selected_universe)

			assert.stub(vim_cmd_stub).was_not_called()
		end)

		it("should set the cwd to the universe's workingDirectory", function()
			hydration_manager.hydrate(selected_universe)

			assert.stub(nvim_command_stub).was.called_with("cd " .. universe.workingDirectory)
		end)

		it("should hydrate buffers, tabpages, and window layout for the universe", function()
			hydration_manager.hydrate(selected_universe)

			assert.stub(hydrateBuffersForUniverse_stub).was.called_with(universe)
			assert.stub(tabpage_hydrate_stub).was.called_with(universe)
			assert.stub(window_layout_hydrate_stub).was.called_with(universe)
		end)

		it("should close generated nofile scratch buffers after hydrating", function()
			hydration_manager.hydrate(selected_universe)

			assert.stub(close_generated_nofile_scratch_buffers_stub).was.called()
		end)

		it("should notify and return early when the universe is not found", function()
			getUniverseByUuid_stub.returns(nil, nil)

			hydration_manager.hydrate(selected_universe)

			assert.stub(notify_stub).was.called_with("Universe not found")
			assert.stub(nvim_command_stub).was_not_called()
			assert.stub(hydrateBuffersForUniverse_stub).was_not_called()
		end)
	end)
end)
