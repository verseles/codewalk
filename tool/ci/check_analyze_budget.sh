#!/usr/bin/env bash
set -euo pipefail

ANALYZE_LOG="${1:-/tmp/flutter_analyze.log}"
MAX_ISSUES="${2:-186}"

if [[ ! -f "$ANALYZE_LOG" ]]; then
  echo "Analyze log not found: $ANALYZE_LOG"
  exit 1
fi

issues_line=$(grep -Eo '[0-9]+ issues found\.?' "$ANALYZE_LOG" | tail -n1 || true)
if [[ -z "$issues_line" ]]; then
  if grep -q "No issues found" "$ANALYZE_LOG"; then
    issues_count=0
  else
    echo "Unable to parse issue count from analyze log."
    exit 1
  fi
else
  issues_count=$(echo "$issues_line" | grep -Eo '^[0-9]+')
fi

echo "Analyze issues: $issues_count (budget: <= $MAX_ISSUES)"

if (( issues_count > MAX_ISSUES )); then
  echo "Analyze budget exceeded."
  exit 1
fi

echo "Analyze budget check passed."
