#!/usr/bin/env bash
#
# Windows XP theme for Omarchy -- installer.
#
# Works on any Omarchy installation: it locates Omarchy at runtime instead of
# assuming a path, and every step is reversible with ./uninstall.sh.
#
#   ./install.sh                  install everything that needs no root
#   ./install.sh --all            also install the Tahoma font and square windows
#   ./install.sh --no-theme       skip applying the theme (install files only)
#   ./install.sh --fonts          install the Tahoma font files (needs root once)
#   ./install.sh --hyprland       square window corners, XP window gaps
#   ./install.sh --menu replace   replace omarchy-menu.jsonc (default)
#   ./install.sh --menu merge     merge into the existing menu extensions
#   ./install.sh --menu skip      leave the existing menu extensions alone
#
# What it installs, and where:
#
#   theme            ~/.config/omarchy/themes/windows-xp  -> a symlink to this repo
#   Start button     ~/.config/omarchy/plugins/windows-xp.start-button
#   Start menu       ~/.config/omarchy/plugins/windows-xp.start-menu
#   menu labels      ~/.config/omarchy/extensions/omarchy-menu.jsonc   (backed up)
#   sounds           ~/.local/share/sounds/windows-xp
#   hooks            ~/.config/omarchy/hooks/post-boot.d/ and theme-set.d/
#   bar layout       ~/.config/omarchy/shell.json                      (backed up)

set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
THEME_SLUG="windows-xp"
OMARCHY_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy"
OMARCHY_THEMES="$OMARCHY_CONFIG/themes"
OMARCHY_PLUGINS="$OMARCHY_CONFIG/plugins"
OMARCHY_HOOKS="$OMARCHY_CONFIG/hooks"
SOUND_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/sounds/windows-xp"

DO_THEME=1
DO_FONTS=0
DO_HYPRLAND=0
MENU_MODE="replace"

step() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m warn\033[0m %s\n' "$*" >&2; }
fail() {
  printf '\033[1;31merror\033[0m %s\n' "$*" >&2
  exit 1
}

parse_args() {
  while (( $# > 0 )); do
    case "$1" in
    --all)
      DO_FONTS=1
      DO_HYPRLAND=1
      shift
      ;;
    --no-theme)
      DO_THEME=0
      shift
      ;;
    --theme)
      DO_THEME=1
      shift
      ;;
    --fonts)
      DO_FONTS=1
      shift
      ;;
    --hyprland)
      DO_HYPRLAND=1
      shift
      ;;
    --menu)
      MENU_MODE="${2:-replace}"
      shift 2
      ;;
    -h | --help)
      sed -n '2,30p' "$0" | sed 's/^#\{1,2\} \{0,1\}//'
      exit 0
      ;;
    *)
      fail "unknown option: $1 (try --help)"
      ;;
    esac
  done

  case "$MENU_MODE" in
  replace | merge | skip) ;;
  *) fail "--menu takes replace, merge or skip" ;;
  esac
}

preflight() {
  command -v omarchy >/dev/null || warn "'omarchy' is not on PATH -- this does not look like an Omarchy system"
  [ -d "$OMARCHY_CONFIG" ] || fail "$OMARCHY_CONFIG is missing; Omarchy has not been set up for this user"

  if [ -n "${OMARCHY_PATH:-}" ] && [ -d "$OMARCHY_PATH" ]; then
    OMARCHY_DIR="$OMARCHY_PATH"
  elif [ -d /usr/share/omarchy ]; then
    OMARCHY_DIR=/usr/share/omarchy
  else
    OMARCHY_DIR=""
  fi

  if [ -n "$OMARCHY_DIR" ]; then
    step "Omarchy found at $OMARCHY_DIR"
  else
    warn "no Omarchy package directory found; reading defaults will be skipped"
  fi

  command -v jq >/dev/null || fail "jq is required (omarchy-pkg-add jq)"
}

install_theme() {
  step "Installing the theme into $OMARCHY_THEMES/$THEME_SLUG"
  mkdir -p "$OMARCHY_THEMES"

  target="$OMARCHY_THEMES/$THEME_SLUG"
  if [ -L "$target" ] || [ -e "$target" ]; then
    if [ -L "$target" ] && [ "$(readlink -f "$target")" = "$REPO_DIR" ]; then
      step "  already linked to this repository"
    else
      backup="$target.bak.$(date +%s)"
      mv "$target" "$backup"
      warn "  moved the existing theme aside to $backup"
    fi
  fi

  if [ ! -e "$target" ]; then
    # A symlink keeps `git pull` as the update path: no files to re-copy.
    ln -s "$REPO_DIR" "$target"
  fi
  step "  $target -> $REPO_DIR"
}

install_plugins() {
  step "Installing the Start button and Start menu shell plugins"
  mkdir -p "$OMARCHY_PLUGINS"

  for plugin in windows-xp.start-button windows-xp.start-menu; do
    source_dir="$REPO_DIR/plugins/$plugin"
    [ -d "$source_dir" ] || fail "missing plugin source: $source_dir"
    target_dir="$OMARCHY_PLUGINS/$plugin"

    mkdir -p "$target_dir"
    cp -f "$source_dir"/*.qml "$source_dir"/manifest.json "$target_dir/"
    step "  $plugin"
  done

  # The Start menu plugin reads its row definitions from its own directory.
  cp -f "$REPO_DIR/menu/xp-menu.json" "$OMARCHY_PLUGINS/windows-xp.start-menu/xp-menu.json"
  sed -i "s|@HOME@|$HOME|g" "$OMARCHY_PLUGINS/windows-xp.start-menu/xp-menu.json"
}

install_menu_extensions() {
  target="$OMARCHY_CONFIG/extensions/omarchy-menu.jsonc"
  source="$REPO_DIR/extensions/omarchy-menu.jsonc"

  if [ "$MENU_MODE" = "skip" ]; then
    step "Leaving $target alone (--menu skip)"
    return
  fi

  step "Installing the Windows XP menu extensions"
  mkdir -p "$(dirname "$target")"

  if [ -f "$target" ]; then
    backup="$target.bak.windows-xp.$(date +%s)"
    cp "$target" "$backup"
    step "  backed up the existing file to $backup"
  fi

  if [ "$MENU_MODE" = "merge" ] && [ -f "$target" ]; then
    # A shallow merge is what the shell does anyway, but doing it here keeps the
    # user's own rows in a file they can read.
    if jq -s '.[0] * .[1]' "$target" "$source" >"$target.merged" 2>/dev/null; then
      mv "$target.merged" "$target"
      step "  merged the XP labels into the existing extensions"
      return
    fi
    warn "  merge failed (the existing file may contain comments); replacing instead"
  fi

  {
    echo "// Installed by the Omarchy Windows XP theme."
    echo "// Backup of the previous file: ${backup:-none}"
    cat "$source"
  } >"$target"
  step "  installed $target"
}

install_action_scripts() {
  step "Installing the folder opener used by the Start menu rows"
  local bin_dir="$HOME/.local/bin"
  mkdir -p "$bin_dir"
  install -m 0755 "$REPO_DIR/scripts/omarchy-xp-open-folder" "$bin_dir/omarchy-xp-open-folder"
  step "  $bin_dir/omarchy-xp-open-folder"

  # The menu actions call it by bare name, so ~/.local/bin has to be on PATH.
  # Omarchy's own setup puts it there; say so when something else removed it.
  case ":$PATH:" in
  *":$bin_dir:"*) ;;
  *)
    warn "  $bin_dir is not on PATH; the folder menu rows will not resolve it"
    warn "  add this to your shell profile:  export PATH=\"\$HOME/.local/bin:\$PATH\""
    ;;
  esac
}

install_sounds() {
  step "Installing the Windows XP sound scheme"
  mkdir -p "$SOUND_DIR/stereo"
  cp -f "$REPO_DIR/sounds/index.theme" "$SOUND_DIR/"
  cp -f "$REPO_DIR/sounds"/*.oga "$SOUND_DIR/stereo/"
  step "  $SOUND_DIR ($(find "$SOUND_DIR/stereo" -name '*.oga' | wc -l) sounds)"

  if command -v gsettings >/dev/null 2>&1 &&
    gsettings writable org.gnome.desktop.sound theme >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.sound theme "windows-xp" 2>/dev/null &&
      step "  selected windows-xp as the GTK sound theme"
  fi
}

install_hooks() {
  step "Installing the startup and theme-set hooks"
  mkdir -p "$OMARCHY_HOOKS/post-boot.d" "$OMARCHY_HOOKS/theme-set.d"
  install -m 0755 "$REPO_DIR/omarchy/hooks/post-boot.d/windows-xp-startup-sound" \
    "$OMARCHY_HOOKS/post-boot.d/windows-xp-startup-sound"
  install -m 0755 "$REPO_DIR/omarchy/hooks/theme-set.d/windows-xp-theme-set" \
    "$OMARCHY_HOOKS/theme-set.d/windows-xp-theme-set"
  step "  $OMARCHY_HOOKS/post-boot.d/windows-xp-startup-sound"
  step "  $OMARCHY_HOOKS/theme-set.d/windows-xp-theme-set"
}

install_bar_layout() {
  step "Putting the Start button on the taskbar"
  bash "$REPO_DIR/scripts/install-shell.sh" --bar bottom
}

install_fonts() {
  step "Installing the Tahoma font"
  if fc-list 2>/dev/null | grep -qi "tahoma"; then
    step "  Tahoma is already installed"
    return
  fi

  if ! command -v yay >/dev/null 2>&1 && ! command -v paru >/dev/null 2>&1; then
    warn "  no AUR helper found; install 'ttf-tahoma' yourself for exact XP text metrics"
    warn "  the theme falls back to Liberation Sans, which is metric-compatible with Arial"
    return
  fi

  helper=$(command -v yay || command -v paru)
  cat <<EOF

  Tahoma is part of the AUR package 'ttf-tahoma'. Installing it needs root
  access once, and the password prompt appears in this terminal.

EOF
  if [ ! -t 0 ]; then
    warn "  no terminal attached; run this yourself:  $helper -S ttf-tahoma"
    return
  fi

  if "$helper" -S --needed --noconfirm ttf-tahoma; then
    step "  Tahoma installed"
    fc-cache -f >/dev/null 2>&1 || true
  else
    warn "  installing ttf-tahoma failed; the theme still works with the fallback font"
  fi
}

install_hyprland() {
  step "Applying square window corners and XP window gaps"
  target="$HOME/.config/hypr/looknfeel.lua"
  snippet="$REPO_DIR/omarchy/hypr/looknfeel-xp.lua"

  [ -f "$snippet" ] || fail "missing $snippet"

  if [ ! -f "$target" ]; then
    warn "  $target does not exist; skipping (run 'omarchy refresh hyprland' first)"
    return
  fi

  if grep -q "Windows XP theme (looknfeel-xp.lua)" "$target" 2>/dev/null; then
    step "  already applied"
    return
  fi

  backup="$target.bak.windows-xp.$(date +%s)"
  cp "$target" "$backup"
  {
    cat "$target"
    echo
    cat "$snippet"
  } >"$target.tmp"
  mv "$target.tmp" "$target"
  step "  appended to $target (backup: $backup)"
}

apply_theme() {
  step "Applying the theme"
  # Clear the first-run stamp so a fresh install sees the setup notice again.
  rm -f "${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/windows-xp-theme-applied"

  version=$(omarchy version 2>/dev/null || echo "?")
  step "  omarchy $version"

  if ! OMARCHY_THEME_SKIP_BACKGROUND=0 omarchy theme set "$THEME_SLUG"; then
    fail "omarchy theme set $THEME_SLUG failed"
  fi

  if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    hyprctl reload >/dev/null 2>&1 || true
  fi
}

restart_shell_now() {
  step "Restarting the Omarchy shell so the Start button and Start menu load"
  if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v omarchy-restart-shell >/dev/null 2>&1; then
    omarchy-restart-shell >/dev/null 2>&1 || warn "  'omarchy restart shell' failed; run it yourself"
  else
    warn "  no running Hyprland session detected; run 'omarchy restart shell' after logging in"
  fi
}

summary() {
  cat <<EOF

$(printf '\033[1;32mWindows XP theme installed.\033[0m')

  Theme        $(omarchy theme current 2>/dev/null || echo "$THEME_SLUG")
  Start button windows-xp.start-button   (left end of the taskbar)
  Start menu   windows-xp.start-menu     (opened by the Start button)
  Menu labels  $OMARCHY_CONFIG/extensions/omarchy-menu.jsonc
  Folder opener ~/.local/bin/omarchy-xp-open-folder
  Sounds       $SOUND_DIR

Try it:
  Click the green Start button, or press Super+Space for the XP menu.
  omarchy theme set windows-xp          re-apply the theme
  ./install.sh --fonts                  exact XP text metrics (needs root once)
  ./uninstall.sh                        undo everything

If this Omarchy version does not show the Start button, run:
  omarchy restart shell

EOF
}

main() {
  parse_args "$@"
  preflight
  install_theme
  install_plugins
  install_action_scripts
  install_menu_extensions
  install_sounds
  install_hooks
  install_bar_layout
  (( DO_FONTS )) && install_fonts
  (( DO_HYPRLAND )) && install_hyprland
  if (( DO_THEME )); then
    apply_theme
    restart_shell_now
  else
    step "Skipping 'omarchy theme set' (--no-theme)"
  fi
  summary
}

main "$@"
