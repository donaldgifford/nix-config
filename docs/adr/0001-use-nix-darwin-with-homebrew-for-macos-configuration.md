---
id: ADR-0001
title: "Use nix-darwin with Homebrew for macOS Configuration"
status: Proposed
author: Donald Gifford
created: 2026-04-11
---
<!-- markdownlint-disable-file MD025 MD041 -->

# 0001. Use nix-darwin with Homebrew for macOS Configuration

<!--toc:start-->
- [Status](#status)
- [Context](#context)
- [Decision](#decision)
- [Consequences](#consequences)
  - [Positive](#positive)
  - [Negative](#negative)
  - [Neutral](#neutral)
- [Alternatives Considered](#alternatives-considered)
- [References](#references)
<!--toc:end-->

## Status

Proposed

## Context

The macOS workstation (MacBook Pro, aarch64-darwin, hostname `donald-mbp`) needs declarative management of:

1. **CLI tools and development packages** — ripgrep, fd, bat, neovim, gh, kubectl, awscli, etc.
2. **GUI applications** — 1Password, Firefox, Docker Desktop, Raycast, Discord, etc.
3. **Mac App Store apps** — Amphetamine, Fantastical, Pixelmator Pro, etc.
4. **macOS system defaults** — Dock behavior, Finder preferences, key repeat rate, trackpad settings, keyboard remapping (Caps Lock → Escape).
5. **Shell environment** — zsh with zinit, starship prompt, fzf, zoxide, direnv, tmux.
6. **Dotfiles** — neovim (LazyVim), ghostty, starship, lazygit, yazi, bat, btop, sesh, eza configs.

The Nix ecosystem provides CLI packages well, but cannot install macOS `.app` bundles or Mac App Store apps. Homebrew handles these natively but is imperative by default. The challenge is combining both tools declaratively while sharing configuration with a NixOS workstation.

Additionally, the macOS machine uses the Determinate Systems Nix installer, which manages the Nix daemon itself — the nix-darwin `nix.enable` option must be set to `false` to avoid conflicts.

## Decision

Use **nix-darwin** as the system configuration framework for macOS, with the following specific choices:

1. **nix-darwin manages Homebrew declaratively** — all brews, casks, and Mac App Store apps are declared in `hosts/macbook/darwin.nix` under `homebrew.{brews,casks,masApps}`. Homebrew's `onActivation.cleanup = "zap"` ensures anything not declared is removed on rebuild.

2. **Home Manager as a darwin module** (not standalone) — HM is wired into `darwinSystem` via `home-manager.darwinModules.home-manager` so that `darwin-rebuild switch` applies both system and user config atomically.

3. **Determinate Nix compatibility** — `nix.enable = false` in `darwin.nix` since the Determinate Systems installer manages the Nix daemon, store, and flakes support independently.

4. **`mkOutOfStoreSymlink` for dotfiles** — raw config files in `config/` are symlinked into `~/.config` rather than copied into the Nix store, so edits to neovim, ghostty, starship, etc. take effect immediately without rebuilding.

5. **TouchID for sudo** — `security.pam.services.sudo_local.touchIdAuth = true` for ergonomic sudo on the MacBook.

6. **1Password SSH agent** — SSH authentication and git commit signing use the 1Password SSH agent at `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`.

7. **Shared common modules** — shell, git, ssh, neovim, tmux, mise, packages, and fonts are defined in `home/common/` and imported by `home/darwin.nix`, keeping them in sync with the NixOS workstation.

## Consequences

### Positive

- A single `sudo darwin-rebuild switch --flake ~/code/nix-config` applies all system, Homebrew, and user-level changes atomically
- GUI apps (casks) and Mac App Store apps are tracked declaratively in version control — a fresh MacBook can be fully provisioned from the flake
- `cleanup = "zap"` prevents Homebrew package accumulation — the declared state is the actual state
- Shared `home/common/` modules eliminate config drift between macOS and NixOS for CLI tools and shell setup
- Editing files in `config/` takes effect immediately without rebuilding

### Negative

- Two package managers (Nix + Homebrew) must coexist — potential for confusion about which manages what (rule: Nix for CLI, Homebrew for GUI apps and Mac-only brews)
- Homebrew `cleanup = "zap"` is aggressive — installing a cask manually and forgetting to add it to `darwin.nix` means it gets removed on next rebuild
- `mkOutOfStoreSymlink` files are not tracked by the Nix store — they depend on the git repo being present at the expected path (`~/code/nix-config/config/`)
- Determinate Nix requires `nix.enable = false`, which means nix-darwin cannot manage Nix settings (GC, trusted-users, etc.) — Determinate handles these separately

### Neutral

- macOS system defaults (`system.defaults`) cover most preferences but not all — some settings may still require manual `defaults write` commands
- Keyboard remapping (Caps Lock → Escape) is handled at the system level by nix-darwin, which works well for the built-in keyboard but external keyboards may need additional configuration
- The `mas` CLI (Mac App Store) requires being signed into the App Store first — this is a manual bootstrap step

## Alternatives Considered

**Homebrew only (no Nix)** — Homebrew can manage CLI tools via `brew install` but lacks reproducibility, atomic upgrades, and rollback. No declarative system defaults management. Would require a separate dotfile manager.

**Nix only (no Homebrew)** — Nix cannot install macOS `.app` bundles from cask taps or Mac App Store apps. Some macOS-specific tools (like `mas`) work better as brews. Nixpkgs has limited darwin GUI app support.

**Home Manager standalone (no nix-darwin)** — Loses declarative management of macOS system defaults, Homebrew, keyboard remapping, TouchID sudo, and fonts at the system level. Would require two separate commands (one for system, one for user config).

**chezmoi / GNU Stow for dotfiles** — Adds another tool to the stack. `mkOutOfStoreSymlink` achieves the same result within the Nix ecosystem and is configured alongside packages in the same module.

## References

- [RFC-0001: Multi-Platform Nix Configuration Management](../rfc/0001-multi-platform-nix-configuration-management.md)
- [nix-darwin](https://github.com/nix-darwin/nix-darwin)
- [Determinate Systems Nix Installer](https://github.com/DeterminateSystems/nix-installer)
- [nix-darwin Homebrew module](https://daiderd.com/nix-darwin/manual/index.html)
