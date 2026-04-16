---
id: ADR-0002
title: "Use NixOS with Sway and Nvidia for Workstation"
status: Proposed
author: Donald Gifford
created: 2026-04-11
---
<!-- markdownlint-disable-file MD025 MD041 -->

# 0002. Use NixOS with Sway and Nvidia for Workstation

<!--toc:start-->
- [Status](#status)
- [Context](#context)
- [Decision](#decision)
  - [Kernel and Boot](#kernel-and-boot)
  - [Nvidia Configuration](#nvidia-configuration)
  - [Wayland Environment](#wayland-environment)
  - [Display and Login](#display-and-login)
  - [Audio](#audio)
  - [System Services](#system-services)
  - [User and Home Manager](#user-and-home-manager)
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

The workstation is a desktop machine with an Nvidia RTX 2080 Ti (Turing architecture) GPU, running x86_64-linux. It needs:

1. **A fully declarative OS** — the entire system configuration (kernel, drivers, services, packages, user environment) should be version-controlled and reproducible.
2. **A tiling Wayland compositor** — keyboard-driven workflow, no traditional desktop environment overhead.
3. **Nvidia driver support under Wayland** — the RTX 2080 Ti requires proprietary Nvidia drivers with specific kernel module settings to work with wlroots-based compositors.
4. **Shared configuration with macOS** — CLI tools, shell setup, git config, and editor should be identical to the MacBook environment.
5. **btrfs filesystem** — snapshots, compression, and subvolume management.
6. **PipeWire audio** — modern audio stack replacing PulseAudio with JACK compatibility.

The main tension is Nvidia + Wayland: this combination requires careful driver configuration that differs from both Nvidia+X11 and AMD+Wayland setups.

## Decision

Use **NixOS** as the operating system with **Sway** as the Wayland compositor and the **Nvidia open kernel module**, with the following specific choices:

### Kernel and Boot

- **LTS kernel** (`pkgs.linuxPackages`) — more stable with Nvidia out-of-tree modules than `linuxPackages_latest`
- **systemd-boot** — simple UEFI bootloader with automatic NixOS generation entries; limited to 5 generations to avoid filling `/boot`
- **Early Nvidia module loading** — `nvidia`, `nvidia_modeset`, `nvidia_uvm`, `nvidia_drm` loaded in initrd for KMS from boot

### Nvidia Configuration

- **Open kernel module** (`hardware.nvidia.open = true`) — supported on Turing (RTX 20xx) and newer since driver 560+
- **KMS enabled** — `nvidia-drm.modeset=1` and `nvidia-drm.fbdev=1` kernel parameters, required for Sway to start
- **Stable driver package** — `config.boot.kernelPackages.nvidiaPackages.stable`
- **VA-API hardware video decoding** — `nvidia-vaapi-driver` in `hardware.graphics.extraPackages`
- **32-bit graphics support** — `hardware.graphics.enable32Bit = true` for Steam/Wine compatibility

### Wayland Environment

- **Sway** via `programs.sway.enable` — handles PAM, polkit, and DBus integration correctly
- **`--unsupported-gpu` flag** — passed to Sway via greetd since wlroots does not officially support Nvidia
- **Environment variables** — `GBM_BACKEND=nvidia-drm`, `__GLX_VENDOR_LIBRARY_NAME=nvidia`, `WLR_NO_HARDWARE_CURSORS=1`, `NIXOS_OZONE_WL=1` (Electron), `MOZ_ENABLE_WAYLAND=1` (Firefox)
- **`WLR_DRM_DEVICES=/dev/dri/card1`** — Nvidia often enumerates as card1 because an EFI framebuffer driver grabs card0 first

### Display and Login

- **greetd + tuigreet** — lightweight, Wayland-native TUI greeter
- **XDG portal** — wlr portal + GTK portal for screen sharing and file pickers

### Audio

- **PipeWire** with ALSA, PulseAudio compat, JACK compat, and WirePlumber session manager
- PulseAudio explicitly disabled to avoid conflicts

### System Services

- **1Password** — system-level install with polkit integration for CLI and GUI
- **gnome-keyring** — DBus secrets storage
- **OpenSSH** — enabled with password authentication
- **Bluetooth** — enabled with Blueman manager
- **nix-ld** — dynamic linker for running unpatched binaries (links stdenv, zlib, openssl, glib)

### User and Home Manager

- **Home Manager as NixOS module** — `home-manager.nixosModules.home-manager` in `flake.nix`
- **Shared common modules** — `home/linux.nix` imports `home/common/*` plus linux-specific modules (`home/linux/sway.nix`, `waybar.nix`, `wofi.nix`, `swaylock.nix`)
- **Immutable users** — `users.mutableUsers = false` with hashed passwords in config

## Consequences

### Positive

- The entire system is reproducible from `flake.nix` — a fresh install requires only the bootstrap script and one `nixos-rebuild switch`
- Generational rollback is trivial — every `nixos-rebuild switch` creates a new generation selectable from the boot menu
- Shared `home/common/` modules keep CLI tools, shell, git, and editor config identical to macOS
- Declarative Nvidia configuration avoids the usual pain of manual driver installation and DKMS
- Weekly automatic garbage collection (`nix.gc`) prevents store bloat

### Negative

- **Nvidia + Sway is unsupported upstream** — the `--unsupported-gpu` flag is required, and some features (hardware cursors) must be disabled via `WLR_NO_HARDWARE_CURSORS=1`
- **`WLR_DRM_DEVICES` may need adjustment** — the card0/card1 enumeration can change with kernel updates or hardware changes
- **Immutable users** means password changes require editing `configuration.nix` and rebuilding — or using `passwd` which gets overwritten on next rebuild
- **Open kernel module on Turing** — while supported, it is less tested than on Ampere+ GPUs; fallback to `open = false` may be needed
- **LTS kernel** may lag behind on hardware support for newer peripherals

### Neutral

- systemd-boot's 5-generation limit is a trade-off between boot menu clutter and rollback depth — old generations are still in the store until GC
- btrfs is well-supported on NixOS but adds complexity for users unfamiliar with subvolumes
- XWayland is included for X11 app compatibility, which covers most Electron apps that haven't migrated to native Wayland

## Alternatives Considered

**GNOME or KDE on Wayland** — full desktop environments with better Nvidia support out of the box, but heavier, less keyboard-driven, and harder to configure declaratively. Sway's i3-compatible config is well-understood and minimal.

**X11 with i3** — avoids all Nvidia+Wayland pain. Rejected because Wayland is the future of Linux display, and the specific issues (cursors, DRM device enumeration) have known workarounds.

**AMD GPU** — would eliminate all Nvidia-specific configuration. Not practical without replacing hardware.

**Arch Linux / Fedora** — not declarative or reproducible. No generational rollback. Would require a separate config management tool (Ansible, etc.) to achieve what NixOS provides natively.

**Hyprland instead of Sway** — more modern Wayland compositor with better Nvidia support and animations. Rejected for now in favor of Sway's maturity and stability, but worth revisiting.

## References

- [RFC-0001: Multi-Platform Nix Configuration Management](../rfc/0001-multi-platform-nix-configuration-management.md)
- [NixOS Wiki: Nvidia](https://nixos.wiki/wiki/Nvidia)
- [Sway Wiki: Nvidia](https://github.com/swaywm/sway/wiki#nvidia-users)
- [NixOS Manual: Sway](https://nixos.wiki/wiki/Sway)
