return {
  { "mason-org/mason.nvim", opts = {} },
  {
    "mason-org/mason-lspconfig.nvim",
    opts = {
      ensure_installed = {
        -- core
        "lua_ls",
        "rust_analyzer",
        "ts_ls",        -- JS/TS
        "solidity_ls",  -- Solidity
        "pyright", -- Python
        -- common project files
        "jsonls",
        "yamlls",
        "bashls",
        "dockerls",
        "docker_compose_language_service",
        "html",
        "cssls",
        "marksman",     -- Markdown
      },
    },
    dependencies = {
      "mason-org/mason.nvim",
      "neovim/nvim-lspconfig",
    },
  },
  {
    "neovim/nvim-lspconfig",
    config = function()
      -- Lua
      vim.lsp.config("lua_ls", {
        settings = {
          Lua = { diagnostics = { globals = { "vim" } } },
        },
      })

      -- Rust
      vim.lsp.config("rust_analyzer", {})

      -- TypeScript / JavaScript
      vim.lsp.config("ts_ls", {})

      -- Python
      vim.lsp.config("pyright", {})

      -- Solidity
      vim.lsp.config("solidity_ls", {})

      -- JSON / YAML
      vim.lsp.config("jsonls", {})
      vim.lsp.config("yamlls", {filetypes = { "yaml" } })

      -- Shell
      vim.lsp.config("bashls", {})

      -- Docker
      vim.lsp.config("dockerls", {})
      vim.lsp.config("docker_compose_language_service", {})

      -- Web
      vim.lsp.config("html", {})
      vim.lsp.config("cssls", {})

      -- Markdown
      vim.lsp.config("marksman", {filetypes = { "markdown" }})

      -- Enable all
      vim.lsp.enable({
        "lua_ls",
        "rust_analyzer",
        "ts_ls",
        "pyright",
        "solidity_ls",
        "jsonls",
        "yamlls",
        "bashls",
        "dockerls",
        "docker_compose_language_service",
        "html",
        "cssls",
        "marksman",
      })
      vim.diagnostic.config({
        virtual_text = {
          prefix = "●", -- o "▎" o nada
          spacing = 2,
          source = false,
          format = function(diagnostic)
            return diagnostic.message:gsub("\n", " ")
          end,
        },
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
      })


      -- Bindings
      vim.keymap.set("n", 'K', vim.lsp.buf.hover, {})
      vim.keymap.set("n", 'gd', vim.lsp.buf.definition, {})
      vim.keymap.set("n", '<leader>ca', vim.lsp.buf.code_action, {})
    end,
  }
}
