local stub = require("luassert.stub")
local match = require("luassert.match")

-- Inject a fake telescope integration before requiring cli_manager so that
-- its transitive require of "integrations.telescope" never reaches the real
-- telescope.nvim modules, which are not available in CI.
package.loaded["integrations.telescope"] = { prompt_select_universe = function() end }

local cli_manager = require("multiverse.managers.cli_manager")
local log = require("multiverse.log")
local addNewUniverseUsecase = require("multiverse.usecases.addNewUniverseUsecase")
local alternateUniverseUsecase = require("multiverse.usecases.alternateUniverseUsecase")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")

describe("cli_manager.registerCommands", function()
	describe("MultiverseAdd", function()
		local create_user_command_stub
		local run_stub

		before_each(function()
			create_user_command_stub = stub(vim.api, "nvim_create_user_command")
			run_stub = stub(addNewUniverseUsecase, "run")
		end)

		after_each(function()
			create_user_command_stub:revert()
			run_stub:revert()
		end)

		local function get_callback()
			cli_manager.registerCommands()

			for _, call in ipairs(create_user_command_stub.calls) do
				if call.refs[1] == "MultiverseAdd" then
					return call.refs[2]
				end
			end
		end

		it("registers a MultiverseAdd user command accepting a variable number of args", function()
			cli_manager.registerCommands()

			assert.stub(create_user_command_stub).was.called_with(
				"MultiverseAdd",
				match._,
				{ nargs = "*", complete = "file" }
			)
		end)

		it("passes both fargs through to addNewUniverseUsecase.run when two args are given", function()
			local callback = get_callback()

			callback({ fargs = { "myname", "/some/dir" } })

			assert.stub(run_stub).was_called_with("myname", "/some/dir")
		end)

		it("passes nil for the missing directory when only one arg is given", function()
			local callback = get_callback()

			callback({ fargs = { "myname" } })

			assert.stub(run_stub).was_called_with("myname", nil)
		end)

		it("passes nil for both name and directory when no args are given", function()
			local callback = get_callback()

			callback({ fargs = {} })

			assert.stub(run_stub).was_called_with(nil, nil)
		end)
	end)

	describe("MultiverseLog", function()
		local create_user_command_stub

		local get_log_file_stub

		before_each(function()
			create_user_command_stub = stub(vim.api, "nvim_create_user_command")
			get_log_file_stub = stub(log, "get_log_file")
		end)

		after_each(function()
			create_user_command_stub:revert()
			get_log_file_stub:revert()
			pcall(vim.cmd, "bdelete!")
			if #vim.api.nvim_list_wins() > 1 then
				vim.cmd("only")
			end
		end)

		it("registers a MultiverseLog user command", function()
			cli_manager.registerCommands()

			assert.stub(create_user_command_stub).was.called_with(
				"MultiverseLog",
				match._,
				match._
			)
		end)

		it("opens a log path containing '%' without mangling it via cmdline expansion", function()
			local log_path = vim.fn.tempname() .. "_a%b.log"
			get_log_file_stub.returns(log_path)

			cli_manager.registerCommands()

			local callback
			for _, call in ipairs(create_user_command_stub.calls) do
				if call.refs[1] == "MultiverseLog" then
					callback = call.refs[2]
				end
			end

			assert.has_no.errors(callback)
			assert.are.equal(log_path, vim.api.nvim_buf_get_name(0))
			assert.is_false(vim.bo.modifiable)
		end)
	end)

	describe("complete_universe", function()
		local create_user_command_stub
		local get_multiverse_stub

		before_each(function()
			create_user_command_stub = stub(vim.api, "nvim_create_user_command")
			get_multiverse_stub = stub(multiverse_repository, "getMultiverse")
		end)

		after_each(function()
			create_user_command_stub:revert()
			get_multiverse_stub:revert()
		end)

		local function get_callback()
			cli_manager.registerCommands()

			for _, call in ipairs(create_user_command_stub.calls) do
				if call.refs[1] == "MultiverseOpen" then
					return call.refs[3].complete
				end
			end
		end

		it("returns matching universe names when the multiverse has universes", function()
			get_multiverse_stub.returns({
				universes = {
					{ name = "foo" },
					{ name = "bar" },
					{ name = "foobar" },
				},
			})

			local callback = get_callback()

			local completions = callback("foo", "", 0)

			assert.are.same({ "foo", "foobar" }, completions)
		end)

		it("returns an empty table without erroring when getMultiverse returns nil", function()
			get_multiverse_stub.returns(nil)

			local callback = get_callback()

			local completions
			assert.has_no.errors(function()
				completions = callback("", "", 0)
			end)

			assert.are.same({}, completions)
		end)
	end)

	describe("MultiverseAlternate", function()
		local create_user_command_stub
		local run_stub

		before_each(function()
			create_user_command_stub = stub(vim.api, "nvim_create_user_command")
			run_stub = stub(alternateUniverseUsecase, "run")
		end)

		after_each(function()
			create_user_command_stub:revert()
			run_stub:revert()
		end)

		it("registers a MultiverseAlternate user command with nargs = 0", function()
			cli_manager.registerCommands()

			assert.stub(create_user_command_stub).was.called_with(
				"MultiverseAlternate",
				match._,
				{ nargs = 0 }
			)
		end)

		it("delegates to alternateUniverseUsecase.run", function()
			cli_manager.registerCommands()

			local callback
			for _, call in ipairs(create_user_command_stub.calls) do
				if call.refs[1] == "MultiverseAlternate" then
					callback = call.refs[2]
				end
			end

			callback()

			assert.stub(run_stub).was_called(1)
		end)
	end)
end)
