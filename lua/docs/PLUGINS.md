# Plugin code placement

A **plugin** here means a `Plugin:new({...})` object with lifecycle hooks
(`beforeDehydrate`, `afterHydrate`, etc.) registered in
`lua/multiverse/managers/plugin_manager.lua`. This is narrower than
`lua/integrations/`, which holds thin third-party-tool helpers (e.g.
telescope, neo-tree pickers) called directly by core usecases and managers
and is not subject to this rule.

All plugin-specific code must live under `lua/plugins/`. Core multiverse
logic in `lua/multiverse/` must not host plugin-specific logic.

A plugin may be structured as:

- **A single `.lua` file** — for self-contained plugins with no extra
  helper modules. See `lua/plugins/copilot_chat_plugin.lua`,
  `lua/plugins/neotree_plugin.lua`, and `lua/plugins/title_sync_plugin.lua`.
- **A subdirectory** — when the plugin needs related functionality (e.g.
  a manager module). The subdirectory contains the plugin entrypoint file,
  named `<name>_plugin.lua`, plus the modules it depends on. See
  `lua/plugins/zellij/zellij_plugin.lua`.

A plugin's tests mirror its source location: specs for a single-file plugin
live in `lua/test/plugins/`, and specs for a subdirectory plugin live in a
matching `lua/test/plugins/<name>/` subdirectory.

Keeping plugin logic out of `lua/multiverse/` keeps core functionality
independent of any specific editor plugin integration.

**Known exceptions, tracked separately rather than blocking this convention
on a full resolution:**

- `lua/multiverse/managers/cli_manager.lua` requires
  `plugins.zellij.zellij_manager` directly, and its `:MultiverseTerminal`
  command body itself calls zellij-specific functions (`is_available`,
  `session_name_for`, `open_floating_terminal`, etc.), independent of the
  plugin lifecycle hooks. This couples core to a plugin and violates the
  rule above; untangling it is tracked in #367.
- `lua/multiverse/plugins/neotree.lua` is a `Plugin:new({...})` object
  that sits in core rather than under `lua/plugins/`. It is not wired into
  `plugin_manager.lua`'s registered plugin list, and its disposition is
  tracked in #147.
