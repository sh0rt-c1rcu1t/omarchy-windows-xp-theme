# Windows XP theme for Omarchy

A complete Windows XP ("Luna" blue) desktop for [Omarchy](https://omarchy.org/):
the Bliss wallpaper, the blue taskbar with its green **start** button, the
two-column Start menu with every Windows XP label wired to the matching place on
a Linux system, the XP sound scheme, and Tahoma-based metrics.

It installs onto **any** Omarchy installation. Nothing is hard-coded to one
machine: the installer finds Omarchy at runtime, and every menu row resolves to
a folder or command that exists on a stock Omarchy system.

```
  ┌──────────────────────────────────────────────────────────────────────┐
  │ [start]  ▫ ▫ ▫ ▫ ▫                    ⏰ 12:34 PM   🔈  🌐  🔋       │ ← taskbar
  └──────────────────────────────────────────────────────────────────────┘
      ┌────────────────────────────────────────────┐
      │ ██  ant                                    │ ← blue header
      ├──────────────────────┬─────────────────────┤
      │ Internet             │ My Documents        │
      │ E-mail               │ My Recent Documents │
      │ [Search programs   ] │ My Pictures         │
      │ ──────────────────── │ My Music            │
      │ My Pictures          │ My Computer         │
      │ My Music             │ My Network Places   │
      │ My Computer      ▸   │ Control Panel       │
      │ Control Panel    ▸   │ Help and Support    │
      │ Help and Support     │ Search              │
      │ Search               │ Run...              │
      │ Run...               │                     │
      ├──────────────────────┴─────────────────────┤
      │                    Log Off   Turn Off Comp │ ← blue footer
      └────────────────────────────────────────────┘
```

## Install

```bash
git clone https://github.com/<you>/omarchy-windows-xp-theme.git
cd omarchy-windows-xp-theme
./install.sh
```

`install.sh` applies the theme and restarts the Omarchy shell. Everything is
reversible with `./uninstall.sh`.

Useful flags:

| Flag | Effect |
|---|---|
| *(none)* | Install everything that needs no root access |
| `--fonts` | Also install Tahoma from the AUR (one root prompt) |
| `--hyprland` | Square window corners, XP window gaps and blue borders |
| `--all` | `--fonts` + `--hyprland` |
| `--no-theme` | Install the files without switching the active theme |
| `--menu replace\|merge\|skip` | How to handle an existing `omarchy-menu.jsonc` |
| `--bar top` | Keep the taskbar at the top of the screen |

Then click the green **start** button, or press <kbd>Super</kbd>+<kbd>Space</kbd>.

## What gets installed

| Piece | Destination |
|---|---|
| Theme (palette, shell styling, wallpapers, previews) | `~/.config/omarchy/themes/windows-xp` — a symlink to this repo, so `git pull` is the update path |
| Start button bar widget | `~/.config/omarchy/plugins/windows-xp.start-button` |
| XP Start menu | `~/.config/omarchy/plugins/windows-xp.start-menu` |
| XP labels for the Omarchy menu | `~/.config/omarchy/extensions/omarchy-menu.jsonc` (the previous file is backed up) |
| Sound scheme | `~/.local/share/sounds/windows-xp` |
| Startup and theme-set hooks | `~/.config/omarchy/hooks/post-boot.d/`, `theme-set.d/` |
| Taskbar layout (bottom bar, Start button first) | `~/.config/omarchy/shell.json` (backed up) |

## The Start menu

Two surfaces are installed, and both speak Windows XP.

**The Start button** opens `windows-xp.start-menu`, a purpose-built surface that
reproduces the XP Start menu: the blue header with your account name, the white
left column, the pale blue right column, the blue footer, and the *Turn off
computer* dialog with its Stand By / Turn Off / Restart buttons.

**The Omarchy menu** (<kbd>Super</kbd>+<kbd>Space</kbd> and every other
`omarchy-menu` binding) keeps all of its functionality but is relabelled:
*All Programs*, *Control Panel*, *Appearance and Themes*, *Windows Update*,
*Turn Off Computer*, and so on.

### What each Windows XP label opens

| Windows XP | Opens |
|---|---|
| All Programs | The application list (`/usr/share/applications`) |
| Internet | `omarchy-launch-browser` — your default browser |
| E-mail | A webmail web app |
| My Documents | `~/Documents` |
| My Pictures | `~/Pictures` |
| My Music | `~/Music` |
| My Videos | `~/Videos` |
| My Recent Documents | The Omarchy clipboard history |
| My Computer → Local Disk (C:) | `/` |
| My Computer → Local Disk (D:) | `$HOME` |
| My Computer → Devices with Removable Storage | `/run/media/$USER` |
| My Computer → Shared Documents | `~/Public` |
| My Computer → Recycle Bin | The file manager's trash |
| My Computer → View System Information | `omarchy-launch-about` |
| My Network Places | Wi-Fi, Bluetooth, Tailscale and LocalSend panels |
| Control Panel | The Omarchy Setup menu |
| ↳ Appearance and Themes | Theme / background / font pickers |
| ↳ Display | `~/.config/hypr/monitors.lua` |
| ↳ Sounds and Audio Devices | The Omarchy audio panel |
| ↳ Network Connections | The Omarchy network panel |
| ↳ Power Options | The Omarchy power panel |
| ↳ Keyboard | `~/.config/hypr/input.lua` |
| ↳ User Accounts | The passwordless-sudo setup dialog |
| ↳ Add or Remove Programs | The Omarchy package installer |
| ↳ System | `omarchy-launch-about` |
| Help and Support | The Omarchy manual |
| Search | The Omarchy application menu |
| Run... | A shell |
| Log Off | `omarchy-system-logout` |
| Turn Off Computer | The XP power dialog: Stand By, Turn Off, Restart |
| Windows Update | `omarchy update` |
| System Properties | `omarchy-launch-about` |

The rows live in `menu/xp-menu.json` for the XP Start menu and
`extensions/omarchy-menu.jsonc` for the Omarchy menu. Both are plain JSON with
comments: add a row, edit an action, and the Start menu picks it up the next time
it opens.

## Wallpaper

`backgrounds/` holds five wallpapers generated procedurally by
`tools/generate-wallpapers.py` — a rolling green hill under a blue sky, plus Azul,
Autumn, Red Moon Desert and Wind in the same spirit. They are original
renderings, not copies of Microsoft's photographs.

```bash
python3 tools/generate-wallpapers.py backgrounds   # regenerate
omarchy theme bg next                              # cycle them
```

## Sounds

`tools/generate-sounds.py` synthesises twenty sounds covering the classic XP
events — the startup chime, the shutdown phrase, the logon and logoff tones,
the notification bell, error and warning figures, device insert and remove, and
battery alarms.

They are synthesised rather than copied because Windows XP's `.wav` files are
Microsoft's copyrighted material. If you own a Windows XP installation you can
use the real ones instead:

```bash
tools/fetch-xp-sounds.sh /path/to/WINDOWS/Media --install
```

The startup chime plays once per login through a `post-boot` hook.

## Fonts

Windows XP draws its interface in **Tahoma** at 8pt. Tahoma is Microsoft's, so
this repository does not ship it; the theme falls back to Liberation Sans, which
is metric-compatible with Arial and close enough that the Start menu and taskbar
keep their proportions.

For exact XP text, install Tahoma once:

```bash
./install.sh --fonts          # uses yay/paru for the AUR package ttf-tahoma
```

## Updating

```bash
cd omarchy-windows-xp-theme && git pull
./install.sh --no-theme
```

`--no-theme` re-copies the shell plugins and menu rows without re-applying the
theme, which is what you want after a plugin or label change.

## Uninstalling

```bash
./uninstall.sh                 # remove everything, keep the active theme
./uninstall.sh --switch-theme "Tokyo Night"
```

`install.sh` backs up every file it touches
(`omarchy-menu.jsonc.bak.windows-xp.*`, `shell.json.bak.windows-xp.*`,
`looknfeel.lua.bak.windows-xp.*`); `uninstall.sh` prints the list at the end so
you can restore whichever you want.

## How it is put together

Omarchy has no window-decoration theming API, so this theme uses every surface
the shell exposes:

- **`colors.toml`** — the Luna palette, including the taskbar blues.
- **`shell.toml`** — the shell's per-surface styling. This is where the taskbar
  height (30px, the XP metric), the taskbar blue, the white Start menu body, the
  navy selection bar, the XP dialog greys and the spacing scale come from.
- **A bar widget plugin** — the green Start button, because a 100×30 Luna
  lozenge is not expressible as a bar token.
- **A menu plugin** — the XP Start menu, because the generic Omarchy menu is a
  single-column hierarchical command menu and XP's is a fixed two-column layout.
- **Menu extensions** — the XP labels on every Omarchy route, so keyboard
  bindings and `omarchy menu summon <route>` keep working.
- **Hooks** — the login chime and the first-run notification.

Two Omarchy behaviours are worth knowing if you modify this:

1. A third-party **full-bar** replacement plugin (one that declares
   `kinds: ["bar"]`) is only mounted at shell start, so this theme styles the
   built-in bar rather than replacing it.
2. A `keepLoaded: true` plugin is not hot-reloaded when its code changes; edit
   `windows-xp.start-menu` and restart the shell (`omarchy restart shell`) to see
   the change. The flag is deliberately omitted here so edits reload live.

## Requirements

- Omarchy 4.x (tested on 4.0.3)
- `jq`, and `python3` + `numpy` only if you regenerate the wallpapers
- `ffmpeg` only if you regenerate or re-encode sounds

## Licence

The theme's own files — wallpapers, sounds, QML, scripts, configuration — are
MIT licensed. See [LICENSE](LICENSE).

"Windows XP", "Tahoma" and the Windows flag are trademarks of Microsoft
Corporation. This project is not affiliated with or endorsed by Microsoft, ships
no Microsoft files, and is intended for personal theming of a Linux desktop.
