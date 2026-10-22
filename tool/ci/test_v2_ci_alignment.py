from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]


def section(text, heading, indentation):
    """Read a block in the repository's block-style workflow YAML."""
    match = re.search(
        rf"^{indentation}{re.escape(heading)}:\s*\n(.*?)(?=^{indentation}\S|\Z)",
        text, re.MULTILINE | re.DOTALL,
    )
    if match is None:
        raise AssertionError(f"Missing workflow section: {heading}")
    return match.group(1)


class V2CiAlignmentTests(unittest.TestCase):
    def setUp(self):
        self.ci = (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8")
        self.deferred = (ROOT / ".github/workflows/v2-deferred-web.yml").read_text(
            encoding="utf-8"
        )
        self.preview = (ROOT / ".github/workflows/v2-owner-preview.yml").read_text(
            encoding="utf-8"
        )

    def test_automatic_foundations_keep_strict_native_checks(self):
        for job in ("v2_foundations", "v2_native_checks"):
            with self.subTest(job=job):
                block = section(self.ci, job, "  ")
                self.assertIn("run: make v2-native-check", block)
                self.assertNotIn("continue-on-error", block)
                self.assertNotRegex(block, r"(?m)^    if:", "native gate must always run")
        self.assertNotIn("make v2-foundations", self.ci)
        self.assertNotIn("--platform chrome test/v2", self.ci)
        # Legacy browser checks retain their independent reference contract.
        self.assertIn("--platform chrome test/web", section(self.ci, "quality", "  "))

    def test_native_builds_do_not_depend_on_deferred_browser(self):
        builds = section(self.ci, "v2_native_builds", "  ")
        self.assertRegex(builds, r"(?m)^    needs: v2_native_checks$")
        self.assertIn("target: [android, linux]", builds)
        self.assertNotIn("continue-on-error", builds)

    def test_full_checkpoint_is_manual_strict_and_validation_only(self):
        trigger = section(self.deferred, "on", "")
        self.assertEqual(trigger.strip(), "workflow_dispatch:")
        self.assertIn("run: make v2-foundations", self.deferred)
        self.assertNotIn("continue-on-error", self.deferred)
        self.assertIn("contents: read", section(self.deferred, "permissions", ""))
        self.assertNotIn("write", section(self.deferred, "permissions", ""))
        self.assertIn("persist-credentials: false", self.deferred)
        self.assertNotIn("secrets.", self.deferred)
        self.assertNotRegex(
            self.deferred,
            r"(?:upload-artifact|pages deploy|make (?:release|web)|workflow_call)",
        )

    def test_owner_preview_is_manual_and_publishes_nothing(self):
        trigger = section(self.preview, "on", "")
        self.assertEqual(trigger.strip(), "workflow_dispatch:")
        self.assertIn("contents: read", section(self.preview, "permissions", ""))
        self.assertNotIn("write", section(self.preview, "permissions", ""))
        self.assertIn("cancel-in-progress: false", section(self.preview, "concurrency", ""))
        self.assertNotIn("continue-on-error", self.preview)
        self.assertNotIn("secrets.", self.preview)
        self.assertNotRegex(
            self.preview,
            r"(?:gh release|pages deploy|wrangler|make (?:release|web|android)\b|workflow_call|--release)",
        )
        self.assertEqual(self.preview.count("persist-credentials: false"), 3)

    def test_owner_preview_builds_each_linux_architecture_on_its_own_host(self):
        linux = section(self.preview, "linux", "  ")
        self.assertIn("arch: x64\n            runner: ubuntu-24.04\n", linux)
        self.assertIn("arch: arm64\n            runner: ubuntu-24.04-arm\n", linux)
        # No published Linux ARM64 SDK archive exists, so arm64 pins the tag.
        self.assertRegex(linux, r"if: matrix.arch == 'x64'\n        uses: subosito/flutter-action@v2")
        self.assertIn('git clone --depth 1 --branch "$FLUTTER_VERSION"', linux)
        self.assertIn('["frameworkVersion"]', linux)
        for step in ("make v2-linux-debug", "make v2-linux-preview-package", "make v2-linux-preview-smoke"):
            self.assertIn(step, linux)
        self.assertIn("codewalk-v2-preview-linux-${{ matrix.arch }}.tar.gz", linux)

    def test_owner_preview_launches_the_same_android_build_before_handoff(self):
        android = section(self.preview, "android", "  ")
        self.assertIn("make v2-android-preview", android)
        self.assertIn("app-arm64-v8a-profile.apk", android)
        launch = section(self.preview, "android_launch", "  ")
        self.assertRegex(launch, r"(?m)^    needs: android$")
        self.assertIn("api-level: 36", launch)
        self.assertIn("arch: x86_64", launch)
        self.assertIn("python3 tool/ci/smoke_v2_android_preview.py", launch)
        self.assertIn("--build-evidence launch/native-evidence/android-preview.json", launch)

    def test_owner_preview_leaves_the_automatic_pipeline_alone(self):
        self.assertNotIn("v2-android-preview", self.ci)
        self.assertNotIn("ubuntu-24.04-arm", self.ci)


if __name__ == "__main__":
    unittest.main()
