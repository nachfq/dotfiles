return {
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = function(_, opts)
      for _, ft in ipairs({ "markdown", "markdown.mdx" }) do
        opts.linters_by_ft[ft] = vim.tbl_filter(function(name)
          return name ~= "markdownlint-cli2"
        end, opts.linters_by_ft[ft] or {})
      end
    end,
  },
}
