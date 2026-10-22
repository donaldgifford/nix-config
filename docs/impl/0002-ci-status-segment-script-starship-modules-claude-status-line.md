---
id: IMPL-0002
title: "CI status segment: script, starship modules, Claude status line"
status: Draft
author: Donald Gifford
created: 2026-10-21
---

<!-- markdownlint-disable-file MD024 MD025 MD041 -->

# IMPL-0002: CI status segment: script, starship modules, Claude status line

<!--toc:start-->
<!--toc:end-->

<!--docz:objective:start-->
## Objective

Build the `ci-status` command and wire it into the starship prompt and the
Claude Code status line, so the CI state of the current HEAD commit
(Buildkite via GitHub commit status, GitHub Actions via check runs, plus the
open PR number) is visible at a glance and never slows the prompt.

**Implements:** [DESIGN-0002](../design/0002-ci-status-segment-for-starship-and-the-claude-code-status-line.md)

Phases are ordered for testability: the script is testable standalone,
starship gives the fastest render loop, and the Claude status line comes
last because it only renders inside a session.

<!--docz:objective:end-->

<!--docz:scope:start-->
## Scope

<!--docz:in-scope:start-->
### In Scope

- `ci-status` as a Home Manager script on PATH (`home/common/ci-status.nix`
  + `home/common/ci-status/ci-status.sh`), macOS.
- Cache under `${XDG_CACHE_HOME:-~/.cache}/ci-status/`, one JSON file per
  `(owner, repo, sha)`, `mkdir` lock per key, detached background refresh.
- One `gh api graphql` query covering Buildkite status contexts, Actions
  check runs, and the associated PR.
- Seven starship custom modules in `config/starship/starship.toml`.
- One segment in `~/.claude/statusline-command.sh`, `GREEN` in the theme
  colour files.
- A `--self-test` that runs the classifier over canned GraphQL JSON.

<!--docz:in-scope:end-->

<!--docz:out-of-scope:start-->
### Out of Scope

- Buildkite API access (queued vs running, per-step detail).
- Clickable segments and the herdr popup plugin. Both are follow-ups on the
  same cache file; the build URL is stored for them but not read.
- The NixOS workstation (`home/linux` does not import the common modules).
- Any change to `~/.claude/settings.json`.

<!--docz:out-of-scope:end-->

<!--docz:scope:end-->

## Implementation Phases

Each phase builds on the previous one. A phase is complete when all its tasks
are checked off and its success criteria are met.

---

<!--docz:phase:start-->
### Phase 1: The script and its cache

The whole feature lives in one bash script; this phase makes it correct and
fast on its own, before any UI reads it. Everything here is testable from a
terminal with `cd` and `time`.

<!--docz:tasks:start-->
#### Tasks

- [x] Create `home/common/ci-status.nix` on the `temporal-oidc` pattern:
      `pkgs.writeShellApplication`, `runtimeInputs = [ gh jq git coreutils ]`,
      body from `./ci-status/ci-status.sh`, added to `home.packages`. Import
      it from `home/darwin.nix`.
- [x] Argument parsing: `--dir <path>` (default `$PWD`), `--format ansi|starship`,
      `--segment bk|gh|pr`, `--is <bk|gh> <yellow|green|red>`, `--refresh`,
      `--ttl <seconds>` (default 30), `--self-test`. Unknown flags exit 0
      silently on the render paths; the prompt must never see an error.
- [x] Repo resolution: `git -C "$dir" -c core.useBuiltinFSMonitor=false remote get-url origin`,
      parse `git@github.com:o/n.git`, `ssh://git@github.com/o/n`,
      `https://github.com/o/n(.git)`; anything else prints nothing.
      `rev-parse HEAD` for the sha. Cache key `<owner>_<name>_<sha>`.
- [x] Cache read: parse `fetched_at` with `jq`; stale when
      `now - fetched_at > ttl`. Never call `stat` for freshness.
- [x] Spawn: when missing or stale, `nohup "$0" --refresh --dir "$dir" >/dev/null 2>&1 & disown`,
      then render whatever is cached (or nothing) and exit 0.
- [x] `--refresh`: `mkdir "$key.lock"` or exit; remove a lock older than
      120 s first (write the epoch inside the lock dir as a file, same
      reason as the cache). Run the DESIGN-0002 GraphQL query through
      `gh api graphql`. On any failure exit 0 after removing the lock,
      leaving the old cache in place.
- [x] Classification in `jq`: Buildkite = worst `StatusContext` whose
      `context` starts with `buildkite/` (`PENDING`/`EXPECTED` yellow,
      `SUCCESS` green, `FAILURE`/`ERROR` red); Actions = worst `CheckRun`
      (not `COMPLETED` yellow; `FAILURE`/`TIMED_OUT`/`CANCELLED`/`STARTUP_FAILURE`
      red; else green); `pr` = first associated PR only when `state == "OPEN"`.
      `object == null` → `{found:false}`.
- [x] Write the cache atomically: `mktemp` in the cache dir, then `mv`.
      Delete sibling entries with `fetched_at` older than 7 days in the
      same pass.
- [x] Renderers: `--format ansi` prints `bk ●`, `gh ✓`, `#n` with
      `$YELLOW/$GREEN/$RED/$DIM/$RESET` taken from the environment
      (defaults to plain ANSI codes when unset); `--format starship --segment X`
      prints the bare glyph text; `--is X colour` exits 0/1 from the cache
      without spawning anything.
- [x] `--self-test`: canned GraphQL responses embedded as heredocs (homelab
      red, homelab pending with open PR, repo-guardian green, Actions with
      one cancelled job, unknown sha) piped through the classifier;
      assert the colours and exit non-zero on the first mismatch.
- [x] `git add` the new files, `just build`. (`just switch` is yours.)

<!--docz:tasks:end-->

<!--docz:criteria:start-->
#### Success Criteria

- `ci-status --self-test` passes.
- In `~/code/homelab`: first call prints nothing and leaves a lock
  directory; within a second the lock is gone and the cache file exists;
  the next call prints `bk ●` coloured by the build. (Verified 2026-10-21:
  homelab HEAD had moved to a green build carrying both a Buildkite status
  and check runs, so `bk` and `gh` both rendered green.)
- In `~/code/repo-guardian`: `gh ✓`, no `bk`. (Verified with Actions still
  running: yellow `gh ✓` and the open PR `#234`.)
- In `~/code/nix-config` on an unpushed commit: nothing, cache has
  `found: false`, no second refresh within the TTL.
- Outside a git repo, and in a repo with a non-GitHub remote: nothing,
  exit 0.
- `time ci-status --format ansi`: about 20 ms, cached or spawning a refresh.
  The original 10 ms target was below the process-startup floor (bash, two
  `git`, one `jq`, about 4 ms each); `date` forks were replaced with bash's
  `printf '%(%s)T'`.
- Three concurrent cold calls in the same repo (`for i in 1 2 3; do ci-status --format ansi & done`)
  produce exactly one `gh api graphql` process (`pgrep -f`).
- `gh auth logout` in a scratch shell, then a cold call: nothing printed,
  nothing on stderr, exit 0; the lock is cleaned up.
- `shellcheck` passes (it runs inside `writeShellApplication` at build
  time, so `just build` is the check).

<!--docz:criteria:end-->
<!--docz:phase:end-->

---

<!--docz:phase:start-->
#### Results (2026-10-21)

All criteria met against the built binary. Two bugs found and fixed on the
way: the cache read used `read` with tab IFS, which collapses empty fields
and put `fetched_at` in the PR slot (now `-` placeholders and space-joined);
and the lock path was a function local, so the `EXIT` trap could not see it
and left `.lock` directories behind (now a global).

### Phase 2: Starship modules

The test bed for colour and cache behaviour, since `starship module` and
`starship timings` make every state and its cost visible on demand.

<!--docz:tasks:start-->
#### Tasks

- [x] Add seven `[custom.ci_*]` tables to `config/starship/starship.toml`:
      `ci_bk_yellow`, `ci_bk_green`, `ci_bk_red`, `ci_gh_yellow`,
      `ci_gh_green`, `ci_gh_red`, `ci_pr`. Each:
      `when = "ci-status --is bk green"` (per module),
      `command = "ci-status --format starship --segment bk"`,
      `shell = ["bash", "--noprofile", "--norc"]`,
      `style = "green"` (palette name), `format = "[$output]($style) "`.
      `ci_pr` uses `when = "ci-status --format starship --segment pr | grep -q ."`
      and `style = "dimmed"`.
- [x] Insert `${custom.ci_bk_yellow}${custom.ci_bk_green}${custom.ci_bk_red}${custom.ci_gh_yellow}${custom.ci_gh_green}${custom.ci_gh_red}${custom.ci_pr}`
      into `format` after `$git_status`. The file is linked out of the
      store, so the next prompt picks it up with no rebuild.
- [x] Change `[palettes.warm_burnout_dark]` `green` from `#70bf56` to
      `#b4bc78` (dried sage), then confirm each palette renders the three
      colours: run `theme` to switch and re-render.
- [x] Measure: `starship timings` in homelab with a warm cache and with
      the cache deleted.

<!--docz:tasks:end-->

<!--docz:criteria:start-->
#### Success Criteria

- `STARSHIP_CONFIG=~/.config/starship.toml starship module custom.ci_bk_red`
  in homelab prints the red `bk ●`; the yellow and green variants print
  nothing there.
- In repo-guardian only the `gh` module renders; in a non-git directory
  none of the seven render.
- `starship timings` shows every `custom.ci_*` module under 20 ms with a
  warm cache and under 50 ms cold (spawn only), none near the 500 ms
  `command_timeout`.
- Prompt width is correct in zsh: the cursor lands after the prompt, no
  wrapped-line artefacts on resize (this is what the per-colour modules buy
  over raw ANSI).
- Both themes colour the segments from their palettes after `theme`.
- Wi-Fi off: the last cached result keeps rendering; a cold repo renders
  nothing; the prompt is not slower (`starship timings` unchanged).

<!--docz:criteria:end-->
<!--docz:phase:end-->

---

<!--docz:phase:start-->
#### Results (2026-10-22)

Live in zsh under herdr: homelab shows `bk ●` `gh ✓` in green from the repo
root and from subdirectories, prompt width correct. `starship timings`:
about 20 ms per module, 44 ms for the two that print, modules run in
parallel; `mise` (76 ms) is still the slowest module in the prompt.
`warm_burnout_dark` green is now dried sage `#b4bc78`. In a non-git
directory the seven `when` checks still run (about 20 ms each, in
parallel) and print nothing. Wi-Fi-off check not run separately; the
logged-out and offline paths share the same code (gh fails, nothing
written) and were covered in Phase 1.

### Phase 3: Claude Code status line

One segment in the existing script, plus the theme colours it needs.
The script moves under nix and the greens are decided (DESIGN-0002):
tokyonight `#9ece6a`, warm burnout dried sage `#b4bc78`.

<!--docz:tasks:start-->
#### Tasks

- [x] Move `~/.claude/statusline-command.sh` to
      `config/claude/statusline-command.sh`; in `home/common/claude.nix`
      link it to `~/.claude/statusline-command.sh` with
      `mkOutOfStoreSymlink` and `force = true`.
- [x] Add the segment after the git-branch segment:
      `ci=$(ci-status --dir "$cwd" --format ansi 2>/dev/null); [ -n "$ci" ] && line+=" $ci"`.
      Export `YELLOW GREEN RED DIM RESET` before the call so the script
      picks up the theme's values.
- [x] Define `GREEN='\033[0;32m'` in the script's ANSI defaults.
- [x] Add `GREEN` to `config/themes/warm-burnout-dark/claude-colors.sh`
      and create `config/themes/tokyonight-dark/claude-colors.sh` with
      `CYAN RED YELLOW GREEN DIM` as truecolor values from the tokyonight
      palette (`GREEN` = `#9ece6a`); warm burnout `GREEN` = `#b4bc78`.
- [x] Hand test with fake stdin:
      `echo '{"workspace":{"current_dir":"'$HOME'/code/homelab"},"model":{"display_name":"x"}}' | bash ~/.claude/statusline-command.sh | command cat -v`.
- [x] Restart a Claude Code session in homelab and in repo-guardian and
      look at the line.

<!--docz:tasks:end-->

<!--docz:criteria:start-->
#### Success Criteria

- The fake-stdin test prints the existing segments plus `bk ●` (red) in
  homelab and `gh ✓` (green) in repo-guardian, with the theme's escape
  codes visible in `cat -v`.
- In a live session the status line shows the segment and still redraws
  promptly; with the cache deleted it shows nothing for the first redraw
  and the segment on the next.
- With `ci-status` deliberately broken (renamed), the status line still
  renders every other segment: the `2>/dev/null` and `[ -n ]` guard hold.
- After `theme tokyonight-dark` and `theme warm-burnout-dark` the three
  colours match the starship prompt in the same terminal.

<!--docz:criteria:end-->
<!--docz:phase:end-->

---

<!--docz:phase:start-->
#### Results (2026-10-22)

Fake-stdin renders with the repo copy and the tokyonight colours: homelab
shows green `bk ●` `gh ✓` after the branch; repo-guardian shows nothing
on the first render after its HEAD moved, then `gh ✓ #236` once the
detached fetch lands; `/tmp` shows no segment. With `ci-status` off PATH
or exiting 3 with stderr output, every other segment still renders. Whole
status line: about 66 ms per render, mostly the script's existing `jq`
calls. Build links `~/.claude/statusline-command.sh` out of the store.
Confirmed live after `just switch` (2026-10-22).

### Phase 4: Ship and settle

Lint gate, PR, and a week of real use before touching the TTL.

<!--docz:tasks:start-->
#### Tasks

- [x] `just check` green (statix, deadnix, nixfmt, `nix flake check`);
      `markdownlint-cli2` on the two docz docs.
- [x] Commit per phase on `feat/claude-statusline`, open one PR referencing
      DESIGN-0002 and IMPL-0002, `just switch` from main after merge.
- [ ] After a week: note in this doc whether the 30 s TTL was right, and
      whether `~/.cache/ci-status` stayed small (expect a few hundred KB).
- [ ] Mark DESIGN-0002 `Implemented` and this doc `Completed` via
      `docz status set`.

<!--docz:tasks:end-->

<!--docz:criteria:start-->
#### Success Criteria

- PR merged; `main` builds and switches cleanly.
- No prompt slowdown reported in a week of use in homelab, repo-guardian
  and nix-config.
- Cache directory under 1 MB and no leftover `.lock` directories.

<!--docz:criteria:end-->
<!--docz:phase:end-->

---

<!--docz:file-changes:start-->
## File Changes

| File | Action | Description |
| ---- | ------ | ----------- |
| `home/common/ci-status.nix` | Create | `writeShellApplication` wrapper, `temporal-oidc` pattern |
| `home/common/ci-status/ci-status.sh` | Create | the script: resolve, cache, refresh, classify, render, self-test |
| `home/darwin.nix` | Modify | import `./common/ci-status.nix` |
| `config/starship/starship.toml` | Modify | seven `[custom.ci_*]` tables; `format` gains them after `$git_status` |
| `config/claude/statusline-command.sh` | Create | moved from `~/.claude/`, one new segment, `GREEN` default |
| `home/common/claude.nix` | Modify | `mkOutOfStoreSymlink` to `~/.claude/statusline-command.sh` |
| `config/themes/warm-burnout-dark/claude-colors.sh` | Modify | add `GREEN` |
| `config/themes/tokyonight-dark/claude-colors.sh` | Create | all five colour variables |

<!--docz:file-changes:end-->

<!--docz:testing:start-->
## Testing Plan

- [ ] `ci-status --self-test`: classifier over five canned GraphQL
      responses (homelab red, homelab pending + open PR, repo-guardian
      green, Actions with a cancelled job, unknown sha). Runs in CI-free
      form: it is just the script.
- [ ] Build-time `shellcheck` via `writeShellApplication`.
- [ ] Manual matrix from the phase criteria: homelab, repo-guardian,
      unpushed commit, non-git dir, non-GitHub remote, Wi-Fi off,
      `gh auth logout`, three concurrent cold calls.
- [ ] Timing: `time ci-status --format ansi` warm; `starship timings`
      warm and cold; both before and after the change for the prompt as a
      whole.
- [ ] Fake-stdin render of the Claude status line, then a live session.

<!--docz:testing:end-->

<!--docz:dependencies:start-->
## Dependencies

- `gh` logged in on this machine (it is: keyring, account donaldgifford).
- Buildkite keeps posting `buildkite/<pipeline>` commit statuses to GitHub
  for homelab; if that integration is ever removed, the `bk` segment goes
  silent rather than erroring.

<!--docz:dependencies:end-->

## Open Questions

All answered 2026-10-21:

| # | Topic | Decision |
|---|---|---|
| 1 | PR shape | One PR for all phases, one commit per phase. |
| 2 | Self-test fixtures | Heredocs inside `ci-status.sh` under `--self-test`. |
| 3 | `statusline.md` task note | Deleted; DESIGN-0002 carries its content. |
| 4 | Starship placement | Left side, straight after `$git_status`. |
| 5 | `jq` and `gh` | From nixpkgs via `runtimeInputs`. |

<!--docz:references:start-->
## References

- [DESIGN-0002](../design/0002-ci-status-segment-for-starship-and-the-claude-code-status-line.md)
- `home/common/temporal-oidc.nix`, the script-on-PATH pattern.
- `config/themes/theme-switch.sh`, how `palette =` and `current/` change.
- Starship custom modules: <https://starship.rs/config/#custom-commands>
- Claude Code status line: <https://docs.claude.com/en/docs/claude-code/statusline>
- GitHub GraphQL `StatusCheckRollup`: <https://docs.github.com/en/graphql/reference/objects#statuscheckrollup>

<!--docz:references:end-->
