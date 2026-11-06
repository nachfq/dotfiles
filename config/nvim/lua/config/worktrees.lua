local M = {}
local pending = {}

local function git(path, ...)
  return vim.system({ "git", "-C", path, ... }, { text = true }):wait()
end

local function base_branch(path)
  local default = git(path, "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD")
  local name = vim.trim(default.stdout or ""):match("^origin/(.+)$")
  local candidates = {}
  if name == "main" or name == "master" then
    candidates[#candidates + 1] = "refs/heads/" .. name
    candidates[#candidates + 1] = "refs/remotes/origin/" .. name
  end
  vim.list_extend(candidates, {
    "refs/heads/main",
    "refs/heads/master",
    "refs/remotes/origin/main",
    "refs/remotes/origin/master",
  })
  for _, ref in ipairs(candidates) do
    if git(path, "show-ref", "--verify", "--quiet", ref).code == 0 then
      return ref
    end
  end
end

function M.show_inline()
  local review = vim.t.worktree_review
  local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
  if not review or vim.bo[buf].buftype ~= "" then
    return
  end
  local file = vim.api.nvim_buf_get_name(buf)
  if not vim.startswith(file, review.path .. "/") then
    return
  end
  local waiting = pending[win]
  if waiting and waiting.buf == buf and waiting.base == review.base then
    return
  end
  local gs = require("gitsigns")
  local unified = require("gitsigns.unified")
  if unified.get_view(win) and vim.w[win].worktree_review_base == review.base then
    return
  end
  local request = { buf = buf, base = review.base }
  pending[win] = request
  local relative = file:sub(#review.path + 2)
  vim.system({ "git", "-C", review.path, "show", review.base .. ":" .. relative }, {}, function(result)
    vim.schedule(function()
      if pending[win] ~= request then
        return
      end
      pending[win] = nil
      local current = vim.t.worktree_review
      if
        vim.api.nvim_get_current_win() ~= win
        or vim.api.nvim_get_current_buf() ~= buf
        or not current
        or current.path ~= review.path
        or current.base ~= review.base
      then
        return
      end
      if result.code ~= 0 and git(review.path, "cat-file", "-e", review.base).code ~= 0 then
        vim.notify("Could not read comparison branch", vim.log.levels.WARN)
        return
      end
      -- New files have an empty base; deleted files keep their old code as virtual lines.
      local lines = result.code == 0 and vim.split(result.stdout, "\n", { plain = true }) or {}
      if lines[#lines] == "" then
        table.remove(lines)
      end
      local base = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(base, 0, -1, false, lines)
      vim.bo[base].modifiable = false
      require("gitsigns.manager").setup()
      pending[win] = request
      require("gitsigns.async").run(function()
        unified.show(win, base, true, false)
      end):await(function(err)
        if pending[win] == request then
          pending[win] = nil
        end
        if not err and vim.api.nvim_win_is_valid(win) then
          vim.w[win].worktree_review_base = review.base
        end
      end)
      for key, direction in pairs({ ["]h"] = "next", ["[h"] = "prev" }) do
        vim.keymap.set("n", key, function()
          gs.nav_hunk(direction)
        end, { buffer = buf, desc = direction == "next" and "Next Hunk" or "Prev Hunk" })
      end
    end)
  end)
end

function M.pick()
  local result = vim.system({ "git", "worktree", "list", "--porcelain", "-z" }, {
    cwd = vim.fn.getcwd(),
  }):wait()
  if result.code ~= 0 then
    vim.notify(vim.trim(result.stderr or "Could not list worktrees"), vim.log.levels.WARN)
    return
  end

  local items = {}
  for _, record in ipairs(vim.split(result.stdout, "\0\0", { plain = true, trimempty = true })) do
    local item = {}
    for _, field in ipairs(vim.split(record, "\0", { plain = true, trimempty = true })) do
      if field:sub(1, 9) == "worktree " then
        item.path = field:sub(10)
      elseif field:sub(1, 18) == "branch refs/heads/" then
        item.branch = field:sub(19)
      elseif field == "bare" then
        item.bare = true
      end
    end
    if item.path and not item.bare then
      items[#items + 1] = item
    end
  end

  local tab = vim.api.nvim_get_current_tabpage()
  vim.ui.select(items, {
    prompt = "Choose worktree",
    format_item = function(item)
      return (item.branch or "(detached)") .. "  —  " .. item.path
    end,
  }, function(item)
    if not item or not vim.api.nvim_tabpage_is_valid(tab) then
      return
    end
    if vim.api.nvim_get_current_tabpage() ~= tab then
      return
    end
    if vim.fn.isdirectory(item.path) ~= 1 then
      vim.notify("Worktree directory is missing: " .. item.path, vim.log.levels.WARN)
      return
    end
    vim.cmd.tcd({ args = { item.path } })
    local base = base_branch(item.path)
    if not base then
      vim.t.worktree_review = nil
      vim.notify("No main or master branch found; opening the worktree without a comparison", vim.log.levels.WARN)
    else
      vim.t.worktree_review = { path = item.path, base = base }
      vim.notify("Reviewing changes against " .. base:gsub("^refs/heads/", ""):gsub("^refs/remotes/", ""))
    end
    require("neo-tree.command").execute({
      source = base and "git_status" or "filesystem",
      action = "focus",
      dir = item.path,
      git_base = base,
      reveal = false,
    })
  end)
end

function M.stop()
  local review = vim.t.worktree_review
  if not review then
    return
  end
  vim.t.worktree_review = nil
  local unified = require("gitsigns.unified")
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    pending[win] = nil
    unified.close(win)
    vim.w[win].worktree_review_base = nil
  end
  require("neo-tree.command").execute({
    source = "filesystem",
    action = "focus",
    dir = review.path,
    reveal = false,
  })
end

function M.setup()
  vim.keymap.set("n", "<leader>gr", M.pick, { desc = "Review worktree" })
  vim.keymap.set("n", "<leader>gR", M.stop, { desc = "Stop worktree review" })
  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = vim.api.nvim_create_augroup("WorktreeInlineReview", { clear = true }),
    callback = function()
      vim.schedule(M.show_inline)
    end,
  })
end

return M
