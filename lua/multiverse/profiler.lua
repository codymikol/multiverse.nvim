local json = require("multiverse.repositories.json")
local log = require("multiverse.log")

local M = {}

local trace_file = vim.fn.stdpath("cache") .. "/multiverse_trace.json"

local events = {}

-- Bounds memory growth and per-flush JSON-encode cost for the life of the
-- nvim session, since nothing on the production save/load path ever calls
-- M.reset() to clear the buffer (see M.end_span below).
local MAX_EVENTS = 1000

-- vim.loop.hrtime() is an absolute, arbitrary-origin nanosecond counter, so
-- its raw magnitude can be too large for json_encode to round-trip exactly.
-- Capturing the origin here bounds `ts`'s magnitude to session length (also
-- matches the Chrome Trace Event Format convention of starting near ts: 0).
local origin_time = vim.loop.hrtime()

local function is_enabled()
	return vim.g.multiverse_enable_profiling == true or vim.g.multiverse_enable_profiling == 1
end

function M.get_trace_file()
	return trace_file
end

function M.start_span(name)
	if not is_enabled() then
		return nil
	end

	return {
		name = name,
		start_time = vim.loop.hrtime(),
	}
end

function M.end_span(span)
	if span == nil or not is_enabled() then
		return
	end

	-- Chrome Trace Event Format wants ts/dur in microseconds; hrtime deltas
	-- are nanoseconds, so divide by 1000. math.floor to an integer is what
	-- guarantees vim.fn.json_encode round-trips the value exactly (see the
	-- origin_time comment above) -- without it these remain fractional
	-- floats that lose precision at realistic session lengths.
	local end_time = vim.loop.hrtime()
	table.insert(events, {
		name = span.name,
		cat = "multiverse",
		ph = "X",
		ts = math.floor((span.start_time - origin_time) / 1000),
		dur = math.floor((end_time - span.start_time) / 1000),
		pid = 1,
		tid = 1,
	})

	if #events > MAX_EVENTS then
		table.remove(events, 1)
	end
end

function M.flush()
	if not is_enabled() then
		return
	end

	-- Wrapped in pcall so profiling can never break a caller's control flow:
	-- vim.fn.mkdir raises a hard Vim error (e.g. E739) rather than returning
	-- falsy when the cache dir can't be created (read-only HOME, etc.).
	local ok, err = pcall(function()
		-- The directory holding trace_file is not guaranteed to exist yet
		-- (e.g. headless test runs before nvim has ever written to the cache
		-- dir). Derived from trace_file itself (rather than re-querying
		-- vim.fn.stdpath("cache")) so this always targets the same directory
		-- trace_file was resolved against at module load time.
		vim.fn.mkdir(vim.fn.fnamemodify(trace_file, ":h"), "p")

		local f = io.open(trace_file, "w")
		if not f then
			log.error("Failed to open trace file: %s", trace_file)
			return
		end

		-- Nested so a raise from encode/write still leaves f:close() run below,
		-- rather than leaking the file handle (io.open("w") already truncated
		-- the file before this point, so there's no truncation left to guard
		-- against here).
		local write_ok, write_err = pcall(function()
			-- An empty Lua table is ambiguous between a JSON object and array;
			-- spelling out "[]" guarantees the array shape chrome://tracing and
			-- Perfetto require as the top-level trace shape, regardless of how
			-- the encoder resolves that ambiguity for an empty buffer. Encoding
			-- here (inside the pcall) so a raise from json.encode still leaves
			-- f:close() run below, matching the write-failure handling.
			local encoded = #events == 0 and "[]" or json.encode(events)

			local wok, werr = f:write(encoded)
			if not wok then
				error(werr)
			end
		end)
		if not write_ok then
			log.error("Error writing profiler trace: %s", write_err)
		end

		-- f:write() can succeed while data is only buffered in libc, not yet on
		-- disk -- the subsequent f:close() is what can surface a disk-full (or
		-- similar) failure, so its return value must be checked too rather than
		-- discarded.
		local close_ok, close_err = f:close()
		if not close_ok then
			log.error("Error closing profiler trace file: %s", close_err)
		end
	end)

	if not ok then
		log.error("Error flushing profiler trace: %s", err)
	end
end

function M.reset()
	events = {}
end

return M
