---
id: INV-0002
title: "Evaluate herdr as tmux replacement"
status: Open
author: Donald Gifford
created: 2026-07-06
---
<!-- markdownlint-disable-file MD025 MD041 -->

# INV 0002: Evaluate herdr as tmux replacement

**Status:** Open
**Author:** Donald Gifford
**Date:** 2026-07-06

<!--toc:start-->
- [Question](#question)
- [Hypothesis](#hypothesis)
- [Context](#context)
- [Current tmux Investment](#current-tmux-investment)
- [What herdr Offers](#what-herdr-offers)
- [Migration Mapping](#migration-mapping)
- [Approach](#approach)
- [Environment](#environment)
- [Findings](#findings)
  - [Observation 1: Feature coverage](#observation-1-feature-coverage)
  - [Observation 2: Nix integration](#observation-2-nix-integration)
- [Risks / Open Questions](#risks--open-questions)
- [Conclusion](#conclusion)
- [Recommendation](#recommendation)
- [References](#references)
<!--toc:end-->

## Question

Can [herdr](https://herdr.dev/) replace tmux in this config without losing
the workflows we depend on — sesh-driven session switching, Claude Code
status notifications, tokyo-night theming, and vi-mode navigation — while
gaining its agent-aware features (semantic agent state, socket API,
agent-native session resume)?

## Hypothesis

Partial replacement is feasible today; full replacement is premature.
herdr's core multiplexing (workspaces/tabs/panes, persistence, SSH attach)
covers tmux's fundamentals, and its agent-state tracking would replace our
custom `claude-tmux-notify` plugin outright. But the sesh + fzf switcher
workflow and tokyo-night status bar have no herdr equivalents, and herdr
is pre-1.0 (v0.7.1) with a young plugin ecosystem.

## Context

We run multiple Claude Code sessions across projects daily. Our tmux setup
exists in large part to serve that workflow — the `claude-tmux-notify`
plugin (our own, donaldgifford/claude-tmux-notify) adds status-bar
notifications and a picker for Claude sessions awaiting input. herdr makes
that entire category first-class: it tracks semantic agent state (blocked /
working / done / idle) natively and exposes a JSON socket API for
orchestration. The question is whether the rest of our tmux investment
ports over.

**Triggered by:** ongoing agentic workflow tooling improvements (see
`home/common/tmux.nix`, claude-tmux-notify plugin)

## Current tmux Investment

What we'd have to replace, from `home/common/tmux.nix` and friends:

| Piece | What it does | herdr equivalent? |
|-------|--------------|-------------------|
| `programs.tmux` (HM module) | declarative install + config | ❌ no HM module — flake package + hand-written config |
| `sensible`, `pain-control` | sane defaults, pane nav bindings | ⚠️ partial — herdr has its own prefix-key model (default `ctrl+b`); `vim-herdr-navigation` plugin covers C-hjkl |
| `logging` plugin | pane logging | ⚠️ pane history replay is native; file logging unknown |
| `claude-tmux-notify` (ours) | Claude status in status bar + picker (`C-c`/`C-y`) | ✅ **native** — semantic agent states are herdr's core feature |
| `fzf-tmux-url` | URL picker | ✅ native link handlers + `herdr-pluck`/`herdr-fingers` plugins |
| `tokyo-night-tmux` theme | status bar + theming | ❌ built-in themes only; plugins **cannot** add status bar items (v1 limit) |
| sesh + fzf switcher (`T`/`R`/`N` binds) | zoxide-aware session switching | ⚠️ `herdr-sessionizer` plugin — fuzzy project/worktree open + TOML layouts |
| `sesh/sesh.toml` config | session presets | ⚠️ port to `herdr-sessionizer` TOML layouts or `herdr-spreader` YAML |
| vi keyMode, copy mode | vi-style scrollback/copy | ❓ needs hands-on verification |
| `detach-on-destroy off`, popup binds | QoL behaviors | ❓ needs hands-on verification |
| shell integration (`fzf.tmux.enableShellIntegration`, `sp` alias) | fzf popups via tmux | ⚠️ fzf-tmux popups are tmux-specific |

## What herdr Offers

From herdr.dev (v0.7.1, ~12.9k stars, actively pushed as of 2026-07-06):

- Real PTY panes, tabs, workspaces; mouse-first with prefix-key bindings
- Persistent server/client model — detach/reattach like tmux, including
  over SSH from mobile
- **Agent awareness**: semantic state per pane (blocked/working/done/idle)
  for 15+ agents including Claude Code; agent-native session resume
- CLI + JSON socket API (`herdr workspace create`, `herdr pane run`, …) —
  scriptable orchestration without tmux send-keys hacks
- Plugin system: local executable plugins with manifest actions and event
  hooks, plus a marketplace
- Session state paths: detach, restart restore, pane history replay, live
  handoff
- Install: curl script, homebrew formula (`brew install herdr`), nix flake
  (`github:ogulcancelik/herdr/vX.Y.Z` — package outputs only, no HM module)
- No Electron, no accounts, no telemetry
- License: dual AGPL-3.0-or-later + commercial (GitHub shows "Other" due to
  the dual-license preamble). Personal terminal use carries no obligations.

## Plugin Ecosystem

Marketplace is an automatic index of GitHub repos tagged `herdr-plugin`
(unreviewed — vet before install). Plugins are external executables (any
language) with a `herdr-plugin.toml` manifest: actions, event hooks, pane
UIs, link handlers, custom keybindings. Install: `herdr plugin install
owner/repo`. **v1 limitation: no custom status bar items or non-pane UI.**

Gap-fillers relevant to us (stars as of 2026-07-06):

| Gap | Plugin | Notes |
|-----|--------|-------|
| sesh switcher | [herdr-sessionizer](https://github.com/andrewchng/herdr-sessionizer) (12★) | fuzzy project/worktree open, declarative TOML workspace layouts, per-repo overrides |
| sesh presets / tmuxinator | [herdr-spreader](https://github.com/yuk1ty/herdr-spreader) (22★) | full workspace layout from YAML |
| universal picker | [herdr-picker-plus](https://github.com/thanhdat77/herdr-picker-plus) (3★) | workspaces, SSH, agents, projects, dirs |
| `prefix-l` last session | [herdr-last-workspace](https://github.com/third774/herdr-last-workspace) (5★) | last-workspace toggle |
| vim-tmux-navigator | [vim-herdr-navigation](https://github.com/paulbkim-dev/vim-herdr-navigation) (22★) | C-hjkl across herdr panes + nvim splits |
| smart-splits | [herdr-splits.nvim](https://github.com/lmilojevicc/herdr-splits.nvim) (10★) | nav + resize |
| tmux-thumbs / URL pick | [herdr-pluck](https://github.com/rmarganti/herdr-pluck) (6★), [herdr-fingers](https://github.com/hitaishi2222/herdr-fingers) (2★) | pattern-match copy overlay |
| fzf command palette | [herdr-command-palette](https://github.com/JanTvrdik/herdr-command-palette) (9★) | fuzzy-run any plugin action |

Beyond tmux parity (agentic extras):

- [herdr-remote](https://github.com/dcolinmorgan/herdr-remote) (26★) — approve agents from phone/menu bar/Telegram
- [herdr-reviewr](https://github.com/persiyanov/herdr-reviewr) (27★) — code-review sidebar, line comments back to agent chat
- [herdr-file-viewer](https://github.com/smarzban/herdr-file-viewer) (50★) — git-aware file viewer pane with diffs
- [herdr-worktree-setup](https://github.com/tdi/herdr-worktree-setup) (5★) — per-project setup on worktree create (.env copy, mise trust, direnv allow)
- [herdr-worktree-from-pr](https://github.com/tdi/herdr-worktree-from-pr) (3★) — worktree from GitHub PR as workspace
- [herdr-ntfysh](https://github.com/cobanov/herdr-ntfysh) (7★) — ntfy push when agent finishes/blocks

## Migration Mapping

Concept translation (from herdr docs/concepts):

| tmux | herdr |
|------|-------|
| session | workspace |
| window | tab |
| pane | pane |
| `tmux attach` | client attach to server |
| `tmux.conf` | herdr configuration (keybindings, themes, sidebar, notifications, scrollback) |
| status-bar plugins | sidebar + built-in agent states |

Nix integration sketch (if we proceed):

```nix
# flake.nix
herdr = {
  url = "github:ogulcancelik/herdr/v0.7.1";
  inputs.nixpkgs.follows = "nixpkgs";  # verify it takes this override
};

# home/common/herdr.nix — no upstream HM module, so:
home.packages = [ inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default ];
# config via config/herdr/ + mkOutOfStoreSymlink, same pattern as other dotfiles
```

## Approach

1. Add herdr flake input on a branch; install the package side-by-side
   with tmux (they don't conflict — different binaries/sockets).
2. Live in herdr for a full week of Claude Code work. Exercise: multiple
   workspaces, detach/reattach, SSH attach from another host, agent state
   sidebar, `herdr pane run` scripting.
3. Score the gaps: sesh switcher replacement (can `herdr workspace` +
   fzf reproduce it?), scrollback/copy-mode ergonomics, theming.
4. Test the socket API against a real orchestration need (e.g. spawn
   Claude in a new pane from a script, poll its state).
5. ~~Review the license~~ Done — AGPL-3.0-or-later (dual w/ commercial);
   fine for personal use.
6. Decide: replace, run hybrid (herdr for agent work, tmux for the rest),
   or stay on tmux and keep improving claude-tmux-notify.

## Environment

| Component | Version / Value |
|-----------|----------------|
| herdr | v0.7.1 (latest release 2026-06-24) |
| tmux | via nixpkgs (programs.tmux HM module) |
| sesh | 2.26.2 (nixpkgs) |
| claude-tmux-notify | v1.0.0 (donaldgifford/claude-tmux-notify) |
| platform | aarch64-darwin (primary), x86_64-linux (workstation) |

## Findings

<!-- Fill in during the hands-on trial. -->

### Observation 1: Feature coverage

### Observation 2: Nix integration

## Risks / Open Questions

- ~~License is "Other"~~ **Resolved:** dual-licensed AGPL-3.0-or-later +
  commercial. AGPL only obligates if we modify + distribute/host it;
  personal terminal use is unencumbered.
- **Pre-1.0 velocity** — v0.7.x; config format and API may churn. Pinning
  the flake input mitigates surprise upgrades but means manual bumps.
- **No home-manager module** — config lives outside `programs.*`; we'd use
  the `config/` symlink pattern, losing nix-level option checking.
- **sesh ecosystem loss** — sesh, fzf-tmux popups, and zoxide session
  jumping are tmux-coupled. `herdr-sessionizer` (12★) looks like the
  closest replacement; needs hands-on validation of the switcher UX.
- **status bar is a hard gap** — plugins cannot add status bar items in
  v1, so tokyo-night-style modules are not reproducible at all.
- **Muscle memory** — pain-control bindings and vi copy-mode are deeply
  ingrained; herdr's mouse-first philosophy may fight terminal-first habits.
- **claude-tmux-notify obsolescence is a feature, not a risk** — but worth
  noting our plugin works today; the grass isn't burning.

## Conclusion

**Answer:** <!-- Yes / No / Inconclusive — pending hands-on trial -->

## Recommendation

<!-- Pending trial. Expected shape: hybrid trial first; full switch only if
     sesh-equivalent workflow exists and license review passes. -->

## References

- [herdr.dev](https://herdr.dev/)
- [herdr docs — install](https://herdr.dev/docs/install/)
- [herdr docs — concepts](https://herdr.dev/docs/concepts/)
- [herdr docs — socket API](https://herdr.dev/docs/socket-api/)
- [github.com/ogulcancelik/herdr](https://github.com/ogulcancelik/herdr)
- `home/common/tmux.nix` — current tmux config
- `config/sesh/sesh.toml` — sesh session presets
- [donaldgifford/claude-tmux-notify](https://github.com/donaldgifford/claude-tmux-notify)
- INV-0001 — split dotfiles investigation (config symlink pattern)
