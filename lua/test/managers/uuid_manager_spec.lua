local stub = require("luassert.stub")

-- Reloads uuid_manager with vim.loop.hrtime() stubbed to hrtime_value, simulating
-- a fresh process load seeded at that instant. math's PRNG is reset to the same
-- fixed point first so any output difference between two calls comes only from
-- the module's own seeding, not state left over by an earlier call.
local function require_uuid_manager_seeded_at(hrtime_value)
	math.randomseed(0)
	local hrtime_stub = stub(vim.loop, "hrtime", function()
		return hrtime_value
	end)
	package.loaded["multiverse.managers.uuid_manager"] = nil
	local ok, result = pcall(require, "multiverse.managers.uuid_manager")
	hrtime_stub:revert()
	assert(ok, result)
	return result
end

describe("uuid_manager", function()
	it("should produce different uuids when the hrtime seed differs across process loads", function()
		local uuid1 = require_uuid_manager_seeded_at(111111).create()
		local uuid2 = require_uuid_manager_seeded_at(222222).create()

		assert.are_not.equal(uuid1, uuid2)
	end)

	it("should not reseed on every create() call", function()
		local uuid_manager = require_uuid_manager_seeded_at(111111)
		local randomseed_stub = stub(math, "randomseed")

		local ok, err = pcall(function()
			uuid_manager.create()
			uuid_manager.create()

			assert.stub(randomseed_stub).was_not_called()
		end)
		randomseed_stub:revert()
		assert(ok, err)
	end)
end)
