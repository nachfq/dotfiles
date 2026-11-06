local M = {}
local active
local helper = (vim.env.XDG_CONFIG_HOME or vim.fn.expand("~/.config")) .. "/herdr/helpers/font-zoom.py"

local function run(args)
  local command = { "python3", helper }
  vim.list_extend(command, args)
  local result = vim.system(command, { text = true }):wait(10000)
  if result.code ~= 0 then
    vim.notify("Font zoom: " .. vim.trim(result.stderr or ""), vim.log.levels.WARN)
    return
  end
  local ok, value = pcall(vim.json.decode, result.stdout)
  if ok then
    return value
  end
end

function M.restore()
  local target = active
  active = nil
  if target then
    run({ "leave", "--owner", target.owner, "--window", target.address, "--pid", tostring(target.pid) })
  end
end

function M.open(win, target)
  if win.opts.width == 0 or #vim.api.nvim_list_uis() == 0 or vim.fn.executable("hyprctl") == 0 then
    return
  end
  M.restore()
  local owner = ("%d-%d"):format(vim.fn.getpid(), win.win or 0)
  local args = { "enter", "--owner", owner }
  if target then
    vim.list_extend(args, { "--window", target.address, "--pid", tostring(target.pid) })
  end
  local state = run(args)
  if state and state.address then
    active = { address = state.address, pid = state.pid, owner = owner }
  end
end

function M.setup()
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("custom_zen_font", { clear = true }),
    callback = M.restore,
  })
end

return M
