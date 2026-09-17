local timestamp_manager = require("multiverse.managers.timestamp_manager")

local UniverseSummary = {}
UniverseSummary.__index = UniverseSummary

local function isNonEmptyString(value)
  return type(value) == "string" and value ~= ""
end

--- @class UniverseSummary
--- @field directory string
--- @field uuid string
--- @field name string
--- @field lastExplored number|nil
---
--- @param opts table
--- @param opts.directory string  the directory of the universe
--- @param opts.uuid string  a unique identifier for the universe
--- @param opts.name string  the name of the universe
--- @param opts.lastExplored number|nil the last time the universe was explored
function UniverseSummary:new(opts)
  opts = opts or {}
  if type(opts) ~= "table" then
    error("UniverseSummary:new requires a table argument", 2)
  end
  if not isNonEmptyString(opts.directory) then
    error("UniverseSummary:new requires opts.directory to be a non-empty string", 2)
  end
  if not isNonEmptyString(opts.uuid) then
    error("UniverseSummary:new requires opts.uuid to be a non-empty string", 2)
  end
  if not isNonEmptyString(opts.name) then
    error("UniverseSummary:new requires opts.name to be a non-empty string", 2)
  end

  local self = setmetatable({}, UniverseSummary)
  self.directory = opts.directory
  self.uuid = opts.uuid
  self.name = opts.name
  self.lastExplored = opts.lastExplored
  return self
end

--- Sets lastExplored to the current timestamp.
--- @return UniverseSummary self
function UniverseSummary:setLastExploredToNow()
  self.lastExplored = timestamp_manager.now()
  return self
end

return UniverseSummary
