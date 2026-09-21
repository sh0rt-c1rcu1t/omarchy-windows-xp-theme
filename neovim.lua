-- Omarchy installs this as the active Neovim colorscheme for the theme.
-- Omarchy ships LazyVim; "onedark" is one of its bundled schemes, so no extra
-- plugin download is needed. Swap in any scheme from :Telescope colorscheme.
return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "onedark",
    },
  },
}
