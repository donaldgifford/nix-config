# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Multi-platform Nix flake managing macOS (nix-darwin, `donald-mbp`) and NixOS (workstation) from a single `flake.nix`. Uses Home Manager as a module (not standalone) on both platforms.

## Build Commands

```bash
# macOS — apply system + home-manager changes
sudo darwin-rebuild switch --flake ~/code/nix-config

# NixOS — apply system + home-manager changes
sudo nixos-rebuild switch --flake ~/code/nix-config#workstation

# Update all flake inputs
nix flake update

# Check flake evaluates without errors
nix flake check

# Format nix files
nixfmt **/*.nix
```

## Nix Linting

```bash
statix check .     # lint nix files for anti-patterns
deadnix .          # find unused nix code
```

## Architecture

**`flake.nix`** — Entry point. Defines two configurations:
- `darwinConfigurations."donald-mbp"` (aarch64-darwin) — uses `hosts/macbook/darwin.nix` + `home/darwin.nix`
- `nixosConfigurations.workstation` (x86_64-linux) — uses `hosts/workstation/configuration.nix` + `home/linux.nix`

**`home/common/`** — Shared Home Manager modules imported by both `home/darwin.nix` and `home/linux.nix`:
- `configs.nix` — symlinks from `config/` dir into `~/.config` via `mkOutOfStoreSymlink`
- `shell.nix`, `git.nix`, `ssh.nix`, `neovim.nix`, `tmux.nix`, `mise.nix`, `packages.nix`, `claude.nix`, `fonts.nix`

**`home/linux/`** — Linux-only modules (sway, waybar, wofi, swaylock).

**`config/`** — Raw dotfiles (nvim, ghostty, starship, lazygit, yazi, bat, btop, sesh, eza, etc.) symlinked into `~/.config` by `home/common/configs.nix`. Edit these directly — they are not managed by Nix expressions.

**`hosts/macbook/darwin.nix`** — macOS system config: Homebrew casks/brews/masApps, system defaults, keyboard remapping. Homebrew `cleanup = "zap"` removes anything not declared.

**`hosts/workstation/`** — NixOS system config with Nvidia (open kernel module), Sway/Wayland, greetd.

**`backup/`** — Historical config iterations. Not used by the active flake.

## Key Patterns

- **`mkOutOfStoreSymlink`**: Config files in `config/` are symlinked (not copied) into the Nix store, so edits take effect immediately without rebuilding.
- **Platform conditionals**: `packages.nix` uses `lib.optionals pkgs.stdenv.isLinux` / `isDarwin` for platform-specific packages.
- **1Password integration**: SSH agent and git commit signing go through 1Password on both platforms (different socket paths per OS).
- **Inputs follow nixpkgs**: Both `nix-darwin` and `home-manager` inputs follow the same `nixpkgs` to avoid version conflicts.
- **Determinate Nix**: macOS uses Determinate Systems installer (`nix.enable = false` in darwin.nix since Determinate manages the daemon).

## Adding a New Tool/Package

1. **Nix package**: Add to `home/common/packages.nix` (or platform-specific section).
2. **Config files**: Place in `config/<tool>/`, add symlink entry in `home/common/configs.nix`.
3. **Homebrew cask** (macOS GUI app): Add to `hosts/macbook/darwin.nix` under `homebrew.casks`.
4. **New Home Manager module**: Create `home/common/<name>.nix`, import it from both `home/darwin.nix` and `home/linux.nix`.
