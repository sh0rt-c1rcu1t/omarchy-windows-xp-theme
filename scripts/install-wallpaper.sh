#!/usr/bin/env bash
#
# Set the Windows XP wallpaper, or install a high-resolution copy of the
# genuine Bliss photograph if you have one.
#
#   scripts/install-wallpaper.sh                    re-apply the theme's own wallpaper
#   scripts/install-wallpaper.sh <file-or-url>      use your own image (4K+ recommended)
#   scripts/install-wallpaper.sh --restore          go back to the theme's own set
#
# Why this exists: Microsoft's Bliss photograph ("Rolling green hill", Charles
# O'Rear, 1996) is copyrighted and is not redistributed with this theme. The
# theme ships original renderings instead. If you own a copy of the image -- from
# a Windows XP installation you are licensed for, or from Microsoft's own
# high-resolution release -- point this script at it and it becomes the theme's
# default background, taking precedence over the generated ones.

set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
THEME_SLUG="windows-xp"
THEME_DIR="$HOME/.config/omarchy/themes/$THEME_SLUG"
# Given a symlinked theme (how install.sh sets it up) `backgrounds` resolves into
# the repository and the change travels with it. A copied theme keeps its own.
BACKGROUNDS_DIR="$THEME_DIR/backgrounds"
CURRENT_BG="$HOME/.local/state/omarchy/current/background"

step() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
fail() {
  printf '\033[1;31merror\033[0m %s\n' "$*" >&2
  exit 1
}

[[ -d $THEME_DIR ]] || fail "$THEME_DIR is missing; run ./install.sh first"

# Preferred order: a user-supplied original first, then the default Bliss
# rendering, then whatever else the theme ships. Wallpapers may be PNG or JPEG.
restore() {
  local candidate
  for candidate in "$BACKGROUNDS_DIR"/0-bliss-original.* "$BACKGROUNDS_DIR"/1-bliss.*; do
    [[ -f $candidate ]] || continue
    step "Restoring the theme's own wallpaper: $(basename "$candidate")"
    ln -nsf "$(readlink -f "$candidate")" "$CURRENT_BG"
    return
  done

  candidate=$(find -L "$BACKGROUNDS_DIR" -maxdepth 1 -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
    -print 2>/dev/null | sort | head -1)
  [[ -n $candidate ]] || fail "no wallpapers found in $BACKGROUNDS_DIR"
  step "Restoring $(basename "$candidate")"
  ln -nsf "$(readlink -f "$candidate")" "$CURRENT_BG"
}

set_wallpaper() {
  local source="$1"
  local target="$BACKGROUNDS_DIR/0-bliss-original.png"

  if [[ $source =~ ^https?:// ]]; then
    command -v curl >/dev/null || fail "curl is required to download a URL"
    step "Downloading $source"
    curl -fsSL --retry 3 -o "$target.tmp" "$source" || fail "download failed"
  else
    [[ -f $source ]] || fail "$source is not a file"
    if file --mime-type -b "$source" | grep -q '^image/'; then
      cp "$source" "$target.tmp"
    else
      fail "$source does not look like an image ($(file --mime-type -b "$source"))"
    fi
  fi

  # Normalise to PNG at the display's aspect ratio so the compositor never has
  # to scale it up, which is what makes a small wallpaper look soft.
  local width height
  width=$(hyprctl monitors -j 2>/dev/null | jq -r '.[0].width // empty')
  height=$(hyprctl monitors -j 2>/dev/null | jq -r '.[0].height // empty')
  if [[ -n $width && -n $height ]] && command -v magick >/dev/null; then
    step "Fitting to ${width}x${height}"
    magick "$target.tmp" -resize "${width}x${height}^" -gravity center \
      -extent "${width}x${height}" -strip -define png:compression-level=6 "$target"
    rm -f "$target.tmp"
  else
    mv "$target.tmp" "$target"
  fi

  step "Installed $(basename "$target") ($(magick identify -format '%wx%h' "$target" 2>/dev/null || echo '?'))"
  ln -nsf "$target" "$CURRENT_BG"
  step "Applied as the current background"

  cat <<EOF

To keep it applied whenever the theme is set, nothing else is needed: the theme's
theme-set hook restores the current wallpaper for windows-xp automatically.

If you downloaded the image from the web, check its licence before publishing
your dotfiles with it included.
EOF
}

case "${1:-}" in
"" | --theme | --restore)
  restore
  ;;
-h | --help)
  sed -n '2,20p' "$0" | sed 's/^#\{1,2\} \{0,1\}//'
  ;;
*)
  set_wallpaper "$1"
  ;;
esac
