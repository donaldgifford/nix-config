{
  config,
  pkgs,
  lib,
  ...
}:

{
  home.activation.installClaude = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ! command -v claude &> /dev/null; then
      curl -fsSL https://claude.ai/install.sh | sh || echo "⚠ Failed to install Claude Code CLI"
    fi
  '';

  home.activation.yaziPackages = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if command -v ya &> /dev/null; then
      ya pkg install || echo "⚠ Failed to install yazi packages"
    fi
  '';
}
