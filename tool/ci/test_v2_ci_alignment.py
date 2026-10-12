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


if __name__ == "__main__":
    unittest.main()
