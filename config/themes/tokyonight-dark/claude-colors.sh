# Tokyonight Night — Claude Code statusline colors (truecolor)
# Sourced by ~/.claude/statusline-command.sh; overrides its ANSI defaults.
# Same values as the tokyonight_dark starship palette, so the status line
# and the prompt match in one terminal.
CYAN='\033[38;2;125;207;255m'   # dir → cyan #7dcfff
RED='\033[38;2;247;118;142m'    # branch, ci failed → red #f7768e
YELLOW='\033[38;2;224;175;104m' # ctx%, ci pending → yellow #e0af68
GREEN='\033[38;2;158;206;106m'  # ci passed → green #9ece6a
DIM='\033[2m'                   # faint, like starship's `dimmed`
