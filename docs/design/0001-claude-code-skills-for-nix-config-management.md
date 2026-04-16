---
id: DESIGN-0001
title: "Claude Code Skills for Nix Config Management"
status: Draft
author: Donald Gifford
created: 2026-04-11
---
<!-- markdownlint-disable-file MD025 MD041 -->

# DESIGN 0001: Claude Code Skills for Nix Config Management

**Status:** Draft
**Author:** Donald Gifford
**Date:** 2026-04-11

<!--toc:start-->
- [Overview](#overview)
- [Goals and Non-Goals](#goals-and-non-goals)
  - [Goals](#goals)
  - [Non-Goals](#non-goals)
- [Background](#background)
- [Detailed Design](#detailed-design)
  - [Skill 1: nix-rebuild — Platform-Aware Rebuild](#skill-1-nix-rebuild--platform-aware-rebuild)
  - [Skill 2: nix-add-package — Add a Package to the Flake](#skill-2-nix-add-package--add-a-package-to-the-flake)
  - [Skill 3: nix-add-cask — Add a Homebrew Cask (macOS)](#skill-3-nix-add-cask--add-a-homebrew-cask-macos)
  - [Skill 4: nix-lint — Lint and Format Nix Files](#skill-4-nix-lint--lint-and-format-nix-files)
  - [Skill 5: nix-add-config — Add a Dotfile with Symlink](#skill-5-nix-add-config--add-a-dotfile-with-symlink)
  - [Skill 6: nix-add-module — Scaffold a New Home Manager Module](#skill-6-nix-add-module--scaffold-a-new-home-manager-module)
  - [Skill 7: nix-diff — Show What Changed Since Last Rebuild](#skill-7-nix-diff--show-what-changed-since-last-rebuild)
- [API / Interface Changes](#api--interface-changes)
- [Testing Strategy](#testing-strategy)
- [Migration / Rollout Plan](#migration--rollout-plan)
- [Open Questions](#open-questions)
- [References](#references)
<!--toc:end-->

## Overview

Design a set of Claude Code skills (plugin commands) that automate common maintenance tasks for this nix-config repository. The skills encode repo-specific conventions — file locations, naming patterns, platform conditionals, and rebuild commands — so that Claude Code can perform multi-file edits correctly without re-discovering the architecture each time.

## Goals and Non-Goals

### Goals

- Automate the most frequent multi-step operations: adding packages, adding configs, scaffolding modules, linting, and rebuilding
- Encode repo conventions (file paths, import patterns, symlink format) into reusable skill prompts
- Reduce the chance of errors when editing Nix files (missing imports, wrong platform guard, forgotten symlink entry)
- Keep skills simple — each skill should be a prompt-based skill (no complex agents), using existing tools (Read, Edit, Write, Bash)

### Non-Goals

- Replacing `nix flake check` or `nixos-rebuild` — skills orchestrate these tools, not replace them
- Managing secrets or 1Password configuration
- Automating NixOS bootstrap or fresh macOS provisioning (these are infrequent, manual operations)
- Building a general-purpose Nix skill — these skills are specific to this repo's layout

## Background

This nix-config repo has well-defined conventions documented in `CLAUDE.md`:

| Task | Files Involved |
|------|---------------|
| Add a CLI package | `home/common/packages.nix` (with optional platform guard) |
| Add a GUI app (macOS) | `hosts/macbook/darwin.nix` → `homebrew.casks` |
| Add a Mac App Store app | `hosts/macbook/darwin.nix` → `homebrew.masApps` |
| Add a dotfile config | Place file in `config/<tool>/`, add symlink in `home/common/configs.nix` |
| Add a new HM module | Create `home/common/<name>.nix`, import from `home/darwin.nix` + `home/linux.nix` |
| Rebuild (macOS) | `sudo darwin-rebuild switch --flake ~/code/nix-config` |
| Rebuild (NixOS) | `sudo nixos-rebuild switch --flake ~/code/nix-config#workstation` |
| Lint | `statix check .` + `deadnix .` |
| Format | `nixfmt **/*.nix` |

Each skill encodes one of these workflows as a Claude Code slash command.

## Detailed Design

### Skill 1: nix-rebuild — Platform-Aware Rebuild

**Trigger:** `/nix-rebuild` or "rebuild", "switch", "apply changes"

**Behavior:**
1. Detect current platform (`uname -s`)
2. Run `nix flake check` to catch evaluation errors before rebuilding
3. If check passes, run the appropriate rebuild command:
   - Darwin: `sudo darwin-rebuild switch --flake ~/code/nix-config`
   - Linux: `sudo nixos-rebuild switch --flake ~/code/nix-config#workstation`
4. Report success or surface errors

**Notes:** This is a convenience wrapper. The user must approve the `sudo` command.

---

### Skill 2: nix-add-package — Add a Package to the Flake

**Trigger:** `/nix-add-package <name>` or "add package X", "install X"

**Behavior:**
1. Search nixpkgs for the package name (`nix search nixpkgs#<name>`)
2. Confirm the correct package attribute with the user
3. Read `home/common/packages.nix`
4. Determine placement:
   - If cross-platform: add to the main `with pkgs;` list
   - If linux-only: add inside `lib.optionals pkgs.stdenv.isLinux`
   - If darwin-only: add inside `lib.optionals pkgs.stdenv.isDarwin`
5. Insert the package in alphabetical order within the appropriate section
6. Run `nixfmt home/common/packages.nix`
7. Ask the user if they want to rebuild now (via `/nix-rebuild`) or continue editing

---

### Skill 3: nix-add-cask — Add a Homebrew Cask (macOS)

**Trigger:** `/nix-add-cask <name>` or "add cask X", "install mac app X"

**Behavior:**
1. Read `hosts/macbook/darwin.nix`
2. Add the cask name to `homebrew.casks` in alphabetical order within the appropriate section comment group
3. Run `nixfmt hosts/macbook/darwin.nix`
4. Remind the user to run `/nix-rebuild` to apply

---

### Skill 4: nix-lint — Lint and Format Nix Files

**Trigger:** `/nix-lint` or "lint", "check nix files"

**Behavior:**
1. Run `nixfmt **/*.nix` (format)
2. Run `statix check .` (anti-pattern detection)
3. Run `deadnix .` (unused code detection)
4. Summarize findings, offer to fix `statix` suggestions with `statix fix .`

**Notes:** Exclude `backup/` directory from linting since those are historical files.

---

### Skill 5: nix-add-config — Add a Dotfile with Symlink

**Trigger:** `/nix-add-config <tool>` or "add config for X", "symlink X config"

**Behavior:**
1. Ask the user for the config file path relative to `config/` (e.g., `config/foo/config.toml`)
2. Create the file in `config/<tool>/` if it doesn't exist
3. Read `home/common/configs.nix`
4. Add a new `xdg.configFile` entry following the existing pattern:
   ```nix
   "<tool>/config.toml".source = link "<tool>/config.toml";
   ```
5. Run `nixfmt home/common/configs.nix`

---

### Skill 6: nix-add-module — Scaffold a New Home Manager Module

**Trigger:** `/nix-add-module <name>` or "create module for X", "add HM module X"

**Behavior:**
1. Create `home/common/<name>.nix` with a minimal module template:
   ```nix
   { config, pkgs, lib, ... }:
   {
     # <name> configuration
   }
   ```
2. Read `home/darwin.nix` and add `./common/<name>.nix` to its imports
3. Read `home/linux.nix` and add `./common/<name>.nix` to its imports
4. Run `nixfmt` on all three files
5. If the module is linux-only, place it in `home/linux/` and only add to `home/linux.nix`

---

### Skill 7: nix-diff — Show What Changed Since Last Rebuild

**Trigger:** `/nix-diff` or "what changed", "diff from last rebuild"

**Behavior:**
1. Run `git diff --name-only` to show modified Nix files
2. For each changed `.nix` file, show a summary of what was added/removed
3. Suggest running `/nix-lint` before rebuilding
4. Suggest running `/nix-rebuild` to apply

## API / Interface Changes

Each skill is invoked as a Claude Code slash command. No external APIs are introduced. Skills use the existing tool set:

- **Read** — read Nix files before editing
- **Edit** — modify Nix files (insert packages, imports, symlink entries)
- **Write** — create new module files
- **Bash** — run `nixfmt`, `statix`, `deadnix`, rebuild commands, `nix search`

## Testing Strategy

Since these are prompt-based skills (not code), testing is manual:

1. **Smoke test each skill** — run the slash command and verify the resulting file edits are correct
2. **Validate with `nix flake check`** — after any skill modifies a `.nix` file, run `nix flake check` to ensure the flake still evaluates
3. **Cross-platform verification** — test `/nix-add-package` with platform-specific packages to verify correct guard placement
4. **Idempotency** — running a skill twice with the same input should not duplicate entries
5. **Lint after edit** — verify `nixfmt` produces no changes after a skill runs (skill should format as a final step)

## Migration / Rollout Plan

1. **Phase 1** — Implement `/nix-lint` and `/nix-rebuild` as the simplest skills to validate the plugin structure
2. **Phase 2** — Implement `/nix-add-package` and `/nix-add-cask` as the most frequently used operations
3. **Phase 3** — Implement `/nix-add-config` and `/nix-add-module` for less frequent but error-prone multi-file operations
4. **Phase 4** — Implement `/nix-diff` as a review/pre-rebuild workflow skill

Each skill is independent and can be shipped individually. No ordering dependencies between skills.

## Resolved Questions

1. **`/nix-rebuild` runs `nix flake check` first** — Yes. Catches evaluation errors before attempting a rebuild.
2. **`/nix-add-package` does not auto-rebuild** — After adding a package, the skill asks the user if they want to rebuild. The user may want to batch multiple additions first.
3. **Skills handle `backup/` cleanup** — Yes. A skill can identify unused backup files, but must ask the user for confirmation before removing anything.
4. **Platform detection via `uname`** — Skills detect the platform with `uname -s` in Bash. Simplest approach for prompt-based skills.
5. **Single plugin structure** — All nix skills live in one plugin (`nix-config`). This is the most idiomatic approach — keeps related skills together with shared references.

## References

- [RFC-0001: Multi-Platform Nix Configuration Management](../rfc/0001-multi-platform-nix-configuration-management.md)
- [ADR-0001: Use nix-darwin with Homebrew for macOS Configuration](../adr/0001-use-nix-darwin-with-homebrew-for-macos-configuration.md)
- [Claude Code Plugin Development](https://docs.anthropic.com/en/docs/claude-code)
- [skill-creator skill](https://github.com/anthropics/claude-code-skills) — reference for plugin scaffolding
