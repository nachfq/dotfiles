"""Apply real config links using an isolated home, preserving existing state."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


@unittest.skipIf(os.geteuid() == 0, "config application deliberately refuses root")
class ApplyTest(unittest.TestCase):
    def test_application_preserves_shell_and_herdr_state_and_tracks_source_files(self):
        with tempfile.TemporaryDirectory(prefix="dotfiles apply ") as directory:
            home = Path(directory)
            config = home / "config"
            state = home / "state"
            (config / "herdr").mkdir(parents=True)
            session = config / "herdr/session.json"
            session.write_text('{"existing": true}\n')
            (config / "herdr/config.toml").write_text("old config\n")
            bashrc = home / ".bashrc"
            bashrc.write_text("# existing shell setup\n")
            env = os.environ | {"HOME": directory, "XDG_CONFIG_HOME": str(config),
                                 "XDG_STATE_HOME": str(state)}
            def apply():
                return subprocess.run([str(ROOT / "apply.sh"), "apply"], env=env,
                                      capture_output=True, text=True, timeout=10)
            result = apply()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((config / "nvim").resolve(), ROOT / "config/nvim")
            self.assertEqual((config / "herdr/config.toml").resolve(), ROOT / "config/herdr/config.toml")
            self.assertEqual(session.read_text(), '{"existing": true}\n')
            self.assertTrue(bashrc.read_text().startswith("# existing shell setup\n"))
            self.assertEqual(bashrc.read_text().count("source "), 1)
            backups = list((state / "dotfiles/backups").glob("*"))
            self.assertEqual(len(backups), 1)
            self.assertEqual((backups[0] / "herdr-config.toml").read_text(), "old config\n")
            content = bashrc.read_text()
            self.assertEqual(apply().returncode, 0)
            self.assertEqual(bashrc.read_text(), content)
            self.assertEqual(list((state / "dotfiles/backups").glob("*")), backups)


if __name__ == "__main__":
    unittest.main()
