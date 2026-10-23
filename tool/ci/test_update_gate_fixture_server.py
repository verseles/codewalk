"""Tests for the v1 update gate fixture server; no Flutter required."""

import json
from pathlib import Path
import sys
import tempfile
import threading
import unittest
import urllib.error
import urllib.request

sys.path.insert(0, str(Path(__file__).resolve().parent))

import update_gate_fixture_server as fixture  # noqa: E402

LATEST = "/repos/verseles/codewalk/releases/latest"
LIST = "/repos/verseles/codewalk/releases"


class FixtureServerTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="update-gate-fixture-")
        self.addCleanup(self.temp.cleanup)
        self.log = Path(self.temp.name) / "requests.jsonl"
        self.server = fixture.make_server("127.0.0.1", 0, str(self.log))
        self.thread = threading.Thread(target=self.server.serve_forever,
                                       daemon=True)
        self.thread.start()
        self.addCleanup(self._stop)
        self.base = f"http://127.0.0.1:{self.server.server_address[1]}"

    def _stop(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=5)

    def get(self, path):
        try:
            with urllib.request.urlopen(self.base + path, timeout=5) as resp:
                return resp.status, json.loads(resp.read())
        except urllib.error.HTTPError as error:
            return error.code, json.loads(error.read())

    def log_lines(self):
        return [json.loads(line) for line in
                self.log.read_text(encoding="utf-8").splitlines()]

    def test_latest_is_stable_v2_with_apk(self):
        status, release = self.get(LATEST)
        self.assertEqual(status, 200)
        self.assertEqual(release["tag_name"], "v2.0.0")
        self.assertFalse(release["draft"])
        self.assertFalse(release["prerelease"])
        self.assertEqual(
            release["html_url"],
            "https://github.com/verseles/codewalk/releases/tag/v2.0.0")
        first_line = release["body"].splitlines()[0]
        self.assertIn("CodeWalk 2 requires OpenCode 2", first_line)
        apks = [a for a in release["assets"] if a["name"].endswith(".apk")]
        self.assertEqual(len(apks), 1)
        self.assertTrue(apks[0]["browser_download_url"].startswith("https://"))

    def test_list_page_one_has_selector_candidates(self):
        status, releases = self.get(LIST + "?per_page=100&page=1")
        self.assertEqual(status, 200)
        self.assertLess(len(releases), 100)  # short page ends the scan
        by_tag = {r["tag_name"]: r for r in releases}
        self.assertIn("v2.0.0", by_tag)
        stable_v1 = by_tag["v1.266.0"]
        self.assertFalse(stable_v1["draft"] or stable_v1["prerelease"])
        self.assertTrue(any(a["name"].endswith(".apk")
                            for a in stable_v1["assets"]))
        self.assertTrue(by_tag["v1.266.0-native.1"]["prerelease"])
        self.assertTrue(any(r["draft"] for r in releases))

    def test_list_pagination_past_end_is_empty(self):
        status, releases = self.get(LIST + "?per_page=100&page=2")
        self.assertEqual(status, 200)
        self.assertEqual(releases, [])
        status, releases = self.get(LIST + "?per_page=2&page=2")
        self.assertEqual(status, 200)
        self.assertEqual(len(releases), 2)

    def test_unknown_path_is_json_404(self):
        status, payload = self.get("/repos/someone/else/releases/latest")
        self.assertEqual(status, 404)
        self.assertEqual(payload["message"], "Not Found")

    def test_log_line_keeps_path_and_pagination_only(self):
        self.get(LIST + "?per_page=100&page=1&token=secret-value")
        self.get(LATEST)
        self.get("/nope")
        lines = self.log_lines()
        self.assertEqual(len(lines), 3)
        first = lines[0]
        self.assertEqual(set(first),
                         {"time", "method", "path", "params", "status"})
        self.assertEqual(first["method"], "GET")
        self.assertEqual(first["path"], LIST)
        self.assertEqual(first["params"], {"per_page": "100", "page": "1"})
        self.assertEqual(first["status"], 200)
        self.assertNotIn("secret-value", self.log.read_text(encoding="utf-8"))
        self.assertEqual(lines[1]["path"], LATEST)
        self.assertEqual(lines[2]["status"], 404)


if __name__ == "__main__":
    unittest.main()
