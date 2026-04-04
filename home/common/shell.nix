{
  config,
  pkgs,
  lib,
  ...
}:

{
  programs.zsh = {
    enable = true;
    autocd = true;
    enableCompletion = true;

    # Zinit manages these — disable HM's built-in versions
    syntaxHighlighting.enable = false;
    autosuggestion.enable = false;

    history = {
      size = 100000;
      save = 100000;
      path = "${config.home.homeDirectory}/.zsh_history";
      share = true;
      ignoreDups = true;
      ignoreSpace = true;
      extended = true;
    };

    shellAliases = {
      # eza
      # eza (richer than current)
      ls = "eza -F -gh --group-directories-first --git --git-ignore --icons --color=always --hyperlink";
      ll = "ls -l";
      lh = "ls -lh";
      la = "ll -a";
      lt = "eza --tree --icons -L 3";
      # Modern replacements
      # ls = "eza --icons";
      # ll = "eza -la --icons --git";
      # la = "eza -a --icons";

      # bat
      cat = "bat --pager=never --style=plain,header";
      fp = "fzf --preview 'bat --color=always --style=numbers --line-range=:500 {}'";

      # sesh
      sp = "sesh connect $(sesh list | fzf)";

      grep = "rg";
      find = "fd";

      # Navigation
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";

      # Git
      g = "git";
      ga = "git add";
      gaa = "git add --all";
      gc = "git commit";
      gcm = "git commit -m";
      gco = "git checkout";
      gd = "git diff";
      gds = "git diff --staged";
      gl = "git pull";
      gp = "git push";
      gst = "git status -sb";
      glg = "git log --oneline --graph --decorate";
      gwip = "git commit -am 'wip'";
      gcl = "git clone"; # use gcl for clone to avoid conflict

      # Kubernetes
      k = "kubectl";
      kk = "kubectl";
      kgp = "kubectl get pods";
      kgs = "kubectl get services";
      kgn = "kubectl get nodes";
      kctx = "kubectx";
      kns = "kubens";

      # Infra
      tf = "terraform";
      tfi = "terraform init";
      tfp = "terraform plan";
      tfa = "terraform apply";

      # Misc
      vi = "nvim";
      vim = "nvim";
      v = "nvim";
      sudoedit = "sudo -E nvim";
      svi = "sudo -E nvim";
    };

    initContent = ''
      # ── Zinit bootstrap ───────────────────────────────────────────────────
      ZINIT_HOME="''${XDG_DATA_HOME:-''${HOME}/.local/share}/zinit/zinit.git"
      if [[ ! -d "$ZINIT_HOME" ]]; then
        mkdir -p "$(dirname $ZINIT_HOME)"
        git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
      fi
      source "''${ZINIT_HOME}/zinit.zsh"
      autoload -Uz _zinit
      (( ''${+_comps} )) && _comps[zinit]=_zinit

      # ── Annexes ───────────────────────────────────────────────────────────
      zinit light-mode for \
        zdharma-continuum/zinit-annex-as-monitor \
        zdharma-continuum/zinit-annex-bin-gem-node \
        zdharma-continuum/zinit-annex-patch-dl \
        zdharma-continuum/zinit-annex-rust

      # ── Completions infrastructure ────────────────────────────────────────
      autoload -Uz compinit
      if [[ -n ''${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
        compinit
      else
        compinit -C
      fi

      zstyle ':completion:*' menu select
      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
      zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
      zstyle ':completion:*:descriptions' format '[%d]'
      zstyle ':completion:*' group-name '''
      zstyle ':fzf-tab:*' switch-header-keys ' '

      # ── Essential plugins ─────────────────────────────────────────────────
      zinit ice wait lucid atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay"
      zinit light zdharma-continuum/fast-syntax-highlighting

      zinit ice wait lucid atload"!_zsh_autosuggest_start"
      zinit light zsh-users/zsh-autosuggestions

      zinit ice wait lucid blockf atpull'zinit creinstall -q .'
      zinit light zsh-users/zsh-completions

      zinit ice wait lucid
      zinit light Aloxaf/fzf-tab

      # ── History substring search (synchronous — needed by vi mode) ───────
      zinit light zsh-users/zsh-history-substring-search

      # ── Tokyo Night ZSH colors ─────────────────────────────────────
      # History substring search
      HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND='bg=#283457,fg=#c0caf5,bold'
      HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND='bg=#db4b4b,fg=#c0caf5,bold'

      # Paste — subtle underline instead of opaque background
      zle_highlight=('paste:none')

      # Autosuggestions — dim comment color
      # ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#545c7e'

      # Vi mode cursor colors (if using zsh-vi-mode)
      ZVM_CURSOR_STYLE_ENABLED=true
      ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BEAM
      ZVM_NORMAL_MODE_CURSOR=$ZVM_CURSOR_BLOCK
      ZVM_VI_INSERT_ESCAPE_BINDKEY=jk

      # ── Vi mode ───────────────────────────────────────────────────────────
      function zvm_after_init() {
        bindkey '^R' fzf-history-widget
        bindkey '^[[A' history-substring-search-up
        bindkey '^[[B' history-substring-search-down
      }

      zinit ice depth=1
      zinit light jeffreytse/zsh-vi-mode

      # ── OMZ plugins ───────────────────────────────────────────────────────
      zinit ice wait lucid
      zinit snippet OMZL::git.zsh

      zinit ice wait lucid atload"unalias grv 2>/dev/null"
      zinit snippet OMZP::git

      zinit ice wait lucid
      zinit snippet OMZP::kubectl

      zinit ice wait lucid
      zinit snippet OMZP::aws

      zinit ice wait lucid
      zinit snippet OMZP::terraform

      zinit ice wait lucid
      zinit snippet OMZP::docker

      zinit ice wait lucid
      zinit snippet OMZP::helm

      # ── Options ───────────────────────────────────────────────────────────
      setopt correct

      # ── 1Password CLI plugins ─────────────────────────────────────────────
      [ -f "$HOME/.config/op/plugins.sh" ] && source "$HOME/.config/op/plugins.sh"

      # ── Krew ──────────────────────────────────────────────────────────────
      export PATH="''${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

      # ── Zoxide (skip in Claude Code sessions) ─────────────────────────
      if [[ -z "''${CLAUDECODE}" ]]; then
        eval "$(zoxide init --cmd cd zsh)"
      fi

      # ── Custom functions ──────────────────────────────────────────────────
      [ -f "$HOME/.zsh/functions.zsh" ] && source "$HOME/.zsh/functions.zsh"

      # add inside initContent, before the platform aliases
      # ── Yazi wrapper (cd to dir on exit) ──────────────────────────────
      function y() {
        local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
        yazi "$@" --cwd-file="$tmp"
        if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
          builtin cd -- "$cwd"
        fi
        rm -f -- "$tmp"
      }

      # ── Platform-specific rebuild aliases ─────────────────────────────────
      if [[ "$(uname)" == "Darwin" ]]; then
        alias nrs="sudo darwin-rebuild switch --flake ~/code/nix-config"
      else
        alias nrs="sudo nixos-rebuild switch --flake ~/code/nix-config#workstation"
        alias nrt="sudo nixos-rebuild test --flake ~/code/nix-config#workstation"
      fi
      alias nfu="nix flake update ~/code/nix-config"
    '';
  };
  #   initContent = ''
  #     # ── Zinit bootstrap ───────────────────────────────────────────────────
  #     ZINIT_HOME="''${XDG_DATA_HOME:-''${HOME}/.local/share}/zinit/zinit.git"
  #     if [[ ! -d "$ZINIT_HOME" ]]; then
  #       mkdir -p "$(dirname $ZINIT_HOME)"
  #       git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
  #     fi
  #     source "''${ZINIT_HOME}/zinit.zsh"
  #
  #     # ── Plugins (turbo mode — deferred loading) ───────────────────────────
  #     zinit wait lucid light-mode for \
  #       atinit"zicompinit; zicdreplay" \
  #         zdharma-continuum/fast-syntax-highlighting \
  #       atload"_zsh_autosuggest_start" \
  #         zsh-users/zsh-autosuggestions \
  #       blockf atpull"zinit creinstall -q ." \
  #         zsh-users/zsh-completions
  #
  #     # ── Key bindings ──────────────────────────────────────────────────────
  #     bindkey -e                          # emacs keybindings
  #     bindkey '^[[A' history-search-backward
  #     bindkey '^[[B' history-search-forward
  #     bindkey '^R'   fzf-history-widget
  #
  #     # ── Completion styling ────────────────────────────────────────────────
  #     zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
  #     zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
  #     zstyle ':completion:*' menu select
  #     zstyle ':completion:*:descriptions' format '[%d]'
  #     zstyle ':completion:*' group-name '''
  #
  #     # add inside initContent, before the platform aliases
  #     # ── Yazi wrapper (cd to dir on exit) ──────────────────────────────
  #     function y() {
  #       local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  #       yazi "$@" --cwd-file="$tmp"
  #       if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
  #         builtin cd -- "$cwd"
  #       fi
  #       rm -f -- "$tmp"
  #     }
  #
  #     # ── Platform-specific rebuild aliases ─────────────────────────────────
  #     if [[ "$(uname)" == "Darwin" ]]; then
  #       alias nrs="sudo darwin-rebuild switch --flake ~/code/nix-config"
  #     else
  #       alias nrs="sudo nixos-rebuild switch --flake ~/code/nix-config#workstation"
  #       alias nrt="sudo nixos-rebuild test --flake ~/code/nix-config#workstation"
  #     fi
  #     alias nfu="nix flake update ~/code/nix-config"
  #   '';
  # };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    tmux.enableShellIntegration = true;
    defaultOptions = [
      "--highlight-line"
      #     "--height 40%"
      "--info=inline-right"
      "--ansi"
      "--layout=reverse"
      "--border"
      # "--border=none"
      "--color=bg+:#283457"
      "--color=bg:#16161e"
      "--color=border:#27a1b9"
      "--color=fg:#c0caf5"
      "--color=gutter:#16161e"
      "--color=header:#ff9e64"
      "--color=hl+:#2ac3de"
      "--color=hl:#2ac3de"
      "--color=info:#545c7e"
      "--color=marker:#ff007c"
      "--color=pointer:#ff007c"
      "--color=prompt:#2ac3de"
      "--color=query:#c0caf5:regular"
      "--color=scrollbar:#27a1b9"
      "--color=separator:#ff9e64"
      "--color=spinner:#ff007c"
    ];
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = false;
    # options = [ "--cmd cd" ];
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = true;
  };

  # ── Nushell ───────────────────────────────────────────────────────────────
  # Installed but not set as default shell — use `nu` to drop into it.
  # Nushell is a structured data shell; great for exploring JSON/YAML output.
  programs.nushell = {
    enable = true;

    # Nushell config
    extraConfig = ''
      $env.config = {
        show_banner: false
        edit_mode: vi
        history: {
          max_size: 50000
          sync_on_enter: true
          file_format: "sqlite"
        }
        completions: {
          case_sensitive: false
          quick: true
          partial: true
          algorithm: "fuzzy"
        }
        cursor_shape: {
          vi_insert: line
          vi_normal: block
        }
      }
    '';

    # Environment config
    extraEnv = ''
      $env.EDITOR = "nvim"
      $env.VISUAL = "nvim"
      $env.PATH = ($env.PATH | split row (char esep) | prepend [
        ($env.HOME + "/.local/bin")
        ($env.HOME + "/go/bin")
      ])
    ''
    + (
      if pkgs.stdenv.isDarwin then
        ''
          $env.SSH_AUTH_SOCK = ($env.HOME + "/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock")
        ''
      else
        ''
          $env.SSH_AUTH_SOCK = ($env.HOME + "/.1password/agent.sock")
        ''
    );

    shellAliases = {
      ls = "eza --icons";
      ll = "eza -la --icons --git";
      cat = "bat";
      vi = "nvim";
      vim = "nvim";
      k = "kubectl";
      tf = "terraform";
    }
    // (
      if pkgs.stdenv.isDarwin then
        {
          nrs = "sudo darwin-rebuild switch --flake ~/code/nix-config";
        }
      else
        {
          nrs = "sudo nixos-rebuild switch --flake ~/code/nix-config#workstation";
        }
    );
  };
}
