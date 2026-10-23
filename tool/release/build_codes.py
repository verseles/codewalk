#!/usr/bin/env python3
"""Proves an Android versionCode is above every published CodeWalk APK.

Both release lines (v1 and v2) publish to one repository and one Android
package, so a new APK must exceed the highest code ever published, whichever
line or version published it. The recorded baseline covers every release
published up to its instant; each APK published after it is downloaded and
its actual versionCode read with aapt2, so nothing relies on a pubspec or a
semantic version. Any release, page or APK that cannot be read fails closed.

Usage:
  build_codes.py check <repo> <apk_version_code>
"""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
LEDGER = Path(__file__).with_name("published_android_codes.json")
BADGING_CODE = re.compile(r"^package: .*\bversionCode='([0-9]+)'", re.M)


def load_baseline(path: Path = LEDGER) -> tuple[str, int]:
    baseline = json.loads(path.read_text(encoding="utf-8"))["baseline"]
    return baseline["through_published_at"], int(baseline["max_version_code"])


def releases_after(releases: list[dict], through: str) -> list[dict]:
    """Published (non-draft) releases after the baseline that carry an APK.

    GitHub timestamps are fixed-width UTC (YYYY-MM-DDTHH:MM:SSZ), so they
    order as strings. A release without a publication time is not trusted.
    """
    later = []
    for release in releases:
        if release.get("draft"):
            continue
        published = release.get("published_at")
        if not isinstance(published, str) or not re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ", published):
            raise ValueError(f"release {release.get('tag_name')!r} has no valid publication time")
        apks = [asset["name"] for asset in release.get("assets", []) if asset.get("name", "").endswith(".apk")]
        if published > through and apks:
            later.append({"tag": release["tag_name"], "apks": apks})
    return later


def highest_code(releases: list[dict], read_code, ledger: Path = LEDGER) -> int:
    through, highest = load_baseline(ledger)
    for release in releases_after(releases, through):
        for apk in release["apks"]:
            highest = max(highest, read_code(release["tag"], apk))
    return highest


def check(planned: int, releases: list[dict], read_code, ledger: Path = LEDGER) -> int:
    highest = highest_code(releases, read_code, ledger)
    if planned <= highest:
        raise ValueError(f"versionCode {planned} is not above the highest published {highest}")
    return highest


def fetch_releases(repo: str, runner=subprocess.run) -> list[dict]:
    # --paginate with --jq emits one release per line across every page.
    output = runner(
        ["gh", "api", "--paginate", f"repos/{repo}/releases?per_page=100",
         "--jq", ".[] | {tag_name, draft, published_at, assets: [.assets[] | {name}]}"],
        check=True, text=True, capture_output=True,
    ).stdout
    return [json.loads(line) for line in output.splitlines() if line.strip()]


def aapt2() -> str:
    tools = Path(os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT") or "") / "build-tools"
    candidates = sorted(tools.glob("*/aapt2")) if tools.is_dir() else []
    if not candidates:
        raise ValueError("aapt2 not found under $ANDROID_HOME/build-tools")
    return str(candidates[-1])


def apk_code(apk: Path, runner=subprocess.run) -> int:
    badging = runner([aapt2(), "dump", "badging", str(apk)], check=True, text=True, capture_output=True).stdout
    match = BADGING_CODE.search(badging)
    if not match:
        raise ValueError(f"no versionCode in the badging of {apk.name}")
    return int(match.group(1))


def downloaded_code(repo: str, runner=subprocess.run):
    def read(tag: str, name: str) -> int:
        with tempfile.TemporaryDirectory() as directory:
            runner(["gh", "release", "download", tag, "--repo", repo, "--pattern", name, "--dir", directory],
                   check=True, capture_output=True)
            return apk_code(Path(directory) / name, runner)
    return read


def main(argv: list[str]) -> int:
    if len(argv) != 4 or argv[1] != "check" or not argv[3].isdigit():
        print(__doc__, file=sys.stderr)
        return 2
    try:
        highest = check(int(argv[3]), fetch_releases(argv[2]), downloaded_code(argv[2]))
    except (ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(f"Refusing to release: {error}", file=sys.stderr)
        return 1
    print(f"highest_published_version_code={highest}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
