#!/usr/bin/env python3
"""Read-only cross-checks over the V2-060B live-smoke evidence.

Issues no request and starts no service: it only checks that the recorded
evidence is internally consistent, zero-spend and isolated. Every file in
this directory except this script, the documentation and the derived report
is produced by the launcher from the recorded run.
"""
import argparse
import hashlib
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
capabilities = read("capabilities.json")
markers = [
    json.loads(line.split("CODEWALK_LIVE_QA ", 1)[1])
    for line in (ROOT / "markers.txt").read_text().splitlines()
    if "CODEWALK_LIVE_QA " in line
]

checks: dict[str, str] = {}


def check(name: str, condition: bool) -> None:
    checks[name] = "passed" if condition else "failed"


observed = {marker["phase"]: marker["status"] for marker in markers}
phases = capabilities["phases"]

# The digests pin the evidence files the launcher wrote.
for line in (ROOT / "SHA256SUMS").read_text().splitlines():
    if not line.strip():
        continue
    digest, name = line.split(None, 1)
    name = name.strip()
    actual = hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
    check(f"digest:{name}", actual == digest)

check("serverVersionIsPinned", provenance["runtimeVersion"] == "2.0.22")
# The evidence names the revision it was made from, and that revision must
# have been a clean tree: a run from a dirty tree cannot be reproduced.
check("provenanceNamesItsRevision", bool(provenance.get("repoCommit")))
check("provenanceTreeWasClean", provenance.get("repoTreeDirty") is False)
check(
    "artifactDigestRecorded",
    bool(provenance["artifact"]["tarballSha256"])
    and bool(provenance["artifact"]["binarySha256"]),
)
check("nativeCostIsZero", provenance["nativeCostUSD"] == 0)
check("zeroSpendDeclared", results["zeroSpend"] is True)
check("runDelivered", results["status"] == "delivered-awaiting-acceptance")
# Every capability the fixture claims is backed by the marker of its phase:
# the phase map is explicit, so a renamed phase can never be skipped.
check(
    "everyCapabilityObserved",
    set(results["capabilities"]) == set(phases.values()),
)
check(
    "everyCapabilityPassed",
    all(value == "passed" for value in results["capabilities"].values()),
)
check(
    "markersAgreeWithResults",
    all(observed.get(phase) == "passed" for phase in phases),
)
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
# The held stream must have ended with the client disconnect, not with the
# hold deadline: that is what proves the disconnect surfaced.
check(
    "holdEndedWithTheDisconnect",
    int(ledger.get("holdAbortedByDisconnect") or 0) >= 1,
)
check("noEgressViolation", egress["violation"] is None and egress["nonLoopbackPeers"] == 0)
# The audit must have run while the suite ran, not only once at the end.
check("egressAuditRan", int(egress.get("auditRuns") or 0) >= 2)
check("serverExited", cleanup["serverExited"] is True)
check("tempRootRemoved", cleanup["tempRootRemoved"] is True)
check("userServiceAlive", cleanup["userOpencodeServiceAlive"] is True)
check("ownedPortsReleased", cleanup["ownedPortsReleased"] is True)
check(
    "noOwnedPortStillListening",
    not (cleanup.get("ownedPortsStillListening") or []),
)
check(
    "noOwnedProcessSurvivor",
    not (cleanup.get("ownedProcessGroupSurvivors") or []),
)
check("limitationsRecorded", len(results["limitations"]) >= 3)

# No secret material may appear anywhere in this directory: an actual header,
# a bearer value or a credential field with a value (prose may name them).
# The derived report and the digest list are excluded: they are regenerated
# from the evidence and would make the check count unstable.
secret = re.compile(
    r"(?i)(authorization\s*[:=]\s*[\"']?\S|bearer\s+[A-Za-z0-9._\-]{16,}"
    r"|\"(password|secret|token|code)\"\s*:\s*\"[^\"]{8,}\")"
)
for path in sorted(ROOT.iterdir()):
    if not path.is_file():
        continue
    if path.suffix == ".py" or path.name in ("SHA256SUMS", "validation.json"):
        continue
    check(f"noSecretMaterial:{path.name}", not secret.search(path.read_text()))

failed = sorted(name for name, value in checks.items() if value != "passed")
report = {
    "unit": "V2-060B",
    "status": "passed" if not failed else "failed",
    "checks": checks,
    "checkCount": len(checks),
    "failedChecks": failed,
    "observations": {
        # Not gates: the user may act on the host while the run is live, and
        # a change there is not a leak of the run.
        "foreignPortsLeft": cleanup.get("foreignPortsLeft"),
        "userListeningPortsRemoved": cleanup.get("userListeningPortsRemoved"),
        "userOpencodeProcessesBefore": cleanup.get("userOpencodeProcessesBefore"),
        "userOpencodeProcessesAfter": cleanup.get("userOpencodeProcessesAfter"),
    },
}
if args.write_report:
    (ROOT / "validation.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({"status": report["status"], "checks": len(checks), "failed": failed}))
sys.exit(0 if report["status"] == "passed" else 1)
