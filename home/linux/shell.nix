{
  config,
  pkgs,
  lib,
  ...
}:

{
  # ── Zsh ───────────────────────────────────────────────────────────────────
  programs.zsh = {
    enable = true;
    autocd = true;
    enableCompletion = true;

    # These replace the most common OMZ plugins
    syntaxHighlighting.enable = true; # zsh-syntax-highlighting
    autosuggestion.enable = true; # zsh-autosuggestions

    history = {
      size = 50000;
      save = 50000;
      path = "${config.home.homeDirectory}/.zsh_history";
      share = true;
      ignoreDups = true;
      ignoreSpace = true;
      extended = true; # save timestamps
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

      # Git (replacing OMZ git plugin aliases)
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
      gstash = "git stash";
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

      # NixOS
      nrs = "sudo nixos-rebuild switch --flake /etc/nixos#workstation";
      nrt = "sudo nixos-rebuild test --flake /etc/nixos#workstation";
      hms = "home-manager switch --flake /etc/nixos#donald";
      nfu = "sudo nix flake update /etc/nixos";

      # Misc
      vi = "nvim";
      vim = "nvim";
      v = "nvim";
      sudoedit = "sudo -E nvim";
      svi = "sudo -E nvim";
    };

    # Zsh options — equivalent to OMZ setopt lines
    initContent = ''
      # ── Completion style ──────────────────────────────────────────────────
      zstyle ':completion:*' menu select
      zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'  # case-insensitive
      zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
      zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
      zstyle ':completion:*:warnings' format '%F{red}No matches%f'

      # ── Options ───────────────────────────────────────────────────────────
      setopt HIST_VERIFY          # show command before running from history
      setopt CORRECT              # spell correction
      setopt COMPLETE_IN_WORD     # complete from both ends
      setopt ALWAYS_TO_END        # move cursor to end on completion
      setopt AUTO_PUSHD           # push dirs onto stack automatically
      setopt PUSHD_IGNORE_DUPS    # no dupes in dir stack
      setopt PUSHD_SILENT         # no output on pushd/popd

      # ── Key bindings ──────────────────────────────────────────────────────
      bindkey '^[[A' history-search-backward   # up arrow searches history
      bindkey '^[[B' history-search-forward    # down arrow searches history
      bindkey '^[[H' beginning-of-line         # Home
      bindkey '^[[F' end-of-line               # End
      bindkey '^[[3~' delete-char              # Delete

      # ── Tool integrations ─────────────────────────────────────────────────
      # zoxide — smart cd (replaces z/autojump)
      eval "$(zoxide init zsh --cmd cd)"

      # mise — dev runtime manager (go, node, python, rust etc)
      # eval "$(mise activate zsh)"

      # fzf — fuzzy finder key bindings and completion
      source ${pkgs.fzf}/share/fzf/key-bindings.zsh
      source ${pkgs.fzf}/share/fzf/completion.zsh

      # 1Password CLI completion
      eval "$(op completion zsh)"; compdef _op op

      # 1Password SSH agent
      export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"

      # ── FZF config ────────────────────────────────────────────────────────
      export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
      export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
      export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
      export FZF_DEFAULT_OPTS='
        --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8
        --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc
        --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8
        --height 40% --border rounded --layout reverse
      '
    '';
  };

  # ── Fzf prompt ───────────────────────────────────────────────────────
  programs.fzf = {
    enable = true;
    tmux.enableShellIntegration = true;
  };

  # ── Starship prompt ───────────────────────────────────────────────────────
  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      add_newline = true;
      scan_timeout = 10;

      format = lib.concatStrings [
        "$os"
        "$username"
        "$hostname"
        "$directory"
        "$git_branch"
        "$git_status"
        "$kubernetes"
        "$terraform"
        "$aws"
        "$golang"
        "$rust"
        "$python"
        "$nodejs"
        "$cmd_duration"
        "$line_break"
        "$jobs"
        "$character"
      ];

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
        vimcmd_symbol = "[❮](bold green)";
      };

      directory = {
        truncation_length = 4;
        truncate_to_repo = true;
        style = "bold blue";
        read_only = " 󰌾";
      };

      git_branch = {
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

      kubernetes = {
        disabled = false;
        style = "bold cyan";
        symbol = "☸ ";
        contexts = [
          {
            context_pattern = ".*prod.*";
            style = "bold red";
            symbol = "☸ ";
          }
        ];
      };

      aws = {
        disabled = false;
        symbol = "☁️  ";
        style = "bold yellow";
      };

      terraform = {
        disabled = false;
        symbol = "💠 ";
      };

      golang = {
        disabled = false;
        symbol = " ";
        style = "bold cyan";
      };

      rust = {
        disabled = false;
        symbol = " ";
        style = "bold orange";
      };

      python = {
        disabled = false;
        symbol = " ";
        style = "bold yellow";
      };

      nodejs = {
        disabled = false;
        symbol = " ";
        style = "bold green";
      };

      cmd_duration = {
        min_time = 2000;
        style = "bold yellow";
        format = "took [$duration]($style) ";
      };

      jobs = {
        symbol = "+ ";
        threshold = 1;
      };

      os = {
        disabled = false;
        symbols = {
          NixOS = " ";
          Macos = " ";
          Linux = " ";
        };
      };
    };
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
