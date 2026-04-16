---
id: RFC-0001
title: "Multi-Platform Nix Configuration Management"
status: Draft
author: Donald Gifford
created: 2026-04-11
---
<!-- markdownlint-disable-file MD025 MD041 -->

# RFC 0001: Multi-Platform Nix Configuration Management

**Status:** Draft
**Author:** Donald Gifford
**Date:** 2026-04-11

<!--toc:start-->
- [Summary](#summary)
- [Problem Statement](#problem-statement)
- [Proposed Solution](#proposed-solution)
- [Design](#design)
- [Alternatives Considered](#alternatives-considered)
- [Implementation Phases](#implementation-phases)
  - [Phase 1: Unified Flake with Shared Home Manager Modules](#phase-1-unified-flake-with-shared-home-manager-modules)
  - [Phase 2: Platform-Specific System Configuration](#phase-2-platform-specific-system-configuration)
  - [Phase 3: Raw Dotfile Symlinks via mkOutOfStoreSymlink](#phase-3-raw-dotfile-symlinks-via-mkoutofstoresymlink)
- [Risks and Mitigations](#risks-and-mitigations)
- [Success Criteria](#success-criteria)
- [References](#references)
<!--toc:end-->

## Summary

Manage macOS (aarch64-darwin) and NixOS (x86_64-linux) workstation environments from a single Nix flake. Shared tooling, shell configuration, and dotfiles are defined once in common Home Manager modules, while platform-specific system configuration (nix-darwin, NixOS) lives in dedicated host directories. Raw config files are symlinked — not copied — into the Nix store so edits take effect immediately without rebuilding.

## Problem Statement

Running two machines (a MacBook and a NixOS workstation) with independent configuration leads to:

- **Configuration drift** — shell aliases, git settings, editor plugins, and CLI tools diverge over time as changes are made on one machine but not the other.
- **Duplicated effort** — every new tool or config change must be applied twice, with platform-specific adjustments discovered ad hoc.
- **No single source of truth** — dotfiles scattered across machines make it hard to reproduce an environment on a fresh install or recover from hardware failure.
- **Opaque state** — imperative package managers (Homebrew, apt) accumulate undeclared packages that are invisible until something breaks.

The impact is lost time debugging "works on my other machine" differences and increased risk during hardware migrations.

## Proposed Solution

Use a single `flake.nix` as the entry point for both platforms:

- **`darwinConfigurations."donald-mbp"`** — nix-darwin system config + Home Manager as a darwin module
- **`nixosConfigurations.workstation`** — NixOS system config + Home Manager as a NixOS module

Shared configuration lives in `home/common/` and is imported by both `home/darwin.nix` and `home/linux.nix`. Platform-specific modules live in `home/linux/` (Sway, Waybar, etc.) and `hosts/macbook/` (Homebrew, macOS defaults).

Raw dotfiles (neovim, ghostty, starship, lazygit, yazi, etc.) live in `config/` and are symlinked into `~/.config` via `mkOutOfStoreSymlink`, allowing immediate editing without `darwin-rebuild` or `nixos-rebuild`.

## Design

```
flake.nix
├── darwinConfigurations."donald-mbp"
│   ├── hosts/macbook/darwin.nix        # system: homebrew, defaults, fonts
│   └── home/darwin.nix                 # HM entry → imports home/common/*
│
├── nixosConfigurations.workstation
│   ├── hosts/workstation/configuration.nix  # system: nvidia, sway, greetd
│   ├── hosts/workstation/hardware-configuration.nix
│   └── home/linux.nix                 # HM entry → imports home/common/* + home/linux/*
│
├── home/common/                       # shared HM modules (shell, git, ssh, tmux, etc.)
│   └── configs.nix                    # mkOutOfStoreSymlink bridge to config/
│
└── config/                            # raw dotfiles, symlinked into ~/.config
    ├── nvim/                          # LazyVim config
    ├── ghostty/
    ├── starship/
    └── ...
```

Key design decisions:

1. **Home Manager as a module** (not standalone) — HM is wired into both `darwinSystem` and `nixosSystem` so a single `rebuild switch` applies system and user config atomically.
2. **Inputs follow nixpkgs** — both `nix-darwin.inputs.nixpkgs` and `home-manager.inputs.nixpkgs` follow the same `nixpkgs` input to prevent version conflicts.
3. **`mkOutOfStoreSymlink`** — config files in `config/` are symlinked out of the Nix store. This means editing `config/nvim/lua/plugins/colorscheme.lua` takes effect immediately without a rebuild. The trade-off is these files are not immutable or reproducible via the store.
4. **Platform conditionals in packages** — `home/common/packages.nix` uses `lib.optionals pkgs.stdenv.isLinux` and `isDarwin` to include platform-specific packages in a single file.
5. **1Password as SSH/signing agent** — both platforms use 1Password for SSH agent and git commit signing, with platform-specific socket paths configured in each HM entry file.

## Alternatives Considered

| Alternative | Why Rejected |
|---|---|
| **Separate repos per machine** | Maximizes drift. Shared config must be copy-pasted. No atomic updates across platforms. |
| **Home Manager standalone** (no nix-darwin/NixOS integration) | Loses the ability to manage system-level config (Homebrew casks, macOS defaults, NixOS services) declaratively. Two separate rebuild commands needed. |
| **GNU Stow / chezmoi for dotfiles** | Doesn't provide package management or system configuration. Would still need Nix for packages, creating two tools to maintain. |
| **Ansible for cross-platform config** | Imperative, stateful, no rollback. Nix's declarative model with generations is strictly better for reproducibility. |
| **NixOS on both machines** | Not practical — macOS hardware requires macOS. nix-darwin is the closest equivalent. |

## Implementation Phases

### Phase 1: Unified Flake with Shared Home Manager Modules

- Create `flake.nix` with both `darwinConfigurations` and `nixosConfigurations`
- Extract shared config into `home/common/` modules (shell, git, ssh, neovim, tmux, mise, packages)
- Create platform entry points (`home/darwin.nix`, `home/linux.nix`) that import common modules

### Phase 2: Platform-Specific System Configuration

- macOS: `hosts/macbook/darwin.nix` — Homebrew casks/brews/masApps, system defaults, keyboard remapping, TouchID sudo
- NixOS: `hosts/workstation/configuration.nix` — Nvidia driver, Sway/Wayland, greetd, PipeWire audio, btrfs

### Phase 3: Raw Dotfile Symlinks via mkOutOfStoreSymlink

- Move raw config files into `config/` directory
- Create `home/common/configs.nix` with `mkOutOfStoreSymlink` entries for each tool
- Validate symlinks work on both platforms

## Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `mkOutOfStoreSymlink` breaks reproducibility | Medium — config files not tracked by Nix store | Medium | Config files are version-controlled in git; the symlink path is deterministic |
| nixpkgs-unstable introduces breaking changes | High — both platforms affected simultaneously | Low | Pin `flake.lock`; update intentionally with `nix flake update`; use generations for rollback |
| Homebrew `cleanup = "zap"` removes manually installed apps | Medium — data loss if app stored state locally | Medium | Declare all desired apps in `darwin.nix`; review before running `darwin-rebuild switch` |
| Platform-specific packages fail on the other platform | Low — build error | Low | Guard with `lib.optionals pkgs.stdenv.isLinux/isDarwin` |
| 1Password agent socket path changes | Medium — SSH and git signing break | Low | Socket paths are explicit in HM entry files; easy to update |

## Success Criteria

- A single `git clone` + one rebuild command fully provisions either machine from scratch
- Adding a new CLI tool requires editing at most two files (`packages.nix` + optionally `configs.nix`)
- Editing a file in `config/` takes effect immediately without rebuilding
- Both platforms share identical shell aliases, git config, and editor setup
- Rolling back to a previous generation restores the full system + user environment

## References

- [ADR-0001: Use nix-darwin with Homebrew for macOS Configuration](../adr/0001-use-nix-darwin-with-homebrew-for-macos-configuration.md)
- [ADR-0002: Use NixOS with Sway and Nvidia for Workstation](../adr/0002-use-nixos-with-sway-and-nvidia-for-workstation.md)
- [DESIGN-0001: Claude Code Skills for Nix Config Management](../design/0001-claude-code-skills-for-nix-config-management.md)
- [nix-darwin](https://github.com/nix-darwin/nix-darwin)
- [Home Manager](https://github.com/nix-community/home-manager)
- [Determinate Systems Nix Installer](https://github.com/DeterminateSystems/nix-installer)
