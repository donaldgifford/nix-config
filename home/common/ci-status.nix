{ pkgs, ... }:

# ci-status: CI state of HEAD for the starship prompt and the Claude Code
# status line, read from GitHub only (Buildkite posts commit statuses there).
# Cache-only on the prompt path; a detached refresh does the one `gh` call.
# Design: docs/design/0002, plan: docs/impl/0002. Same shape as temporal-oidc:
# a command on PATH so starship (bash) and the status line can both call it.
let
  ci-status = pkgs.writeShellApplication {
    name = "ci-status";
    runtimeInputs = with pkgs; [
      gh
      jq
      git
      coreutils
    ];
    text = builtins.readFile ./ci-status/ci-status.sh;
  };
in
{
  home.packages = [ ci-status ];
}
