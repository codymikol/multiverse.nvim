-- Stub every telescope submodule (and universe_repository) before requiring
-- integrations.telescope, since telescope.nvim is not vendored/installed in
-- CI and the real modules would fail to load.
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

package.loaded["multiverse.repositories.universe_repository"] = {
	getUniverseByUuid = function() end,
}

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
