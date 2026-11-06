local M = {}

local directions = { h = "left", j = "down", k = "up", l = "right" }

local function is_terminal_float()
  return vim.bo.buftype == "terminal" and vim.api.nvim_win_get_config(0).relative ~= ""
end

local function is_zen_window()
  local zen = package.loaded["snacks.zen"]
  return zen and zen.win and zen.win.win == vim.api.nvim_get_current_win()
end

function M.navigate(key)
  local current = vim.api.nvim_get_current_win()
  -- Keep terminal and Zen overlays open when leaving the editor via Herdr.
  if not is_terminal_float() and not is_zen_window() then
    vim.cmd("wincmd " .. key)
  end
  if vim.api.nvim_get_current_win() ~= current or not vim.env.HERDR_PANE_ID then
    return
  end

  -- Target this editor's pane explicitly, even if another client has focus.
  vim.system({
    vim.env.HERDR_BIN_PATH or "herdr",
    "pane",
    "focus",
    "--pane",
    vim.env.HERDR_PANE_ID,
    "--direction",
    directions[key],
  }, { text = true }, function(result)
    if result.code ~= 0 then
      vim.schedule(function()
        vim.notify("Herdr navigation failed: " .. vim.trim(result.stderr or ""), vim.log.levels.WARN)
      end)
    end
  end)
end

function M.setup()
  if not vim.env.HERDR_PANE_ID then
    return
  end
  for key, direction in pairs(directions) do
    local navigation_key = key
    vim.keymap.set({ "n", "t" }, "<C-" .. key .. ">", function()
      if vim.api.nvim_get_mode().mode == "t" and not is_terminal_float() then
        vim.cmd.stopinsert()
        vim.schedule(function()
          M.navigate(navigation_key)
        end)
      else
        M.navigate(navigation_key)
      end
    end, { desc = "Navigate Neovim/Herdr " .. direction })
  end
end

return M
