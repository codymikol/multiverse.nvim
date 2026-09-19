local state_store = require("multiverse.store.state_store")

describe("state_store.try_transition", function()
	before_each(function()
		state_store.set_current_state(state_store.STATES.IDLE)
	end)

	after_each(function()
		state_store.set_current_state(state_store.STATES.IDLE)
	end)

	it("returns true and changes the state when current_state matches from", function()
		local result = state_store.try_transition(state_store.STATES.IDLE, state_store.STATES.HYDRATION)

		assert.is_true(result)
		assert.are.equal(state_store.STATES.HYDRATION, state_store.get_current_state())
	end)

	it("returns false and leaves the state unchanged when current_state does not match from", function()
		local result = state_store.try_transition(state_store.STATES.HYDRATION, state_store.STATES.CLEANUP)

		assert.is_false(result)
		assert.are.equal(state_store.STATES.IDLE, state_store.get_current_state())
	end)

	it("returns true and leaves the state unchanged when from and to are the same", function()
		local result = state_store.try_transition(state_store.STATES.IDLE, state_store.STATES.IDLE)

		assert.is_true(result)
		assert.are.equal(state_store.STATES.IDLE, state_store.get_current_state())
	end)

	it("errors when from is not a valid state", function()
		assert.has_error(function()
			state_store.try_transition("NOT_A_STATE", state_store.STATES.CLEANUP)
		end)
	end)

	it("errors when to is not a valid state", function()
		assert.has_error(function()
			state_store.try_transition(state_store.STATES.IDLE, "NOT_A_STATE")
		end)
	end)
end)

describe("state_store.with_lock", function()
	before_each(function()
		state_store.set_current_state(state_store.STATES.IDLE)
	end)

	after_each(function()
		state_store.set_current_state(state_store.STATES.IDLE)
	end)

	it("transitions to the given state during fn and resets to the prior state after", function()
		local observed_during
		state_store.with_lock(state_store.STATES.HYDRATION, function()
			observed_during = state_store.get_current_state()
		end)

		assert.are.equal(state_store.STATES.HYDRATION, observed_during)
		assert.are.equal(state_store.STATES.IDLE, state_store.get_current_state())
	end)

	it("returns whatever fn returns", function()
		local result = state_store.with_lock(state_store.STATES.HYDRATION, function()
			return "some-value"
		end)

		assert.are.equal("some-value", result)
	end)

	it("does not clobber a state change made by fn back to the prior state", function()
		state_store.with_lock(state_store.STATES.HYDRATION, function()
			state_store.set_current_state(state_store.STATES.CLEANUP)
		end)

		assert.are.equal(state_store.STATES.CLEANUP, state_store.get_current_state())
	end)

	it("propagates an error raised inside fn while still resetting the state if unclobbered", function()
		assert.has_error(function()
			state_store.with_lock(state_store.STATES.HYDRATION, function()
				error("boom")
			end)
		end)

		assert.are.equal(state_store.STATES.IDLE, state_store.get_current_state())
	end)

	it("does not drop leading nil return values from fn", function()
		local a, b, c = state_store.with_lock(state_store.STATES.HYDRATION, function()
			return nil, "boom", 3
		end)

		assert.are.equal(nil, a)
		assert.are.equal("boom", b)
		assert.are.equal(3, c)
	end)

	it("propagates errors raised inside fn without prepending with_lock's own file/line location", function()
		local ok, err = pcall(function()
			state_store.with_lock(state_store.STATES.HYDRATION, function()
				error("boom")
			end)
		end)

		assert.is_false(ok)
		assert.is_not_nil(tostring(err):find("boom", 1, true))
		assert.is_nil(tostring(err):find("state_store.lua", 1, true))
	end)

	it("errors when state is not a valid state, never invokes fn, and leaves current_state untouched", function()
		local fn_called = false

		assert.has_error(function()
			state_store.with_lock("BOGUS", function()
				fn_called = true
			end)
		end)

		assert.is_false(fn_called)
		assert.are.equal(state_store.STATES.IDLE, state_store.get_current_state())
	end)
end)
