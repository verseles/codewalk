"""Regression tests for fresh, deterministic LCOV gating; no Flutter required."""

from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("check_coverage.sh")
ROOT = SCRIPT.resolve().parents[2]


def record(source="lib/example.dart", hits=(1, 0)):
    return "\n".join([
        f"SF:{source}",
        *(f"DA:{number},{count}" for number, count in enumerate(hits, 1)),
        f"LF:{len(hits)}", f"LH:{sum(count > 0 for count in hits)}",
        "end_of_record", "",
    ])


class CoverageGateTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="coverage-gate-")
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.raw = self.directory / "raw.info"
        self.output = self.directory / "filtered.info"
        self.policy = self.directory / "baseline.tsv"
        self.policy.write_text("", encoding="utf-8")

    def run_gate(self, data, minimum="50", baseline=""):
        if data is not None:
            self.raw.write_text(data, encoding="utf-8")
        self.policy.write_text(baseline, encoding="utf-8")
        return subprocess.run(
            ["bash", str(SCRIPT), str(self.raw), minimum, str(self.output), str(self.policy)],
            capture_output=True, text=True, check=False,
        )

    def test_accepts_exact_threshold_and_publishes_fresh_report(self):
        result = self.run_gate(record())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.output.read_text(), record())

    def test_stale_high_coverage_never_overrides_current_low_coverage(self):
        self.output.write_text(record(hits=(1, 1)), encoding="utf-8")
        result = self.run_gate(record(hits=(0, 0)))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("0.00%", result.stdout)
        self.assertEqual(self.output.read_text(), record(hits=(0, 0)))

    def test_filters_generated_sources_without_lcov(self):
        data = record() + record("lib/data/model.g.dart", (0,) * 10)
        data += record("lib/l10n/generated/app_en.dart", (0,) * 10)
        data += record("lib/generated_plugin_registrant.dart", (0,) * 10)
        result = self.run_gate(data)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.output.read_text(), record())

    def test_absolute_sources_share_the_same_policy_and_exclusions(self):
        data = record(str(ROOT / "lib/example.dart"))
        data += record(str(ROOT / "lib/l10n/app.dart"), (0,) * 10)
        result = self.run_gate(data, baseline="lib/example.dart 50\n")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_missing_and_empty_reports_fail(self):
        for data in (None, "", record(hits=())):
            with self.subTest(data=data):
                self.assertNotEqual(self.run_gate(data).returncode, 0)

    def test_malformed_or_unterminated_records_fail(self):
        for data in (
            record().replace("DA:1,1", "DA:1,-1"),
            record().replace("LF:2", "LF:99"),
            record().replace("LH:1", "LH:9"),
            record().replace("end_of_record\n", ""),
            record().replace("DA:1,1", "DA:one,1"),
            record().replace("LF:2\n", ""),
            record().replace("LH:1\n", ""),
            record().replace("LF:2\nLH:1\n", ""),
            record() + record(),
        ):
            with self.subTest(data=data):
                self.assertNotEqual(self.run_gate(data).returncode, 0)

    def test_invalid_thresholds_fail(self):
        for minimum in ("nan", "Infinity", "-1", "101", "invalid"):
            with self.subTest(minimum=minimum):
                self.assertNotEqual(self.run_gate(record(), minimum).returncode, 0)

    def test_foreign_sources_cannot_inflate_project_coverage(self):
        for source in (
            "test/example.dart", "/tmp/other/lib/example.dart", "../lib/example.dart",
            "lib/../outside.dart", "lib/nested/../../outside.dart",
        ):
            with self.subTest(source=source):
                data = record(hits=(0, 0)) + record(source, (1,) * 10)
                result = self.run_gate(data)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.output.exists())

    def test_normalizes_equivalent_relative_sources(self):
        result = self.run_gate(record("./lib//example.dart"), baseline="lib/example.dart 50\n")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_output_cannot_overwrite_raw_input(self):
        self.output = self.raw
        result = self.run_gate(record())
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.raw.read_text(), record())

    def test_output_cannot_overwrite_policy(self):
        self.output = self.policy
        baseline = "lib/example.dart 50\n"
        result = self.run_gate(record(), baseline=baseline)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.policy.read_text(), baseline)

    def test_rounding_does_not_pass_a_below_threshold_report(self):
        result = self.run_gate(record(hits=(1, 1, 0)), "66.67")
        self.assertNotEqual(result.returncode, 0)

    def test_protected_file_must_exist_and_meet_its_floor(self):
        for baseline in ("lib/missing.dart 1\n", "lib/example.dart 51\n"):
            with self.subTest(baseline=baseline):
                self.assertNotEqual(self.run_gate(record(), baseline=baseline).returncode, 0)

    def test_invalid_baselines_fail(self):
        for baseline in (
            "lib/example.dart nan\n", "lib/example.dart\n",
            "lib/example.dart 1\nlib/example.dart 2\n", "lib/data/model.g.dart 1\n",
        ):
            with self.subTest(baseline=baseline):
                self.assertNotEqual(self.run_gate(record(), baseline=baseline).returncode, 0)


if __name__ == "__main__":
    unittest.main()
