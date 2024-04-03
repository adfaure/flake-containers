{ pkgs, lib, rootpath, name, flake-root, localAddress, hostAddress, ... }:
let
  inherit (lib) getExe optionalString mapAttrsToList concatStringsSep;

  flakeContainersBaseDir = ".flake-containers";

  # Base container volume, that will be the / of the container
  containerSystemDir = "${flakeContainersBaseDir}/${name}/config";

  # Contains container configuration to configure its launching parameters (volumes, network etc)
  containerConfigDir = "${flakeContainersBaseDir}/${name}/volume";

  # Code from https://github.com/NixOS/nixpkgs/blob/8b152a2242d4f29de1c072f833ab941dd141c510/nixos/modules/virtualisation/nixos-containers.nix#L43
  containerInit = pkgs.writeScript "container-init" ''
    #! ${pkgs.runtimeShell} -e

    # Exit early if we're asked to shut down.
    trap "exit 0" SIGRTMIN+3

    ${pkgs.iproute2}/bin/ip link set host0 name eth0
    ${pkgs.iproute2}/bin/ip link set dev eth0 up

    ${pkgs.iproute2}/bin/ip addr add ${localAddress} dev eth0

    ${pkgs.iproute2}/bin/ip route add ${hostAddress} dev eth0
    ${pkgs.iproute2}/bin/ip route add default via ${hostAddress}

    # Start the regular stage 2 script.
    # We source instead of exec to not lose an early stop signal, which is
    # also the only _reliable_ shutdown signal we have since early stop
    # does not execute ExecStop* commands.
    set +e
    . "$1"
  '';

  ipcall = ipcmd: variable: ''
    ${ipcmd} add ${variable} dev $ifaceHost
  '';

  containerUpScript = pkgs.writeShellApplication {
    name = "${name}-up";
    text = ''
      # TODO: see how they get rootpath
      # https://github.com/Platonic-Systems/mission-control/blob/master/nix/flake-module.nix#L76C32-L76C67

      # Tricks taken from https://github.com/Platonic-Systems/mission-control/blob/a562943f45d9b8ae63dd62ec084202fdbdbeb83f/nix/wrapper.nix#L45
      # It allow me to get the flake folder as the base dir for the containers.
      # but it also create a dependency on flake-root...
      FLAKE_ROOT="$(${lib.getExe flake-root})"

      machine_dir="$FLAKE_ROOT/${containerSystemDir}"

      if [ -d "$machine_dir" ]; then
        echo "$machine_dir already exists"
        # exit 1
      fi

      mkdir -p "$machine_dir"
      cd "$machine_dir"

      mkdir -p etc nix/store sbin home bin root usr var/lib run tmp
      mkdir -p etc/nxcconcatStringsSep
      # Force for the moment
      ln -snf ${rootpath}/etc/os-release etc/
      ln -snf ${rootpath}/sw/bin/sh bin/sh

      # Clean previous interfaces
      ip link del dev "ve-${name}" 2> /dev/null || true
      ip link del dev "vb-${name}" 2> /dev/null || true

      # start container in subprocess
      systemd-nspawn \
        -M "${name}" -D "$machine_dir" \
        --private-network \
        --network-veth \
        --notify-ready=yes \
        --kill-signal=SIGRTMIN+3 \
        --bind-ro=/nix/store \
        --bind-ro=/nix/var/nix/db \
        --bind-ro=/nix/var/nix/daemon-socket \
        --bind="${rootpath}:/nix/var/nix/profiles" \
        --bind="${rootpath}:/nix/var/nix/gcroots" \
        --link-journal=try-guest \
        --capability="CAP_NET_ADMIN" \
        ${containerInit} "${rootpath}/init" &

      # FIXME: Aouch
      sleep 5s

      # Activate the network
      ip link set dev ve-${name} up

      ${pkgs.iproute2}/bin/ip addr add ${hostAddress} dev ve-${name}
      ${pkgs.iproute2}/bin/ip route add ${localAddress} dev ve-${name}

      # wait end of conainter
      wait
    '';
  };
in containerUpScript
