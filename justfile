# nix-config — `just` lists recipes. Stop-gap for flake bumps until Renovate's
# nix manager is wired up; see README/CLAUDE.md for the raw commands.

set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

flake := justfile_directory()
rebuild := if os() == "macos" { "darwin-rebuild" } else { "nixos-rebuild" }
target := if os() == "macos" { flake } else { flake + "#workstation" }
pkgs_attr := if os() == "macos" { ".#darwinConfigurations.donald-mbp.pkgs" } else { ".#nixosConfigurations.workstation.pkgs" }

# Default: list recipes
_default:
    @just --list --unsorted

# Build the system without switching, then show what would change
[group('build')]
build:
    {{ rebuild }} build --flake {{ target }}
    nvd diff /run/current-system ./result

# Build and switch (sudo). Same as the `nrs` alias.
[group('build')]
switch:
    sudo {{ rebuild }} switch --flake {{ target }}

# Bump every flake input to latest. Tag-pinned inputs (herdr) stay put — use retag.
[group('update')]
update:
    nix flake update
    @just lock-diff

# Bump one flake input: just bump nixpkgs
[group('update')]
bump input:
    nix flake update {{ input }}
    @just lock-diff

# Re-pin a tag-locked input to a release and re-lock: just retag herdr v0.9.4
[group('update')]
retag input tag:
    #!/usr/bin/env bash
    set -eu -o pipefail
    cd {{ flake }}
    repo=$(jq -r --arg i '{{ input }}' '.nodes[$i].original // {} | select(.type == "github") | "\(.owner)/\(.repo)"' flake.lock)
    [[ -n "$repo" ]] || { echo "error: '{{ input }}' is not a github: input in flake.lock" >&2; exit 1; }
    perl -pi -e "s|github:\Q$repo\E/[^\"]+|github:$repo/{{ tag }}|" flake.nix
    grep -q "github:$repo/{{ tag }}\"" flake.nix \
      || { echo "error: no tagged url for $repo in flake.nix — input isn't pinned to a ref" >&2; exit 1; }
    grep -n "github:$repo/" flake.nix
    nix flake update '{{ input }}'
    just lock-diff

# Show flake inputs whose lock changed vs HEAD (what update/bump/retag did)
[group('update')]
lock-diff:
    #!/usr/bin/env bash
    set -eu -o pipefail
    cd {{ flake }}
    # keyed by input name (root.inputs), not lock node name (nixpkgs_2 …)
    summarize() { jq -r '. as $l | .nodes.root.inputs | to_entries[] | select(.value | type == "string") | .key as $k | $l.nodes[.value].locked | "\($k)\t\((.rev // .narHash)[:7])\t\(.lastModified | todate[:10])"'; }
    changed=$(join -t $'\t' -j1 <(git show HEAD:flake.lock | summarize | sort) <(summarize < flake.lock | sort) \
      | awk -F'\t' '$2 != $4 { printf "%-26s %s (%s)  ->  %s (%s)\n", $1, $2, $3, $4, $5 }')
    if [[ -n "$changed" ]]; then echo "$changed"; else echo "flake.lock unchanged vs HEAD"; fi

# List flake inputs with locked date and pinned ref
[group('update')]
inputs:
    @jq -r '. as $l | .nodes.root.inputs | to_entries[] | select(.value | type == "string") | .key as $k | $l.nodes[.value] | "\($k)\t\(.locked.lastModified | todate[:10])\t\(.original.ref // "-")"' {{ flake }}/flake.lock | sort | column -t

# Compare pinned package versions to nixpkgs-unstable: just outdated lazygit gh
[group('update')]
outdated +pkgs="lazygit gh atuin neovim yazi starship eza bat ripgrep btop":
    #!/usr/bin/env bash
    set -eu -o pipefail
    cd {{ flake }}
    printf '%-20s %-14s %-14s\n' package ours unstable
    for p in {{ pkgs }}; do
      ours=$(nix eval --raw "{{ pkgs_attr }}.$p.version" 2>/dev/null || echo "?")
      now=$(nix eval --raw "github:NixOS/nixpkgs/nixpkgs-unstable#$p.version" 2>/dev/null || echo "?")
      printf '%-20s %-14s %-14s %s\n' "$p" "$ours" "$now" "$([[ "$ours" == "$now" ]] || echo behind)"
    done

# Format all tracked nix files (except the generated hardware-configuration.nix)
[group('check')]
fmt:
    git -C {{ flake }} ls-files -z '*.nix' ':!hosts/workstation/hardware-configuration.nix' | xargs -0 nixfmt

# Lint nix: statix (see statix.toml) + deadnix (backup/ skipped, unused module args allowed)
[group('check')]
lint:
    statix check {{ flake }}
    deadnix --no-lambda-pattern-names --exclude {{ flake }}/backup -- {{ flake }}

# Pre-commit gate: formatting, lint, flake evaluates
[group('check')]
check: lint
    git -C {{ flake }} ls-files -z '*.nix' ':!hosts/workstation/hardware-configuration.nix' | xargs -0 nixfmt --check
    nix flake check {{ flake }}
