local state_store = require("multiverse.store.state_store")

local augroup_name = "multiverse_state_store_spec"

describe("state_store", function()
	describe("set_current_state", function()
		local autocmd_id

		before_each(function()
			state_store.set_current_state(state_store.STATES.IDLE)
			vim.api.nvim_create_augroup(augroup_name, { clear = true })
		end)

		after_each(function()
			if autocmd_id then
				pcall(vim.api.nvim_del_autocmd, autocmd_id)
				autocmd_id = nil
			end
			pcall(vim.api.nvim_del_augroup_by_name, augroup_name)
		end)

		it("should fire a MultiverseStateChanged User autocmd with the new state", function()
			local captured
			local state_during_callback

			autocmd_id = vim.api.nvim_create_autocmd("User", {
				pattern = "MultiverseStateChanged",
				group = augroup_name,
				callback = function(args)
					captured = args.data
					state_during_callback = state_store.get_current_state()
				end,
			})

			state_store.set_current_state(state_store.STATES.HYDRATION)

			assert.is_not_nil(captured)
			assert.equals(state_store.STATES.HYDRATION, captured.state)
			assert.equals(state_store.STATES.HYDRATION, state_during_callback)
		end)

		it("should not fire the MultiverseStateChanged autocmd when given an invalid state", function()
			local call_count = 0

			autocmd_id = vim.api.nvim_create_autocmd("User", {
				pattern = "MultiverseStateChanged",
				group = augroup_name,
				callback = function()
					call_count = call_count + 1
				end,
			})

			assert.has_error(function()
				state_store.set_current_state("NOT_A_REAL_STATE")
			end)

			assert.equals(0, call_count)
		end)
	end)
end)
