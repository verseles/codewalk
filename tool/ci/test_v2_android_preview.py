import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tool.ci import smoke_v2_android_preview as smoke


class AndroidPreviewSmokeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.apk = self.root / "app-x86_64-profile.apk"
        self.apk.write_bytes(b"x86_64 split fixture")
        self.evidence = self.root / "android-preview.json"
        self.record(smoke.native.sha256(self.apk))

    def record(self, digest, **changes):
        value = {"target": "android-preview", "compiler": "pass", "source_commit": "a" * 40,
                 "artifacts_sha256": {smoke.SPLIT: digest}}
        value.update(changes)
        self.evidence.write_text(json.dumps(value))

    def test_launched_split_must_be_the_recorded_one(self):
        self.assertEqual(smoke.same_build(self.apk, self.evidence)["source_commit"], "a" * 40)
        self.record("0" * 64)
        with self.assertRaisesRegex(RuntimeError, "not the split"):
            smoke.same_build(self.apk, self.evidence)

    def test_unverified_or_other_build_record_is_refused(self):
        for changes in ({"compiler": "fail"}, {"target": "android"}):
            with self.subTest(changes=changes):
                self.record(smoke.native.sha256(self.apk), **changes)
                with self.assertRaisesRegex(RuntimeError, "verified preview build"):
                    smoke.same_build(self.apk, self.evidence)

    def test_crashes_of_the_preview_and_unhandled_flutter_errors_are_found(self):
        package = smoke.native.PREVIEW_APPLICATION_ID
        logcat = "\n".join([
            "10-22 05:40:01.100  1200  1200 I ActivityTaskManager: Displayed com.verseles.codewalk.v2preview",
            "10-22 05:40:02.100  1300  1300 E flutter : [ERROR] Unhandled Exception: Bad state",
            "10-22 05:40:03.100  1300  1300 E AndroidRuntime: FATAL EXCEPTION: main",
            "10-22 05:40:03.101  1300  1300 E AndroidRuntime: Process: com.verseles.codewalk.v2preview, PID: 1300",
            "10-22 05:40:04.100  1500  1500 F DEBUG   : pid: 1500, tid: 1500, name: 1.ui  >>> com.verseles.codewalk.v2preview <<<",
        ])
        found = smoke.crash_lines(logcat, package)
        self.assertEqual(len(found), 3)
        self.assertNotIn("FATAL EXCEPTION: main", "\n".join(found))
        self.assertEqual(smoke.crash_lines(logcat.splitlines()[0], package), [])

    def test_a_crash_of_another_process_is_not_the_preview(self):
        logcat = "\n".join([
            "10-22 05:40:03.100  1400  1400 E AndroidRuntime: FATAL EXCEPTION: main",
            "10-22 05:40:03.101  1400  1400 E AndroidRuntime: Process: com.google.android.gms, PID: 1400",
            "10-22 05:40:04.100  1600  1600 F DEBUG   : pid: 1600, tid: 1600, name: binder  >>> system_server <<<",
        ])
        self.assertEqual(smoke.crash_lines(logcat, smoke.native.PREVIEW_APPLICATION_ID), [])

    def test_the_preview_must_be_the_activity_in_front(self):
        package = smoke.native.PREVIEW_APPLICATION_ID
        current = ("  topResumedActivity=ActivityRecord{3c1 u0 "
                   "com.verseles.codewalk.v2preview/com.verseles.codewalk.MainActivity t12}\n")
        legacy = ("    mResumedActivity: ActivityRecord{3c1 u0 "
                  "com.verseles.codewalk.v2preview/com.verseles.codewalk.MainActivity t12}\n")
        self.assertTrue(smoke.in_front(current, package))
        self.assertTrue(smoke.in_front(legacy, package))
        launcher = ("  topResumedActivity=ActivityRecord{3c1 u0 "
                    "com.google.android.apps.nexuslauncher/.NexusLauncherActivity t1}\n"
                    "  * Task{12 type=standard A=com.verseles.codewalk.v2preview}\n")
        self.assertFalse(smoke.in_front(launcher, package))
        # The production app in front is not the preview.
        production = ("  topResumedActivity=ActivityRecord{3c1 u0 "
                      "com.verseles.codewalk/.MainActivity t9}\n")
        self.assertFalse(smoke.in_front(production, package))

    def test_a_blank_screen_is_not_a_launch(self):
        smoke.rendered(0.2)
        with self.assertRaisesRegex(RuntimeError, "drew no screen"):
            smoke.rendered(0.001)


if __name__ == "__main__":
    unittest.main()
