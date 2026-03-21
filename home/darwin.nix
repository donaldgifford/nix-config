{
  config,
  pkgs,
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
    ./common/claude.nix
    ./common/fonts.nix
  ];

  home.username = "donaldgifford";
  home.homeDirectory = "/Users/donaldgifford";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # ── Session ─────────────────────────────────────────────────────────────────
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "bat --plain";
    MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    # 1Password SSH agent — macOS path
    SSH_AUTH_SOCK = "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
  };

  home.sessionPath = [
    "$HOME/.local/bin"
    # "$HOME/go/bin"
    "/opt/homebrew/bin"
  ];

  # ── macOS-specific config ───────────────────────────────────────────────────
  # Add anything darwin-only here that doesn't fit in common/ modules

  # Ghostty config (if using ghostty)
  # xdg.configFile."ghostty/config".source =
  # config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/config/ghostty/config";
}
