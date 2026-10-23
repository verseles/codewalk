import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).parent
TAG = "v2.0.0-beta.1"
COMMIT = "a" * 40


def run_with_stub(script: str, tool: str, stub: str, args, files=None):
    with tempfile.TemporaryDirectory() as bin_dir:
        log = Path(bin_dir) / "calls"
        executable = Path(bin_dir) / tool
        executable.write_text(f'#!/bin/sh\necho "$*" >> "{log}"\n' + stub)
        executable.chmod(executable.stat().st_mode | stat.S_IEXEC)
        if files is None:
            asset = Path(bin_dir) / "a.apk"
            asset.write_text("apk")
            files = [str(asset)]
        env = {**os.environ, "PATH": f"{bin_dir}:{os.environ['PATH']}"}
        result = subprocess.run(["bash", str(HERE / script), *args, *files], env=env, capture_output=True)
        return result.returncode, log.read_text() if log.exists() else ""


class RequireNewReleaseTests(unittest.TestCase):
    def run_gh(self, stub):
        return run_with_stub("require_new_release.sh", "gh", stub, ["owner/repo", TAG], files=[])[0]

    def test_a_missing_release_is_new(self):
        self.assertEqual(self.run_gh('echo "gh: Not Found (HTTP 404)" >&2; exit 1\n'), 0)

    def test_an_existing_release_is_refused(self):
        self.assertEqual(self.run_gh(f"echo '{{\"tag_name\":\"{TAG}\"}}'\n"), 1)

    def test_any_other_answer_is_refused(self):
        for stub in (
            'echo "gh: API rate limit exceeded (HTTP 403)" >&2; exit 1\n',
            'echo "gh: Server Error (HTTP 500)" >&2; exit 1\n',
            'echo "error connecting to api.github.com" >&2; exit 1\n',
        ):
            with self.subTest(stub=stub):
                self.assertEqual(self.run_gh(stub), 1)


class RequireTagAtCommitTests(unittest.TestCase):
    def run_git(self, stub):
        return run_with_stub("require_tag_at_commit.sh", "git", stub, ["owner/repo", TAG, COMMIT], files=[])[0]

    def test_a_lightweight_tag_at_the_commit_passes(self):
        self.assertEqual(self.run_git(f'printf "{COMMIT}\\trefs/tags/{TAG}\\n"\n'), 0)

    def test_an_annotated_tag_is_peeled(self):
        stub = f'printf "{"b" * 40}\\trefs/tags/{TAG}\\n{COMMIT}\\trefs/tags/{TAG}^{{}}\\n"\n'
        self.assertEqual(self.run_git(stub), 0)

    def test_a_tag_at_another_commit_is_refused(self):
        stub = f'printf "{COMMIT}\\trefs/tags/{TAG}\\n{"c" * 40}\\trefs/tags/{TAG}^{{}}\\n"\n'
        self.assertEqual(self.run_git(stub), 1)

    def test_a_missing_tag_or_failed_lookup_is_refused(self):
        self.assertEqual(self.run_git("true\n"), 1)
        self.assertNotEqual(self.run_git("exit 128\n"), 0)


class CreateV2BetaReleaseTests(unittest.TestCase):
    def run_create(self, stub, files=None):
        return run_with_stub("create_v2_beta_release.sh", "gh", stub, ["owner/repo", TAG], files)

    def test_creates_a_prerelease_that_is_never_latest_then_uploads(self):
        code, calls = self.run_create('case "$1" in api) echo 1;; esac\n')
        self.assertEqual(code, 0)
        create, upload = calls.splitlines()
        self.assertIn("--method POST repos/owner/repo/releases", create)
        self.assertIn(f"tag_name={TAG}", create)
        self.assertIn("prerelease=true", create)
        self.assertIn("make_latest=false", create)
        self.assertIn("draft=false", create)
        self.assertNotIn("--clobber", upload)
        self.assertTrue(upload.startswith(f"release upload {TAG} "))

    def test_an_existing_release_stops_before_any_upload(self):
        code, calls = self.run_create('case "$1" in api) echo "already_exists (HTTP 422)" >&2; exit 1;; esac\n')
        self.assertEqual(code, 1)
        self.assertNotIn("release upload", calls)

    def test_a_missing_asset_fails_before_any_call(self):
        code, calls = self.run_create("", files=["/nonexistent/a.apk"])
        self.assertEqual(code, 1)
        self.assertEqual(calls, "")

    def test_a_failed_upload_deletes_the_new_release(self):
        code, calls = self.run_create(
            'case "$1 $2" in "api --method") case "$3" in POST) echo 42;; esac;; '
            '"release upload") exit 1;; esac\n'
        )
        self.assertEqual(code, 1)
        self.assertIn("api --method DELETE repos/owner/repo/releases/42", calls)


if __name__ == "__main__":
    unittest.main()
