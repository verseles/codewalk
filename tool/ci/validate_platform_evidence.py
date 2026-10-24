#!/usr/bin/env python3
"""Validate the V2-078A MVP platform evidence matrix (plan §15.4).

Every MVP target records each evidence dimension once; compiling, launching,
signing and the functional flow are separate cells and one never stands in
for another. A cell is pending until its producer runs. pass needs the
revision it was observed at and the evidence that shows it; pending-resource
names the missing resource and the next action; fail and inconclusive give
the reason; approved-tier links the recorded decision. Each passing dimension
carries its own fact: the artifact digest, the signer (or the explicit
unsigned record) and the device it ran on. G3, G4 and the provisional G5 are
rerun at a recorded revision. Deferred platforms are recorded but can never
pass. Every file beside the matrix is pinned in SHA256SUMS, every local
evidence file a cell cites is one of them, and none carries a credential or
an address.

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
RESULTS = {"pending", "pass", "pending-resource", "fail", "inconclusive", "approved-tier"}
REVISION = re.compile(r"[0-9a-f]{8,40}")
SHA256 = re.compile(r"[0-9a-f]{64}")
# Evidence that lives outside the folder (a CI run, an Issue comment).
REMOTE = "https://github.com/verseles/codewalk/"
TEXT_SUFFIXES = {".json", ".jsonl", ".md", ".txt", ".log"}


def _digest(value: object) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _dimension(name: str, target: str, dimension: str, cell: dict) -> list[str]:
    if dimension == "package" and not _digest(cell.get("sha256")):
        return [f"{name}: pass without the artifact sha256"]
    # An APK is always signed and names its package; a Linux bundle is not
    # signed, which is recorded rather than passed as signing.
    if dimension == "signature" and target.startswith("android-") and not (
            _digest(cell.get("signer_sha256")) and cell.get("application_id") and "unsigned" not in cell):
        return [f"{name}: pass without the APK signer and application id"]
    if dimension == "signature" and target.startswith("linux-") and not (
            cell.get("unsigned") is True and "signer_sha256" not in cell):
        return [f"{name}: pass without the explicit unsigned record"]
    if dimension in ("install", "functional") and not cell.get("device"):
        return [f"{name}: pass without the device or runner it ran on"]
    return []


def _revision(value: object) -> bool:
    return isinstance(value, str) and REVISION.fullmatch(value) is not None


def _cell(name: str, cell: dict, final: bool, gate: bool = False, target: str = "",
          dimension: str | None = None) -> list[str]:
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
    if result == "approved-tier":
        if not cell.get("decision"):
            found.append(f"{name}: approved-tier without the recorded decision")
        return found
    if not cell.get("producer"):
        found.append(f"{name}: pass without its producer")
    items = cell.get("evidence")
    if not (isinstance(items, list) and items and all(isinstance(item, str) and item for item in items)):
        found.append(f"{name}: pass without evidence")
    if gate and not cell.get("command"):
        found.append(f"{name}: pass without the command that ran")
    if dimension:
        found += _dimension(name, target, dimension, cell)
    return found


def problems(matrix: dict, final: bool = False) -> list[str]:
    found: list[str] = []
    text = json.dumps(matrix)
    if any(SECRET_VALUE_RE.search(t) for t in [text, *_strings(matrix)]):
        found.append("a credential-shaped value is recorded")
    for address in set(ADDRESS.findall(text)) - ALLOWED_ADDRESSES:
        found.append(f"an address is recorded: {address}")
    if matrix.get("unit") != "V2-078A" or matrix.get("server", {}).get("version") != "2.0.22":
        found.append("the matrix is not V2-078A on OpenCode 2.0.22")
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
        found += _cell(f"{key[0]}/{key[1]}", cell, final, target=key[0], dimension=key[1])
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


def _cited(matrix: dict) -> set[str]:
    entries = [*matrix.get("cells", []), *(matrix.get("gates") or {}).values()]
    cited = set()
    for entry in entries:
        if isinstance(entry, dict):
            items = entry.get("evidence")
            if isinstance(items, list):
                cited.update(item for item in items if isinstance(item, str) and not item.startswith(REMOTE))
    return cited


def folder_problems(folder: Path, matrix: dict) -> list[str]:
    found = sums(folder)
    sums_path = folder / "SHA256SUMS"
    if not sums_path.is_file():
        return found + ["SHA256SUMS is missing"]
    listed = {line.split(maxsplit=1)[1].strip().lstrip("*")
              for line in sums_path.read_text().splitlines() if len(line.split(maxsplit=1)) == 2}
    present = {path.relative_to(folder).as_posix() for path in folder.rglob("*")
               if path.is_file() and path.name != "SHA256SUMS"}
    for name in sorted(present - listed):
        found.append(f"{name} is not pinned in SHA256SUMS")
    for name in sorted(_cited(matrix) - present):
        found.append(f"cited evidence {name} is not beside the matrix")
    for name in sorted(present):
        path = folder / name
        if path.suffix not in TEXT_SUFFIXES:
            continue
        text = path.read_text(errors="replace")
        if SECRET_VALUE_RE.search(text):
            found.append(f"{name}: a credential-shaped value is recorded")
        for address in set(ADDRESS.findall(text)) - ALLOWED_ADDRESSES:
            found.append(f"{name}: an address is recorded: {address}")
    return found


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("matrix", nargs="?", default=str(DEFAULT))
    parser.add_argument("--final", action="store_true", help="reject pending cells")
    args = parser.parse_args(argv)
    path = Path(args.matrix)
    matrix = json.loads(path.read_text())
    found = problems(matrix, final=args.final) + folder_problems(path.parent, matrix)
    for line in found:
        print(f"platform-evidence: {line}", file=sys.stderr)
    return 1 if found else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
