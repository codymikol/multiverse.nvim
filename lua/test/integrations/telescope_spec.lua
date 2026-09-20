-- Stub every telescope submodule required at the top of
-- integrations/telescope.lua so that the real module can be required
-- without telescope.nvim being installed, and so prompt_select_universe's
-- picker/sorter/previewer wiring can be exercised directly.
package.loaded["telescope.actions"] = {
	select_default = { replace = function() end },
	close = function() end,
}

package.loaded["telescope.pickers"] = {
	new = function(_, opts)
		return {
			find = function() end,
			_opts = opts,
		}
	end,
}

package.loaded["telescope.finders"] = {
	new_table = function(opts)
		return opts
	end,
}

local fake_fuzzy_sorter = {
	scoring_function = function(_, prompt, _display, entry)
		if prompt == "nomatch" then
			return -1
		end
		-- Derive a score from the entry so tests can distinguish which entry
		-- was passed through, proving exact pass-through rather than just
		-- "not -1".
		return (entry and entry.value and entry.value.fuzzyRank) or 0
	end,
	highlighter = function(_, prompt, display)
		return "fake-highlight:" .. prompt .. ":" .. display
	end,
}

package.loaded["telescope.sorters"] = {
	get_generic_fuzzy_sorter = function()
		return fake_fuzzy_sorter
	end,
	Sorter = {
		new = function(_, opts)
			return opts
		end,
	},
}

package.loaded["telescope.previewers"] = {
	new_buffer_previewer = function(opts)
		return opts
	end,
}

package.loaded["telescope.actions.state"] = {
	get_selected_entry = function() end,
}

package.loaded["telescope.previewers.utils"] = {}

local stub = require("luassert.stub")

local WindowLayout = require("multiverse.data.layout.WindowLayout")
local Row = require("multiverse.data.layout.Row")
local Leaf = require("multiverse.data.layout.Leaf")
local Universe = require("multiverse.data.Universe")
local Tabpage = require("multiverse.data.Tabpage")
local Window = require("multiverse.data.Window")
local Buffer = require("multiverse.data.Buffer")

local universe_repository = require("multiverse.repositories.universe_repository")
local log = require("multiverse.log")

local telescope_integration = require("integrations.telescope")

local last_pickers_opts

local function captureLastPickerOpts()
	local pickers = package.loaded["telescope.pickers"]
	local original_new = pickers.new
	pickers.new = function(_, opts)
		last_pickers_opts = opts
		return original_new(_, opts)
	end
end

captureLastPickerOpts()

describe("telescope.get_universe_preview", function()
	local telescope
	local getUniverseByUuid_stub
	local notify_stub
	local log_error_stub

	before_each(function()
		package.loaded["integrations.telescope"] = nil
		telescope = require("integrations.telescope")
	end)

	after_each(function()
		if getUniverseByUuid_stub then
			getUniverseByUuid_stub:revert()
			getUniverseByUuid_stub = nil
		end
		if notify_stub then
			notify_stub:revert()
			notify_stub = nil
		end
		if log_error_stub then
			log_error_stub:revert()
			log_error_stub = nil
		end
		package.loaded["integrations.telescope"] = nil
	end)

	it("does not concatenate the raw error into the user-facing notify, and logs the detail", function()
		getUniverseByUuid_stub = stub(universe_repository, "get_universe_by_uuid")
		getUniverseByUuid_stub.returns(nil, "boom: something exploded")

		notify_stub = stub(vim, "notify")
		log_error_stub = stub(log, "error")

		local universe_summary = {
			uuid = "universe-uuid",
			name = "test-universe",
			directory = "/home/test",
			lastExplored = os.time(),
		}

		telescope.get_universe_preview(universe_summary)

		assert.stub(notify_stub).was.called_with(
			"Error fetching universe for preview, check MultiverseLog for more information",
			vim.log.levels.ERROR
		)

		assert.stub(log_error_stub).was.called_with(
			"Error fetching universe preview: %s",
			"boom: something exploded"
		)
	end)

	it("does not truncate the preview when an earlier tabpage has an empty layout", function()
		-- Tabpage 1: empty layout (the edge case that triggers the bug)
		local emptyLayout = WindowLayout:new()
		local tabpage1 = Tabpage:new("tabpage-1-uuid", 1, "window-1-uuid")
		tabpage1:setLayout(emptyLayout)

		-- Tabpage 2: normal layout with a single leaf window, plus one
		-- buffer that isn't shown in any layout leaf.
		local window = Window:new({ uuid = "window-2-uuid", bufferUuid = "buffer-1-uuid", windowId = 2 })
		local tabpage2 = Tabpage:new("tabpage-2-uuid", 2, "window-2-uuid")
		tabpage2:addWindow(window)

		local layout2 = WindowLayout:new()
		local row = Row:new()
		local leaf = Leaf:new({ windowUuid = "window-2-uuid", windowId = 2 })
		row:addChild(leaf)
		layout2:addChild(row)
		tabpage2:setLayout(layout2)

		local shownBuffer = Buffer:new("buffer-1-uuid", 1, "/home/test/shown.lua")
		local hiddenBuffer = Buffer:new("buffer-2-uuid", 2, "/home/test/hidden.lua")

		local universe = Universe:new({ uuid = "universe-uuid", name = "test-universe", workingDirectory = "/home/test" })
		universe:addTabpage(tabpage1)
		universe:addTabpage(tabpage2)
		universe:addBuffer(shownBuffer)
		universe:addBuffer(hiddenBuffer)

		getUniverseByUuid_stub = stub(universe_repository, "get_universe_by_uuid")
		getUniverseByUuid_stub.returns(universe, nil)

		local universe_summary = {
			uuid = "universe-uuid",
			name = "test-universe",
			directory = "/home/test",
			lastExplored = os.time(),
		}

		local lines = telescope.get_universe_preview(universe_summary)

		local found_tabpage_2 = false
		local found_shown_buffer = false
		local not_displayed_section_index = nil

		for idx, line in ipairs(lines) do
			if line == "tabpage 2" then
				found_tabpage_2 = true
			end
			if line:match("shown%.lua") then
				found_shown_buffer = true
			end
			if line == "buffers not displayed in layout:" then
				not_displayed_section_index = idx
			end
		end

		assert.is_true(found_tabpage_2, "expected preview lines to include 'tabpage 2', got: " .. vim.inspect(lines))
		assert.is_true(
			found_shown_buffer,
			"expected preview lines to include tabpage 2's rendered window line, got: " .. vim.inspect(lines)
		)
		assert.is_not_nil(
			not_displayed_section_index,
			"expected the 'buffers not displayed in layout:' section to run, got: " .. vim.inspect(lines)
		)

		local not_displayed_lines = {}
		for idx = not_displayed_section_index + 1, #lines do
			table.insert(not_displayed_lines, lines[idx])
		end

		assert.same({ "", "hidden.lua" }, not_displayed_lines)
	end)
end)

describe("integrations.telescope.prompt_select_universe sorter", function()
	local sorter

	before_each(function()
		last_pickers_opts = nil
		telescope_integration.prompt_select_universe({}, function() end)
		sorter = last_pickers_opts.sorter
	end)

	it("sorts entries by lastExplored descending", function()
		local score_recent = sorter.scoring_function(sorter, "", "somedisplay", { value = { lastExplored = 200 } })
		local score_older = sorter.scoring_function(sorter, "", "somedisplay", { value = { lastExplored = 50 } })

		assert.is_true(score_recent < score_older)
	end)

	it("does not collide with telescope's -1 discard sentinel when lastExplored == 1", function()
		local score_one = sorter.scoring_function(sorter, "", "somedisplay", { value = { lastExplored = 1 } })
		local score_recent = sorter.scoring_function(sorter, "", "somedisplay", { value = { lastExplored = 200 } })

		assert.is_not.equal(-1, score_one)
		assert.is_true(score_recent < score_one)
	end)

	it("still discards non-matching entries when the underlying fuzzy sorter reports no match", function()
		local score = sorter.scoring_function(sorter, "nomatch", "somedisplay", { value = { lastExplored = 1 } })

		assert.are.equal(-1, score)
	end)

	it("treats nil or non-numeric lastExplored as 0, without erroring", function()
		local score_nil = sorter.scoring_function(sorter, "", "somedisplay", { value = { lastExplored = nil } })
		local score_garbage =
			sorter.scoring_function(sorter, "", "somedisplay", { value = { lastExplored = "garbage" } })
		local score_numeric = sorter.scoring_function(sorter, "", "somedisplay", { value = { lastExplored = 5 } })

		assert.are.equal(score_garbage, score_nil)
		assert.is_true(score_numeric < score_nil)
		assert.is_true(score_numeric < score_garbage)
	end)

	it("delegates entirely to the fuzzy sorter for a non-empty prompt", function()
		local entry = { value = { lastExplored = 1, fuzzyRank = 42 } }

		local actual = sorter.scoring_function(sorter, "abc", "somedisplay", entry)
		local expected = fake_fuzzy_sorter.scoring_function(fake_fuzzy_sorter, "abc", "somedisplay", entry)

		assert.are.equal(expected, actual)
	end)

	it("delegates entirely to the fuzzy sorter's highlighter", function()
		assert.are.equal(
			fake_fuzzy_sorter.highlighter(fake_fuzzy_sorter, "abc", "display"),
			sorter.highlighter(sorter, "abc", "display")
		)
	end)

	it("does not collide with telescope's -1 discard sentinel when lastExplored is negative", function()
		local score_negative = sorter.scoring_function(sorter, "", "somedisplay", { value = { lastExplored = -2 } })
		local score_recent = sorter.scoring_function(sorter, "", "somedisplay", { value = { lastExplored = 200 } })

		assert.is_not.equal(-1, score_negative)
		assert.is_true(score_recent < score_negative)
	end)

	it("does not produce NaN when lastExplored is NaN", function()
		local score_nan = sorter.scoring_function(sorter, "", "somedisplay", { value = { lastExplored = 0 / 0 } })
		local score_recent = sorter.scoring_function(sorter, "", "somedisplay", { value = { lastExplored = 200 } })

		assert.is_true(score_nan == score_nan)
		assert.is_true(score_recent < score_nan)
	end)
end)

describe("integrations.telescope.prompt_select_universe preview", function()
	it("does not error building the preview when lastExplored is nil", function()
		last_pickers_opts = nil
		telescope_integration.prompt_select_universe({}, function() end)

		local bufnr = vim.api.nvim_create_buf(false, true)
		local entry = { value = { name = "u", directory = "/tmp", uuid = "abc", lastExplored = nil } }

		assert.has_no.errors(function()
			last_pickers_opts.previewer.define_preview({ state = { bufnr = bufnr } }, entry, {})
		end)
	end)
end)
