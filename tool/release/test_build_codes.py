import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

import build_codes
from build_codes import check, fetch_releases, highest_code, load_baseline, releases_after

THROUGH = "2026-10-23T15:21:00Z"


def release(tag, published, assets=("codewalk-android-arm64.apk",), draft=False):
    return {"tag_name": tag, "draft": draft, "published_at": published,
            "assets": [{"name": name} for name in assets]}


HISTORY = [
    release("v1.266.0-native.1", THROUGH),
    release("v1.265.1", "2026-10-02T19:16:01Z"),
]


class BuildCodeTests(unittest.TestCase):
    def setUp(self):
        self.reads = []

    def reader(self, codes):
        def read(tag, name):
            self.reads.append((tag, name))
            return codes[tag]
        return read

    def test_the_recorded_baseline_is_the_published_cohort(self):
        self.assertEqual(load_baseline(), (THROUGH, 1792744369))

    def test_releases_up_to_the_baseline_are_never_downloaded(self):
        self.assertEqual(highest_code(HISTORY, self.reader({})), 1792744369)
        self.assertEqual(self.reads, [])

    def test_a_later_apk_is_read_from_its_actual_bytes(self):
        later = HISTORY + [release("v2.0.0-beta.1", "2026-11-01T00:00:00Z"),
                           release("v1.266.1", "2026-11-02T00:00:00Z")]
        codes = {"v2.0.0-beta.1": 1793500000, "v1.266.1": 1793600000}
        self.assertEqual(highest_code(later, self.reader(codes)), 1793600000)
        self.assertEqual({tag for tag, _ in self.reads}, {"v2.0.0-beta.1", "v1.266.1"})

    def test_drafts_and_releases_without_an_apk_are_skipped(self):
        later = HISTORY + [release("v2.0.0-beta.1", "2026-11-01T00:00:00Z", draft=True),
                           release("v1.266.1", "2026-11-02T00:00:00Z", assets=("codewalk-linux-x64.tar.gz",))]
        self.assertEqual(highest_code(later, self.reader({})), 1792744369)

    def test_a_planned_code_must_exceed_every_published_code(self):
        later = HISTORY + [release("v1.266.1", "2026-11-02T00:00:00Z")]
        read = self.reader({"v1.266.1": 1793600000})
        with self.assertRaisesRegex(ValueError, "not above"):
            check(1793600000, later, read)
        with self.assertRaisesRegex(ValueError, "not above"):
            check(1792744369, HISTORY, read)
        self.assertEqual(check(1793600001, later, read), 1793600000)

    def test_an_unreadable_release_fails_closed(self):
        for bad in (None, "", "2026-11-01", "2026-11-01T00:00:00+00:00"):
            with self.subTest(published=bad), self.assertRaisesRegex(ValueError, "publication time"):
                releases_after([release("v9", bad)], THROUGH)

        def broken(tag, name):
            raise ValueError("no versionCode")
        with self.assertRaises(ValueError):
            check(1800000000, HISTORY + [release("v1.266.1", "2026-11-02T00:00:00Z")], broken)

    def test_every_page_is_requested(self):
        lines = "\n".join(json.dumps(item) for item in HISTORY) + "\n"
        runner = mock.Mock(return_value=mock.Mock(stdout=lines))
        self.assertEqual(fetch_releases("owner/repo", runner), HISTORY)
        command = runner.call_args.args[0]
        self.assertIn("--paginate", command)
        self.assertIn("repos/owner/repo/releases?per_page=100", command)

    def test_the_badging_versioncode_is_parsed(self):
        badging = "package: name='com.verseles.codewalk' versionCode='1792744369' versionName='1.266.0'\n"
        runner = mock.Mock(return_value=mock.Mock(stdout=badging))
        with mock.patch.object(build_codes, "aapt2", return_value="aapt2"):
            self.assertEqual(build_codes.apk_code(Path("a.apk"), runner), 1792744369)
            runner.return_value = mock.Mock(stdout="package: name='x'\n")
            with self.assertRaises(ValueError):
                build_codes.apk_code(Path("a.apk"), runner)

    def test_a_missing_aapt2_fails_closed(self):
        with tempfile.TemporaryDirectory() as empty, mock.patch.dict("os.environ", {"ANDROID_HOME": empty}):
            with self.assertRaisesRegex(ValueError, "aapt2"):
                build_codes.aapt2()


if __name__ == "__main__":
    unittest.main()
