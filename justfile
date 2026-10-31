# nix-config — `just` lists recipes. Stop-gap for flake bumps until Renovate's
# nix manager is wired up; see README/CLAUDE.md for the raw commands.

set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

flake := justfile_directory()
rebuild := if os() == "macos" { "darwin-rebuild" } else { "nixos-rebuild" }
target := if os() == "macos" { flake } else { flake + "#workstation" }
pkgs_attr := if os() == "macos" { ".#darwinConfigurations.donald-mbp.pkgs" } else { ".#nixosConfigurations.workstation.pkgs" }
system_attr := if os() == "macos" { ".#darwinConfigurations.donald-mbp.system" } else { ".#nixosConfigurations.workstation.config.system.build.toplevel" }

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

# Preview a bump without touching flake.lock: lock diff + nvd diff of the resulting system. just plan nixpkgs (no arg = all)
[group('update')]
plan input="":
    #!/usr/bin/env bash
    set -eu -o pipefail
    cd {{ flake }}
    tmp=$(mktemp -d); tmp=$(cd "$tmp" && pwd -P)   # physical path — nix rejects the /var symlink
    trap 'rm -rf "$tmp"' EXIT
    nix flake update {{ input }} --output-lock-file "$tmp/new.lock" >/dev/null
    just _lock-diff-files flake.lock "$tmp/new.lock"
    echo
    echo "building current vs bumped system (flake.lock untouched, nothing switched)…"
    nix build {{ system_attr }} --out-link result
    nix build {{ system_attr }} --reference-lock-file "$tmp/new.lock" --no-write-lock-file --out-link result-plan
    nvd diff result result-plan
    echo
    echo "apply with: just bump {{ input }} && just switch   (result-plan keeps the preview build cached)"

# Show flake inputs whose lock changed vs HEAD (what update/bump/retag did)
[group('update')]
lock-diff:
    #!/usr/bin/env bash
    set -eu -o pipefail
    cd {{ flake }}
    tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
    git show HEAD:flake.lock > "$tmp"
    just _lock-diff-files "$tmp" flake.lock

# Per-input diff between two lock files (keyed by input name, not lock node name)
_lock-diff-files old new:
    #!/usr/bin/env bash
    set -eu -o pipefail
    summarize() { jq -r '. as $l | .nodes.root.inputs | to_entries[] | select(.value | type == "string") | .key as $k | $l.nodes[.value].locked | "\($k)\t\((.rev // .narHash)[:7])\t\(.lastModified | todate[:10])"' "$1" | sort; }
    changed=$(join -t $'\t' -j1 <(summarize '{{ old }}') <(summarize '{{ new }}') \
      | awk -F'\t' '$2 != $4 { printf "%-26s %s (%s)  ->  %s (%s)\n", $1, $2, $3, $4, $5 }')
    if [[ -n "$changed" ]]; then echo "$changed"; else echo "no input changes"; fi

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

# Nix store usage: size, generations, nixpkgs copies, GC roots, and what `clean` could reclaim
[group('store')]
disk:
    #!/usr/bin/env bash
    set -eu -o pipefail
    gib() { awk '{printf "%.1f GiB", $1/1073741824}'; }
    # nar sizes from the nix db (fast); `du -sh /nix/store` is the on-disk figure
    read -r store_b store_n < <(nix path-info --all -s | awk '{s+=$2} END {print s+0, NR}')
    echo "store:             $(echo "$store_b" | gib)   ($store_n paths incl. .drv)"
    echo "~/.cache/nix:      $(du -sh "$HOME/.cache/nix" 2>/dev/null | cut -f1)"
    mtime() { local e; e=$(stat -c %Y "$1" 2>/dev/null || stat -f %m "$1"); date -d @"$e" +%F 2>/dev/null || date -r "$e" +%F; }
    mapfile -t gens < <(command ls /nix/var/nix/profiles/ | grep -oE 'system-[0-9]+-link' | sort -t- -k2 -n)
    echo "system gens:       ${#gens[@]}   (oldest $(mtime "/nix/var/nix/profiles/${gens[0]}"), newest $(mtime "/nix/var/nix/profiles/${gens[-1]}"))"
    echo "current closure:   $(nix path-info -S "$(readlink /run/current-system)" | awk '{print $2}' | gib)"
    copies=$(for d in /nix/store/*-source; do [[ -f "$d/pkgs/top-level/all-packages.nix" ]] && echo "$d"; done || true)
    if [[ -n "$copies" ]]; then
      read -r copies_b copies_n < <(echo "$copies" | nix path-info -s --stdin | awk '{s+=$2} END {print s+0, NR}')
    else copies_b=0; copies_n=0; fi
    echo "nixpkgs copies:    $copies_n   ($(echo "$copies_b" | gib)) — one per evaluated nixpkgs rev; gc'd once unreferenced"
    echo "result GC roots:"
    nix-store --gc --print-roots 2>/dev/null | awk '{print $1}' \
      | grep -vE '^/proc|^/run/|/nix/var/nix/profiles|flake-registry|/gcroots/|censored' | sed 's/^/  /' || true
    # what a `clean` would leave alive: current system, HM gcroot, result links above
    live=$(readlink /run/current-system)
    live="$live $(readlink -f "$HOME/.local/state/home-manager/gcroots/current-home" 2>/dev/null || true)"
    for r in $(nix-store --gc --print-roots 2>/dev/null | awk '{print $1}' | grep -vE '^/proc|^/run/|/nix/var/nix/profiles|flake-registry|/gcroots/|censored'); do
      [[ -L "$r" ]] && live="$live $(readlink -f "$r")"
    done
    live_b=$(nix-store -q --requisites $live | sort -u | nix path-info -s --stdin | awk '{s+=$2} END {print s+0}')
    echo "live after clean:  $(echo "$live_b" | gib)   →  reclaimable ≈ $(echo $((store_b - live_b)) | gib) (old generations + unreferenced paths)"

# Delete system generations older than N days and run gc (sudo): just clean 14
[group('store')]
clean days="14":
    #!/usr/bin/env bash
    set -eu -o pipefail
    cd {{ flake }}
    rm -f result result-plan   # repo build links are GC roots; `just build`/`plan` recreate them
    sudo nix-collect-garbage --delete-older-than {{ days }}d
    echo "store now: $(du -sh /nix/store | cut -f1)"

# Hard-link identical store files (slow, one-off; auto-optimise-store is off)
[group('store')]
optimise:
    sudo nix store optimise

# Pin CPE vendors that sbomnix can't resolve. It drops a vendor when its
# daily cpedict lists the product under several (brotli: google + a Go port),
# falling back to vendor = product, which grype then never matches.
_fix-cpes file:
    #!/usr/bin/env bash
    set -eu -o pipefail
    jq '{"brotli": "google"} as $v | .components |= map(
          $v[.name // ""] as $vendor
          | if $vendor and .cpe then .cpe |= sub("^cpe:2\\.3:a:[^:]+:"; "cpe:2.3:a:\($vendor):") else . end)' \
      "{{ file }}" > "{{ file }}.tmp" && mv "{{ file }}.tmp" "{{ file }}"

# SBOM of the running system into .sbom/ (CycloneDX, SPDX, CSV) via sbomnix
[group('security')]
sbom:
    #!/usr/bin/env bash
    set -eu -o pipefail
    out={{ flake }}/.sbom; mkdir -p "$out"; cd "$out"
    name="$(scutil --get LocalHostName 2>/dev/null || hostname -s)-$(date +%Y%m%d-%H%M)"
    # sbomnix runs from the pinned flake input, not installed (see packages.nix)
    sbomnix=$(nix build --no-link --print-out-paths --impure --expr \
      '(builtins.getFlake "{{ flake }}").inputs.sbomnix.packages.${builtins.currentSystem}.sbomnix')
    "$sbomnix/bin/sbomnix" /run/current-system --verbose=0 \
      --cdx="$name.cdx.json" --spdx="$name.spdx.json" --csv="$name.csv"
    just _fix-cpes "$out/$name.cdx.json"
    ln -sf "$name.cdx.json" latest.cdx.json
    echo "$out/$name.cdx.json ($(jq '.components | length' "$name.cdx.json") components)"

# Scan the latest SBOM with grype (regenerated if the system changed). `just scan high` exits non-zero on high+
[group('security')]
scan fail_on="":
    #!/usr/bin/env bash
    set -eu -o pipefail
    sbom={{ flake }}/.sbom/latest.cdx.json
    if [ ! -e "$sbom" ] || [ -n "$(find /nix/var/nix/profiles -maxdepth 1 -name system -newer "$sbom")" ]; then
      just sbom
    fi
    fail_on="{{ fail_on }}"
    grype "sbom:$sbom" ${fail_on:+--fail-on "$fail_on"}

# What a bump would do to CVEs: scan the running system vs a bumped build (lock untouched, nothing switched)
[group('security')]
cves input="":
    #!/usr/bin/env bash
    set -eu -o pipefail
    cd {{ flake }}
    tmp=$(mktemp -d); tmp=$(cd "$tmp" && pwd -P)   # physical path — nix rejects the /var symlink
    trap 'rm -rf "$tmp"' EXIT
    nix flake update {{ input }} --output-lock-file "$tmp/new.lock" >/dev/null
    just _lock-diff-files flake.lock "$tmp/new.lock"
    echo
    echo "building the bumped system…"
    nix build {{ system_attr }} --reference-lock-file "$tmp/new.lock" --no-write-lock-file --out-link result-plan
    sbomnix=$(nix build --no-link --print-out-paths --impure --expr \
      '(builtins.getFlake "{{ flake }}").inputs.sbomnix.packages.${builtins.currentSystem}.sbomnix')
    echo "SBOMs and scans…"
    (cd "$tmp"
      "$sbomnix/bin/sbomnix" /run/current-system \
        --verbose=0 --cdx=now.cdx.json --spdx=now.spdx.json --csv=now.csv
      "$sbomnix/bin/sbomnix" {{ flake }}/result-plan \
        --verbose=0 --cdx=bump.cdx.json --spdx=bump.spdx.json --csv=bump.csv) >/dev/null 2>&1
    just _fix-cpes "$tmp/now.cdx.json"; just _fix-cpes "$tmp/bump.cdx.json"
    grype -q sbom:"$tmp/now.cdx.json" -o json --file "$tmp/now.json"
    grype -q sbom:"$tmp/bump.cdx.json" -o json --file "$tmp/bump.json"
    jq -rn --slurpfile a "$tmp/now.json" --slurpfile b "$tmp/bump.json" '
      def sevs: ["Critical","High","Medium","Low","Negligible","Unknown"];
      def rows(m): [m[0].matches[] | {k: (.vulnerability.id + "|" + .artifact.name),
          id: .vulnerability.id, sev: .vulnerability.severity, pkg: .artifact.name, ver: .artifact.version,
          fixed: (.vulnerability.fix.state == "fixed"), fix: (.vulnerability.fix.versions | join(","))}] | unique_by(.k);
      def count(xs): [sevs[] as $s | "\($s[:4]) \([xs[] | select(.sev == $s)] | length)"] | join("  ");
      def list(xs; f): [xs[] | select(.sev == "Critical" or .sev == "High")] | sort_by(. as $r | (sevs | index($r.sev)), .pkg)
        | if length == 0 then "  (none critical/high)" else .[] | f end;
      rows($a) as $now | rows($b) as $bump | ($now | map(.k)) as $nk | ($bump | map(.k)) as $bk
      | [$now[] | select(.k as $k | $bk | index($k) | not)] as $gone
      | [$bump[] | select(.k as $k | $nk | index($k) | not)] as $new
      | [$bump[] | select(.fixed)] as $waiting | [$bump[] | select(.fixed | not)] as $nofix
      | "",
        "now:           \($now | length) findings   \(count($now))",
        "after bump:    \($bump | length) findings   \(count($bump))",
        "",
        "FIXED BY THIS BUMP (\($gone | length))", list($gone; "  \(.sev[:4])  \(.pkg) \(.ver)  \(.id)"),
        "",
        "NEW IN THIS BUMP (\($new | length))", list($new; "  \(.sev[:4])  \(.pkg) \(.ver)  \(.id)"),
        "",
        "STILL OPEN, FIX EXISTS UPSTREAM — waiting on nixpkgs, or overlay it (\($waiting | length))",
        list($waiting; "  \(.sev[:4])  \(.pkg) \(.ver) -> \(.fix)  \(.id)"),
        "",
        "STILL OPEN, NO FIX YET (\($nofix | length))", list($nofix; "  \(.sev[:4])  \(.pkg) \(.ver)  \(.id)")'
    echo
    echo "apply with: just bump {{ if input == "" { "<input>" } else { input } }} && just switch   (or just update for all inputs)"

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
