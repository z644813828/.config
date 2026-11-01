import importlib.util
from pathlib import Path
import unittest


spec = importlib.util.spec_from_file_location(
    "certbot_proxy", Path(__file__).with_name("prepare-certbot-proxy.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ProxyTests(unittest.TestCase):
    def test_only_proxy_values_are_copied(self):
        source = "HTTPS_PROXY=http://user:pass@proxy.invalid:3128\nTELEGRAM_BOT_TOKEN=not-a-real-token\n"
        result = module.environment(source)
        self.assertNotIn("TOKEN", result)
        self.assertNotIn("not-a-real-token", result)
        self.assertEqual(len(result.splitlines()), 8)
        self.assertIn("NO_PROXY=localhost,127.0.0.1,::1\n", result)

    def test_lowercase_and_last_duplicate_win(self):
        result = module.environment(
            "HTTPS_PROXY=http://first.invalid\nHTTPS_PROXY=http://second.invalid\n"
            "https_proxy='http://third.invalid'\n")
        self.assertIn("HTTPS_PROXY=http://third.invalid\n", result)
        self.assertNotIn("first.invalid", result)
        self.assertNotIn("second.invalid", result)

    def test_rejects_unsafe_or_missing_proxy(self):
        for source in ("", "HTTPS_PROXY=bad", "HTTPS_PROXY=http://a.invalid:bad",
                       "HTTPS_PROXY=http://user:bad pass@a.invalid", "HTTPS_PROXY=http://a.invalid/\\x"):
            with self.subTest(source=source), self.assertRaises(ValueError):
                module.environment(source)


if __name__ == "__main__":
    unittest.main()
