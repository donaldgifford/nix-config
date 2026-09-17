{ config, ... }:

# Atuin — synced, searchable shell history (self-hosted server).
#
# First-time setup on a new machine (interactive, run once):
#   atuin register -u <user> -e <email>   # or: atuin login -u <user> -k "$(op read ...)"
#   atuin import zsh                      # ~/.zsh_history
#   atuin import nu-hist-db               # nushell sqlite history
#   atuin sync
#   atuin key                             # -> store in 1Password; needed to log in elsewhere
{
  # atuin owns Ctrl-R in both shells; stop fzf from binding it there (HM's
  # fzf module warns about the double binding otherwise). Ctrl-T / Alt-C
  # stay fzf. Sets FZF_CTRL_R_COMMAND="" per shell, which fzf's own
  # key-bindings honour as "don't bind".
  programs.fzf.historyWidget = {
    zsh.command = "";
    nushell.command = "";
  };

  # Theme switcher hook. atuin resolves `theme.name = "current"` to
  # ~/.config/atuin/themes/current.toml; make that an out-of-store link that
  # passes through the switcher's `current` symlink, so `theme <name>` swaps
  # atuin's colours with no env var and no new shell. (An ATUIN_THEME_DIR
  # env approach failed in herdr/tmux panes whose server predates the switch:
  # they inherit __HM_SESS_VARS_SOURCED=1 and never re-read session vars.
  # Missing theme => atuin silently falls back to its uncoloured "(none)".)
  xdg.configFile."atuin/themes/current.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/code/nix-config/config/themes/current/atuin/current.toml";

  programs.atuin = {
    enable = true;

    # zsh: NOT via the HM hook. zsh-vi-mode rebinds keymaps when it
    # initialises, so the `atuin init zsh` eval lives inside zvm_after_init
    # in shell.nix instead. Nushell's hook is fine (HM orders it after fzf so
    # atuin keeps Ctrl-R there).
    enableZshIntegration = false;
    enableNushellIntegration = true;
    enableBashIntegration = false;

    # Applied to every shell hook (shell.nix reuses this list for zsh).
    # Up/Down stay on zsh-history-substring-search / reedline; atuin is Ctrl-R.
    flags = [ "--disable-up-arrow" ];

    # Config is fully declared here, so let HM replace whatever atuin
    # scribbled into ~/.config/atuin/config.toml before the first switch.
    forceOverwriteSettings = true;

    # Background sync + history writes via a launchd agent (org.nix-community.home.atuin-daemon).
    # NB: with the daemon on, `atuin history start` talks to the socket and
    # does NOT fall back to sqlite — if every prompt prints a connect error,
    # check `launchctl list | grep atuin` or flip this off.
    daemon.enable = true;

    settings = {
      # ── Sync ────────────────────────────────────────────────────────────
      sync_address = "https://atuin.fartlab.dev";
      auto_sync = true;
      sync_frequency = "5m";
      sync.records = true; # sync v2 (server is 18.22)
      update_check = false; # nix owns the version

      # ── Search UI ───────────────────────────────────────────────────────
      style = "compact";
      inline_height = 20;
      invert = true; # search bar on top, like fzf --layout=reverse
      show_preview = true;
      show_help = true;
      show_tabs = true;
      enter_accept = true; # Enter runs, Tab edits
      search_mode = "fuzzy";
      filter_mode = "global";
      workspaces = true; # `workspace` filter tab = commands run in this git repo
      # Filter-tab cycle order (Ctrl-R again inside the UI)
      search.filters = [
        "global"
        "workspace"
        "directory"
        "host"
        "session"
      ];
      ui.columns = [
        "exit"
        "duration"
        {
          type = "directory";
          width = 30;
        }
        "command"
      ];
      dialect = "us";

      # ── Vi keymap ───────────────────────────────────────────────────────
      keymap_mode = "vim-insert";
      # Same shapes as ZVM_*_MODE_CURSOR / nushell cursor_shape
      keymap_cursor = {
        emacs = "steady-bar";
        vim_insert = "steady-bar";
        vim_normal = "steady-block";
      };
      keys.scroll_exits = false; # j/k past the list edge stays in the search

      # ── Theme (see xdg.configFile above) ────────────────────────────────
      theme.name = "current";

      # ── Privacy ─────────────────────────────────────────────────────────
      secrets_filter = true; # skip lines that look like AWS keys, GitHub tokens, etc.
      # Regexes (matched anywhere in the command) that are never recorded.
      # secrets_filter catches token-shaped strings, not commands that carry
      # a secret as an argument.
      history_filter = [
        "^atuin (login|register)" # the login line contains the encryption key
        "--from-literal" # kubectl create secret ... --from-literal=k=v
        "--token[= ]"
        "--password[= ]"
        "^export [A-Za-z_]*(TOKEN|SECRET|PASSWORD|KEY)="
      ];
      store_failed = true; # failed commands are the ones you go looking for
      dotfiles.enabled = false; # aliases/env are HM's job, not atuin's

      # `atuin stats` — count `git commit` rather than `git`, `sudo x` as `x`,
      # and skip navigation noise
      stats = {
        common_prefix = [ "sudo" ];
        common_subcommands = [
          "aws"
          "cargo"
          "docker"
          "gh"
          "git"
          "go"
          "helm"
          "just"
          "k"
          "kubectl"
          "mise"
          "nix"
          "npm"
          "pnpm"
          "terraform"
          "tf"
        ];
        ignored_commands = [
          "cd"
          "ls"
          "ll"
          "la"
          "lt"
          "nvim"
          "vi"
          "vim"
          "clear"
          "exit"
          "z"
        ];
      };
    };
  };
}
