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
      container = mkOption { };
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
    perSystem = { pkgs, system, ... }:
      let
        containerConfig = {
          # system.stateVersion = lib.mkDefault lib.trivial.release;
          imports = [
            # Minimal module that declares a container
            ({ pkgs, lib, modulesPath, ... }: {
              boot.isContainer = true;
              imports = [ "${modulesPath}/profiles/minimal.nix" ];
              systemd.sockets.nix-daemon.enable = lib.mkDefault false;
              systemd.services.nix-daemon.enable = lib.mkDefault false;
            })

            # user defined module
            cfg.container 
          ];
        };
        builtContainer = pkgs.nixos containerConfig;
        toplevel = "${builtContainer}";
      in {
        packages.container = pkgs.writeTextFile {
          name = "test";
          text = ''
            echo "container toplevel = ${toplevel}"
          '';
        };
        # Empty for the example
        devShells.flake-containers =
          pkgs.mkShell { nativeBuildInputs = []; };
      };
  };
}
