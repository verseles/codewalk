#!/usr/bin/env bash
set -euo pipefail

LCOV_FILE="${1:-coverage/lcov.info}"
MIN_COVERAGE="${2:-35}"
FILTERED_FILE="${3:-coverage/lcov.filtered.info}"

if [[ ! -f "$LCOV_FILE" ]]; then
  echo "Coverage file not found: $LCOV_FILE"
  exit 1
fi

INPUT_FILE="$LCOV_FILE"

if command -v lcov >/dev/null 2>&1; then
  lcov --remove "$LCOV_FILE" \
    "lib/**/*.g.dart" \
    "**/generated_plugin_registrant.dart" \
    "lib/l10n/*" \
    -o "$FILTERED_FILE" \
    --ignore-errors unused >/dev/null 2>&1 || {
    echo "lcov filtering failed, falling back to raw report."
  }
  if [[ -f "$FILTERED_FILE" ]]; then
    INPUT_FILE="$FILTERED_FILE"
  fi
else
  echo "lcov not found, using raw coverage report."
fi

total_lines=$(awk -F: '/^LF:/{sum+=$2} END {print sum+0}' "$INPUT_FILE")
covered_lines=$(awk -F: '/^LH:/{sum+=$2} END {print sum+0}' "$INPUT_FILE")

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
