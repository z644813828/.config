import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("edit_user", Path(__file__).with_name("mtproto-edit-user.py"))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class RenameTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        for directory in ("etc/systemd/system", "etc/tproxy-server"):
            (self.root / directory).mkdir(parents=True)
        self.config = self.root / "etc/mtg-AlexeyP-1.toml"
        self.config.write_text('secret = "unchanged"\nbind-to = "0.0.0.0:8450"\nextra = true\n')
        (self.root / "etc/systemd/system/mtg-AlexeyP-1.service").write_text(
            "Description=mtg (AlexeyP-1)\nExecStart=/usr/local/bin/mtg run /etc/mtg-AlexeyP-1.toml\n")
        self.profiles = self.root / "etc/tproxy-server/profiles.json"
        self.info = self.root / "etc/tproxy-server/client-info.json"
        self.profiles.write_text(json.dumps({"profiles": [{"name": "AlexeyP-1", "secret": "same", "carrier_mode": "https"}]}))
        self.info.write_text(json.dumps({"profiles": [{"user": "AlexeyP-1", "link": "same-link", "proxy_secret": "same"}]}))

    def test_rename_preserves_access_and_config(self):
        with patch.object(mod, "run", return_value=subprocess.CompletedProcess([], 0, "", "")):
            mod.edit(self.root, "AlexeyP-1", "AlexeyP-6", 8450)
        self.assertFalse(self.config.exists())
        self.assertIn('extra = true', (self.root / "etc/mtg-AlexeyP-6.toml").read_text())
        self.assertEqual(json.loads(self.profiles.read_text())["profiles"][0],
                         {"name": "AlexeyP-6", "secret": "same", "carrier_mode": "https"})
        self.assertEqual(json.loads(self.info.read_text())["profiles"][0]["link"], "same-link")

    def test_conflict_and_invalid_name(self):
        with self.assertRaises(ValueError):
            mod.prepare(self.root, "AlexeyP-1", "../bad", 8450)
        (self.root / "etc/mtg-existing.toml").write_text("")
        with self.assertRaises(ValueError):
            mod.prepare(self.root, "AlexeyP-1", "existing", 8450)
        self.info.write_text('{"profiles":[{"user":"occupied"}]}')
        with self.assertRaises(ValueError):
            mod.prepare(self.root, "AlexeyP-1", "occupied", 8450)

    def test_inconsistent_profiles(self):
        self.info.write_text('{"profiles":[]}')
        with self.assertRaises(ValueError):
            mod.prepare(self.root, "AlexeyP-1", "renamed", 8450)

    def test_rollback_after_service_failure(self):
        before = {p: p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
        def run(*args, check=True):
            if args == ("systemctl", "start", "mtg-renamed.service") and check:
                raise RuntimeError("injected failure")
            return subprocess.CompletedProcess(args, 0, "", "")
        with patch.object(mod, "run", side_effect=run):
            with self.assertRaisesRegex(RuntimeError, "rolled back"):
                mod.edit(self.root, "AlexeyP-1", "renamed", 8450)
        for path, data in before.items():
            self.assertEqual(path.read_bytes(), data)
        self.assertFalse((self.root / "etc/mtg-renamed.toml").exists())

    def test_without_webproxy_and_unchanged_name(self):
        self.profiles.unlink()
        self.info.unlink()
        changes, removed, relay = mod.prepare(self.root, "AlexeyP-1", "AlexeyP-1", 8450)
        self.assertFalse(removed)
        self.assertFalse(relay)
        self.assertEqual(changes[self.config][0], self.config.read_bytes())


if __name__ == "__main__":
    unittest.main()
