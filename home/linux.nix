{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    inputs.lazyvim-nix.homeManagerModules.default
    ./common/configs.nix
    ./common/shell.nix
    ./common/git.nix
    ./common/ssh.nix
    ./common/neovim.nix
    ./common/tmux.nix
    ./common/mise.nix
    ./common/packages.nix
    ./common/fonts.nix

    # ── Linux-only modules ──────────────────────────────────────────────────
    # Uncomment these as you port them from /etc/nixos/home/
    ./linux/sway.nix
    ./linux/waybar.nix
    ./linux/wofi.nix
    ./linux/swaylock.nix
  ];

  home.username = "donald";
  home.homeDirectory = "/home/donald";
  home.stateVersion = "25.11"; # match your existing stateVersion if different

  programs.home-manager.enable = true;

  # ── Session ─────────────────────────────────────────────────────────────────
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "bat --plain";
    MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";
    XDG_RUNTIME_DIR = "/run/user/1000";
    XCURSOR_SIZE = "24";
    XCURSOR_THEME = "Adwaita";

  };

  home.pointerCursor = {
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
    size = 24; # at 2x scale this renders as a normal sized cursor
    x11.enable = true;
    gtk.enable = true;
  };

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/go/bin"
  ];

  # ── Linux-specific config ───────────────────────────────────────────────────
  # Add anything Linux-only here that doesn't fit in a module

  # GPG agent (if you use it alongside 1Password)
  # services.gpg-agent = {
  #   enable = true;
  #   enableSshSupport = false;  # 1Password handles SSH
  #   defaultCacheTtl = 3600;
  # };
}
