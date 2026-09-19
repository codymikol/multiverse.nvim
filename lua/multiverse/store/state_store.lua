
local M = {}

M.STATES = {
  DEHYDRATION = "DEHYDRATION",
  CLEANUP = "CLEANUP",
  HYDRATION = "HYDRATION",
  IDLE = "IDLE",
}

local current_state = M.STATES.IDLE

--- @param state string
local function validate_state(state)
  if not vim.tbl_contains(vim.tbl_values(M.STATES), state) then
    error("Invalid state: " .. tostring(state))
  end
end

--- Packs a variable number of results, including any leading nils, into a
--- table with an explicit `n` count so callers can safely `unpack` them
--- without relying on the `#` operator (which stops at nil holes).
--- @param ... any
--- @return table
local function pack(...)
  return { n = select("#", ...), ... }
end

M.get_current_state = function()
  return current_state
end

M.set_current_state = function(state)
  validate_state(state)
  current_state = state
end

M.try_transition = function(from, to)
  validate_state(from)
  validate_state(to)

  if current_state ~= from then
    return false
  end

  current_state = to
  return true
end

--- Runs `fn` with the store transitioned to `state`, restoring the prior
--- state afterward unless `fn` (or something it triggered) has already
--- moved the state away from `state` itself, in which case that change is
--- left alone rather than clobbered.
--- @param state string
--- @param fn fun(): ...
--- @return ... whatever fn returns (including leading nils), re-raises any error fn raises
M.with_lock = function(state, fn)
  local prior_state = current_state
  M.set_current_state(state)

  local results = pack(pcall(fn))
  local ok = results[1]

  if current_state == state then
    current_state = prior_state
  end

  if not ok then
    error(results[2], 0)
  end

  return unpack(results, 2, results.n)
end

return M
