# NixOS: Nvidia + Wayland + Sway & Home Manager Guide

---

## Part 1: NixOS from Scratch with Nvidia, Wayland, and Sway

---

### 1.1 Understanding the NixOS Mental Model

Before touching an installer, it's worth internalizing how NixOS differs from every other Linux distribution. NixOS is a **declarative** operating system — your entire system configuration lives in one or more `.nix` files, typically rooted at `/etc/nixos/configuration.nix`. There is no "running a bunch of commands and hoping the state is right." You describe what you want, run `nixos-rebuild switch`, and the system converges to that declaration. Packages are immutable, stored in `/nix/store` with content-addressed paths (e.g., `/nix/store/abc123-firefox-110.0`), and multiple versions can coexist without conflict. Rollback is a first-class citizen — every generation you build is bootable from GRUB.

The Nvidia + Wayland combination has historically been painful on any distro. On NixOS it's more manageable because you're declaring driver state explicitly rather than fighting dpkg hooks, but there are still real gotchas. Sway is a Wayland compositor that is Wayland-native and works extremely well, but it assumes KMS (kernel mode setting), which Nvidia partially resists. The combination works well as of late 2024/2025 but requires specific knobs to be turned.

---

### 1.2 Installation Media

Download the NixOS minimal ISO from <https://nixos.org/download>. The graphical installer is fine for hardware detection, but the minimal ISO gives you more control and is what this guide assumes. Write it to USB with:

```bash
dd if=nixos-minimal-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Boot into the live environment. You'll land at a bash shell as `nixos` with sudo access.

---

### 1.3 Partitioning

This guide uses GPT with UEFI. Adapt for BIOS/MBR if needed, but UEFI is strongly recommended for modern Nvidia systems since UEFI + KMS tends to behave better.

```bash
# Identify your disk
lsblk

# Partition with fdisk or gdisk — example using sgdisk
sgdisk --zap-all /dev/nvme0n1
sgdisk -n 1:0:+1G   -t 1:ef00 -c 1:"EFI"   /dev/nvme0n1   # EFI partition
sgdisk -n 2:0:+16G  -t 2:8200 -c 2:"swap"  /dev/nvme0n1   # swap (match RAM or 16G)
sgdisk -n 3:0:0     -t 3:8300 -c 3:"root"  /dev/nvme0n1   # root, rest of disk
```

Format the partitions:

```bash
mkfs.fat -F32 -n EFI /dev/nvme0n1p1
mkswap -L swap /dev/nvme0n1p2
mkfs.ext4 -L nixos /dev/nvme0n1p3
# If you prefer btrfs (recommended for snapshotting):
mkfs.btrfs -L nixos /dev/nvme0n1p3
```

For btrfs, create subvolumes for clean snapshot management:

```bash
mount /dev/nvme0n1p3 /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@log
umount /mnt

mount -o subvol=@,compress=zstd,noatime /dev/nvme0n1p3 /mnt
mkdir -p /mnt/{home,nix,var/log,boot}
mount -o subvol=@home,compress=zstd,noatime /dev/nvme0n1p3 /mnt/home
mount -o subvol=@nix,compress=zstd,noatime  /dev/nvme0n1p3 /mnt/nix
mount -o subvol=@log,compress=zstd,noatime  /dev/nvme0n1p3 /mnt/var/log
mount /dev/nvme0n1p1 /mnt/boot
swapon /dev/nvme0n1p2
```

---

### 1.4 Generating and Editing the Base Configuration

```bash
nixos-generate-config --root /mnt
```

This writes `/mnt/etc/nixos/hardware-configuration.nix` (auto-generated, don't heavily edit) and `/mnt/etc/nixos/configuration.nix` (your main config). Open the main config in the live environment's editor:

```bash
nano /mnt/etc/nixos/configuration.nix
```

---

### 1.5 The Full configuration.nix

Below is a production-quality `configuration.nix` for Nvidia + Wayland + Sway. Every meaningful option is explained inline.

```nix
{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # ── Bootloader ──────────────────────────────────────────────────────────────
  # systemd-boot is simpler than GRUB for UEFI systems and integrates well
  # with NixOS generations. Each generation appears as a separate boot entry.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Keep the last 5 generations in the boot menu to avoid filling /boot
  boot.loader.systemd-boot.configurationLimit = 5;

  # ── Kernel ───────────────────────────────────────────────────────────────────
  # Use the latest LTS kernel. Nvidia requires out-of-tree modules, so NixOS
  # rebuilds them against whatever kernel you choose. Latest LTS is the sweet
  # spot between driver support and stability.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Kernel parameters critical for Nvidia + Wayland:
  # - nvidia-drm.modeset=1: enables KMS (kernel modesetting) for Nvidia,
  #   required for Wayland to work. Without this, Sway will not start.
  # - nvidia-drm.fbdev=1: enables framebuffer device support (needed on newer
  #   driver versions for VT switching)
  # - mem_sleep_default=deep: better suspend behavior with Nvidia
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia-drm.fbdev=1"
    "mem_sleep_default=deep"
  ];

  # Load Nvidia modules early in the initrd so KMS is active from boot
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

  # ── Networking ───────────────────────────────────────────────────────────────
  networking.hostName = "yourhostname";
  networking.networkmanager.enable = true;

  # ── Locale / Time ────────────────────────────────────────────────────────────
  time.timeZone = "America/Detroit";
  i18n.defaultLocale = "en_US.UTF-8";

  # ── Nvidia Driver Configuration ───────────────────────────────────────────────
  # NixOS wraps the Nvidia proprietary driver with a lot of configuration.
  # The key insight: you MUST use the nixpkgs Nvidia module — don't try to
  # install the driver manually from nvidia.com, it will break the module system.

  # Tell NixOS which video driver to use
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # The "modesetting" option is what wires up nvidia-drm.modeset=1 at the
    # driver level. Must be true for Wayland/Sway.
    modesetting.enable = true;

    # Power management: the open-source nvidia module has better power
    # management on Ampere+ GPUs. The proprietary kernel module is the default.
    # Set to true for experimental (but often better) power management.
    powerManagement.enable = false;
    powerManagement.finegrained = false;

    # Use the open-source kernel module (available since driver 515+).
    # For Ampere (RTX 30xx) and newer: set to true for better compatibility.
    # For older GPUs (Turing / RTX 20xx, GTX 16xx): keep false.
    open = false; # change to true if you have RTX 30xx or newer

    # NVIDIA settings GUI app — useful for quick adjustments
    nvidiaSettings = true;

    # Driver package selection. "stable" tracks the latest production driver.
    # Other options: beta, production, legacy_470, legacy_390.
    # Check https://nixos.wiki/wiki/Nvidia for version mapping.
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Enable OpenGL (required for Wayland hardware acceleration)
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true; # for 32-bit apps (Steam, Wine)
    extraPackages = with pkgs; [
      nvidia-vaapi-driver  # VA-API support for hardware video decoding
      vaapiVdpau
      libvdpau-va-gl
    ];
  };

  # ── Wayland Environment Variables ────────────────────────────────────────────
  # These are system-wide environment variables. Some apps (Electron, Firefox,
  # Chromium) need hints to use Wayland rendering rather than XWayland fallback.
  environment.sessionVariables = {
    # Tell the Nvidia EGL driver to use the correct platform
    # GBM is the buffer manager Wayland compositors use
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";

    # Use EGL for hardware acceleration on Wayland
    WLR_NO_HARDWARE_CURSORS = "1"; # fixes cursor issues on Nvidia with wlroots

    # Optional: force Wayland for specific toolkits
    NIXOS_OZONE_WL = "1";   # Electron apps use Wayland
    MOZ_ENABLE_WAYLAND = "1"; # Firefox Wayland
    QT_QPA_PLATFORM = "wayland";
    SDL_VIDEODRIVER = "wayland";
    _JAVA_AWT_WM_NONREPARENTING = "1"; # Java Swing apps in tiling WMs
  };

  # ── Sway ──────────────────────────────────────────────────────────────────────
  # Sway is a Wayland compositor implementing the i3 layout protocol.
  # "programs.sway" handles PAM integration, polkit, and DBus correctly.
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true; # fixes GTK apps not applying themes
    extraPackages = with pkgs; [
      swaylock       # screen locker
      swayidle       # idle daemon (dim/lock/suspend)
      swaybg         # wallpaper setter
      swaynotificationcenter  # notification daemon (or use mako)
      waybar         # status bar (highly configurable)
      wofi           # app launcher (rofi-wayland alternative)
      wl-clipboard   # wl-copy / wl-paste CLI tools
      grim           # screenshot tool
      slurp          # region selection for screenshots
      xdg-utils      # xdg-open, xdg-mime
      xwayland       # XWayland for X11 app compatibility
      foot           # terminal emulator (pure Wayland, fast)
      kanshi         # dynamic display configuration
    ];
  };

  # XDG portal enables screen sharing, file pickers, etc. via DBus
  # The wlr portal is specifically for wlroots-based compositors (Sway)
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };

  # ── Display Manager / Login ──────────────────────────────────────────────────
  # greetd + tuigreet is a lightweight, Wayland-native greeter.
  # Alternatively, you can disable the display manager entirely and start
  # Sway from TTY with `exec sway` in ~/.bash_profile (simpler but less polished).
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd sway";
        user = "greeter";
      };
    };
  };

  # ── Audio ─────────────────────────────────────────────────────────────────────
  # PipeWire is the modern audio system. It handles PulseAudio compatibility,
  # JACK compatibility, and Bluetooth. ALSA alone is not sufficient for Sway.
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;    # PulseAudio compatibility shim
    jack.enable = true;     # JACK compatibility
    wireplumber.enable = true; # session/policy manager for PipeWire
  };
  # Disable PulseAudio (PipeWire replaces it)
  sound.enable = false;
  hardware.pulseaudio.enable = false;

  # ── Bluetooth ─────────────────────────────────────────────────────────────────
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # ── DBus / PolicyKit ─────────────────────────────────────────────────────────
  # Required for privileged operations (mounting, shutdown, etc.) in a
  # compositor-only environment (no full DE like GNOME)
  services.dbus.enable = true;
  security.polkit.enable = true;

  # ── Fonts ─────────────────────────────────────────────────────────────────────
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    (nerdfonts.override { fonts = [ "JetBrainsMono" "FiraCode" "Hack" ]; })
  ];

  # ── System Packages ───────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    htop
    pciutils   # lspci
    usbutils   # lsusb
    file
    unzip
    zip
    ripgrep
    fd
    bat
    nvtopPackages.full  # Nvidia GPU monitor (like htop for GPU)
  ];

  # ── User Account ──────────────────────────────────────────────────────────────
  users.users.donald = {
    isNormalUser = true;
    description = "Donald";
    extraGroups = [
      "wheel"          # sudo
      "networkmanager" # manage network connections
      "audio"          # direct audio access
      "video"          # GPU/display access
      "input"          # input devices
      "docker"         # if using Docker
    ];
    shell = pkgs.fish; # or bash, zsh
  };

  # ── Nix Settings ─────────────────────────────────────────────────────────────
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true; # deduplicate identical files in /nix/store
      trusted-users = [ "root" "donald" ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # Allow unfree packages (Nvidia driver, VS Code, etc.)
  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "24.11"; # Set to the NixOS version you installed
}
```

---

### 1.6 Installing

With the config written:

```bash
nixos-install
# You'll be prompted to set the root password
# After install completes:
reboot
```

On first boot, log in as root or your user via greetd/tuigreet, and Sway should launch.

---

### 1.7 Verifying Nvidia + Wayland is Working

Once in Sway, open a terminal (`foot` is bound to `$mod+Return` in Sway's default config) and run:

```bash
# Confirm Nvidia driver is loaded
lsmod | grep nvidia

# Check KMS is enabled
cat /sys/module/nvidia_drm/parameters/modeset
# Should output: Y

# Check DRM device exists
ls /dev/dri/

# Verify Wayland session
echo $WAYLAND_DISPLAY
# Should output: wayland-1 (or similar)

# Check OpenGL renderer is Nvidia (not llvmpipe/software)
glxinfo | grep "OpenGL renderer"

# GPU monitoring
nvtop
```

---

### 1.8 Sway Configuration

Sway's user config lives at `~/.config/sway/config`. On first launch Sway looks for this file; if absent it uses a default config. Here's a solid starting point that's Nvidia-aware:

<!-- markdownlint-disable MD040 -->
```
# ~/.config/sway/config

# Set the modifier key (Mod4 = Super/Windows key)
set $mod Mod4

# Terminal
set $term foot

# Application launcher
set $menu wofi --show drun --lines 10 --prompt "Launch"

# Output configuration (adjust to your monitor)
# Run `swaymsg -t get_outputs` to list outputs
output DP-1 resolution 2560x1440 position 0,0 scale 1

# Wallpaper
output * bg /path/to/wallpaper.jpg fill

# Font
font pango:JetBrainsMono Nerd Font 10

# Key bindings
bindsym $mod+Return exec $term
bindsym $mod+d exec $menu
bindsym $mod+Shift+q kill
bindsym $mod+Shift+e exec swaynag -t warning -m 'Exit sway?' -B 'Yes' 'swaymsg exit'

# Screenshot
bindsym Print exec grim ~/screenshots/$(date +%Y%m%d_%H%M%S).png
bindsym Shift+Print exec grim -g "$(slurp)" ~/screenshots/$(date +%Y%m%d_%H%M%S).png

# Volume (PipeWire/PulseAudio)
bindsym XF86AudioRaiseVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bindsym XF86AudioLowerVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindsym XF86AudioMute exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle

# Brightness (install brightnessctl)
bindsym XF86MonBrightnessUp exec brightnessctl set +5%
bindsym XF86MonBrightnessDown exec brightnessctl set 5%-

# Workspaces
bindsym $mod+1 workspace number 1
# ... through 10

# Start waybar as the status bar
bar {
    swaybar_command waybar
}

# Autostart
exec --no-startup-id nm-applet --indicator
exec --no-startup-id swayidle -w \
    timeout 300 'swaylock -f -c 000000' \
    timeout 600 'swaymsg "output * power off"' \
    resume 'swaymsg "output * power on"'

# Input (keyboard, touchpad)
input "type:keyboard" {
    xkb_layout us
    repeat_delay 300
    repeat_rate 50
}
input "type:touchpad" {
    tap enabled
    natural_scroll enabled
    dwt enabled
}
```
<!-- markdownlint-enable MD040 -->

---

### 1.9 Enabling Flakes (Strongly Recommended)

Flakes give you pinned, reproducible dependency graphs. Once you're booted, convert your setup to use flakes. Create `/etc/nixos/flake.nix`:

```nix
{
  description = "NixOS system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... } @ inputs: {
    nixosConfigurations."yourhostname" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.donald = import ./home.nix;
        }
      ];
    };
  };
}
```

Then rebuild with:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#yourhostname
```

---

## Part 2: Home Manager — Complete Guide for Linux and macOS

---

### 2.1 What is Home Manager

Home Manager (HM) is a Nix-based system for declaratively managing your user environment — dotfiles, packages, shell configuration, services, and more — using the same mental model as NixOS but scoped to `$HOME`. It works on NixOS (as a module), non-NixOS Linux (standalone), and macOS (standalone or via nix-darwin).

The core value proposition: instead of scattered dotfiles, symlinks managed by chezmoi/stow, and manually installed per-user tools, everything is declared in `~/.config/home-manager/home.nix` (or wherever you point it), versioned in git, and applied atomically.

---

### 2.2 Installation

**On NixOS** (the cleanest option): Home Manager runs as a NixOS module. Add it to your flake as shown in section 1.9 above. You get `nixos-rebuild switch` managing both the OS and your home environment in one command.

**Standalone on Linux or macOS**: First install Nix if on macOS (use the Determinate Systems installer for macOS, it handles SIP and multi-user installs properly):

```bash
# Determinate Systems nix installer (recommended for macOS and non-NixOS Linux)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# Reload shell to get nix in PATH
exec $SHELL

# Enable flakes (if not already done by installer)
mkdir -p ~/.config/nix
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
```

Initialize Home Manager as a standalone flake:

```bash
nix run home-manager/master -- init --switch
```

This creates `~/.config/home-manager/flake.nix` and `~/.config/home-manager/home.nix` and performs a first switch. After that, run `home-manager switch` to apply changes (or `home-manager switch --flake ~/.config/home-manager` if using flakes explicitly).

---

### 2.3 The Flake Structure

After init, your `~/.config/home-manager/flake.nix` looks like:

```nix
{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      # Change this to your system: "x86_64-linux", "aarch64-linux", "aarch64-darwin", "x86_64-darwin"
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      homeConfigurations."donald" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home.nix ];
      };
    };
}
```

If you want to manage multiple machines or users from the same flake (great for your homelab + work setup), add more configurations:

```nix
homeConfigurations = {
  "donald@workstation" = home-manager.lib.homeManagerConfiguration {
    pkgs = nixpkgs.legacyPackages."x86_64-linux";
    modules = [ ./home-linux.nix ];
  };
  "donald@macbook" = home-manager.lib.homeManagerConfiguration {
    pkgs = nixpkgs.legacyPackages."aarch64-darwin";
    modules = [ ./home-darwin.nix ];
  };
};
```

Apply a specific one with: `home-manager switch --flake ~/.config/home-manager#donald@workstation`

---

### 2.4 The home.nix — Core Structure

```nix
{ config, pkgs, lib, ... }:

{
  # Required: your username and home directory
  home.username = "donald";
  home.homeDirectory = "/home/donald";  # macOS: "/Users/donald"

  # Required: Home Manager release version for backward compat
  home.stateVersion = "24.11";

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # ── Packages ────────────────────────────────────────────────────────────────
  home.packages = with pkgs; [
    # CLI tools
    ripgrep
    fd
    bat
    eza           # modern ls replacement
    fzf
    zoxide        # smart cd
    starship      # cross-shell prompt
    direnv        # per-directory env vars / nix shells
    nix-direnv    # direnv integration for nix shells
    jq
    yq
    httpie
    delta         # better git diff

    # Dev
    go
    gopls
    golangci-lint
    rust-analyzer
    nodejs
    python3

    # Cloud / Infra
    awscli2
    kubectl
    helm
    terraform
    k9s
    fluxcd

    # macOS or Linux specific using lib.optionals:
  ] ++ lib.optionals pkgs.stdenv.isLinux [
    # Linux-only packages
    wl-clipboard
    xdg-utils
  ] ++ lib.optionals pkgs.stdenv.isDarwin [
    # macOS-only packages
    mas    # Mac App Store CLI
  ];
}
```

---

### 2.5 Shell Configuration

Home Manager has first-class support for most shells. Here's a comprehensive fish + zsh setup:

```nix
# Fish shell
programs.fish = {
  enable = true;
  shellAliases = {
    ls  = "eza --icons";
    ll  = "eza -la --icons --git";
    lt  = "eza --tree --icons -L 3";
    cat = "bat";
    cd  = "z";  # zoxide
    k   = "kubectl";
    tf  = "terraform";
  };
  shellInit = ''
    # Disable fish greeting
    set -g fish_greeting ""

    # zoxide init
    zoxide init fish | source

    # direnv hook
    direnv hook fish | source
  '';
  plugins = [
    {
      name = "autopair";
      src = pkgs.fishPlugins.autopair;
    }
    {
      name = "fzf-fish";
      src = pkgs.fishPlugins.fzf-fish;
    }
  ];
};

# Zsh (if you prefer zsh)
programs.zsh = {
  enable = true;
  autocd = true;
  enableCompletion = true;
  syntaxHighlighting.enable = true;
  autosuggestion.enable = true;
  history = {
    size = 50000;
    save = 50000;
    share = true;
    ignoreDups = true;
    ignoreSpace = true;
  };
  shellAliases = {
    ls  = "eza --icons";
    ll  = "eza -la --icons --git";
    cat = "bat";
    k   = "kubectl";
  };
  initExtra = ''
    eval "$(zoxide init zsh)"
    eval "$(direnv hook zsh)"
    eval "$(starship init zsh)"
  '';
  oh-my-zsh = {
    enable = true;
    plugins = [ "git" "kubectl" "aws" "docker" "fzf" ];
  };
};
```

---

### 2.6 Git Configuration

```nix
programs.git = {
  enable = true;
  userName  = "Donald";
  userEmail = "donald@example.com";

  signing = {
    key = "~/.ssh/id_ed25519.pub";
    signByDefault = true;
    format = "ssh"; # use SSH signing instead of GPG
  };

  aliases = {
    s   = "status -sb";
    lg  = "log --oneline --graph --decorate";
    co  = "checkout";
    br  = "branch";
    undo = "reset HEAD~1 --mixed";
    amend = "commit --amend --no-edit";
  };

  extraConfig = {
    init.defaultBranch = "main";
    pull.rebase = true;
    push.autoSetupRemote = true;
    rerere.enabled = true;
    fetch.prune = true;
    diff.tool = "delta";

    core = {
      editor = "nvim";
      autocrlf = "input";
      pager = "delta";
    };

    interactive.diffFilter = "delta --color-only";

    delta = {
      navigate = true;
      light = false;
      side-by-side = true;
      line-numbers = true;
    };
  };

  ignores = [
    ".DS_Store"
    ".direnv"
    ".envrc"
    "*.swp"
    "*.swo"
    ".idea/"
    ".vscode/"
    "node_modules/"
    "__pycache__/"
  ];
};
```

---

### 2.7 Neovim Configuration

Home Manager can manage Neovim with plugins declaratively:

```nix
programs.neovim = {
  enable = true;
  defaultEditor = true;
  viAlias  = true;
  vimAlias = true;

  plugins = with pkgs.vimPlugins; [
    # LSP
    nvim-lspconfig
    nvim-cmp
    cmp-nvim-lsp
    cmp-buffer
    cmp-path
    luasnip

    # Treesitter (syntax highlighting)
    (nvim-treesitter.withPlugins (p: with p; [
      nix go rust python typescript lua bash json yaml toml
    ]))

    # UI
    telescope-nvim
    telescope-fzf-native-nvim
    neo-tree-nvim
    lualine-nvim
    bufferline-nvim
    which-key-nvim

    # Git
    gitsigns-nvim
    vim-fugitive

    # Misc
    nvim-autopairs
    comment-nvim
    indent-blankline-nvim

    # Colorscheme
    catppuccin-nvim
  ];

  extraLuaConfig = ''
    vim.opt.number = true
    vim.opt.relativenumber = true
    vim.opt.expandtab = true
    vim.opt.shiftwidth = 2
    vim.opt.tabstop = 2
    vim.opt.smartindent = true
    vim.opt.termguicolors = true
    vim.opt.undofile = true
    vim.opt.ignorecase = true
    vim.opt.smartcase = true
    vim.opt.splitbelow = true
    vim.opt.splitright = true

    -- Colorscheme
    vim.cmd.colorscheme("catppuccin-mocha")

    -- Leader key
    vim.g.mapleader = " "

    -- Keymaps
    local map = vim.keymap.set
    map("n", "<leader>ff", "<cmd>Telescope find_files<cr>")
    map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>")
    map("n", "<leader>e",  "<cmd>Neotree toggle<cr>")
    map("n", "<C-h>", "<C-w>h")
    map("n", "<C-l>", "<C-w>l")
    map("n", "<C-j>", "<C-w>j")
    map("n", "<C-k>", "<C-w>k")
  '';
};
```

---

### 2.8 Terminal Emulators

```nix
# Foot (Wayland-native, fast — ideal for Sway)
programs.foot = {
  enable = true;
  settings = {
    main = {
      term = "xterm-256color";
      font = "JetBrainsMono Nerd Font:size=12";
      dpi-aware = "yes";
    };
    colors = {
      background = "1e1e2e";
      foreground = "cdd6f4";
    };
    scrollback.lines = 10000;
  };
};

# Alacritty (cross-platform, GPU-accelerated, good for macOS parity)
programs.alacritty = {
  enable = true;
  settings = {
    window = {
      padding = { x = 8; y = 8; };
      decorations = "none";  # borderless on Linux
      opacity = 0.95;
    };
    font = {
      normal.family = "JetBrainsMono Nerd Font";
      size = 12.0;
    };
    colors = {
      primary = {
        background = "0x1e1e2e";
        foreground = "0xcdd6f4";
      };
    };
  };
};

# Kitty (also cross-platform, good macOS native feel)
programs.kitty = {
  enable = true;
  font = {
    name = "JetBrainsMono Nerd Font";
    size = 12;
  };
  settings = {
    background_opacity = "0.95";
    window_padding_width = 8;
    confirm_os_window_close = 0;
  };
};
```

---

### 2.9 SSH Configuration

```nix
programs.ssh = {
  enable = true;
  addKeysToAgent = "yes";  # auto-add keys on first use

  matchBlocks = {
    "github.com" = {
      hostname = "github.com";
      user = "git";
      identityFile = "~/.ssh/id_ed25519";
    };
    "homelab" = {
      hostname = "192.168.1.100";
      user = "donald";
      identityFile = "~/.ssh/id_ed25519";
      forwardAgent = true;
    };
    "*.internal" = {
      user = "donald";
      identityFile = "~/.ssh/id_ed25519";
      serverAliveInterval = 60;
      serverAliveCountMax = 3;
    };
  };
};
```

---

### 2.10 Environment Variables and Session Variables

```nix
# Environment variables available to all processes started from the user session
home.sessionVariables = {
  EDITOR  = "nvim";
  VISUAL  = "nvim";
  PAGER   = "bat --plain";
  MANPAGER = "sh -c 'col -bx | bat -l man -p'";

  # Go
  GOPATH  = "$HOME/go";
  GOBIN   = "$HOME/go/bin";

  # Rust
  CARGO_HOME = "$HOME/.cargo";

  # AWS
  AWS_PAGER = "bat --plain --language=json";
};

# Add directories to PATH
home.sessionPath = [
  "$HOME/go/bin"
  "$HOME/.cargo/bin"
  "$HOME/.local/bin"
];
```

---

### 2.11 Managing Dotfiles Directly (home.file)

For config files that don't have a dedicated Home Manager module, use `home.file`:

```nix
home.file = {
  # Copy a file literally
  ".config/starship.toml".source = ./starship.toml;

  # Write content inline
  ".config/btop/btop.conf".text = ''
    color_theme = "catppuccin_mocha"
    vim_keys = true
    update_ms = 1000
  '';

  # Reference a directory
  ".config/sway".source = ./sway;

  # Link (symlink) rather than copy
  ".config/nvim".source = config.lib.file.mkOutOfStoreSymlink
    "/home/donald/dotfiles/nvim";
};
```

The `mkOutOfStoreSymlink` pattern is especially useful for Neovim configs you're actively editing — it creates a symlink to your live dotfiles repo rather than copying to the immutable nix store, so changes take effect immediately without a `home-manager switch`.

---

### 2.12 macOS-Specific Configuration

On macOS, some things need special handling. Create a `home-darwin.nix` or gate sections with `lib.mkIf`:

```nix
{ config, pkgs, lib, ... }:

{
  # macOS home directory
  home.homeDirectory = lib.mkForce "/Users/donald";

  # macOS-specific packages
  home.packages = with pkgs; lib.optionals stdenv.isDarwin [
    coreutils     # GNU coreutils (macOS ships with BSD versions)
    gnused
    gnugrep
    gawk
    findutils
    mas           # Mac App Store CLI
  ];

  # Homebrew integration (if you use brew alongside nix)
  # Home Manager doesn't manage brew, but you can set PATH to include it
  home.sessionPath = lib.mkIf pkgs.stdenv.isDarwin [
    "/opt/homebrew/bin"   # Apple Silicon homebrew
    "/usr/local/bin"      # Intel homebrew
  ];

  # macOS defaults via nix-darwin (if using nix-darwin, not pure HM)
  # If standalone HM on macOS, you can write macOS defaults via activation scripts:
  home.activation.macosDefaults = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # Show hidden files in Finder
    defaults write com.apple.finder AppleShowAllFiles -bool true
    # Always show file extensions
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    # Disable the "Are you sure you want to open this application?" dialog
    defaults write com.apple.LaunchServices LSQuarantine -bool false
    # Fast key repeat
    defaults write NSGlobalDomain KeyRepeat -int 2
    defaults write NSGlobalDomain InitialKeyRepeat -int 25
  '';

  # Terminal.app and iTerm2 use $SHELL — make sure fish is registered
  programs.fish.loginShellInit = lib.mkIf pkgs.stdenv.isDarwin ''
    # Add nix to PATH for GUI apps (macOS-specific issue)
    fish_add_path /nix/var/nix/profiles/default/bin
    fish_add_path $HOME/.nix-profile/bin
  '';
}
```

---

### 2.13 Sharing Configuration Between Linux and macOS

The cleanest pattern is a shared `common.nix` imported by both platform-specific files:

```bash
~/.config/home-manager/
├── flake.nix
├── common.nix          ← shared packages, git, shell, nvim, etc.
├── home-linux.nix      ← imports common.nix + Linux specifics (Sway, foot)
└── home-darwin.nix     ← imports common.nix + macOS specifics
```

`home-linux.nix`:

```nix
{ config, pkgs, lib, ... }:
{
  imports = [ ./common.nix ];
  home.username = "donald";
  home.homeDirectory = "/home/donald";
  home.stateVersion = "25.11";

  # Linux-specific
  programs.foot.enable = true;
  programs.sway.enable = false; # Sway managed at system level on NixOS
}
```

`home-darwin.nix`:

```nix
{ config, pkgs, lib, ... }:
{
  imports = [ ./common.nix ];
  home.username = "donald";
  home.homeDirectory = "/Users/donald";
  home.stateVersion = "25.11";

  # macOS-specific
  programs.kitty.enable = true;
  programs.alacritty.enable = true;
}
```

---

### 2.14 Services (Linux)

Home Manager can run user-level systemd services on Linux:

```nix
# Run a service as your user (no sudo needed)
services.syncthing.enable = true;

services.gpg-agent = {
  enable = true;
  enableSshSupport = true;
  defaultCacheTtl = 3600;
  pinentryPackage = pkgs.pinentry-gnome3;
};

# Custom user service
systemd.user.services.my-sync = {
  Unit.Description = "My custom sync service";
  Service = {
    ExecStart = "${pkgs.rclone}/bin/rclone sync /local/path remote:path";
    Restart = "on-failure";
  };
  Install.WantedBy = [ "default.target" ];
};
```

---

### 2.15 Direnv + nix-direnv (Essential for Project Dev Shells)

This combo lets you drop into per-project Nix dev shells automatically when `cd`-ing into a directory — critical for managing Go, Rust, Python, and Node versions per project without polluting your global env.

```nix
programs.direnv = {
  enable = true;
  nix-direnv.enable = true;   # caches nix shells so they don't re-evaluate constantly
  enableFishIntegration = true;
  enableZshIntegration  = true;
};
```

In each project, create a `flake.nix` and `.envrc`:

```bash
# .envrc
use flake
```

```nix
# flake.nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs = { nixpkgs, ... }:
    let pkgs = nixpkgs.legacyPackages.x86_64-linux; in {
      devShells.x86_64-linux.default = pkgs.mkShell {
        buildInputs = with pkgs; [ go gopls golangci-lint delve ];
        shellHook = ''
          echo "Go dev shell loaded ($(go version))"
        '';
      };
    };
}
```

Run `direnv allow` once in the project directory and the shell activates automatically on every subsequent `cd`.

---

### 2.16 Updating and Day-to-Day Workflow

```bash
# Update all flake inputs (nixpkgs, home-manager) to latest
cd ~/.config/home-manager
nix flake update

# Apply the updated configuration
home-manager switch --flake ~/.config/home-manager

# On NixOS (updates both OS and home environment)
sudo nixos-rebuild switch --flake /etc/nixos#yourhostname

# List Home Manager generations (like NixOS generations, but for home)
home-manager generations

# Roll back to previous generation
home-manager generations | head -5
# Copy the activation script path from the output and run it,
# or use: home-manager switch --rollback (if available in your version)

# Remove old generations to free disk space
nix-collect-garbage --delete-older-than 30d

# Check what would change before applying
home-manager switch --dry-run --flake ~/.config/home-manager
```

---

### 2.17 Troubleshooting Common Issues

**Nvidia: Sway fails to start, "failed to open DRM device"**
Confirm `nvidia-drm.modeset=1` is in your boot params and the modules are loaded early with `boot.initrd.kernelModules`. Run `systemctl status greetd` for logs.

**Nvidia: cursor is invisible or corrupted**
Set `WLR_NO_HARDWARE_CURSORS=1` in your environment (already in the config above).

**Nvidia: screen sharing / OBS doesn't capture**
Ensure `xdg-desktop-portal-wlr` is installed and the portal is running. Check `systemctl --user status xdg-desktop-portal-wlr`.

**Home Manager: "collision between packages"**
Two packages in `home.packages` provide the same file. Use `lib.lowPrio` or remove the conflicting package: `(lib.lowPrio pkgs.somepkg)`.

**Home Manager on macOS: fish/zsh not found as login shell**
macOS's `/etc/shells` must contain the nix store path to your shell. Home Manager can handle this: `programs.fish.loginShellInit` and make sure to run `chsh -s $(which fish)` after the first switch.

**"error: attribute 'X' missing"**
Usually means the nixpkgs channel you're on doesn't have that package yet. Switch to `nixpkgs-unstable` in your flake inputs for the latest packages, or search <https://search.nixos.org> to confirm the correct attribute name.

---

### 2.18 Recommended Repository Structure for Your Setup

Given your multi-machine enterprise + homelab context, a mono-repo structure works well:

```bash
~/dotfiles/
├── flake.nix                    ← top-level flake, defines all hosts
├── flake.lock                   ← pinned dependency graph
├── nixos/
│   ├── workstation/
│   │   ├── configuration.nix
│   │   └── hardware-configuration.nix
│   └── homelab/
│       ├── configuration.nix
│       └── hardware-configuration.nix
├── home/
│   ├── common.nix               ← shared HM config
│   ├── linux.nix
│   ├── darwin.nix
│   └── modules/
│       ├── git.nix
│       ├── neovim.nix
│       ├── shell.nix
│       └── tools.nix
└── modules/                     ← reusable NixOS modules
    ├── nvidia.nix
    ├── sway.nix
    └── security.nix
```

With this structure, `sudo nixos-rebuild switch --flake ~/dotfiles#workstation` builds your full system, and `home-manager switch --flake ~/dotfiles#donald@workstation` manages your home environment. Both can be unified into one rebuild if using the NixOS module approach from section 1.9.
