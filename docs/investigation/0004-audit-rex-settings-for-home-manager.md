---
id: INV-0004
title: "Audit Rex settings for Home Manager"
status: In Progress
author: Donald Gifford
created: 2026-11-26
---

<!-- markdownlint-disable-file MD025 MD041 -->

# INV-0004: Audit Rex settings for Home Manager

<!--toc:start-->
<!-- markdownlint-capture -->
<!-- markdownlint-disable MD013 -->
- [Question](#question)
- [Hypothesis](#hypothesis)
- [Context](#context)
- [Approach](#approach)
- [Environment](#environment)
- [Findings](#findings)
  - [Seven UI settings are set but not pinned](#seven-ui-settings-are-set-but-not-pinned)
  - [Rex documents 162 settings and we pin about 26](#rex-documents-162-settings-and-we-pin-about-26)
  - [New since 2026-11-24: session restore with resume rules](#new-since-2026-11-24-session-restore-with-resume-rules)
  - [rex.set does not exist on the installed build](#rexset-does-not-exist-on-the-installed-build)
  - [rex.set is planned to cover all settings](#rexset-is-planned-to-cover-all-settings)
  - [New since 2026-11-24: Quick Terminal](#new-since-2026-11-24-quick-terminal)
  - [The new quick switcher and the imported prefix keys](#the-new-quick-switcher-and-the-imported-prefix-keys)
- [Conclusion](#conclusion)
- [Recommendation](#recommendation)
  - [Today](#today)
  - [Deferred](#deferred)
- [References](#references)
<!-- markdownlint-restore -->
<!--toc:end-->

<!--docz:question:start-->
## Question

Rex is a preview app and changes quickly. Which of its settings should this
repo manage that it does not manage today, and which should wait?

<!--docz:question:end-->

<!--docz:hypothesis:start-->
## Hypothesis

Some Settings-UI choices have drifted from what `darwin.nix` pins, and recent
Rex releases have probably added options worth setting.

<!--docz:hypothesis:end-->

<!--docz:context:start-->
## Context

Rex has two config surfaces. `config/rex/init.lua` holds key bindings and
actions and is read by the Rex server. Settings-UI preferences live in the
`com.superlogical.rex` defaults domain, and `hosts/macbook/darwin.nix` pins
about 26 of them through `CustomUserPreferences`. The pins were last reviewed
in PR #141.

This document is numbered 0004 on purpose. INV-0003 belongs to the unmerged
terminal-browser work in PR #148.

**Triggered by:** a review of the Rex setup after the terminal-browser trial

<!--docz:context:end-->

<!--docz:approach:start-->
## Approach

1. Export the live `com.superlogical.rex` preferences and compare the keys
   with the block pinned in `hosts/macbook/darwin.nix`.
2. Fetch the Rex docs (`llms-full.txt`) and compare the headings and the
   documented settings with a copy fetched on 2026-11-24.
3. Test on the installed build whether the new `rex.set` call exists.
4. Check that the agent hook the new resume feature depends on is installed.

<!--docz:approach:end-->

<!--docz:environment:start-->
## Environment

| Component | Version / Value                                     |
| --------- | --------------------------------------------------- |
| Rex       | 0.1.0-preview.21, built 2026-11-17, app build 2147  |
| Rex docs  | fetched 2026-11-24 and 2026-11-26                   |
| macOS     | Darwin 27.2.0, Apple Silicon                        |

<!--docz:environment:end-->

<!--docz:findings:start-->
## Findings

### Seven UI settings are set but not pinned

`CustomUserPreferences` writes only the keys it lists, so these survive a
switch on this machine. A new machine would not get them.

| Key | Current value | Decision |
| --- | --- | --- |
| `Workspace.focusFollowsMouse` | `true` | Pin now |
| `Workspace.activityGrouping` | `priority` | Pin now |
| `RexAppUpdateChannel` | `preview` | Pin now |
| `rex.developer-mode-enabled` | `true` | Pin now |
| `Workspace.lightThemeID` | `merino-light` | Defer |
| `rex.server.run-mode` | `bundled` | Defer |
| `rex.server.web-client-origin-patterns` | `https://rex.superlogical.com` | Defer |

Why three are deferred:

- `Workspace.lightThemeID`: the theme switcher owns `darkThemeID`, and
  nothing owns the light theme yet. It belongs with the switcher.
- `rex.server.run-mode` and the origin pattern look like defaults that Rex
  wrote itself. Pinning a default adds noise and can fight a future change.

The remaining unpinned keys are app state and should not be pinned:
onboarding, last focused session, activity history, imported themes, sync
hosts and cached routes.

### Rex documents 162 settings and we pin about 26

The preferences file stores only values that differ from the default. The
docs name each setting by its UI label, not by its defaults key. To pin a
setting we have not changed, someone has to toggle it in the UI and read the
key back.

Settings that look relevant to this setup and are still at their defaults:

- **SSH agent socket**: we use the 1Password agent.
- **Option key**: sends Alt or types special characters. It may affect the
  `alt+g` lazygit binding.
- **Autobalance splits**: resizes panes when one opens or closes. It is the
  reason terminal-browser's split size was ignored in upstream reports.
- **Shell startup command**.

### New since 2026-11-24: session restore with resume rules

The docs gained three pages: Session Restore, Resume Rules, and the Program
Resume Protocol (OSC 7577).

- After a server restart, Rex restores sessions, tabs and panes. A pane that
  ran a program which reports a resume command gets that program back, if a
  trust rule allows it.
- Rex ships rules for Claude Code, Codex and OpenCode. Only Claude Code
  reports today, through the hook that `rex skill setup` installs.
  `rex skill status` shows that hook as current here.
- Claude Code comes back in the same pane and conversation with its original
  flags, but with a new terminal's environment.
- Rules are set in `init.lua` with a new call, `rex.set`:

  ```lua
  rex.set("resume.trust.claude.dir", "~/code")
  rex.set("resume.trust.codex", false)
  ```

- A rule can also be added for other programs. The docs include a Neovim
  example of under 20 lines.

### `rex.set` does not exist on the installed build

On 0.1.0-preview.21, a file containing only a `rex.set` call fails
`rex config check`:

```text
error init.lua:1: attempt to call a non-function object
Error: the configuration has errors
```

An unguarded `rex.set` in `init.lua` would therefore break the config until
Rex updates. A guard keeps the file loadable on both builds:

```lua
if rex.set then
  rex.set("resume.trust.claude.dir", "~/code")
end
```

The rules cannot be exercised until a build with `rex.set` is installed.

### `rex.set` is planned to cover all settings

The docs say settings are used only for resume rules today, and that a future
version will use the same interface for all general settings. When that
lands, the pinned block in `darwin.nix` can move into `init.lua`. That
removes the "restart Rex to see them" step and the one-way overwrite on
switch.

### New since 2026-11-24: Quick Terminal

An experimental drop-down terminal window with about ten settings (size,
position, transparency, which host it opens on). It sits behind an
experimental-features toggle.

### The new quick switcher and the imported prefix keys

The experimental "New quick switcher" was turned on during this
investigation. Its key is `Workspace.experiments.usesNewQuickSwitcher`. It
changes Go to Anything (`pane.go_to`, default `cmd+p`) into one list of every
session, block and reporting process.

`init.lua` has 51 bindings on a `ctrl+b` prefix, carried over from tmux and
herdr. Compared with Rex's built-in actions on this build:

- **Out of date.** `prefix s` and `prefix T` open `session.switch`, the older
  session-only picker. The new switcher is reached through `pane.go_to`,
  which no prefix key runs.
- **Mismatched.** `prefix [` opens Find. Rex has a real vi-style copy mode
  (`pane.copy_mode.enter`), which is what `prefix [` means in tmux.
- **Missing.** No prefix key reaches `pane.move.*` (move a pane),
  `client.navigate.back` and `forward`, `session.undo_close`, or
  `session.new`.
- **Still needed.** Eight bound actions have no built-in shortcut, so the
  prefix is the only way to reach them: `pane.resize`, `pane.balance`,
  `pane.move_to_new_tab`, `client.tab.rename`, `session.rename`,
  `session.next`, `session.previous` and `client.config.reload`. The lazygit
  popup is ours as well.
- **Duplicated.** Everything else has a built-in `cmd` shortcut too. Some
  prefix keys are also doubled for herdr (`v`, `shift+r`, `ctrl+h/j/k/l`,
  `ctrl+y`), which is no longer in use.

All the actions named here exist on 0.1.0-preview.21 (`rex actions`).

**Decision:** remove the whole prefix map and try Rex's defaults. `cmd+p`
covers the switcher, `cmd+f` covers Find, and `cmd+d` covers nearly every
split. The lazygit popup stays and moves from `prefix alt+g` to
`ctrl+cmd+g`, which no default uses. With the prefix gone, `ctrl+b` reaches
the terminal again.

<!--docz:findings:end-->

<!--docz:conclusion:start-->
## Conclusion

The hypothesis held in part. Four UI choices have drifted and are worth
pinning. The one significant new feature, resume rules, is configured in
`init.lua` but needs a newer Rex build than the one installed. A broad sweep
of the other settings is poor value right now, because the supported way to
set them is about to change.

**Answer:** Yes, a few. Pin four settings and add guarded resume rules today. Defer the
rest until `rex.set` covers general settings.

<!--docz:conclusion:end-->

<!--docz:recommendation:start-->
## Recommendation

### Today

- [x] Pin `Workspace.focusFollowsMouse`, `Workspace.activityGrouping`,
      `RexAppUpdateChannel` and `rex.developer-mode-enabled` in
      `hosts/macbook/darwin.nix`.
- [x] Add resume rules to `config/rex/init.lua` behind an `if rex.set` guard:
      resume Claude Code only under `~/code`.
- [x] Remove the tmux/herdr `ctrl+b` prefix bindings from
      `config/rex/init.lua` and use Rex's default keys. Keep the lazygit
      popup on `ctrl+cmd+g`.

### Deferred

| Item | Revisit when |
| --- | --- |
| Verify the resume rules by restarting the server with Claude Code running | Rex updates to a build with `rex.set` |
| Add a Neovim resume rule | The Claude Code rule is proven |
| Decide whether a Claude Code started with `--dangerously-skip-permissions` should resume | Same |
| Move the pinned preferences from `darwin.nix` into `init.lua` | `rex.set` covers general settings |
| Pin SSH agent socket, Option key, autobalance splits, shell startup command | Each is toggled in the UI once so its key can be read, or `rex.set` covers it |
| Own `Workspace.lightThemeID` in the theme switcher | A light theme is added to `config/themes` |
| Rebind any of the eight actions that have no built-in shortcut (resize, balance, move pane to new tab, tab and session rename, session next/previous, config reload) | One is missed in daily use; until then they are in the command palette |
| Pin `Workspace.experiments.usesNewQuickSwitcher` | The switcher has been used for a while and is staying on |
| Try Quick Terminal | It leaves the experimental toggle, or on demand |
| Pin `rex.server.run-mode` and the web-client origin pattern | Only if they turn out not to be defaults |

<!--docz:recommendation:end-->

<!--docz:references:start-->
## References

- [Rex docs: configuration file](https://www.superlogical.com/rex/docs/customize/config.md)
- [Rex docs: session restore](https://www.superlogical.com/rex/docs/features/session-restore.md)
- [Rex docs: resume rules](https://www.superlogical.com/rex/docs/customize/resume-rules.md)
- [hosts/macbook/darwin.nix](../../hosts/macbook/darwin.nix)
- [config/rex/init.lua](../../config/rex/init.lua)
- [config/themes/theme-switch.sh](../../config/themes/theme-switch.sh)

<!--docz:references:end-->
