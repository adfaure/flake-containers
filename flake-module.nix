toplevel@{ pkgs, config, inputs, lib, withSystem, ... }:
let
  inherit (builtins) listToAttrs attrNames attrValues foldl' length filter;
  inherit (lib)
    mkIf mkOption mkDefault mkMerge mapAttrs mkEnableOption types
    recursiveUpdateUntil isDerivation literalExpression;

  cfg = config.flake-containers;

  overlayType = types.uniq
    (types.functionTo (types.functionTo (types.lazyAttrsOf types.unspecified)));

  nixpkgsOptionType = types.submodule {
    options = {
      nixpkgs = mkOption {
        type = types.path;
        default = inputs.nixpkgs;
        defaultText = literalExpression "inputs.nixpkgs";
        description = ''
          The nixpkgs flake to use.

          This option needs to set if the nixpkgs that you want to use is under a different name
          in flake inputs.
        '';
      };
      config = mkOption {
        default = { };
        type = types.attrs;
        description = ''
          The configuration of the Nix Packages collection.
        '';
        example = literalExpression ''
          { allowUnfree = true; }
        '';
      };
      overlays = mkOption {
        default = [ ];
        type = types.uniq (types.listOf overlayType);
        description = ''
          List of overlays to use with the Nix Packages collection.
        '';
        example = literalExpression ''
          [
            inputs.fenix.overlays.default
          ]
        '';
      };
    };
  };

  flakeContainersConfigType = types.submodule {
    options = {
      enable = mkEnableOption "flake containers";
      nixpkgs = mkOption {
        type = nixpkgsOptionType;
        default = { };
        description = ''
          Config about the nixpkgs used by flake containers.
        '';
      };
      containers = mkOption { };
    };
  };

in {
  options.flake-containers = mkOption {
    type = flakeContainersConfigType;
    default = { };
    description = ''
      The config for flake-containers.
    '';
  };
  config = mkIf cfg.enable {
    perSystem = perSystemScope@{ config, self', lib, pkgs, system, ... }:
      let
        mergeIntoSet = lib.foldr (a: b: a // b) { };
        # Fot the moment, map containers to private adresses
        allocatedAdresses = mergeIntoSet (lib.imap1 (i: name: {
          "${name}" = let ipPrefix = "10.233.${builtins.toString i}";
          in {
            hostAddress = "${ipPrefix}.1";
            localAddress = "${ipPrefix}.2";
          };
        }) ((lib.mapAttrsToList (name: config: name)) cfg.containers));
        # Create a the commands that manage the containers
        mkContainer = name: container: localAddress: hostAddress:
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
              "${container-name}-up" = (import ./src/container-up.nix) {
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
          };

        # Create all containers
        containers = lib.mapAttrsToList (name: container:
          mkContainer name container allocatedAdresses."${name}".localAddress
          allocatedAdresses."${name}".hostAddress) cfg.containers;

        # Create a list to be add to the buildInputs
        to-list = lib.concatMap
          # Create a list from the set
          (lib.mapAttrsToList (name: command: command))
          # Get the commands attribute for each container
          (lib.forEach containers (container: container.commands));

        to-attribute-set = mergeIntoSet
          # Get the commands attribute for each container
          (lib.forEach containers (container: container.commands));

      in {
        # flake-part way to specify nixpkgs
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [];
          config.permittedInsecurePackages = [
                "zookeeper-3.7.2"
            ];
        };
        packages = to-attribute-set;
        # Empty for the example
        devShells.flake-containers =
          pkgs.mkShell { nativeBuildInputs = lib.flatten to-list; };
      };
  };
}
