{ pkgs, ... }:

# opencode — the binary itself is a Homebrew tap (hosts/macbook/darwin.nix);
# this module supplies its language servers and config.
#
# opencode's built-in LSP entries look the server binary up on PATH first and
# only download into ~/.cache/opencode/bin as a fallback. Everything here is
# on PATH, and the fallback is switched off, so what runs is what nix (or
# mise) installed. Servers already provided elsewhere and not repeated here:
#   gopls, marksman, ruff, tflint    — mise (config/mise/conf.d/global.toml)
#   rust-analyzer                    — mise rust toolchain (~/.cargo/bin)
#   nixd, nil                        — home/common/packages.nix
#   clangd                           — Xcode CLT
# nvim keeps its own Mason copies for now; unifying those is a separate job.
{
  home.packages = with pkgs; [
    basedpyright # python (built-in pyright disabled in opencode.jsonc)
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

  home.sessionVariables.OPENCODE_DISABLE_LSP_DOWNLOAD = "true";
  # HM doesn't pass sessionVariables into nushell; set it there too so a bare
  # `nu` behaves the same. (herdr/tmux panes older than the switch won't see
  # either until their server restarts — harmless, it only re-enables the
  # download fallback there.)
  programs.nushell.extraEnv = ''
    $env.OPENCODE_DISABLE_LSP_DOWNLOAD = "true"
  '';
}
