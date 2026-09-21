#!/usr/bin/env bash
#
# Put the Windows XP taskbar layout into ~/.config/omarchy/shell.json.
#
#   scripts/install-shell.sh              # bar at the bottom, Start button first
#   scripts/install-shell.sh --bar top    # keep the bar at the top
#   scripts/install-shell.sh --restore    # undo: remove the Start button entry
#
# The script edits only the `bar` subtree and backs the file up first. It is
# idempotent: running it twice changes nothing the second time.

set -euo pipefail

SHELL_CONFIG="$HOME/.config/omarchy/shell.json"
POSITION="bottom"
RESTORE=0
START_BUTTON_ID="windows-xp.start-button"
MENU_WIDGET_ID="omarchy.menu"

while (( $# > 0 )); do
  case "$1" in
  --bar)
    POSITION="${2:-bottom}"
    shift 2
    ;;
  --restore)
    RESTORE=1
    shift
    ;;
  -h | --help)
    sed -n '2,14p' "$0" | sed 's/^#\{1,2\} \{0,1\}//'
    exit 0
    ;;
  *)
    echo "install-shell: unknown option $1" >&2
    exit 2
    ;;
  esac
done

case "$POSITION" in
top | bottom) ;;
*)
  echo "install-shell: --bar takes 'top' or 'bottom'" >&2
  exit 2
  ;;
esac

command -v jq >/dev/null || {
  echo "install-shell: jq is required" >&2
  exit 2
}

if [ ! -f "$SHELL_CONFIG" ]; then
  echo "install-shell: $SHELL_CONFIG does not exist; is Omarchy set up?" >&2
  exit 1
fi

backup="$SHELL_CONFIG.bak.windows-xp.$(date +%s)"
cp "$SHELL_CONFIG" "$backup"
echo "Backed up $SHELL_CONFIG to $backup"

if (( RESTORE )); then
  jq '
    .bar.layout.left = ([.bar.layout.left[]? | select(.id != "'"$START_BUTTON_ID"'")])
  ' "$SHELL_CONFIG" >"$SHELL_CONFIG.tmp"
  mv "$SHELL_CONFIG.tmp" "$SHELL_CONFIG"
  echo "Removed the Start button from the bar layout"
  exit 0
fi

# Ensure the layout sections exist, then build the XP layout:
#   left   Start button, then the menu-less remainder (workspaces)
#   center clock, as Windows XP's tray clock is the only always-visible item
#   right  tray and status indicators, as in the XP notification area
jq --arg pos "$POSITION" --arg start "$START_BUTTON_ID" --arg menu "$MENU_WIDGET_ID" '
  .bar = (.bar // {}) |
  .bar.position = $pos |
  .bar.transparent = false |
  .bar.layout = (.bar.layout // {}) |
  .bar.layout.left = (.bar.layout.left // []) |
  .bar.layout.center = (.bar.layout.center // []) |
  .bar.layout.right = (.bar.layout.right // []) |
  # Drop a previous Start button so the operation is idempotent, then put one
  # at the head of the left section.
  .bar.layout.left = ([{ id: $start }] + [.bar.layout.left[]? | select(.id != $start)]) |
  # The Omarchy menu button is redundant next to the Start button.
  .bar.layout.left = [.bar.layout.left[]? | select(.id != $menu)] |
  .bar.layout.right = ([.bar.layout.right[]? | select(.id != $menu)])
' "$SHELL_CONFIG" >"$SHELL_CONFIG.tmp"
mv "$SHELL_CONFIG.tmp" "$SHELL_CONFIG"

echo "Bar layout: position=$POSITION with the Start button at the left"
echo
echo "Activate it with:  omarchy restart shell"
