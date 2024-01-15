# multiverse.nvim

this is built on top of https://github.com/natecraddock/workspaces.nvim and focuses on
treating a workspace ( open buffers, open windows, current neotree dir ) as persisted state
that should hydrate upon re-entry.

### Features

* Save and hydrate buffers upon entering / leaving a workspace

### Integrations

Neotree - automatically set the neotree directory upon entering a workspace

### TODO

* Save and hydrate windows upon entering / leaving a workspace
* Treat entering a workspace directly "nvim ./multiverse.nvim" the same as through the workspaces api
