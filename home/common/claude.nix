{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Status line script, linked out of the store so edits are live. Claude
  # Code's settings.json (which points at it) stays unmanaged. `force`
  # replaces the plain file that predates this link.
  home.file.".claude/statusline-command.sh" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/code/nix-config/config/claude/statusline-command.sh";
    force = true;
  };

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
