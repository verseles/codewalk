#!/usr/bin/env bash
# Succeeds only when GitHub answers 404 for the release of tag $2 in repo $1.
# An existing release, or any other answer (auth, rate limit, network),
# fails, so a cohort release is never updated in place.
set -uo pipefail
repo="$1"
tag="$2"
if output="$(gh api "repos/$repo/releases/tags/$tag" 2>&1)"; then
  echo "Release $tag already exists; cohort releases are immutable."
  exit 1
fi
if printf '%s' "$output" | grep -q 'HTTP 404'; then
  exit 0
fi
echo "Could not confirm that release $tag is new: $output"
exit 1
