local buffer_manager = require("multiverse.managers.buffer_manager")
local stub = require("luassert.stub")

--- Stubs the vim.api functions buffer_manager consults about a given buffer
--- (used by isUniverseBuffer/isDesiredUniverseBuffer) so each test can
--- describe the buffer under test via a small options table.
--- @param opts table|nil
--- @return table stubs to be reverted in after_each
--- @return table named handles to individual stubs (currently just `loaded`, when opts.loaded is set)
local function stubBuffer(opts)
	opts = opts or {}

	local valid = opts.valid ~= false
	local modifiable = opts.modifiable ~= false
	local readonly = opts.readonly or false
	local buftype = opts.buftype or ""
	local buflisted = opts.buflisted ~= false
	local name = opts.name
	if name == nil then name = "/home/foo/bar.txt" end

	local stubs = {}

	local nvim_buf_is_valid = stub(vim.api, "nvim_buf_is_valid")
	nvim_buf_is_valid.returns(valid)
	table.insert(stubs, nvim_buf_is_valid)

	local nvim_get_option_value = stub(vim.api, "nvim_get_option_value")
	nvim_get_option_value.invokes(function(option, _)
		if option == "modifiable" then
			return modifiable
		elseif option == "readonly" then
			return readonly
		elseif option == "buftype" then
			return buftype
		elseif option == "buflisted" then
			return buflisted
		end
		error("stubBuffer: unstubbed option " .. vim.inspect(option))
	end)
	table.insert(stubs, nvim_get_option_value)

	local nvim_buf_get_name = stub(vim.api, "nvim_buf_get_name")
	nvim_buf_get_name.returns(name)
	table.insert(stubs, nvim_buf_get_name)

	local named = {}
	if opts.loaded ~= nil then
		local nvim_buf_is_loaded = stub(vim.api, "nvim_buf_is_loaded")
		nvim_buf_is_loaded.returns(opts.loaded)
		table.insert(stubs, nvim_buf_is_loaded)
		named.loaded = nvim_buf_is_loaded
	end

	return stubs, named
end

local function revertStubs(stubs)
	for _, s in ipairs(stubs) do
		s:revert()
	end
end

describe("buffer_manager", function()
	describe("isUniverseBuffer", function()
		local stubs

		after_each(function()
			if stubs then
				revertStubs(stubs)
				stubs = nil
			end
		end)

		it("should return true for a valid, modifiable, normal, listed, non-scratch buffer", function()
			stubs = stubBuffer()

			assert.is_true(buffer_manager.isUniverseBuffer(1))
		end)

		it("should return false for an invalid buffer id", function()
			stubs = stubBuffer({ valid = false })

			assert.is_false(buffer_manager.isUniverseBuffer(1))
		end)

		it("should return false for a non-modifiable buffer", function()
			stubs = stubBuffer({ modifiable = false })

			assert.is_false(buffer_manager.isUniverseBuffer(1))
		end)

		it("should return false for a read-only buffer that is also not a normal buffer", function()
			stubs = stubBuffer({ readonly = true, buftype = "help" })

			assert.is_false(buffer_manager.isUniverseBuffer(1))
		end)

		it("should return false for a read-only buffer with a normal buftype", function()
			stubs = stubBuffer({ readonly = true })

			assert.is_false(buffer_manager.isUniverseBuffer(1))
		end)

		it("should return false for a non-normal buffer that is not read-only", function()
			stubs = stubBuffer({ buftype = "help" })

			assert.is_false(buffer_manager.isUniverseBuffer(1))
		end)

		it("should return false for an unlisted buffer", function()
			stubs = stubBuffer({ buflisted = false })

			assert.is_false(buffer_manager.isUniverseBuffer(1))
		end)

		it("should return false for a scratch buffer with an empty name", function()
			stubs = stubBuffer({ name = "" })

			assert.is_false(buffer_manager.isUniverseBuffer(1))
		end)

		it("should return true for an unloaded but otherwise valid, modifiable, normal, listed, non-scratch buffer", function()
			-- buffers can be unloaded but still a part of the universe (see comment in
			-- isDesiredUniverseBuffer); explicitly stub nvim_buf_is_loaded to return
			-- false and assert it is never consulted.
			local named
			stubs, named = stubBuffer({ loaded = false })

			assert.is_true(buffer_manager.isUniverseBuffer(1))
			assert.stub(named.loaded).was_not_called()
		end)
	end)

	describe("hydrateBuffersForUniverse", function()
		local created_buffers

		after_each(function()
			for _, bufnr in ipairs(created_buffers or {}) do
				pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
			end
			created_buffers = nil
		end)

		--- Hydrates a universe with a single buffer named `name` and returns the
		--- resulting bufferId, registering it for cleanup in after_each.
		--- @param name string
		--- @return number
		local function hydrateOneBuffer(name)
			local universe = { uuid = "some-uuid", buffers = { { bufferName = name, bufferId = nil } } }

			buffer_manager.hydrateBuffersForUniverse(universe)

			local bufnr = universe.buffers[1].bufferId
			created_buffers = created_buffers or {}
			table.insert(created_buffers, bufnr)
			return bufnr
		end

		it("adds a listed buffer for a normal bufferName and records its id", function()
			local name = "/tmp/buffer_manager_spec_normal.txt"

			local bufnr = hydrateOneBuffer(name)

			assert.are.equal(name, vim.api.nvim_buf_get_name(bufnr))
			assert.is_true(vim.api.nvim_get_option_value("buflisted", { buf = bufnr }))
		end)

		local pwned_marker = vim.fn.tempname()
		local bar_name = "/tmp/buffer_manager_spec_evil.txt | lua buffer_manager_spec_pwned = true"
		local backtick_name = "/tmp/buffer_manager_spec_evil_`touch " .. pwned_marker .. "`.txt"

		describe("names containing ex-command or filename-expansion special characters", function()
			-- Excludes a raw "%" sigil: log.debug's string.format(message) call
			-- (lua/multiverse/log.lua:16) treats any "%" in the logged buffer name
			-- as a format spec and errors before hydrateBuffersForUniverse ever
			-- reaches :badd, on main as well as this branch. That's a pre-existing,
			-- unrelated bug tracked as #290, not the ex-command/filename-expansion
			-- issue in scope here.
			local cases = {
				{ desc = "a bar ex-command separator", name = bar_name },
				{ desc = "a backtick shell-expansion sequence", name = backtick_name },
				{ desc = "a hash alternate-file sigil", name = "/tmp/buffer_manager_spec_evil#1.txt" },
				{ desc = "a dollar environment-variable sigil", name = "/tmp/buffer_manager_spec_evil_$HOME.txt" },
			}

			for _, case in ipairs(cases) do
				it("adds a buffer literally named after " .. case.desc .. ", without expanding it", function()
					local bufnr = hydrateOneBuffer(case.name)

					assert.are.equal(case.name, vim.api.nvim_buf_get_name(bufnr))
					assert.is_true(vim.api.nvim_get_option_value("buflisted", { buf = bufnr }))
				end)
			end
		end)

		it("does not run a shell command embedded in a backticked bufferName", function()
			os.remove(pwned_marker)

			hydrateOneBuffer(backtick_name)

			assert.is_nil(io.open(pwned_marker, "r"))
		end)

		it("does not run an ex command embedded after a bar in a bufferName", function()
			_G.buffer_manager_spec_pwned = false

			hydrateOneBuffer(bar_name)

			local ran = _G.buffer_manager_spec_pwned
			_G.buffer_manager_spec_pwned = nil
			assert.is_false(ran)
		end)

		it("does not add a buffer for an empty or nil bufferName (scratch buffer)", function()
			local buffers_before = #vim.api.nvim_list_bufs()
			local universe = {
				uuid = "some-uuid",
				buffers = {
					{ bufferName = "", bufferId = 1 },
					{ bufferName = nil, bufferId = 2 },
				},
			}

			buffer_manager.hydrateBuffersForUniverse(universe)

			assert.are.equal(buffers_before, #vim.api.nvim_list_bufs())
			assert.are.equal(1, universe.buffers[1].bufferId)
			assert.are.equal(2, universe.buffers[2].bufferId)
		end)
	end)

	describe("exports", function()
		it("should not expose a closeAll function", function()
			assert.is_nil(buffer_manager.closeAll)
		end)

		it("should not expose a saveAll function", function()
			assert.is_nil(buffer_manager.saveAll)
		end)

		it("should not expose a hydrate function", function()
			assert.is_nil(buffer_manager.hydrate)
		end)

		it("should still expose isUniverseBuffer as a function", function()
			assert.are.equal("function", type(buffer_manager.isUniverseBuffer))
		end)

		it("should still expose closeAllBuffers as a function", function()
			assert.are.equal("function", type(buffer_manager.closeAllBuffers))
		end)

		it("should still expose hydrateBuffersForUniverse as a function", function()
			assert.are.equal("function", type(buffer_manager.hydrateBuffersForUniverse))
		end)

		it("should still expose get_all_buffers as a function", function()
			assert.are.equal("function", type(buffer_manager.get_all_buffers))
		end)

		it("should still expose close_generated_nofile_scratch_buffers as a function", function()
			assert.are.equal("function", type(buffer_manager.close_generated_nofile_scratch_buffers))
		end)
	end)
end)
