# Plugins

Plugins hook into the dehydrate/hydrate lifecycle of a *Universe*. A plugin is registered
with `multiverse.managers.plugin_manager`'s `M.register(plugin)`, and can define any of four
lifecycle hooks: `beforeDehydrate`, `afterDehydrate`, `beforeHydrate`, and `afterHydrate`.

This doc only covers hook ordering and priority, not the full plugin registration/hook API.

## Priority

Each plugin may declare an optional numeric `priority` via the `opts` table passed to
`Plugin:new(opts)` (which forwards `priority` on to `PluginContext:new`):

```lua
local Plugin = require("multiverse.data.plugin.Plugin")

local myPlugin = Plugin:new({
	name = "my-plugin",
	priority = 50,
	beforeHydrate = function(ctx)
		-- ...
	end,
})
```

- **Lower priority numbers run earlier.**
- Plugins that don't set `priority` default to `100`.
- The built-in plugins (Neotree, Zellij, TitleSync) don't set an explicit priority, so they
  all default to `100` and run in their original relative order. A user plugin registered
  with a priority below `100` runs before all of them.
- The same relative order is used for all four lifecycle hooks — `beforeDehydrate`,
  `afterDehydrate`, `beforeHydrate`, and `afterHydrate`.

## Ordering semantics

Ordering is decided once, at registration time (`M.register`) — the hook dispatch loop simply
iterates the plugin list in whatever order it's already in.

- **Ties preserve registration order.** A newly registered plugin is placed after every
  already-registered plugin whose priority is `<=` its own, and before the first one with a
  strictly greater priority — so when priorities tie (including the default-vs-default case),
  the new plugin lands after the existing ones.
- **Re-registering a plugin keeps its slot only if its priority is unchanged.** If a
  plugin with the same `name` is already registered and the new registration has the
  same priority (e.g. overriding a built-in plugin's hooks without touching its
  priority), it swaps into the exact same slot. If the priority differs, the old
  registration is removed and the new one is inserted by its new priority, same as a
  first-time registration — so it can move.
- **A hook that registers a plugin mid-dispatch doesn't affect the in-flight dispatch.**
  Ordering is snapshotted at the start of each lifecycle call, so a newly (re-)registered
  plugin's hook starts firing on the *next* lifecycle call, not the one in progress.

## Example

```lua
-- Registered with priority 10: runs before every built-in plugin (priority 100).
plugin_manager.register(Plugin:new({
	name = "early-plugin",
	priority = 10,
	beforeDehydrate = function(ctx)
		-- ...
	end,
}))

-- No priority set: defaults to 100, runs after early-plugin but alongside (and after,
-- due to registration order) the built-in plugins.
plugin_manager.register(Plugin:new({
	name = "default-priority-plugin",
	afterHydrate = function(ctx)
		-- ...
	end,
}))
```
