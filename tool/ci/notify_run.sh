#!/usr/bin/env bash
# Waits for a GitHub Actions run of the current commit and reports through hey,
# so no agent spends tokens watching CI. Start it through make watch-ci or
# make watch-release.
#
# Usage: notify_run.sh <workflow-file> <failures|always>
set -u

workflow="${1:?workflow file}"
mode="${2:-failures}"
sha="$(git rev-parse HEAD)"
short="$(git rev-parse --short HEAD)"
hey_bin="${HEY_BIN:-$HOME/bin/hey}"
appear_seconds="${NOTIFY_APPEAR_SECONDS:-600}"
watch_seconds="${NOTIFY_WATCH_SECONDS:-10800}"
poll_seconds="${NOTIFY_POLL_SECONDS:-60}"

report() {
  "$hey_bin" "codewalk: $1" >/dev/null 2>&1
}

# Only the push event: a manual Release dispatch is a dry run on the same commit.
run_id=""
deadline=$((SECONDS + appear_seconds))
while [ -z "$run_id" ] && [ "$SECONDS" -lt "$deadline" ]; do
  run_id="$(gh run list --workflow "$workflow" --commit "$sha" --event push --limit 1 \
    --json databaseId --jq '.[0].databaseId // empty' 2>/dev/null)"
  [ -n "$run_id" ] || sleep "$poll_seconds"
done

if [ -z "$run_id" ]; then
  report "$workflow did not start for $short. Nothing pending from you; the next unit checks it."
  exit 1
fi

# Failed polls are transient: one network error must not read as a failed run.
status=""
conclusion=""
deadline=$((SECONDS + watch_seconds))
while [ "$status" != completed ] && [ "$SECONDS" -lt "$deadline" ]; do
  result="$(gh run view "$run_id" --json status,conclusion \
    --jq '"\(.status) \(.conclusion)"' 2>/dev/null)" || result=""
  status="${result%% *}"
  conclusion="${result#* }"
  [ "$status" = completed ] || sleep "$poll_seconds"
done

url="$(gh run view "$run_id" --json url --jq '.url' 2>/dev/null)" || url=""
[ -n "$url" ] || url="run $run_id"

if [ "$status" != completed ]; then
  report "$workflow: could not determine the result for $short: $url. Nothing pending from you; check it with status."
  exit 1
fi

case "$conclusion" in
  success)
    [ "$mode" = always ] && report "$workflow passed for $short. Nothing pending from you."
    exit 0
    ;;
  cancelled | skipped)
    # A newer push replaced this run; its own watcher reports.
    [ "$mode" = always ] && report "$workflow was $conclusion for $short: $url. Nothing pending from you."
    exit 0
    ;;
  *)
    report "$workflow ended as $conclusion for $short: $url. Nothing pending from you; the next avançar starts by fixing it."
    exit 1
    ;;
esac
