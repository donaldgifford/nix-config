#!/usr/bin/env bash
# theme — switch all supported apps between themes in config/themes/.
#
# Usage: theme [name]        (no arg: fzf picker)
#
# Per-app mechanics (everything is live-editable via mkOutOfStoreSymlink):
#   symlink   ~/.config/themes/current -> <name>/  (tmux/fzf/bat/eza/nvim read it)
#   ghostty   rewrites the `theme = ` line in config/ghostty/config
#   herdr     splices <name>/herdr.toml between THEME:BEGIN/END markers
#   rex       imports the ghostty theme file via client.theme.import
#   tmux      re-sources config live
# New shells pick up env (BAT_THEME, EZA_CONFIG_DIR, fzf colors) on start.
set -euo pipefail

THEMES="$HOME/.config/themes"

name="${1:-}"
if [ -z "$name" ]; then
  name=$(find "$THEMES" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; \
    | sort | fzf --prompt='theme  ' --height=~10) || exit 0
fi

dir="$THEMES/$name"
[ -d "$dir" ] || { echo "theme: no such theme '$name' in $THEMES" >&2; exit 1; }

ln -sfn "$dir" "$THEMES/current"

# write_through: overwrite a possibly-symlinked file without breaking the link
write_through() { # $1=dest $2=tmpfile
  cat "$2" > "$1" && rm -f "$2"
}

# ── ghostty: swap the `theme = ` line ────────────────────────────────────────
ghostty_cfg="$HOME/.config/ghostty/config"
ghostty_theme="$(head -1 "$dir/ghostty-theme")"
tmp=$(mktemp)
sed -E "s/^theme = .*/theme = $ghostty_theme/" "$ghostty_cfg" > "$tmp"
write_through "$ghostty_cfg" "$tmp"

# ── starship: swap the `palette = ` line ─────────────────────────────────────
# Both palettes are defined in starship.toml; new prompts pick it up instantly
# (starship re-reads config every render).
starship_cfg="$HOME/.config/starship.toml"
if [ -f "$dir/starship-palette" ]; then
  starship_palette="$(head -1 "$dir/starship-palette")"
  tmp=$(mktemp)
  sed -E "s/^palette = .*/palette = '$starship_palette'/" "$starship_cfg" > "$tmp"
  write_through "$starship_cfg" "$tmp"
fi

# ── herdr: splice the [theme] block between markers ──────────────────────────
herdr_cfg="$HOME/.config/herdr/config.toml"
if [ -f "$dir/herdr.toml" ] && grep -q "THEME:BEGIN" "$herdr_cfg"; then
  tmp=$(mktemp)
  awk -v themefile="$dir/herdr.toml" '
    /THEME:BEGIN/ { print; while ((getline line < themefile) > 0) print line; skip=1; next }
    /THEME:END/   { skip=0 }
    !skip { print }
  ' "$herdr_cfg" > "$tmp"
  write_through "$herdr_cfg" "$tmp"
fi

# ── rex: import the same Ghostty theme file into the Rex app ─────────────────
# Rex has no theme setting in init.lua; its client.theme.import action reads a
# Ghostty theme file and selects it. Needs Remote Control on (Rex Settings >
# Rex Server). rex is only on PATH inside Rex terminals, so fall back to the
# server's bundled CLI; --autostart=false so switching never spawns a server.
rex_bin="${REX_BIN_DIR:-$HOME/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS}/rex"
if [ -x "$rex_bin" ]; then
  rex_theme=""
  for d in "$HOME/.config/ghostty/themes" \
    "$HOME/Applications/Home Manager Apps/Ghostty.app/Contents/Resources/ghostty/themes"; do
    [ -f "$d/$ghostty_theme" ] && { rex_theme="$d/$ghostty_theme"; break; }
  done
  if [ -z "$rex_theme" ]; then
    echo "  rex: no Ghostty theme file for '$ghostty_theme', skipped" >&2
  elif ! "$rex_bin" --autostart=false "do" client.theme.import path="$rex_theme" >/dev/null 2>&1; then
    echo "  rex: not updated (app closed, or Remote Control off in Settings > Rex Server)" >&2
  fi
fi

# ── bat: make sure vendored tmThemes are in the cache ────────────────────────
if ! bat --list-themes 2>/dev/null | grep -q "Warm Burnout"; then
  bat cache --build >/dev/null
fi

# ── tmux: reload live sessions ───────────────────────────────────────────────
if tmux info &>/dev/null; then
  tmux source-file ~/.config/tmux/tmux.conf
fi

echo "theme → $name"
echo "  live now:   tmux, rex, eza/bat/fzf (new shells), nvim (new instances)"
echo "  reload:     ghostty cmd+shift+,   herdr: restart server"
