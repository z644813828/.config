import importlib.util
from datetime import datetime, timedelta
from pathlib import Path
import tempfile
import unittest
from unittest import mock


SPEC = importlib.util.spec_from_file_location(
    "pull_backups", str(Path(__file__).with_name("pull-vps-backups-from-ftp.py")))
BACKUPS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BACKUPS)


class RetentionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.now = datetime(2026, 10, 4, 12)

    def archive(self, server, age):
        stamp = (self.now - timedelta(days=age)).strftime("%Y%m%dT%H%M%SZ")
        path = self.root / "vps-config-{}-{}.tar.gz".format(server, stamp)
        path.write_bytes(b"archive")
        return path

    def test_old_filename_is_removed_despite_recent_local_mtime(self):
        old = self.archive("vps1", 120)
        recent = [self.archive("vps1", age) for age in (1, 2, 3)]
        boundary = self.archive("vps1", 90)
        BACKUPS.prune_local_backups(self.root, 90, self.now)
        self.assertFalse(old.exists())
        self.assertTrue(boundary.exists())
        self.assertTrue(all(path.exists() for path in recent))

    def test_three_latest_are_retained_per_server_even_when_all_old(self):
        for server in ("vps1", "vps2"):
            for age in (100, 110, 120, 130):
                self.archive(server, age)
        BACKUPS.prune_local_backups(self.root, 90, self.now)
        for server in ("vps1", "vps2"):
            self.assertEqual(len(list(self.root.glob("vps-config-{}-*.tar.gz".format(server)))), 3)

    def test_other_files_and_symlinks_are_untouched(self):
        for name in ("notes.txt", "vps-config-vps1-20261301T000000Z.tar.gz",
                     "vps-config-vps1-20200101T000000Z.tar.gz.part"):
            (self.root / name).write_bytes(b"keep")
        nested = self.root / "real-directory"
        nested.mkdir()
        linked = self.root / "vps-config-vps1-20200101T000000Z.tar.gz"
        linked.symlink_to(self.root / "notes.txt")
        (self.root / "linked-directory").symlink_to(nested, target_is_directory=True)
        before = sorted(str(path) for path in self.root.iterdir())
        BACKUPS.prune_local_backups(self.root, 90, self.now)
        self.assertEqual(before, sorted(str(path) for path in self.root.iterdir()))

    def test_failed_download_never_runs_retention(self):
        config = dict(DEST_DIR=str(self.root), REMOTE_ROOT="/backups",
                      FTP_HOST="test", FTP_USER="test", FTP_PASS="test",
                      LOCAL_RETENTION_DAYS=90)
        with mock.patch.object(BACKUPS.ftplib, "FTP"), \
                mock.patch.object(BACKUPS, "mirror_dir", side_effect=IOError("failure")), \
                mock.patch.object(BACKUPS, "prune_local_backups") as prune:
            with self.assertRaises(IOError):
                BACKUPS.pull_backups(config)
            prune.assert_not_called()

    def test_truncated_transfer_preserves_existing_file(self):
        local = self.root / "backup.tar.gz"
        local.write_bytes(b"original")
        ftp = mock.Mock()
        ftp.size.return_value = 100
        ftp.retrbinary.side_effect = lambda command, callback: callback(b"short")
        with self.assertRaises(IOError):
            BACKUPS.download_if_needed(ftp, local.name, local)
        self.assertEqual(local.read_bytes(), b"original")


if __name__ == "__main__":
    unittest.main()
