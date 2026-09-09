-- Stub out the telescope.nvim third-party modules required at the top of
-- integrations/telescope.lua so that the real module can be required
-- without telescope.nvim being installed.
package.loaded["telescope.actions"] = {}
package.loaded["telescope.pickers"] = {}
package.loaded["telescope.finders"] = {}
package.loaded["telescope.sorters"] = {}
package.loaded["telescope.previewers"] = {}
package.loaded["telescope.actions.state"] = {}
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

describe("telescope.get_universe_preview", function()
	local telescope
	local getUniverseByUuid_stub

	before_each(function()
		package.loaded["integrations.telescope"] = nil
		telescope = require("integrations.telescope")
	end)

	after_each(function()
		if getUniverseByUuid_stub then
			getUniverseByUuid_stub:revert()
			getUniverseByUuid_stub = nil
		end
		package.loaded["integrations.telescope"] = nil
	end)

	it("does not truncate the preview when an earlier tabpage has an empty layout", function()
		-- Tabpage 1: empty layout (the edge case that triggers the bug)
		local emptyLayout = WindowLayout:new()
		local tabpage1 = Tabpage:new("tabpage-1-uuid", 1, "window-1-uuid")
		tabpage1:setLayout(emptyLayout)

		-- Tabpage 2: normal layout with a single leaf window, plus one
		-- buffer that isn't shown in any layout leaf.
		local window = Window:new("window-2-uuid", "buffer-1-uuid", 2)
		local tabpage2 = Tabpage:new("tabpage-2-uuid", 2, "window-2-uuid")
		tabpage2:addWindow(window)

		local layout2 = WindowLayout:new()
		local row = Row:new()
		local leaf = Leaf:new("window-2-uuid", 2)
		row:addChild(leaf)
		layout2:addChild(row)
		tabpage2:setLayout(layout2)

		local shownBuffer = Buffer:new("buffer-1-uuid", 1, "/home/test/shown.lua")
		local hiddenBuffer = Buffer:new("buffer-2-uuid", 2, "/home/test/hidden.lua")

		local universe = Universe:new("universe-uuid", "test-universe", "/home/test")
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
