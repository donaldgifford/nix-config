{ lib, pkgs, ... }:

{
  # Opens a URL in a terminal-browser split beside the calling pane (INV-0003).
  # A real file on PATH because mdp and docz-review run $BROWSER as a single
  # program; Neovim's keymaps call it too.
  home.packages = [
    (pkgs.writeScriptBin "terminal-browser-split" (
      builtins.readFile ../../config/rex/terminal-browser-split
    ))
  ];

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
    # Rex renders OSC 8 hyperlinks, but supports-hyperlinks-style detection
    # (Claude Code's PR links, etc.) only allowlists known TERM_PROGRAMs and
    # "rex" isn't one, so links fall back to plain underlined text.
    if [ "$TERM_PROGRAM" = rex ]; then
      export FORCE_HYPERLINK=1
      # docz-review pages open beside the agent, not in the system browser.
      # Not $BROWSER: that would redirect every tool that opens a URL.
      export DOCZ_REVIEW_BROWSER=terminal-browser-split
    fi
  '';
}
