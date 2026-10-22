# ci-status — CI state of the current HEAD commit, from GitHub only.
#
# Buildkite posts a `buildkite/<pipeline>` commit status to GitHub and
# GitHub Actions results are check runs, so one `gh api graphql` call covers
# both plus the associated PR. The prompt path (every mode except
# --refresh) only ever reads a cache file and, when that is missing or
# stale, spawns a detached refresh; it never touches the network itself.
#
#   ci-status [--dir D] --format ansi                 whole line, escape codes
#   ci-status [--dir D] --format starship --segment bk|gh|pr   bare text
#   ci-status [--dir D] --is bk|gh yellow|green|red   exit 0/1, for starship `when`
#   ci-status [--dir D] --refresh                     fetch + write the cache
#   ci-status [--ttl S]                               staleness, default 30 s
#   ci-status --self-test                             classifier over canned JSON
#
# Cache: ${XDG_CACHE_HOME:-~/.cache}/ci-status/<owner>_<repo>_<sha>, JSON with
# fetched_at inside (no stat: GNU coreutils shadow BSD on this Mac). One
# refresh per key at a time via a mkdir lock. Design: docs/design/0002.

set -euo pipefail

TTL=30
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ci-status"
LOCK_MAX_AGE=120
PRUNE_AFTER=$((7 * 24 * 3600))

dir="$PWD"
format=""
segment=""
mode="render"
is_seg=""
is_col=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dir) dir="${2-}"; shift 2 ;;
    --format) format="${2-}"; shift 2 ;;
    --segment) segment="${2-}"; shift 2 ;;
    --is) mode="is"; is_seg="${2-}"; is_col="${3-}"; shift 3 ;;
    --refresh) mode="refresh"; shift ;;
    --ttl) TTL="${2-30}"; shift 2 ;;
    --self-test) mode="selftest"; shift ;;
    *) exit 0 ;; # the prompt must never see an error
  esac
done

# shellcheck disable=SC2016 # $vars are GraphQL / jq, not shell
QUERY='query($owner:String!,$name:String!,$sha:GitObjectID!){
  repository(owner:$owner,name:$name){
    object(oid:$sha){ ... on Commit {
      associatedPullRequests(first:1){ nodes{ number state } }
      statusCheckRollup{ contexts(first:100){ nodes{
        __typename
        ... on StatusContext{ context state targetUrl }
        ... on CheckRun{ name status conclusion }
      }}}
    }}
  }
}'

# GraphQL response -> cache entry. $now is injected with --argjson.
# shellcheck disable=SC2016
CLASSIFY='
def worst(l):
  if any(l[]; . == "red") then "red"
  elif any(l[]; . == "yellow") then "yellow"
  elif (l | length) > 0 then "green"
  else null end;
.data.repository.object as $o
| if $o == null then { found: false }
  else
    ($o.statusCheckRollup.contexts.nodes // []) as $n
    | ([ $n[]
         | select(.__typename == "StatusContext" and (.context | startswith("buildkite/")))
         | { c: (if .state == "SUCCESS" then "green"
                 elif (.state == "FAILURE" or .state == "ERROR") then "red"
                 else "yellow" end),
             url: .targetUrl } ]) as $bk
    | ([ $n[]
         | select(.__typename == "CheckRun")
         | (if .status != "COMPLETED" then "yellow"
            elif (.conclusion | IN("FAILURE", "TIMED_OUT", "CANCELLED", "STARTUP_FAILURE")) then "red"
            else "green" end) ]) as $gh
    | ($o.associatedPullRequests.nodes[0] // null) as $pr
    | { found: true }
      + (if ($bk | length) > 0 then { bk: { state: worst([ $bk[].c ]), url: $bk[0].url } } else {} end)
      + (if ($gh | length) > 0 then { gh: { state: worst($gh) } } else {} end)
      + (if $pr != null and $pr.state == "OPEN" then { pr: { number: $pr.number } } else {} end)
  end
| . + { fetched_at: $now }
'

now_s() { printf '%(%s)T' -1; } # bash builtin; a `date` fork is ~3 ms of the hot path

# ── repo resolution ──────────────────────────────────────────────────────────
owner=""
name=""
sha=""
key=""

git_q() { git -C "$dir" -c core.useBuiltinFSMonitor=false "$@" 2>/dev/null; }

resolve() {
  local url path
  url=$(git_q remote get-url origin) || return 1
  case "$url" in
    git@github.com:*) path="${url#git@github.com:}" ;;
    ssh://git@github.com/*) path="${url#ssh://git@github.com/}" ;;
    https://github.com/*) path="${url#https://github.com/}" ;;
    *) return 1 ;;
  esac
  path="${path%/}"
  path="${path%.git}"
  owner="${path%%/*}"
  name="${path#*/}"
  [ -n "$owner" ] && [ -n "$name" ] && [[ "$name" != */* ]] || return 1
  sha=$(git_q rev-parse HEAD) || return 1
  key="$CACHE_DIR/${owner}_${name}_${sha}"
}

# ── refresh (the only network path) ─────────────────────────────────────────
LOCK=""
prune() {
  local f fetched now
  now=$(now_s)
  for f in "$CACHE_DIR"/*; do
    [ -f "$f" ] || continue
    fetched=$(jq -r '.fetched_at // 0' "$f" 2>/dev/null || echo 0)
    [ $((now - fetched)) -gt "$PRUNE_AFTER" ] && rm -f "$f"
  done
  return 0
}

refresh() {
  resolve || exit 0
  mkdir -p "$CACHE_DIR"
  local started now resp tmp
  LOCK="$key.lock" # global: the EXIT trap runs after this function's locals are gone
  now=$(now_s)
  if ! mkdir "$LOCK" 2>/dev/null; then
    started=$(cat "$LOCK/started" 2>/dev/null || echo 0)
    [ $((now - started)) -gt "$LOCK_MAX_AGE" ] || exit 0
    rm -rf "$LOCK"
    mkdir "$LOCK" 2>/dev/null || exit 0
  fi
  echo "$now" >"$LOCK/started"
  trap 'rm -rf "$LOCK"' EXIT
  resp=$(gh api graphql -f query="$QUERY" -f owner="$owner" -f name="$name" -f sha="$sha" 2>/dev/null) || exit 0
  tmp=$(mktemp "$CACHE_DIR/.tmp.XXXXXX")
  if jq -e --argjson now "$(now_s)" "$CLASSIFY" <<<"$resp" >"$tmp" 2>/dev/null; then
    mv -f "$tmp" "$key"
  else
    rm -f "$tmp"
  fi
  prune
}

# ── hot path ─────────────────────────────────────────────────────────────────
found=""
bk_state=""
gh_state=""
pr_number=""

load() {
  resolve || exit 0
  local now fetched=0
  now=$(now_s)
  if [ -f "$key" ]; then
    # One jq for everything the renderers need. "-" stands in for empty:
    # read collapses runs of whitespace IFS, so an empty field would shift
    # every field after it.
    read -r found bk_state gh_state pr_number fetched < <(
      jq -r '[(.found // false | tostring), (.bk.state // "-"), (.gh.state // "-"),
              (.pr.number // "-" | tostring), (.fetched_at // 0 | tostring)] | join(" ")' "$key" 2>/dev/null
    ) || true
    [ "$bk_state" = "-" ] && bk_state=""
    [ "$gh_state" = "-" ] && gh_state=""
    [ "$pr_number" = "-" ] && pr_number=""
    fetched="${fetched:-0}"
  fi
  if [ -z "$found" ] || [ $((now - fetched)) -gt "$TTL" ]; then
    nohup "$0" --refresh --dir "$dir" >/dev/null 2>&1 &
    disown 2>/dev/null || true
  fi
  [ "$found" = "true" ] || exit 0
}

glyph() {
  case "$1" in
    bk) printf 'bk ●' ;;
    gh) printf 'gh ✓' ;;
    pr) if [ -n "$pr_number" ]; then printf '#%s' "$pr_number"; fi ;;
  esac
  return 0
}

render_ansi() {
  local yellow green red dim reset
  yellow="${YELLOW:-$'\033[0;33m'}"
  green="${GREEN:-$'\033[0;32m'}"
  red="${RED:-$'\033[0;31m'}"
  dim="${DIM:-$'\033[2m'}"
  reset="${RESET:-$'\033[0m'}"
  local out="" seg state col
  for seg in bk gh; do
    if [ "$seg" = bk ]; then state="$bk_state"; else state="$gh_state"; fi
    case "$state" in
      yellow) col="$yellow" ;;
      green) col="$green" ;;
      red) col="$red" ;;
      *) continue ;;
    esac
    out+="${out:+ }${col}$(glyph "$seg")${reset}"
  done
  if [ -n "$pr_number" ]; then out+="${out:+ }${dim}#${pr_number}${reset}"; fi
  if [ -n "$out" ]; then printf '%s\n' "$out"; fi
  return 0
}

render_starship() {
  case "$segment" in
    bk) if [ -n "$bk_state" ]; then glyph bk; fi ;;
    gh) if [ -n "$gh_state" ]; then glyph gh; fi ;;
    pr) glyph pr ;;
  esac
  return 0
}

# ── self-test ────────────────────────────────────────────────────────────────
selftest() {
  local fails=0
  check() { # $1=label $2=expected summary, stdin=GraphQL response
    local got
    got=$(jq -r --argjson now 0 "$CLASSIFY"' | "found=\(.found) bk=\(.bk.state // "-") gh=\(.gh.state // "-") pr=\(.pr.number // "-")"')
    if [ "$got" = "$2" ]; then
      printf 'ok   %s\n' "$1"
    else
      printf 'FAIL %s\n     want %s\n     got  %s\n' "$1" "$2" "$got"
      fails=$((fails + 1))
    fi
  }
  check "homelab red, no PR" "found=true bk=red gh=- pr=-" <<'EOF'
{"data":{"repository":{"object":{"associatedPullRequests":{"nodes":[]},"statusCheckRollup":{"contexts":{"nodes":[{"__typename":"StatusContext","context":"buildkite/homelab","state":"FAILURE","targetUrl":"https://buildkite.com/x/homelab/builds/1"}]}}}}}}
EOF
  check "homelab pending with open PR" "found=true bk=yellow gh=- pr=228" <<'EOF'
{"data":{"repository":{"object":{"associatedPullRequests":{"nodes":[{"number":228,"state":"OPEN"}]},"statusCheckRollup":{"contexts":{"nodes":[{"__typename":"StatusContext","context":"buildkite/homelab","state":"PENDING","targetUrl":"https://buildkite.com/x/homelab/builds/2"}]}}}}}}
EOF
  check "actions all green, merged PR hidden" "found=true bk=- gh=green pr=-" <<'EOF'
{"data":{"repository":{"object":{"associatedPullRequests":{"nodes":[{"number":9,"state":"MERGED"}]},"statusCheckRollup":{"contexts":{"nodes":[{"__typename":"CheckRun","name":"lint","status":"COMPLETED","conclusion":"SUCCESS"},{"__typename":"CheckRun","name":"docs","status":"COMPLETED","conclusion":"SKIPPED"}]}}}}}}
EOF
  check "actions one cancelled → red" "found=true bk=- gh=red pr=-" <<'EOF'
{"data":{"repository":{"object":{"associatedPullRequests":{"nodes":[]},"statusCheckRollup":{"contexts":{"nodes":[{"__typename":"CheckRun","name":"a","status":"COMPLETED","conclusion":"SUCCESS"},{"__typename":"CheckRun","name":"b","status":"COMPLETED","conclusion":"CANCELLED"},{"__typename":"CheckRun","name":"c","status":"IN_PROGRESS","conclusion":null}]}}}}}}
EOF
  check "actions running, red beats yellow" "found=true bk=- gh=red pr=-" <<'EOF'
{"data":{"repository":{"object":{"associatedPullRequests":{"nodes":[]},"statusCheckRollup":{"contexts":{"nodes":[{"__typename":"CheckRun","name":"a","status":"QUEUED","conclusion":null},{"__typename":"CheckRun","name":"b","status":"COMPLETED","conclusion":"TIMED_OUT"}]}}}}}}
EOF
  check "both systems, non-buildkite status ignored" "found=true bk=green gh=yellow pr=-" <<'EOF'
{"data":{"repository":{"object":{"associatedPullRequests":{"nodes":[]},"statusCheckRollup":{"contexts":{"nodes":[{"__typename":"StatusContext","context":"buildkite/homelab","state":"SUCCESS","targetUrl":"u"},{"__typename":"StatusContext","context":"codecov/patch","state":"FAILURE","targetUrl":"u"},{"__typename":"CheckRun","name":"a","status":"IN_PROGRESS","conclusion":null}]}}}}}}
EOF
  check "unknown sha" "found=false bk=- gh=- pr=-" <<'EOF'
{"data":{"repository":{"object":null}}}
EOF
  check "no rollup at all" "found=true bk=- gh=- pr=-" <<'EOF'
{"data":{"repository":{"object":{"associatedPullRequests":{"nodes":[]},"statusCheckRollup":null}}}}
EOF
  [ "$fails" -eq 0 ]
}

# ── dispatch ─────────────────────────────────────────────────────────────────
case "$mode" in
  refresh) refresh ;;
  selftest) selftest ;;
  is)
    load
    case "$is_seg" in
      bk) [ "$bk_state" = "$is_col" ] ;;
      gh) [ "$gh_state" = "$is_col" ] ;;
      *) false ;;
    esac
    ;;
  render)
    load
    case "$format" in
      ansi) render_ansi ;;
      starship) render_starship ;;
    esac
    ;;
esac
