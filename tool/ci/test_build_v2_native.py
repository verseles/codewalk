import contextlib
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock
import zipfile

import build_v2_native as native


class NativeBuildTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "lib").mkdir()
        (self.root / native.ENTRY_POINT).write_text("v2 fixture", encoding="utf-8")
        self.calls = []
        self.artifacts = True
        self.failure = False
        self.wrong_arch = False
        self.kernel = b"compiled fixture"

    def runner(self, command, **kwargs):
        self.calls.append(command)
        if command == ["git", "rev-parse", "HEAD"]:
            return subprocess.CompletedProcess(command, 0, stdout="a" * 40)
        if command == ["git", "status", "--porcelain"]:
            return subprocess.CompletedProcess(command, 0, stdout="")
        if command == ["flutter", "--version", "--machine"]:
            return subprocess.CompletedProcess(command, 0, stdout=json.dumps({"frameworkVersion": "fixture"}))
        if self.failure:
            raise subprocess.CalledProcessError(7, command)
        if self.artifacts:
            if "apk" in command:
                output = self.root / "build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk"
                output.parent.mkdir(parents=True)
                abi = "x86_64" if self.wrong_arch else "arm64-v8a"
                with zipfile.ZipFile(output, "w") as archive:
                    archive.writestr(f"lib/{abi}/libflutter.so", b"fixture")
                    if self.kernel is not None:
                        archive.writestr("assets/flutter_assets/kernel_blob.bin", self.kernel)
            else:
                arch = command[-1].removeprefix("linux-")
                output = self.root / f"build/linux/{arch}/debug/bundle"
                (output / "lib").mkdir(parents=True)
                (output / "data/flutter_assets").mkdir(parents=True)
                machine = 183 if arch == "arm64" else 62
                if self.wrong_arch:
                    machine = 0
                header = b"\x7fELF\x02\x01" + b"\x00" * 12 + machine.to_bytes(2, "little")
                (output / "codewalk").write_bytes(header)
                (output / "lib/libflutter_linux_gtk.so").write_bytes(b"fixture")
                if self.kernel is not None:
                    (output / "data/flutter_assets/kernel_blob.bin").write_bytes(self.kernel)
        return subprocess.CompletedProcess(command, 0)

    def build(self, target, machine="x86_64"):
        with contextlib.redirect_stdout(io.StringIO()):
            return native.build(self.root, target=target, system="Linux", machine=machine, runner=self.runner)

    def test_android_explicit_debug_target_and_fresh_abi_inspection(self):
        result = self.build("android")
        self.assertEqual(result["command"], ["flutter", "build", "apk", "--debug", "--no-pub",
                                           "--target", "lib/main_v2.dart", "--target-platform", "android-arm64",
                                           "--split-per-abi"])
        self.assertEqual(result["compiler"], "pass")
        self.assertEqual(result["installation"], "not-tested")
        self.assertEqual(result["release_aot"], "not-tested")
        self.assertTrue(result["artifacts_sha256"])
        self.assertEqual(json.loads((self.root / "build/native-evidence/android.json").read_text()), result)

    def test_linux_native_arm64_bundle_not_an_assumed_x64_path(self):
        result = self.build("linux", "aarch64")
        self.assertEqual(result["command"][-1], "linux-arm64")
        self.assertIn("build/linux/arm64/debug/bundle/codewalk", result["artifacts_sha256"])

    def test_unsupported_android_host_stops_before_any_process(self):
        with self.assertRaisesRegex(RuntimeError, "x64 host"):
            self.build("android", "aarch64")
        self.assertEqual(self.calls, [])

    def test_unknown_host_or_target_does_not_guess_architecture(self):
        for target, system, machine in (("linux", "Linux", "mips"), ("linux", "Windows", "x86_64"),
                                        ("other", "Linux", "x86_64")):
            with self.subTest(target=target, system=system, machine=machine):
                with self.assertRaises((RuntimeError, ValueError)):
                    native.command_for(target, system, machine)

    def test_old_native_outputs_are_preserved_and_never_used_as_proof(self):
        output = self.root / "build/linux/old-user-artifact"
        output.parent.mkdir(parents=True)
        output.write_text("preserve", encoding="utf-8")
        with self.assertRaisesRegex(RuntimeError, "already exists"):
            self.build("linux")
        self.assertEqual(output.read_text(), "preserve")
        self.assertEqual(self.calls, [])

    def test_output_symlink_is_refused_without_writing_destination(self):
        (self.root / "build").mkdir()
        (self.root / "build/app").symlink_to(self.root / "missing-output")
        with self.assertRaisesRegex(RuntimeError, "already exists"):
            self.build("android")
        self.assertEqual(self.calls, [])

    def test_exit_zero_without_artifacts_is_not_compilation_success(self):
        self.artifacts = False
        with self.assertRaises(FileNotFoundError):
            self.build("android")
        self.assertEqual(json.loads((self.root / "build/native-evidence/android.json").read_text())["compiler"], "fail")

    def test_failed_compiler_propagates_exit_and_records_failure(self):
        self.failure = True
        with self.assertRaises(subprocess.CalledProcessError) as failure:
            self.build("linux")
        self.assertEqual(failure.exception.returncode, 7)
        self.assertEqual(json.loads((self.root / "build/native-evidence/linux.json").read_text())["compiler"], "fail")

    def test_wrong_native_artifact_architecture_is_rejected(self):
        self.wrong_arch = True
        with self.assertRaisesRegex(RuntimeError, "ABIs"):
            self.build("android")
        with self.assertRaisesRegex(RuntimeError, "architecture"):
            self.build("linux")

    def test_missing_or_empty_debug_kernel_cannot_be_compiler_pass(self):
        for target in ("android", "linux"):
            for kernel in (None, b""):
                with self.subTest(target=target, kernel=kernel):
                    with tempfile.TemporaryDirectory() as directory:
                        root = Path(directory)
                        old_root = self.root
                        self.root = root
                        try:
                            (root / "lib").mkdir()
                            (root / native.ENTRY_POINT).write_text("fixture", encoding="utf-8")
                            self.kernel = kernel
                            with self.assertRaisesRegex(RuntimeError, "compiled Dart kernel"):
                                self.build(target)
                            self.assertEqual(json.loads((root / f"build/native-evidence/{target}.json").read_text())["compiler"], "fail")
                        finally:
                            self.root = old_root

    def test_hashing_streams_large_files_without_python311_helper(self):
        contents = b"binary fixture" * 100000
        file = self.root / "large-artifact"
        file.write_bytes(contents)
        with mock.patch.object(hashlib, "file_digest", create=True, side_effect=AssertionError("3.11 helper unavailable")):
            self.assertEqual(native.sha256(file), hashlib.sha256(contents).hexdigest())


if __name__ == "__main__":
    unittest.main()
