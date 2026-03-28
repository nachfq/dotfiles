vim.cmd("set expandtab")
vim.cmd("set tabstop=2")
vim.cmd("set softtabstop=2")
vim.cmd("set shiftwidth=2")

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.opt.termguicolors = true

vim.cmd.colorscheme("habamax")
vim.api.nvim_set_hl(0, "Normal", { bg = "NONE" })
vim.api.nvim_set_hl(0, "NormalFloat", { bg = "NONE" })
vim.api.nvim_set_hl(0, "NormalNC", { bg = "#24211E" })
vim.api.nvim_set_hl(0, "ActivePane", { bg = "NONE" })
vim.api.nvim_set_hl(0, "InactivePane", { bg = "#24211E" })
vim.api.nvim_set_hl(0, "WinSeparator", { fg = "#3A3531", bg = "NONE" })
vim.api.nvim_set_hl(0, "VertSplit", { fg = "#3A3531", bg = "NONE" })
vim.api.nvim_set_hl(0, "StatusLine", { fg = "#E6D8C3", bg = "#2A2724" })
vim.api.nvim_set_hl(0, "StatusLineNC", { fg = "#8C847A", bg = "#2A2724" })
vim.api.nvim_set_hl(0, "CursorLine", { bg = "#2A2724" })
vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#F2E9DC", bold = true })
vim.api.nvim_set_hl(0, "WinBar", { fg = "#8a8a8a", bg = "NONE" })
vim.api.nvim_set_hl(0, "WinBarNC", { fg = "#5a5a5a", bg = "NONE" })
vim.opt.laststatus = 3

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.clipboard = "unnamedplus"
vim.opt.autoread = true
vim.opt.updatetime = 200
vim.opt.cursorline = true
vim.opt.fillchars = { vert = "│", horiz = "─" }

local autoread_group = vim.api.nvim_create_augroup("ExternalFileAutoread", { clear = true })
local focus_group = vim.api.nvim_create_augroup("FocusedWindowCursorline", { clear = true })

local function refresh_window_focus()
  local current = vim.api.nvim_get_current_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win == current then
      vim.wo[win].cursorline = true
      vim.wo[win].winhighlight = "Normal:ActivePane,NormalNC:InactivePane"
    else
      vim.wo[win].cursorline = false
      vim.wo[win].winhighlight = "Normal:InactivePane,NormalNC:InactivePane"
    end
  end
end

vim.api.nvim_create_autocmd({ "VimEnter", "WinEnter", "BufEnter" }, {
  group = focus_group,
  callback = refresh_window_focus,
})

vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI", "TermClose", "TermLeave" }, {
  group = autoread_group,
  callback = function()
    if vim.fn.mode() ~= "c" then
      vim.cmd("silent! checktime")
    end
  end,
})

vim.api.nvim_create_autocmd("FileChangedShellPost", {
  group = autoread_group,
  callback = function()
    vim.notify("File reloaded from disk", vim.log.levels.INFO)
  end,
})
