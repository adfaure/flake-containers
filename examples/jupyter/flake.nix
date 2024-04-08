{
  description = "Flake containers with configured overlay";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    # This project is based on flake-parts, so you need to import it
    flake-parts.url = "github:hercules-ci/flake-parts";
    # flake-root is a dependency that enable to find the root project for the flake
    # repositorty to create the states for the containers
    flake-root.url = "github:srid/flake-root";
    # Import flake-containers
    flake-containers.url = "../..";
  };
  outputs =
    inputs@{ self, nixpkgs, flake-parts, flake-containers, flake-root, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports =
        [ inputs.flake-containers.flakeModule inputs.flake-root.flakeModule ];

      systems = [ "x86_64-linux" ];

      perSystem = { config, self', inputs', pkgs, system, ... }: {
        devShells.default = with pkgs;
          mkShell rec {
            buildInputs = [
              (pkgs.python3.withPackages
                (python-pkgs: [ python-pkgs.notebook ]))
            ];
          };
      };

      flake-containers = {
        # Enable the containers
        enable = true;
        # Define the containers as nixos modules
        containers = let srcdir = "/tmp/src";
        in {
          jupyter = {
            # 
            volumes = [ ".:${srcdir}" ];
            
            # How to create a better way to define runCommand ?
            runCommand = pkgs:
              let
                pythonEnv = (pkgs.python3.withPackages
                  (python-pkgs: [ python-pkgs.notebook ]));
              in ''
                cd ${srcdir} ; ${pythonEnv}/bin/python -m jupyter notebook --ip 0.0.0.0 --allow-root
              '';

            configuration = { pkgs, lib, ... }: {
              # Network configuration.
              networking.useDHCP = false;
              networking.firewall.allowedTCPPorts = [ 8888 ];
            };
          };
        };
      };
    };
}
