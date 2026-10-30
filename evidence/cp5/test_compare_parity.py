#!/usr/bin/env python3
"""
Unit tests for compare_parity.py verifying strict error handling,
dimension mismatch detection, malformed PNG rejection, and accurate AE diff calculation.
"""

import os
import shutil
import subprocess
import sys
import tempfile
import unittest

import compare_parity


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

    def test_dimensions_check(self):
        img = self._create_image("test.png", 412, 915, "white")
        w, h = compare_parity.get_image_dimensions(img)
        self.assertEqual((w, h), (412, 915))

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

    def test_strict_mode_fails_on_missing_pairs(self):
        with self.assertRaises(FileNotFoundError):
            compare_parity.run_comparison(
                captures_dir=self.captures_dir,
                output_report=self.report_path,
                strict=True,
            )

    def test_dimension_mismatch_fails_strict(self):
        # Create all images, but one has wrong height
        for sc in compare_parity.SCENARIOS:
            for plat_name, plat_info in compare_parity.PLATFORMS.items():
                w, h = plat_info["size"]
                for th in compare_parity.THEMES:
                    pair_id = f"{sc['id']}_{plat_name}_{th}"
                    self._create_image(f"{pair_id}_v1.png", w, h, "white")
                    # Break dimension for s1_mobile_light_v2
                    if pair_id == "s1_mobile_light":
                        self._create_image(f"{pair_id}_v2.png", w, h - 10, "white")
                    else:
                        self._create_image(f"{pair_id}_v2.png", w, h, "white")

        with self.assertRaises(ValueError):
            compare_parity.run_comparison(
                captures_dir=self.captures_dir,
                output_report=self.report_path,
                strict=True,
            )

    def test_dimension_mismatch_always_fails_non_strict(self):
        # Even with strict=False, mismatched dimensions between v1 and v2 must fail
        for sc in compare_parity.SCENARIOS:
            for plat_name, plat_info in compare_parity.PLATFORMS.items():
                w, h = plat_info["size"]
                for th in compare_parity.THEMES:
                    pair_id = f"{sc['id']}_{plat_name}_{th}"
                    self._create_image(f"{pair_id}_v1.png", w, h, "white")
                    if pair_id == "s1_mobile_light":
                        self._create_image(f"{pair_id}_v2.png", w, h - 10, "white")
                    else:
                        self._create_image(f"{pair_id}_v2.png", w, h, "white")

        with self.assertRaises(ValueError):
            compare_parity.run_comparison(
                captures_dir=self.captures_dir,
                output_report=self.report_path,
                strict=False,
            )

    def test_unsupported_format_fails(self):
        # Create a non-PNG image
        jpg_path = os.path.join(self.captures_dir, "test.jpg")
        cmd = ["convert", "-size", "100x100", "xc:white", jpg_path]
        subprocess.run(cmd, check=True)
        with self.assertRaises(ValueError):
            compare_parity.get_image_dimensions(jpg_path)


if __name__ == "__main__":
    unittest.main()
