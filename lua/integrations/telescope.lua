local M = {}

local actions = require('telescope.actions')
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local sorters = require('telescope.sorters')
local action_state = require('telescope.actions.state')

---@param universe_summaries UniverseSummary[]
---@param callback fun(selected_universe: UniverseSummary | nil)
---@return nil
M.prompt_select_universe = function(universe_summaries, callback)

  pickers.new({}, {
    prompt_title = 'Universes',
    finder = finders.new_table {
      results = universe_summaries,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.name,
          ordinal = entry.lastExplored,
        }
      end,
    },
    sorter = sorters.get_fzy_sorter(), -- todo(mikol): this should sort by LRU
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        callback(selection.value)
      end)
      return true
    end,
  }):find()

end

return M
