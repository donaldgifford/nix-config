---
id: INV-0001
title: "Split Dotfiles into Separate Repo"
status: Open
author: Donald Gifford
created: 2026-04-27
---
<!-- markdownlint-disable-file MD025 MD041 -->

# INV 0001: Split Dotfiles into Separate Repo

**Status:** Open
**Author:** Donald Gifford
**Date:** 2026-04-27

<!--toc:start-->
- [Question](#question)
- [Hypothesis](#hypothesis)
- [Context](#context)
- [Approach](#approach)
- [Findings](#findings)
  - [Current Setup](#current-setup)
  - [Option A: Status Quo (Single Repo)](#option-a-status-quo-single-repo)
  - [Option B: Sibling Clone (Two Repos, Plain Path Reference)](#option-b-sibling-clone-two-repos-plain-path-reference)
  - [Option C: Flake Input (Two Repos, Locked via flake.lock)](#option-c-flake-input-two-repos-locked-via-flakelock)
  - [Option D: Git Submodule](#option-d-git-submodule)
- [Tradeoffs Summary](#tradeoffs-summary)
- [Conclusion](#conclusion)
- [Recommendation](#recommendation)
- [References](#references)
<!--toc:end-->

## Question

Should the raw dotfiles in `config/` (nvim, ghostty, starship, lazygit, yazi, etc.) be extracted into a separate `dotfiles` repository that this nix config references, instead of living in this repo?

## Hypothesis

For a single user managing only nix-enabled machines, splitting adds operational friction (two repos to clone, push, sync) without meaningful benefit. The split becomes worthwhile only when dotfiles need to be reused on non-nix machines (work laptop, remote servers, CI containers, etc.) or shared publicly without exposing nix internals.

## Context

This config currently has `config/` co-located with `home/`, `hosts/`, and `flake.nix` in a single repo. `home/common/configs.nix` symlinks `config/<tool>/` paths into `~/.config` via `mkOutOfStoreSymlink`, so edits take effect immediately without rebuilding. This works well today, but as the dotfile collection grows, the question of separation becomes more relevant — especially if a non-nix machine enters the picture (work laptop, remote dev environment, etc.).

**Triggered by:** Working on multiple platforms and wanting to keep the option open to reuse dotfiles outside nix.

## Approach

1. Document the current setup and how `mkOutOfStoreSymlink` interacts with `config/`.
2. Enumerate the realistic options for splitting (sibling clone, flake input, submodule).
3. For each option, identify how editing, pushing, and rebuilding workflows change.
4. Identify the breakpoint conditions that would justify a split.

## Findings

### Current Setup

- `config/` lives at the repo root alongside `home/`, `hosts/`, `flake.nix`.
- `home/common/configs.nix` defines `dotfiles = "${config.home.homeDirectory}/code/nix-config/config"` and uses `mkOutOfStoreSymlink` to link entries into `~/.config`.
- Edits to files in `config/` take effect immediately — no rebuild needed.
- Both nix code and dotfiles are versioned, branched, and PR'd together.
- 13 tools currently configured: `nvim`, `ghostty`, `sesh`, `eza`, `btop`, `bat`, `yazi`, `starship`, `lazygit`, `diffnav`, `gh`, `gh-dash`, `git`.

### Option A: Status Quo (Single Repo)

**Workflow:**
- One clone, one push.
- Atomic commits can include both nix changes and the dotfile changes that depend on them (e.g., adding a tool to `packages.nix` and its config in `config/<tool>/` in the same commit).

**Pros:**
- Simplest mental model.
- No coordination between repos.
- `mkOutOfStoreSymlink` works as-is — dotfile edits live without rebuild.
- Single source of truth for the entire workstation setup.

**Cons:**
- Larger repo, mixed concerns (system config + user dotfiles).
- Dotfiles cannot be cloned/used independently on non-nix machines.
- Public sharing means exposing the nix-darwin / NixOS host configs alongside.

### Option B: Sibling Clone (Two Repos, Plain Path Reference)

**Setup:**
- New repo `donaldgifford/dotfiles` containing the current `config/` directory at the root.
- Clone to `~/code/dotfiles` on each machine.
- Update `home/common/configs.nix`:
  ```nix
  dotfiles = "${config.home.homeDirectory}/code/dotfiles";
  ```
- Delete `config/` from `nix-config`.

**Workflow:**
- Two clones, two pushes (when changes span both).
- Bootstrap script needs to clone both repos to predictable paths.
- `mkOutOfStoreSymlink` still works — no rebuild needed for dotfile edits.
- No version coupling — `nix-config` doesn't track which `dotfiles` commit is "current". Both must just both be cloned in their expected paths.

**Pros:**
- Dotfiles reusable on any machine (just clone and symlink manually if not using nix).
- Easy to share publicly without nix internals.
- Edit-without-rebuild preserved.
- Clean separation of concerns.

**Cons:**
- Atomic changes that span both (e.g., adding a tool needs `packages.nix` + `configs.nix` + new `config/foo/`) require coordination across two PRs.
- Bootstrap is now a 2-step clone.
- No guarantee that the dotfiles repo is at a specific revision when nix-config builds — can drift between machines.

### Option C: Flake Input (Two Repos, Locked via flake.lock)

**Setup:**
- New repo `donaldgifford/dotfiles` containing `config/` at the root.
- Add to `flake.nix`:
  ```nix
  inputs.dotfiles = {
    url = "github:donaldgifford/dotfiles";
    flake = false;
  };
  ```
- Update `configs.nix` to reference the input store path (passed via `specialArgs`).

**Workflow:**
- Dotfile edits no longer take effect immediately — every change requires `nix flake update dotfiles` and a rebuild.
- `flake.lock` pins the dotfile revision, so all machines on the same lock are guaranteed identical.
- Loses the live-edit property entirely.

**Pros:**
- Reproducible: every nix-config build pins to a specific dotfile revision.
- Public dotfiles repo possible.
- Can roll back dotfiles via `flake.lock` history.

**Cons:**
- **Major regression in workflow** — every nvim/ghostty/etc. tweak becomes a flake update + rebuild cycle.
- Defeats the entire purpose of `mkOutOfStoreSymlink`.
- Almost certainly the wrong choice unless reproducibility of dotfiles is more important than iteration speed.

### Option D: Git Submodule

**Setup:**
- `config/` becomes a git submodule pointing at `donaldgifford/dotfiles`.
- `mkOutOfStoreSymlink` still references `~/code/nix-config/config/` — the submodule fills it.

**Workflow:**
- `git clone --recurse-submodules` for fresh setup.
- Submodule pinned to specific commit in parent repo (similar reproducibility to flake input).
- Editing requires going into the submodule, committing, pushing, then pushing the parent's pointer update.

**Pros:**
- One root path (`~/code/nix-config/config/`) so `configs.nix` doesn't change.
- Pinned revisions for reproducibility.

**Cons:**
- Submodules have a reputation for being painful — easy to forget to push the submodule, easy to leave it in detached HEAD, confusing for collaborators.
- Editing dotfiles now requires two commits in two repos.
- Live-edit still works locally, but the submodule pointer can drift from what's pushed.
- Generally considered worse than either Option B or status quo.

## Tradeoffs Summary

| Aspect | A: Status Quo | B: Sibling Clone | C: Flake Input | D: Submodule |
|--------|---------------|------------------|----------------|--------------|
| Setup complexity | Lowest | Low | Medium | Medium-High |
| Live-edit (no rebuild) | ✓ | ✓ | ✗ | ✓ |
| Atomic cross-repo changes | ✓ | ✗ (2 PRs) | ✗ | ✗ |
| Reusable on non-nix machines | ✗ | ✓ | ✓ | ✓ |
| Public-shareable dotfiles only | ✗ | ✓ | ✓ | ✓ |
| Reproducibility (pinned dotfiles) | ✓ (same repo) | ✗ | ✓ | ✓ |
| Bootstrap steps | 1 | 2 | 1 | 1 (recursive clone) |
| Risk of drift between machines | Low | Medium | None | Low |
| Workflow friction | None | Slight | High | High |

## Conclusion

**Answer:** Inconclusive — depends on a future condition.

For the current state (nix on both machines, no shared dotfile use case outside nix), Option A (status quo) is strictly best. Splitting adds friction without solving a real problem.

If a non-nix machine enters the picture (work laptop, remote dev box, container), Option B (sibling clone) becomes worthwhile. It preserves the live-edit workflow and adds only modest setup overhead.

Option C (flake input) is rejected — the loss of live-edit is too steep.

Option D (submodule) is rejected — operational complexity exceeds the benefit.

## Recommendation

**Stay on Option A** until one of the following triggers a re-evaluation:

- Adding a non-nix machine that should share these dotfiles (work, remote dev, container)
- Wanting to publish the dotfiles publicly without exposing host configs
- Outgrowing the single-repo size (currently small enough that it's not an issue)

When the trigger fires, migrate to Option B. Migration steps:

1. Create `donaldgifford/dotfiles` and copy `config/` into its root.
2. Delete `config/` from `nix-config`, change one line in `home/common/configs.nix` (`dotfiles = "${config.home.homeDirectory}/code/dotfiles";`).
3. Clone `dotfiles` to `~/code/dotfiles` on each machine.
4. Rebuild — symlinks now resolve through the new path.

Estimated migration effort: ~30 minutes including testing on both platforms.

## References

- [home/common/configs.nix](../../home/common/configs.nix) — current symlink definitions
- [RFC-0001: Multi-Platform Nix Configuration Management](../rfc/0001-multi-platform-nix-configuration-management.md)
- [Home Manager `mkOutOfStoreSymlink` docs](https://nix-community.github.io/home-manager/options.xhtml)
