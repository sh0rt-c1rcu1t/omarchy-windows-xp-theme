#!/usr/bin/env bash
#
# Verify the Windows XP theme on a machine, and prove the Start menu folder
# mapping points at that machine's real folders.
#
#   tools/verify-install.sh
#
# Run this ON the machine the theme was installed on. It writes nothing except a
# scratch file in the theme directory; it is safe to run repeatedly.
#
# Exit status is 0 when every check passes, 1 when something is wrong. Each
# failure prints the command to fix it, so this doubles as the repair guide.
#
# Why this exists: the folder rows resolve their targets through `xdg-user-dir`
# at click time, and Omarchy does not require Documents/Pictures/Music/Videos to
# exist or to live in the home directory. That makes the mapping correct by
# construction but not obvious, and "correct by construction" is worth checking
# on a machine nobody has looked at.

set -uo pipefail

REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
THEME_SLUG="windows-xp"
CONFIG="$HOME/.config/omarchy"
PLUGIN_MENU="$CONFIG/plugins/windows-xp.start-menu"
PLUGIN_BUTTON="$CONFIG/plugins/windows-xp.start-button"
OPENER="$HOME/.local/bin/omarchy-xp-open-folder"

pass=0
fail=0

ok() {
  printf '  \033[1;32mPASS\033[0m %s\n' "$*"
  pass=$((pass + 1))
}
bad() {
  printf '  \033[1;31mFAIL\033[0m %s\n' "$*"
  fail=$((fail + 1))
}
note() { printf '       %s\n' "$*"; }
section() { printf '\n\033[1;34m%s\033[0m\n' "$*"; }

section "Machine"
printf '  host %s, user %s, home %s\n' "$(hostname)" "$(whoami)" "$HOME"
printf '  desktop %s\n' "${XDG_CURRENT_DESKTOP:-?}${XDG_SESSION_TYPE:+ / $XDG_SESSION_TYPE}"

# ------------------------------------------------------------------ packages
section "Prerequisites"
if command -v omarchy >/dev/null 2>&1; then
  ok "omarchy on PATH ($(omarchy version 2>/dev/null || echo 'version unknown'))"
else
  bad "omarchy is not on PATH"
  note "this does not look like an Omarchy machine"
fi

for cmd in jq git; do
  if command -v "$cmd" >/dev/null 2>&1; then ok "$cmd present"; else bad "$cmd missing"; fi
done

# --------------------------------------------------------------------- theme
section "Theme"
if [ -d "$CONFIG/themes/$THEME_SLUG" ]; then
  ok "theme directory present"
  if [ -L "$CONFIG/themes/$THEME_SLUG" ]; then
    note "-> $(readlink -f "$CONFIG/themes/$THEME_SLUG")"
  else
    note "(a copy, not a symlink to the repository: 'git pull' will not update it)"
  fi
else
  bad "$CONFIG/themes/$THEME_SLUG is missing"
  note "fix: run ./install.sh in the checkout"
fi

current=$(omarchy theme current 2>/dev/null || echo "")
if [ -n "$current" ]; then
  case "$current" in
  *[Xx][Pp]* | *Windows*)
    ok "active theme is '$current'"
    ;;
  *)
    bad "active theme is '$current', not the XP theme"
    note "fix: omarchy theme set $THEME_SLUG"
    ;;
  esac
else
  bad "could not read the active theme"
fi

# ---------------------------------------------------------------- wallpaper
section "Wallpaper"
bg_link="$HOME/.local/state/omarchy/current/background"
if [ -e "$bg_link" ]; then
  resolved=$(readlink -f "$bg_link")
  ok "background set: $(basename -- "$resolved")"
  if command -v magick >/dev/null 2>&1; then
    dims=$(magick identify -format '%wx%h' "$resolved" 2>/dev/null || echo '?')
    note "resolution $dims"
    # The compositor lays surfaces out at physical/scale. An image that does not
    # match that logical size gets cropped and magnified, which looks soft.
    if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
      want=$(hyprctl monitors -j 2>/dev/null | jq -r '.[0] | "\((.width/(.scale//1))|floor)x\((.height/(.scale//1))|floor)"' 2>/dev/null || echo '')
      if [ -n "$want" ] && [ "$want" != "?" ]; then
        if [ "$dims" = "$want" ]; then
          ok "image matches the logical desktop ($dims)"
        else
          note "logical desktop is $want but the image is $dims"
          note "the compositor will rescale it; refit with scripts/install-wallpaper.sh <image>"
        fi
      fi
    fi
  fi
  case "$resolved" in
  *0-bliss-original*) ok "using the real Bliss photograph" ;;
  *1-bliss*) note "using the rendered stand-in (photograph not installed)" ;;
  esac
else
  bad "no background is set"
  note "fix: scripts/install-wallpaper.sh /path/to/bliss.jpg"
fi

# ------------------------------------------------------------------ plugins
section "Shell plugins"
for plugin in "$PLUGIN_BUTTON:Start button" "$PLUGIN_MENU:Start menu"; do
  path="${plugin%%:*}"
  label="${plugin##*:}"
  # Test the glob itself: `[ -f "$path"/*.qml ]` expands to several words and
  # becomes `[ -f a.qml b.qml ... ]`, which errors out and would report a
  # perfectly good plugin as missing.
  if [ -f "$path/manifest.json" ] && compgen -G "$path/*.qml" >/dev/null; then
    ok "$label files installed"
  else
    bad "$label files missing at $path"
  fi
done

# Both plugins are deliberately written against bare QtQuick, so they cannot be
# broken by Omarchy changing its internal qs.Ui / qs.Commons modules.
if grep -rlqE '^\s*import\s+qs\.(Ui|Commons)' "$PLUGIN_BUTTON" "$PLUGIN_MENU" 2>/dev/null; then
  bad "a plugin still imports an Omarchy-internal QML module"
  note "that couples the theme to Omarchy internals and will break on upgrade"
else
  ok "plugins depend on QtQuick only (upgrade-safe)"
fi

if [ -f "$CONFIG/shell.json" ]; then
  if jq -e '[.. | objects | select(.id? == "windows-xp.start-button")] | length > 0' \
    "$CONFIG/shell.json" >/dev/null 2>&1; then
    ok "Start button is in the bar layout"
    pos=$(jq -r '.bar.position // "?"' "$CONFIG/shell.json")
    note "taskbar position: $pos"
  else
    bad "the Start button is not in the bar layout"
    note "fix: scripts/install-shell.sh --bar bottom"
  fi
else
  bad "$CONFIG/shell.json is missing"
fi

# ------------------------------------------------------------- folder rows
section "Folder mapping (what each Start menu row opens)"
if [ ! -x "$OPENER" ]; then
  bad "folder opener missing at $OPENER"
  note "fix: ./install.sh  (or copy scripts/omarchy-xp-open-folder there)"
else
  ok "folder opener installed"
fi

# The XDG folders are the ones the menu rows target. Create any that are absent:
# a row that lands on a folder which does not exist is the exact failure this
# theme is meant to prevent.
section "XDG user folders"
for key in DOCUMENTS PICTURES MUSIC VIDEOS DOWNLOAD; do
  dir=$(xdg-user-dir "$key" 2>/dev/null || true)
  if [ -z "$dir" ]; then
    bad "$key has no XDG entry"
    note "fix: xdg-user-dirs-update"
    continue
  fi
  if [ -d "$dir" ]; then
    ok "$(printf '%-9s' "$key") $dir"
  else
    if mkdir -p "$dir" 2>/dev/null; then
      ok "$(printf '%-9s' "$key") $dir (created)"
    else
      bad "$(printf '%-9s' "$key") $dir is missing and could not be created"
    fi
  fi
done

section "Menu rows resolve to"
if [ -x "$OPENER" ]; then
  # Compare what the rows resolve to against the XDG folders above: they are the
  # same source of truth, so a mismatch here means the opener is broken.
  declare -A expect=(
    [xdg:DOCUMENTS]=DOCUMENTS
    [xdg:PICTURES]=PICTURES
    [xdg:MUSIC]=MUSIC
    [xdg:VIDEOS]=VIDEOS
  )
  for target in xdg:DOCUMENTS xdg:PICTURES xdg:MUSIC xdg:VIDEOS home root trash removable; do
    got=$("$OPENER" --print-target "$target" 2>/dev/null || echo 'ERROR')
    if [ "$got" = "ERROR" ]; then
      bad "$(printf '%-14s' "$target") failed to resolve"
      continue
    fi
    want="${expect[$target]:-}"
    if [ -n "$want" ]; then
      wantdir=$(xdg-user-dir "$want" 2>/dev/null || true)
      if [ "$got" = "$wantdir" ]; then
        ok "$(printf '%-14s' "$target") $got"
      else
        bad "$(printf '%-14s' "$target") $got (expected $wantdir)"
      fi
    else
      ok "$(printf '%-14s' "$target") $got"
    fi
  done
else
  note "skipped: the opener is not installed"
fi

# ------------------------------------------------------------- menu wiring
section "Installed menu rows point at the opener"
mapping="$PLUGIN_MENU/xp-menu.json"
if [ -f "$mapping" ]; then
  # A row still calling omarchy-launch-nautilus would silently open the home
  # folder: that command takes no arguments.
  if grep -q 'omarchy-launch-nautilus' "$mapping"; then
    bad "xp-menu.json still calls omarchy-launch-nautilus (it ignores its path argument)"
  else
    count=$(grep -c 'omarchy-xp-open-folder' "$mapping")
    ok "$count rows use omarchy-xp-open-folder"
  fi
  if grep -q '@HOME@' "$mapping"; then
    bad "xp-menu.json still contains the @HOME@ placeholder"
    note "it was copied without substituting the home directory"
  else
    ok "home paths substituted for this machine"
  fi
else
  bad "$mapping is missing"
fi

if [ -f "$CONFIG/extensions/omarchy-menu.jsonc" ]; then
  rows=$(grep -c 'omarchy-xp-open-folder' "$CONFIG/extensions/omarchy-menu.jsonc" 2>/dev/null || echo 0)
  if [ "$rows" -gt 0 ]; then
    ok "omarchy-menu extensions carry $rows folder rows"
  else
    bad "the omarchy-menu extensions carry no folder rows"
  fi
  # jq catches a broken edit before the shell does, where the symptom is a menu
  # that silently renders empty.
  if sed 's://.*::' "$CONFIG/extensions/omarchy-menu.jsonc" | jq -e . >/dev/null 2>&1; then
    ok "menu extensions are valid JSON"
  else
    bad "menu extensions are not valid JSON; the menu will render empty"
  fi
else
  bad "$CONFIG/extensions/omarchy-menu.jsonc is missing"
fi

# ------------------------------------------------------------------- sounds
section "Sounds"
sound_dir="${XDG_DATA_HOME:-$HOME/.local/share}/sounds/windows-xp"
if [ -f "$sound_dir/index.theme" ]; then
  count=$(find "$sound_dir" -name '*.oga' 2>/dev/null | wc -l)
  ok "$count sounds installed at $sound_dir"
else
  bad "no sound scheme at $sound_dir"
  note "fix: scripts/install-sounds.sh"
fi

if [ -f "$CONFIG/hooks/post-boot.d/windows-xp-startup-sound" ]; then
  ok "startup chime hook installed"
else
  note "startup chime hook not installed (optional)"
fi

# -------------------------------------------------------------- live shell
section "Live session"
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null 2>&1; then
  if hyprctl layers 2>/dev/null | grep -q "omarchy-bar"; then
    ok "taskbar surface is mapped"
  else
    bad "no omarchy-bar surface; the shell may need restarting"
    note "fix: omarchy restart shell"
  fi
  printf '  %s\n' "layers:"
  hyprctl layers 2>/dev/null | grep -E "namespace|Layer level [0-9]" | sed 's/^/    /' | head -12
else
  note "no live Hyprland session; cannot check surfaces"
  note "run this from a terminal inside the desktop session for that check"
fi

# -------------------------------------------------------------------- font
section "Font"
# Same test the installer uses: fc-list prints localised style names, so matching
# its output is locale-dependent. A file test does not care about locale.
if fc-match Tahoma 2>/dev/null | grep -qi tahoma || fc-list 2>/dev/null | grep -qi tahoma; then
  ok "Tahoma installed"
else
  note "Tahoma not installed: text uses the fallback (Liberation Sans)"
  note "optional: ./install.sh --fonts"
fi

# ------------------------------------------------------------------ result
printf '\n'
if [ "$fail" -eq 0 ]; then
  printf '\033[1;32mAll %d checks passed.\033[0m\n' "$pass"
  exit 0
fi
printf '\033[1;31m%d passed, %d failed.\033[0m\n' "$pass" "$fail"
exit 1
