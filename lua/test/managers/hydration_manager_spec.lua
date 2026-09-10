local stub = require("luassert.stub")
local match = require("luassert.match")

local universe_repository = require("multiverse.repositories.universe_repository")
local buffer_manager = require("multiverse.managers.buffer_manager")
local neotree_integration = require("integrations.neotree")
local tabpage_manager = require("multiverse.managers.tabpage_manager")
local window_layout_manager = require("multiverse.managers.window_layout_manager")
local hydration_manager = require("multiverse.managers.hydration_manager")
local log = require("multiverse.log")

describe("hydration_manager", function()
	describe("hydrate", function()
		local get_universe_by_uuid_stub
		local hydrateBuffersForUniverse_stub
		local close_generated_nofile_scratch_buffers_stub
		local neotree_hydrate_stub
		local tabpage_hydrate_stub
		local window_layout_hydrate_stub
		local notify_stub
		local nvim_command_stub
		local log_error_stub

		before_each(function()
			get_universe_by_uuid_stub = stub(universe_repository, "get_universe_by_uuid")
			hydrateBuffersForUniverse_stub = stub(buffer_manager, "hydrateBuffersForUniverse")
			close_generated_nofile_scratch_buffers_stub = stub(buffer_manager, "close_generated_nofile_scratch_buffers")
			neotree_hydrate_stub = stub(neotree_integration, "hydrate")
			tabpage_hydrate_stub = stub(tabpage_manager, "hydrate")
			window_layout_hydrate_stub = stub(window_layout_manager, "hydrate")
			notify_stub = stub(vim, "notify")
			nvim_command_stub = stub(vim.api, "nvim_command")
			log_error_stub = stub(log, "error")
		end)

		after_each(function()
			get_universe_by_uuid_stub:revert()
			hydrateBuffersForUniverse_stub:revert()
			close_generated_nofile_scratch_buffers_stub:revert()
			neotree_hydrate_stub:revert()
			tabpage_hydrate_stub:revert()
			window_layout_hydrate_stub:revert()
			notify_stub:revert()
			nvim_command_stub:revert()
			log_error_stub:revert()
		end)

		describe("when the universe is not found", function()
			before_each(function()
				get_universe_by_uuid_stub.returns(nil, "some error")
			end)

			it("should notify the user and not hydrate anything", function()
				hydration_manager.hydrate({ uuid = "abc" })

				assert.stub(get_universe_by_uuid_stub).was.called_with("abc")

				assert.stub(notify_stub).was.called_with("Universe not found: some error")

				assert.stub(hydrateBuffersForUniverse_stub).was_not.called()
				assert.stub(tabpage_hydrate_stub).was_not.called()
				assert.stub(window_layout_hydrate_stub).was_not.called()
				assert.stub(neotree_hydrate_stub).was_not.called()
				assert.stub(close_generated_nofile_scratch_buffers_stub).was_not.called()
			end)
		end)

		describe("when the universe is found", function()
			local universe

			before_each(function()
				universe = { workingDirectory = "/some/dir", uuid = "abc" }
				get_universe_by_uuid_stub.returns(universe, nil)
			end)

			it("should hydrate the current neovim environment with the universe", function()
				hydration_manager.hydrate({ uuid = "abc" })

				assert.stub(get_universe_by_uuid_stub).was.called_with("abc")

				assert.stub(nvim_command_stub).was.called_with("cd /some/dir")

				assert.stub(hydrateBuffersForUniverse_stub).was.called_with(universe)
				assert.stub(tabpage_hydrate_stub).was.called_with(universe)
				assert.stub(window_layout_hydrate_stub).was.called_with(universe)
				assert.stub(neotree_hydrate_stub).was.called()
				assert.stub(close_generated_nofile_scratch_buffers_stub).was.called()

				assert.stub(notify_stub).was_not.called()
			end)

			describe("when the universe's working directory contains characters that require escaping", function()
				before_each(function()
					universe.workingDirectory = "/some/dir with spaces"
				end)

				it("should escape the working directory before passing it to the :cd command", function()
					hydration_manager.hydrate({ uuid = "abc" })

					assert.stub(nvim_command_stub).was.called_with("cd /some/dir\\ with\\ spaces")

					assert.stub(hydrateBuffersForUniverse_stub).was.called_with(universe)
					assert.stub(tabpage_hydrate_stub).was.called_with(universe)
					assert.stub(window_layout_hydrate_stub).was.called_with(universe)
					assert.stub(neotree_hydrate_stub).was.called()
					assert.stub(close_generated_nofile_scratch_buffers_stub).was.called()

					assert.stub(notify_stub).was_not.called()
				end)
			end)

			describe("when the universe's working directory contains an Ex command separator", function()
				before_each(function()
					universe.workingDirectory = "/some/dir|qall!"
				end)

				it("should escape the working directory so it cannot inject a second Ex command", function()
					hydration_manager.hydrate({ uuid = "abc" })

					assert.stub(nvim_command_stub).was.called_with("cd /some/dir\\|qall\\!")
				end)
			end)
		end)

		describe("when a hydration stage throws an error", function()
			local universe

			before_each(function()
				universe = { workingDirectory = "/some/dir", uuid = "abc" }
				get_universe_by_uuid_stub.returns(universe, nil)
				window_layout_hydrate_stub.invokes(function()
					error("boom 100% full")
				end)
			end)

			it("should notify the user and still run cleanup instead of propagating the error", function()
				assert.has_no.errors(function()
					hydration_manager.hydrate({ uuid = "abc" })
				end)

				assert.stub(close_generated_nofile_scratch_buffers_stub).was.called()
				assert.stub(neotree_hydrate_stub).was_not.called()

				assert.stub(notify_stub).was.called_with(match._, vim.log.levels.ERROR)
				assert.stub(log_error_stub).was.called_with("%s", match._)
			end)
		end)
	end)
end)
