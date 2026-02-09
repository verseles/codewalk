#!/usr/bin/env bash
set -euo pipefail

LCOV_FILE="${1:-coverage/lcov.info}"
MIN_COVERAGE="${2:-35}"

if [[ ! -f "$LCOV_FILE" ]]; then
  echo "Coverage file not found: $LCOV_FILE"
  exit 1
fi

total_lines=$(awk -F: '/^LF:/{sum+=$2} END {print sum+0}' "$LCOV_FILE")
covered_lines=$(awk -F: '/^LH:/{sum+=$2} END {print sum+0}' "$LCOV_FILE")

if [[ "$total_lines" -eq 0 ]]; then
  echo "No executable lines found in coverage report."
  exit 1
fi

coverage_pct=$(awk -v c="$covered_lines" -v t="$total_lines" 'BEGIN { printf "%.2f", (c/t)*100 }')

echo "Coverage: $coverage_pct% ($covered_lines/$total_lines)"

is_below=$(awk -v actual="$coverage_pct" -v min="$MIN_COVERAGE" 'BEGIN { if (actual < min) print 1; else print 0 }')
if [[ "$is_below" -eq 1 ]]; then
  echo "Coverage gate failed: expected >= ${MIN_COVERAGE}%, got ${coverage_pct}%"
  exit 1
fi

echo "Coverage gate passed (>= ${MIN_COVERAGE}%)."
