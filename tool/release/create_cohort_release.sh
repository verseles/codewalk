#!/usr/bin/env bash
# Creates the cohort release for tag $2 in repo $1 and uploads the files
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
body="CodeWalk $tag: the CodeWalk 1 transition cohort for Android and Linux (x64, ARM64). A prerelease, never the latest release; ordinary stable and CodeWalk 1 updates do not offer it."
id="$(gh api --method POST "repos/$repo/releases" \
  -f tag_name="$tag" -f name="$tag" -f body="$body" \
  -F draft=false -F prerelease=true -f make_latest=false \
  --jq .id)"
if ! gh release upload "$tag" "$@" --repo "$repo"; then
  echo "Upload failed; deleting the incomplete release $tag ($id)."
  gh api --method DELETE "repos/$repo/releases/$id" || true
  exit 1
fi
