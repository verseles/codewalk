#!/usr/bin/env bash
# Succeeds only when the remote tag $2 in repo $1 exists and points (peeled,
# for an annotated tag) at commit $3. A release names an existing tag, so
# GitHub never creates a missing tag at another commit.
set -euo pipefail
repo="$1"
tag="$2"
commit="$3"
refs="$(git ls-remote "https://github.com/$repo.git" "refs/tags/$tag" "refs/tags/$tag^{}")"
target="$(printf '%s\n' "$refs" | awk -v peeled="refs/tags/$tag^{}" -v plain="refs/tags/$tag" \
  '$2 == peeled { p = $1 } $2 == plain { t = $1 } END { print (p != "" ? p : t) }')"
if [ -z "$target" ]; then
  echo "Tag $tag does not exist in $repo; refusing to publish."
  exit 1
fi
if [ "$target" != "$commit" ]; then
  echo "Tag $tag points at $target, not the built commit $commit; refusing to publish."
  exit 1
fi
