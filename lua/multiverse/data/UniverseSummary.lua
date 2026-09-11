local timestamp_manager = require("multiverse.managers.timestamp_manager")

local UniverseSummary = {}
UniverseSummary.__index = UniverseSummary

--- @class UniverseSummary
--- @field directory string
--- @field uuid string
--- @field name string
--- @field lastExplored number
---
--- @param opts table
--- @param opts.directory string  the directory of the universe
--- @param opts.uuid string  a unique identifier for the universe
--- @param opts.name string  the name of the universe
--- @param opts.lastExplored number|nil the last time the universe was explored
function UniverseSummary:new(opts)
  opts = opts or {}
  if not opts.directory then
    error("UniverseSummary:new requires opts.directory")
  end
  if not opts.uuid then
    error("UniverseSummary:new requires opts.uuid")
  end
  if not opts.name then
    error("UniverseSummary:new requires opts.name")
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
