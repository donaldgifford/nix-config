#!/usr/bin/env bash
# =============================================================================
# nixos-bootstrap.sh
# Partitions a disk with btrfs, mounts subvolumes, and installs NixOS.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/donaldgifford/nix-config/main/nixos-bootstrap.sh | bash
#   -- or --
#   bash nixos-bootstrap.sh
#
# Run from the NixOS live ISO as root (or with sudo).
# =============================================================================

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() {
  echo -e "${RED}[ERROR]${NC} $*"
  exit 1
}
prompt() { echo -e "${BOLD}[INPUT]${NC} $*"; }

# ── Config — edit these or they'll be prompted ────────────────────────────────
HOSTNAME=""     # e.g. "nixbox" — prompted if empty
USERNAME=""     # e.g. "donald" — prompted if empty
DISK=""         # e.g. "/dev/nvme0n1" or "/dev/sda" — prompted if empty
SWAP_SIZE="16G" # swap partition size
TIMEZONE="America/Detroit"

# Where to pull configuration.nix from once you have a repo.
# Leave empty to write an inline starter config instead.
CONFIG_URL=""
# e.g. CONFIG_URL="https://raw.githubusercontent.com/YOURNAME/dotfiles/main/nixos/configuration.nix"

# ── Sanity checks ─────────────────────────────────────────────────────────────
check_root() {
  if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root. Try: sudo bash nixos-bootstrap.sh"
  fi
}

check_nixos_iso() {
  if ! command -v nixos-install &>/dev/null; then
    error "nixos-install not found. Are you booted into the NixOS live ISO?"
  fi
}

check_deps() {
  for cmd in sgdisk mkfs.fat mkswap mkfs.btrfs btrfs git curl; do
    if ! command -v "$cmd" &>/dev/null; then
      error "Required command not found: $cmd"
    fi
  done
}

# ── User prompts ──────────────────────────────────────────────────────────────
gather_inputs() {
  echo ""
  echo -e "${BOLD}══════════════════════════════════════════${NC}"
  echo -e "${BOLD}       NixOS Bootstrap Installer          ${NC}"
  echo -e "${BOLD}══════════════════════════════════════════${NC}"
  echo ""

  if [[ -z "$DISK" ]]; then
    echo "Available disks:"
    lsblk -d -o NAME,SIZE,MODEL | grep -v loop
    echo ""
    prompt "Enter disk to install to (e.g. /dev/nvme0n1 or /dev/sda):"
    read -r DISK
  fi

  # Validate disk exists
  if [[ ! -b "$DISK" ]]; then
    error "Disk not found: $DISK"
  fi

  if [[ -z "$HOSTNAME" ]]; then
    prompt "Enter hostname for this machine:"
    read -r HOSTNAME
  fi

  if [[ -z "$USERNAME" ]]; then
    prompt "Enter your username:"
    read -r USERNAME
  fi

  # Confirm before doing anything destructive
  echo ""
  warn "This will COMPLETELY WIPE: ${DISK}"
  warn "Hostname: ${HOSTNAME} | User: ${USERNAME} | Swap: ${SWAP_SIZE}"
  echo ""
  prompt "Type 'yes' to continue, anything else to abort:"
  read -r CONFIRM
  if [[ "$CONFIRM" != "yes" ]]; then
    echo "Aborted."
    exit 0
  fi
}

# ── Partitioning ──────────────────────────────────────────────────────────────
partition_disk() {
  info "Wiping and partitioning ${DISK}..."

  # Wipe existing partition table
  sgdisk --zap-all "$DISK"
  partprobe "$DISK"
  sleep 1

  # Create partitions:
  # 1: EFI  (1 GiB,  FAT32)
  # 2: swap (SWAP_SIZE)
  # 3: root (remaining, btrfs)
  sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI" "$DISK"
  sgdisk -n 2:0:+${SWAP_SIZE} -t 2:8200 -c 2:"swap" "$DISK"
  sgdisk -n 3:0:0 -t 3:8300 -c 3:"root" "$DISK"

  partprobe "$DISK"
  sleep 2

  success "Partitioning complete"
}

# Resolve partition paths — handles both nvme (nvme0n1p1) and sata (sda1) naming
get_part() {
  local disk="$1" num="$2"
  if [[ "$disk" == *nvme* || "$disk" == *mmcblk* ]]; then
    echo "${disk}p${num}"
  else
    echo "${disk}${num}"
  fi
}

# ── Formatting ────────────────────────────────────────────────────────────────
format_partitions() {
  local efi swap root
  efi=$(get_part "$DISK" 1)
  swap=$(get_part "$DISK" 2)
  root=$(get_part "$DISK" 3)

  info "Formatting EFI partition: ${efi}"
  mkfs.fat -F32 -n EFI "$efi"

  info "Formatting swap partition: ${swap}"
  mkswap -L swap "$swap"

  info "Formatting root partition as btrfs: ${root}"
  mkfs.btrfs -L nixos -f "$root"

  success "Formatting complete"
}

# ── Btrfs subvolumes ──────────────────────────────────────────────────────────
create_subvolumes() {
  local root
  root=$(get_part "$DISK" 3)

  info "Creating btrfs subvolumes..."

  mount "$root" /mnt

  btrfs subvolume create /mnt/@
  btrfs subvolume create /mnt/@home
  btrfs subvolume create /mnt/@nix
  btrfs subvolume create /mnt/@log
  btrfs subvolume create /mnt/@snapshots

  umount /mnt

  success "Subvolumes created: @, @home, @nix, @log, @snapshots"
}

# ── Mounting ──────────────────────────────────────────────────────────────────
mount_partitions() {
  local efi swap root
  efi=$(get_part "$DISK" 1)
  swap=$(get_part "$DISK" 2)
  root=$(get_part "$DISK" 3)

  # Common btrfs mount options:
  # - compress=zstd:3  — transparent compression, level 3 is a good balance
  # - noatime          — don't update access times on reads (significant perf win on SSD)
  # - space_cache=v2   — improved free space tracking
  local OPTS="compress=zstd:3,noatime,space_cache=v2"

  info "Mounting subvolumes..."

  mount -o "subvol=@,${OPTS}" "$root" /mnt
  mkdir -p /mnt/{home,nix,var/log,.snapshots,boot}

  mount -o "subvol=@home,${OPTS}" "$root" /mnt/home
  mount -o "subvol=@nix,${OPTS}" "$root" /mnt/nix
  mount -o "subvol=@log,${OPTS}" "$root" /mnt/var/log
  mount -o "subvol=@snapshots,${OPTS}" "$root" /mnt/.snapshots
  mount "$efi" /mnt/boot

  swapon "$swap"

  success "All partitions mounted"
  info "Current mount layout:"
  lsblk "$DISK"
}

# ── NixOS config ──────────────────────────────────────────────────────────────
write_configuration() {
  info "Writing NixOS configuration..."

  mkdir -p /mnt/etc/nixos

  # If a CONFIG_URL is set, pull it down. Otherwise write a starter config.
  if [[ -n "$CONFIG_URL" ]]; then
    info "Pulling configuration.nix from: ${CONFIG_URL}"
    curl -fsSL "$CONFIG_URL" -o /mnt/etc/nixos/configuration.nix
    success "configuration.nix pulled from remote"
  else
    warn "No CONFIG_URL set — writing starter configuration.nix"
    write_starter_config
  fi
}

write_starter_config() {
  # This is a minimal but working config. Once you have your dotfiles repo,
  # replace this with a CONFIG_URL pointing to your full configuration.nix.
  cat >/mnt/etc/nixos/configuration.nix <<NIXCONFIG
{ config, pkgs, lib, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # ── Boot ────────────────────────────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 5;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Nvidia + Wayland — remove these if you don't have an Nvidia GPU
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia-drm.fbdev=1"
  ];
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

  # ── Filesystem ──────────────────────────────────────────────────────────────
  # hardware-configuration.nix handles the actual mount entries.
  # We just need to ensure btrfs tools are available.
  boot.supportedFilesystems = [ "btrfs" ];
  environment.systemPackages = [ pkgs.btrfs-progs ];

  # ── Networking ──────────────────────────────────────────────────────────────
  networking.hostName = "${HOSTNAME}";
  networking.networkmanager.enable = true;

  # ── Locale ──────────────────────────────────────────────────────────────────
  time.timeZone = "${TIMEZONE}";
  i18n.defaultLocale = "en_US.UTF-8";

  # ── Nvidia ──────────────────────────────────────────────────────────────────
  # Remove this entire block if you don't have an Nvidia GPU
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;           # supported on Turing (RTX 20xx) and newer as of driver 560+
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };

  # ── Sway + Wayland ──────────────────────────────────────────────────────────
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraPackages = with pkgs; [
      swaylock swayidle swaybg waybar wofi
      wl-clipboard grim slurp foot xdg-utils xwayland
    ];
  };

  environment.sessionVariables = {
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_NO_HARDWARE_CURSORS = "1";
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "\${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd sway";
      user = "greeter";
    };
  };

  # ── Audio ────────────────────────────────────────────────────────────────────
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };
  sound.enable = false;
  hardware.pulseaudio.enable = false;

  # ── DBus / Polkit ────────────────────────────────────────────────────────────
  services.dbus.enable = true;
  security.polkit.enable = true;

  # ── Packages ─────────────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    git vim wget curl htop pciutils usbutils
    ripgrep fd bat nvtopPackages.full
    btrfs-progs
  ];

  # ── Fonts ────────────────────────────────────────────────────────────────────
  fonts.packages = with pkgs; [
    noto-fonts noto-fonts-emoji
    (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
  ];

  # ── User ─────────────────────────────────────────────────────────────────────
  users.users.${USERNAME} = {
    isNormalUser = true;
    description = "${USERNAME}";
    extraGroups = [ "wheel" "networkmanager" "audio" "video" "input" ];
    shell = pkgs.zsh;
  };
  programs.zsh.enable = true;

  # ── Nix settings ─────────────────────────────────────────────────────────────
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    trusted-users = [ "root" "${USERNAME}" ];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.11";
}
NIXCONFIG

  success "Starter configuration.nix written"
  warn "Remember to set CONFIG_URL in this script once you have your dotfiles repo"
}

# ── Hardware config ───────────────────────────────────────────────────────────
generate_hardware_config() {
  info "Generating hardware-configuration.nix..."
  nixos-generate-config --root /mnt
  success "hardware-configuration.nix generated"
}

# ── Install ───────────────────────────────────────────────────────────────────
run_install() {
  info "Running nixos-install (this will take a while on first run)..."
  echo ""
  nixos-install --no-root-passwd
  # --no-root-passwd skips setting the root password here.
  # You'll set your user password on first login via `passwd`.
  echo ""
  success "nixos-install complete"
}

# ── Post-install summary ──────────────────────────────────────────────────────
print_summary() {
  echo ""
  echo -e "${BOLD}${GREEN}══════════════════════════════════════════${NC}"
  echo -e "${BOLD}${GREEN}         Installation Complete!           ${NC}"
  echo -e "${BOLD}${GREEN}══════════════════════════════════════════${NC}"
  echo ""
  echo -e "  Hostname : ${BOLD}${HOSTNAME}${NC}"
  echo -e "  User     : ${BOLD}${USERNAME}${NC}"
  echo -e "  Disk     : ${BOLD}${DISK}${NC}"
  echo -e "  FS       : ${BOLD}btrfs (subvols: @, @home, @nix, @log, @snapshots)${NC}"
  echo ""
  echo -e "  Next steps:"
  echo -e "  1. ${BOLD}reboot${NC} and remove the USB"
  echo -e "  2. Log in as root, then run: ${BOLD}passwd ${USERNAME}${NC} to set your password"
  echo -e "  3. Log in as ${USERNAME} — Sway should start via greetd"
  echo -e "  4. Set up your dotfiles repo and update CONFIG_URL in this script"
  echo ""
  echo -e "  Config is at: ${BOLD}/mnt/etc/nixos/${NC} (pre-reboot)"
  echo -e "  After reboot:  ${BOLD}/etc/nixos/${NC}"
  echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  check_root
  check_nixos_iso
  check_deps
  gather_inputs
  partition_disk
  format_partitions
  create_subvolumes
  mount_partitions
  write_configuration
  generate_hardware_config
  run_install
  print_summary
}

main "$@"
