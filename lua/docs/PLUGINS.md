# Plugins

A *Plugin* lets you hook into the dehydrate/hydrate lifecycle of a *Universe*.
*Dehydration* is the process of saving the state of the current *Universe*
(its tabpages, windows, and buffers) into persistence; *hydration* is the
process of rebuilding that state when a *Universe* is opened. Plugins are
notified at four points around this process, so they can save their own
state, clean up resources, or restore/re-render things as a *Universe* is
torn down and rebuilt.

## Authoring a plugin

A plugin is created with `Plugin:new(opts)`, from `multiverse.data.plugin.Plugin`:

```lua
local Plugin = require("multiverse.data.plugin.Plugin")

local myPlugin = Plugin:new({
  name = "MyPlugin",

  beforeDehydrate = function(ctx)
    -- ...
  end,

  afterDehydrate = function(ctx)
    -- ...
  end,

  beforeHydrate = function(ctx)
    -- ...
  end,

  afterHydrate = function(ctx)
    -- ...
  end,
})
```

- **`name`** (string, required) — identifies the plugin. `Plugin:new` returns
  `nil` if `name` is missing or not a non-empty string. The examples below
  use a hardcoded literal `name`, so this can't happen — but if you build
  `name` dynamically, check the result before registering it.
- **`beforeDehydrate`**, **`afterDehydrate`**, **`beforeHydrate`**,
  **`afterHydrate`** (functions, all optional) — lifecycle hooks. Only the
  hooks you provide are called; omit any you don't need.

## Lifecycle hooks

- **`beforeDehydrate(ctx: BeforeDehydrateContext)`**
  The first lifecycle event called. This is called before the state of the
  universe is saved into persistence. Here when required is a good time to
  drive the related plugin to save its own state, or clean up any resources.

- **`afterDehydrate(ctx: AfterDehydrateContext)`**
  The second lifecycle event called. This is called after the state of the
  universe is saved into persistence.

- **`beforeHydrate(ctx: BeforeHydrateContext)`**
  The third lifecycle event called. This is called after all tabpages,
  windows, and buffers have been purged, and the universe is about to be
  hydrated. This can be used to prepare any resources that may need to be
  rendered in the universe.

- **`afterHydrate(ctx: AfterHydrateContext)`**
  The final lifecycle event called. This is called after the universe has
  been hydrated. This can be used to interact with the now existing
  tabpages, windows, and buffers.

Each context is currently a table with a single field, `ctx.universe`.
For `beforeDehydrate`/`afterDehydrate`, `ctx.universe` is populated with
the `Universe` being dehydrated. For `beforeHydrate`/`afterHydrate`,
`ctx.universe` is currently always `nil` (an existing quirk of
`multiverse_manager.lua`) — do not rely on it being populated in a
hydrate hook.

## Registering a plugin

Pass your plugin(s) into `Multiverse.setup({ plugins = { ... } })`. Extending
the [lazy.nvim installation example](../../README.md#installation):

```lua
{
  "codymikol/multiverse.nvim",
  dependencies = { "nvim-telescope/telescope.nvim" },
  lazy = false,
  config = function()
    local Plugin = require("multiverse.data.plugin.Plugin")

    local myPlugin = Plugin:new({
      name = "MyPlugin",
      beforeDehydrate = function(ctx)
        -- ...
      end,
    })

    require("multiverse").setup({
      plugins = { myPlugin },
    })
  end,
}
```

## Complete example

A minimal plugin that just logs when the universe is dehydrated and hydrated:

```lua
local Plugin = require("multiverse.data.plugin.Plugin")

local LoggingPlugin = Plugin:new({
  name = "LoggingPlugin",

  beforeDehydrate = function(_)
    vim.notify("LoggingPlugin: dehydrating universe...")
  end,

  afterHydrate = function(_)
    vim.notify("LoggingPlugin: universe hydrated")
  end,
})

require("multiverse").setup({
  plugins = { LoggingPlugin },
})
```
