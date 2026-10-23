#!/usr/bin/env python3
"""Decides what a tag-triggered release may publish, failing closed.

  vX.Y.Z             stable: every platform, the latest flag left to GitHub
  v1.X.Y-native.N    the v1 transition cohort: Android and Linux only, a
                     prerelease that is never latest and never overwritten

Any other ref (a branch, a beta or other suffix, a malformed tag) publishes
nothing. The pubspec version name must equal the tag without its v and
cohort suffix, so a build never ships under another version.

Usage: release_plan.py <ref_type> <ref_name> <pubspec.yaml>
Prints `kind=stable|native` for $GITHUB_OUTPUT.
"""
import re
import sys

NUM = r"(?:0|[1-9][0-9]*)"
STABLE = re.compile(rf"^v({NUM}\.{NUM}\.{NUM})$")
NATIVE = re.compile(rf"^v(1\.{NUM}\.{NUM})-native\.{NUM}$")
PUBSPEC_VERSION = re.compile(r"^version:\s*([^\s+]+)\+([0-9]+)\s*$", re.M)


def plan(ref_type: str, ref_name: str, pubspec: str) -> str:
    if ref_type != "tag":
        raise ValueError(f"releases are published from tags only, not the {ref_type} {ref_name!r}")
    match = PUBSPEC_VERSION.search(pubspec)
    if not match:
        raise ValueError("pubspec.yaml has no `version: X.Y.Z+BUILD` line")
    name = match.group(1)
    for kind, pattern in (("stable", STABLE), ("native", NATIVE)):
        tag = pattern.match(ref_name)
        if tag:
            if tag.group(1) != name:
                raise ValueError(f"tag {ref_name} does not match the pubspec version {name}")
            return kind
    raise ValueError(f"tag {ref_name} is neither a stable release nor a v1 native cohort")


def main(argv: list[str]) -> int:
    if len(argv) != 4:
        print(__doc__, file=sys.stderr)
        return 2
    try:
        with open(argv[3], encoding="utf-8") as f:
            kind = plan(argv[1], argv[2], f.read())
    except ValueError as error:
        print(f"Refusing to release: {error}", file=sys.stderr)
        return 1
    print(f"kind={kind}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
