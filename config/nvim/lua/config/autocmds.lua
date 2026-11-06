-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local function set_inline_diff_colors()
  -- Background-only highlights preserve syntax colors without reverse video.
  vim.api.nvim_set_hl(0, "GitSignsAddInline", { bg = "#304b38" })
  vim.api.nvim_set_hl(0, "GitSignsChangeInline", { bg = "#364563" })
  vim.api.nvim_set_hl(0, "GitSignsDeleteInline", { bg = "#58383e" })
end

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("custom_inline_diff_colors", { clear = true }),
  callback = set_inline_diff_colors,
})
set_inline_diff_colors()
