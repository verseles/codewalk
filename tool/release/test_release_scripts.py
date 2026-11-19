import os
import plistlib
import re
import stat
import subprocess
import tempfile
import unittest
from unittest import mock
from pathlib import Path

HERE = Path(__file__).parent
ROOT = HERE.parents[1]
BETA_TAG = "v2.0.0-beta.1"
STABLE_TAG = "v2.0.0"
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
        return run_with_stub("require_new_release.sh", "gh", stub, ["owner/repo", BETA_TAG], files=[])[0]

    def test_a_missing_release_is_new(self):
        self.assertEqual(self.run_gh('echo "gh: Not Found (HTTP 404)" >&2; exit 1\n'), 0)

    def test_an_existing_release_is_refused(self):
        self.assertEqual(self.run_gh(f"echo '{{\"tag_name\":\"{BETA_TAG}\"}}'\n"), 1)

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
        return run_with_stub("require_tag_at_commit.sh", "git", stub, ["owner/repo", BETA_TAG, COMMIT], files=[])[0]

    def test_a_lightweight_tag_at_the_commit_passes(self):
        self.assertEqual(self.run_git(f'printf "{COMMIT}\\trefs/tags/{BETA_TAG}\\n"\n'), 0)

    def test_an_annotated_tag_is_peeled(self):
        stub = f'printf "{"b" * 40}\\trefs/tags/{BETA_TAG}\\n{COMMIT}\\trefs/tags/{BETA_TAG}^{{}}\\n"\n'
        self.assertEqual(self.run_git(stub), 0)

    def test_a_tag_at_another_commit_is_refused(self):
        stub = f'printf "{COMMIT}\\trefs/tags/{BETA_TAG}\\n{"c" * 40}\\trefs/tags/{BETA_TAG}^{{}}\\n"\n'
        self.assertEqual(self.run_git(stub), 1)

    def test_a_missing_tag_or_failed_lookup_is_refused(self):
        self.assertEqual(self.run_git("true\n"), 1)
        self.assertNotEqual(self.run_git("exit 128\n"), 0)


class CreateV2ReleaseTests(unittest.TestCase):
    def run_create(self, stub, tag=BETA_TAG, kind="beta", files=None):
        return run_with_stub("create_v2_release.sh", "gh", stub, ["owner/repo", tag, kind], files)

    def _init_repo(self, directory: str, relpath: str, content: str, tag: str) -> Path:
        root = Path(directory)
        subprocess.run(["git", "init", "-q", directory], check=True)
        source = root / relpath
        source.parent.mkdir(parents=True, exist_ok=True)
        source.write_text(content, encoding="utf-8")
        subprocess.run(["git", "-C", directory, "add", relpath], check=True)
        subprocess.run(
            ["git", "-C", directory, "-c", "user.name=Test", "-c", "user.email=test@example.test",
             "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null", "commit", "-qm", "notes"],
            check=True,
        )
        subprocess.run(["git", "-C", directory, "tag", tag], check=True)
        return source

    def test_beta_curated_notes_are_read_from_the_tag_and_validated(self):
        for notes, expected in [("> 📣 Approved announcement\n\n- Full notes", 0), ("> 📣 " + "x" * 301, 1)]:
            with self.subTest(expected=expected), tempfile.TemporaryDirectory() as directory:
                source = self._init_repo(directory, "release-notes/v2-beta.md", notes, BETA_TAG)
                source.write_text("Never publish notes from the working tree", encoding="utf-8")
                with mock.patch.dict(os.environ, {"GIT_DIR": str(Path(directory) / ".git")}):
                    code, calls = self.run_create('case "$1" in api) echo 1;; esac\n', tag=BETA_TAG, kind="beta")
                self.assertEqual(code, expected)
                self.assertNotIn("Never publish", calls)
                if expected == 0:
                    self.assertIn("Approved announcement", calls)
                    self.assertIn("Full notes", calls)
                else:
                    self.assertEqual(calls, "")

    def test_stable_notes_are_read_from_tag_changelog_and_mark_latest(self):
        good = (
            "# Changelog\n\n"
            "## v2.0.0 - 2026-11-19\n\n"
            "> 📣 CodeWalk 2.0.0 is stable.\n\n"
            "- Stable desktop and Android release.\n\n"
            "## v1.265.1 - 2026-10-20\n\n"
            "- Prior v1.\n"
        )
        bad_announcement = "## v2.0.0 - 2026-11-19\n\n> 📣 " + "x" * 301 + "\n\n- Notes\n"
        missing_section = "## v1.265.1 - 2026-10-20\n\n- Prior v1.\n"
        for content, expected in [(good, 0), (bad_announcement, 1), (missing_section, 1)]:
            with self.subTest(expected=expected), tempfile.TemporaryDirectory() as directory:
                source = self._init_repo(directory, "CHANGELOG.md", content, STABLE_TAG)
                source.write_text("## v2.0.0 - 2026-11-19\n\n- Never from working tree\n", encoding="utf-8")
                with mock.patch.dict(os.environ, {"GIT_DIR": str(Path(directory) / ".git")}):
                    code, calls = self.run_create('case "$1" in api) echo 7;; esac\n', tag=STABLE_TAG, kind="stable")
                self.assertEqual(code, expected)
                self.assertNotIn("Never from working tree", calls)
                if expected == 0:
                    *create_lines, upload = calls.splitlines()
                    create = "\n".join(create_lines)
                    self.assertIn("prerelease=false", create)
                    self.assertIn("make_latest=true", create)
                    self.assertIn("draft=false", create)
                    self.assertIn("CodeWalk 2.0.0 is stable.", create)
                    self.assertNotIn("Prior v1.", create)
                    self.assertNotIn("--clobber", upload)
                    self.assertTrue(upload.startswith(f"release upload {STABLE_TAG} "))
                else:
                    self.assertEqual(calls, "")

    def test_beta_creates_a_prerelease_that_is_never_latest_then_uploads(self):
        code, calls = self.run_create('case "$1" in api) echo 1;; esac\n', tag=BETA_TAG, kind="beta")
        self.assertEqual(code, 0)
        create, upload = calls.splitlines()
        self.assertIn("--method POST repos/owner/repo/releases", create)
        self.assertIn(f"tag_name={BETA_TAG}", create)
        self.assertIn("prerelease=true", create)
        self.assertIn("make_latest=false", create)
        self.assertIn("draft=false", create)
        self.assertNotIn("--clobber", upload)
        self.assertTrue(upload.startswith(f"release upload {BETA_TAG} "))

    def test_mismatched_kind_and_tag_is_refused_before_any_call(self):
        for tag, kind in ((STABLE_TAG, "beta"), (BETA_TAG, "stable"), ("v2.0.1", "stable"), (BETA_TAG, "nightly")):
            with self.subTest(tag=tag, kind=kind):
                code, calls = self.run_create('case "$1" in api) echo 1;; esac\n', tag=tag, kind=kind)
                self.assertEqual(code, 1)
                self.assertEqual(calls, "")

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


class InstallPs1ContractTests(unittest.TestCase):
    def test_windows_installer_guards_channels_migration_and_has_no_v1_fallback(self):
        text = (ROOT / "install.ps1").read_text(encoding="utf-8")
        for required in (
            "CODEWALK_CHANNEL",
            "CODEWALK_VERSION",
            "CODEWALK_MIGRATION",
            "CODEWALK_UPDATE_CONTRACT",
            "CODEWALK_INSTALLER_SOURCE_ONLY",
            ".installed-channel",
            "accept-v2",
            "CODEWALK_CHANNEL='v1'",
            "Assert-MajorPolicy",
            "Select-ReleaseForChannel",
            "if ($null -eq $batch) { break }",
        ):
            with self.subTest(required=required):
                self.assertIn(required, text)
        # Keep Windows PowerShell 5.1 compatibility (no PowerShell 7-only null-coalescing).
        self.assertNotIn("??", text)
        # Missing asset must fail rather than querying another release.
        missing_block = re.search(r"if \(-not \$match\) \{(.*?)\n  \}", text, re.S)
        self.assertIsNotNone(missing_block)
        self.assertIn("Fail ", missing_block.group(1))
        self.assertNotIn("Invoke-GitHubReleaseApi", missing_block.group(1))


class MacosBuildConfigTests(unittest.TestCase):
    def test_macos_deployment_target_is_12_0_everywhere(self):
        for rel in (
            "macos/Podfile",
            "macos/Flutter/Flutter-Debug.xcconfig",
            "macos/Flutter/Flutter-Release.xcconfig",
            "macos/Runner.xcodeproj/project.pbxproj",
        ):
            with self.subTest(path=rel):
                text = (ROOT / rel).read_text(encoding="utf-8")
                self.assertIn("12.0", text)
                self.assertNotRegex(text, r"(?:platform :osx,\s*'11\.0'|MACOSX_DEPLOYMENT_TARGET\s*=\s*'?11\.0'?)")

    def test_macos_entitlements_enable_outbound_network_and_user_selected_reads(self):
        for rel in ("macos/Runner/Release.entitlements", "macos/Runner/DebugProfile.entitlements"):
            with self.subTest(path=rel):
                entitlements = plistlib.loads((ROOT / rel).read_bytes())
                self.assertTrue(entitlements.get("com.apple.security.network.client"))
                self.assertTrue(entitlements.get("com.apple.security.files.user-selected.read-only"))


if __name__ == "__main__":
    unittest.main()
