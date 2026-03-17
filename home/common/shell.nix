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
      # Modern replacements
      ls = "eza --icons";
      ll = "eza -la --icons --git";
      lt = "eza --tree --icons -L 3";
      la = "eza -a --icons";
      cat = "bat";
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

      # Kubernetes
      k = "kubectl";
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

      # ── Plugins (turbo mode — deferred loading) ───────────────────────────
      zinit wait lucid light-mode for \
        atinit"zicompinit; zicdreplay" \
          zdharma-continuum/fast-syntax-highlighting \
        atload"_zsh_autosuggest_start" \
          zsh-users/zsh-autosuggestions \
        blockf atpull"zinit creinstall -q ." \
          zsh-users/zsh-completions

      # ── Key bindings ──────────────────────────────────────────────────────
      bindkey -e                          # emacs keybindings
      bindkey '^[[A' history-search-backward
      bindkey '^[[B' history-search-forward
      bindkey '^R'   fzf-history-widget

      # ── Completion styling ────────────────────────────────────────────────
      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
      zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
      zstyle ':completion:*' menu select
      zstyle ':completion:*:descriptions' format '[%d]'
      zstyle ':completion:*' group-name '''

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

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      format = lib.concatStrings [
        "$directory"
        "$git_branch"
        "$git_status"
        "$nix_shell"
        "$golang"
        "$rust"
        "$nodejs"
        "$python"
        "$kubernetes"
        "$terraform"
        "$cmd_duration"
        "$line_break"
        "$character"
      ];

      directory = {
        truncation_length = 3;
        truncation_symbol = ".../";
        style = "bold cyan";
      };

      git_branch = {
        format = "[$symbol$branch]($style) ";
        symbol = " ";
        style = "bold purple";
      };

      git_status = {
        ahead = "⇡\${count}";
        behind = "⇣\${count}";
        diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
        modified = "!\${count}";
        staged = "+\${count}";
        untracked = "?\${count}";
        deleted = "✘\${count}";
        stashed = "\\$\${count}";
      };

      nix_shell = {
        format = "[$symbol$state]($style) ";
        symbol = " ";
      };

      golang.format = "[$symbol($version)]($style) ";
      rust.format = "[$symbol($version)]($style) ";
      nodejs.format = "[$symbol($version)]($style) ";
      python.format = "[$symbol($version)]($style) ";

      kubernetes = {
        disabled = false;
        format = "[$symbol$context(/$namespace)]($style) ";
      };

      cmd_duration = {
        min_time = 2000;
        format = "took [$duration]($style) ";
      };

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };
    };
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    tmux.enableShellIntegration = true;
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
    ];
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
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
      $env.SSH_AUTH_SOCK = ($env.HOME + "/.1password/agent.sock")
      $env.PATH = ($env.PATH | split row (char esep) | prepend [
        ($env.HOME + "/.local/bin")
        ($env.HOME + "/go/bin")
      ])
    '';

    shellAliases = {
      ls = "eza --icons";
      ll = "eza -la --icons --git";
      cat = "bat";
      vi = "nvim";
      vim = "nvim";
      k = "kubectl";
      tf = "terraform";
      nrs = "sudo nixos-rebuild switch --flake /etc/nixos#workstation";
      hms = "home-manager switch --flake /etc/nixos#donald";
    };
  };
}
