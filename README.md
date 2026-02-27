# Nix Dotfiles

NixOS configuration for a 2080 Ti + Wayland + Sway setup. Managed declaratively via NixOS flakes and Home Manager.

---

## System

| | |
|---|---|
| **OS** | NixOS 25.11 |
| **GPU** | NVIDIA RTX 2080 Ti (Turing) |
| **Compositor** | Sway (Wayland) |
| **Shell** | Zsh |
| **Filesystem** | btrfs (subvolumes) |

---

## Fresh Install

Boot the [NixOS minimal ISO](https://nixos.org/download), connect to the internet, then run the bootstrap script. It will partition your disk, create btrfs subvolumes, pull the config, and install NixOS in one shot.

```bash
curl -fsSL https://raw.githubusercontent.com/donaldgifford/nix-config/main/nixos-bootstrap.sh | bash
```

The script will prompt you for:

- Which disk to install to (it will show you available disks first)
- Hostname
- Username

It will ask you to confirm before touching anything. After install completes, reboot and remove the USB.

### First Boot

Log in as root via the greetd terminal prompt and set your user password:

```bash
passwd YOURUSERNAME
```

Then log out of root and log in as your user. Sway will launch automatically.

---

## Updating

After making changes to any `.nix` file:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#YOURHOSTNAME
```

To update nixpkgs and all flake inputs to latest:

```bash
cd /etc/nixos
sudo nix flake update
sudo nixos-rebuild switch --flake /etc/nixos#YOURHOSTNAME
```

---

## Home Manager

Home Manager is included as a NixOS module and is applied automatically as part of `nixos-rebuild switch`. To apply Home Manager changes without a full system rebuild:

```bash
home-manager switch --flake /etc/nixos#YOURUSERNAME
```

---

## Structure

```
.
├── nixos-bootstrap.sh          # Run from live ISO to install from scratch
├── flake.nix                   # Flake entrypoint, defines hosts and HM configs
├── flake.lock                  # Pinned dependency graph — commit this
├── nixos/
│   └── configuration.nix       # Main system config (Nvidia, Sway, services)
├── home/
│   ├── home.nix                # Home Manager config (packages, shell, git, nvim)
│   └── modules/                # Split HM config (optional)
│       ├── git.nix
│       ├── neovim.nix
│       └── shell.nix
└── README.md
```

---

## Nvidia Notes

This config uses the open-source Nvidia kernel module (`hardware.nvidia.open = true`), supported on Turing (RTX 20xx) and newer since driver 560+. KMS is enabled via `nvidia-drm.modeset=1` which is required for Sway to start. If you're cloning this for an older GPU (GTX 10xx or earlier), set `open = false` in `nixos/configuration.nix`.

If you see an invisible cursor after logging in, `WLR_NO_HARDWARE_CURSORS=1` is already set in the config and should handle it. If Sway fails to start entirely, check:

```bash
systemctl status greetd
journalctl -u greetd -b
```

---

## Rollback

Every `nixos-rebuild switch` creates a new generation. To roll back to the previous one:

```bash
sudo nixos-rebuild switch --rollback
```

Or select a previous generation from the systemd-boot menu at startup (all generations are listed there).

To clean up old generations:

```bash
sudo nix-collect-garbage --delete-older-than 30d
sudo nixos-rebuild boot  # update bootloader entries after GC
```

---

## macOS / Home Manager Standalone

If you're using Home Manager standalone on macOS (without NixOS), install Nix first via the Determinate Systems installer:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

Then apply the Home Manager config:

```bash
home-manager switch --flake github:YOURNAME/dotfiles#YOURUSERNAME@darwin
```
