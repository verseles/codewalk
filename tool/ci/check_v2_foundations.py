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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--no-build", action="store_true", help="Omit the explicit v2 Web build."
    )
    args = parser.parse_args()

    run(["dart", "run", "tool/ci/import_rules.dart"])
    listing = json.loads(run(["dart", "pub", "workspace", "list", "--json"], capture=True))
    packages = []
    for package in listing["packages"]:
        path = Path(package["path"]).resolve()
        if path == ROOT:
            continue
        if not path.is_relative_to(ROOT / "packages"):
            raise RuntimeError(f"Unexpected workspace package outside packages/: {path}")
        packages.append((package["name"], path))

    discovered = {path for _, path in packages}
    on_disk = {path.parent.resolve() for path in (ROOT / "packages").glob("*/pubspec.yaml")}
    if not packages or discovered != on_disk:
        raise RuntimeError("Workspace discovery does not cover every package pubspec.")

    for name, path in sorted(packages):
        if not any((path / "test").rglob("*_test.dart")):
            raise RuntimeError(f"No discoverable tests in workspace package {name}")
        print(f"Active v2 package: {name}", flush=True)
        run(["dart", "analyze", "--fatal-infos"], path)
        run(["dart", "test"], path)

    run(["dart", "test", "tool/ci/test/import_rules_test.dart"])
    run(["python3", "tool/l10n/generate_v2_localizations.py", "--check"])
    app_paths = [
        path for path in ("lib/app", "lib/features", "lib/platform", "lib/shared")
        if (ROOT / path).is_dir()
    ]
    run(["flutter", "analyze", "--no-pub", *app_paths, "lib/main_v2.dart", "test/v2"])
    run(["flutter", "test", "--no-pub", "test/v2"])
    run(["flutter", "test", "--no-pub", "--platform", "chrome", "test/v2"])
    if not args.no_build:
        run([
            "flutter", "build", "web", "--no-pub", "--target", "lib/main_v2.dart",
            "--output", "build/v2/web",
        ])
    print(
        f"V2 foundations passed: {len(packages)} discovered packages and explicit entry point. "
        "Native platform compilation and distribution remain separate evidence.",
        flush=True,
    )


if __name__ == "__main__":
    main()
