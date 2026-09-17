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
      lang.cmake = {
        enable = true;
      };
      lang.toml = {
        enable = true;
      };
      lang.typescript = {
        enable = true;
      };
      lang.go = {
        enable = true;
        installDependencies = true;
        installRuntimeDependencies = false;
      };
      lang.helm = {
        enable = true;
      };
      lang.docker = {
        enable = true;
      };
      lang.nix = {
        enable = true;
      };
      lang.terraform = {
        enable = true;
      };
      lang.yaml = {
        enable = true;
      };
      lang.json = {
        enable = true;
      };
      lang.markdown = {
        enable = true;
      };
      lang.typst = {
        enable = true;
      };
      lang.bash = {
        enable = true;
      };
      lang.python = {
        enable = true;
        installDependencies = true;
        installRuntimeDependencies = false;
      };
      lang.rust = {
        enable = true;
        installDependencies = true;
        installRuntimeDependencies = false;
      };
      ui.treesitter-context = {
        enable = true;
      };
      editor.navic = {
        enable = true;
      };
      editor.neo-tree = {
        enable = true;
      };
      util.mini-hipatterns = {
        enable = true;
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
