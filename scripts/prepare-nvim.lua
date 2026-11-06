-- Finish the configured downloads before the headless bootstrap exits.
local ok, err = xpcall(function()
  require("lazy").load({ plugins = { "mason.nvim", "nvim-treesitter" } })

  local registry = require("mason-registry")
  registry.refresh()
  local packages = LazyVim.opts("mason.nvim").ensure_installed or {}
  for _, name in ipairs(packages) do
    local package = registry.get_package(name)
    if not package:is_installed() and not package:is_installing() then
      package:install()
    end
  end
  assert(vim.wait(300000, function()
    for _, name in ipairs(packages) do
      if registry.get_package(name):is_installing() then
        return false
      end
    end
    return true
  end, 100), "Timed out installing Mason packages")
  for _, name in ipairs(packages) do
    assert(registry.get_package(name):is_installed(), "Mason installation failed: " .. name)
  end

  local treesitter = require("nvim-treesitter")
  local languages = LazyVim.opts("nvim-treesitter").ensure_installed or {}
  treesitter.install(languages):wait(300000)
  local installed = treesitter.get_installed()
  for _, language in ipairs(languages) do
    assert(vim.tbl_contains(installed, language), "Tree-sitter installation failed: " .. language)
  end
  print("Neovim plugins, configured Mason tools and parsers are ready.")
end, debug.traceback)

if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd("cquit 1")
end
