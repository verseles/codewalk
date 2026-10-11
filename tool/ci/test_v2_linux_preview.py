import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tool.preview import preview_linux as preview
from tool.ci import smoke_v2_linux_preview as smoke


class LinuxPreviewTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bundle = self.root / "bundle"
        (self.bundle / "lib").mkdir(parents=True)
        (self.bundle / "data/flutter_assets").mkdir(parents=True)
        (self.bundle / "codewalk").write_bytes(b"\x7fELF\x02\x01" + b"\0" * 12 + (62).to_bytes(2, "little"))
        (self.bundle / "codewalk").chmod(0o755)
        (self.bundle / "lib/libflutter_linux_gtk.so").write_bytes(b"engine fixture")
        (self.bundle / "data/flutter_assets/kernel_blob.bin").write_bytes(b"compiled fixture")
        self.metadata = self.root / "metadata.json"
        self.metadata.write_text(json.dumps({"compiler": "pass", "target": "linux", "mode": "debug",
                                            "entry_point": "lib/main_v2.dart", "source_commit": "a" * 40,
                                            "source_dirty": False, "flutter": {"frameworkVersion": "fixture"},
                                            "artifacts_sha256": {f"build/linux/x64/debug/bundle/{path.relative_to(self.bundle)}": preview.digest(path)
                                                                 for path in preview.files_under(self.bundle)}}))
        self.archive = self.root / "preview.tar.gz"

    def package(self):
        preview.package(self.bundle, self.metadata, self.archive)
        return smoke.extract(self.archive, self.root / "extracted")

    def test_package_extract_integrity_and_executable_launcher(self):
        extracted = self.package()
        manifest = preview.verify_bundle(extracted)
        self.assertEqual(manifest["source_commit"], "a" * 40)
        self.assertEqual(manifest["entry_point"], "lib/main_v2.dart")
        self.assertTrue(os.access(extracted / "Open-preview.sh", os.X_OK))
        self.assertIn("do NOT survive", (extracted / "PREVIEW.txt").read_text())
        self.assertEqual(self.archive.with_suffix(".gz.sha256").read_text().split()[0], preview.digest(self.archive))

    def test_tampered_bundle_fails_before_launch(self):
        extracted = self.package()
        (extracted / "codewalk").write_bytes(b"tampered")
        with self.assertRaisesRegex(RuntimeError, "integrity"):
            preview.verify_bundle(extracted)

    def test_refuses_archive_overwrite(self):
        self.archive.write_bytes(b"existing")
        with self.assertRaisesRegex(RuntimeError, "overwrite"):
            preview.package(self.bundle, self.metadata, self.archive)
        self.assertEqual(self.archive.read_bytes(), b"existing")

    def test_wrong_compiler_metadata_or_machine_is_rejected(self):
        value = json.loads(self.metadata.read_text())
        value["compiler"] = "fail"
        self.metadata.write_text(json.dumps(value))
        with self.assertRaisesRegex(RuntimeError, "verified"):
            preview.package(self.bundle, self.metadata, self.archive)
        value["compiler"] = "pass"
        self.metadata.write_text(json.dumps(value))
        (self.bundle / "codewalk").write_bytes(b"\x7fELF\x02\x01" + b"\0" * 12 + (183).to_bytes(2, "little"))
        value["artifacts_sha256"]["build/linux/x64/debug/bundle/codewalk"] = preview.digest(self.bundle / "codewalk")
        self.metadata.write_text(json.dumps(value))
        with self.assertRaisesRegex(RuntimeError, "x64"):
            preview.package(self.bundle, self.metadata, self.archive)

    def test_manifest_cannot_omit_files_or_use_a_traversing_commit(self):
        extracted = self.package()
        manifest_file = extracted / "preview-manifest.json"
        manifest = json.loads(manifest_file.read_text())
        manifest["source_commit"] = "../../escape"
        manifest_file.write_text(json.dumps(manifest))
        with self.assertRaisesRegex(RuntimeError, "hexadecimal commit"):
            preview.verify_bundle(extracted)
        manifest["source_commit"] = "a" * 40
        manifest["files_sha256"].pop("codewalk")
        manifest_file.write_text(json.dumps(manifest))
        with self.assertRaisesRegex(RuntimeError, "incomplete"):
            preview.verify_bundle(extracted)

    def test_bundle_external_link_cannot_be_packaged(self):
        external = self.root / "external"
        external.write_bytes(b"private fixture")
        (self.bundle / "lib/external.so").symlink_to(external)
        with self.assertRaisesRegex(RuntimeError, "external symlink"):
            preview.package(self.bundle, self.metadata, self.archive)

    def test_compiler_inventory_rejects_missing_extra_and_modified_files(self):
        kernel = self.bundle / "data/flutter_assets/kernel_blob.bin"
        original = kernel.read_bytes()
        kernel.write_bytes(b"changed after compiler receipt")
        with self.assertRaisesRegex(RuntimeError, "recorded compiler"):
            preview.package(self.bundle, self.metadata, self.archive)
        kernel.write_bytes(original)
        extra = self.bundle / "extra-unverified-file"
        extra.write_bytes(b"extra")
        with self.assertRaisesRegex(RuntimeError, "recorded compiler"):
            preview.package(self.bundle, self.metadata, self.archive)
        extra.unlink()
        kernel.unlink()
        with self.assertRaisesRegex(RuntimeError, "recorded compiler"):
            preview.package(self.bundle, self.metadata, self.archive)

    def test_missing_compiler_hashes_cannot_be_relabelled_as_verified(self):
        metadata = json.loads(self.metadata.read_text())
        metadata.pop("artifacts_sha256")
        self.metadata.write_text(json.dumps(metadata))
        with self.assertRaisesRegex(RuntimeError, "hashes are required"):
            preview.package(self.bundle, self.metadata, self.archive)

    def test_invalid_commit_cannot_select_a_profile_outside_preview_base(self):
        for value in ("/tmp/outside", "../../escape", "", None, "g" * 40):
            with self.subTest(value=value), self.assertRaisesRegex(RuntimeError, "hexadecimal commit"):
                preview.require_commit(value)

    def test_archive_traversal_and_links_are_refused(self):
        for name, link in (("../outside", False), ("/absolute", False), ("codewalk-v2-preview/link", True)):
            with self.subTest(name=name):
                with tarfile.open(self.archive, "w:gz") as archive:
                    member = tarfile.TarInfo(name)
                    if link:
                        member.type = tarfile.SYMTYPE
                        member.linkname = "/outside"
                    archive.addfile(member)
                with self.assertRaisesRegex(RuntimeError, "Unsafe"):
                    smoke.extract(self.archive, self.root / "extract-malicious")
        self.assertFalse((self.root / "outside").exists())

    def test_native_profile_is_distinct_and_persists_nonsecret_files(self):
        profile = self.root / "preview-profile"
        preview.prepare_profile(profile)
        stored = profile / "data/appearance.json"
        stored.write_text('{"dark":true}')
        preview.prepare_profile(profile)
        self.assertEqual(stored.read_text(), '{"dark":true}')
        self.assertEqual(profile.stat().st_mode & 0o777, 0o700)

    def test_existing_nonpreview_data_is_preserved(self):
        profile = self.root / "installed-v1"
        profile.mkdir()
        sentinel = profile / "data.json"
        sentinel.write_bytes(b"preserve")
        with self.assertRaisesRegex(RuntimeError, "non-preview"):
            preview.prepare_profile(profile)
        self.assertEqual(sentinel.read_bytes(), b"preserve")

    def test_profile_symlink_cannot_redirect_to_installed_data(self):
        target = self.root / "installed"
        target.mkdir()
        profile = self.root / "profile-link"
        profile.symlink_to(target)
        with self.assertRaisesRegex(RuntimeError, "symlink"):
            preview.prepare_profile(profile)
        self.assertEqual(list(target.iterdir()), [])

    def test_foreign_and_symlinked_markers_are_rejected_before_chmod(self):
        profile = self.root / "foreign-profile"
        profile.mkdir(mode=0o755)
        marker = profile / preview.PROFILE_MARKER
        marker.write_text('{"kind":"foreign-application"}')
        before = profile.stat().st_mode
        with self.assertRaisesRegex(RuntimeError, "does not identify"):
            preview.prepare_profile(profile)
        self.assertEqual(profile.stat().st_mode, before)
        self.assertEqual(marker.read_text(), '{"kind":"foreign-application"}')
        marker.unlink()
        target = self.root / "external-marker"
        target.write_text(json.dumps({"kind": preview.KIND}))
        marker.symlink_to(target)
        with self.assertRaisesRegex(RuntimeError, "Unsafe profile marker"):
            preview.prepare_profile(profile)
        self.assertEqual(profile.stat().st_mode, before)
        self.assertTrue(marker.is_symlink())

    def test_default_base_symlink_never_writes_into_legacy_data(self):
        data_home = self.root / "data-home"
        data_home.mkdir()
        legacy = self.root / "legacy-data"
        legacy.mkdir(mode=0o755)
        sentinel = legacy / "sentinel"
        sentinel.write_bytes(b"installed data")
        before = legacy.stat().st_mode
        (data_home / "codewalk-v2-preview").symlink_to(legacy)
        with self.assertRaisesRegex(RuntimeError, "base must not be a symlink"):
            preview.default_profile(data_home, "a" * 40)
        self.assertEqual(list(legacy.iterdir()), [sentinel])
        self.assertEqual(sentinel.read_bytes(), b"installed data")
        self.assertEqual(legacy.stat().st_mode, before)

    def test_default_base_accepts_intentional_data_home_link_but_not_foreign_base(self):
        target = self.root / "real-data-home"
        target.mkdir()
        data_home = self.root / "linked-data-home"
        data_home.symlink_to(target)
        profile = preview.default_profile(data_home, "a" * 40)
        preview.prepare_profile(profile)
        self.assertTrue((profile / preview.PROFILE_MARKER).is_file())
        self.assertEqual(preview.default_profile(data_home, "a" * 40), profile)
        (target / "codewalk-v2-preview" / preview.BASE_MARKER).unlink()
        before = (target / "codewalk-v2-preview").stat().st_mode
        with self.assertRaisesRegex(RuntimeError, "not an owned preview base"):
            preview.default_profile(data_home, "b" * 40)
        self.assertEqual((target / "codewalk-v2-preview").stat().st_mode, before)

    def test_private_environment_removes_bus_and_keyring_inheritance(self):
        profile = self.root / "profile"
        runtime = self.root / "runtime"
        inherited = {"HOME": str(self.root), "DISPLAY": ":123", "DBUS_SESSION_BUS_ADDRESS": "host-bus",
                     "DBUS_STARTER_ADDRESS": "host-starter", "GNOME_KEYRING_CONTROL": "host-control"}
        result = preview.isolated_environment(profile, runtime, inherited)
        self.assertFalse(any(k.startswith(("DBUS_", "GNOME_KEYRING_")) for k in result))
        self.assertEqual(result["DISPLAY"], ":123")
        self.assertEqual(result["XDG_DATA_HOME"], str(profile / "data"))
        self.assertEqual(result["XDG_RUNTIME_DIR"], str(runtime))
        self.assertEqual(inherited["DBUS_SESSION_BUS_ADDRESS"], "host-bus")

    def test_missing_private_bus_fails_without_host_fallback(self):
        with mock.patch.dict(os.environ, {}, clear=True), self.assertRaisesRegex(RuntimeError, "Private session bus"):
            preview.private_session(self.bundle, self.root / "profile", self.root / "runtime")

    def test_real_owned_process_group_shutdown_is_bounded(self):
        process = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"], start_new_session=True)
        self.addCleanup(lambda: preview.stop_owned(process))
        preview.stop_owned(process)
        self.assertIsNotNone(process.poll())

    def test_shutdown_tolerates_process_exit_between_poll_and_signal(self):
        process = mock.Mock(pid=12345)
        process.poll.return_value = None
        with mock.patch.object(os, "killpg", side_effect=ProcessLookupError):
            preview.stop_owned(process)
        process.wait.assert_called_once_with(timeout=5)

    def test_dark_rendering_is_not_proved_by_static_label_or_saved_json(self):
        smoke.verify_dark_rendering(0.9, 0.12, 0.13)
        for values in ((0.9, 0.9, 0.9), (0.9, 0.12, 0.8), (0.3, 0.2, 0.2)):
            with self.subTest(values=values), self.assertRaisesRegex(RuntimeError, "Rendered dark"):
                smoke.verify_dark_rendering(*values)

    def test_ocr_control_location_requires_expected_words(self):
        words = [("Appearance", 100, 200), ("App", 300, 400), ("Logs", 350, 400)]
        self.assertEqual(smoke.locate(words, "App Logs"), (300, 400))
        self.assertIsNone(smoke.locate(words, "Dark"))
        self.assertIsNone(smoke.locate(words, "Logs App"))

    def test_compact_checks_reject_wide_geometry_and_visible_master_in_detail(self):
        self.assertTrue(smoke.compact_geometry("WIDTH=480\nHEIGHT=800\n"))
        for values in ("WIDTH=1280\nHEIGHT=720\n", "WIDTH=480\nHEIGHT=720\n", "WIDTH=480\n"):
            self.assertFalse(smoke.compact_geometry(values))
        wide = [("Appearance", 1, 1), ("App", 2, 1), ("Logs", 3, 1), ("Dark", 4, 1)]
        self.assertFalse(smoke.ui_state_matches(wide, ["Appearance", "App Logs"], ["Dark"]))
        self.assertFalse(smoke.ui_state_matches(wide, ["Dark"], ["App Logs"]))
        self.assertTrue(smoke.ui_state_matches(wide[:3], ["Appearance", "App Logs"], ["Dark"]))

    def test_real_appearance_master_caption_does_not_fail_compact_list(self):
        text = "Appearance App Logs Choose light, dark, or system mode then keep the CodeWalk classic palette"
        words = [(word, index, 1) for index, word in enumerate(text.split())]
        self.assertTrue(smoke.ui_state_matches(words, ["Appearance", "App Logs"], ["Visual style"]))
        detail_words = words + [("Visual", 100, 2), ("style", 110, 2)]
        self.assertFalse(smoke.ui_state_matches(detail_words, ["Appearance", "App Logs"], ["Visual style"]))

    def test_ocr_ignores_low_confidence_noise(self):
        text = "text\tconf\tleft\ttop\twidth\theight\nDark\t80\t20\t30\t40\t20\nNoise\t1\t0\t0\t5\t5\n"
        self.assertEqual(smoke.parse_ocr(text), [("Dark", 40, 40, "original", ("", "", "", ""))])

    def test_scaled_colored_button_coordinates_and_line_ids_are_preserved(self):
        text = ("text\tconf\tleft\ttop\twidth\theight\tpage_num\tblock_num\tpar_num\tline_num\n"
                "Pair\t93\t2090\t196\t50\t22\t1\t1\t1\t3\n"
                "a\t93\t2152\t202\t14\t16\t1\t1\t1\t3\n"
                "server\t93\t2178\t202\t88\t16\t1\t1\t1\t3\n")
        words = smoke.parse_ocr(text, scale=2, pass_id="gray-2x")
        self.assertEqual(smoke.locate(words, "Pair a server"), (1058, 104))
        wrong_line = [words[0], (*words[1][:4], ("1", "1", "1", "4")), words[2]]
        self.assertIsNone(smoke.locate(wrong_line, "Pair a server"))
        wrong_pass = [words[0], (*words[1][:3], "other-pass", words[1][4]), words[2]]
        self.assertIsNone(smoke.locate(wrong_pass, "Pair a server"))

    def test_click_prefers_exact_control_case_over_description_word(self):
        words = [("dark,", 10, 20), ("Dark", 100, 200)]
        self.assertEqual(smoke.locate(words, "Dark", prefer_exact=True), (100, 200))
        self.assertEqual(smoke.locate(words, "Dark"), (10, 20))

    def test_bounded_ocr_fallback_finds_filled_control_without_inventing_text(self):
        tsv = ("text\tconf\tleft\ttop\twidth\theight\tpage_num\tblock_num\tpar_num\tline_num\n"
               "Pair\t93\t2090\t196\t50\t22\t1\t1\t1\t3\n")
        calls = []
        def runner(command, **options):
            calls.append(command)
            if command[0] == "convert":
                return ""
            return tsv if "--psm" in command and command[command.index("--psm") + 1] == "6" else tsv.splitlines()[0] + "\n"
        words = smoke.recognize_screenshot(self.root / "screenshot.png", self.root, runner)
        self.assertIsNotNone(smoke.locate(words, "Pair"))
        self.assertIsNone(smoke.locate(words, "Missing control"))
        self.assertEqual(sum(command[0] == "tesseract" for command in calls), 3)
        self.assertEqual(sum(command[0] == "convert" for command in calls), 2)


if __name__ == "__main__":
    unittest.main()
