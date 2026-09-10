local on_buffer_close = require("multiverse.autocmd.on_buffer_close")
local multiverse_manager = require("multiverse.managers.multiverse_manager")
local state_store = require("multiverse.store.state_store")
local stub = require("luassert.stub")

local augroup_name = "multiverse_on_buffer_close"

describe("on_buffer_close.register", function()
	local save_stub

	before_each(function()
		save_stub = stub(multiverse_manager, "save")
	end)

	after_each(function()
		save_stub:revert()
		vim.api.nvim_del_augroup_by_name(augroup_name)
	end)

	it("should not create duplicate autocmds when register() is called more than once", function()
		on_buffer_close.register()
		on_buffer_close.register()

		local autocmds = vim.api.nvim_get_autocmds({ group = augroup_name })
		assert.are.equal(1, #autocmds)
		assert.are.equal("BufDelete", autocmds[1].event)
	end)
end)

describe("on_buffer_close callback", function()
	local save_stub
	local previous_state

	local function get_callback()
		local autocmds = vim.api.nvim_get_autocmds({ group = augroup_name })
		return autocmds[1].callback
	end

	-- Fixed, non-early-returning wait: comfortably longer than on_buffer_close.lua's
	-- 10ms DEBOUNCE_MS, so a trailing/duplicate save has time to land before we assert.
	-- Keep this margin in sync if that constant changes.
	local function wait_for_debounce()
		vim.wait(50)
	end

	before_each(function()
		save_stub = stub(multiverse_manager, "save")
		previous_state = state_store.get_current_state()
		on_buffer_close.register()
	end)

	after_each(function()
		save_stub:revert()
		state_store.set_current_state(previous_state)
		vim.api.nvim_del_augroup_by_name(augroup_name)
	end)

	it("should call multiverse_manager.save() when the current state is IDLE", function()
		state_store.set_current_state(state_store.STATES.IDLE)

		local callback = get_callback()
		callback()

		wait_for_debounce()

		assert.stub(save_stub).was.called(1)
	end)

	it("should not call multiverse_manager.save() when the current state is not IDLE", function()
		state_store.set_current_state(state_store.STATES.CLEANUP)

		local callback = get_callback()
		callback()

		wait_for_debounce()

		assert.stub(save_stub).was.called(0)
	end)

	it("should coalesce rapid-fire BufDelete events into a single debounced save() call", function()
		state_store.set_current_state(state_store.STATES.IDLE)

		local callback = get_callback()
		callback()
		callback()

		wait_for_debounce()

		assert.stub(save_stub).was.called(1)
	end)

	it("should not call multiverse_manager.save() when state changes to non-IDLE before the debounced timer fires", function()
		state_store.set_current_state(state_store.STATES.IDLE)

		local callback = get_callback()
		callback()

		state_store.set_current_state(state_store.STATES.CLEANUP)

		wait_for_debounce()

		assert.stub(save_stub).was.called(0)
	end)

	it("should call multiverse_manager.save() again on a second, later BufDelete after the first debounced save landed", function()
		state_store.set_current_state(state_store.STATES.IDLE)

		local callback = get_callback()

		callback()
		wait_for_debounce()

		callback()
		wait_for_debounce()

		assert.stub(save_stub).was.called(2)
	end)
end)
