#!/usr/bin/env bash
# Creates a CodeWalk 2 release (beta or stable) for tag $2 in repo $1 and
# uploads the files that follow. The create call fails when a release for the
# tag already exists, so an existing release is never updated; assets go only
# to the release this call created. Every file is checked first, and a failed
# upload deletes the release this call created, so a rerun starts clean.
#
# Usage:
#   create_v2_release.sh <repo> <tag> <beta|stable> <files...>
set -euo pipefail
repo="$1"
tag="$2"
kind="$3"
shift 3

case "$kind" in
  beta)
    if [[ ! "$tag" =~ ^v2\.0\.0-beta\.[1-9][0-9]*$ ]]; then
      echo "Refusing beta publication for non-beta tag: $tag" >&2
      exit 1
    fi
    prerelease="true"
    make_latest="false"
    ;;
  stable)
    if [[ ! "$tag" =~ ^v2\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
      echo "Refusing stable publication for unsupported tag: $tag" >&2
      exit 1
    fi
    prerelease="false"
    make_latest="true"
    ;;
  *)
    echo "Unsupported release kind: $kind (expected beta or stable)" >&2
    exit 1
    ;;
esac

if [ "$#" -lt 1 ]; then
  echo "At least one release asset is required." >&2
  exit 1
fi
for file in "$@"; do
  [ -f "$file" ] && [ -r "$file" ] || { echo "Missing release asset: $file" >&2; exit 1; }
done

if [ "$kind" = "beta" ]; then
  body="CodeWalk $tag: an opt-in beta of CodeWalk 2 for Android, Linux (x64, ARM64), Windows (x64), and macOS (Apple Silicon). A prerelease, never the latest release; stable and CodeWalk 1 updates do not offer it. Install with CODEWALK_CHANNEL=beta."
  # Read from the immutable release tag, never from another checkout's notes.
  notes_ref="$tag:release-notes/v2-beta.md"
  if git cat-file -e "$notes_ref" 2>/dev/null; then
    body="$(git show "$notes_ref")"
  fi
else
  # Stable notes come exclusively from the immutable release tag's CHANGELOG.md.
  changelog_ref="$tag:CHANGELOG.md"
  if ! git cat-file -e "$changelog_ref" 2>/dev/null; then
    echo "Missing CHANGELOG.md on tag $tag" >&2
    exit 1
  fi
  changelog="$(git show "$changelog_ref")"
  body="$(python3 -c '
import re, sys
tag, content = sys.argv[1], sys.argv[2]
pattern = re.compile(
    rf"^##\s+{re.escape(tag)}\s+-\s+\d{{4}}-\d{{2}}-\d{{2}}\s*\n(?P<body>.*?)(?=^##(?:\s|$)|\Z)",
    flags=re.MULTILINE | re.DOTALL,
)
match = pattern.search(content)
if not match:
    raise SystemExit(f"Missing CHANGELOG.md section for {tag}")
body = match.group("body").strip()
if not body:
    raise SystemExit(f"Empty CHANGELOG.md section for {tag}")
print(body)
' "$tag" "$changelog")"
fi

python3 -c '
import sys
body = sys.argv[1]
if not body.strip() or len(body.encode("utf-8")) > 65536:
    raise SystemExit("Invalid release notes size")
first = body.splitlines()[0]
if first.startswith("> 📣"):
    announcement = first.removeprefix("> 📣").strip()
    if not announcement or len(announcement) > 300:
        raise SystemExit("Invalid release announcement")
' "$body"

id="$(gh api --method POST "repos/$repo/releases" \
  -f tag_name="$tag" -f name="$tag" -f body="$body" \
  -F draft=false -F prerelease="$prerelease" -f make_latest="$make_latest" \
  --jq .id)"
if ! gh release upload "$tag" "$@" --repo "$repo"; then
  echo "Upload failed; deleting the incomplete release $tag ($id)." >&2
  gh api --method DELETE "repos/$repo/releases/$id" || true
  exit 1
fi
