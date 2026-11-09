"""Terminal helpers use a PTY; they never start a real GitHub login."""

import base64
import fcntl
import os
from pathlib import Path
import pty
import select
import subprocess
import termios
import unittest


HELPERS = Path(__file__).resolve().parents[2] / "config/bash/gh-headless"


class GhHeadlessTest(unittest.TestCase):
    def test_clipboard_reaches_tty_even_when_helper_stdout_is_discarded(self):
        master, slave = pty.openpty()

        def acquire_tty():
            os.setsid()
            fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

        try:
            result = subprocess.run(
                [str(HELPERS / "xclip"), "-in", "-selection", "clipboard"],
                input=b"TEST-CODE", stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
                pass_fds=(slave,), preexec_fn=acquire_tty, timeout=5,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(select.select([master], [], [], 1)[0], "No clipboard request reached the TTY")
            payload = os.read(master, 4096)
            self.assertEqual(payload, b"\x1b]52;c;" + base64.b64encode(b"TEST-CODE") + b"\x07")
        finally:
            os.close(master)
            os.close(slave)

    def test_clipboard_reads_fail_without_querying_terminal(self):
        result = subprocess.run(
            [str(HELPERS / "xclip"), "-out", "-selection", "clipboard"],
            input=b"", capture_output=True, timeout=5,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"writes only", result.stderr)
        self.assertEqual(result.stdout, b"")

    def test_browser_presents_local_clickable_url(self):
        url = "https://github.com/login/device"
        result = subprocess.run([str(HELPERS / "browser"), url],
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Ctrl+clic", result.stdout)
        self.assertIn(f"\x1b]8;;{url}\x1b\\{url}\x1b]8;;\x1b\\", result.stdout)

    def test_browser_rejects_terminal_controls_and_non_web_urls(self):
        for url in ("https://github.com/\x1b]52;c;bad\x07", "file:///etc/passwd", "https://"):
            with self.subTest(url=url):
                result = subprocess.run([str(HELPERS / "browser"), url],
                                        capture_output=True, text=True, timeout=5)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "")


if __name__ == "__main__":
    unittest.main()
