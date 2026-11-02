#!/usr/bin/env python3
"""
Unit tests for compare_parity.py: strict pair and region handling, manifest
validation, dimension mismatch detection, malformed PNG rejection, and AE diffs.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import compare_parity

DEFAULT_REGIONS = {"toolbar": {"x": 0, "y": 0, "w": 50, "h": 20}}


class TestCompareParity(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp(prefix="test_compare_parity_")
        self.captures_dir = os.path.join(self.tmpdir, "captures")
        os.makedirs(self.captures_dir)
        self.report_path = os.path.join(self.tmpdir, "report.json")

    def tearDown(self):
        shutil.rmtree(self.tmpdir)

    def _create_image(self, filename, width, height, color="white"):
        path = os.path.join(self.captures_dir, filename)
        cmd = ["convert", "-size", f"{width}x{height}", f"xc:{color}", path]
        subprocess.run(cmd, check=True)
        return path

    def _write_manifest(self, pair_id, side, regions):
        path = os.path.join(self.captures_dir, f"{pair_id}_{side}.regions.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump({"regions": regions}, f)

    def _make_pair(self, pair_id="s1_mobile_light", size=(412, 915), v2_size=None,
                   v1_regions=None, v2_regions=None, v2_manifest=True):
        w, h = size
        v2_w, v2_h = v2_size or size
        self._create_image(f"{pair_id}_v1.png", w, h, "white")
        self._create_image(f"{pair_id}_v2.png", v2_w, v2_h, "white")
        self._write_manifest(pair_id, "v1", v1_regions or DEFAULT_REGIONS)
        if v2_manifest:
            self._write_manifest(pair_id, "v2", v2_regions or DEFAULT_REGIONS)

    def _run(self, strict=True):
        return compare_parity.run_comparison(
            captures_dir=self.captures_dir,
            output_report=self.report_path,
            strict=strict,
            expected_pair_ids=compare_parity.discover_pairs(self.captures_dir),
            check_required_regions=False,
        )

    def test_dimensions_check(self):
        img = self._create_image("test.png", 412, 915, "white")
        w, h = compare_parity.get_image_dimensions(img)
        self.assertEqual((w, h), (412, 915))

    def test_ae_metric_formats_and_errors(self):
        for output, expected in [
            ("42", 42),
            ("380890 (0.371963)", 380890),
            ("0 (0)", 0),
            ("1.024e+06 (1)", 1024000),
        ]:
            with self.subTest(output=output), patch.object(compare_parity, "run_cmd", return_value=(1, "", output)):
                self.assertEqual(compare_parity.compare_images("a", "b", "diff"), expected)
        for output in ["12 warning", "4 (1.5)", "NaN", "4 (0.5) warning"]:
            with self.subTest(output=output), patch.object(compare_parity, "run_cmd", return_value=(1, "", output)):
                with self.assertRaises(RuntimeError):
                    compare_parity.compare_images("a", "b", "diff")

    def test_empty_image_fails(self):
        path = os.path.join(self.captures_dir, "empty.png")
        open(path, "w").close()
        with self.assertRaises(ValueError):
            compare_parity.get_image_dimensions(path)

    def test_corrupted_image_fails(self):
        path = os.path.join(self.captures_dir, "corrupt.png")
        with open(path, "wb") as f:
            f.write(b"not a png image header")
        with self.assertRaises(ValueError):
            compare_parity.get_image_dimensions(path)

    def test_identical_images_diff_zero(self):
        img1 = self._create_image("a.png", 100, 100, "white")
        img2 = self._create_image("b.png", 100, 100, "white")
        diff = os.path.join(self.tmpdir, "diff.png")
        ae = compare_parity.compare_images(img1, img2, diff)
        self.assertEqual(ae, 0)

    def test_different_images_diff_positive(self):
        img1 = self._create_image("a.png", 100, 100, "white")
        img2 = self._create_image("b.png", 100, 100, "black")
        diff = os.path.join(self.tmpdir, "diff.png")
        ae = compare_parity.compare_images(img1, img2, diff)
        self.assertEqual(ae, 10000)

    def test_unsupported_format_fails(self):
        jpg_path = os.path.join(self.captures_dir, "test.jpg")
        cmd = ["convert", "-size", "100x100", "xc:white", jpg_path]
        subprocess.run(cmd, check=True)
        with self.assertRaises(ValueError):
            compare_parity.get_image_dimensions(jpg_path)

    def test_no_captures_fails(self):
        with self.assertRaises(FileNotFoundError):
            self._run(strict=True)

    def test_capture_outside_the_matrix_fails_strict(self):
        # The production matrix, not the discovered set, decides what is expected.
        self._make_pair(pair_id="s12_desktop_light", size=(1280, 800))
        with self.assertRaises(ValueError):
            compare_parity.run_comparison(
                captures_dir=self.captures_dir,
                output_report=self.report_path,
                strict=True,
                check_required_regions=False,
            )

    def test_complete_identical_pair_reports_zero_difference(self):
        self._make_pair()
        report = self._run(strict=True)
        self.assertEqual(report["status"], "complete")
        self.assertEqual(report["pairs_count"], 1)
        pair = report["pairs"][0]
        self.assertEqual(pair["diff_percent"], 0.0)
        self.assertEqual(pair["regions"]["toolbar"]["ae"], 0)
        self.assertFalse(pair["regions"]["toolbar"]["size_mismatch"])

    def test_state_with_substate_is_recognized(self):
        self._make_pair(pair_id="s11_project_mobile_light")
        report = self._run(strict=True)
        self.assertEqual(report["pairs_count"], 1)
        self.assertEqual(report["pairs"][0]["pair_id"], "s11_project_mobile_light")

    def test_missing_whole_expected_pair_fails(self):
        self._make_pair()
        with self.assertRaises(FileNotFoundError):
            compare_parity.run_comparison(
                self.captures_dir, self.report_path, check_required_regions=False,
            )

    def test_missing_region_on_both_sides_fails(self):
        self._make_pair(pair_id="s13_busy_mobile_light")
        with self.assertRaisesRegex(ValueError, "missing required regions"):
            compare_parity.run_comparison(
                self.captures_dir, self.report_path,
                expected_pair_ids={"s13_busy_mobile_light"},
            )

    def test_missing_manifest_fails_strict(self):
        self._make_pair(v2_manifest=False)
        with self.assertRaises(FileNotFoundError):
            self._run(strict=True)

    def test_missing_manifest_is_partial_when_not_strict(self):
        self._make_pair(v2_manifest=False)
        report = self._run(strict=False)
        self.assertEqual(report["status"], "partial")
        self.assertEqual(report["missing_count"], 1)
        self.assertEqual(report["pairs_count"], 0)

    def test_missing_region_fails_even_when_not_strict(self):
        self._make_pair(
            v1_regions={"toolbar": DEFAULT_REGIONS["toolbar"], "composer": {"x": 0, "y": 40, "w": 50, "h": 20}},
            v2_regions=DEFAULT_REGIONS,
        )
        with self.assertRaises(ValueError):
            self._run(strict=False)

    def test_region_outside_image_fails(self):
        self._make_pair(v1_regions={"toolbar": {"x": 400, "y": 0, "w": 50, "h": 20}})
        with self.assertRaises(ValueError):
            self._run(strict=True)

    def test_region_size_mismatch_is_a_full_difference(self):
        self._make_pair(v2_regions={"toolbar": {"x": 0, "y": 0, "w": 60, "h": 20}})
        report = self._run(strict=True)
        region = report["pairs"][0]["regions"]["toolbar"]
        self.assertTrue(region["size_mismatch"])
        self.assertIsNone(region["ae"])
        self.assertEqual(region["diff_percent"], 100.0)

    def test_dimension_mismatch_fails_strict(self):
        self._make_pair(v2_size=(412, 905))
        with self.assertRaises(ValueError):
            self._run(strict=True)

    def test_dimension_mismatch_always_fails_non_strict(self):
        self._make_pair(v2_size=(412, 905))
        with self.assertRaises(ValueError):
            self._run(strict=False)

    def test_both_images_wrong_expected_size_fails(self):
        self._make_pair(size=(402, 905))
        with self.assertRaises(ValueError):
            self._run(strict=False)


if __name__ == "__main__":
    unittest.main()
