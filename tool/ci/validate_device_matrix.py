#!/usr/bin/env python3
"""Validate the V2-042C device reliability matrix.

Every scenario is recorded once on every target. A cell is pending until it
runs; pass needs its observables inside the bounds, fail and inconclusive
need the reason. Evidence never carries a credential or an address.

Usage:
  python3 tool/ci/validate_device_matrix.py [--final] [MATRIX]
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from live_smoke_v2_opencode import SECRET_VALUE_RE  # noqa: E402

DEFAULT = (
    Path(__file__).resolve().parents[2]
    / "test/contract/fixtures/opencode/2.0.22/device-reliability-042c/matrix.json"
)
TARGETS = ("s25", "api31", "linux-x64", "linux-arm64")
SCENARIOS = ("drop", "handover", "background", "restart", "tui")
RESULTS = {"pending", "pass", "fail", "inconclusive"}
# Seconds from the end of the disturbance (network back, app in front, server
# ready, session created) to the view being live again or the row listed.
BOUNDS = {"drop": 10, "handover": 10, "background": 10, "restart": 30, "tui": 10}
# A disturbed stream passes only with the reconnect the server saw for it.
RECONNECTS = ("drop", "handover", "background", "restart")
# Emulator and loopback aliases are not personal addresses.
ALLOWED_ADDRESSES = {"10.0.2.2", "127.0.0.1"}
ADDRESS = re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b")


def _time(value: object) -> bool:
    if not isinstance(value, str):
        return False
    try:
        datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return False
    return True


def _strings(value: object):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for item in value.values():
            yield from _strings(item)
    elif isinstance(value, list):
        for item in value:
            yield from _strings(item)


def problems(matrix: dict, final: bool = False) -> list[str]:
    found: list[str] = []
    text = json.dumps(matrix)
    # Each recorded string is checked as written, not only as JSON escapes it.
    if any(SECRET_VALUE_RE.search(t) for t in [text, *_strings(matrix)]):
        found.append("a credential-shaped value is recorded")
    for address in set(ADDRESS.findall(text)) - ALLOWED_ADDRESSES:
        found.append(f"an address is recorded: {address}")
    if matrix.get("unit") != "V2-042C" or matrix.get("server", {}).get("version") != "2.0.22":
        found.append("the matrix is not V2-042C on OpenCode 2.0.22")
    if matrix.get("durable_log", {}).get("enabled") is not False:
        found.append("the durable log must stay off with its reason")
    elif not matrix["durable_log"].get("reason"):
        found.append("the durable log has no reason")
    cells = matrix.get("cells")
    if not isinstance(cells, list):
        return found + ["cells is not a list"]
    seen = {}
    for cell in cells:
        key = (cell.get("target"), cell.get("scenario"))
        if key[0] not in TARGETS or key[1] not in SCENARIOS:
            found.append(f"unknown cell {key}")
            continue
        if key in seen:
            found.append(f"duplicate cell {key}")
        seen[key] = cell
        name = f"{key[0]}/{key[1]}"
        result = cell.get("result")
        if result not in RESULTS:
            found.append(f"{name}: result {result!r}")
            continue
        if result == "pending":
            if final:
                found.append(f"{name}: still pending")
            continue
        if not isinstance(cell.get("build"), str) or not cell["build"]:
            found.append(f"{name}: no build")
        if not (_time(cell.get("started")) and _time(cell.get("ended"))):
            found.append(f"{name}: no UTC start and end")
        if not cell.get("steps"):
            found.append(f"{name}: no steps")
        if result in ("fail", "inconclusive"):
            if not cell.get("reason"):
                found.append(f"{name}: {result} without a reason")
            continue
        seconds = cell.get("recovery_seconds")
        if not isinstance(seconds, (int, float)) or seconds < 0:
            found.append(f"{name}: pass without recovery_seconds")
        elif seconds > BOUNDS[key[1]]:
            found.append(f"{name}: pass beyond {BOUNDS[key[1]]} s")
        if cell.get("prompt_shown") != 1:
            found.append(f"{name}: pass needs the prompt shown exactly once")
        if cell.get("duplicates") != 0:
            found.append(f"{name}: pass with duplicates")
        if cell.get("stuck_running") is not False:
            found.append(f"{name}: pass needs stuck_running false")
        if key[1] == "handover" and not cell.get("transport_proof"):
            found.append(f"{name}: pass needs the transport change it observed")
        if key[1] in RECONNECTS and not cell.get("reconnect_proof"):
            found.append(f"{name}: pass needs the stream reconnect the server recorded")
        if not cell.get("evidence"):
            found.append(f"{name}: pass without evidence")
    for target in TARGETS:
        for scenario in SCENARIOS:
            if (target, scenario) not in seen:
                found.append(f"missing cell {target}/{scenario}")
    return found


def sums(folder: Path) -> list[str]:
    path = folder / "SHA256SUMS"
    if not path.is_file():
        return []
    found = []
    for number, line in enumerate(path.read_text().splitlines(), 1):
        if not line.strip():
            continue
        parts = line.split(maxsplit=1)
        if len(parts) != 2 or not re.fullmatch(r"[0-9a-f]{64}", parts[0]):
            found.append(f"SHA256SUMS line {number} is malformed")
            continue
        digest, name = parts[0], parts[1].strip().lstrip("*")
        target = folder / name
        if not target.is_file() or hashlib.sha256(target.read_bytes()).hexdigest() != digest:
            found.append(f"SHA256SUMS mismatch: {name}")
    return found


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("matrix", nargs="?", default=str(DEFAULT))
    parser.add_argument("--final", action="store_true", help="reject pending cells")
    args = parser.parse_args(argv)
    path = Path(args.matrix)
    found = problems(json.loads(path.read_text()), final=args.final) + sums(path.parent)
    for line in found:
        print(f"device-matrix: {line}", file=sys.stderr)
    return 1 if found else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
