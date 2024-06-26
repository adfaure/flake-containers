toplevel@{ pkgs, config, inputs, lib, withSystem, ... }:
let
  inherit (builtins) listToAttrs attrNames attrValues foldl' length filter;
  inherit (lib)
    mkIf mkOption mkDefault mkMerge mapAttrs mkEnableOption types
    recursiveUpdateUntil isDerivation literalExpression;

  cfg = config.flake-containers;

  overlayType = types.uniq
    (types.functionTo (types.functionTo (types.lazyAttrsOf types.unspecified)));

  containerOptionType = types.submodule {
    options = {
      configuration = mkOption {};
      volumes-ro = mkOption {
        default = [];
      };
      volumes = mkOption {
        default = [];
      };
      runCommand = mkOption {
        default = null;
      };
    };
  };

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
      containers = mkOption { 
        type = types.attrsOf containerOptionType;
        default = { };
        description = ''
          Container configuration. Defines the system modules, volumes etc
        '';
      };
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
        mkContainer =
          import ./src/mkContainer.nix { inherit lib pkgs perSystemScope; };

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

        selectedPkgs = import cfg.nixpkgs.nixpkgs {
          inherit system;
          overlays = cfg.nixpkgs.overlays;
          config = cfg.nixpkgs.config;
        };

        shellHookHelpStr = let
          commands-list = lib.foldr (a: b: a + "\n" + b) " " (lib.flatten
            (lib.forEach containers
              (container: builtins.attrNames container.commands)));
        in ''
          flake-containers Shell Hook!

          The following commands are available (sudo is required for the up commands):
          ${commands-list}
        '';

      in {
        # flake-part way to specify nixpkgs
        _module.args.pkgs = selectedPkgs;

        # Create packages so they can be used directly from nix run
        packages = to-attribute-set;

        # Empty for the example
        devShells.flake-containers = pkgs.mkShell {
          shellHook = ''echo "${shellHookHelpStr}"'';
          nativeBuildInputs = lib.flatten to-list;
        };
      };
  };
}
