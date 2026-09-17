local Leaf = {}
Leaf.__index = Leaf

local function isNonEmptyString(value)
  return type(value) == "string" and value ~= ""
end

--- @class Leaf
--- @field type string
--- @field windowUuid string
--- @field windowId number | nil

--- @param opts table
--- @param opts.windowUuid string  the uuid of the window this leaf represents
--- @param opts.windowId number|nil the neovim window id of the window this leaf represents
function Leaf:new(opts)
  opts = opts or {}
  if type(opts) ~= "table" then
    error("Leaf:new requires a table argument", 2)
  end
  if not isNonEmptyString(opts.windowUuid) then
    error("Leaf:new requires opts.windowUuid to be a non-empty string", 2)
  end

  local self = setmetatable({}, Leaf)
  self.type = "leaf"
  self.windowUuid = opts.windowUuid
  self.windowId = opts.windowId
  return self
end

return Leaf
