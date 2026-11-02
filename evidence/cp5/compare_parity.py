#!/usr/bin/env python3
"""
Automated visual parity comparator for CodeWalk v1 vs v2 captures.

Each capture pair is <state>_<platform>_<theme> with a PNG and a regions
manifest per side (<pair>_v1.regions.json, <pair>_v2.regions.json). The
parity suite exports the region rectangles from widget geometry. The
comparator discovers pairs from the manifests and fails on any missing pair,
image, manifest, or region. Region sizes that differ between sides are
reported as full differences.
"""

import argparse
import json
import os
import re
import subprocess
import sys

PLATFORMS = {
    "mobile": {"size": (412, 915)},
    "desktop": {"size": (1280, 800)},
}

THEMES = ["light", "dark"]

STATES = ("s1", "s2", "s5", "s6", "s7", "s8", "s9", "s10",
          "s11_session", "s11_project", "s13_empty", "s13_multiline", "s13_busy")
EXPECTED_PAIRS = {
    f"{state}_{platform}_{theme}"
    for state in STATES
    for platform in PLATFORMS
    for theme in THEMES
} | {f"s12_mobile_{theme}" for theme in THEMES}

PAIR_RE = re.compile(r"^(?P<state>[a-z0-9]+(?:_[a-z0-9]+)*)_(?P<platform>mobile|desktop)_(?P<theme>light|dark)$")
MANIFEST_SUFFIX = ".regions.json"


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
        # ImageMagick prints large counts in %g notation, e.g. "1.024e+06 (1)".
        match = re.fullmatch(r"(\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)(?:\s+\((\d*\.?\d+(?:[eE][+-]?\d+)?)\))?", metric_str)
        if match and (match.group(2) is None or 0 <= float(match.group(2)) <= 1):
            return int(round(float(match.group(1))))
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


def load_regions(manifest_path):
    """Returns {name: (x, y, w, h)} in integer pixels, or raises ValueError."""
    try:
        with open(manifest_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        raise ValueError(f"Unreadable regions manifest {manifest_path}: {e}")

    regions = data.get("regions") if isinstance(data, dict) else None
    if not isinstance(regions, dict):
        raise ValueError(f"Regions manifest without a 'regions' object: {manifest_path}")

    parsed = {}
    for name, rect in regions.items():
        try:
            x, y = round(float(rect["x"])), round(float(rect["y"]))
            w, h = round(float(rect["w"])), round(float(rect["h"]))
        except (KeyError, TypeError, ValueError) as e:
            raise ValueError(f"Malformed region '{name}' in {manifest_path}: {e}")
        if w <= 0 or h <= 0:
            raise ValueError(f"Empty region '{name}' in {manifest_path}: {w}x{h}")
        parsed[name] = (x, y, w, h)
    return parsed


def region_geometry(rect):
    x, y, w, h = rect
    return f"{w}x{h}+{x}+{y}"


def discover_pairs(captures_dir):
    """Pair ids from any side's image or manifest, so a lone file is reported as missing."""
    pairs = set()
    for name in os.listdir(captures_dir):
        for side in ("v1", "v2"):
            for suffix in (f"_{side}.png", f"_{side}{MANIFEST_SUFFIX}"):
                if name.endswith(suffix):
                    pairs.add(name[: -len(suffix)])
    return sorted(pairs)


def required_regions(state, platform):
    regions = {"toolbar"}
    if platform == "desktop" or state in {"s8", "s11_session", "s11_project"}:
        regions.add("side_panel")
    if state in {"s1", "s2", "s5", "s7", "s9", "s10", "s13_empty", "s13_multiline", "s13_busy"}:
        regions.add("composer")
    if state in {"s1", "s2", "s7", "s13_busy"}:
        regions.add("timeline")
    if state in {"s9", "s10"}:
        regions.add("tabs")
    if state in {"s10", "s11_session", "s11_project", "s12"}:
        regions.add("overlay")
    return regions


def run_comparison(captures_dir, output_report, rel_base_dir=None, strict=True, expected_pair_ids=None, check_required_regions=True):
    if not os.path.isdir(captures_dir):
        raise FileNotFoundError(f"Captures directory does not exist: {captures_dir}")

    out_dir = os.path.dirname(os.path.abspath(output_report))
    if out_dir and not os.path.exists(out_dir):
        os.makedirs(out_dir, exist_ok=True)

    base_dir = rel_base_dir or out_dir
    discovered = discover_pairs(captures_dir)
    if not discovered:
        raise FileNotFoundError(f"No parity captures found in {captures_dir}")
    expected = EXPECTED_PAIRS if expected_pair_ids is None else set(expected_pair_ids)
    unexpected = sorted(set(discovered) - expected)
    if unexpected and strict:
        raise ValueError(f"Captures outside the expected matrix: {', '.join(unexpected)}")
    pair_ids = sorted(set(discovered) | expected)

    results = []
    missing_pairs = []

    for pair_id in pair_ids:
        match = PAIR_RE.match(pair_id)
        if not match:
            raise ValueError(f"Unrecognized parity pair id: {pair_id}")
        plat_name, th = match.group("platform"), match.group("theme")
        expected_size = PLATFORMS[plat_name]["size"]
        total_pixels = expected_size[0] * expected_size[1]

        v1_img = os.path.join(captures_dir, f"{pair_id}_v1.png")
        v2_img = os.path.join(captures_dir, f"{pair_id}_v2.png")
        v1_manifest = os.path.join(captures_dir, f"{pair_id}_v1{MANIFEST_SUFFIX}")
        v2_manifest = os.path.join(captures_dir, f"{pair_id}_v2{MANIFEST_SUFFIX}")

        presence = {
            "v1_image": os.path.exists(v1_img),
            "v2_image": os.path.exists(v2_img),
            "v1_manifest": os.path.exists(v1_manifest),
            "v2_manifest": os.path.exists(v2_manifest),
        }
        if not all(presence.values()):
            missing_pairs.append({"pair_id": pair_id, **presence})
            continue

        try:
            w1, h1 = get_image_dimensions(v1_img)
            w2, h2 = get_image_dimensions(v2_img)
        except Exception as e:
            raise RuntimeError(f"Validation failed for pair {pair_id}: {e}")

        if (w1, h1) != (w2, h2):
            raise ValueError(f"Pair {pair_id} dimension mismatch: v1=({w1}, {h1}) vs v2=({w2}, {h2})")
        if (w1, h1) != expected_size:
            raise ValueError(f"{v1_img}: expected {expected_size}, got ({w1}, {h1})")

        v1_regions = load_regions(v1_manifest)
        v2_regions = load_regions(v2_manifest)
        if set(v1_regions) != set(v2_regions):
            only_v1 = sorted(set(v1_regions) - set(v2_regions))
            only_v2 = sorted(set(v2_regions) - set(v1_regions))
            raise ValueError(f"Pair {pair_id} region sets differ: only v1={only_v1}, only v2={only_v2}")
        if check_required_regions:
            missing = required_regions(match.group("state"), plat_name) - set(v1_regions)
            if missing:
                raise ValueError(f"Pair {pair_id} missing required regions: {sorted(missing)}")
        for side, regions, size in (("v1", v1_regions, (w1, h1)), ("v2", v2_regions, (w2, h2))):
            for r_name, (x, y, w, h) in regions.items():
                if x < 0 or y < 0 or x + w > size[0] or y + h > size[1]:
                    raise ValueError(f"Pair {pair_id} {side} region '{r_name}' outside {size}: {x},{y} {w}x{h}")

        diff_img = os.path.join(captures_dir, f"{pair_id}_diff.png")
        montage_img = os.path.join(captures_dir, f"{pair_id}_montage.png")

        ae_total = compare_images(v1_img, v2_img, diff_img)
        diff_pct = (ae_total / total_pixels) * 100.0 if total_pixels > 0 else 0.0

        create_montage(v1_img, v2_img, diff_img, montage_img)

        region_stats = {}
        for r_name in sorted(v1_regions):
            v1_rect, v2_rect = v1_regions[r_name], v2_regions[r_name]
            v1_crop = os.path.join(captures_dir, f"{pair_id}_v1_{r_name}.png")
            v2_crop = os.path.join(captures_dir, f"{pair_id}_v2_{r_name}.png")
            diff_crop = os.path.join(captures_dir, f"{pair_id}_diff_{r_name}.png")

            crop_image(v1_img, region_geometry(v1_rect), v1_crop)
            crop_image(v2_img, region_geometry(v2_rect), v2_crop)

            region_pixels = v1_rect[2] * v1_rect[3]
            size_mismatch = (v1_rect[2], v1_rect[3]) != (v2_rect[2], v2_rect[3])
            if size_mismatch:
                r_ae = None
                r_pct = 100.0
            else:
                r_ae = compare_images(v1_crop, v2_crop, diff_crop)
                r_pct = (r_ae / region_pixels) * 100.0

            region_stats[r_name] = {
                "v1_rect": {"x": v1_rect[0], "y": v1_rect[1], "w": v1_rect[2], "h": v1_rect[3]},
                "v2_rect": {"x": v2_rect[0], "y": v2_rect[1], "w": v2_rect[2], "h": v2_rect[3]},
                "size_mismatch": size_mismatch,
                "ae": r_ae,
                "pixels": region_pixels,
                "diff_percent": round(r_pct, 2),
                "crop_v1": os.path.relpath(v1_crop, base_dir),
                "crop_v2": os.path.relpath(v2_crop, base_dir),
                "crop_diff": None if size_mismatch else os.path.relpath(diff_crop, base_dir),
            }

        record = {
            "pair_id": pair_id,
            "state": match.group("state"),
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

    report = {
        "status": "complete" if not missing_pairs else "partial",
        "pairs_count": len(results),
        "missing_count": len(missing_pairs),
        "missing_pairs": missing_pairs,
        "pairs": results,
    }

    with open(output_report, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)

    return report


def main():
    parser = argparse.ArgumentParser(description="CodeWalk v1 vs v2 Parity Comparator")
    parser.add_argument("--captures-dir", "-c", required=True, help="Directory containing capture PNGs and manifests")
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
