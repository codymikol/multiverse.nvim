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
    - `name` (string, optional): The name of the universe to add. Defaults to the basename of the directory (see below) if omitted or empty.
    - `directory` (string, optional): The directory the universe is rooted at. Defaults to the current working directory if omitted or empty.
  - **Usage**:
    - `:MultiverseAdd` adds a universe for the current directory, named after its basename.
    - `:MultiverseAdd name` adds a universe for the current directory with the given name.
    - `:MultiverseAdd name directory` adds a universe for the given directory with the given name.
  - **Completion**: Supports file-path completion for positional arguments.

- **`MultiverseOpen`**
  - **Description**: Opens a specified *Universe*.
  - **Arguments**: 
    - `name` (string): The name of the *Universe* to open.
  - **Completion**: Supports auto-completion for existing *Universes*.

- **`MultiverseRemove`**
  - **Description**: Removes an existing *Universe* from the *Multiverse*, after confirming since this cannot be undone.
  - **Arguments**: 
    - `name` (string): The name of the *Universe* to remove.
  - **Completion**: Supports auto-completion for existing *Universes*.

- **`MultiverseList`**
  - **Description**: Opens a *Telescope* picker that lists all *Universes* and loads one upon selection.
  - **Arguments**: None.

- **`MultiverseLog`**
  - **Description**: Opens the plugin's log file, which contains detailed diagnostic information for errors reported via notifications.
  - **Arguments**: None.

- **`MultiverseTerminal`**
  - **Description**: Toggles a floating terminal backed by a Zellij session tied to the current *Universe*'s directory. The window opens straight into terminal-insert mode, ready to type into immediately. To close it again, press `<C-\><C-n>` first to leave terminal-insert mode, then re-run `:MultiverseTerminal` or its keymap (see [Keymaps](#keymaps)). Closing it only detaches the nvim-side window — the underlying Zellij session survives and is reattached, either by invoking this command again or automatically after a universe switch or restarting Neovim. No-ops with a warning if the `zellij` binary isn't installed.
  - **Arguments**: None.



## Keymaps

`setup()` accepts an optional `opts.keymaps` table to bind normal-mode keys directly to the commands above. Omitting `opts.keymaps` registers no keymaps, leaving existing configs unaffected:

```lua
require("multiverse").setup({
  keymaps = {
    list = "<leader>ml",
    terminal = "<leader>mt",
    add = "<leader>ma",
    open = "<leader>mo",
    remove = "<leader>mr",
    log = "<leader>mL",
  }
})
```

Commands that take an argument (`add`, `open`, `remove`) drop the cursor into the command line (e.g. `:MultiverseOpen `) with completion, rather than executing immediately.

## Terminal Title

`setup()` accepts an optional `opts.title` flag to sync `vim.o.titlestring` to the active *Universe*'s name on each universe switch: it's off by default, and enabling it also forces `vim.o.title = true`, overriding a user who had explicitly set `set notitle`. Each call to `setup()` sets `vim.g.multiverse_title_enabled` from `opts.title`, so omitting `title` (or calling `setup()` more than once without it) always disables the sync, even if the global was set directly beforehand.

```lua
require("multiverse").setup({
  title = true,
})
```

## Startup Behavior

- **Automatic hydration on directory entry**
  - **Description**: Opening Neovim directly on a directory that matches a registered *Universe* (e.g. `nvim .` or `nvim /path/to/project`) automatically hydrates that *Universe* on startup, equivalent to running `:MultiverseOpen <name>`. No action is required from the user.

## Integrations

- **`Neotree`**
  - Automatically syncs to the working directory of the loaded universe.

## Contributing

Contributions are welcome! Please read the [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to contribute to this project.
