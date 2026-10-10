import contextlib
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

import check_v2_foundations as foundations


class FoundationsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.packages = []
        for name in ("codewalk_core", "codewalk_net", "harness_opencode", "harness_host"):
            self.add_package(name)
        for path in ("lib/main_v2.dart", "test/v2/migration/import_test.dart", "test/contract/chp/schema_test.dart"):
            file = self.root / path
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text("fixture", encoding="utf-8")
        self.calls = []
        self.fail_command = None
        self.output = io.StringIO()

    def add_package(self, name):
        path = self.root / "packages" / name
        (path / "test").mkdir(parents=True)
        (path / "pubspec.yaml").write_text(f"name: {name}\n", encoding="utf-8")
        (path / "test/example_test.dart").write_text("fixture", encoding="utf-8")
        self.packages.append({"name": name, "path": str(path)})

    def runner(self, command, cwd, *, capture=False):
        self.calls.append((command, cwd))
        if command == self.fail_command:
            raise subprocess.CalledProcessError(9, command)
        if capture:
            return json.dumps({"packages": [{"name": "root", "path": str(self.root)}, *self.packages]})

    def check(self, **options):
        with contextlib.redirect_stdout(self.output):
            foundations.check(self.root, runner=self.runner, **options)

    def test_native_checks_discover_new_package_and_keep_all_vm_families(self):
        self.add_package("codewalk_extra")
        self.check(profile="native")
        commands = [command for command, _ in self.calls]
        tested = {cwd.name for command, cwd in self.calls if command == ["dart", "test"]}
        self.assertEqual(tested, {package["name"] for package in self.packages})
        self.assertIn(["flutter", "test", "--no-pub", "test/v2", "test/contract/chp"], commands)
        self.assertIn(["python3", "tool/l10n/generate_v2_localizations.py", "--check"], commands)
        self.assertFalse(any("chrome" in command or "build" in command for command in commands))
        self.assertIn("5 discovered packages", self.output.getvalue())

    def test_full_default_still_runs_browser_and_explicit_web_build(self):
        self.check()
        commands = [command for command, _ in self.calls]
        self.assertIn(["flutter", "test", "--no-pub", "--platform", "chrome", "test/v2"], commands)
        self.assertIn(["flutter", "build", "web", "--no-pub", "--target", "lib/main_v2.dart",
                       "--output", "build/v2/web"], commands)

    def test_no_build_keeps_browser_check(self):
        self.check(no_build=True)
        commands = [command for command, _ in self.calls]
        self.assertTrue(any("chrome" in command for command in commands))
        self.assertFalse(any("build" in command for command in commands))

    def test_discovery_rejects_external_missing_and_duplicate_packages(self):
        originals = list(self.packages)
        for packages in (
            originals + [{"name": "outside", "path": str(self.root.parent / "outside")}],
            originals[:-1], originals + [originals[0]],
            [dict(originals[0], name=originals[1]["name"]), *originals[1:]],
        ):
            with self.subTest(packages=packages), self.assertRaises(RuntimeError):
                foundations.discover_packages(self.root, {"packages": packages})

    def test_missing_package_tests_cannot_pass(self):
        (Path(self.packages[0]["path"]) / "test/example_test.dart").unlink()
        with self.assertRaisesRegex(RuntimeError, "No discoverable tests"):
            self.check(profile="native")
        self.assertNotIn("checks passed", self.output.getvalue())

    def test_missing_chp_tests_cannot_be_silently_omitted(self):
        (self.root / "test/contract/chp/schema_test.dart").unlink()
        with self.assertRaisesRegex(RuntimeError, "Missing authored-v2 tests"):
            self.check(profile="native")

    def test_missing_explicit_entry_point_fails_before_commands(self):
        (self.root / "lib/main_v2.dart").unlink()
        with self.assertRaisesRegex(RuntimeError, "Missing explicit"):
            self.check(profile="native")
        self.assertEqual(self.calls, [])

    def test_unknown_profile_does_not_silently_skip_full_gates(self):
        with self.assertRaisesRegex(ValueError, "profile"):
            self.check(profile="ful")
        self.assertEqual(self.calls, [])

    def test_gate_failure_stops_without_success_or_later_commands(self):
        for command in (
            ["dart", "run", "tool/ci/import_rules.dart"],
            ["dart", "analyze", "--fatal-infos"], ["dart", "test"],
            ["python3", "tool/l10n/generate_v2_localizations.py", "--check"],
            ["flutter", "test", "--no-pub", "test/v2", "test/contract/chp"],
        ):
            with self.subTest(command=command):
                self.calls.clear()
                self.output = io.StringIO()
                self.fail_command = command
                with self.assertRaises(subprocess.CalledProcessError):
                    self.check(profile="native")
                self.assertEqual(self.calls[-1][0], command)
                self.assertNotIn("checks passed", self.output.getvalue())


if __name__ == "__main__":
    unittest.main()
