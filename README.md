# multiverse.nvim

Hop between projects, preserving the state of your open tabpages, windows, and buffers.

The aim of this project is to increase productivity when context switching between many projects.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim). `setup()` registers a `VimEnter` autocmd that automatically hydrates a matching *Universe* on startup (see [Startup Behavior](#startup-behavior)), so the plugin must load eagerly (`lazy = false`) rather than on a command or event that could fire after `VimEnter`:

```lua
{
  "codymikol/multiverse.nvim",
  dependencies = { "nvim-telescope/telescope.nvim" },
  lazy = false,
  config = function()
    require("multiverse").setup()
  end,
}
```

## CLI

- **`MultiverseAdd`**
  - **Description**: Adds a new *Universe* to the *Multiverse*.
  - **Arguments**: 
    - `name` (string): The name of the universe to add.
  - **Completion**: Supports auto-completion for existing *Universes*.

- **`MultiverseOpen`**
  - **Description**: Opens a specified *Universe*.
  - **Arguments**: 
    - `name` (string): The name of the *Universe* to open.
  - **Completion**: Supports auto-completion for existing *Universes*.

- **`MultiverseRemove`**
  - **Description**: Removes an existing *Universe*, after confirmation — this deletes persisted data and cannot be undone.
  - **Arguments**: 
    - `name` (string): The name of the *Universe* to remove.
  - **Completion**: Supports auto-completion for existing *Universes*.

- **`MultiverseList`**
  - **Description**: Opens a *Telescope* picker that lists all *Universes* and loads one upon selection.
  - **Arguments**: None.



## Startup Behavior

- **Automatic hydration on directory entry**
  - **Description**: Opening Neovim directly on a directory that matches a registered *Universe* (e.g. `nvim .` or `nvim /path/to/project`) automatically hydrates that *Universe* on startup, equivalent to running `:MultiverseOpen <name>`. No action is required from the user.

## Integrations

- **`Neotree`**
  - Automatically syncs to the working directory of the loaded universe.

## Contributing

Contributions are welcome! Please read the [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to contribute to this project.
