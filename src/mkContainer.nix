{ lib, pkgs, perSystemScope, ... }:
# Create a the commands that manage the containers
name: container: localAddress: hostAddress:
let
  containerConfig = {
    # system.stateVersion = lib.mkDefault lib.trivial.release;
    imports = [
      # Minimal module that declares a container
      ({ pkgs, lib, modulesPath, ... }: {
        boot.isContainer = true;
        # imports = [ "${modulesPath}/profiles/minimal.nix" ];
        systemd.sockets.nix-daemon.enable = lib.mkDefault false;
        systemd.services.nix-daemon.enable = lib.mkDefault false;
      })
      # user defined module
      container.configuration
    ];
  };
  container-name = name;
  builtContainer = pkgs.nixos containerConfig;
  rootPath = "${builtContainer.toplevel}";
in {
  inherit container-name builtContainer rootPath;
  commands = {
    # Maybe not the best way to import it
    # TODO: make it a function instead ?
    "${container-name}-up" = (import ./container-up.nix) {
      inherit pkgs lib localAddress hostAddress;
      rootpath = rootPath;
      flake-root = perSystemScope.config.flake-root.package;
      name = container-name;
    };
    "${container-name}-down" = pkgs.writeShellApplication {
      name = "${container-name}-down";
      text = ''
        machinectl stop ${container-name}
      '';
    };
    "${container-name}-shell" = pkgs.writeShellApplication {
      name = "${container-name}-shell";
      text = ''
        machinectl shell ${container-name}
      '';
    };
  };
}
