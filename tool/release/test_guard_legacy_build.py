from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from guard_legacy_build import guard

SCRIPT = Path(__file__).with_name("guard_legacy_build.py")


class LegacyBuildGuardTests(unittest.TestCase):
    def test_the_legacy_version_builds(self):
        guard("version: 1.265.0+1790827338\n")
        guard("version: 1.265.0+1790827338\n", "refs/heads/main")

    def test_a_codewalk_2_version_refuses_the_legacy_entry_point(self):
        for version in ("2.0.0-beta.1+1792800000", "2.0.0+1792800000", "3.1.0+1", "0.9.0+1"):
            with self.subTest(version=version), self.assertRaisesRegex(ValueError, "legacy"):
                guard(f"version: {version}\n")

    def test_the_web_deploy_runs_only_from_main(self):
        for ref in ("refs/heads/v1", "refs/heads/feature", "refs/tags/v2.0.0-beta.1", ""):
            with self.subTest(ref=ref), self.assertRaisesRegex(ValueError, "refs/heads/main"):
                guard("version: 1.265.0+1790827338\n", ref)

    def test_a_missing_version_is_refused(self):
        with self.assertRaisesRegex(ValueError, "pubspec"):
            guard("name: codewalk\n")

    def test_the_command_line_exits_nonzero_when_refusing(self):
        with tempfile.TemporaryDirectory() as directory:
            pubspec = Path(directory) / "pubspec.yaml"
            pubspec.write_text("version: 2.0.0-beta.1+1792800000\n")
            run = lambda *args: subprocess.run([sys.executable, str(SCRIPT), str(pubspec), *args],
                                               capture_output=True).returncode
            self.assertEqual(run(), 1)
            pubspec.write_text("version: 1.265.0+1790827338\n")
            self.assertEqual(run(), 0)
            self.assertEqual(run("--web-ref", "refs/heads/v1"), 1)
            self.assertEqual(run("--web-ref", "refs/heads/main"), 0)


if __name__ == "__main__":
    unittest.main()
