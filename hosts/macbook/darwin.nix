{ pkgs, ... }:

{
  # ── Nix ─────────────────────────────────────────────────────────────────────
  # If using Determinate Nix: set to false (Determinate manages the daemon)
  # If using upstream Nix: set to true and configure nix.settings below
  nix.enable = false;

  # If using upstream Nix, uncomment these:
  # nix.settings = {
  #   experimental-features = [ "nix-command" "flakes" ];
  #   trusted-users = [ "@admin" "donald" ];
  # };
  # nix.gc = {
  #   automatic = true;
  #   interval = { Weekday = 0; Hour = 2; Minute = 0; };
  #   options = "--delete-older-than 30d";
  # };

  # ── Primary user (required for system.defaults, homebrew, etc.) ─────────────
  system.primaryUser = "donaldgifford";

  # ── System packages (available to all users) ────────────────────────────────
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
  ];

  # ── Shell ───────────────────────────────────────────────────────────────────
  # Create /etc/zshrc that loads the nix-darwin environment
  programs.zsh.enable = true;

  # ── Security ────────────────────────────────────────────────────────────────
  # TouchID for sudo — huge QoL, persists across reboots
  security.pam.services.sudo_local.touchIdAuth = true;

  # ── Fonts ─────────────────────────────────────────────────────────────────────
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
  ];

  # ── Homebrew ────────────────────────────────────────────────────────────────
  # nix-darwin will install Homebrew if not already present
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true;
      cleanup = "zap"; # remove anything not declared here
      upgrade = true;
    };

    # CLI tools that work better via brew on macOS (prefer nix when possible)
    brews = [
      "mas" # Mac App Store CLI (needed for masApps below)
      "dlvhdr/formulae/diffnav" # diffnav
    ];

    # GUI applications
    casks = [
      # ── Core ──
      "1password"
      "1password-cli"
      "obsidian"

      # ── Dev ──
      "docker-desktop" # Docker Desktop

      # ── Browsers ──
      "firefox" # or "google-chrome", "firefox"

      # ── Communication ──
      "discord"
      "tableplus"

      # ── Utilities ──
      "raycast" # spotlight replacement
      "tailscale-app"
      "gpg-suite-no-mail"
      "wireshark-app"
      "istat-menus"
      "bartender"
      "rectangle"
      "cleanshot"
      "backblaze"
      "ivpn"
      "protonvpn"
      "little-snitch@5"
      "vlc" # media player
      "balenaetcher" # usb flashing
    ];

    # Mac App Store apps — requires being signed into the App Store first
    # Find IDs: mas search <name> or from the App Store URL
    masApps = {
      "Amphetamine" = 937984704;
      "Pixelmator Pro" = 1289583905;
      "Fantastical" = 975937182;
      "Monodraw" = 920404675;
      "Transmit 5" = 1436522307;
      "Pastebot" = 1179623856;
      # "Xcode"     = 497799835;
      # "Tailscale" = 1475387142;
      # "Wireguard" = 1451685025;
    };
  };

  # ── macOS System Defaults ───────────────────────────────────────────────────
  system.defaults = {
    # Global
    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      AppleInterfaceStyleSwitchesAutomatically = true;

      # Fast key repeat
      KeyRepeat = 2;
      InitialKeyRepeat = 20;
      ApplePressAndHoldEnabled = false;
      # InitialKeyRepeat = 25;

      # Expand save/print panels by default
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
      PMPrintingExpandedStateForPrint = true;
      PMPrintingExpandedStateForPrint2 = true;

      # Disable auto-correct annoyances
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
    };

    # Dock
    dock = {
      autohide = true;
      show-recents = false;
      mru-spaces = false; # don't rearrange spaces by recent use
      minimize-to-application = true;
      tilesize = 48;
    };

    # Finder
    finder = {
      AppleShowAllExtensions = true;
      FXPreferredViewStyle = "Nlsv"; # list view
      ShowPathbar = true;
      ShowStatusBar = true;
      _FXShowPosixPathInTitle = true;
      FXEnableExtensionChangeWarning = false;
    };

    # Trackpad
    trackpad = {
      Clicking = true; # tap to click
      TrackpadThreeFingerDrag = true;
    };

    # Login window
    loginwindow = {
      GuestEnabled = false;
    };

    # Screensaver
    screensaver = {
      askForPassword = true;
      askForPasswordDelay = 0;
    };

    # Custom defaults (anything not covered above)
    CustomUserPreferences = {
      # Disable the "Are you sure you want to open this application?" dialog
      "com.apple.LaunchServices" = {
        LSQuarantine = false;
      };
    };
  };

  # ── Keyboard ────────────────────────────────────────────────────────────────
  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToEscape = true; # useful for vim/neovim
  };

  # ── Platform ────────────────────────────────────────────────────────────────
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Allow unfree packages (1password, vscode, slack, etc.)
  nixpkgs.config.allowUnfree = true;

  # ── User ────────────────────────────────────────────────────────────────────
  users.users.donaldgifford = {
    name = "donaldgifford";
    home = "/Users/donaldgifford";
  };

  # ── Backwards compat ────────────────────────────────────────────────────────
  # Don't change without reading: darwin-rebuild changelog
  system.stateVersion = 4;
}
