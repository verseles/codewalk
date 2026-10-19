#!/usr/bin/env python3
"""Read-only cross-checks over the V2-060B live-smoke evidence.

Issues no request and starts no service: it only checks that the recorded
evidence is internally consistent, zero-spend and isolated.
"""
import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument(
    "--write-report", action="store_true", help="explicitly regenerate validation.json"
)
args = parser.parse_args()

read = lambda name: json.loads((ROOT / name).read_text())
results = read("results.json")
provenance = read("provenance.json")
events = read("events.json")
ledger = read("stub-ledger.json")
egress = read("egress.json")
cleanup = read("cleanup.json")
markers = [
    json.loads(line.split("CODEWALK_LIVE_QA ", 1)[1])
    for line in (ROOT / "markers.txt").read_text().splitlines()
    if "CODEWALK_LIVE_QA " in line
]

checks: dict[str, str] = {}


def check(name: str, condition: bool) -> None:
    assert condition, name
    checks[name] = "passed"


observed = {marker["phase"]: marker["status"] for marker in markers}
check("serverVersionIsPinned", provenance["runtimeVersion"] == "2.0.22")
check("artifactDigestRecorded", bool(provenance["artifact"]["tarballSha256"]) and bool(provenance["artifact"]["binarySha256"]))
check("nativeCostIsZero", provenance["nativeCostUSD"] == 0)
check("zeroSpendDeclared", results["zeroSpend"] is True)
check(
    "everyCapabilityObserved",
    all(
        results["capabilities"][name] == "passed"
        for name in (
            "pairing",
            "send",
            "approval",
            "approvalManual",
            "approvalAuto",
            "reconnect",
            "stop",
            "stopIdle",
        )
    ),
    )
check("markersAgreeWithResults", all(observed.get(name) == "passed" for name in results["capabilities"] if name in observed))
check("clientExitClean", events["flutterExit"] == 0)
check("nativeProbePassed", events["s0Probe"] == "passed")
check("stubRequestCapRespected", len(ledger["requests"]) <= ledger["cap"])
check(
    "stubScenariosMatchResults",
    any("CW060B_SCENARIO_SEND" in r["marker"] for r in ledger["requests"])
    and any("CW060B_SCENARIO_APPROVAL" in r["marker"] for r in ledger["requests"])
    and any("CW060B_SCENARIO_HOLD" in r["marker"] for r in ledger["requests"]),
)
check(
    "toolCallContinuedAfterApproval",
    any(r["has_tool_result"] for r in ledger["requests"]),
)
check("noEgressViolation", egress["violation"] is None and egress["nonLoopbackPeers"] == 0)
check("serverExited", cleanup["serverExited"] is True)
check("tempRootRemoved", cleanup["tempRootRemoved"] is True)
check("userProcessesUnchanged", cleanup["userOpencodeProcessesUnchanged"] is True)
check("ownedPortsReleased", cleanup["ownedPortsReleased"] is True)
check(
    "noForeignListeningPortLeft",
    not (
        set(cleanup["userListeningPortsAfter"])
        - set(cleanup["userListeningPortsBefore"])
        - set(cleanup.get("ownedPorts") or [])
    ),
)
check("limitationsRecorded", len(results["limitations"]) >= 3)

# No secret material may appear anywhere in this directory: an actual header,
# a bearer value or a credential field with a value (prose may name them).
secret = re.compile(
    r"(?i)(authorization\s*[:=]\s*[\"']?\S|bearer\s+[A-Za-z0-9._\-]{16,}"
    r"|\"(password|secret|token|code)\"\s*:\s*\"[^\"]{8,}\")"
)
for path in sorted(ROOT.iterdir()):
    if path.suffix == ".py" or path.name == "SHA256SUMS":
        continue
    check(f"noSecretMaterial:{path.name}", not secret.search(path.read_text()))

report = {
    "unit": "V2-060B",
    "status": "passed" if all(v == "passed" for v in checks.values()) else "failed",
    "checks": checks,
    "checkCount": len(checks),
}
if args.write_report:
    (ROOT / "validation.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({"status": report["status"], "checks": len(checks)}))
sys.exit(0 if report["status"] == "passed" else 1)
