#!/usr/bin/env python3
"""Validate the V2-078A MVP platform evidence matrix (plan §15.4).

Every MVP target records each evidence dimension once; compiling, launching,
signing and the functional flow are separate cells and one never stands in
for another. A cell is pending until its producer runs. pass needs the
revision it was observed at and the evidence that shows it; pending-resource
names the missing resource and the next action; fail and inconclusive give
the reason. G3, G4 and the provisional G5 are rerun at a recorded revision.
Deferred platforms are recorded but can never pass. Evidence never carries a
credential or an address.

Usage:
  python3 tool/ci/validate_platform_evidence.py [--final] [MATRIX]
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from live_smoke_v2_opencode import SECRET_VALUE_RE  # noqa: E402
from validate_device_matrix import ADDRESS, ALLOWED_ADDRESSES, _strings, sums  # noqa: E402

DEFAULT = (
    Path(__file__).resolve().parents[2]
    / "test/contract/fixtures/native-builds/platform-078a/matrix.json"
)
TARGETS = ("android-s25", "android-api31", "linux-x64", "linux-arm64")
DIMENSIONS = ("package", "install", "signature", "functional")
GATES = ("G3", "G4", "G5-provisional")
DEFERRED = ("web", "ios", "macos", "windows")
RESULTS = {"pending", "pass", "pending-resource", "fail", "inconclusive"}
REVISION = re.compile(r"[0-9a-f]{8,40}")


def _revision(value: object) -> bool:
    return isinstance(value, str) and REVISION.fullmatch(value) is not None


def _cell(name: str, cell: dict, final: bool, gate: bool = False) -> list[str]:
    found = []
    result = cell.get("result")
    if result not in RESULTS:
        return [f"{name}: result {result!r}"]
    if result == "pending":
        return [f"{name}: still pending"] if final else []
    if result == "pending-resource":
        if not cell.get("resource") or not cell.get("next_action"):
            found.append(f"{name}: pending-resource needs the resource and the next action")
        return found
    if not _revision(cell.get("revision")):
        found.append(f"{name}: no revision")
    if result in ("fail", "inconclusive"):
        if not cell.get("reason"):
            found.append(f"{name}: {result} without a reason")
        return found
    if not cell.get("producer"):
        found.append(f"{name}: pass without its producer")
    if not cell.get("evidence"):
        found.append(f"{name}: pass without evidence")
    if gate and not cell.get("command"):
        found.append(f"{name}: pass without the command that ran")
    return found


def problems(matrix: dict, final: bool = False) -> list[str]:
    found: list[str] = []
    text = json.dumps(matrix)
    if any(SECRET_VALUE_RE.search(t) for t in [text, *_strings(matrix)]):
        found.append("a credential-shaped value is recorded")
    for address in set(ADDRESS.findall(text)) - ALLOWED_ADDRESSES:
        found.append(f"an address is recorded: {address}")
    if matrix.get("unit") != "V2-078A":
        found.append("the matrix is not V2-078A")
    cells = matrix.get("cells")
    if not isinstance(cells, list):
        return found + ["cells is not a list"]
    seen = set()
    for cell in cells:
        key = (cell.get("target"), cell.get("dimension"))
        if key[0] not in TARGETS or key[1] not in DIMENSIONS:
            found.append(f"unknown cell {key}")
            continue
        if key in seen:
            found.append(f"duplicate cell {key}")
        seen.add(key)
        found += _cell(f"{key[0]}/{key[1]}", cell, final)
    for target in TARGETS:
        for dimension in DIMENSIONS:
            if (target, dimension) not in seen:
                found.append(f"missing cell {target}/{dimension}")
    gates = matrix.get("gates")
    if not isinstance(gates, dict) or set(gates) != set(GATES):
        found.append(f"gates must be exactly {', '.join(GATES)}")
    else:
        for name in GATES:
            found += _cell(name, gates[name], final, gate=True)
    deferred = matrix.get("deferred")
    if not isinstance(deferred, dict) or set(deferred) != set(DEFERRED):
        found.append(f"deferred must be exactly {', '.join(DEFERRED)}")
    else:
        for name in DEFERRED:
            entry = deferred[name]
            if entry.get("result") != "deferred-post-mvp":
                found.append(f"deferred {name}: must stay deferred-post-mvp, never pass")
            if not entry.get("tracked_by"):
                found.append(f"deferred {name}: no tracking Issue")
    return found


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("matrix", nargs="?", default=str(DEFAULT))
    parser.add_argument("--final", action="store_true", help="reject pending cells")
    args = parser.parse_args(argv)
    path = Path(args.matrix)
    found = problems(json.loads(path.read_text()), final=args.final) + sums(path.parent)
    for line in found:
        print(f"platform-evidence: {line}", file=sys.stderr)
    return 1 if found else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
