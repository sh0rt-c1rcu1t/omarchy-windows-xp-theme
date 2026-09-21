#!/usr/bin/env bash
#
# Replace the synthesised sounds in this theme with the real Windows XP sounds
# from a Windows XP installation (or an extracted ISO) that you own.
#
# Windows XP's Media directory is copyrighted Microsoft material, so it is not
# included in this repository. If you have the originals, this script maps them
# onto the freedesktop sound names the theme installs.
#
#   tools/fetch-xp-sounds.sh /path/to/WINDOWS/Media
#   tools/fetch-xp-sounds.sh --install /path/to/WINDOWS/Media
#
# With --install the copied files are also placed in
# ~/.local/share/sounds/windows-xp/stereo/ so they take effect immediately.
#
# Files are converted to Ogg Vorbis because that is what sound themes ship.

set -euo pipefail

SOURCE_DIR=""
DO_INSTALL=0

while (( $# > 0 )); do
  case "$1" in
  --install)
    DO_INSTALL=1
    shift
    ;;
  -h | --help)
    sed -n '2,20p' "$0" | sed 's/^#\{1,2\} \{0,1\}//'
    exit 0
    ;;
  *)
    SOURCE_DIR="$1"
    shift
    ;;
  esac
done

if [[ -z $SOURCE_DIR ]]; then
  echo "usage: $0 [--install] /path/to/WINDOWS/Media" >&2
  exit 2
fi

if [[ ! -d $SOURCE_DIR ]]; then
  echo "$0: $SOURCE_DIR is not a directory" >&2
  exit 2
fi

command -v ffmpeg >/dev/null || {
  echo "$0: ffmpeg is required to convert the waveforms" >&2
  exit 2
}

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OUT_DIR="$REPO_DIR/sounds"

# Windows XP file name (without extension) -> freedesktop sound name.
# The mapping follows what each sound is for, not a literal name match.
MAPPING=(
  "Windows XP Startup:desktop-login"
  "Windows XP Shutdown:desktop-logout"
  "Windows XP Logon Sound:service-login"
  "Windows XP Logoff Sound:service-logout"
  "Windows XP Ding:message"
  "Windows XP Notify:message-new-instant"
  "Windows XP Information Bar:dialog-information"
  "Windows XP Error:dialog-error"
  "Windows XP Critical Stop:alarm-clock-elapsed"
  "Windows XP Question:dialog-question"
  "Windows XP Hardware Insert:device-added"
  "Windows XP Hardware Remove:device-removed"
  "Windows XP Battery Low:battery-low"
  "Windows XP Battery Critical:battery-caution"
  "Windows XP Pop-up Blocked:dialog-warning"
  "Windows XP Exclamation:dialog-warning"
  "Windows XP Balloon:bell"
  "Windows XP Menu Command:complete"
  "Windows XP Restore:power-plug"
  "Windows XP Minimize:power-unplug"
)

# Locate a source file case-insensitively, in .wav first.
find_source() {
  local base="$1" candidate
  for candidate in "$SOURCE_DIR/$base.wav" "$SOURCE_DIR/$base.WAV" \
    "$SOURCE_DIR/${base// /_}.wav" "$SOURCE_DIR/${base// /}.wav"; do
    [[ -f $candidate ]] && {
      printf '%s' "$candidate"
      return 0
    }
  done
  # Last resort: a case-insensitive glob, in case the file is named differently.
  local match
  match=$(find "$SOURCE_DIR" -maxdepth 1 -iname "${base}.wav" -print -quit 2>/dev/null || true)
  [[ -n $match ]] && {
    printf '%s' "$match"
    return 0
  }
  return 1
}

converted=0
missing=0

for entry in "${MAPPING[@]}"; do
  xp_name="${entry%%:*}"
  target_name="${entry##*:}"
  if ! source=$(find_source "$xp_name"); then
    printf '  missing: %s\n' "$xp_name"
    (( ++missing ))
    continue
  fi

  target="$OUT_DIR/$target_name.oga"
  if ! ffmpeg -hide_banner -loglevel error -y -i "$source" -c:a libvorbis -q:a 6 "$target"; then
    printf '  failed to convert %s\n' "$source" >&2
    exit 1
  fi
  printf '  %-38s -> %s\n' "$(basename "$source")" "$(basename "$target")"
  (( ++converted ))
done

printf '\nconverted %d file(s), %d not found\n' "$converted" "$missing"

if (( DO_INSTALL )); then
  install_dir="$HOME/.local/share/sounds/windows-xp"
  mkdir -p "$install_dir/stereo"
  cp "$REPO_DIR/sounds/index.theme" "$install_dir/"
  cp "$REPO_DIR/sounds"/*.oga "$install_dir/stereo/"
  echo "installed to $install_dir"
fi
