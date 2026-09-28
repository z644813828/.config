"""Exercise the hourly limiter with Docker and the clock stubbed out."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name('openclaw_health.sh')
DOCKER = r'''#!/bin/bash
if [ "$1" = inspect ]; then
    echo true
elif [ "$2" = -i ]; then
    cat >/dev/null
    if [ -f "$MOCK_DIR/valid" ]; then exit 0; else exit 3; fi
elif [ "$4" = agent ]; then
    echo attempt >>"$MOCK_DIR/calls"
    sleep "${MOCK_DELAY:-0}"
    if [ "${MOCK_SUCCESS:-0}" = 1 ]; then
        touch "$MOCK_DIR/valid"
    else
        exit 1
    fi
elif [ "$4" = models ]; then
    echo '{}'
elif [ "$4" = --version ]; then
    echo 'OpenClaw test'
fi
'''


class HourlyLimitTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for name, content in [('docker', DOCKER),
                              ('date', '#!/bin/bash\necho "$MOCK_NOW"\n')]:
            path = self.root / name
            path.write_text(content)
            path.chmod(0o700)
        self.env = dict(os.environ, PATH=str(self.root) + ':' + os.environ['PATH'],
                        MOCK_DIR=str(self.root), MOCK_NOW='1800000000',
                        OPENCLAW_CONTAINER='openclaw',
                        OPENCLAW_HEALTH_STATE_DIR=str(self.root / 'state'))

    def run_check(self):
        return subprocess.run(['bash', str(SCRIPT)], env=self.env,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              universal_newlines=True, timeout=10)

    def calls(self):
        path = self.root / 'calls'
        return len(path.read_text().splitlines()) if path.exists() else 0

    def test_failures_are_limited_until_exact_hour_boundary(self):
        self.assertEqual(self.run_check().returncode, 2)
        self.env['MOCK_NOW'] = '1800003599'
        result = self.run_check()
        self.assertEqual(result.returncode, 2)
        self.assertIn('hourly limit', result.stdout)
        self.assertEqual(self.calls(), 1)
        self.env['MOCK_NOW'] = '1800003600'
        self.assertEqual(self.run_check().returncode, 2)
        self.assertEqual(self.calls(), 2)

    def test_success_is_also_limited_if_token_expires_again(self):
        self.env['MOCK_SUCCESS'] = '1'
        self.assertEqual(self.run_check().returncode, 0)
        (self.root / 'valid').unlink()
        self.assertEqual(self.run_check().returncode, 2)
        self.assertEqual(self.calls(), 1)

    def test_external_refresh_recovers_during_cooldown(self):
        self.run_check()
        (self.root / 'valid').touch()
        self.assertEqual(self.run_check().returncode, 0)
        self.assertEqual(self.calls(), 1)

    def test_invalid_timestamp_does_not_spend_quota(self):
        (self.root / 'state').mkdir()
        (self.root / 'state/openclaw.last-attempt').write_text('broken\n')
        self.assertEqual(self.run_check().returncode, 2)
        self.assertEqual(self.calls(), 0)

    def test_parallel_checks_make_only_one_attempt(self):
        self.env['MOCK_DELAY'] = '1'
        processes = [subprocess.Popen(['bash', str(SCRIPT)], env=self.env,
                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                     for _ in range(2)]
        for process in processes:
            process.communicate(timeout=10)
            self.assertEqual(process.returncode, 2)
        self.assertEqual(self.calls(), 1)


if __name__ == '__main__':
    unittest.main()
