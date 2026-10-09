local stub = require("luassert.stub")

-- Inject a fake telescope integration before requiring cli_manager (transitively
-- required by multiverse.lua) so it never reaches the real telescope.nvim modules,
-- which are not available in CI.
package.loaded["integrations.telescope"] = { prompt_select_universe = function() end }

local Multiverse = require("multiverse")
local initialize = require("multiverse.usecases.initialize")
local cli = require("multiverse.managers.cli_manager")
local plugin_manager = require("multiverse.managers.plugin_manager")
local on_exit = require("multiverse.autocmd.on_exit")
local on_buffer_close = require("multiverse.autocmd.on_buffer_close")
local on_vim_enter = require("multiverse.autocmd.on_vim_enter")

describe("Multiverse.setup", function()
	local initialize_run_stub
	local cli_register_commands_stub
	local plugin_manager_setup_commands_stub
	local on_exit_register_stub
	local on_buffer_close_register_stub
	local on_vim_enter_register_stub
	local keymap_set_stub
	local notify_stub
	local exists_stub
	local original_title_enabled

	before_each(function()
		initialize_run_stub = stub(initialize, "run")
		cli_register_commands_stub = stub(cli, "registerCommands")
		plugin_manager_setup_commands_stub = stub(plugin_manager, "setupCommands")
		on_exit_register_stub = stub(on_exit, "register")
		on_buffer_close_register_stub = stub(on_buffer_close, "register")
		on_vim_enter_register_stub = stub(on_vim_enter, "register")
		keymap_set_stub = stub(vim.keymap, "set")
		notify_stub = stub(vim, "notify")
		exists_stub = stub(vim.fn, "exists")
		exists_stub.returns(2)
		original_title_enabled = vim.g.multiverse_title_enabled
	end)

	after_each(function()
		initialize_run_stub:revert()
		cli_register_commands_stub:revert()
		plugin_manager_setup_commands_stub:revert()
		on_exit_register_stub:revert()
		on_buffer_close_register_stub:revert()
		on_vim_enter_register_stub:revert()
		keymap_set_stub:revert()
		notify_stub:revert()
		exists_stub:revert()
		vim.g.multiverse_title_enabled = original_title_enabled
	end)

	it("registers zero keymaps when opts.keymaps is not provided", function()
		Multiverse.setup()

		assert.stub(keymap_set_stub).was.called(0)
	end)

	it("still registers the plugin's ex-commands regardless of opts.keymaps", function()
		Multiverse.setup({ keymaps = { list = "<leader>ml" } })

		assert.stub(cli_register_commands_stub).was.called(1)
	end)

	it("sets up plugin-registered commands regardless of opts.keymaps", function()
		Multiverse.setup({ keymaps = { list = "<leader>ml" } })

		assert.stub(plugin_manager_setup_commands_stub).was.called(1)
	end)

	it("registers zero keymaps when opts is an empty table", function()
		Multiverse.setup({})

		assert.stub(keymap_set_stub).was.called(0)
	end)

	it("maps the configured 'list' key to MultiverseList", function()
		Multiverse.setup({ keymaps = { list = "<leader>ml" } })

		assert.stub(keymap_set_stub).was.called_with(
			"n",
			"<leader>ml",
			"<cmd>MultiverseList<cr>",
			{ desc = "MultiverseList" }
		)
	end)

	it("maps the configured 'terminal' key to MultiverseTerminal", function()
		Multiverse.setup({ keymaps = { terminal = "<leader>mt" } })

		assert.stub(keymap_set_stub).was.called_with(
			"n",
			"<leader>mt",
			"<cmd>MultiverseTerminal<cr>",
			{ desc = "MultiverseTerminal" }
		)
	end)

	it("warns and does not set a keymap when the mapped command is not registered", function()
		exists_stub.returns(0)

		Multiverse.setup({ keymaps = { terminal = "<leader>mt" } })

		assert.stub(keymap_set_stub).was.called(0)
		assert.stub(notify_stub).was.called_with(
			"multiverse.setup: cannot map keymaps key 'terminal' to missing command 'MultiverseTerminal'",
			vim.log.levels.WARN
		)
	end)

	it("maps the configured 'open' key into cmdline mode instead of executing with no argument", function()
		Multiverse.setup({ keymaps = { open = "<leader>mo" } })

		assert.stub(keymap_set_stub).was.called_with(
			"n",
			"<leader>mo",
			":MultiverseOpen ",
			{ desc = "MultiverseOpen (prompt)" }
		)
	end)

	it("warns and registers nothing for an unsupported keymaps key", function()
		Multiverse.setup({ keymaps = { alternate = "<leader>mm" } })

		assert.stub(keymap_set_stub).was.called(0)
		assert.stub(notify_stub).was.called_with(
			"multiverse.setup: unknown keymaps key 'alternate'",
			vim.log.levels.WARN
		)
	end)

	it("registers only the valid keymap when opts.keymaps mixes a valid and an unsupported key", function()
		Multiverse.setup({ keymaps = { list = "<leader>ml", alternate = "<leader>mm" } })

		assert.stub(keymap_set_stub).was.called(1)
		assert.stub(keymap_set_stub).was.called_with(
			"n",
			"<leader>ml",
			"<cmd>MultiverseList<cr>",
			{ desc = "MultiverseList" }
		)
		assert.stub(notify_stub).was.called_with(
			"multiverse.setup: unknown keymaps key 'alternate'",
			vim.log.levels.WARN
		)
	end)

	it("enables vim.g.multiverse_title_enabled when opts.title is true", function()
		Multiverse.setup({ title = true })

		assert.is_true(vim.g.multiverse_title_enabled)
	end)

	it("disables vim.g.multiverse_title_enabled when opts is not provided", function()
		Multiverse.setup()

		assert.is_false(vim.g.multiverse_title_enabled)
	end)

	it("disables vim.g.multiverse_title_enabled when opts is an empty table", function()
		Multiverse.setup({})

		assert.is_false(vim.g.multiverse_title_enabled)
	end)

	it("warns and disables vim.g.multiverse_title_enabled for a non-boolean opts.title", function()
		Multiverse.setup({ title = "yes" })

		assert.is_false(vim.g.multiverse_title_enabled)
		assert.stub(notify_stub).was.called_with(
			"multiverse.setup: opts.title must be a boolean, got: string",
			vim.log.levels.WARN
		)
	end)
end)
