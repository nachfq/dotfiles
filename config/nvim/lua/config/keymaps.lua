-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("n", "<leader>ghi", function()
  require("gitsigns").diffthis(nil, { unified = true })
end, { desc = "Toggle Inline Diff" })

require("config.herdr_navigation").setup()
require("config.worktrees").setup()
require("config.codex_bridge").setup()
