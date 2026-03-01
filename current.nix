{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [ ./hardware-configuration.nix ];
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
  #  boot.kernelPackages = pkgs.linuxPackages_latest;

  # LTS kernel — more stable with Nvidia drivers than linuxPackages_latest
  boot.kernelPackages = pkgs.linuxPackages;

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
  boot.initrd.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
    "nvidia_drm"
  ];

  # ── Networking ───────────────────────────────────────────────────────────────
  networking.hostName = "workstation";
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
    open = true; # change to true if you have RTX 30xx or newer

    # NVIDIA settings GUI app — useful for quick adjustments
    nvidiaSettings = true;

    # Driver package selection. "stable" tracks the latest production driver.
    # Other options: beta, production, legacy_470, legacy_390.
    # Use latest driver — nvidiaPackages.stable has a known EGL bug that
    # breaks wlroots/Sway on Wayland. latest fixes it.
    # Check https://nixos.wiki/wiki/Nvidia for version mapping.
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Enable OpenGL (required for Wayland hardware acceleration)
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # for 32-bit apps (Steam, Wine)
    extraPackages = with pkgs; [
      nvidia-vaapi-driver # VA-API support for hardware video decoding
      libvdpau-va-gl
    ];
  };

  # ── Wayland Environment Variables ────────────────────────────────────────────
  # These are system-wide environment variables. Some apps (Electron, Firefox,
  # Chromium) need hints to use Wayland rendering rather than XWayland fallback.
  # Use environment.variables (not sessionVariables) so these are available
  # to greetd and other system services, not just user sessions.
  # WLR_DRM_DEVICES: Nvidia often enumerates as card1 instead of card0
  # because an EFI framebuffer driver grabs card0 first at boot.
  environment.variables = {
    # Tell the Nvidia EGL driver to use the correct platform
    # GBM is the buffer manager Wayland compositors use
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";

    # Use EGL for hardware acceleration on Wayland
    WLR_NO_HARDWARE_CURSORS = "1"; # fixes cursor issues on Nvidia with wlroots

    # Optional: force Wayland for specific toolkits
    NIXOS_OZONE_WL = "1"; # Electron apps use Wayland
    MOZ_ENABLE_WAYLAND = "1"; # Firefox Wayland
    QT_QPA_PLATFORM = "wayland";
    SDL_VIDEODRIVER = "wayland";
    _JAVA_AWT_WM_NONREPARENTING = "1"; # Java Swing apps in tiling WMs

    # Note sure if needed or not
    WLR_DRM_DEVICES = "/dev/dri/card1";

  };

  # ── Sway ──────────────────────────────────────────────────────────────────────
  # Sway is a Wayland compositor implementing the i3 layout protocol.
  # "programs.sway" handles PAM integration, polkit, and DBus correctly.
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true; # fixes GTK apps not applying themes
    extraPackages = with pkgs; [
      swaylock # screen locker
      swayidle # idle daemon (dim/lock/suspend)
      swaybg # wallpaper setter
      swaynotificationcenter # notification daemon (or use mako)
      waybar # status bar (highly configurable)
      wofi # app launcher (rofi-wayland alternative)
      wl-clipboard # wl-copy / wl-paste CLI tools
      grim # screenshot tool
      slurp # region selection for screenshots
      xdg-utils # xdg-open, xdg-mime
      xwayland # XWayland for X11 app compatibility
      foot # terminal emulator (pure Wayland, fast)
      kanshi # dynamic display configuration
      # mako
    ];
  };

  # Enable the gnome-keyring secrets vault.
  # Will be exposed through DBus to programs willing to store secrets.
  services.gnome.gnome-keyring.enable = true;

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
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd 'sway --unsupported-gpu'";
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
    pulse.enable = true; # PulseAudio compatibility shim
    jack.enable = true; # JACK compatibility
    wireplumber.enable = true; # session/policy manager for PipeWire
  };
  # Disable PulseAudio (PipeWire replaces it)
  services.pulseaudio.enable = false;

  # ── Filesystem ──────────────────────────────────────────────────────────────
  boot.supportedFilesystems = [ "btrfs" ];

  # ── SSH ────────────────────────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
    };
  };

  # ── Bluetooth ─────────────────────────────────────────────────────────────────
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # ── DBus / PolicyKit ─────────────────────────────────────────────────────────
  # Required for privileged operations (mounting, shutdown, etc.) in a
  # compositor-only environment (no full DE like GNOME)
  services.dbus.enable = true;
  security.polkit.enable = true;

  # ── System Packages ───────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    htop
    pciutils # lspci
    usbutils # lsusb
    file
    unzip
    zip
    ripgrep
    fd
    bat
    nvtopPackages.full # Nvidia GPU monitor (like htop for GPU)
    btrfs-progs
  ];

  # ── Fonts ─────────────────────────────────────────────────────────────────────
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
  ];

  # ── User Account ──────────────────────────────────────────────────────────────
  users.mutableUsers = false; # passwords are managed declaratively

  users.users.root = {
    hashedPassword = "$6$qzW7FquWrsvSdA2z$YWEjmYpsXk0/oWVjHcSm.nJbuUCE3s9Gj6Vj6yg.xvPRGmfWalH7.JDEkyyRcllR9dAXuw0RSQCVlJWMxMUp//";
  };

  users.users.donald = {
    isNormalUser = true;
    description = "Donald";
    extraGroups = [
      "wheel" # sudo
      "networkmanager" # manage network connections
      "audio" # direct audio access
      "video" # GPU/display access
      "input" # input devices
      "docker" # if using Docker
    ];
    shell = pkgs.zsh; # or bash, fish
    hashedPassword = "$6$XEP8iARuOLqjxM7f$JxYe7f2.3S78WHrMWwjwT22sDtO4wkfxXY2gegYAEBaJ1.ID5NsjvVnn6FhIehPSiylqTBpOlzAg8I3dgw./e/";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINOeDUZ8unhW85b8Cu1zmEDp5CNeg0oYpvRpK1eMYQvd donald"
    ];

  };
  programs.zsh.enable = true;

  # ── Nix Settings ─────────────────────────────────────────────────────────────
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true; # deduplicate identical files in /nix/store
      trusted-users = [
        "root"
        "donald"
      ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # Allow unfree packages (Nvidia driver, VS Code, etc.)
  nixpkgs.config.allowUnfree = true;

  # System install of 1Password. This way allows for system authentication and
  # for CLI integration.
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    # Certain features, including CLI integration and system authentication support,
    # require enabling PolKit integration on some desktop environments (e.g. Plasma).
    polkitPolicyOwners = [ "yourUsernameHere" ];
  };

  system.stateVersion = "25.11"; # Set to the NixOS version you installed
}
