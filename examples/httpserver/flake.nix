{
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

      flake-containers = {
        # Enable the containers
        enable = true;

        # Define and configure nixpgs
        nixpkgs = { config.permittedInsecurePackages = [ "zookeeper-3.7.2" ]; };

        # Define the containers as nixos modules
        containers = {
          # One container named httpsserver
          httpserver = {
            configuration = { pkgs, lib, ... }: {
              # Network configuration.
              networking.useDHCP = false;
              networking.firewall.allowedTCPPorts = [ 80 ];

              # Enable a web server.
              services.httpd = {
                enable = true;
                adminAddr = "morty@example.org";
              };

              services.zookeeper.enable = true;
            };
          };
        };
      };
    };
}
