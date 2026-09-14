-- Shared helpers for the window_layout_manager `*.headless.lua` regression
-- scripts (not busted specs; see each script's header for why).

local M = {}

function M.make_buf(name)
  local b = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(b, name)
  vim.api.nvim_set_option_value("buftype", "", { buf = b })
  vim.api.nvim_set_option_value("modifiable", true, { buf = b })
  vim.api.nvim_set_option_value("buflisted", true, { buf = b })
  return b
end

-- Recursively walks a vim.fn.winlayout() tree, replacing each leaf's raw
-- window id with that window's buffer name, so two layouts captured at
-- different points in time (with different window ids) can be compared for
-- structural/order equality via vim.deep_equal.
function M.layout_by_bufname(node)
  local kind = node[1]
  if kind == "leaf" then
    local winid = node[2]
    return vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(winid))
  end

  local children = {}
  for i, child in ipairs(node[2]) do
    children[i] = M.layout_by_bufname(child)
  end
  return { kind, children }
end

return M
