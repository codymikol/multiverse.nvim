local buffer_manager = require("multiverse.managers.buffer_manager")
local stub = require("luassert.stub")

--- Stubs the vim.api functions buffer_manager consults about a given buffer
--- (used by isUniverseBuffer/isDesiredUniverseBuffer/saveAll) so each test can
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

		-- Characterization, not a statement of intent: this early-return-past-buftype
		-- behavior may be an unintentional drift, see #178.
		it("should return true for a read-only buffer even though it is not a normal buffer", function()
			stubs = stubBuffer({ readonly = true, buftype = "help" })

			assert.is_true(buffer_manager.isUniverseBuffer(1))
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

	describe("saveAll", function()
		local stubs
		local tmpdir
		local original_workspaces

		before_each(function()
			tmpdir = vim.fn.tempname()
			vim.fn.mkdir(tmpdir, "p")

			-- "workspaces" is an external runtime dependency not present in the
			-- test environment; inject a fake module so saveAll's require() resolves.
			original_workspaces = package.loaded["workspaces"]
			package.loaded["workspaces"] = { name = function() return "test-workspace" end }

			local Persistance = require("multiverse.repositories.persistance")

			stubs = {}
			table.insert(stubs, stub(Persistance, "getDir").returns(tmpdir))
			table.insert(stubs, stub(vim.api, "nvim_list_bufs").returns({ 1 }))
			table.insert(stubs, stub(vim.fn, "filereadable").returns(1))
		end)

		after_each(function()
			if stubs then
				revertStubs(stubs)
				stubs = nil
			end
			package.loaded["workspaces"] = original_workspaces
			vim.fn.delete(tmpdir, "rf")
		end)

		local function savedBufferFile()
			local bufferFileLocation = tmpdir .. "/" .. vim.fn.sha256("test-workspace") .. "/buffer.txt"
			local f = io.open(bufferFileLocation, "r")
			local contents = f and f:read("*a") or nil
			if f then
				f:close()
			end
			return contents
		end

		local function stubTrackedBuffer(opts)
			-- parens truncate stubBuffer's second return (named handles); without
			-- them list_extend receives it as a numeric `start` arg and errors.
			vim.list_extend(stubs, (stubBuffer(opts)))
		end

		it("should not persist a valid, loaded but non-modifiable buffer", function()
			stubTrackedBuffer({ loaded = true, modifiable = false })

			buffer_manager.saveAll()

			local contents = savedBufferFile()
			assert.is_not_nil(contents)
			assert.are.equal("", contents)
		end)

		it("should persist a valid, loaded, modifiable buffer", function()
			stubTrackedBuffer({ loaded = true })

			buffer_manager.saveAll()

			local contents = savedBufferFile()
			assert.are.equal("/home/foo/bar.txt\n", contents)
		end)
	end)
end)
