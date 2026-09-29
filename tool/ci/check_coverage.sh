#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
python3 "$SCRIPT_DIR/check_coverage.py" \
  "${1:-coverage/lcov.info}" \
  "${2:-35}" \
  "${3:-coverage/lcov.filtered.info}" \
  "${4:-$SCRIPT_DIR/coverage_baseline.tsv}"
