-- Let the shared Neovim/Herdr mappings handle Snacks terminal navigation.
-- LazyVim's buffer-local mappings otherwise take precedence over them.
if not vim.env.HERDR_PANE_ID then
  return {}
end

return {
  "folke/snacks.nvim",
  opts = {
    terminal = {
      win = {
        keys = {
          nav_h = false,
          nav_j = false,
          nav_k = false,
          nav_l = false,
        },
      },
    },
  },
}
