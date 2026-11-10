local M = {}
local target, draft
local context = require("herdr-codex.context")
local shared_ns = vim.api.nvim_create_namespace("herdr_codex_shared_numbers")

local function paint_shared(buf)
  vim.api.nvim_buf_clear_namespace(buf, shared_ns, 0, -1)
  for _, range in ipairs(vim.b[buf].herdr_codex_number_ranges or {}) do
    vim.api.nvim_buf_set_extmark(buf, shared_ns, range[1], range[2], {
      end_row = range[1], end_col = range[3], number_hl_group = "CodexBridgeSharedNumber", priority = 140,
    })
  end
end

local function observe_selection(selection)
  if not selection or not selection.buffer or not selection.ranges then
    return
  end
  local buf = selection.buffer
  if not vim.api.nvim_buf_is_loaded(buf)
    or vim.api.nvim_buf_get_name(buf) ~= selection.file
    or vim.api.nvim_buf_get_changedtick(buf) ~= selection.changedtick
  then
    return -- The request contains the old snapshot, not the edited source.
  end
  local ranges = vim.b[buf].herdr_codex_number_ranges or {}
  for _, range in ipairs(selection.ranges) do
    local exists = false
    for _, previous in ipairs(ranges) do
      if vim.deep_equal(previous, range) then
        exists = true
        break
      end
    end
    if not exists then
      ranges[#ranges + 1] = range
    end
  end
  vim.b[buf].herdr_codex_number_ranges = ranges
  vim.b[buf].herdr_codex_number_content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  paint_shared(buf)
  if vim.b[buf].herdr_codex_number_watch then
    return
  end
  local function content_changed()
    local before = vim.b[buf].herdr_codex_number_content
    if not before then
      return
    end
    local after = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    if not vim.deep_equal(before, after) then
      vim.api.nvim_buf_clear_namespace(buf, shared_ns, 0, -1)
      vim.b[buf].herdr_codex_number_content = nil
      vim.b[buf].herdr_codex_number_ranges = nil
    else
      -- Nvim can adjust extmarks after calling a reload/line callback, even
      -- when identical text was written. Restore only after that adjustment.
      vim.schedule(function()
        if vim.api.nvim_buf_is_loaded(buf) and vim.b[buf].herdr_codex_number_content
          and vim.deep_equal(vim.b[buf].herdr_codex_number_content, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
        then
          paint_shared(buf)
        end
      end)
    end
  end
  local attach
  attach = function()
    if vim.b[buf].herdr_codex_number_watch then
      return
    end
    vim.b[buf].herdr_codex_number_watch = vim.api.nvim_buf_attach(buf, false, {
      on_lines = content_changed,
      on_reload = function()
        vim.schedule(function()
          if vim.api.nvim_buf_is_loaded(buf) then
            content_changed()
          end
        end)
      end,
      on_detach = function()
        if not vim.api.nvim_buf_is_valid(buf) then
          return
        end
        vim.b[buf].herdr_codex_number_watch = nil
        -- :edit! can unload and reload the same buffer rather than report
        -- on_reload. Check the final contents, then reattach if still marked.
        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(buf) then
            return
          end
          if vim.api.nvim_buf_is_loaded(buf) then
            content_changed()
            if vim.b[buf].herdr_codex_number_content then
              attach()
            end
          else
            vim.api.nvim_buf_clear_namespace(buf, shared_ns, 0, -1)
            vim.b[buf].herdr_codex_number_content = nil
            vim.b[buf].herdr_codex_number_ranges = nil
          end
        end)
      end,
    })
  end
  attach()
end

local function warn(message)
  vim.notify(message, vim.log.levels.WARN, { title = "Agents / Herdr" })
end

-- Use argv throughout: selected code and dictated text must never reach a shell.
local function call(args, raw)
  local argv = { vim.env.HERDR_BIN_PATH or "herdr" }
  vim.list_extend(argv, args)
  local result = vim.system(argv, { text = true, timeout = 4000 }):wait()
  if result.code ~= 0 then
    error(vim.trim(result.stderr or "") ~= "" and vim.trim(result.stderr) or "Herdr did not respond")
  end
  if raw then
    return result.stdout or ""
  end
  local response = vim.json.decode(result.stdout)
  if response.error or not response.result then
    error(response.error and response.error.message or "Invalid Herdr response")
  end
  return response.result
end

local function attempt(fn)
  local ok, result = pcall(fn)
  if not ok then
    warn(tostring(result):gsub("^.-:%d+: ", ""))
    return
  end
  return result
end

local function session(agent)
  local info = agent.agent_session
  return type(info) == "table" and info.kind .. ":" .. info.value or nil
end

local function identity(agent)
  if not agent or (agent.agent ~= "codex" and agent.agent ~= "pi") then
    error("This pane no longer contains Pi or Codex. Choose a destination again.")
  end
  local info = call({ "pane", "process-info", "--pane", agent.pane_id }).process_info
  local pids = {}
  for _, process in ipairs(info.foreground_processes or {}) do
    if process.name == agent.agent or process.name:match("^" .. agent.agent .. "%-") then
      pids[#pids + 1] = tostring(process.pid)
    end
  end
  if #pids == 0 then
    error("The agent is not in the foreground in this pane.")
  end
  table.sort(pids)
  return { harness = agent.agent, terminal = agent.terminal_id, pids = table.concat(pids, ","), session = session(agent) }
end

local function validate(chosen)
  local agent = call({ "agent", "get", chosen.pane_id }).agent
  local now = identity(agent)
  if not vim.deep_equal(now, chosen.identity) then
    error("The agent process or session changed. Press Ctrl+c to choose it again.")
  end
  if agent.agent_status ~= "idle" and agent.agent_status ~= "done" then
    error("The agent is busy or awaiting input. Your request is still here.")
  end
  if agent.interactive_ready == false then
    error("The agent is not ready to receive text yet.")
  end
  return agent
end

function M.choose(after)
  local finished = false
  local function complete(linked)
    if finished then
      return
    end
    finished = true
    if after then
      after(linked)
    end
  end
  local opened = attempt(function()
    local agents = call({ "agent", "list" }).agents or {}
    local workspaces = call({ "workspace", "list" }).workspaces or {}
    local labels, tabs, options = {}, {}, {}
    for _, workspace in ipairs(workspaces) do
      labels[workspace.workspace_id] = workspace.label or workspace.workspace_id
    end
    for _, agent in ipairs(agents) do
      if agent.agent == "codex" or agent.agent == "pi" then
        if not tabs[agent.workspace_id] then
          tabs[agent.workspace_id] = {}
          for _, tab in ipairs(call({ "tab", "list", "--workspace", agent.workspace_id }).tabs or {}) do
            tabs[agent.workspace_id][tab.tab_id] = tab.label or tab.tab_id
          end
        end
        agent.bridge_label = table.concat({
          labels[agent.workspace_id] or agent.workspace_id,
          tabs[agent.workspace_id][agent.tab_id] or agent.tab_id,
          agent.name or agent.terminal_title_stripped or agent.agent,
          "[" .. agent.agent .. "]",
          agent.pane_id,
        }, " → ")
        options[#options + 1] = agent
      end
    end
    if #options == 0 then
      error("Herdr found no running Pi or Codex agents.")
    end
    table.sort(options, function(a, b)
      local a_local = a.workspace_id == vim.env.HERDR_WORKSPACE_ID
      local b_local = b.workspace_id == vim.env.HERDR_WORKSPACE_ID
      if a_local ~= b_local then
        return a_local
      end
      return a.bridge_label < b.bridge_label
    end)
    vim.ui.select(options, {
      prompt = "Link this Neovim to Pi or Codex",
      format_item = function(item)
        return item.bridge_label .. " [" .. item.agent_status .. "]"
      end,
    }, function(agent)
      if not agent then
        complete(false)
        return
      end
      local linked = attempt(function()
        -- Resolve again after the picker: the occupant may have changed meanwhile.
        local live = call({ "agent", "get", agent.pane_id }).agent
        target = { pane_id = agent.pane_id, label = agent.bridge_label, identity = identity(live) }
        context.set_target(target.pane_id)
        vim.g.codex_bridge_target = target.label
        return true
      end)
      if linked and not after then
        vim.notify("Linked to agent: " .. target.label)
      end
      complete(linked == true)
    end)
    return true
  end)
  if not opened then
    complete(false)
  end
end

-- Capture before opening any picker, and use getregion to preserve UTF-8,
-- backwards, linewise and rectangular selections without touching registers.
function M.capture()
  local captured, message = context.capture()
  if not captured then
    error(message)
  end
  vim.cmd.normal({ args = { vim.keycode("<Esc>") }, bang = true })
  return captured
end

-- Herdr has no structured draft API. Recognize the main composer by its
-- prompt and footer; allow existing input so successive selections accumulate.
-- Never clear or replace that input, and reject unrecognized dialogs/layouts.
function M.composer_state(text, harness)
  if harness == "pi" then
    local lines = vim.split(text, "\n", { plain = true })
    local function border(line)
      local value = vim.trim(line):gsub(" ↑ %d+ more ", ""):gsub(" ↓ %d+ more ", "")
      return #value >= 24 and value:gsub("─", "") == ""
    end
    -- Pi's normal editor is bounded by horizontal rules immediately above
    -- its cwd/context footer. Fail closed for dialogs or unknown/custom editors.
    for bottom = #lines - 2, 2, -1 do
      local stats = lines[bottom + 2]
      if border(lines[bottom]) and lines[bottom + 1]:match("^[~/]")
        and (stats:match("[%d%.]+%%/[%d%.]+") or stats:match("%?/[%d%.]+"))
      then
        local content = false
        for row = bottom - 1, 1, -1 do
          if border(lines[row]) then
            return content and "draft" or "empty"
          end
          local line = vim.trim(lines[row])
          local lower = line:lower()
          if lower:match("esc.*cancel") or lower:match("ctrl%+c.*cancel") then
            return nil
          end
          content = content or line ~= ""
        end
        return nil
      end
    end
    return nil
  end
  local prompt
  local extra, model_footer = false, false
  for line in (text .. "\n"):gmatch("(.-)\n") do
    local content = line:match("^%s*›%s?(.*)$")
    if content then
      prompt = vim.trim(content)
      extra, model_footer = false, false
    elseif prompt and vim.trim(line) ~= "" then
      if line:find("GPT%-") then
        model_footer = true
      elseif not line:find("for shortcuts", 1, true) then
        extra = true
      end
    end
  end
  local placeholders = {
    ["Ask Codex to do anything"] = true,
    ["Explain this codebase"] = true,
    ["Summarize recent commits"] = true,
    ["Implement {feature}"] = true,
    ["Find and fix a bug in @filename"] = true,
    ["Write tests for @filename"] = true,
    ["Improve documentation in @filename"] = true,
    ["Use /skills to list available skills"] = true,
  }
  -- Codex hides the shortcuts row while a large pasted chunk is in its draft.
  if not prompt or not model_footer then
    return nil
  end
  return ((placeholders[prompt] or prompt == "") and not extra) and "empty" or "draft"
end

function M.empty_composer(text, harness)
  return M.composer_state(text, harness) == "empty"
end

function M.message(selection, instruction)
  if not selection then
    return instruction
  end
  -- A longer fence also handles selected Markdown containing triple backticks.
  local fence = "```"
  while selection.text:find(fence, 1, true) do
    fence = fence .. "`"
  end
  local source = string.format("File: %s\nLines: %d–%d", selection.file, selection.start_line, selection.end_line)
  if selection.mode == "\22" then
    source = source .. "\nBlock selection: only the columns included below."
  end
  if selection.modified then
    source = source .. "\nSelection contains unsaved buffer changes; the file on disk may differ."
  end
  return table.concat({ instruction, "", source, "", fence, selection.text, fence }, "\n")
end

local function hide(request)
  request = request or draft
  if not request then
    return
  end
  vim.cmd.stopinsert()
  request.closing = true
  for _, win in ipairs({ request.win or -1, request.panel or -1 }) do
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  request.win, request.panel = nil, nil
  request.closing = false
end

function M.transfer(submit)
  if not draft or draft.sending or draft.picking then
    return
  end
  attempt(function()
    local request = draft
    if request.uncertain then
      error("The previous transfer was not confirmed. Check the agent and close this request before trying again.")
    end
    local instruction = vim.trim(table.concat(vim.api.nvim_buf_get_lines(request.buf, 0, -1, false), "\n"))
    if instruction == "" then
      error("Write or dictate feedback before transferring it.")
    end
    if not target then
      M.connect(true, submit)
      return
    end
    if not target or not vim.deep_equal(target, request.target) then
      error("The destination changed. Press Ctrl+c to reconnect this request.")
    end
    validate(request.target)
    local screen = call({ "pane", "read", request.target.pane_id, "--source", "detection", "--lines", "100" }, true)
    local composer = M.composer_state(screen, request.target.identity.harness)
    if not composer then
      error("Could not recognize the agent composer. Check it; your request is still here.")
    end
    local text = M.message(request.selection, instruction):gsub("\r\n", "\n")
    if composer == "draft" then
      text = "\n\n" .. text
    end
    if text:find("[%z\1-\8\11-\31\127]") then
      error("The request contains terminal control characters. Remove them before transferring.")
    end
    if #text > 60000 then
      error("The selection is too large (60 KB limit). Select a smaller fragment.")
    end
    request.sending = true
    local command
    if submit then
      -- Herdr's agent prompt API appends a paste and Enter in order. Do not
      -- focus the target or wait for the agent to finish its response.
      command = { "agent", "prompt", request.target.pane_id, text }
    else
      -- send-text is raw bytes and succeeds silently. Wrap all newlines in
      -- bracketed paste, accept the exit status, and do not submit Enter.
      command = { "pane", "send-text", request.target.pane_id, "\27[200~" .. text .. "\27[201~" }
    end
    local ok, err = pcall(call, command, true)
    if not ok then
      -- Delivery failures can be ambiguous. Do not permit an accidental retry.
      request.sending = false
      request.uncertain = true
      error("Herdr did not confirm delivery. Check the agent before trying again: " .. tostring(err))
    end
    request.delivered = true
    -- Highlighting is best-effort after delivery; never turn a successful
    -- transfer into a retryable error because a source buffer disappeared.
    pcall(observe_selection, request.selection)
    hide()
    draft = nil
    vim.api.nvim_buf_delete(request.buf, { force = true })
    vim.notify(submit and "Sent to agent." or "Added to the agent draft. Enter sends the next comment and the full draft.")
  end)
end

local placeholder_ns = vim.api.nvim_create_namespace("codex_bridge_placeholder")
local header_ns = vim.api.nvim_create_namespace("codex_bridge_header")

local function fit(text, width)
  if vim.fn.strdisplaywidth(text) <= width then
    return text
  end
  local length = vim.fn.strchars(text)
  for keep = math.max(0, width - 1), 0, -1 do
    local left = math.ceil(keep / 2)
    local shortened = vim.fn.strcharpart(text, 0, left) .. "…"
      .. vim.fn.strcharpart(text, length - (keep - left))
    if vim.fn.strdisplaywidth(shortened) <= width then
      return shortened
    end
  end
  return ""
end

local function footer(request)
  return " Enter Send · Ctrl+s Stage · Shift+Enter New line · Ctrl+c " .. (request.target and "Change" or "Connect") .. " · Ctrl+q Close "
end

local function destination(request, width)
  return "  To      " .. fit(request.target and request.target.label or "Not connected · choose Pi or Codex", width)
end

local function show()
  if not draft then
    return
  end
  if draft.win and vim.api.nvim_win_is_valid(draft.win) then
    vim.api.nvim_set_current_win(draft.win)
    return
  end
  local request = draft
  local width = math.max(8, math.min(96, vim.o.columns - 6))
  local height = math.max(6, math.min(16, vim.o.lines - 6))
  local selection = request.selection
  local location = "Message only · no code selection"
  if selection then
    location = vim.fn.fnamemodify(selection.file, ":~:.")
      .. string.format(":%d–%d", selection.start_line, selection.end_line)
    if selection.modified then
      location = location .. "  ·  unsaved"
    end
  end
  local panel_buf = vim.api.nvim_create_buf(false, true)
  request.panel_buf = panel_buf
  vim.bo[panel_buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(panel_buf, 0, -1, false, {
    destination(request, math.max(1, width - 12)),
    "  Source  " .. fit(location, math.max(1, width - 12)),
    "",
    "  " .. string.rep("─", math.max(1, width - 4)),
  })
  vim.bo[panel_buf].modifiable = false
  for row = 0, 1 do
    vim.api.nvim_buf_set_extmark(panel_buf, header_ns, row, 2, {
      end_col = 8, hl_group = "CodexBridgeLabel",
    })
  end
  vim.api.nvim_buf_set_extmark(panel_buf, header_ns, 1, 10, {
    end_col = #vim.api.nvim_buf_get_lines(panel_buf, 1, 2, false)[1], hl_group = "Directory",
  })
  vim.api.nvim_buf_set_extmark(panel_buf, header_ns, 3, 0, {
    line_hl_group = "CodexBridgeLabel",
  })
  request.panel = vim.api.nvim_open_win(panel_buf, false, {
    relative = "editor", style = "minimal", border = "rounded", focusable = false,
    width = width, height = height,
    row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    title = " AGENT · " .. (selection and "Selection feedback" or "Message") .. " ", title_pos = "center", zindex = 60,
    footer = footer(request), footer_pos = "center",
  })
  request.win = vim.api.nvim_open_win(request.buf, true, {
    relative = "win", win = request.panel, style = "minimal", border = "none",
    row = 4, col = 2, width = math.max(1, width - 4), height = math.max(1, height - 5), zindex = 61,
  })
  for _, win in ipairs({ request.panel, request.win }) do
    vim.wo[win].winhighlight = "Normal:NormalFloat,FloatBorder:CodexBridgeBorder"
    vim.wo[win].winbar = ""
    vim.wo[win].spell = false
    vim.wo[win].colorcolumn = ""
  end
  vim.wo[request.panel].wrap = false
  vim.wo[request.win].wrap = true
  vim.wo[request.win].linebreak = true
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(request.win), once = true,
    callback = function()
      if request.closing then
        return
      end
      vim.schedule(function()
        if draft == request then
          M.discard()
        end
      end)
    end,
  })
  vim.cmd.startinsert()
end

function M.refresh()
  if not draft then
    return
  end
  if draft.panel and vim.api.nvim_win_is_valid(draft.panel) then
    local width = vim.api.nvim_win_get_width(draft.panel)
    local previous = vim.api.nvim_buf_get_lines(draft.panel_buf, 0, 1, false)[1]
    local updated = destination(draft, math.max(1, width - 12))
    vim.bo[draft.panel_buf].modifiable = true
    vim.api.nvim_buf_set_text(draft.panel_buf, 0, 10, 0, #previous, { updated:sub(11) })
    vim.bo[draft.panel_buf].modifiable = false
    vim.api.nvim_win_set_config(draft.panel, { footer = footer(draft), footer_pos = "center" })
  end
  if draft.win and vim.api.nvim_win_is_valid(draft.win) then
    vim.api.nvim_set_current_win(draft.win)
    vim.cmd.startinsert()
  end
end

function M.connect(send_after, submit)
  if not draft or draft.sending or draft.picking then
    return
  end
  local request = draft
  request.picking = true
  M.choose(function(linked)
    request.picking = false
    if draft ~= request or not vim.api.nvim_buf_is_valid(request.buf) then
      return
    end
    if linked then
      request.target = vim.deepcopy(target)
    end
    M.refresh()
    if linked and send_after then
      M.transfer(submit)
    end
  end)
end

local function configure_request(buf)
  vim.bo[buf].filetype = "codex_request"
  vim.bo[buf].textwidth = 0
  vim.bo[buf].formatoptions = ""
  vim.bo[buf].autoindent = false
  vim.b[buf].completion = false -- Blink's documented per-buffer disable switch.
  local blink = package.loaded["blink.cmp"]
  if vim.api.nvim_get_current_buf() == buf and blink and blink.hide then
    blink.hide()
  end
  for _, key in ipairs({ "<CR>", "<C-s>" }) do
    local submit = key == "<CR>"
    vim.keymap.set({ "n", "i" }, key, function()
      M.transfer(submit)
    end, { buffer = buf, desc = submit and "Send comment and draft to agent" or "Stage comment in agent draft" })
  end
  -- Non-recursive RHS: insert a real newline without invoking the Enter map.
  vim.keymap.set("i", "<S-CR>", "<CR>", { buffer = buf, desc = "Insert a new line" })
  vim.keymap.set("n", "<S-CR>", "o", { buffer = buf, desc = "Insert a new line" })
  vim.keymap.set({ "n", "i" }, "<C-c>", function()
    M.connect(false)
  end, { buffer = buf, desc = "Change agent connection" })
  vim.keymap.set({ "n", "i" }, "<C-q>", M.discard, { buffer = buf, desc = "Close request" })
  vim.keymap.set("n", "q", M.discard, { buffer = buf, desc = "Close request" })
  local function placeholder()
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    vim.api.nvim_buf_clear_namespace(buf, placeholder_ns, 0, -1)
    local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "")
    if text == "" then
      vim.api.nvim_buf_set_extmark(buf, placeholder_ns, 0, 0, {
        virt_text = { { "Write or dictate your feedback…", "Comment" } }, virt_text_pos = "overlay",
      })
    end
  end
  placeholder()
  if not vim.b[buf].codex_bridge_placeholder then
    vim.b[buf].codex_bridge_placeholder = true
    vim.api.nvim_buf_attach(buf, false, {
      on_lines = function()
        vim.schedule(placeholder)
      end,
    })
  end
end

function M.compose(selection)
  -- A new selection is a new piece of feedback, never a retained old request.
  if selection and draft then
    M.discard()
  end
  if draft and vim.api.nvim_buf_is_valid(draft.buf) then
    show()
    return
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  draft = { buf = buf, selection = selection, target = vim.deepcopy(target) }
  configure_request(buf)
  show()
end

function M.discard()
  local request = draft
  draft = nil
  hide(request)
  if request and vim.api.nvim_buf_is_valid(request.buf) then
    vim.api.nvim_buf_delete(request.buf, { force = true })
  end
end

function M.setup()
  context.setup()
  context.set_target(target and target.pane_id)
  if vim.env.HERDR_ENV ~= "1" or not vim.env.HERDR_PANE_ID then
    return
  end
  vim.api.nvim_set_hl(0, "CodexBridgeBorder", { default = true, link = "DiagnosticInfo" })
  vim.api.nvim_set_hl(0, "CodexBridgeLabel", { default = true, link = "Comment" })
  local function shared_highlight()
    vim.api.nvim_set_hl(0, "CodexBridgeSharedNumber", { default = true, fg = 0x7aa2f7, bold = true })
  end
  shared_highlight()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("HerdrCodexSharedHighlight", { clear = true }),
    callback = shared_highlight,
  })
  -- Retire the old underline observers by clearing their separate state.
  -- Their callbacks become inert; their marks migrate without losing history.
  local old_ns = vim.api.nvim_create_namespace("herdr_codex_shared")
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local ranges = vim.b[buf].herdr_codex_shared_ranges
      local content = vim.b[buf].herdr_codex_shared_content
      vim.b[buf].herdr_codex_shared_ranges = nil
      vim.b[buf].herdr_codex_shared_content = nil
      vim.api.nvim_buf_clear_namespace(buf, old_ns, 0, -1)
      if ranges and content and vim.deep_equal(content, vim.api.nvim_buf_get_lines(buf, 0, -1, false)) then
        observe_selection({ buffer = buf, file = vim.api.nvim_buf_get_name(buf),
          changedtick = vim.api.nvim_buf_get_changedtick(buf), ranges = ranges })
      elseif vim.b[buf].herdr_codex_number_ranges then
        paint_shared(buf)
      end
    end
  end
  -- Refresh already open request windows during a live configuration update.
  if draft and vim.api.nvim_buf_is_valid(draft.buf) then
    configure_request(draft.buf)
    if draft.win and vim.api.nvim_win_is_valid(draft.win) then
      hide()
      show()
    end
  end
  -- Remove only this module's old prefix mappings during live upgrades.
  for _, mode in ipairs({ "n", "x" }) do
    for _, key in ipairs({ "<leader>ac", "<leader>as", "<leader>ad" }) do
      local mapping = vim.fn.maparg(key, mode, false, true)
      if mapping.desc and mapping.desc:match("^Codex:") then
        vim.keymap.del(mode, key)
      end
    end
  end
  vim.keymap.set("x", "<leader>a", function()
    attempt(function()
      M.compose(M.capture())
    end)
  end, { desc = "Agent: comment on selection", nowait = true })
  vim.keymap.set("n", "<leader>a", function()
    M.compose()
  end, { desc = "Agent: write feedback", nowait = true })
end

return M
