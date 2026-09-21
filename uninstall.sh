#!/usr/bin/env bash
#
# Undo everything install.sh did.
#
#   ./uninstall.sh                 remove files, keep the current theme applied
#   ./uninstall.sh --switch-theme  switch to another theme afterwards
#
# Backups taken by install.sh (~/.config/omarchy/extensions/omarchy-menu.jsonc
# .bak.windows-xp.*, shell.json.bak.windows-xp.*, looknfeel.lua.bak.windows-xp.*)
# are listed at the end so you can restore them by hand.

set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
OMARCHY_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy"
THEME_SLUG="windows-xp"

SWITCH_THEME=0
NEXT_THEME=""
while (( $# > 0 )); do
  case "$1" in
  --switch-theme)
    SWITCH_THEME=1
    NEXT_THEME="${2:-}"
    shift
    (( $# > 0 )) && shift || true
    ;;
  -h | --help)
    sed -n '2,12p' "$0" | sed 's/^#\{1,2\} \{0,1\}//'
    exit 0
    ;;
  *)
    echo "uninstall: unknown option $1" >&2
    exit 2
    ;;
  esac
done

step() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

step "Removing the Start button from the bar layout"
bash "$REPO_DIR/scripts/install-shell.sh" --restore >/dev/null

step "Removing the shell plugins"
rm -rf "$OMARCHY_CONFIG/plugins/windows-xp.start-button" \
  "$OMARCHY_CONFIG/plugins/windows-xp.start-menu"

step "Removing the hooks"
rm -f "$OMARCHY_CONFIG/hooks/post-boot.d/windows-xp-startup-sound" \
  "$OMARCHY_CONFIG/hooks/theme-set.d/windows-xp-theme-set"

step "Removing the theme symlink"
if [ -L "$OMARCHY_CONFIG/themes/$THEME_SLUG" ]; then
  rm -f "$OMARCHY_CONFIG/themes/$THEME_SLUG"
fi

step "Keeping the sound scheme in place (delete it yourself if you want it gone:"
printf '     rm -rf %s)\n' "${XDG_DATA_HOME:-$HOME/.local/share}/sounds/windows-xp"

step "The menu extensions file was left in place; restore the backup to undo it"

if (( SWITCH_THEME )); then
  if [ -z "$NEXT_THEME" ]; then
    NEXT_THEME="Tokyo Night"
  fi
  step "Switching the theme to $NEXT_THEME"
  omarchy theme set "$NEXT_THEME" || true
fi

step "Restarting the shell"
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v omarchy-restart-shell >/dev/null 2>&1; then
  omarchy-restart-shell >/dev/null 2>&1 || true
fi

echo
echo "Backups left behind by install.sh:"
ls -1 "$OMARCHY_CONFIG"/extensions/omarchy-menu.jsonc.bak.windows-xp.* \
  "$OMARCHY_CONFIG"/shell.json.bak.windows-xp.* \
  "$HOME"/.config/hypr/looknfeel.lua.bak.windows-xp.* 2>/dev/null || echo "  (none)"

exit 0
