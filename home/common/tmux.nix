{
  config,
  pkgs,
  lib,
  ...
}:

{
  # ── Sesh — smart session manager ─────────────────────────────────────────
  # programs.sesh = {
  #   enable = true;
  #   enableTmuxIntegration = true;
  #
  #   settings = {
  #     plugins = [
  #       {
  #         name = "sesh";
  #         prefix = ";s ";
  #         src_once = "sesh list -d -c -t -T";
  #         cmd = "sesh connect --switch %RESULT%";
  #         keep_sort = false;
  #         recalculate_score = true;
  #         show_icon_when_single = true;
  #         switcher_only = true;
  #       }
  #     ];
  #   };
  # };

  # ── Tmux ──────────────────────────────────────────────────────────────────
  programs.tmux = {
    enable = true;
    mouse = true;
    terminal = "tmux-256color";
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 50000;
    keyMode = "vi";

    plugins = with pkgs.tmuxPlugins; [
      sensible
      pain-control
      logging
      {
        plugin = fzf-tmux-url;
      }
      {
        plugin = tokyo-night-tmux;
        extraConfig = ''
          set -g @tokyo-night-tmux_theme night
          set -g @tokyo-night-tmux_show_path 1
          set -g @tokyo-night-tmux_path_format relative
          set -g @tokyo-night-tmux_show_hostname 0
          set -g @tokyo-night-tmux_show_wbg 1
          set -g @tokyo-night-tmux_window_id_style hide
          set -g @tokyo-night-tmux_pane_id_style hide
          set -g @tokyo-night-tmux_window_tidy_icons 0
          set -g @tokyo-night-tmux_terminal_icon ⚡
        '';
      }
    ];

    extraConfig = ''
      # ── Reload config ───────────────────────────────────────────────────
      unbind r
      bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded 🚀"

      # ── Sesh session switcher ───────────────────────────────────────────
      bind-key "T" run-shell "sesh connect \"\$(
        sesh list --icons | fzf-tmux -p 80%,70% \
          --no-sort --ansi --border-label ' sesh ' --prompt '⚡  ' \
          --header '  ^a all ^t tmux ^g configs ^x zoxide ^d tmux kill ^f find' \
          --bind 'tab:down,btab:up' \
          --bind 'ctrl-a:change-prompt(⚡  )+reload(sesh list --icons)' \
          --bind 'ctrl-t:change-prompt(🪟  )+reload(sesh list -t --icons)' \
          --bind 'ctrl-g:change-prompt(⚙️  )+reload(sesh list -c --icons)' \
          --bind 'ctrl-x:change-prompt(📁  )+reload(sesh list -z --icons)' \
          --bind 'ctrl-f:change-prompt(🔎  )+reload(fd -H -d 2 -t d -E .Trash . ~)' \
          --bind 'ctrl-d:execute(tmux kill-session -t {2..})+change-prompt(⚡  )+reload(sesh list --icons)' \
          --preview-window 'right:55%' \
          --preview 'sesh preview {}'
      )\""

      bind-key "N" display-popup -E "sesh ui"

      bind-key "R" run-shell "sesh connect \"\$(
        sesh list --icons | fzf-tmux -p 100%,100% --no-border \
          --query \"\$(sesh root)\" \
          --list-border \
          --no-sort --prompt '⚡  ' \
          --input-border \
          --bind 'tab:down,btab:up' \
          --bind 'ctrl-b:abort' \
          --bind 'ctrl-t:change-prompt(🪟  )+reload(sesh list -t --icons)' \
          --bind 'ctrl-g:change-prompt(⚙️  )+reload(sesh list -c --icons)' \
          --bind 'ctrl-x:change-prompt(📁  )+reload(sesh list -z --icons)' \
          --bind 'ctrl-f:change-prompt(🔎  )+reload(fd -H -d 2 -t d -E .Trash . ~)' \
          --bind 'ctrl-d:execute(tmux kill-session -t {2..})+change-prompt(⚡  )+reload(sesh list --icons)' \
          --preview-window 'right:70%' \
          --preview 'sesh preview {}' \
      )\""

      # ── Better defaults ─────────────────────────────────────────────────
      set -g detach-on-destroy off
      bind-key x kill-pane

      # ── True color support ──────────────────────────────────────────────
      set -as terminal-overrides ",xterm*:Tc"
    '';
  };
}
