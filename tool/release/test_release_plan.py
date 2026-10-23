import unittest

from release_plan import plan

BETA = "version: 2.0.0-beta.3+1792800000\n"
LEGACY = "version: 1.265.0+1790827338\n"


class ReleasePlanTests(unittest.TestCase):
    def test_a_matching_beta_tag_publishes_with_the_arm64_code(self):
        for event in ("push", "workflow_dispatch"):
            with self.subTest(event=event):
                self.assertEqual(plan(event, "tag", "v2.0.0-beta.3", BETA), {
                    "publish": "true", "version": "2.0.0-beta.3",
                    "build_number": "1792800000", "apk_version_code": "1792802000",
                })

    def test_every_other_tag_is_refused(self):
        for tag in ("v1.266.0", "v2.0.0", "v1.266.0-native.1", "v2.0.0-native.1", "v2.0.0-rc.1",
                    "v2.0.1-beta.1", "v3.0.0-beta.1", "v2.0.0-beta.0", "v2.0.0-beta.03",
                    "v2.0.0-beta.3 ", "2.0.0-beta.3", "v2.0.0-beta.3+1", "v2.0.0-beta"):
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                plan("push", "tag", tag, BETA)

    def test_a_tag_must_match_the_pubspec(self):
        with self.assertRaisesRegex(ValueError, "does not match"):
            plan("push", "tag", "v2.0.0-beta.4", BETA)
        with self.assertRaisesRegex(ValueError, "does not match"):
            plan("push", "tag", "v2.0.0-beta.1", LEGACY)

    def test_a_tag_takes_no_dry_run_version(self):
        with self.assertRaisesRegex(ValueError, "dry-run"):
            plan("workflow_dispatch", "tag", "v2.0.0-beta.3", BETA, "2.0.0-beta.3")

    def test_a_main_dispatch_is_a_dry_run_that_never_publishes(self):
        result = plan("workflow_dispatch", "branch", "main", LEGACY, "2.0.0-beta.1", now=1792775859)
        self.assertEqual(result, {"publish": "false", "version": "2.0.0-beta.1",
                                  "build_number": "1792775859", "apk_version_code": "1792777859"})
        # The build number never drops below the pubspec's.
        self.assertEqual(plan("workflow_dispatch", "branch", "main", BETA, "2.0.0-beta.4", now=1)["build_number"],
                         "1792800001")

    def test_a_dry_run_needs_a_beta_version(self):
        for version in ("", "2.0.0", "1.266.0", "2.0.0-beta.0", "v2.0.0-beta.1"):
            with self.subTest(version=version), self.assertRaises(ValueError):
                plan("workflow_dispatch", "branch", "main", LEGACY, version)

    def test_branches_and_other_events_publish_nothing(self):
        for event, ref_type, ref in (("push", "branch", "main"), ("workflow_dispatch", "branch", "v1"),
                                     ("workflow_dispatch", "branch", "feature"), ("schedule", "tag", "v2.0.0-beta.3"),
                                     ("pull_request", "branch", "main")):
            with self.subTest(event=event, ref=ref), self.assertRaises(ValueError):
                plan(event, ref_type, ref, BETA, "2.0.0-beta.4")

    def test_a_pubspec_without_a_build_number_is_refused(self):
        with self.assertRaisesRegex(ValueError, "pubspec"):
            plan("push", "tag", "v2.0.0-beta.3", "version: 2.0.0-beta.3\n")

    def test_a_code_above_the_android_limit_is_refused(self):
        with self.assertRaisesRegex(ValueError, "exceeds"):
            plan("push", "tag", "v2.0.0-beta.3", "version: 2.0.0-beta.3+2099999000\n")


if __name__ == "__main__":
    unittest.main()
