---
id: INV-0003
title: "Set up terminal-browser in Rex"
status: Concluded
author: Donald Gifford
created: 2026-11-24
---

<!-- markdownlint-disable-file MD025 MD041 -->

# INV-0003: Set up terminal-browser in Rex

<!--toc:start-->
<!-- markdownlint-capture -->
<!-- markdownlint-disable MD013 -->
- [Question](#question)
- [Hypothesis](#hypothesis)
- [Context](#context)
- [Approach](#approach)
- [Environment](#environment)
- [Findings](#findings)
  - [Packaging: the Homebrew cask](#packaging-the-homebrew-cask)
  - [Packaging: mise was tried and rejected](#packaging-mise-was-tried-and-rejected)
  - [The Rex backend drives the rex CLI](#the-rex-backend-drives-the-rex-cli)
  - [Rex answers the kitty graphics query](#rex-answers-the-kitty-graphics-query)
  - [A split pane does not have rex on PATH](#a-split-pane-does-not-have-rex-on-path)
  - [Open upstream issues for Rex](#open-upstream-issues-for-rex)
  - [First run writes outside the repo](#first-run-writes-outside-the-repo)
  - [The Claude Code plugin is a separate, riskier step](#the-claude-code-plugin-is-a-separate-riskier-step)
  - [Hands-on results: the basics work](#hands-on-results-the-basics-work)
  - [Hands-on results: page zoom jumps in Rex](#hands-on-results-page-zoom-jumps-in-rex)
  - [Hands-on results: mdp, docz HTML and docz-review](#hands-on-results-mdp-docz-html-and-docz-review)
  - [Hands-on results: other things to know](#hands-on-results-other-things-to-know)
  - [Install footprint and removal](#install-footprint-and-removal)
- [Conclusion](#conclusion)
- [Recommendation](#recommendation)
- [References](#references)
<!-- markdownlint-restore -->
<!--toc:end-->

<!--docz:question:start-->
## Question

Can we add [terminal-browser](https://github.com/zenbu-labs/terminal-browser)
to this flake and wire it into our Rex setup, now that upstream lists Rex as a
supported terminal? What does the setup consist of, and what does it change on
the machine?

<!--docz:question:end-->

<!--docz:hypothesis:start-->
## Hypothesis

It should be a small change: a Homebrew cask, a Rex keybinding, and maybe a
config symlink. Rex support landed upstream only this month, so some rough
edges are likely.

<!--docz:hypothesis:end-->

<!--docz:context:start-->
## Context

Rex replaced tmux and herdr as the multiplexer on the mac (PR #140).
terminal-browser draws a real Chromium page in a terminal pane with the kitty
graphics protocol, and an agent can drive it. That gives a coding agent and a
web page in one Rex tab. Release v0.16.1 (2026-11-24) added Rex to the list of
supported terminals.

**Triggered by:** terminal-browser v0.16.1 adding Rex support

<!--docz:context:end-->

<!--docz:approach:start-->
## Approach

1. Read the upstream README, the Rex backend (`rex.ts`), the CLI setup and
   config code, the Homebrew cask, and the open Rex issues.
2. Check on this machine that every `rex` subcommand the backend calls exists.
3. Run a probe script in a short-lived `rex split` pane. It sends the same
   kitty graphics query that terminal-browser sends, and records the reply and
   the environment a split command gets.
4. Compare what the tool writes on first run with how this repo manages
   `~/.config` and `~/.claude`.

5. Install the cask, then use it by hand in Rex: a plain split, the mdp
   markdown preview from Neovim, a `docz export html` page, and a `docz-review`
   round.
6. Script the same flows in throwaway Rex panes and read the page zoom back
   with `terminal-browser action -- eval devicePixelRatio`.

Steps 1 to 4 were desk research before the install. The findings under
"Hands-on results" come from steps 5 and 6.

<!--docz:approach:end-->

<!--docz:environment:start-->
## Environment

| Component        | Version / Value                                    |
| ---------------- | -------------------------------------------------- |
| terminal-browser | 0.16.1 for the desk research, 0.16.3 installed (cask) |
| Rex              | 0.1.0-preview.21, built 2026-11-17, API revision 18 |
| mise             | 2026.10.17 (trial install only)                    |
| mdp              | 0.6.1                                              |
| docz-review      | 2.6.1                                              |
| Claude Code      | 2.1.322                                            |
| macOS            | Darwin 27.2.0, Apple Silicon                       |

<!--docz:environment:end-->

<!--docz:findings:start-->
## Findings

### Packaging: the Homebrew cask

- `nix search nixpkgs terminal-browser` finds nothing.
- It is in the main `homebrew-cask` repository as `terminal-browser`, so it
  needs no tap and no `trusted:` entry. The cask installs one binary and
  supports macOS and Linux.
- The cost: `homebrew.onActivation.upgrade = true` upgrades casks on every
  switch, casks cannot be pinned, and upstream releases almost daily (0.15.6
  to 0.16.3 in six days). The version can change under us on any `nrs`.
- `terminal-browser upgrade`, the tool's own updater, is not needed. Under
  Homebrew it only prints the `brew upgrade` command.

### Packaging: mise was tried and rejected

mise's `github:` backend can install a pinned version from the GitHub
releases, which would fix the auto-upgrade. It was working on this branch and
then reverted, because it is worse in every other way:

- A plain mise install does not run. The tarball contains 228 AppleDouble
  `._*` files. macOS `tar` folds them into file attributes, but mise extracts
  them as real files inside the signed `.app`. `codesign --verify` then fails
  with "a sealed resource is missing or invalid" and macOS kills the process
  on launch. It needs a `postinstall` step that deletes them.
- mise tools are not on PATH for a Rex block's command, so the `prefix b`
  binding has to run `mise exec -- terminal-browser`.
- terminal-browser names its data directories after a hash of its install
  path. Under mise the path contains the version, so every bump starts a
  fresh browser profile and leaves the old directories behind. The cask path
  is special-cased upstream and keeps one profile.
- The agent skill links point into the versioned install directory, so they
  break when that version is removed.

If the daily upgrades become a problem, revisit this, or ask upstream to drop
the AppleDouble files from the tarball.

### The Rex backend drives the `rex` CLI

Rex does not implement terminal-browser's socket API
(`TERMINAL_BROWSER_TERMINAL_SOCKET` is unset in our panes). terminal-browser
uses its built-in backend instead, which detects Rex from `REX_BLOCK` or
`TERM_PROGRAM=rex` and runs the `rex` binary from `REX_BIN_DIR`.

Every command it calls exists on our Rex build:

| Backend operation | Rex command                                    | Present |
| ----------------- | ---------------------------------------------- | ------- |
| list panes        | `rex block ls --json`                          | yes     |
| pane tty          | `rex block call process --block`               | yes     |
| neighbor pane     | `rex window inspect --json`                    | yes     |
| send text, paste  | `rex send --block`                             | yes     |
| focus             | `rex focus`                                    | yes     |
| split             | `rex split --block --split`                    | yes     |
| split size        | `rex api call session.resize_pane`             | yes     |
| zoom detection    | `rex session inspect --json`, `rex events -s`  | yes     |

None of these are `rex do client.*` actions, so the backend should not depend
on Remote Control. This was not tested.

### Rex answers the kitty graphics query

The probe pane got this reply to terminal-browser's own query:

```text
graphics_reply = ESC _ G i=4207;OK ESC \   ESC [ ?62;22c
pixels_reply   = ESC [ 4;384;640 t
```

Rex reports kitty graphics support and the pane size in pixels, so
terminal-browser's startup check will pass.

### A split pane does not have `rex` on PATH

The probe also recorded the environment of a `rex split -- COMMAND` pane:

```text
PATH=~/.local/bin:/opt/homebrew/bin:~/.nix-profile/bin:...
rex=None
REX_BIN_DIR=.../Rex Server.app/Contents/MacOS
```

- `/opt/homebrew/bin` is on PATH, so a pane can start `terminal-browser`.
- `rex` is not. Our fix in `home/common/rex.nix` re-adds `REX_BIN_DIR` in
  `.zshrc`, and Rex runs split commands without the interactive config.
- The backend is unaffected, because it uses `REX_BIN_DIR`.
- `browser/src/ui/rex-zoom.ts` runs a bare `rex` and ignores errors. In a
  browser opened with `--split`, zoom detection probably fails silently. The
  visible effect would be toolbar buttons under Rex's zoom controls while the
  pane is zoomed.

### Open upstream issues for Rex

- [#244](https://github.com/zenbu-labs/terminal-browser/issues/244) (open):
  on 0.15.3 the page went blank and Rex showed "Reconnecting…" while
  scrolling, with the Rex server at about 110% CPU. The workaround was
  `render.presenter patched` and `render.fps 30`. Later releases added
  Rex-specific rendering (tiles, a cell-grid renderer, scroll offsets), but
  nobody has confirmed a fix on the issue.
- [#258](https://github.com/zenbu-labs/terminal-browser/issues/258) (open):
  `--split --size` was ignored. v0.16.1 contains a fix that resizes with
  `session.resize_pane`; the issue has not been closed.

### First run writes outside the repo

On the first run of any command, terminal-browser:

- symlinks its agent skill into `~/.claude/skills/terminal-browser` and
  `~/.agents/skills/terminal-browser`, without asking;
- sets `terminal.integrated.enableImages` in the user settings of every VS
  Code-style editor it finds;
- starts usage telemetry and crash reports, both on by default. Either of
  `DO_NOT_TRACK=1` or `TERMINAL_BROWSER_NO_TELEMETRY=1` turns both off.

Settings live in `~/.config/terminal-browser/settings.json` and
`shortcuts.json`. They fit the `config/` symlink pattern, but the settings GUI
and `terminal-browser config set` write to them.

### The Claude Code plugin is a separate, riskier step

Upstream also ships a plugin that draws the browser inside the Claude Code
pane (`/browser`). It is not needed for `terminal-browser open --split`.

- It needs `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1` and a plugin install. Both go
  in `~/.claude/settings.json`, which this repo does not manage.
- It needs kitty unicode placeholders. Upstream lists only ghostty, kitty and
  libghostty terminals for the plugin, not Rex.
- Upstream warns that multiplexers break it, and Rex is one.
- Upstream calls it experimental.

### Hands-on results: the basics work

After installing the cask (0.16.3):

- `terminal-browser open <url> --split right` opens a working browser pane.
- A `browser_split` action bound to `prefix b` opens one beside the focused
  pane.
- A process with no terminal attached can open a split, because the backend
  finds the calling pane from `REX_BLOCK`. This is what lets other tools use
  it as their browser.
- A local HTML file path opens the same way as a URL.
- Clicking a link in Rex still opens the macOS default browser. Rex has no
  setting for the link handler, and that is the behavior we want.

Two usability limits showed up in use:

- Heavy pages lag a bit when scrolling. The blank pane and "Reconnecting…"
  banner from #244 were not seen.
- A half-width split is narrow for pages with a sidebar. docz-review's
  two-column layout squeezes the document into a column that is hard to read.
  That is the page's layout, not terminal-browser's. Zooming the pane
  (`prefix z`) or lowering page zoom (cmd+-) gives it room.

The toolbar in a zoomed pane was not checked.

### Hands-on results: page zoom jumps in Rex

This is the one real defect found.

- About a second after a pane opens, the page zoom is multiplied by about 2.4
  (100% becomes 238%).
- terminal-browser saves zoom per host name and ignores the port, so the bad
  zoom sticks. It compounds on the next open, up to the 500% cap. Every
  preview on `127.0.0.1` shares it.
- This matches upstream
  [#166](https://github.com/zenbu-labs/terminal-browser/issues/166): zoom
  follows the terminal's cell size, and the change is saved.
- Reset-zoom (cmd+0 or ctrl+0) in the pane fixes it. Sending `ctrl+0` to the
  pane with `rex send-key` works too.
- Opening each preview on a fresh `*.localhost` name avoids the saved zoom,
  but not the jump itself, and `docz-review` rejects any host except the
  exact `127.0.0.1` address. That approach was dropped.
- With one `ctrl+0` two seconds after the pane appears, 19 of 20 scripted
  opens ended at 100%. A second press was added after the miss and is
  unverified.
- Upstream PR
  [#331](https://github.com/zenbu-labs/terminal-browser/pull/331) adds a
  default-zoom setting and a `--zoom` flag. It is not merged.

### Hands-on results: mdp, docz HTML and docz-review

All three tools can use terminal-browser through one wrapper script,
`terminal-browser-split`, which runs `terminal-browser open --split right`
and then resets zoom.

- **mdp.** The server honors `$BROWSER` and runs it as a single program with
  the URL as its only argument, hence the wrapper. Two plugin behaviors got
  in the way of reopening a closed preview: `:MdpToggle` stops a running
  server, and `:MdpOpen` and `:MdpPreview` call macOS `open` directly. The
  plugin's own `lazy.lua` binds `<leader>mp` to `:MdpPreview`, which is why a
  second press went to Firefox.
- **docz HTML.** `docz export html <file> --out <dir> --format json` reports
  the page path, and terminal-browser opens the file. Nothing had to be built
  in docz. The page is a static export, not a live preview.
- **docz-review.** It honors `DOCZ_REVIEW_BROWSER`, then `BROWSER`. A full
  round worked with a real mouse selection: the comment came back to the
  terminal as an annotation.

### Hands-on results: other things to know

- "Send to agent" is always in terminal-browser's right-click menu. There is
  no setting to hide it. Only its `ctrl+g` shortcut can be unbound. It
  overlaps with docz-review's own annotations but did not break them.
- `terminal-browser action` leaves an `agent-browser` process behind on each
  call. 41 had built up during testing. After that, `action` could no longer
  connect to a browser in the same daemon.
- Browsers in different Rex tabs share one daemon.

### Install footprint and removal

Checked on this machine after real use. `<hash>` is 8 hex characters derived
from the install path. For the cask it stays the same across versions; here
it is `58a67c5b`.

| Path | What it is | Created by |
| --- | --- | --- |
| `/opt/homebrew/Caskroom/terminal-browser/<version>/` | The tool, about 300 MB: CLI, Chromium (Electron), `agent-browser`, skills | cask |
| `/opt/homebrew/bin/terminal-browser` | Symlink to the launcher | cask |
| `~/.claude/skills/terminal-browser` | Symlink to the agent skill | first run |
| `~/.agents/skills/terminal-browser` | Same | first run |
| `~/.codex/skills/terminal-browser` | Same, Codex variant | first run |
| `~/.local/state/terminal-browser/` | Setup marker and the list of skill links | first run |
| `~/.local/share/terminal-browser-<hash>/` | Browser profile and database | first browser |
| `~/.local/state/terminal-browser-<hash>/` | Logs, daemon socket, instance and agent sockets | first browser |
| `~/.local/state/terminal-browser-interop/` | Cross-instance state | first browser |
| `~/.cache/terminal-browser-<hash>/` | Favicons (not present yet here) | browsing |
| `~/.config/terminal-browser/` | `settings.json`, `shortcuts.json` (empty until a setting changes) | first run |

It would also link the skill into `~/.cursor/skills` and `~/.gemini/skills`
if those directories existed, and set `terminal.integrated.enableImages` in
any VS Code-style editor's user settings. Neither applied here. It installed
no Claude Code plugin and no hooks, and it did not touch
`~/.claude/settings.json`.

A daemon keeps running after the last browser closes, and each
`terminal-browser action` call can leave an `agent-browser` process.

To remove terminal-browser completely:

1. Stop it: `terminal-browser shutdown`, then
   `pkill -f agent-browser/bin/agent-browser`.
2. Delete the `"terminal-browser"` line from `homebrew.casks` in
   `hosts/macbook/darwin.nix` and switch. Because `cleanup = "zap"`, Homebrew
   uninstalls the cask and runs its zap list, which deletes the skill links
   and the `terminal-browser-*` data, state and cache directories.
3. Check for leftovers. The zap was not exercised in this investigation, and
   its list does not include `~/.config/terminal-browser`:
   `rm -rf ~/.config/terminal-browser`.
4. To do it by hand instead of relying on zap:
   `rm ~/.claude/skills/terminal-browser ~/.agents/skills/terminal-browser ~/.codex/skills/terminal-browser`
   and
   `rm -rf ~/.local/share/terminal-browser-* ~/.local/state/terminal-browser ~/.local/state/terminal-browser-* ~/.cache/terminal-browser-*`.
5. Revert the repo changes listed under Recommendation. Each one is inert
   without the binary, but the `prefix b` binding would open a pane that
   fails.

<!--docz:findings:end-->

<!--docz:conclusion:start-->
## Conclusion

terminal-browser works in Rex and is now set up on this branch. The cask
installs cleanly, Rex passes the graphics check, and the backend's Rex
commands all exist on our build. It also works as the browser for mdp, docz
HTML exports and docz-review.

The hypothesis held on size and on rough edges. The setup is small, and there
is one real defect: page zoom jumps when a pane opens in Rex. We work around
it with a reset-zoom key press, which is not fully reliable.

**Answer:** Yes. It is set up and usable, with a zoom workaround that should
be removed when upstream fixes #166.

<!--docz:conclusion:end-->

<!--docz:recommendation:start-->
## Recommendation

Merge the setup on this branch. It contains:

| Change | Where |
| --- | --- |
| `terminal-browser` cask | `hosts/macbook/darwin.nix` |
| `TERMINAL_BROWSER_NO_TELEMETRY=1` | `home/darwin.nix` |
| `terminal-browser-split` wrapper on PATH | `config/rex/terminal-browser-split`, `home/common/rex.nix` |
| `DOCZ_REVIEW_BROWSER` exported inside Rex | `home/common/rex.nix` |
| `prefix b` opens a browser split | `config/rex/init.lua` |
| mdp previews open in a split and can be reopened | `config/nvim/lua/plugins/mdp.lua`, `config/nvim/bin/mdp-browser` |
| `<leader>mh` previews a docz HTML export | `config/nvim/lua/config/keymaps.lua` |

Notes on how it behaves:

- Everything is conditional on `TERM_PROGRAM=rex`. Outside Rex the tools use
  the system browser as before.
- `$BROWSER` is set only inside Neovim, for mdp. Setting it for the whole
  shell would redirect every tool that opens a URL.
- Inside Rex, `<leader>mp`, `<leader>cp` and `<leader>mo` start the preview or
  reopen it. They no longer stop it. Use `:MdpStop`, or let the idle timeout
  stop it.
- `nrs` applies the cask, the wrapper and the environment variables. The Rex
  and Neovim files are live symlinks into the main checkout, so they apply on
  merge. Rex also needs `rex config reload`.
- The cask upgrades on every `nrs`. Expect the version to move often.

Follow-ups:

1. Check that the second reset-zoom press closes the gap. If panes still open
   zoomed, retime it in `config/rex/terminal-browser-split`.
2. Remove the reset-zoom workaround when upstream fixes #166 or merges #331.
3. Teach mdp's `:MdpOpen` to honor `$BROWSER`. Then the URL file and the
   `mdp-browser` wrapper can go.
4. Check the toolbar in a zoomed pane. If zoom detection fails, put `REX_BIN_DIR` on PATH for non-interactive
   shells and confirm with `rex split --wait -- sh -c 'command -v rex'`.
5. Report the `agent-browser` process leak upstream, and watch for it once
   agents use `terminal-browser action` regularly.
6. Ask upstream for a setting that hides "Send to agent" if it becomes
   confusing next to docz-review.
7. Leave `~/.config/terminal-browser` unmanaged until the settings settle.
8. Skip the Claude Code plugin until upstream supports Rex for it.
9. Report the AppleDouble files in the release tarball upstream. Without
   them a pinned mise install would be worth another look.

<!--docz:recommendation:end-->

<!--docz:references:start-->
## References

- [terminal-browser](https://github.com/zenbu-labs/terminal-browser) and its
  [Rex backend](https://github.com/zenbu-labs/terminal-browser/blob/main/pixel/packages/pixel/src/terminal/terminals/rex.ts)
- [Homebrew cask](https://github.com/Homebrew/homebrew-cask/blob/HEAD/Casks/t/terminal-browser.rb)
- [Claude Code plugin README](https://github.com/zenbu-labs/terminal-browser/blob/main/claude-code-plugin/README.md)
- Upstream issues [#166](https://github.com/zenbu-labs/terminal-browser/issues/166),
  [#244](https://github.com/zenbu-labs/terminal-browser/issues/244)
  and [#258](https://github.com/zenbu-labs/terminal-browser/issues/258)
- [Rex CLI docs](https://www.superlogical.com/rex/docs/automate/cli)
- [home/common/rex.nix](../../home/common/rex.nix)
- [config/rex/init.lua](../../config/rex/init.lua)
- [config/rex/terminal-browser-split](../../config/rex/terminal-browser-split)
- [config/nvim/lua/plugins/mdp.lua](../../config/nvim/lua/plugins/mdp.lua)
- [hosts/macbook/darwin.nix](../../hosts/macbook/darwin.nix)
- [INV-0002: Evaluate herdr as tmux replacement](0002-evaluate-herdr-as-tmux-replacement.md)

<!--docz:references:end-->
