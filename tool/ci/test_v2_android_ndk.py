from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("install_android_ndk.sh")


class AndroidNdkTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "sdk with spaces"
        self.manager = self.root / "cmdline-tools/latest/bin/sdkmanager"
        self.manager.parent.mkdir(parents=True)
        self.log = Path(self.temp.name) / "calls"
        self.manager.write_text(
            '#!/bin/sh\n'
            'printf "%s\\n" "$@" >> "$SDK_LOG"\n'
            'if [ "$1" = "--version" ]; then exit "${VERSION_EXIT:-0}"; fi\n'
            'exit "${INSTALL_EXIT:-0}"\n', encoding="utf-8"
        )
        self.manager.chmod(0o755)
        self.env = {"PATH": "/usr/bin:/bin", "ANDROID_HOME": str(self.root),
                    "SDK_LOG": str(self.log)}

    def run_script(self):
        return subprocess.run(["/bin/bash", str(SCRIPT)], env=self.env,
                              text=True, capture_output=True)

    def test_uses_verified_absolute_path_without_sdkmanager_on_path(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text().splitlines(),
                         ["--version", f"--sdk_root={self.root}", "--install", "ndk;28.2.13676358"])

    def test_compatible_sdk_root_fallback(self):
        self.env["ANDROID_SDK_ROOT"] = self.env.pop("ANDROID_HOME")
        self.assertEqual(self.run_script().returncode, 0)

    def test_missing_or_inconsistent_root_fails_before_install(self):
        for env in ({}, {"ANDROID_HOME": str(self.root), "ANDROID_SDK_ROOT": "/other"}):
            with self.subTest(env=env):
                self.env = {"PATH": "/usr/bin:/bin", "SDK_LOG": str(self.log), **env}
                self.assertNotEqual(self.run_script().returncode, 0)
                self.assertFalse(self.log.exists())

    def test_missing_or_nonexecutable_manager_is_not_silently_skipped(self):
        self.manager.chmod(0o644)
        self.assertNotEqual(self.run_script().returncode, 0)
        self.manager.unlink()
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertFalse(self.log.exists())

    def test_version_failure_stops_before_install(self):
        self.env["VERSION_EXIT"] = "8"
        self.assertEqual(self.run_script().returncode, 8)
        self.assertEqual(self.log.read_text().splitlines(), ["--version"])

    def test_real_install_failure_propagates(self):
        self.env["INSTALL_EXIT"] = "9"
        self.assertEqual(self.run_script().returncode, 9)
        self.assertEqual(self.log.read_text().splitlines()[-1], "ndk;28.2.13676358")


if __name__ == "__main__":
    unittest.main()
