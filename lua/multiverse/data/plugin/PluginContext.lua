--- Types-only module: not required anywhere; do not add one.
--- These LuaCATS annotations exist purely for editor/type tooling.

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
