local log = require("multiverse.log")

local PluginContext = {}
PluginContext.__index = PluginContext

local function isNonEmptyString(value)
	return type(value) == "string" and value ~= ""
end

local HOOK_FIELDS = {
	"beforeDehydrate",
	"afterDehydrate",
	"beforeHydrate",
	"afterHydrate",
}

--- @class BeforeDehydrateContext
--- @field universe Universe

--- @class AfterDehydrateContext
--- @field universe Universe

--- @class BeforeHydrateContext
--- @field universe Universe

--- @class AfterHydrateContext
--- @field universe Universe

--- @class PluginContext
--- @field name string
--- @field beforeDehydrate? fun(BeforeDehydrateContext): nil
--- @field afterDehydrate? fun(AfterDehydrateContext): nil
--- @field beforeHydrate? fun(BeforeHydrateContext): nil
--- @field afterHydrate? fun(AfterHydrateContext): nil

--- @param opts table
--- @return PluginContext|nil
function PluginContext:new(opts)
	if type(opts) ~= "table" then
		log.warn("PluginContext opts was not a table, got: %s", type(opts))
		opts = {}
	end

	if not isNonEmptyString(opts.name) then
		log.warn("PluginContext was missing a valid name, got: %s", opts.name)
		return nil
	end

	local self = setmetatable({}, PluginContext)
	self.name = opts.name

	for _, field in ipairs(HOOK_FIELDS) do
		local value = opts[field]
		if value ~= nil then
			if type(value) == "function" then
				self[field] = value
			else
				log.warn("PluginContext hook %s was not a function, got: %s", field, value)
			end
		end
	end

	return self
end

return PluginContext
