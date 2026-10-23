#!/usr/bin/env python3
"""Decides what the main release workflow may build and publish, failing closed.

  v2.0.0-beta.N    a v2 beta: Android arm64 and Linux x64/ARM64 built from
                   lib/main_v2.dart, published as a prerelease that is never
                   latest and never overwritten

main publishes nothing else: a stable vX.Y.Z, a v1 native cohort, GA v2.0.0,
another prerelease family or a malformed tag belong to other lines or later
gates. The pubspec must carry `2.0.0-beta.N+BUILD` for the tag's N.

A manual dispatch from refs/heads/main is a dry run: it builds and verifies
the artifacts for an explicit beta version without publishing anything.

Usage:
  release_plan.py <event> <ref_type> <ref_name> <pubspec.yaml> [dry_run_version]
Prints `publish=`, `version=`, `build_number=` and `apk_version_code=` lines
for $GITHUB_OUTPUT.
"""
import re
import sys
import time

NUM = r"(?:0|[1-9][0-9]*)"
BETA_NUM = r"[1-9][0-9]*"
BETA_TAG = re.compile(rf"^v(2\.0\.0-beta\.{BETA_NUM})$")
BETA_VERSION = re.compile(rf"^2\.0\.0-beta\.{BETA_NUM}$")
PUBSPEC_VERSION = re.compile(r"^version:\s*([^\s+]+)\+([0-9]+)\s*$", re.M)
# Flutter's --split-per-abi adds 1000 x the ABI code to versionCode, and
# arm64-v8a is ABI 2: the published APK carries the pubspec build + 2000.
ARM64_VERSION_CODE_OFFSET = 2000
# Android rejects a versionCode above 2100000000.
MAX_ANDROID_VERSION_CODE = 2_100_000_000


def pubspec_version(pubspec: str) -> tuple[str, int]:
    match = PUBSPEC_VERSION.search(pubspec)
    if not match:
        raise ValueError("pubspec.yaml has no `version: X.Y.Z+BUILD` line")
    return match.group(1), int(match.group(2))


def apk_version_code(build_number: int) -> int:
    code = build_number + ARM64_VERSION_CODE_OFFSET
    if code > MAX_ANDROID_VERSION_CODE:
        raise ValueError(f"Android versionCode {code} exceeds {MAX_ANDROID_VERSION_CODE}")
    return code


def plan(event: str, ref_type: str, ref_name: str, pubspec: str,
         dry_run_version: str = "", now: int | None = None) -> dict:
    name, build = pubspec_version(pubspec)
    if ref_type == "tag":
        if event not in ("push", "workflow_dispatch"):
            raise ValueError(f"unsupported event {event!r} for a tag")
        if dry_run_version:
            raise ValueError("a tag publishes its own version; a dry-run version is for main only")
        tag = BETA_TAG.match(ref_name)
        if not tag:
            raise ValueError(f"tag {ref_name} is not a v2 beta (v2.0.0-beta.N); main publishes nothing else")
        if tag.group(1) != name:
            raise ValueError(f"tag {ref_name} does not match the pubspec version {name}")
        return {"publish": "true", "version": name, "build_number": str(build),
                "apk_version_code": str(apk_version_code(build))}
    if event == "workflow_dispatch" and ref_type == "branch" and ref_name == "main":
        if not BETA_VERSION.match(dry_run_version):
            raise ValueError("a dry run needs an explicit 2.0.0-beta.N version")
        # A dry run never ships, so its build number only has to be valid and
        # above the pubspec's; the epoch keeps it in the published range.
        build = max(build + 1, int(time.time() if now is None else now))
        return {"publish": "false", "version": dry_run_version, "build_number": str(build),
                "apk_version_code": str(apk_version_code(build))}
    raise ValueError(f"releases come from v2 beta tags or a main dry run, not the {ref_type} {ref_name!r}")


def main(argv: list[str]) -> int:
    if len(argv) not in (5, 6):
        print(__doc__, file=sys.stderr)
        return 2
    try:
        with open(argv[4], encoding="utf-8") as f:
            result = plan(argv[1], argv[2], argv[3], f.read(), argv[5] if len(argv) == 6 else "")
    except ValueError as error:
        print(f"Refusing to release: {error}", file=sys.stderr)
        return 1
    for key, value in result.items():
        print(f"{key}={value}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
