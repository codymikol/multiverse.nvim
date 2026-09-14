local stub = require("luassert.stub")
local json = require("multiverse.repositories.json")
local log = require("multiverse.log")

local module_name = "multiverse.profiler"

-- Reloads the profiler with vim.fn.stdpath("cache") stubbed to point at a
-- throwaway tmp directory instead of the real cache dir, so tests never read,
-- write, or delete a developer's actual multiverse_trace.json. Mirrors
-- require_uuid_manager_seeded_at in managers/uuid_manager_spec.lua: stub,
-- reload the module fresh, revert. The pcall + assert(ok, err) surfaces any
-- error raised while requiring the module instead of swallowing it.
local function require_profiler_with_cache_dir(tmp_dir)
	local original_stdpath = vim.fn.stdpath
	local stdpath_stub = stub(vim.fn, "stdpath", function(what)
		if what == "cache" then
			return tmp_dir
		end
		return original_stdpath(what)
	end)

	package.loaded[module_name] = nil
	local ok, result = pcall(require, module_name)
	stdpath_stub:revert()
	assert(ok, result)
	return result
end

local function read_trace_file(path)
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local contents = f:read("*a")
	f:close()
	return json.decode(contents)
end

describe("profiler", function()
	local previous_enable_profiling
	local tmp_dir

	before_each(function()
		previous_enable_profiling = vim.g.multiverse_enable_profiling
		vim.g.multiverse_enable_profiling = nil
		tmp_dir = vim.fn.tempname()
	end)

	after_each(function()
		vim.g.multiverse_enable_profiling = previous_enable_profiling
		package.loaded[module_name] = nil
		vim.fn.delete(tmp_dir, "rf")
	end)

	describe("start_span", function()
		it("should return nil and not call vim.loop.hrtime when profiling is disabled", function()
			local hrtime_stub = stub(vim.loop, "hrtime")

			local ok, err = pcall(function()
				local profiler = require_profiler_with_cache_dir(tmp_dir)
				-- Module load itself calls hrtime() exactly once, unconditionally,
				-- to capture origin_time -- assert that baseline here so the
				-- assertion below isolates whether start_span (while disabled)
				-- makes any *additional* call.
				assert.stub(hrtime_stub).was.called(1)

				local span = profiler.start_span("test-span")

				assert.is_nil(span)
				assert.stub(hrtime_stub).was.called(1)
			end)
			hrtime_stub:revert()
			assert(ok, err)
		end)

		it("should treat vim.g.multiverse_enable_profiling == 1 (the Vimscript-truthy form) as enabled", function()
			-- README documents `let g:multiverse_enable_profiling = 1` as a valid
			-- way to enable profiling from Vimscript, which sets the Lua number 1
			-- rather than the Lua boolean true -- is_enabled() has a dedicated
			-- `== 1` arm for exactly this case.
			vim.g.multiverse_enable_profiling = 1

			local ok, err = pcall(function()
				local profiler = require_profiler_with_cache_dir(tmp_dir)

				local span = profiler.start_span("vimscript-enabled-span")

				assert.is_not_nil(span)
			end)
			assert(ok, err)
		end)
	end)

	describe("end_span", function()
		it("should record a duration event whose dur reflects the hrtime delta in microseconds when enabled", function()
			vim.g.multiverse_enable_profiling = true

			local call_count = 0
			-- First value is consumed by the module-load origin_time capture;
			-- the remaining two are start/end for the span itself.
			local hrtime_values = { 500000, 1000000, 6000000 } -- 5,000,000ns delta => 5,000us dur
			local hrtime_stub = stub(vim.loop, "hrtime", function()
				call_count = call_count + 1
				return hrtime_values[call_count]
			end)

			local ok, err = pcall(function()
				local profiler = require_profiler_with_cache_dir(tmp_dir)
				local span = profiler.start_span("test-span")
				profiler.end_span(span)
				profiler.flush()

				local events = read_trace_file(profiler.get_trace_file())
				assert.equals(1, #events)
				assert.equals("test-span", events[1].name)
				assert.equals("X", events[1].ph)
				assert.equals(5000, events[1].dur)
			end)
			hrtime_stub:revert()
			assert(ok, err)
		end)

		it("should floor ts/dur so distinct sub-millisecond-apart spans keep distinct integer ts values at realistic hrtime magnitudes", function()
			vim.g.multiverse_enable_profiling = true

			-- Realistic ~24h-uptime hrtime magnitude with ~1ms gaps between spans
			-- -- the exact scenario that still collapses `ts` values under
			-- json_encode's ~7-significant-digit float formatting even after
			-- subtracting a per-process origin, since origin-relative values
			-- still grow unbounded over a long session and remain fractional
			-- floats. Only flooring ts/dur to integers guarantees exact
			-- round-tripping regardless of magnitude. Empirically:
			-- vim.fn.json_encode({a = 86400000123456/1000, b = 86400001123456/1000})
			-- collapses both to 8.64e10, while flooring first keeps them distinct.
			-- The first stubbed call here is consumed by the module-level
			-- `origin_time` capture at load time.
			local call_count = 0
			local hrtime_values = {
				0, -- origin_time (module load, session start)
				86400000123456, -- span-1 start (~24h into the session)
				86400000133456, -- span-1 end   (+10000ns, dur=10us)
				86400001123456, -- span-2 start (~1ms after span-1 start)
				86400001133456, -- span-2 end   (+10000ns, dur=10us)
			}
			local hrtime_stub = stub(vim.loop, "hrtime", function()
				call_count = call_count + 1
				return hrtime_values[call_count]
			end)

			local ok, err = pcall(function()
				local profiler = require_profiler_with_cache_dir(tmp_dir)
				profiler.end_span(profiler.start_span("span-1"))
				profiler.end_span(profiler.start_span("span-2"))
				profiler.flush()

				local events = read_trace_file(profiler.get_trace_file())
				assert.equals(2, #events)
				assert.are_not.equals(events[1].ts, events[2].ts)
				assert.equals(86400000123, events[1].ts)
				assert.equals(86400001123, events[2].ts)
				assert.equals(10, events[1].dur)
				assert.equals(10, events[2].dur)
			end)
			hrtime_stub:revert()
			assert(ok, err)
		end)

		it("should not error and should not add an event when passed nil", function()
			vim.g.multiverse_enable_profiling = true

			local ok, err = pcall(function()
				local profiler = require_profiler_with_cache_dir(tmp_dir)

				profiler.end_span(nil)
				profiler.flush()

				-- Asserted on the raw file content (rather than only a decoded
				-- table's #events == 0) because vim.fn.json_encode({}) yields the
				-- JSON object "{}", not the array "[]" chrome://tracing/Perfetto
				-- require as the top-level shape -- decoding both alike would
				-- hide a regression back to encoding "{}" for an empty buffer.
				local f = io.open(profiler.get_trace_file(), "r")
				local raw = f:read("*a")
				f:close()
				assert.equals("[]", raw)

				local events = read_trace_file(profiler.get_trace_file())
				assert.is_table(events)
				assert.equals(0, #events)
			end)
			assert(ok, err)
		end)

		it("should not add an event when profiling is disabled before end_span is called", function()
			local ok, err = pcall(function()
				vim.g.multiverse_enable_profiling = true
				local profiler = require_profiler_with_cache_dir(tmp_dir)
				local span = profiler.start_span("disabled-before-end")

				vim.g.multiverse_enable_profiling = false
				profiler.end_span(span)
				vim.g.multiverse_enable_profiling = true

				profiler.flush()

				local events = read_trace_file(profiler.get_trace_file())
				assert.is_table(events)
				assert.equals(0, #events)
			end)
			assert(ok, err)
		end)
	end)

	describe("flush", function()
		it("should be a no-op when profiling is disabled", function()
			local profiler = require_profiler_with_cache_dir(tmp_dir)

			profiler.flush()

			local f = io.open(profiler.get_trace_file(), "r")
			assert.is_nil(f)
		end)

		it("should write the buffered events as a JSON array to the trace file", function()
			vim.g.multiverse_enable_profiling = true

			local call_count = 0
			-- First value is consumed by the module-load origin_time capture.
			local hrtime_values = { 500000, 1000000, 2000000 }
			local hrtime_stub = stub(vim.loop, "hrtime", function()
				call_count = call_count + 1
				return hrtime_values[call_count]
			end)

			local ok, err = pcall(function()
				local profiler = require_profiler_with_cache_dir(tmp_dir)
				profiler.end_span(profiler.start_span("flush-span"))
				profiler.flush()

				-- chrome://tracing/Perfetto require a top-level JSON array.
				local f = io.open(profiler.get_trace_file(), "r")
				local raw = f:read("*a")
				f:close()
				assert.equals("[", raw:sub(1, 1))

				local events = read_trace_file(profiler.get_trace_file())
				assert.is_table(events)
				assert.is_true((vim.islist or vim.tbl_islist)(events))
				assert.equals(1, #events)
				-- The Chrome Trace Event Format contract this feature exists to
				-- satisfy, not just the fields this test happens to compute.
				assert.equals("multiverse", events[1].cat)
				assert.equals(1, events[1].pid)
				assert.equals(1, events[1].tid)
				assert.equals("flush-span", events[1].name)
			end)
			hrtime_stub:revert()
			assert(ok, err)
		end)

		it("should not raise when io.open fails and the trace file path contains a literal percent sign", function()
			local percent_tmp_dir = tmp_dir .. "%s-cache"
			local open_stub

			local ok, err = pcall(function()
				local profiler = require_profiler_with_cache_dir(percent_tmp_dir)
				vim.g.multiverse_enable_profiling = true
				profiler.end_span(profiler.start_span("percent-span"))

				open_stub = stub(io, "open", function()
					return nil
				end)

				assert.has_no.errors(function()
					profiler.flush()
				end)
			end)
			if open_stub then
				open_stub:revert()
			end
			vim.fn.delete(percent_tmp_dir, "rf")
			assert(ok, err)
		end)

		it("should not raise when vim.fn.mkdir errors (e.g. E739 on a read-only cache dir)", function()
			vim.g.multiverse_enable_profiling = true

			local hrtime_stub = stub(vim.loop, "hrtime", function()
				return 1000000
			end)

			local mkdir_stub

			local ok, err = pcall(function()
				local profiler = require_profiler_with_cache_dir(tmp_dir)
				profiler.end_span(profiler.start_span("mkdir-fails-span"))

				mkdir_stub = stub(vim.fn, "mkdir", function()
					error("boom")
				end)

				assert.has_no.errors(function()
					profiler.flush()
				end)
			end)
			if mkdir_stub then
				mkdir_stub:revert()
			end
			hrtime_stub:revert()
			assert(ok, err)
		end)

		it("should not raise when the error caught from a failed write is itself re-logged and contains a percent sign", function()
			-- Real Vim mkdir errors (e.g. E739) embed the offending path in the
			-- error text, so a percent sign in the trace file's directory makes
			-- it into `err` here too. log.error(...) passes `err` as a *vararg*
			-- substituted into a "%s" placeholder, never as the format string
			-- itself, so a percent sign inside `err` is harmless here -- this
			-- test guards that re-logging such an error doesn't itself crash
			-- log.error's string.format call.
			vim.g.multiverse_enable_profiling = true

			local hrtime_stub = stub(vim.loop, "hrtime", function()
				return 1000000
			end)

			local mkdir_stub

			local ok, err = pcall(function()
				local profiler = require_profiler_with_cache_dir(tmp_dir)
				profiler.end_span(profiler.start_span("mkdir-percent-span"))

				mkdir_stub = stub(vim.fn, "mkdir", function(path)
					error("E739: Cannot create directory: " .. path .. "%s-suffix")
				end)

				assert.has_no.errors(function()
					profiler.flush()
				end)
			end)
			if mkdir_stub then
				mkdir_stub:revert()
			end
			hrtime_stub:revert()
			assert(ok, err)
		end)

		it("should log an error when f:write fails (e.g. disk full) instead of discarding the trace silently", function()
			vim.g.multiverse_enable_profiling = true

			local hrtime_stub = stub(vim.loop, "hrtime", function()
				return 1000000
			end)

			local open_stub
			local log_error_stub = stub(log, "error")

			local ok, err = pcall(function()
				local profiler = require_profiler_with_cache_dir(tmp_dir)
				profiler.end_span(profiler.start_span("write-fails-span"))

				local fake_file = {
					write = function()
						return nil, "disk full"
					end,
					close = function()
						return true
					end,
				}
				open_stub = stub(io, "open", function()
					return fake_file
				end)

				assert.has_no.errors(function()
					profiler.flush()
				end)
			end)
			if open_stub then
				open_stub:revert()
			end
			hrtime_stub:revert()
			assert(ok, err)

			assert.stub(log_error_stub).was.called(1)
			local log_detail = log_error_stub.calls[1].refs[2]
			assert.is_not_nil(tostring(log_detail):find("disk full", 1, true))
			log_error_stub:revert()
		end)

		it("should log an error when f:close fails (e.g. disk full flushing buffered writes) instead of discarding it silently", function()
			vim.g.multiverse_enable_profiling = true

			local hrtime_stub = stub(vim.loop, "hrtime", function()
				return 1000000
			end)

			local open_stub
			local log_error_stub = stub(log, "error")

			local ok, err = pcall(function()
				local profiler = require_profiler_with_cache_dir(tmp_dir)
				profiler.end_span(profiler.start_span("close-fails-span"))

				local fake_file = {
					write = function()
						return true
					end,
					close = function()
						return nil, "disk full closing"
					end,
				}
				open_stub = stub(io, "open", function()
					return fake_file
				end)

				assert.has_no.errors(function()
					profiler.flush()
				end)
			end)
			if open_stub then
				open_stub:revert()
			end
			hrtime_stub:revert()
			assert(ok, err)

			assert.stub(log_error_stub).was.called(1)
			local log_detail = log_error_stub.calls[1].refs[2]
			assert.is_not_nil(tostring(log_detail):find("disk full closing", 1, true))
			log_error_stub:revert()
		end)
	end)

	describe("reset", function()
		it("should clear buffered events so a subsequent flush() writes an empty array", function()
			vim.g.multiverse_enable_profiling = true

			local call_count = 0
			-- First value is consumed by the module-load origin_time capture.
			local hrtime_values = { 500000, 1000000, 2000000 }
			local hrtime_stub = stub(vim.loop, "hrtime", function()
				call_count = call_count + 1
				return hrtime_values[call_count]
			end)

			local ok, err = pcall(function()
				local profiler = require_profiler_with_cache_dir(tmp_dir)
				profiler.end_span(profiler.start_span("reset-span"))
				profiler.reset()
				profiler.flush()

				local events = read_trace_file(profiler.get_trace_file())
				assert.is_table(events)
				assert.equals(0, #events)
			end)
			hrtime_stub:revert()
			assert(ok, err)
		end)
	end)

	describe("event buffer capping", function()
		it("should cap the buffered events at exactly MAX_EVENTS, dropping the oldest and retaining the newest", function()
			vim.g.multiverse_enable_profiling = true

			-- Realistic large hrtime magnitude (~8.6e14ns, as in a long-uptime
			-- host), advancing 1ms per hrtime() call, rather than a fixed tiny
			-- stub value -- exercises the ring buffer under the same magnitude
			-- that motivated flooring ts/dur to integers above.
			local base_time = 865904401234567
			local increment_ns = 1000000
			local call_count = 0
			local hrtime_stub = stub(vim.loop, "hrtime", function()
				local value = base_time + (call_count * increment_ns)
				call_count = call_count + 1
				return value
			end)

			local ok, err = pcall(function()
				local profiler = require_profiler_with_cache_dir(tmp_dir)

				for i = 1, 1200 do
					profiler.end_span(profiler.start_span("span-" .. i))
				end

				profiler.flush()

				local events = read_trace_file(profiler.get_trace_file())
				assert.is_table(events)
				assert.equals(1000, #events)
				-- Oldest 200 spans (span-1..span-200) were evicted; the newest
				-- 1000 (span-201..span-1200) were retained, in insertion order.
				assert.equals("span-201", events[1].name)
				assert.equals("span-1200", events[#events].name)
			end)
			hrtime_stub:revert()
			assert(ok, err)
		end)
	end)
end)
