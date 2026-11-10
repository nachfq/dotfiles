"""Exercise the real Neovim request card with a model-free Herdr double."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
LUA = r'''
vim.opt.runtimepath:prepend(vim.env.DOTFILES_TEST_ROOT .. "/config/nvim")
local bridge = require("config.codex_bridge")
local rule = string.rep("─", 80)
local function pi_editor(body)
  return table.concat({ "Previous answer", rule, body, rule,
    "~/project (main) • example", "↑2k 1.0%/272k (auto)     any-model • high" }, "\n")
end
local codex_empty = "› Ask Codex to do anything\n  GPT-6.1 high · ~/project\n  ? for shortcuts"
assert(bridge.composer_state(pi_editor(""), "pi") == "empty")
assert(bridge.composer_state(pi_editor("Already typed\nanother line"), "pi") == "draft")
assert(bridge.composer_state(pi_editor("enter submit  esc cancel"), "pi") == nil)
assert(bridge.composer_state("Unrecognized layout", "pi") == nil)
assert(bridge.composer_state(codex_empty, "codex") == "empty")
assert(bridge.composer_state("› Existing input\n GPT-6.1 high", "codex") == "draft")
assert(bridge.composer_state("Allow this tool?", "codex") == nil)

local kind, status, pid, screen, failure = "pi", "idle", 100, pi_editor(""), false
local sent, notices = {}, {}
vim.notify = function(text) notices[#notices + 1] = text end
local function agent(harness)
  return { agent = harness, agent_status = status, interactive_ready = true,
    pane_id = harness, terminal_id = "terminal-" .. harness,
    workspace_id = "workspace", tab_id = "tab", name = "example" }
end
vim.ui.select = function(options, _, callback)
  assert(#options == 2)
  for _, option in ipairs(options) do
    assert(option.bridge_label:find("[" .. option.agent .. "]", 1, true))
    if option.agent == kind then callback(option); return end
  end
  error("Destination missing")
end
vim.system = function(argv)
  local result
  if argv[2] == "agent" and argv[3] == "list" then
    result = { agents = { agent("pi"), agent("codex") } }
  elseif argv[2] == "workspace" then
    result = { workspaces = { { workspace_id = "workspace" } } }
  elseif argv[2] == "tab" then
    result = { tabs = { { tab_id = "tab" } } }
  elseif argv[2] == "agent" and argv[3] == "get" then
    result = { agent = agent(argv[4]) }
  elseif argv[3] == "process-info" then
    result = { process_info = { foreground_processes = { { name = kind, pid = pid } } } }
  elseif argv[3] == "read" then
    return { wait = function() return { code = 0, stdout = screen } end }
  elseif argv[3] == "prompt" or argv[3] == "send-text" then
    sent[#sent + 1] = argv
    return { wait = function() return { code = failure and 1 or 0, stdout = "", stderr = "Test failure" } end }
  else
    error("Unexpected Herdr operation")
  end
  return { wait = function() return { code = 0, stdout = vim.json.encode({ result = result }) } end }
end

local function request(harness, composer, feedback)
  kind, status, pid, screen, failure = harness, "idle", 100, composer, false
  sent, notices = {}, {}
  bridge.choose()
  bridge.compose({ file = "/tmp/example.py", start_line = 2, end_line = 3,
    text = "print('literal $(false)')\n# unsaved", modified = true, mode = "V" })
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { feedback or "Explain this fragment" })
  return buf
end

for _, harness in ipairs({ "pi", "codex" }) do
  request(harness, harness == "pi" and pi_editor("") or codex_empty)
  bridge.transfer(true)
  assert(#sent == 1 and sent[1][2] == "agent" and sent[1][3] == "prompt")
  assert(sent[1][4] == harness)
  assert(sent[1][5]:find("literal $(false)", 1, true))
  assert(sent[1][5]:find("unsaved buffer changes", 1, true))

  request(harness, harness == "pi" and pi_editor("Existing draft") or "› Existing draft\n GPT-6.1 high")
  bridge.transfer(false)
  assert(#sent == 1 and sent[1][3] == "send-text")
  assert(sent[1][5]:sub(1, 8) == "\27[200~\n\n")
  assert(sent[1][5]:sub(-6) == "\27[201~")

  local buf = request(harness, harness == "pi" and pi_editor("") or codex_empty)
  status = "working"
  bridge.transfer(true)
  assert(#sent == 0 and vim.api.nvim_buf_is_valid(buf))
  bridge.discard()

  request(harness, harness == "pi" and pi_editor("") or codex_empty)
  pid = 101
  bridge.transfer(true)
  assert(#sent == 0)
  bridge.discard()

  request(harness, "Unknown dialog")
  bridge.transfer(true)
  assert(#sent == 0)
  bridge.discard()

  request(harness, harness == "pi" and pi_editor("") or codex_empty, "Unsafe\27text")
  bridge.transfer(true)
  assert(#sent == 0)
  bridge.discard()

  request(harness, harness == "pi" and pi_editor("") or codex_empty)
  failure = true
  bridge.transfer(true)
  bridge.transfer(true)
  assert(#sent == 1) -- Uncertain delivery cannot be retried from the same card.
  bridge.discard()
end
print("Pi/Codex request-card checks passed")
'''


@unittest.skipUnless(shutil.which("nvim"), "requires Neovim")
class HerdrAgentBridgeTest(unittest.TestCase):
    def test_pi_and_codex_selection_send_stage_and_safety_guards(self):
        with tempfile.TemporaryDirectory() as temporary:
            script = Path(temporary) / "bridge.lua"
            script.write_text(LUA)
            result = subprocess.run(
                ["nvim", "--headless", "-u", "NONE", "-l", str(script)],
                env=os.environ | {"DOTFILES_TEST_ROOT": str(ROOT)},
                capture_output=True, text=True, timeout=20,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
