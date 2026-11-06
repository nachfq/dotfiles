"""Set Codex defaults for disposable agent environments, preserving local settings."""

import os
from pathlib import Path
import re
import shutil
import tempfile
import time
import tomllib


codex_home = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex")).expanduser()
config = codex_home / "config.toml"
source = config.read_text() if config.exists() else ""
before = tomllib.loads(source)
defaults = {"sandbox_mode": "danger-full-access", "approval_policy": "never"}

if all(before.get(key) == value for key, value in defaults.items()):
    print("Codex already defaults to full access without approval prompts.")
else:
    # Only edit root assignments; preserve tables, comments and hook trust records.
    lines = source.splitlines(keepends=True)
    boundary = next((i for i, line in enumerate(lines) if line.lstrip().startswith("[")), len(lines))
    root = [line for line in lines[:boundary]
            if not re.match(r"^\s*(sandbox_mode|approval_policy)\s*=", line)]
    updated = ('sandbox_mode = "danger-full-access"\n'
               'approval_policy = "never"\n\n' + "".join(root + lines[boundary:]))
    # Refuse to write if anything except the requested defaults would change.
    if tomllib.loads(updated) != before | defaults:
        raise SystemExit("Could not preserve this config layout; config.toml was not changed.")
    if config.exists():
        state = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
        backup = state / "dotfiles/backups" / f"codex-{time.time_ns()}"
        backup.mkdir(parents=True)
        shutil.copy2(config, backup / "config.toml")
        print(f"Backed up configuration to {backup / 'config.toml'}")
    codex_home.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=codex_home, delete=False) as output:
        temporary = Path(output.name)
        output.write(updated)
    try:
        temporary.replace(config)
    finally:
        temporary.unlink(missing_ok=True)
    print(f"Configured {config}: full access, no approval prompts. Restart Codex to apply.")
