#!/usr/bin/env python3
"""Small changelog helper used by `make release` and release.yml."""

from __future__ import annotations

import argparse
import datetime as _dt
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CHANGELOG = ROOT / "CHANGELOG.md"


def _run_git(args: list[str]) -> str:
    try:
        return subprocess.check_output(
            ["git", *args],
            cwd=ROOT,
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
    except subprocess.CalledProcessError:
        return ""


def _normal_version(version: str) -> str:
    value = version.strip()
    if not value:
        raise SystemExit("version is required")
    return value if value.startswith("v") else f"v{value}"


def _latest_tag() -> str:
    return _run_git(["describe", "--tags", "--abbrev=0"])


def _commit_bullets(since_tag: str) -> list[str]:
    range_arg = f"{since_tag}..HEAD" if since_tag else "HEAD"
    output = _run_git(["log", "--pretty=format:%s", range_arg])
    subjects = [line.strip() for line in output.splitlines() if line.strip()]
    if not subjects:
        return ["- Release maintenance."]
    return [f"- {subject}" for subject in subjects if not subject.startswith("release: cut ")]


def _read_changelog() -> str:
    if CHANGELOG.exists():
        return CHANGELOG.read_text(encoding="utf-8")
    return (
        "# Changelog\n\n"
        "Release notes for tagged CodeWalk versions. GitHub Issues remain the "
        "canonical tracker for planned work and acceptance criteria.\n"
    )


def _announce_block(announce: str | None) -> str:
    """Formats an optional release announcement as a visible blockquote.

    Returns an empty string when there is no usable text so callers keep
    the current section shape. Internal newlines collapse to spaces to keep
    the announcement a single blockquote line.
    """
    if announce is None:
        return ""
    text = " ".join(announce.split()).strip()
    if not text:
        return ""
    if len(text) > 300:
        text = text[:297].rsplit(" ", 1)[0] + "…"
        print("warning: release announcement truncated to 300 characters")
    return f"> 📣 {text}\n\n"


def update(version: str, announce: str | None = None) -> None:
    tag = _normal_version(version)
    content = _read_changelog().rstrip() + "\n"
    heading_pattern = re.compile(rf"^##\s+{re.escape(tag)}(?:\s|$)", re.MULTILINE)
    if heading_pattern.search(content):
        return

    date = _dt.date.today().isoformat()
    bullets = _commit_bullets(_latest_tag())
    section = f"## {tag} - {date}\n\n" + _announce_block(announce) + "\n".join(bullets) + "\n\n"

    first_heading = re.search(r"^##\s+", content, flags=re.MULTILINE)
    if first_heading:
        content = content[: first_heading.start()] + section + content[first_heading.start() :]
    else:
        content = content.rstrip() + "\n\n" + section
    CHANGELOG.write_text(content, encoding="utf-8", newline="\n")


def extract(version: str, output: str) -> None:
    tag = _normal_version(version)
    content = _read_changelog()
    pattern = re.compile(
        rf"^##\s+{re.escape(tag)}[^\n]*\n(?P<body>.*?)(?=^##\s+|\Z)",
        flags=re.MULTILINE | re.DOTALL,
    )
    match = pattern.search(content)
    body = match.group("body").strip() if match else f"Release {tag}."
    Path(output).write_text(body + "\n", encoding="utf-8", newline="\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)

    update_parser = sub.add_parser("update")
    update_parser.add_argument("version")
    update_parser.add_argument("--announce", default=None)

    extract_parser = sub.add_parser("extract")
    extract_parser.add_argument("version")
    extract_parser.add_argument("--output", required=True)

    args = parser.parse_args()
    if args.command == "update":
        update(args.version, announce=args.announce)
    elif args.command == "extract":
        extract(args.version, args.output)


if __name__ == "__main__":
    main()

