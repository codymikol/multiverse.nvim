# 0.0.1

Created multiverse.nvim

* Save current open buffers upon leaving a workspace and rehydrate upon re-entry.
* Set the correct Neotree directory upon opening a workspace.
* Automatically load a universe when opening Neovim directly on its directory.
* Register custom plugins with dehydrate/hydrate lifecycle hooks via `Multiverse.setup({ plugins = { ... } })`.
