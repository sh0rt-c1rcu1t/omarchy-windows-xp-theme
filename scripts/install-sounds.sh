#!/usr/bin/env bash
#
# Install the Windows XP sound scheme for the user and, when the desktop's sound
# theme can be set from the command line, select it.
#
#   scripts/install-sounds.sh            # install and select
#   scripts/install-sounds.sh --no-select
#
# The sounds land in ~/.local/share/sounds/windows-xp/, which is a standard
# location libcanberra reads, so no root access is needed.

set -euo pipefail

SELECT=1
[[ ${1:-} == "--no-select" ]] && SELECT=0

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SOURCE_DIR="$REPO_DIR/sounds"
TARGET_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/sounds/windows-xp"

if [[ ! -d $SOURCE_DIR ]]; then
  echo "install-sounds: $SOURCE_DIR is missing" >&2
  exit 1
fi

mkdir -p "$TARGET_DIR/stereo"
cp "$SOURCE_DIR/index.theme" "$TARGET_DIR/"
cp "$SOURCE_DIR"/*.oga "$TARGET_DIR/stereo/"

echo "Installed $(find "$TARGET_DIR/stereo" -name '*.oga' | wc -l) sounds to $TARGET_DIR"

if (( SELECT )); then
  # GTK and GNOME-based applications read this. Hyprland sessions usually have
  # no audio-event daemon, so the hooks in omarchy/hooks/ are what make the
  # login and theme-switch sounds audible.
  if command -v gsettings >/dev/null 2>&1 &&
    gsettings writable org.gnome.desktop.sound theme >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.sound theme "windows-xp" 2>/dev/null &&
      echo "Selected windows-xp as the desktop sound theme"
  fi
fi

exit 0
