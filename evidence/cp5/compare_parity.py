#!/usr/bin/env python3
"""
Automated visual parity comparator for CodeWalk v1 vs v2 chat screens.
Compares full-screen captures and partitioned regions (header, timeline, composer).
Fails explicitly with non-zero exit code on missing files, malformed PNGs,
dimension mismatches, or command execution errors.
"""

import argparse
import json
import os
import subprocess
import sys

SCENARIOS = [
    {"id": "s1", "title": "Short turn completed"},
    {"id": "s2", "title": "Rich timeline with code and reasoning"},
    {"id": "s5", "title": "Empty session connected"},
]

PLATFORMS = {
    "mobile": {
        "size": (412, 915),
        "regions": {
            "header": "412x80+0+0",
            "timeline": "412x700+0+80",
            "composer": "412x135+0+780",
        },
        "region_pixels": {
            "header": 412 * 80,
            "timeline": 412 * 700,
            "composer": 412 * 135,
        },
    },
    "desktop": {
        "size": (1280, 800),
        "regions": {
            "header": "1280x70+0+0",
            "timeline": "1280x630+0+70",
            "composer": "1280x100+0+700",
        },
        "region_pixels": {
            "header": 1280 * 70,
            "timeline": 1280 * 630,
            "composer": 1280 * 100,
        },
    },
}

THEMES = ["light", "dark"]


def run_cmd(cmd):
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return p.returncode, p.stdout.strip(), p.stderr.strip()


def get_image_dimensions(img_path):
    """Returns (width, height) using identify, or raises ValueError."""
    if not os.path.exists(img_path):
        raise FileNotFoundError(f"File not found: {img_path}")
    if os.path.getsize(img_path) == 0:
        raise ValueError(f"Empty image file (0 bytes): {img_path}")

    code, out, err = run_cmd(["identify", "-format", "%w %h %m", img_path])
    if code != 0 or not out:
        raise ValueError(f"Failed to identify image {img_path}: {err or 'Unknown error'}")

    parts = out.split()
    if len(parts) < 2:
        raise ValueError(f"Unexpected identify output '{out}' for {img_path}")

    try:
        w, h = int(parts[0]), int(parts[1])
    except ValueError as e:
        raise ValueError(f"Invalid dimensions '{out}' for {img_path}: {e}")

    if len(parts) >= 3 and parts[2].upper() != "PNG":
        raise ValueError(f"Unsupported image format '{parts[2]}' for {img_path}; expected PNG")

    return w, h


def compare_images(img1, img2, diff_out):
    """
    Compares two images using ImageMagick compare -metric AE.
    Code 0 = identical (0 AE).
    Code 1 = differences present (AE output on stderr).
    Code 2 or other = command error (raises RuntimeError).
    """
    cmd = ["compare", "-metric", "AE", img1, img2, diff_out]
    code, out, err = run_cmd(cmd)
    if code in (0, 1):
        metric_str = err.strip()
        try:
            return int(float(metric_str))
        except ValueError:
            raise RuntimeError(f"Unable to parse compare AE metric '{metric_str}': {err}")
    raise RuntimeError(f"ImageMagick compare failed with code {code} for {img1} vs {img2}: {err}")


def crop_image(src, crop_geom, dst):
    cmd = ["convert", src, "-crop", crop_geom, "+repage", dst]
    code, out, err = run_cmd(cmd)
    if code != 0:
        raise RuntimeError(f"ImageMagick convert crop failed for {src} ({crop_geom}): {err}")


def create_montage(img1, img2, diff_img, dst):
    cmd = ["montage", img1, img2, diff_img, "-geometry", "+4+4", dst]
    code, out, err = run_cmd(cmd)
    if code != 0:
        raise RuntimeError(f"ImageMagick montage failed for {dst}: {err}")


def run_comparison(captures_dir, output_report, rel_base_dir=None, strict=True):
    if not os.path.isdir(captures_dir):
        raise FileNotFoundError(f"Captures directory does not exist: {captures_dir}")

    out_dir = os.path.dirname(os.path.abspath(output_report))
    if out_dir and not os.path.exists(out_dir):
        os.makedirs(out_dir, exist_ok=True)

    base_dir = rel_base_dir or out_dir
    results = []
    missing_pairs = []
    dimension_errors = []

    for sc in SCENARIOS:
        for plat_name, plat_info in PLATFORMS.items():
            expected_size = plat_info["size"]
            total_pixels = expected_size[0] * expected_size[1]

            for th in THEMES:
                pair_id = f"{sc['id']}_{plat_name}_{th}"
                v1_img = os.path.join(captures_dir, f"{pair_id}_v1.png")
                v2_img = os.path.join(captures_dir, f"{pair_id}_v2.png")

                # Validate existence
                if not os.path.exists(v1_img) or not os.path.exists(v2_img):
                    missing_pairs.append({
                        "pair_id": pair_id,
                        "v1_exists": os.path.exists(v1_img),
                        "v2_exists": os.path.exists(v2_img),
                    })
                    continue

                # Validate integrity and dimensions
                try:
                    w1, h1 = get_image_dimensions(v1_img)
                    w2, h2 = get_image_dimensions(v2_img)
                except Exception as e:
                    raise RuntimeError(f"Validation failed for pair {pair_id}: {e}")

                if (w1, h1) != (w2, h2):
                    raise ValueError(f"Pair {pair_id} dimension mismatch: v1=({w1}, {h1}) vs v2=({w2}, {h2})")
                if (w1, h1) != expected_size:
                    dimension_errors.append(f"{v1_img}: expected {expected_size}, got ({w1}, {h1})")
                if (w2, h2) != expected_size:
                    dimension_errors.append(f"{v2_img}: expected {expected_size}, got ({w2}, {h2})")

                if dimension_errors and strict:
                    raise ValueError(f"Dimension errors detected: {dimension_errors[-1]}")

                diff_img = os.path.join(captures_dir, f"{pair_id}_diff.png")
                montage_img = os.path.join(captures_dir, f"{pair_id}_montage.png")

                ae_total = compare_images(v1_img, v2_img, diff_img)
                diff_pct = (ae_total / total_pixels) * 100.0 if total_pixels > 0 else 0.0

                create_montage(v1_img, v2_img, diff_img, montage_img)

                region_stats = {}
                for r_name, r_geom in plat_info["regions"].items():
                    v1_crop = os.path.join(captures_dir, f"{pair_id}_v1_{r_name}.png")
                    v2_crop = os.path.join(captures_dir, f"{pair_id}_v2_{r_name}.png")
                    diff_crop = os.path.join(captures_dir, f"{pair_id}_diff_{r_name}.png")

                    crop_image(v1_img, r_geom, v1_crop)
                    crop_image(v2_img, r_geom, v2_crop)

                    r_ae = compare_images(v1_crop, v2_crop, diff_crop)
                    r_pixels = plat_info["region_pixels"][r_name]
                    r_pct = (r_ae / r_pixels) * 100.0 if r_pixels > 0 else 0.0

                    region_stats[r_name] = {
                        "ae": r_ae,
                        "pixels": r_pixels,
                        "diff_percent": round(r_pct, 2),
                        "crop_v1": os.path.relpath(v1_crop, base_dir),
                        "crop_v2": os.path.relpath(v2_crop, base_dir),
                        "crop_diff": os.path.relpath(diff_crop, base_dir),
                    }

                record = {
                    "scenario": sc["id"],
                    "title": sc["title"],
                    "platform": plat_name,
                    "theme": th,
                    "resolution": f"{expected_size[0]}x{expected_size[1]}",
                    "total_pixels": total_pixels,
                    "ae_total": ae_total,
                    "diff_percent": round(diff_pct, 2),
                    "v1_image": os.path.relpath(v1_img, base_dir),
                    "v2_image": os.path.relpath(v2_img, base_dir),
                    "diff_image": os.path.relpath(diff_img, base_dir),
                    "montage_image": os.path.relpath(montage_img, base_dir),
                    "regions": region_stats,
                }
                results.append(record)

    if missing_pairs and strict:
        details = ", ".join(m["pair_id"] for m in missing_pairs)
        raise FileNotFoundError(f"Missing required parity pairs ({len(missing_pairs)}): {details}")

    if dimension_errors and strict:
        raise ValueError(f"Dimension errors ({len(dimension_errors)}): {dimension_errors}")

    report = {
        "status": "complete" if not missing_pairs else "partial",
        "pairs_count": len(results),
        "missing_count": len(missing_pairs),
        "pairs": results,
    }

    with open(output_report, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)

    return report


def main():
    parser = argparse.ArgumentParser(description="CodeWalk v1 vs v2 Parity Comparator")
    parser.add_argument("--captures-dir", "-c", required=True, help="Directory containing capture PNGs")
    parser.add_argument("--output", "-o", required=True, help="Path to output parity_report.json")
    parser.add_argument("--base-dir", "-b", default=None, help="Base directory for relative paths in report")
    parser.add_argument("--allow-missing", action="store_true", help="Allow missing pairs (non-strict mode)")
    args = parser.parse_args()

    try:
        report = run_comparison(
            captures_dir=args.captures_dir,
            output_report=args.output,
            rel_base_dir=args.base_dir,
            strict=not args.allow_missing,
        )
        print(f"Parity report successfully written to {args.output} ({report['pairs_count']} pairs)")
        sys.exit(0)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
