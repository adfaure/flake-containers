{ pkgs, lib, rootpath, name, flake-root, ... }:
let
  fc-up = pkgs.writeShellApplication {
    name = name;
    text = ''
      set -x
      # TODO see how they get rootpath
      # https://github.com/Platonic-Systems/mission-control/blob/master/nix/flake-module.nix#L76C32-L76C67
      base_dir=".flake-containers"
      mkdir -p .flake-containers

      # Tricks taken from https://github.com/Platonic-Systems/mission-control/blob/a562943f45d9b8ae63dd62ec084202fdbdbeb83f/nix/wrapper.nix#L45
      # It allow me to get the flake folder as the base dir for the containers.
      # but it also create a dependency on flake-root.
      FLAKE_ROOT="''$(${lib.getExe flake-root})"
      cd "$FLAKE_ROOT"

      machine_dir="$FLAKE_ROOT/$base_dir/${name}"

      if [ -d "$machine_dir" ]; then
        echo "$machine_dir already exists"
        # exit 1
      fi

      mkdir -p "$machine_dir"
      cd "$machine_dir"

      mkdir -p etc nix/store sbin home bin root usr var/lib run tmp
      mkdir -p etc/nxc

      echo ${name} > etc/nxc/hostname

      # Force for the moment
      ln -snf ${rootpath}/etc/os-release etc/
      ln -snf ${rootpath}/sw/bin/sh bin/sh

      exec sudo systemd-nspawn \
        -M "${name}" -D "$machine_dir" \
        -U \
        --notify-ready=yes \
        --kill-signal=SIGRTMIN+3 \
        --bind-ro=/nix/store \
        --bind-ro=/nix/var/nix/db \
        --bind-ro=/nix/var/nix/daemon-socket \
        --bind="${rootpath}:/nix/var/nix/profiles" \
        --bind="${rootpath}:/nix/var/nix/gcroots" \
        --link-journal=try-guest \
        "${rootpath}/init"
    '';
  };
in fc-up
