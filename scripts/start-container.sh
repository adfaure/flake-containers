#!/usr/bin/env bash
set -x

base_dir="/tmp/nc-tests"
machine="nc-test"
machine_dir="$base_dir/$machine"

toplevel="/nix/store/ach3867rm8y3156ck238qrsrgyy6ck88-nixos-system-nixos-23.11pre-git"

exec systemd-nspawn \
  -M "$machine" -D "$machine_dir" \
  -U \
  --notify-ready=yes \
  --kill-signal=SIGRTMIN+3 \
  --bind-ro=/nix/store \
  --bind-ro=/nix/var/nix/db \
  --bind-ro=/nix/var/nix/daemon-socket \
  --bind="$toplvel:/nix/var/nix/profiles" \
  --bind="$toplevel:/nix/var/nix/gcroots" \
  --link-journal=try-guest \
  "$toplevel/init"