#!/usr/bin/env bash
# Agent picker — claude-tmux-notify picker replacement (INV-0002).
# Lists agent panes blocked-first with a live pane preview; enter focuses.
set -euo pipefail

rows=$(herdr agent list | jq -r '
  .result.agents
  | sort_by(.agent_status | if . == "blocked" then 0 elif . == "working" then 1 else 2 end)
  | .[]
  | [.terminal_id, .agent_status, .agent, .cwd]
  | @tsv')

if [ -z "$rows" ]; then
  echo "no agent sessions"
  sleep 1
  exit 0
fi

pick=$(echo "$rows" | awk -F'\t' '{
  icon = ($2 == "blocked") ? "🤖" : ($2 == "working") ? "⏳" : "✅"
  n = split($4, parts, "/")
  printf "%s\t%s %-7s  %s  (%s)\n", $1, icon, $2, parts[n], $3
}' | fzf --delimiter='\t' --with-nth=2 --no-sort --ansi \
  --prompt='🤖  ' \
  --header='agents · blocked first · enter: focus' \
  --preview 'herdr agent read {1} --lines 30 --format ansi | jq -rj .result.read.text' \
  --preview-window 'right:60%') || exit 0

herdr agent focus "$(echo "$pick" | cut -f1)"
