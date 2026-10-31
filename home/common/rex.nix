{ lib, ... }:

{
  # Rex (agentic terminal multiplexer) prepends its server's bin dir to PATH
  # and exports REX_BIN_DIR, but our zshrc then rebuilds PATH (krew, mise),
  # dropping `rex`. Re-prepend it last so the CLI matching the running server
  # wins. Order 2000 lands after HM's mkAfter (1500) hooks — starship, mise,
  # direnv. Not via home.sessionPath: outside Rex the var is empty and would
  # add a blank PATH entry. https://www.superlogical.com/rex/docs/automate/cli#path
  programs.zsh.initContent = lib.mkOrder 2000 ''
    # ── Rex CLI ───────────────────────────────────────────────────────────
    if [ -n "$REX_BIN_DIR" ]; then
      export PATH="$REX_BIN_DIR:$PATH"
    fi
  '';
}
