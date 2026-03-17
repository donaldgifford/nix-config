{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    inputs.lazyvim-nix.homeManagerModules.default
    ./home/packages.nix
    ./home/shell.nix
    ./home/git.nix
    ./home/ssh.nix
    ./home/mise.nix
    ./home/neovim.nix
    ./home/sway.nix
    ./home/waybar.nix
    ./home/wofi.nix
    ./home/swaylock.nix
    ./home/tmux.nix
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
