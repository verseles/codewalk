#!/usr/bin/env python3
"""Discover and check the active v2 packages and explicit Flutter entry point.

This target is separate from the retained-reference root suite. It establishes
the V2-020A package graph; the full platform/test lifecycle belongs to V2-020C.
"""

import argparse
import json
from pathlib import Path
import shlex
import subprocess


ROOT = Path(__file__).resolve().parents[2]


def run(command, cwd=ROOT, *, capture=False):
    relative = cwd.relative_to(ROOT)
    print(f"[{relative}] {shlex.join(command)}", flush=True)
    result = subprocess.run(
        command, cwd=cwd, check=True, text=True, capture_output=capture
    )
    return result.stdout if capture else None


def discover_packages(root, listing):
    packages = []
    names = set()
    paths = set()
    for package in listing["packages"]:
        path = Path(package["path"]).resolve()
        if path == root:
            continue
        if not path.is_relative_to(root / "packages"):
            raise RuntimeError(f"Unexpected workspace package outside packages/: {path}")
        if path in paths or package["name"] in names:
            raise RuntimeError("Duplicate workspace package name or path.")
        names.add(package["name"])
        paths.add(path)
        packages.append((package["name"], path))

    discovered = {path for _, path in packages}
    on_disk = {path.parent.resolve() for path in (root / "packages").glob("*/pubspec.yaml")}
    if not packages or discovered != on_disk:
        raise RuntimeError("Workspace discovery does not cover every package pubspec.")
    return sorted(packages)


def check(root=ROOT, *, profile="full", no_build=False, runner=run):
    if profile not in {"full", "native"}:
        raise ValueError("Unknown v2 check profile.")
    if not (root / "lib/main_v2.dart").is_file():
        raise RuntimeError("Missing explicit v2 entry point: lib/main_v2.dart")
    runner(["dart", "run", "tool/ci/import_rules.dart"], root)
    listing = json.loads(runner(
        ["dart", "pub", "workspace", "list", "--json"], root, capture=True
    ))
    packages = discover_packages(root, listing)
    for name, path in packages:
        if not any((path / "test").rglob("*_test.dart")):
            raise RuntimeError(f"No discoverable tests in workspace package {name}")
        print(f"Active v2 package: {name}", flush=True)
        runner(["dart", "analyze", "--fatal-infos"], path)
        runner(["dart", "test"], path)

    runner(["dart", "test", "tool/ci/test/import_rules_test.dart"], root)
    runner(["python3", "tool/l10n/generate_v2_localizations.py", "--check"], root)
    app_paths = [
        path for path in ("lib/app", "lib/features", "lib/platform", "lib/shared")
        if (root / path).is_dir()
    ]
    tests = ["test/v2", "test/contract/chp"]
    for directory in tests:
        if not any((root / directory).rglob("*_test.dart")):
            raise RuntimeError(f"Missing authored-v2 tests: {directory}")
    runner(["flutter", "analyze", "--no-pub", *app_paths, "lib/main_v2.dart", *tests], root)
    runner(["flutter", "test", "--no-pub", *tests], root)
    if profile == "full":
        runner(["flutter", "test", "--no-pub", "--platform", "chrome", "test/v2"], root)
    if profile == "full" and not no_build:
        runner([
            "flutter", "build", "web", "--no-pub", "--target", "lib/main_v2.dart",
            "--output", "build/v2/web",
        ], root)
    print(
        f"V2 {profile} checks passed: {len(packages)} discovered packages and explicit entry point. "
        "Native platform compilation and distribution remain separate evidence.",
        flush=True,
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", choices=("full", "native"), default="full")
    parser.add_argument(
        "--no-build", action="store_true", help="Omit the explicit v2 Web build."
    )
    args = parser.parse_args()
    check(profile=args.profile, no_build=args.no_build)


if __name__ == "__main__":
    main()
