#!/usr/bin/env python3
"""Share one reversible Foot font zoom between Herdr and Neovim Zen mode."""

import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import subprocess
import sys

STEPS = 3  # Foot's default font-size increment is 0.5 points.


def hypr(*args):
    result = subprocess.run(
        ["hyprctl", *args], capture_output=True, text=True, timeout=2, check=True
    )
    return result.stdout.strip()


def find_window(address=None, pid=None):
    if address:
        clients = json.loads(hypr("-j", "clients"))
        return next(
            (c for c in clients if c["address"] == address
             and c["pid"] == pid and c["class"] == "foot"), None
        )
    window = json.loads(hypr("-j", "activewindow"))
    if window.get("class") != "foot":
        raise RuntimeError("Font zoom requires a focused Foot window")
    return window


def resize(window, key):
    action = 'hl.dsp.send_shortcut({ mods = "CTRL", key = %s, window = %s })' % (
        json.dumps(key), json.dumps("address:" + window["address"])
    )
    if hypr("dispatch", action) != "ok":
        raise RuntimeError("Foot did not accept the font shortcut")


def set_zoom(state, window, enabled):
    if state["zoomed"] == enabled:
        return
    key, rollback = ("equal", "minus") if enabled else ("minus", "equal")
    applied = 0
    try:
        for _ in range(STEPS):
            resize(window, key)
            applied += 1
    except Exception:
        for _ in range(applied):
            resize(window, rollback)
        raise
    state["zoomed"] = enabled


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("toggle", "enter", "leave", "status"))
    parser.add_argument("--owner")
    parser.add_argument("--window")
    parser.add_argument("--pid", type=int)
    args = parser.parse_args()
    if args.action in ("enter", "leave") and not args.owner:
        parser.error("Zen enter/leave requires --owner")
    if bool(args.window) != (args.pid is not None):
        parser.error("--window and --pid must be provided together")
    if args.action == "leave" and not args.window:
        parser.error("Zen leave requires the original --window and --pid")

    window = find_window(args.window, args.pid)
    if window is None:
        print(json.dumps({"closed": True}))
        return
    address = window["address"]
    if not re.fullmatch(r"0x[0-9a-fA-F]+", address):
        raise RuntimeError("Invalid terminal window address")

    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
    directory = runtime / "herdr-font-zoom"
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    state_path = directory / f'{window["pid"]}-{address}.json'
    with state_path.with_suffix(".lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        state = {"zoomed": False, "mode": "manual", "owners": []}
        if state_path.exists():
            state = json.loads(state_path.read_text())

        if args.action == "toggle":
            set_zoom(state, window, not state["zoomed"])
            # A manual decision supersedes any earlier automatic Zen ownership.
            state.update(mode="manual", owners=[])
        elif args.action == "enter":
            if not state["zoomed"]:
                set_zoom(state, window, True)
                state.update(mode="zen", owners=[])
            if state["mode"] == "zen" and args.owner not in state["owners"]:
                state["owners"].append(args.owner)
        elif args.action == "leave" and args.owner in state["owners"]:
            state["owners"].remove(args.owner)
            if not state["owners"] and state["mode"] == "zen":
                set_zoom(state, window, False)

        if args.action != "status":
            temporary = state_path.with_suffix(".tmp")
            temporary.write_text(json.dumps(state))
            temporary.replace(state_path)
        print(json.dumps({**state, "address": address, "pid": window["pid"]}))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Font zoom: {error}", file=sys.stderr)
        sys.exit(1)
