{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    # Import NUR repository
    nur.url = "github:nix-community/NUR";
    # This project is based on flake-parts, so you need to import it
    flake-parts.url = "github:hercules-ci/flake-parts";
    # flake-root is a dependency that enable to find the root project for the flake
    # repositorty to create the states for the containers
    flake-root.url = "github:srid/flake-root";
    # Import flake-containers
    flake-containers.url = "../..";
  };
  outputs =
    inputs@{ self, nur, nixpkgs, flake-parts, flake-containers, flake-root, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports =
        [ inputs.flake-containers.flakeModule inputs.flake-root.flakeModule ];

      systems = [ "x86_64-linux" ];

      flake-containers = {
        # Enable the containers
        enable = true;

        # Define and configure nixpgs
        nixpkgs = {
          overlays = [ nur.overlay ];
          config.allowBroken = true;
        };

        # Define the containers as nixos modules
        containers = {
          # One container named httpsserver
          nur = {
            configuration = { pkgs, lib, ... }: {
               environment.systemPackages = with pkgs; [
                  pkgs.nur.repos.caarlos0.timer
               ];

            };
          };
        };
      };
    };
}
