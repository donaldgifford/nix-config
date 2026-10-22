#!/usr/bin/env bash
# Claude Code statusLine command - based on robbyrussell/Starship default style
# Linked to ~/.claude/statusline-command.sh by home/common/claude.nix (live
# edits, no rebuild). Wired up in ~/.claude/settings.json, which is unmanaged.

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

cost_total=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')

five_hour_used_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_day_used_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

five_hour_reset_at=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_day_reset_at=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# Convert ISO-8601 UTC timestamp to "fri 5pm" in local timezone.
human_time() {
  local iso="$1"
  [ -z "$iso" ] && return
  local fmt="+%a %-I%p"
  local out epoch

  if date --version >/dev/null 2>&1; then
    # GNU date (Linux / NixOS) — parses ISO-8601 natively, converts to local
    out=$(date -d "$iso" "$fmt" 2>/dev/null)
  else
    # BSD date (macOS) — parse as UTC to epoch, then format in local tz
    epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" "+%s" 2>/dev/null)
    [ -n "$epoch" ] && out=$(date -r "$epoch" "$fmt" 2>/dev/null)
  fi

  # Lowercase AM/PM → am/pm (tr is portable; ${var,,} needs bash 4+)
  printf '%s' "$out" | tr '[:upper:]' '[:lower:]'
}

# Shorten path: replace $HOME with ~
home="$HOME"
short_dir="${cwd/#$home/\~}"

# Git branch (skip optional lock to avoid blocking)
git_branch=""
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git_branch=$(git -C "$cwd" -c core.useBuiltinFSMonitor=false symbolic-ref --short HEAD 2>/dev/null ||
    git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

# Colors (ANSI)
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
DIM='\033[2m'
RESET='\033[0m'

# Theme override — the active theme (config/themes in nix-config) may redefine
# CYAN/RED/YELLOW/DIM with truecolor values; ANSI defaults above are the fallback.
[ -f "$HOME/.config/themes/current/claude-colors.sh" ] && . "$HOME/.config/themes/current/claude-colors.sh"
# ci-status reads these from the environment (docs/design/0002)
export CYAN RED YELLOW GREEN DIM RESET

# Build status line
line=""

# Directory
line+="$(printf "${CYAN}%s${RESET}" "$short_dir")"

# Git branch
if [ -n "$git_branch" ]; then
  line+=" $(printf "${RED}(%s)${RESET}" "$git_branch")"
fi

# CI on HEAD: Buildkite + GitHub Actions + open PR. Cache-only, ~20 ms; a
# stale entry spawns a detached refresh. Prints nothing outside GitHub repos.
if [ -n "$git_branch" ] && command -v ci-status >/dev/null 2>&1; then
  ci=$(ci-status --dir "$cwd" --format ansi 2>/dev/null) || ci=""
  [ -n "$ci" ] && line+=" $ci"
fi

# Model
if [ -n "$model" ]; then
  line+=" $(printf "${DIM}[%s]${RESET}" "$model")"
fi

# Context usage
if [ -n "$used_pct" ]; then
  printf_pct=$(printf "%.0f" "$used_pct" 2>/dev/null || echo "$used_pct")
  line+=" $(printf "${YELLOW}ctx:%s%%${RESET}" "$printf_pct")"
fi

# Cost Total
if [ -n "$cost_total" ]; then
  printf_cost_total=$(printf "$%.2f" "$cost_total" 2>/dev/null || echo "$cost_total")
  line+=" $(printf "${DIM}%s${RESET}" "$printf_cost_total")"
fi
#
# # Five Hour Used Percentage
# if [ -n "$five_hour_used_pct" ]; then
#   printf_five_hour_used_pct=$(printf "%.0f" "$five_hour_used_pct" 2>/dev/null || echo "$five_hour_used_pct")
#   line+=" $(printf "${YELLOW}5h:%s%%${RESET}" "$printf_five_hour_used_pct")"
# fi
#
# # Five Hour Reset At
# if [ -n "$five_hour_reset_at" ]; then
#   line+=" $(printf "${DIM}[%s]${RESET}" "$five_hour_reset_at")"
# fi
#
# # Seven Day Used Percentage
# if [ -n "$seven_day_used_pct" ]; then
#   printf_seven_day_used_pct=$(printf "%.0f" "$seven_day_used_pct" 2>/dev/null || echo "$seven_day_used_pct")
#   line+=" $(printf "${YELLOW}7d:%s%%${RESET}" "$printf_seven_day_used_pct")"
# fi
#
# # Seven Day Reset
# if [ -n "$seven_day_reset_at" ]; then
#   line+=" $(printf "${DIM}[%s]${RESET}" "$seven_day_reset_at")"
# fi

# Five Hour Used Percentage
if [ -n "$five_hour_used_pct" ]; then
  printf_pct=$(printf "%.0f" "$five_hour_used_pct")
  reset=$(human_time "$five_hour_reset_at")
  line+=" $(printf "${YELLOW}5h:%s%%${RESET}" "$printf_pct")"
  [ -n "$reset" ] && line+=" $(printf "${DIM}(%s)${RESET}" "$reset")"
fi

# Seven Day Used Percentage
if [ -n "$seven_day_used_pct" ]; then
  printf_pct=$(printf "%.0f" "$seven_day_used_pct")
  reset=$(human_time "$seven_day_reset_at")
  line+=" $(printf "${YELLOW}7d:%s%%${RESET}" "$printf_pct")"
  [ -n "$reset" ] && line+=" $(printf "${DIM}(%s)${RESET}" "$reset")"
fi

printf "%b\n" "$line"
