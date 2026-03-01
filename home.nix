
{ config, pkgs, lib, ... }:

{
  home.username = "donald";
  home.homeDirectory = "/home/donald";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # ── Packages ──────────────────────────────────────────────────────────────
  home.packages = with pkgs; [
    # Shell tools
    eza          # modern ls
    bat          # modern cat
    ripgrep      # fast grep
    fd           # fast find
    fzf          # fuzzy finder
    zoxide       # smart cd
    delta        # better git diffs
    jq           # json processing
    yq           # yaml processing
    htop
    unzip
    zip

    # mise — manages Go, Node, Python, Ruby etc runtimes per project
    mise

    # Cloud / Infra (installed globally — mise handles language runtimes)
    awscli2
    kubectl
    k9s
    helm
    terraform
    fluxcd

    # 1Password CLI — needed for SSH agent and git signing integration
    _1password-cli

    # Wayland / Sway utilities
    wl-clipboard
    grim
    slurp
    brightnessctl
    pamixer       # volume control from CLI/waybar
    playerctl     # media player control
  ];

  # ── SSH ───────────────────────────────────────────────────────────────────
  # 1Password SSH agent socket path on Linux.
  # The agent exposes your SSH keys stored in 1Password vaults.
  # You must have 1Password desktop app installed and SSH agent enabled
  # in 1Password Settings → Developer → Use the SSH agent.
  programs.ssh = {
    enable = true;

    # Point SSH at the 1Password agent socket instead of the default ssh-agent.
    # This means all SSH connections use keys from your 1Password vault.
    extraConfig = ''
      Host *
        IdentityAgent ~/.1password/agent.sock
    '';

    matchBlocks = {
      "github.com" = {
        hostname = "github.com";
        user = "git";
        # No identityFile needed — 1Password agent handles key selection
      };

      "*.internal" = {
        user = "donald";
        forwardAgent = true;
        serverAliveInterval = 60;
        serverAliveCountMax = 3;
      };
    };
  };

  # ── Git ───────────────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    userName  = "Donald";
    userEmail = "your@email.com"; # ← update this

    signing = {
      # 1Password SSH signing — uses your SSH key stored in 1Password
      # to sign commits instead of GPG. Much simpler to manage.
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINOeDUZ8unhW85b8Cu1zmEDp5CNeg0oYpvRpK1eMYQvd donald";
      signByDefault = true;
      format = "ssh";
    };

    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      rerere.enabled = true;
      fetch.prune = true;

      core = {
        editor = "nvim";
        pager  = "delta";
      };

      interactive.diffFilter = "delta --color-only";

      delta = {
        navigate       = true;
        side-by-side   = true;
        line-numbers   = true;
        light          = false;
      };

      # Tell git where the 1Password SSH signing program is.
      # This is what allows `git commit` to use 1Password for signing.
      gpg.ssh.program = "${pkgs._1password-gui}/bin/op-ssh-sign";
    };

    aliases = {
      s     = "status -sb";
      lg    = "log --oneline --graph --decorate";
      co    = "checkout";
      br    = "branch";
      undo  = "reset HEAD~1 --mixed";
      amend = "commit --amend --no-edit";
      wip   = "commit -am 'wip'";
    };

    ignores = [
      ".DS_Store"
      ".direnv"
      ".envrc"
      "*.swp"
      ".idea/"
      ".vscode/"
      "node_modules/"
      "__pycache__/"
      "*.local"
    ];
  };

  # ── Zsh ───────────────────────────────────────────────────────────────────
  programs.zsh = {
    enable = true;
    autocd  = true;
    enableCompletion  = true;
    syntaxHighlighting.enable = true;
    autosuggestion.enable     = true;

    history = {
      size      = 50000;
      save      = 50000;
      share     = true;
      ignoreDups = true;
      ignoreSpace = true;
    };

    shellAliases = {
      ls  = "eza --icons";
      ll  = "eza -la --icons --git";
      lt  = "eza --tree --icons -L 3";
      cat = "bat";
      cd  = "z";         # zoxide
      k   = "kubectl";
      tf  = "terraform";
      hms = "home-manager switch --flake /etc/nixos#donald";
      nrs = "sudo nixos-rebuild switch --flake /etc/nixos#workstation";
    };

    initContent = ''
      # zoxide — smart cd
      eval "$(zoxide init zsh)"

      # mise — activate shims for dev runtimes (go, node, python, etc)
      eval "$(mise activate zsh)"

      # 1Password shell completion
      eval "$(op completion zsh)"; compdef _op op

      # Set 1Password SSH agent socket
      export SSH_AUTH_SOCK=~/.1password/agent.sock
    '';
  };

  # ── Starship prompt ───────────────────────────────────────────────────────
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      add_newline = true;

      format = lib.concatStrings [
        "$username"
        "$hostname"
        "$directory"
        "$git_branch"
        "$git_status"
        "$kubernetes"
        "$terraform"
        "$aws"
        "$cmd_duration"
        "$line_break"
        "$character"
      ];

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol   = "[❯](bold red)";
      };

      directory = {
        truncation_length = 4;
        truncate_to_repo  = true;
        style = "bold blue";
      };

      git_branch = {
        symbol = " ";
        style  = "bold purple";
      };

      git_status = {
        ahead    = "⇡${count}";
        behind   = "⇣${count}";
        diverged = "⇕⇡${ahead_count}⇣${behind_count}";
        modified = "!${count}";
        staged   = "+${count}";
        untracked = "?${count}";
      };

      kubernetes = {
        disabled = false;
        style    = "bold cyan";
        symbol   = "☸ ";
      };

      aws = {
        disabled = false;
        symbol   = "☁️  ";
        style    = "bold yellow";
      };

      terraform = {
        disabled = false;
        symbol   = "💠 ";
      };

      cmd_duration = {
        min_time = 2000;
        style    = "bold yellow";
      };
    };
  };

  # ── Neovim ────────────────────────────────────────────────────────────────
  programs.neovim = {
    enable        = true;
    defaultEditor = true;
    viAlias       = true;
    vimAlias      = true;

    plugins = with pkgs.vimPlugins; [
      # ── LSP ──────────────────────────────────────────────────────────────
      nvim-lspconfig
      nvim-cmp
      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      cmp-cmdline
      luasnip
      cmp_luasnip
      friendly-snippets

      # ── Treesitter ────────────────────────────────────────────────────────
      (nvim-treesitter.withPlugins (p: with p; [
        nix go rust python typescript javascript
        lua bash json yaml toml markdown hcl
      ]))
      nvim-treesitter-textobjects

      # ── Telescope ─────────────────────────────────────────────────────────
      telescope-nvim
      telescope-fzf-native-nvim
      telescope-file-browser-nvim

      # ── UI ────────────────────────────────────────────────────────────────
      neo-tree-nvim
      lualine-nvim
      bufferline-nvim
      which-key-nvim
      nvim-web-devicons
      indent-blankline-nvim
      noice-nvim
      nui-nvim
      nvim-notify

      # ── Git ───────────────────────────────────────────────────────────────
      gitsigns-nvim
      vim-fugitive
      diffview-nvim

      # ── Editing ───────────────────────────────────────────────────────────
      nvim-autopairs
      comment-nvim
      nvim-surround
      leap-nvim

      # ── Colorscheme ───────────────────────────────────────────────────────
      catppuccin-nvim
    ];

    extraLuaConfig = ''
      -- ── Options ──────────────────────────────────────────────────────────
      local opt = vim.opt
      opt.number         = true
      opt.relativenumber = true
      opt.expandtab      = true
      opt.shiftwidth     = 2
      opt.tabstop        = 2
      opt.smartindent    = true
      opt.termguicolors  = true
      opt.undofile       = true
      opt.ignorecase     = true
      opt.smartcase      = true
      opt.splitbelow     = true
      opt.splitright     = true
      opt.scrolloff      = 8
      opt.cursorline     = true
      opt.signcolumn     = "yes"
      opt.updatetime     = 250
      opt.completeopt    = { "menu", "menuone", "noselect" }
      opt.clipboard      = "unnamedplus"  -- use system clipboard (wl-clipboard)

      -- ── Colorscheme ──────────────────────────────────────────────────────
      require("catppuccin").setup({ flavour = "mocha" })
      vim.cmd.colorscheme("catppuccin-mocha")

      -- ── Leader ───────────────────────────────────────────────────────────
      vim.g.mapleader      = " "
      vim.g.maplocalleader = " "

      -- ── Keymaps ──────────────────────────────────────────────────────────
      local map = vim.keymap.set
      local opts = { noremap = true, silent = true }

      -- Navigation
      map("n", "<C-h>", "<C-w>h", opts)
      map("n", "<C-l>", "<C-w>l", opts)
      map("n", "<C-j>", "<C-w>j", opts)
      map("n", "<C-k>", "<C-w>k", opts)

      -- Telescope
      map("n", "<leader>ff", "<cmd>Telescope find_files<cr>",  opts)
      map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>",   opts)
      map("n", "<leader>fb", "<cmd>Telescope buffers<cr>",     opts)
      map("n", "<leader>fh", "<cmd>Telescope help_tags<cr>",   opts)
      map("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>",    opts)

      -- File tree
      map("n", "<leader>e", "<cmd>Neotree toggle<cr>", opts)

      -- Git
      map("n", "<leader>gs", "<cmd>Git<cr>",          opts)
      map("n", "<leader>gd", "<cmd>DiffviewOpen<cr>", opts)
      map("n", "<leader>gh", "<cmd>DiffviewFileHistory<cr>", opts)

      -- LSP (set up in LspAttach autocmd below)
      map("n", "<leader>ca", vim.lsp.buf.code_action,  opts)
      map("n", "<leader>rn", vim.lsp.buf.rename,       opts)
      map("n", "K",          vim.lsp.buf.hover,        opts)
      map("n", "gd",         vim.lsp.buf.definition,   opts)
      map("n", "gr",         vim.lsp.buf.references,   opts)
      map("n", "gi",         vim.lsp.buf.implementation, opts)
      map("n", "[d",         vim.diagnostic.goto_prev, opts)
      map("n", "]d",         vim.diagnostic.goto_next, opts)

      -- Buffer navigation
      map("n", "<S-l>", "<cmd>BufferLineCycleNext<cr>", opts)
      map("n", "<S-h>", "<cmd>BufferLineCyclePrev<cr>", opts)

      -- ── Plugins ──────────────────────────────────────────────────────────

      -- Catppuccin
      require("catppuccin").setup({ flavour = "mocha", integrations = {
        treesitter    = true,
        gitsigns      = true,
        telescope     = { enabled = true },
        neo_tree      = true,
        bufferline    = true,
        which_key     = true,
        indent_blankline = { enabled = true },
        noice         = true,
      }})

      -- Lualine
      require("lualine").setup({ options = {
        theme     = "catppuccin",
        component_separators = { left = "", right = "" },
        section_separators   = { left = "", right = "" },
      }})

      -- Bufferline
      require("bufferline").setup({ options = {
        numbers            = "ordinal",
        diagnostics        = "nvim_lsp",
        show_buffer_close_icons = false,
      }})

      -- Gitsigns
      require("gitsigns").setup({
        signs = {
          add    = { text = "+" },
          change = { text = "~" },
          delete = { text = "_" },
        },
      })

      -- Neo-tree
      require("neo-tree").setup({
        window = { width = 30 },
        filesystem = { filtered_items = { visible = true } },
      })

      -- Telescope
      require("telescope").setup({
        extensions = { fzf = {} },
      })
      require("telescope").load_extension("fzf")
      require("telescope").load_extension("file_browser")

      -- Treesitter
      require("nvim-treesitter.configs").setup({
        highlight    = { enable = true },
        indent       = { enable = true },
        textobjects  = {
          select = {
            enable    = true,
            lookahead = true,
            keymaps   = {
              ["af"] = "@function.outer",
              ["if"] = "@function.inner",
              ["ac"] = "@class.outer",
            },
          },
        },
      })

      -- Autopairs
      require("nvim-autopairs").setup({})

      -- Comment
      require("Comment").setup({})

      -- Surround
      require("nvim-surround").setup({})

      -- Leap
      require("leap").set_default_keymaps()

      -- Which-key
      require("which-key").setup({})

      -- Noice (fancy cmdline/messages UI)
      require("noice").setup({
        lsp = {
          override = {
            ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
            ["vim.lsp.util.stylize_markdown"]                = true,
            ["cmp.entry.get_documentation"]                  = true,
          },
        },
        presets = {
          bottom_search         = true,
          command_palette       = true,
          long_message_to_split = true,
        },
      })

      -- ── LSP ──────────────────────────────────────────────────────────────
      local lspconfig  = require("lspconfig")
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      -- Language servers — add/remove as needed.
      -- Runtimes (go, node etc) are managed by mise so LSP binaries
      -- need to be available in your PATH via mise shims.
      local servers = {
        "nixd",          -- Nix
        "terraformls",   -- Terraform
        "helm_ls",       -- Helm
        "yamlls",        -- YAML
        "jsonls",        -- JSON
        "bashls",        -- Bash
        "lua_ls",        -- Lua
      }

      for _, server in ipairs(servers) do
        lspconfig[server].setup({ capabilities = capabilities })
      end

      -- Go LSP (gopls via mise)
      lspconfig.gopls.setup({
        capabilities = capabilities,
        settings = {
          gopls = {
            analyses  = { unusedparams = true },
            staticcheck = true,
          },
        },
      })

      -- ── Completion ───────────────────────────────────────────────────────
      local cmp    = require("cmp")
      local luasnip = require("luasnip")
      require("luasnip.loaders.from_vscode").lazy_load()

      cmp.setup({
        snippet = {
          expand = function(args) luasnip.lsp_expand(args.body) end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-d>"]   = cmp.mapping.scroll_docs(-4),
          ["<C-f>"]   = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"]    = cmp.mapping.confirm({ select = true }),
          ["<Tab>"]   = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip"  },
          { name = "buffer"   },
          { name = "path"     },
        }),
      })

      -- Format on save
      vim.api.nvim_create_autocmd("BufWritePre", {
        callback = function()
          vim.lsp.buf.format({ async = false })
        end,
      })
    '';
  };

  # ── Sway config ───────────────────────────────────────────────────────────
  wayland.windowManager.sway = {
    enable = true;
    # Don't let HM install sway — it's already managed at the system level.
    # We just want HM to write the config file.
    package = null;

    config = {
      modifier  = "Mod4";
      terminal  = "foot";
      menu      = "wofi --show drun --lines 10 --prompt Launch";

      fonts = {
        names = [ "JetBrainsMono Nerd Font" ];
        size  = 10.0;
      };

      gaps = {
        inner = 8;
        outer = 4;
      };

      bars = [];  # waybar handles the bar

      input = {
        "type:keyboard" = {
          xkb_layout    = "us";
          repeat_delay  = "300";
          repeat_rate   = "50";
        };
        "type:touchpad" = {
          tap             = "enabled";
          natural_scroll  = "enabled";
          dwt             = "enabled";
        };
      };

      keybindings =
        let mod = "Mod4"; in {
          # Core
          "${mod}+Return"      = "exec foot";
          "${mod}+d"           = "exec wofi --show drun";
          "${mod}+Shift+q"     = "kill";
          "${mod}+Shift+e"     = "exec swaynag -t warning -m 'Exit sway?' -B 'Yes' 'swaymsg exit'";
          "${mod}+Shift+c"     = "reload";

          # Focus
          "${mod}+h" = "focus left";
          "${mod}+j" = "focus down";
          "${mod}+k" = "focus up";
          "${mod}+l" = "focus right";

          # Move
          "${mod}+Shift+h" = "move left";
          "${mod}+Shift+j" = "move down";
          "${mod}+Shift+k" = "move up";
          "${mod}+Shift+l" = "move right";

          # Layout
          "${mod}+v"       = "splith";
          "${mod}+s"       = "layout stacking";
          "${mod}+w"       = "layout tabbed";
          "${mod}+e"       = "layout toggle split";
          "${mod}+f"       = "fullscreen toggle";
          "${mod}+Shift+f" = "floating toggle";

          # Workspaces
          "${mod}+1" = "workspace number 1";
          "${mod}+2" = "workspace number 2";
          "${mod}+3" = "workspace number 3";
          "${mod}+4" = "workspace number 4";
          "${mod}+5" = "workspace number 5";
          "${mod}+6" = "workspace number 6";
          "${mod}+7" = "workspace number 7";
          "${mod}+8" = "workspace number 8";
          "${mod}+9" = "workspace number 9";
          "${mod}+Shift+1" = "move container to workspace number 1";
          "${mod}+Shift+2" = "move container to workspace number 2";
          "${mod}+Shift+3" = "move container to workspace number 3";
          "${mod}+Shift+4" = "move container to workspace number 4";
          "${mod}+Shift+5" = "move container to workspace number 5";

          # Screenshot
          "Print"       = "exec grim ~/screenshots/$(date +%Y%m%d_%H%M%S).png";
          "Shift+Print" = "exec grim -g \"$(slurp)\" ~/screenshots/$(date +%Y%m%d_%H%M%S).png";

          # Volume
          "XF86AudioRaiseVolume" = "exec pamixer -i 5";
          "XF86AudioLowerVolume" = "exec pamixer -d 5";
          "XF86AudioMute"        = "exec pamixer -t";

          # Brightness
          "XF86MonBrightnessUp"   = "exec brightnessctl set +5%";
          "XF86MonBrightnessDown" = "exec brightnessctl set 5%-";

          # Lock
          "${mod}+Shift+l" = "exec swaylock -f -c 000000";
        };

      startup = [
        { command = "waybar"; }
        { command = "mkdir -p ~/screenshots"; }
        {
          # swayidle: lock after 5min, turn off displays after 10min
          command = ''
            swayidle -w \
              timeout 300 'swaylock -f -c 000000' \
              timeout 600 'swaymsg "output * power off"' \
              resume 'swaymsg "output * power on"' \
              before-sleep 'swaylock -f -c 000000'
          '';
        }
      ];
    };
  };

  # ── Swaylock ──────────────────────────────────────────────────────────────
  programs.swaylock = {
    enable   = true;
    settings = {
      color            = "1e1e2e";
      font             = "JetBrainsMono Nerd Font";
      indicator-radius = 100;
      indicator-thickness = 7;
      inside-color     = "1e1e2e";
      ring-color       = "cba6f7";
      key-hl-color     = "a6e3a1";
      text-color       = "cdd6f4";
      line-color       = "1e1e2e";
      separator-color  = "00000000";
    };
  };

  # ── Waybar ────────────────────────────────────────────────────────────────
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer    = "top";
        position = "top";
        height   = 30;

        modules-left   = [ "sway/workspaces" "sway/mode" ];
        modules-center = [ "sway/window" ];
        modules-right  = [
          "cpu" "memory" "temperature"
          "pulseaudio" "network"
          "clock" "tray"
        ];

        "sway/workspaces" = {
          disable-scroll = true;
          all-outputs    = true;
        };

        cpu = {
          format   = " {usage}%";
          interval = 2;
        };

        memory = {
          format   = " {}%";
          interval = 5;
        };

        temperature = {
          format       = " {temperatureC}°C";
          critical-threshold = 80;
          format-critical    = " {temperatureC}°C";
        };

        network = {
          format-wifi         = " {essid} ({signalStrength}%)";
          format-ethernet     = " {ipaddr}";
          format-disconnected = "⚠ Disconnected";
          tooltip-format      = "{ifname}: {ipaddr}";
        };

        pulseaudio = {
          format         = "{icon} {volume}%";
          format-muted   = " muted";
          format-icons   = { default = [ "" "" "" ]; };
          on-click       = "pamixer -t";
          on-click-right = "pavucontrol";
        };

        clock = {
          format          = " {:%H:%M}";
          format-alt      = " {:%Y-%m-%d %H:%M:%S}";
          tooltip-format  = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };

        tray = {
          spacing = 10;
        };
      };
    };

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 13px;
        border: none;
        border-radius: 0;
        min-height: 0;
      }

      window#waybar {
        background-color: #1e1e2e;
        color: #cdd6f4;
      }

      #workspaces button {
        padding: 0 8px;
        color: #6c7086;
        border-bottom: 3px solid transparent;
      }

      #workspaces button.focused {
        color: #cdd6f4;
        border-bottom: 3px solid #cba6f7;
      }

      #workspaces button:hover {
        background: #313244;
      }

      #clock, #cpu, #memory, #temperature,
      #network, #pulseaudio, #tray {
        padding: 0 12px;
        color: #cdd6f4;
      }

      #cpu    { color: #89b4fa; }
      #memory { color: #a6e3a1; }
      #clock  { color: #cba6f7; }

      #temperature.critical { color: #f38ba8; }
    '';
  };

  # ── Wofi ──────────────────────────────────────────────────────────────────
  programs.wofi = {
    enable = true;
    settings = {
      width           = 600;
      height          = 400;
      location        = "center";
      show            = "drun";
      prompt          = "Launch";
      filter_rate     = 100;
      allow_markup    = true;
      no_actions      = true;
      halign          = "fill";
      orientation     = "vertical";
      content_halign  = "fill";
      insensitive     = true;
      allow_images    = true;
      image_size      = 32;
      gtk_dark        = true;
    };
    style = ''
      window {
        background-color: #1e1e2e;
        border: 2px solid #cba6f7;
        border-radius: 12px;
      }

      #input {
        background-color: #313244;
        color: #cdd6f4;
        border: none;
        border-radius: 8px;
        padding: 8px;
        margin: 8px;
      }

      #inner-box {
        background-color: transparent;
      }

      #entry {
        padding: 6px 12px;
        border-radius: 6px;
        color: #cdd6f4;
      }

      #entry:selected {
        background-color: #313244;
        color: #cba6f7;
      }

      #text {
        color: #cdd6f4;
      }

      #text:selected {
        color: #cba6f7;
      }
    '';
  };

  # ── Direnv ────────────────────────────────────────────────────────────────
  # Works alongside mise — use for nix dev shells per project
  programs.direnv = {
    enable               = true;
    nix-direnv.enable    = true;
    enableZshIntegration = true;
  };

  # ── Session variables ─────────────────────────────────────────────────────
  home.sessionVariables = {
    EDITOR   = "nvim";
    VISUAL   = "nvim";
    PAGER    = "bat --plain";
    MANPAGER = "sh -c 'col -bx | bat -l man -p'";

    # 1Password SSH agent
    SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";
  };

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/go/bin"
  ];
}
