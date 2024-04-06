# flake-containers

## Introduction
A proof of concept project for defining NixOS containers (systemd-nspawn) in a flake.nix file.

## Description
"flake-containers" is a small project demonstrating the usage of Nix for managing systemd containers. It utilizes the Nix language and the Nix flake system to define and launch containers with systemd-nspawn.

## Features
- Define systemd containers in Nix.
- Generate commands to manage the containers (mostly wrappers around machinectl, instead of the ups commands).

## Why?
As stated, this is a proof of concept. I created it for experimenting with systemd-nspawn, NixOS, and flake-parts.

That being said, in my development workflow, I almost always define my development dependencies into a flake for Rust, Python, Go, etc. When I need to use different services, such as a database, I would typically rely on Docker. However, with flake-containers, I can directly benefit from NixOS services and enable and configure the services that I need, in a reproducible and shareable way.

It's worth mentioning that while there already exists a way to manage NixOS containers using `nixos-container`, it integrates within a NixOS configuration. This project has been largely inspired by `nixos-containers` (in fact, most of the code comes from there). However, flake-containers enables the definition and management of NixOS containers without the need to update your system configuration. Furthermore, it should work on any Linux distribution with Nix installed.

## Limitations
- It requires root privileges to start the containers.
- nixpkgs can be configured with a config and overlays, even changing the nixpkgs source. However, it cannot be set on a per container basis, and it is effective for each containers.
- There is a dependency on flake-roots to retrieve the path for the project, where I store the states for the containers.
- I dont think that the container can be updated while alive (with with nixos-rebuild switch for instance).

## Future Works
- It is not a compose-style project (at least for now); there is one command per container. No "flake-containers up" command.
- No support for volumes (temporary or permanent).
    - Volumes can be configured now in nix
- The network configuration is currently simple and not configurable.
- Compatibility with other distributions is untested; it has only been tested on NixOS.
- The project lacks testing. It appears to work on my computer; that's the only guarantee I can offer at the moment.
- There is an ugly sleep at the start time. I need a better way to detect when a container is alive to start the network configuration.
- Better nix code (add comments and types)
- Create a script to clean container states directory: https://github.com/NixOS/nixpkgs/issues/63028#issuecomment-507517718

## Usage

1. Start by creating a flake with the following content:
    ```nix
    {
        inputs = {
            nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
            # This project is based on flake-parts, so you need to import it
            flake-parts.url = "github:hercules-ci/flake-parts";
            # flake-root is a dependency that enable to find the root project for the flake
            # repositorty to create the states for the containers
            flake-root.url = "github:srid/flake-root";
            # Import flake-containers
            flake-containers.url = "github:adfaure/flake-containers";
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
                # Define the containers as nixos modules
                containers = {
                    # One container named httpsserver
                    httpserver = {
                        # Define volumes to be bind inside the conaiter
                        volumes = [ "/tmp" "src:/tmp/src" ];
                        volumes-ro = [ "/data" ];
                        
                        # The configuration is a regular nixos module
                        configuration = { pkgs, lib, ... }: {
                            # Network configuration.
                            networking.useDHCP = false;
                            networking.firewall.allowedTCPPorts = [ 80 ];

                            # Enable a web server.
                            services.httpd = {
                                enable = true;
                                adminAddr = "morty@example.org";
                            };
                        };
                    };
                };
            };
        };
    }
    ```
3. Use `nix flake show` to see what is available. For each container, the flake defines the command to manage.
    ```
    > nix flake show
    git+file:///home/adfaure/code/flake-containers?dir=examples/httpserver
    ├───devShells
    │   └───x86_64-linux
    │       └───flake-containers: development environment 'nix-shell'
    └───packages
        └───x86_64-linux
            ├───httpserver-down: package 'httpserver-down'
            ├───httpserver-shell: package 'httpserver-shell'
            └───httpserver-up: package 'httpserver-up'
    ```
2. Use `nix develop .#flake-containers` to dive into a shell containing commands to manage your containers.
3. Start the container with `sudo httpserver-up` to start the container.
4. The container should appear with the `machinectl list` command.

## Contributing
Contributions are welcome! Feel free to open issues for bugs or feature requests, and submit pull requests with improvements.

## License
This project is licensed under the [MIT License](LICENSE).

## References

- https://gitlab.inria.fr/nixos-compose/nixos-compose
- https://www.tweag.io/blog/2020-07-31-nixos-flakes/
- https://github.com/tfc/nspawn-nixos
- https://blog.beardhatcode.be/2020/12/Declarative-Nixos-Containers.html
- https://nixos.org/manual/nixos/stable/#sec-imperative-containers
- https://github.com/NixOS/nixpkgs/blob/2456e8475ffd7363fe194505ef0488dfc89a8eb1/nixos/modules/virtualisation/containers.nix#L212
- https://github.com/NixOS/nixpkgs/blob/1729a61ebf54dad1fe8c3cfeeadbad530e041169/pkgs/tools/virtualization/nixos-container/nixos-container.pl