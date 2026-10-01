local M = {}

-- statusline/titlestring/winbar all expand '%' items (e.g. '%{expr}' evaluates
-- expr), and single-byte ASCII control characters (C0 0x00-0x1F plus DEL
-- 0x7F) can corrupt rendering or reach the terminal unfiltered — both must be
-- stripped from a user-supplied Universe name before it is rendered. Bytes
-- >= 0x80 are left untouched: in a UTF-8 context they only ever occur as
-- parts of multi-byte sequences, never as standalone control codes.
M.sanitize = function(value)
  local without_control_bytes = value:gsub("[%z\1-\31\127]", "")
  return (without_control_bytes:gsub("%%", "%%%%"))
end

return M
