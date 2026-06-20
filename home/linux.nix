{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    inputs.lazyvim-nix.homeManagerModules.default
    ./linux/packages.nix
    ./linux/shell.nix
    ./linux/git.nix
    ./linux/ssh.nix
    ./linux/mise.nix
    ./linux/neovim.nix
    ./linux/sway.nix
    ./linux/waybar.nix
    ./linux/wofi.nix
    ./linux/swaylock.nix
    ./linux/tmux.nix
  ];

  home.username = "donald";
  home.homeDirectory = "/home/donald";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  home.pointerCursor = {
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
    size = 24; # at 2x scale this renders as a normal sized cursor
    x11.enable = true;
    gtk.enable = true;
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "bat --plain";
    MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    MANROFFOPT = "-c";
    SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";
    XDG_RUNTIME_DIR = "/run/user/1000";
    XCURSOR_SIZE = "24";
    XCURSOR_THEME = "Adwaita";
  };

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/go/bin"
  ];
}
