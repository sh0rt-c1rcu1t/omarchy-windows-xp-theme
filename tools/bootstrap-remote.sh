#!/usr/bin/env bash
#
# One-shot installer for a *second* Omarchy machine.
#
# Run this ON the target machine (manny-aio), not over SSH from here:
#
#   curl -fsSL https://raw.githubusercontent.com/sh0rt-c1rcu1t/omarchy-windows-xp-theme/master/tools/bootstrap-remote.sh | bash
#
# or, if you already cloned the repository there:
#
#   ./tools/bootstrap-remote.sh
#
# It clones the theme if it is not already present, installs it, and then prints
# what the Start menu rows resolve to *on that machine* -- which is the part that
# differs from one computer to the next, because Omarchy does not require
# Documents, Pictures, Music and Videos to exist or to live in the home
# directory. The menu rows resolve their targets through `xdg-user-dir` at click
# time, so they follow that machine's real folders automatically; this script
# reports what they will open so it can be checked rather than assumed.

set -euo pipefail

REPO_URL="https://github.com/sh0rt-c1rcu1t/omarchy-windows-xp-theme.git"
REPO_DIR="${REPO_DIR:-$HOME/omarchy-windows-xp-theme}"

step() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m warn\033[0m %s\n' "$*" >&2; }
fail() {
  printf '\033[1;31merror\033[0m %s\n' "$*" >&2
  exit 1
}

# ---------------------------------------------------------------- preflight
[[ $EUID -ne 0 ]] || fail "run this as your normal user, not with sudo"

command -v omarchy >/dev/null || warn "'omarchy' is not on PATH; is this an Omarchy machine?"
[[ -d "$HOME/.config/omarchy" ]] || fail "$HOME/.config/omarchy is missing; set Omarchy up first"
command -v git >/dev/null || fail "git is required"
command -v jq >/dev/null || fail "jq is required"

step "Target: $(hostname) as $(whoami), home $HOME"

# ------------------------------------------------------------------- clone
if [[ -d $REPO_DIR/.git ]]; then
  step "Updating the existing checkout in $REPO_DIR"
  git -C "$REPO_DIR" pull --ff-only
elif [[ -f ./install.sh && -d ./plugins ]]; then
  REPO_DIR=$(pwd)
  step "Using the checkout at $REPO_DIR"
else
  step "Cloning into $REPO_DIR"
  git clone --depth 1 "$REPO_URL" "$REPO_DIR"
fi

[[ -x $REPO_DIR/install.sh ]] || fail "$REPO_DIR/install.sh is missing or not executable"

# ----------------------------------------------------------------- install
# No --fonts or --hyprland here: both change system state beyond the theme, and
# on a fresh machine they are worth doing deliberately. Pass them through if the
# caller asked: bootstrap-remote.sh --all
step "Running install.sh ${*:-}"
"$REPO_DIR/install.sh" "$@"

# ----------------------------------------------------- verify the mapping
step "Folder targets on $(hostname)"
printf '  %-14s %s\n' "documents" "$(xdg-user-dir DOCUMENTS 2>/dev/null || echo "$HOME/Documents")"
printf '  %-14s %s\n' "pictures" "$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
printf '  %-14s %s\n' "music" "$(xdg-user-dir MUSIC 2>/dev/null || echo "$HOME/Music")"
printf '  %-14s %s\n' "videos" "$(xdg-user-dir VIDEOS 2>/dev/null || echo "$HOME/Videos")"
printf '  %-14s %s\n' "downloads" "$(xdg-user-dir DOWNLOAD 2>/dev/null || echo "$HOME/Downloads")"

# Create any that are missing, because a Start menu row that lands on a
# non-existent folder is exactly the failure this theme exists to avoid.
for entry in DOCUMENTS PICTURES MUSIC VIDEOS; do
  dir=$(xdg-user-dir "$entry" 2>/dev/null || true)
  [[ -n $dir ]] || continue
  if [[ ! -d $dir ]]; then
    mkdir -p "$dir" && step "  created $dir"
  fi
done

# ------------------------------------------------------------ sanity check
opener="$HOME/.local/bin/omarchy-xp-open-folder"
if [[ -x $opener ]]; then
  step "Folder opener resolves to:"
  for target in xdg:DOCUMENTS xdg:PICTURES xdg:MUSIC xdg:VIDEOS home root; do
    printf '  %-16s %s\n' "$target" "$("$opener" --print-target "$target" 2>/dev/null || echo '?')"
  done
else
  warn "$opener is missing; the folder rows will not work"
fi

cat <<EOF

$(printf '\033[1;32mDone on %s.\033[0m' "$(hostname)")

  Log out and back in (or run: omarchy restart shell) so the Start button and
  Start menu plugins are picked up, then click the green start button.

  The Bliss photograph is not in the repository. Add it on this machine with:
    $REPO_DIR/scripts/install-wallpaper.sh /path/to/bliss.jpg

EOF
