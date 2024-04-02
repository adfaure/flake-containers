#!/usr/bin/env bash

# Name of the container
machine=$1
# Top level 
toplevel=$2

base_dir="/tmp/nc-tests"

if [[ -z "$machine" ]]; then
    echo "machine name required"
    exit 1
fi
if [[ -z "$toplevel" ]]; then
    echo "toplevel path required"
    exit 1
fi
machine_dir="$base_dir/$machine"

if [ -d $machine_dir ]; then
   echo "$machine_dir already exists"
   exit 1
fi

mkdir -p $machine_dir
cd $machine_dir

# mkdir dev etc nix proc sbin sys
#mkdir -p dev etc nix/store proc sbin sys run/wrappers home bin root usr var
# dev proc sys
mkdir -p etc nix/store sbin home bin root usr var/lib run tmp

mkdir -p etc/nxc
echo $machine > etc/nxc/hostname

ln -s $toplevel/etc/os-release etc/
# ln -s $toplevel/init sbin/

ln -s $toplevel/sw/bin/sh bin/sh

# mount --bind -o ro /nix/store $machine_dir/nix/store

# mount -t tmpfs tmpfs $machine_dir/run
# mkdir -p $machine_dir/run/wrappers
# mount -t tmpfs -o exec,suid tmpfs $machine_dir/run/wrappers
# mount -t tmpfs -o exec,mode=777 tmpfs $machine_dir/tmp

# set -ex
#
# root="/tmp/nc-test"
#
# mkdir -p -m 0755 "$root/etc" "$root/var/lib"
# mkdir -p -m 0700 "$root/var/lib/private" "$root/root" # /run/containers
#
# if ! [ -e "$root/etc/os-release" ]; then
#   touch "$root/etc/os-release"
# fi
#
# if ! [ -e "$root/etc/machine-id" ]; then
#   touch "$root/etc/machine-id"
# fi
#
# mkdir -p -m 0755 \
#   "/nix/var/nix/profiles/per-container/$INSTANCE" \
#   "/nix/var/nix/gcroots/per-container/$INSTANCE"
#
# cp --remove-destination /etc/resolv.conf "$root/etc/resolv.conf"
#
# if [ "$PRIVATE_NETWORK" = 1 ]; then
#   extraFlags+=" --network-veth"
#   if [ -n "$HOST_BRIDGE" ]; then
#     extraFlags+=" --network-bridge=$HOST_BRIDGE"
#   fi
#   if [ -n "$HOST_PORT" ]; then
#     OIFS=$IFS
#     IFS=","
#     for i in $HOST_PORT
#     do
#         extraFlags+=" --port=$i"
#     done
#     IFS=$OIFS
#   fi
# fi
# 
# # extraFlags+=" ${concatStringsSep " " (mapAttrsToList nspawnExtraVethArgs cfg.extraVeths)}"
# 
# for iface in $INTERFACES; do
#   extraFlags+=" --network-interface=$iface"
# done
# 
# for iface in $MACVLANS; do
#   extraFlags+=" --network-macvlan=$iface"
# done
# 
# # If the host is 64-bit and the container is 32-bit, add a
# # --personality flag.
# ${optionalString (config.nixpkgs.system == "x86_64-linux") ''
#   if [ "$(< ''${SYSTEM_PATH:-/nix/var/nix/profiles/per-container/$INSTANCE/system}/system)" = i686-linux ]; then
#     extraFlags+=" --personality=x86"
#   fi
# ''}

# # Run systemd-nspawn without startup notification (we'll
# # wait for the container systemd to signal readiness).
# exec ${config.systemd.package}/bin/systemd-nspawn \
#   --keep-unit \
#   -M "$INSTANCE" -D "$root" $extraFlags \
#   $EXTRA_NSPAWN_FLAGS \
#   --notify-ready=yes \
#   --bind-ro=/nix/store \
#   --bind-ro=/nix/var/nix/db \
#   --bind-ro=/nix/var/nix/daemon-socket \
#   --bind="/nix/var/nix/profiles/per-container/$INSTANCE:/nix/var/nix/profiles" \
#   --bind="/nix/var/nix/gcroots/per-container/$INSTANCE:/nix/var/nix/gcroots" \
#   --setenv PRIVATE_NETWORK="$PRIVATE_NETWORK" \
#   --setenv HOST_BRIDGE="$HOST_BRIDGE" \
#   --setenv HOST_ADDRESS="$HOST_ADDRESS" \
#   --setenv LOCAL_ADDRESS="$LOCAL_ADDRESS" \
#   --setenv HOST_ADDRESS6="$HOST_ADDRESS6" \
#   --setenv LOCAL_ADDRESS6="$LOCAL_ADDRESS6" \
#   --setenv HOST_PORT="$HOST_PORT" \
#   --setenv PATH="$PATH" \
#   ${if cfg.additionalCapabilities != null && cfg.additionalCapabilities != [] then
#     ''--capability="${concatStringsSep " " cfg.additionalCapabilities}"'' else ""
#   } \
#   ${if cfg.tmpfs != null && cfg.tmpfs != [] then
#     ''--tmpfs=${concatStringsSep " --tmpfs=" cfg.tmpfs}'' else ""
#   } \
#   ${containerInit cfg} "''${SYSTEM_PATH:-/nix/var/nix/profiles/system}/init"
