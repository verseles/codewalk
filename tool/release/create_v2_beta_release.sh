#!/usr/bin/env bash
# Creates the v2 beta release for tag $2 in repo $1 and uploads the files
# that follow. The create call fails when a release for the tag already
# exists, so an existing release is never updated; assets go only to the
# release this call created. Every file is checked first, and a failed
# upload deletes the release this call created, so a rerun starts clean.
set -euo pipefail
repo="$1"
tag="$2"
shift 2
for file in "$@"; do
  [ -f "$file" ] && [ -r "$file" ] || { echo "Missing release asset: $file"; exit 1; }
done
body="CodeWalk $tag: an opt-in beta of CodeWalk 2 for Android and Linux (x64, ARM64). A prerelease, never the latest release; stable and CodeWalk 1 updates do not offer it. Install with CODEWALK_CHANNEL=beta."
# Read from the immutable release tag, never from another checkout's notes.
notes_ref="$tag:release-notes/v2-beta.md"
if git cat-file -e "$notes_ref" 2>/dev/null; then
  body="$(git show "$notes_ref")"
  python3 -c '
import sys
body = sys.argv[1]
if not body.strip() or len(body.encode("utf-8")) > 65536:
    raise SystemExit("Invalid beta release notes size")
first = body.splitlines()[0]
if first.startswith("> 📣"):
    announcement = first.removeprefix("> 📣").strip()
    if not announcement or len(announcement) > 300:
        raise SystemExit("Invalid beta announcement")
' "$body"
fi
id="$(gh api --method POST "repos/$repo/releases" \
  -f tag_name="$tag" -f name="$tag" -f body="$body" \
  -F draft=false -F prerelease=true -f make_latest=false \
  --jq .id)"
if ! gh release upload "$tag" "$@" --repo "$repo"; then
  echo "Upload failed; deleting the incomplete release $tag ($id)."
  gh api --method DELETE "repos/$repo/releases/$id" || true
  exit 1
fi
