# multiverse.nvim

Hop between projects, preserving the state of your open tabpages, windows, and buffers.

The aim of this project is to increase productivity when context switching between many projects.

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
  - **Description**: Removes an existing *Universe* from the *Multiverse*.
  - **Arguments**: 
    - `name` (string): The name of the *Universe* to remove.
  - **Completion**: Supports auto-completion for existing *Universes*.

- **`MultiverseList`**
  - **Description**: Opens a *Telescope* picker that lists all *Universes* and loads one upon selection.
  - **Arguments**: None.



## Integrations

- **`Neotree`**
  - Automatically syncs to the working directory of the loaded universe.

## Contributing

Contributions are welcome! Please read the [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to contribute to this project.
