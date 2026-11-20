#!/usr/bin/env python3
"""Graduates CodeWalk 2 on main from beta to stable v2.0.0: `make release V=stable`.

This is a one-shot graduation from 2.0.0-beta.N to 2.0.0. It reads the curated
release notes committed in release-notes/v2.0.0.md, prepends the matching
`## v2.0.0 - YYYY-MM-DD` section to CHANGELOG.md (so CHANGELOG.md stays clean
until the tag commit), sets pubspec.yaml to `2.0.0+BUILD`, commits both with
the Task Memory snapshot, creates the annotated `v2.0.0` tag, and pushes main
and that tag atomically.

With --dry-run it prints the plan and changes nothing.
"""
import argparse
from datetime import datetime, timezone
from pathlib import Path
import re
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
from cut_beta import ROOT, SNAPSHOT, changed_paths, git, next_build  # noqa: E402
from release_plan import BETA_VERSION, STABLE_VERSION, apk_version_code, pubspec_version  # noqa: E402

TARGET_VERSION = "2.0.0"
TARGET_TAG = "v2.0.0"
NOTES_REL = Path("release-notes/v2.0.0.md")
CHANGELOG_REL = Path("CHANGELOG.md")
MAX_NOTES_BYTES = 65536
MAX_ANNOUNCEMENT_CHARS = 300


def next_stable_version(current: str, bump: str = "minor") -> str:
    if BETA_VERSION.match(current):
        return "2.0.0"
    if STABLE_VERSION.match(current):
        _, minor_s, patch_s = current.split(".")
        minor, patch = int(minor_s), int(patch_s)
        if bump == "patch":
            return f"2.{minor}.{patch + 1}"
        if bump == "minor":
            return f"2.{minor + 1}.0"
        raise ValueError(f"unsupported stable bump: {bump}")
    raise ValueError(f"cannot cut a stable v2 release from {current}")


def notes_rel_for(version: str) -> Path:
    return Path(f"release-notes/v{version}.md")


def validate_notes(text: str) -> str:
    body = text.strip()
    if not body:
        raise ValueError(f"{NOTES_REL} is empty")
    if len(body.encode("utf-8")) > MAX_NOTES_BYTES:
        raise ValueError(f"{NOTES_REL} exceeds {MAX_NOTES_BYTES} bytes")
    if re.search(r"^##(?:\s|$)", body, flags=re.M):
        raise ValueError(f"{NOTES_REL} must not contain `##` release headings")
    lines = body.splitlines()
    if lines[0].startswith("> 📣"):
        announcement = lines[0].removeprefix("> 📣").strip()
        if not announcement or len(announcement) > MAX_ANNOUNCEMENT_CHARS:
            raise ValueError(
                f"{NOTES_REL} leading `> 📣` announcement must be 1..{MAX_ANNOUNCEMENT_CHARS} characters"
            )
    return body


def prepend_changelog(changelog_text: str, version: str, date_iso: str, notes: str) -> str:
    tag = f"v{version}"
    if re.search(rf"^##\s+{re.escape(tag)}(?:\s|$)", changelog_text, flags=re.M):
        raise ValueError(f"CHANGELOG.md already contains a section for {tag}")
    content = changelog_text.rstrip() + "\n"
    section = f"## {tag} - {date_iso}\n\n{notes}\n\n"
    first_heading = re.search(r"^##\s+", content, flags=re.M)
    if first_heading:
        return content[: first_heading.start()] + section + content[first_heading.start():]
    return content.rstrip() + "\n\n" + section


def plan(runner=subprocess.run, now: int | None = None, today: str | None = None,
         root: Path = ROOT, bump: str = "minor") -> dict:
    branch = git(runner, "rev-parse", "--abbrev-ref", "HEAD")
    if branch != "main":
        raise ValueError(f"stable v2 releases are cut on main, not {branch}")
    dirty = [path for path in changed_paths(runner) if path.split("/", 1)[0] != SNAPSHOT]
    if dirty:
        raise ValueError(f"commit or resolve pending changes first: {dirty[:5]}")
    head = git(runner, "rev-parse", "HEAD")
    remote = git(runner, "ls-remote", "origin", "refs/heads/main").split("\t", 1)[0]
    if remote != head:
        raise ValueError(f"main is not at origin/main ({head[:8]} vs {remote[:8] or 'none'}); sync first")
    name, build = pubspec_version((root / "pubspec.yaml").read_text(encoding="utf-8"))
    target_version = next_stable_version(name, bump=bump)
    target_tag = f"v{target_version}"
    notes_rel = notes_rel_for(target_version)
    notes_path = root / notes_rel
    if not notes_path.is_file():
        raise ValueError(f"missing curated release notes: {notes_rel}")
    notes = validate_notes(notes_path.read_text(encoding="utf-8"))
    changelog_path = root / CHANGELOG_REL
    if not changelog_path.is_file():
        raise ValueError(f"missing {CHANGELOG_REL}")
    date_iso = today or datetime.now(timezone.utc).date().isoformat()
    # Validate changelog insertion before mutating anything.
    prepend_changelog(changelog_path.read_text(encoding="utf-8"), target_version, date_iso, notes)
    if git(runner, "tag", "--list", target_tag) or git(runner, "ls-remote", "--tags", "origin", f"refs/tags/{target_tag}"):
        raise ValueError(f"tag {target_tag} already exists")
    new_build = next_build(build, int(time.time() if now is None else now))
    return {
        "from": f"{name}+{build}",
        "version": target_version,
        "build": new_build,
        "tag": target_tag,
        "date": date_iso,
        "notes": notes,
        "apk_version_code": apk_version_code(new_build),
        "commit": head,
        "push": ["git", "push", "--atomic", "origin", "HEAD:refs/heads/main", f"refs/tags/{target_tag}"],
    }


def cut(step: dict, runner=subprocess.run, root: Path = ROOT) -> None:
    pubspec = root / "pubspec.yaml"
    changelog = root / CHANGELOG_REL
    original_pubspec = pubspec.read_text(encoding="utf-8")
    original_changelog = changelog.read_text(encoding="utf-8")
    updated_pubspec, count = re.subn(
        r"^version:.*$", f"version: {step['version']}+{step['build']}", original_pubspec, count=1, flags=re.M
    )
    if count != 1:
        raise ValueError("pubspec.yaml has no version line")
    updated_changelog = prepend_changelog(original_changelog, step["version"], step["date"], step["notes"])
    pubspec.write_text(updated_pubspec, encoding="utf-8", newline="\n")
    changelog.write_text(updated_changelog, encoding="utf-8", newline="\n")
    try:
        git(runner, "add", "-f", "--", "pubspec.yaml", str(CHANGELOG_REL), SNAPSHOT)
        git(runner, "commit", "-m", f"release: cut {step['tag']}")
    except subprocess.CalledProcessError:
        pubspec.write_text(original_pubspec, encoding="utf-8", newline="\n")
        changelog.write_text(original_changelog, encoding="utf-8", newline="\n")
        git(runner, "reset", "--quiet", "--", "pubspec.yaml", str(CHANGELOG_REL))
        raise
    try:
        git(runner, "tag", "-a", step["tag"], "-m", step["tag"])
        runner(step["push"], cwd=root, check=True)
    except subprocess.CalledProcessError as error:
        raise ValueError(
            f"the release commit exists locally but the tag or push failed ({error}: "
            f"{(error.stderr or '').strip()}); finish with: "
            f"git tag -a {step['tag']} -m {step['tag']} (if missing), then {' '.join(step['push'])}"
        ) from error


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--bump", choices=("minor", "patch"), default="minor")
    args = parser.parse_args(argv[1:])
    try:
        step = plan(bump=args.bump)
    except (ValueError, subprocess.CalledProcessError) as error:
        print(f"Refusing to cut stable release: {error}", file=sys.stderr)
        return 1
    print(f"{step['from']} -> {step['version']}+{step['build']} (APK versionCode {step['apk_version_code']})")
    print(f"CHANGELOG heading: ## {step['tag']} - {step['date']}")
    print(f"commit on {step['commit'][:8]}, tag {step['tag']}, then: {' '.join(step['push'])}")
    if args.dry_run:
        print("Dry run: nothing was changed.")
        return 0
    try:
        cut(step)
    except (ValueError, subprocess.CalledProcessError) as error:
        print(f"Stable cut failed: {error}", file=sys.stderr)
        return 1
    print(f"Released {step['tag']}: the Release workflow verifies and publishes it as the latest stable release.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
