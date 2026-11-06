-- Editor context for local MCP readers. Source text stays in this process;
-- readers use fixed RPC expressions over Neovim's existing local socket.
local M = {}
local latest, codex_pane_id
local limit = 60000

local function visual(mode)
  return mode == "v" or mode == "V" or mode == "\22"
end

local function remember(selection, force)
  if not force and latest and latest.buffer == selection.buffer and latest.changedtick == selection.changedtick
    and latest.mode == selection.mode and vim.deep_equal(latest.ranges, selection.ranges)
  then
    return
  end
  latest = vim.deepcopy(selection)
  local seconds, micros = vim.uv.gettimeofday()
  latest.captured_at = seconds + micros / 1000000
  if #latest.text > limit then
    latest.text = nil
    latest.too_large = true
  end
end

local function capture_positions(first, last, mode, force)
  local buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf)
  if vim.bo[buf].buftype ~= "" or file == "" or first[2] < 1 or last[2] < 1 then
    return nil, "Select code in a named file."
  end
  local selection = {
    file = file,
    buffer = buf,
    changedtick = vim.api.nvim_buf_get_changedtick(buf),
    start_line = math.min(first[2], last[2]),
    end_line = math.max(first[2], last[2]),
    mode = mode,
    text = table.concat(vim.fn.getregion(first, last, { type = mode }), "\n"),
    modified = vim.bo[buf].modified,
    ranges = {},
  }
  for _, segment in ipairs(vim.fn.getregionpos(first, last, { type = mode, eol = true })) do
    local start, finish = segment[1], segment[2]
    local line = vim.api.nvim_buf_get_lines(buf, start[2] - 1, start[2], false)[1]
    local start_col = math.min(#line, math.max(0, start[3] - 1))
    local end_col = math.min(#line, math.max(0, finish[3] - 1))
    end_col = math.min(#line, end_col + #vim.fn.strcharpart(line:sub(end_col + 1), 0, 1))
    selection.ranges[#selection.ranges + 1] = { start[2] - 1, start_col, end_col }
  end
  remember(selection, force)
  return selection
end

function M.capture(force)
  local mode = vim.fn.mode()
  if not visual(mode) then
    return nil, "Select code in Visual mode first."
  end
  return capture_positions(vim.fn.getpos("v"), vim.fn.getpos("."), mode, force)
end

local function source_changed()
  return latest and latest.buffer == vim.api.nvim_get_current_buf()
    and vim.api.nvim_buf_get_changedtick(latest.buffer) ~= latest.changedtick
end

local function refresh_live()
  if visual(vim.fn.mode()) and not source_changed() then
    M.capture()
  end
end

local function valid()
  return latest and vim.api.nvim_buf_is_loaded(latest.buffer)
    and vim.api.nvim_buf_get_name(latest.buffer) == latest.file
    and vim.api.nvim_buf_get_changedtick(latest.buffer) == latest.changedtick
end

function M.set_target(pane_id)
  codex_pane_id = pane_id
end

function M.metadata()
  refresh_live()
  return {
    editor_id = vim.v.servername,
    pid = vim.fn.getpid(),
    cwd = vim.fn.getcwd(),
    file = latest and latest.file or vim.api.nvim_buf_get_name(0),
    has_selection = not not (valid() and not latest.too_large and not latest.consumed),
    selected_at = latest and latest.captured_at or nil,
    codex_pane_id = codex_pane_id,
    herdr_pane_id = vim.env.HERDR_PANE_ID,
    herdr_socket_path = vim.env.HERDR_SOCKET_PATH,
  }
end

-- Non-consuming inspection for local diagnostics. Only get_selection is
-- exposed to MCP; a successful tool read consumes this selection once.
function M.peek_selection()
  refresh_live()
  if not latest or latest.consumed then
    return { status = "no_selection", message = "No new selection. Select text again, or continue discussing the previous result." }
  end
  if not valid() then
    return { status = "stale", message = "The source changed or unloaded. Select the paragraph again." }
  end
  if latest.too_large then
    return { status = "selection_too_large", message = "Select a smaller fragment (60 KB maximum)." }
  end
  return {
    status = "ok",
    editor_id = vim.v.servername,
    selection = {
      file = latest.file, start_line = latest.start_line, end_line = latest.end_line,
      text = latest.text, mode = latest.mode, ranges = vim.deepcopy(latest.ranges),
      modified = vim.bo[latest.buffer].modified, captured_at = latest.captured_at,
    },
  }
end

function M.get_selection()
  local result = M.peek_selection()
  if result.status == "ok" then
    latest.consumed = true
    latest.text = nil
  end
  return result
end

function M.setup()
  if vim.v.servername == "" then
    pcall(vim.fn.serverstart) -- Local Unix socket, not a TCP listener.
  end
  local group = vim.api.nvim_create_augroup("HerdrCodexSelectionContext", { clear = true })
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = group,
    callback = refresh_live,
  })
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = group,
    callback = function()
      local before, after = vim.v.event.old_mode, vim.v.event.new_mode
      if visual(after) then
        -- Starting Visual again is a new selection even for an identical range.
        M.capture(true)
      elseif visual(before) and not source_changed() then
        -- Visual operators can mutate text before this event fires. Keep the
        -- pre-operator snapshot stale instead of reading post-edit positions.
        capture_positions(vim.fn.getpos("'<"), vim.fn.getpos("'>"), before)
      end
    end,
  })
end

return M
