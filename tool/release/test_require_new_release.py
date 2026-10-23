import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name("require_new_release.sh")


def run_with_gh(stub: str) -> int:
    with tempfile.TemporaryDirectory() as bin_dir:
        gh = Path(bin_dir) / "gh"
        gh.write_text("#!/bin/sh\n" + stub)
        gh.chmod(gh.stat().st_mode | stat.S_IEXEC)
        env = {**os.environ, "PATH": f"{bin_dir}:{os.environ['PATH']}"}
        return subprocess.run(
            ["bash", str(SCRIPT), "owner/repo", "v1.266.0-native.1"],
            env=env, capture_output=True,
        ).returncode


class RequireNewReleaseTests(unittest.TestCase):
    def test_a_missing_release_is_new(self):
        self.assertEqual(run_with_gh('echo "gh: Not Found (HTTP 404)" >&2; exit 1\n'), 0)

    def test_an_existing_release_is_refused(self):
        self.assertEqual(run_with_gh('echo \'{"tag_name":"v1.266.0-native.1"}\'\n'), 1)

    def test_any_other_answer_is_refused(self):
        for stub in (
            'echo "gh: API rate limit exceeded (HTTP 403)" >&2; exit 1\n',
            'echo "gh: Server Error (HTTP 500)" >&2; exit 1\n',
            'echo "error connecting to api.github.com" >&2; exit 1\n',
        ):
            with self.subTest(stub=stub):
                self.assertEqual(run_with_gh(stub), 1)


if __name__ == "__main__":
    unittest.main()


CREATE = Path(__file__).with_name("create_cohort_release.sh")


def run_create(stub: str) -> tuple[int, str]:
    with tempfile.TemporaryDirectory() as bin_dir:
        log = Path(bin_dir) / "calls"
        gh = Path(bin_dir) / "gh"
        gh.write_text(f'#!/bin/sh\necho "$*" >> "{log}"\n' + stub)
        gh.chmod(gh.stat().st_mode | stat.S_IEXEC)
        env = {**os.environ, "PATH": f"{bin_dir}:{os.environ['PATH']}"}
        code = subprocess.run(
            ["bash", str(CREATE), "owner/repo", "v1.266.0-native.1", "a.apk"],
            env=env, capture_output=True,
        ).returncode
        return code, log.read_text() if log.exists() else ""


class CreateCohortReleaseTests(unittest.TestCase):
    def test_creates_a_prerelease_that_is_never_latest_then_uploads(self):
        code, calls = run_create('case "$1" in api) echo 1;; esac\n')
        self.assertEqual(code, 0)
        create, upload = calls.splitlines()
        self.assertIn("prerelease=true", create)
        self.assertIn("make_latest=false", create)
        self.assertIn("draft=false", create)
        self.assertTrue(upload.startswith("release upload v1.266.0-native.1 a.apk"))

    def test_an_existing_release_stops_before_any_upload(self):
        code, calls = run_create(
            'case "$1" in api) echo "already_exists (HTTP 422)" >&2; exit 1;; esac\n'
        )
        self.assertEqual(code, 1)
        self.assertNotIn("release upload", calls)
