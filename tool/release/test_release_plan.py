import unittest

from release_plan import plan

PUBSPEC = "name: codewalk\nversion: 1.266.0+1791000000\n"


class ReleasePlanTests(unittest.TestCase):
    def test_a_stable_tag_publishes_everything(self):
        self.assertEqual(plan("tag", "v1.266.0", PUBSPEC), "stable")

    def test_a_native_cohort_tag_is_the_cohort(self):
        self.assertEqual(plan("tag", "v1.266.0-native.1", PUBSPEC), "native")
        self.assertEqual(plan("tag", "v1.266.0-native.12", PUBSPEC), "native")

    def test_everything_else_publishes_nothing(self):
        for ref in (
            "v2.0.0-beta.1",
            "v1.266.0-native",
            "v1.266.0-native.01",
            "v1.266.0-native.1.2",
            "v1.266.0-rc.1",
            "v1.266",
            "1.266.0",
            "v01.266.0",
            "v2.266.0-native.1",
        ):
            with self.subTest(ref=ref), self.assertRaises(ValueError):
                plan("tag", ref, PUBSPEC.replace("1.266.0", ref.lstrip("v").split("-")[0]))

    def test_a_branch_publishes_nothing(self):
        with self.assertRaises(ValueError):
            plan("branch", "v1", PUBSPEC)

    def test_the_tag_must_match_the_pubspec_version(self):
        with self.assertRaises(ValueError):
            plan("tag", "v1.266.1", PUBSPEC)
        with self.assertRaises(ValueError):
            plan("tag", "v1.265.0-native.1", PUBSPEC)
        with self.assertRaises(ValueError):
            plan("tag", "v1.266.0", "name: codewalk\n")


if __name__ == "__main__":
    unittest.main()
