{
  config,
  pkgs,
  lib,
  ...
}:

{
  programs.lazyvim = {
    enable = true;

    # Language extras — each one automatically installs the LSP, formatter,
    # linter, and treesitter parser for that language.
    # Languages
    extras = {
      lang = {
        cmake = {
          enable = true;
        };
        docker = {
          enable = true;
        };
        go = {
          enable = true;
          installDependencies = true;
          installRuntimeDependencies = false;

        };
        helm = {
          enable = true;
        };
        json = {
          enable = true;
        };
        markdown = {
          enable = true;
        };
        nix = {
          enable = true;
        };
        python = {
          enable = true;
          installDependencies = true;
          installRuntimeDependencies = false;

        };
        rust = {
          enable = true;
          installDependencies = true;
          installRuntimeDependencies = false;

        };
        sql = {
          enable = true;
        };
        tailwind = {
          enable = true;
        };
        terraform = {
          enable = true;
        };
        toml = {
          enable = true;
        };
        typescript = {
          enable = true;
        };
        typst = {
          enable = true;
        };
        yaml = {
          enable = true;
        };
      };

      # UI
      ui = {
        treesitter-context = {
          enable = true;
        };
      };

      # Editor
      editor = {
        navic = {
          enable = true;
        };
        neo-tree = {
          enable = true;
        };
      };

      # Utils
      util = {
        mini-hipatterns = {
          enable = true;
        };
      };

      # Coding
      coding = {
        mini-surround = {
          enable = true;
        };
      };
    };

    # Extra tools available to neovim that aren't covered by language extras
    extraPackages = with pkgs; [
      # Nix
      nixd
      alejandra
      statix # nix linter
      deadnix # finds dead nix code - pair well with statix
      gcc # C compiler for treesitter parser compilation
      tree-sitter # treesitter CLI
      nixfmt # nix file formatter

      # Lua
      lua-language-server
      stylua

      # TypeScript/JS (lang.typescript extra needs these)
      nodePackages.typescript-language-server
      nodePackages.prettier
      nodejs

      # Biome (formatting.biome)
      biome

      # Docker (lang.docker)
      dockerfile-language-server
      hadolint

      # Helm (lang.helm)
      helm-ls

      # Markdown
      markdownlint-cli
      mdformat

      # SQL
      sqls

      # TOML
      taplo

      # Tailwind
      nodePackages.vscode-langservers-extracted

      # CMake
      cmake-language-server

      # DAP (dap.core)
      delve # Go debugger
      lldb # C/Rust debugger

      # General
      lazygit
      ripgrep
      fd
    ];

    plugins = {
      mason = ''
        return {
          { "williamboman/mason.nvim", enabled = false },
          { "williamboman/mason-lspconfig.nvim", enabled = false },
          { "WhoIsSethDaniel/mason-tool-installer.nvim", enabled = false },
        }
      '';
    };
    # If you have an existing LazyVim config directory, point at it here.
    # lazyvim-nix will merge your customizations with its generated config.
    # Your existing keymaps, plugins, options, and autocmds all carry over.
    #
    configFiles = ./nvim;
    #
    # The ./nvim directory should mirror ~/.config/nvim structure:
    # nvim/
    # ├── lua/
    # │   ├── config/
    # │   │   ├── keymaps.lua
    # │   │   ├── options.lua
    # │   │   └── autocmds.lua
    # │   └── plugins/
    # │       ├── colorscheme.lua
    # │       └── editor.lua
    # └── ... any other files you have
  };
}
