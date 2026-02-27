#!/usr/bin/env bash
# bootstrap.sh — run this from the NixOS live ISO after mounting drives

set -euo pipefail

# Mount your drives first, then:
git clone https://github.com/donaldgifford/nix-config /mnt/etc/nixos
nixos-install --flake /mnt/etc/nixos#donald
