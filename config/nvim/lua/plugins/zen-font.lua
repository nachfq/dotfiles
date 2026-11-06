return {
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      local font = require("config.zen_font")
      font.setup()
      opts.zen = opts.zen or {}
      opts.zen.on_open = font.open
      opts.zen.on_close = font.restore
    end,
  },
}
