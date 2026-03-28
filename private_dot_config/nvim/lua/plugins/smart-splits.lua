return {
  {
    "mrjones2014/smart-splits.nvim",
    lazy = false,
    config = function()
      local smart_splits = require("smart-splits")

      smart_splits.setup({
        ignored_filetypes = { "neo-tree", "NvimTree" },
      })

      vim.keymap.set("n", "<C-h>", smart_splits.move_cursor_left, { desc = "move to left split" })
      vim.keymap.set("n", "<C-j>", smart_splits.move_cursor_down, { desc = "move to below split" })
      vim.keymap.set("n", "<C-k>", smart_splits.move_cursor_up, { desc = "move to upper split" })
      vim.keymap.set("n", "<C-l>", smart_splits.move_cursor_right, { desc = "move to right split" })

      vim.keymap.set("n", "<M-h>", smart_splits.resize_left, { desc = "resize split left" })
      vim.keymap.set("n", "<M-j>", smart_splits.resize_down, { desc = "resize split down" })
      vim.keymap.set("n", "<M-k>", smart_splits.resize_up, { desc = "resize split up" })
      vim.keymap.set("n", "<M-l>", smart_splits.resize_right, { desc = "resize split right" })
    end,
  },
}
