"""Behavior of the agentless CI watcher, with fake gh and hey commands."""
import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FAKE_GH = """#!/usr/bin/env bash
echo "$*" >> "$FAKE_DIR/gh.log"
case "$*" in
  "run list"*) [ -z "${FAKE_NO_RUN:-}" ] && echo 42; exit 0 ;;
  *status,conclusion*)
    line="$(head -n 1 "$FAKE_DIR/views")"
    [ "$(wc -l < "$FAKE_DIR/views")" -gt 1 ] && sed -i 1d "$FAKE_DIR/views"
    [ "$line" = error ] && exit 1
    echo "$line"
    ;;
  *url*) echo https://example.test/run/42 ;;
esac
"""
FAKE_HEY = """#!/usr/bin/env bash
echo "$*" >> "$FAKE_DIR/hey.log"
"""


class NotifyRunTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.dir = Path(self.temp.name)
        for name, body in (("gh", FAKE_GH), ("hey", FAKE_HEY)):
            path = self.dir / name
            path.write_text(body)
            path.chmod(path.stat().st_mode | stat.S_IEXEC)

    def run_watcher(self, views, mode="failures", **env):
        (self.dir / "views").write_text("\n".join(views) + "\n")
        result = subprocess.run(
            ["bash", str(ROOT / "tool/ci/notify_run.sh"), "release.yml", mode],
            cwd=ROOT,
            capture_output=True,
            text=True,
            env={
                **os.environ,
                "PATH": f"{self.dir}:{os.environ['PATH']}",
                "FAKE_DIR": str(self.dir),
                "HEY_BIN": str(self.dir / "hey"),
                "NOTIFY_POLL_SECONDS": "0",
                "NOTIFY_APPEAR_SECONDS": "1",
                "NOTIFY_WATCH_SECONDS": "30",
                **env,
            },
        )
        log = self.dir / "hey.log"
        return result.returncode, log.read_text() if log.exists() else ""

    def test_success_is_silent_when_only_failures_report(self):
        self.assertEqual(self.run_watcher(["completed success"]), (0, ""))

    def test_success_reports_when_always(self):
        code, report = self.run_watcher(["completed success"], mode="always")
        self.assertEqual(code, 0)
        self.assertIn("release.yml passed", report)

    def test_failure_reports_the_run(self):
        code, report = self.run_watcher(["completed failure"])
        self.assertEqual(code, 1)
        self.assertIn("ended as failure", report)
        self.assertIn("https://example.test/run/42", report)

    def test_a_cancelled_run_stays_silent_when_only_failures_report(self):
        self.assertEqual(self.run_watcher(["completed cancelled"]), (0, ""))

    def test_failed_polls_do_not_read_as_a_failed_run(self):
        views = ["error", "in_progress null", "error", "completed success"]
        self.assertEqual(self.run_watcher(views), (0, ""))

    def test_an_unknown_result_is_not_reported_as_a_failed_run(self):
        code, report = self.run_watcher(["error"], NOTIFY_WATCH_SECONDS="1")
        self.assertEqual(code, 1)
        self.assertIn("could not determine", report)
        self.assertNotIn("ended as", report)

    def test_a_run_that_never_starts_is_reported(self):
        code, report = self.run_watcher(["completed success"], FAKE_NO_RUN="1")
        self.assertEqual(code, 1)
        self.assertIn("did not start", report)

    def test_only_push_runs_are_followed(self):
        self.run_watcher(["completed success"])
        self.assertIn("--event push", (self.dir / "gh.log").read_text())


if __name__ == "__main__":
    unittest.main()
