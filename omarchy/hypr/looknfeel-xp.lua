# Windows XP window decoration for Omarchy.
#
# Appended to ~/.config/hypr/looknfeel.lua by the theme's install.sh, which
# backs the original file up first. Delete the block below and reload Hyprland
# (`hyprctl reload`) to go back to the Omarchy defaults.

-- Windows XP theme (looknfeel-xp.lua) --------------------------------------
-- XP has square window corners, a 3px blue frame on the focused window, a
-- grey frame on the rest, and no gaps between tiled windows.
hl.config({
  general = {
    gaps_in = 2,
    gaps_out = 4,
    border_size = 3,
    resize_on_border = false,

    col = {
      -- #0054e3 is the Luna title bar blue.
      active_border = { colors = { "rgba(0054e3ee)", "rgba(3f8cf3ee)" }, angle = 90 },
      inactive_border = "rgba(7ba2e7aa)",
    },
  },

  decoration = {
    rounding = 0,
    active_opacity = 1.0,
    inactive_opacity = 1.0,

    shadow = {
      enabled = true,
      range = 12,
      render_power = 3,
      color = "rgba(0a1a3aaa)",
    },

    blur = {
      enabled = false,
    },
  },

  animations = {
    enabled = true,
  },
})
