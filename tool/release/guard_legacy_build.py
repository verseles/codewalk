#!/usr/bin/env python3
"""Refuses to build the legacy entry point under a CodeWalk 2 version.

main holds only CodeWalk 2. The Web deploy workflow still builds through the
legacy path until V1-04 splits it, so a 2.x pubspec stops it here.
v2 artifacts come only from lib/main_v2.dart builds.

With --web-ref, it also requires the Web deploy to run from refs/heads/main:
the Pages target is the main preview, and V1-04 must land before any v2 Web
publication.

Usage: guard_legacy_build.py <pubspec.yaml> [--web-ref <GITHUB_REF>]
"""
import re
import sys

PUBSPEC_VERSION = re.compile(r"^version:\s*([0-9]+)\.[0-9]+\.[0-9]+[^\s+]*\+[0-9]+\s*$", re.M)


def guard(pubspec: str, web_ref: str | None = None) -> None:
    match = PUBSPEC_VERSION.search(pubspec)
    if not match:
        raise ValueError("pubspec.yaml has no `version: X.Y.Z+BUILD` line")
    if match.group(1) != "1":
        raise ValueError(
            f"pubspec is CodeWalk {match.group(1)}.x but this target builds the legacy lib/main.dart; "
            "build v2 from lib/main_v2.dart (make v2-web is a local check only; V1-04 precedes any v2 Web deploy)")
    if web_ref is not None and web_ref != "refs/heads/main":
        raise ValueError(f"the main preview deploys only from refs/heads/main, not {web_ref!r}")


def main(argv: list[str]) -> int:
    if len(argv) == 2:
        web_ref = None
    elif len(argv) == 4 and argv[2] == "--web-ref":
        web_ref = argv[3]
    else:
        print(__doc__, file=sys.stderr)
        return 2
    try:
        with open(argv[1], encoding="utf-8") as f:
            guard(f.read(), web_ref)
    except ValueError as error:
        print(f"Refusing to build: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
