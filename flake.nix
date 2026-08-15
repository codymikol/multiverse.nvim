{
  description = "multiverse.nvim: a project management plugin for neovim";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    spindrift.url = "github:jordansmall/spindrift";
  };

  outputs = inputs@{ 
    self,
    nixpkgs,
    flake-utils,
    flake-parts,
    spindrift,
    }:

    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      imports = [ spindrift.flakeModules.default ];

      perSystem =
        { config, pkgs, ... }:
        {
          spindrift = {

            infra.image = {
              packages = p: [ p.neovim ];
              prefetch = "nvim --headless '+Lazy! sync' +qa";
            };

            forge = {
              backend = "github";
              repoSlug = "codymikol/multiverse.nvim";
            };

            git.user = {
              name = "bot";
              email = "hi@codymikol.com";
            };
 
            settings = {
              concurrency = { maxParallel = 1; };
            };

          };

          devShells.default = pkgs.mkShell {
            packages = [ config.packages.spindrift ];
          };

        };
    };
}




