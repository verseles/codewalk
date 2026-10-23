#!/usr/bin/env python3
"""Cuts the next CodeWalk 2 beta on main: `make release V=beta`.

main releases only v2.0.0-beta.N; stable, patch and v1 releases belong to
the v1 branch, and GA promotion to exactly v2.0.0 is a later gate. The cut
sets pubspec to 2.0.0-beta.N+BUILD, commits it with the Task Memory
snapshot, creates the annotated tag and pushes exactly main and that tag
(never --follow-tags, which would also push unrelated local tags). The tag
starts the release workflow, which rechecks the build code against every
published APK before building.

It never writes CHANGELOG.md: installed CodeWalk 1 apps read main's
CHANGELOG.md and reject any heading that is not a stable `## vX.Y.Z - date`,
so a beta section would break their release history.

With --dry-run it prints the plan and changes nothing.
"""
import argparse
from pathlib import Path
import re
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_codes import load_baseline  # noqa: E402
from release_plan import ARM64_VERSION_CODE_OFFSET, BETA_VERSION, apk_version_code, pubspec_version  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
# Matches the Makefile's NEXT_BUILD_CODE_SH offset.
BUILD_CODE_OFFSET = 2001
# The Task Memory snapshot travels in every commit (AGENTS.md).
SNAPSHOT = ".task-memory"


def git(runner, *args) -> str:
    return runner(["git", *args], cwd=ROOT, check=True, text=True, capture_output=True).stdout.strip()


def changed_paths(runner) -> list[str]:
    """Every path git status reports, both sides of a rename or copy included."""
    status = runner(["git", "status", "--porcelain", "-z"], cwd=ROOT, check=True, text=True,
                    capture_output=True).stdout
    entries = status.split("\0")
    paths, index = [], 0
    while index < len(entries):
        entry = entries[index]
        index += 1
        if not entry:
            continue
        paths.append(entry[3:])
        # With -z, a rename or copy is "XY new" followed by the original path.
        if "R" in entry[:2] or "C" in entry[:2]:
            paths.append(entries[index])
            index += 1
    return paths


def next_version(current: str) -> str:
    if BETA_VERSION.match(current):
        return f"2.0.0-beta.{int(current.rsplit('.', 1)[1]) + 1}"
    if re.fullmatch(r"1\.[0-9]+\.[0-9]+", current):
        return "2.0.0-beta.1"
    raise ValueError(f"cannot cut a beta after {current}; GA promotion is a separate gate")


def next_build(current: int, now: int) -> int:
    # Above the pubspec, the published baseline and the clock; the release
    # workflow re-verifies against every APK published since the baseline.
    floor = load_baseline()[1] - ARM64_VERSION_CODE_OFFSET
    build = max(current + 1, floor + 1, now + BUILD_CODE_OFFSET)
    apk_version_code(build)
    return build


def plan(runner=subprocess.run, now: int | None = None) -> dict:
    branch = git(runner, "rev-parse", "--abbrev-ref", "HEAD")
    if branch != "main":
        raise ValueError(f"betas are cut on main, not {branch}")
    dirty = [path for path in changed_paths(runner) if path.split("/", 1)[0] != SNAPSHOT]
    if dirty:
        raise ValueError(f"commit or resolve pending changes first: {dirty[:5]}")
    head = git(runner, "rev-parse", "HEAD")
    remote = git(runner, "ls-remote", "origin", "refs/heads/main").split("\t", 1)[0]
    if remote != head:
        raise ValueError(f"main is not at origin/main ({head[:8]} vs {remote[:8] or 'none'}); sync first")
    name, build = pubspec_version((ROOT / "pubspec.yaml").read_text(encoding="utf-8"))
    version = next_version(name)
    tag = f"v{version}"
    if git(runner, "tag", "--list", tag) or git(runner, "ls-remote", "--tags", "origin", f"refs/tags/{tag}"):
        raise ValueError(f"tag {tag} already exists")
    new_build = next_build(build, int(time.time() if now is None else now))
    return {"from": f"{name}+{build}", "version": version, "build": new_build, "tag": tag,
            "apk_version_code": apk_version_code(new_build), "commit": head,
            "push": ["git", "push", "--atomic", "origin", "HEAD:refs/heads/main", f"refs/tags/{tag}"]}


def cut(step: dict, runner=subprocess.run) -> None:
    pubspec = ROOT / "pubspec.yaml"
    text = pubspec.read_text(encoding="utf-8")
    updated, count = re.subn(r"^version:.*$", f"version: {step['version']}+{step['build']}", text, count=1, flags=re.M)
    if count != 1:
        raise ValueError("pubspec.yaml has no version line")
    pubspec.write_text(updated, encoding="utf-8", newline="\n")
    try:
        git(runner, "add", "pubspec.yaml", "--", SNAPSHOT)
        git(runner, "commit", "-m", f"release: cut {step['tag']}")
    except subprocess.CalledProcessError:
        # Nothing was committed: leave main on its previous version.
        pubspec.write_text(text, encoding="utf-8", newline="\n")
        git(runner, "reset", "--quiet", "--", "pubspec.yaml")
        raise
    try:
        git(runner, "tag", "-a", step["tag"], "-m", step["tag"])
        runner(step["push"], cwd=ROOT, check=True)
    except subprocess.CalledProcessError as error:
        raise ValueError(
            f"the release commit exists locally but the tag or push failed ({error}: "
            f"{(error.stderr or '').strip()}); finish with: "
            f"git tag -a {step['tag']} -m {step['tag']} (if missing), then {' '.join(step['push'])}") from error


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv[1:])
    try:
        step = plan()
    except (ValueError, subprocess.CalledProcessError) as error:
        print(f"Refusing to cut a beta: {error}", file=sys.stderr)
        return 1
    print(f"{step['from']} -> {step['version']}+{step['build']} (APK versionCode {step['apk_version_code']})")
    print(f"commit on {step['commit'][:8]}, tag {step['tag']}, then: {' '.join(step['push'])}")
    if args.dry_run:
        print("Dry run: nothing was changed.")
        return 0
    try:
        cut(step)
    except (ValueError, subprocess.CalledProcessError) as error:
        print(f"Beta cut failed: {error}", file=sys.stderr)
        return 1
    print(f"Released {step['tag']}: the Release workflow verifies and publishes it as a prerelease.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
