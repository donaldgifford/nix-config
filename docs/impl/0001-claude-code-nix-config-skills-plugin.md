---
id: IMPL-0001
title: "Claude Code Nix Config Skills Plugin"
status: Draft
author: Donald Gifford
created: 2026-04-16
---
<!-- markdownlint-disable-file MD025 MD041 -->

# IMPL 0001: Claude Code Nix Config Skills Plugin

**Status:** Draft
**Author:** Donald Gifford
**Date:** 2026-04-16

<!--toc:start-->
- [Objective](#objective)
- [Scope](#scope)
  - [In Scope](#in-scope)
  - [Out of Scope](#out-of-scope)
- [Implementation Phases](#implementation-phases)
  - [Phase 1: Plugin Scaffold and Foundation Skills](#phase-1-plugin-scaffold-and-foundation-skills)
  - [Phase 2: Package Management Skill](#phase-2-package-management-skill)
  - [Phase 3: Config and Module Scaffolding Skills](#phase-3-config-and-module-scaffolding-skills)
  - [Phase 4: Diff and Review Workflow Skill](#phase-4-diff-and-review-workflow-skill)
- [File Changes](#file-changes)
- [Testing Plan](#testing-plan)
- [Dependencies](#dependencies)
- [Resolved Questions](#resolved-questions)
- [References](#references)
<!--toc:end-->

## Objective

Implement 6 Claude Code skills as project-local skills in `.claude/skills/` for managing this nix-config repository. The skills automate common multi-file operations (adding packages, configs, modules) and encode repo-specific conventions so Claude Code performs edits correctly without re-discovering the architecture.

**Implements:** [DESIGN-0001: Claude Code Skills for Nix Config Management](../design/0001-claude-code-skills-for-nix-config-management.md)

## Scope

### In Scope

- 6 project-local skills in `.claude/skills/`: `nix-rebuild`, `nix-lint`, `nix-add-package`, `nix-add-config`, `nix-add-module`, `nix-diff`
- Per-skill reference files (duplicated where shared across skills)
- Smoke testing each skill against the live repo

### Out of Scope

- Plugin manifest (`plugin.json`) — project-local skills don't need one
- Agents or hooks — all skills are prompt-based (SKILL.md only)
- General-purpose Nix skills — these are specific to this repo's layout
- Secrets management or 1Password configuration
- CI/CD integration — no automated test pipeline for skills
- Publishing to a registry — project-local only

## Implementation Phases

Each phase builds on the previous one. A phase is complete when all its tasks are checked off and its success criteria are met.

---

### Phase 1: Plugin Scaffold and Foundation Skills

Establish the skill directory structure and reference files. Implement the two simplest skills (`nix-lint` and `nix-rebuild`) to validate the structure works end-to-end.

#### Tasks

- [ ] Create skill directory structure:
  ```
  .claude/skills/
    nix-lint/
      SKILL.md
      references/
        repo-layout.md
    nix-rebuild/
      SKILL.md
      references/
        repo-layout.md
  ```
- [ ] Write `references/repo-layout.md` (duplicated in each skill that needs it):
  - [ ] Document file paths, module structure, and conventions from CLAUDE.md
  - [ ] Document `mkOutOfStoreSymlink` pattern, platform conditionals, import conventions
- [ ] Write `.claude/skills/nix-lint/SKILL.md`:
  - [ ] Frontmatter: `name: nix-lint`, description with triggers "lint", "check nix files", "format nix"
  - [ ] Body: run `nixfmt **/*.nix`, then `statix check .`, then `deadnix .`
  - [ ] Offer to run `statix fix .` if issues found
- [ ] Write `.claude/skills/nix-rebuild/SKILL.md`:
  - [ ] Frontmatter: `name: nix-rebuild`, description with triggers "rebuild", "switch", "apply changes"
  - [ ] Body: detect platform via `uname -s`, always run `nix flake check` first, then run appropriate rebuild command
  - [ ] Darwin: `sudo darwin-rebuild switch --flake ~/code/nix-config`
  - [ ] Linux: `sudo nixos-rebuild switch --flake ~/code/nix-config#workstation`
- [ ] Smoke test: invoke `/nix-lint` and verify it runs all three tools
- [ ] Smoke test: invoke `/nix-rebuild` and verify it detects the correct platform and runs `nix flake check`

#### Success Criteria

- Skills are discovered by Claude Code in this project
- `/nix-lint` runs `nixfmt`, `statix`, and `deadnix`
- `/nix-rebuild` detects Darwin vs Linux, runs `nix flake check`, then runs the correct rebuild command
- Reference files load correctly when skills need them

---

### Phase 2: Package Management Skill

Implement the unified package management skill that handles both Nix packages and Homebrew casks. When the user asks to install something, the skill determines whether it's a Nix package or a Homebrew cask and asks the user which to use if ambiguous.

#### Tasks

- [ ] Write `.claude/skills/nix-add-package/SKILL.md`:
  - [ ] Frontmatter: `name: nix-add-package`, description with triggers "add package", "install", "add cask", "install mac app"
  - [ ] Body — Nix package flow:
    - [ ] Search nixpkgs (`nix search nixpkgs#<name>`), confirm with user
    - [ ] Read `home/common/packages.nix`
    - [ ] Determine placement: main list, `isLinux` block, or `isDarwin` block
    - [ ] Insert in alphabetical order within the correct section
    - [ ] Run `nixfmt home/common/packages.nix`
  - [ ] Body — Homebrew cask flow (macOS GUI apps):
    - [ ] Read `hosts/macbook/darwin.nix`
    - [ ] Add cask to `homebrew.casks` in the appropriate section group (Core, Dev, Browsers, Communication, Utilities)
    - [ ] Insert alphabetically within section
    - [ ] Run `nixfmt hosts/macbook/darwin.nix`
  - [ ] Body — Disambiguation:
    - [ ] If the package could be either Nix or Homebrew (e.g., "install firefox"), present both options with context (Nix = CLI/cross-platform, Homebrew = macOS GUI `.app` bundle)
    - [ ] Let the user choose
  - [ ] Ask user if they want to rebuild via `/nix-rebuild` after adding
  - [ ] Reference `repo-layout.md` and `nix-patterns.md` for file paths and conventions
- [ ] Write `.claude/skills/nix-add-package/references/repo-layout.md` (duplicate)
- [ ] Write `.claude/skills/nix-add-package/references/nix-patterns.md`:
  - [ ] Document platform conditional pattern (`lib.optionals pkgs.stdenv.isLinux/isDarwin`)
  - [ ] Document `packages.nix` section structure (comments, guard locations, existing packages)
  - [ ] Document `darwin.nix` homebrew section (cask groups, brew list, masApps format)
- [ ] Smoke test: add a cross-platform Nix package — verify correct placement in main list
- [ ] Smoke test: add a linux-only Nix package — verify it lands in `isLinux` block
- [ ] Smoke test: add a Homebrew cask — verify correct placement in `darwin.nix`
- [ ] Smoke test: add an ambiguous package (e.g., "firefox") — verify skill asks user to choose
- [ ] Verify `nix flake check` passes after each edit

#### Success Criteria

- `/nix-add-package` handles both Nix packages and Homebrew casks in a single skill
- Ambiguous requests prompt the user to choose between Nix and Homebrew
- Nix packages are placed in the correct platform section alphabetically
- Homebrew casks are placed in the correct section group alphabetically
- No duplicate entries are created
- `nix flake check` passes after edits
- Files are formatted with `nixfmt` as a final step

---

### Phase 3: Config and Module Scaffolding Skills

Implement the multi-file editing skills that create new files and update imports.

#### Tasks

- [ ] Write `.claude/skills/nix-add-config/SKILL.md`:
  - [ ] Frontmatter: `name: nix-add-config`, description with triggers "add config", "symlink config", "add dotfile"
  - [ ] Body: ask user for tool name and config file path relative to `config/`
  - [ ] Create file in `config/<tool>/` if it doesn't exist
  - [ ] Read `home/common/configs.nix` and add `xdg.configFile` entry using the `link` helper
  - [ ] Document the exact pattern: `"<tool>/file".source = link "<tool>/file";`
  - [ ] Run `nixfmt home/common/configs.nix` after edit
- [ ] Write `.claude/skills/nix-add-config/references/configs-nix-pattern.md`:
  - [ ] Document the `configs.nix` `let` block, `link` helper function, and existing entries
  - [ ] Document `mkOutOfStoreSymlink` details
- [ ] Write `.claude/skills/nix-add-module/SKILL.md`:
  - [ ] Frontmatter: `name: nix-add-module`, description with triggers "add module", "create module", "new HM module"
  - [ ] Body: create `home/common/<name>.nix` with minimal template:
    ```nix
    { config, pkgs, lib, ... }:
    {
      # <name> configuration
    }
    ```
  - [ ] Read `home/darwin.nix` and add `./common/<name>.nix` to imports list
  - [ ] Read `home/linux.nix` and add `./common/<name>.nix` to imports list
  - [ ] Run `nixfmt` on all three files
  - [ ] Handle linux-only variant: place in `home/linux/`, only add to `home/linux.nix`
- [ ] Write `.claude/skills/nix-add-module/references/module-template.md`:
  - [ ] Document the module file template
  - [ ] Document import list locations in `darwin.nix` and `linux.nix`
  - [ ] Document linux-only module placement in `home/linux/`
- [ ] Smoke test: invoke `/nix-add-config` for a new tool — verify file creation + `configs.nix` entry
- [ ] Smoke test: invoke `/nix-add-module` — verify module creation + both import lists updated
- [ ] Smoke test: invoke `/nix-add-module` with linux-only flag — verify only `linux.nix` updated
- [ ] Verify `nix flake check` passes after each edit

#### Success Criteria

- `/nix-add-config` creates config files and adds correct symlink entries to `configs.nix`
- `/nix-add-config` follows the existing `link` helper pattern exactly
- `/nix-add-module` creates a valid module file and adds imports to both `darwin.nix` and `linux.nix`
- `/nix-add-module` handles the linux-only variant correctly (only `linux.nix`)
- `nix flake check` passes after edits from both skills
- All modified files are formatted with `nixfmt`

---

### Phase 4: Diff and Review Workflow Skill

Implement the final review/pre-rebuild skill.

#### Tasks

- [ ] Write `.claude/skills/nix-diff/SKILL.md`:
  - [ ] Frontmatter: `name: nix-diff`, description with triggers "what changed", "diff", "show changes", "nix diff"
  - [ ] Body: run `git diff --name-only` filtered to `*.nix` files
  - [ ] For each changed file, show a concise summary of additions/removals
  - [ ] Suggest running `/nix-lint` if any `.nix` files changed
  - [ ] Suggest running `/nix-rebuild` to apply changes
  - [ ] Optionally run `nvd` dry-build diff if user wants package-level comparison
- [ ] Smoke test: modify a `.nix` file, invoke `/nix-diff`, verify it reports the change
- [ ] Smoke test: verify it suggests `/nix-lint` and `/nix-rebuild` in output
- [ ] Final review: verify all 6 skills are discoverable and trigger on expected phrases

#### Success Criteria

- `/nix-diff` shows changed `.nix` files with meaningful summaries
- `/nix-diff` suggests `/nix-lint` and `/nix-rebuild` as next steps
- All 6 skills are listed when querying available slash commands
- Each skill triggers on its documented trigger phrases

---

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `.claude/skills/nix-lint/SKILL.md` | Create | Lint and format skill |
| `.claude/skills/nix-lint/references/repo-layout.md` | Create | Repo structure reference |
| `.claude/skills/nix-rebuild/SKILL.md` | Create | Platform-aware rebuild skill |
| `.claude/skills/nix-rebuild/references/repo-layout.md` | Create | Repo structure reference (dup) |
| `.claude/skills/nix-add-package/SKILL.md` | Create | Unified add package/cask skill |
| `.claude/skills/nix-add-package/references/repo-layout.md` | Create | Repo structure reference (dup) |
| `.claude/skills/nix-add-package/references/nix-patterns.md` | Create | Platform conditionals, section structure |
| `.claude/skills/nix-add-config/SKILL.md` | Create | Add dotfile config skill |
| `.claude/skills/nix-add-config/references/configs-nix-pattern.md` | Create | configs.nix symlink pattern |
| `.claude/skills/nix-add-module/SKILL.md` | Create | Scaffold HM module skill |
| `.claude/skills/nix-add-module/references/module-template.md` | Create | Module template and import locations |
| `.claude/skills/nix-diff/SKILL.md` | Create | Show changes since last rebuild |

## Testing Plan

All testing is manual since skills are prompt-based:

- [ ] Each skill triggers when invoked as `/skill-name`
- [ ] Each skill triggers on natural language phrases from its description
- [ ] File edits produce valid Nix that passes `nix flake check`
- [ ] `nixfmt` produces no changes after a skill runs (skill formats as final step)
- [ ] Running a skill twice with the same input does not duplicate entries
- [ ] Platform detection correctly identifies Darwin vs Linux
- [ ] `/nix-add-package` correctly disambiguates between Nix and Homebrew when needed

## Dependencies

- Claude Code CLI with skill support
- Nix tooling installed: `nixfmt`, `statix`, `deadnix`, `nvd`
- `gh` CLI for any future CI integration

## Resolved Questions

1. **Skill location** — Skills live in `.claude/skills/<skill-name>/SKILL.md` as project-local skills. No `plugin.json` manifest needed for project-local skills. Confirmed via [Claude Code docs](https://code.claude.com/docs/en/skills.md).

2. **Shared references** — Each skill has its own `references/` directory. Shared reference files (e.g., `repo-layout.md`) are duplicated into each skill that needs them. Claude Code auto-discovers references per-skill directory only.

3. **Package vs cask overlap** — Merged `nix-add-cask` into `nix-add-package` as a single unified skill. When a package could be either Nix or Homebrew (e.g., "install firefox"), the skill presents both options with context and lets the user choose. This reduces the skill count from 7 to 6.

4. **`backup/` directory** — Will be moved out of the repo entirely. No need for exclusion logic in `/nix-lint` or any other skill.

5. **`nix flake check` in `/nix-rebuild`** — Always runs before rebuilding. No skip flag.

## References

- [DESIGN-0001: Claude Code Skills for Nix Config Management](../design/0001-claude-code-skills-for-nix-config-management.md)
- [RFC-0001: Multi-Platform Nix Configuration Management](../rfc/0001-multi-platform-nix-configuration-management.md)
- [ADR-0001: Use nix-darwin with Homebrew for macOS Configuration](../adr/0001-use-nix-darwin-with-homebrew-for-macos-configuration.md)
- [ADR-0002: Use NixOS with Sway and Nvidia for Workstation](../adr/0002-use-nixos-with-sway-and-nvidia-for-workstation.md)
- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills.md)
