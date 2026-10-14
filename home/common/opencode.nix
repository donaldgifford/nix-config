{ pkgs, ... }:

# opencode — the binary itself is a Homebrew tap (hosts/macbook/darwin.nix).
#
# Language servers. Added for opencode V1's LSP tools (PR #127); opencode V2
# accepts an `lsp` block but runs no language servers at all, so opencode no
# longer uses anything here. They stay on PATH for other editors — nvim still
# runs its own Mason copies, so if that unification never happens, dropping
# this module (and its import in home/darwin.nix) is the honest move.
# Servers on PATH from elsewhere:
#   gopls, marksman, ruff, tflint    — mise (config/mise/conf.d/global.toml)
#   rust-analyzer                    — mise rust toolchain (~/.cargo/bin)
#   nixd, nil                        — home/common/packages.nix
#   clangd                           — Xcode CLT
{
  home.packages = with pkgs; [
    basedpyright
    bash-language-server
    dockerfile-language-server # docker-langserver
    lua-language-server
    taplo # toml
    terraform-ls
    tinymist # typst
    typescript-language-server
    vscode-langservers-extracted # vscode-json-language-server (+ css/html/eslint)
    yaml-language-server
  ];
}
