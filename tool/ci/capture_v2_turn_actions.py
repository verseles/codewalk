#!/usr/bin/env python3
"""Capture V2-071G against an isolated, pinned 2.0.22 and zero-spend provider.

Nothing is published. Raw server logs and credentials stay in the owned temporary
root. Only sanitized requests, responses, events and cleanup reach --out. Existing
D captures remain immutable; they provide the actual file-restoration evidence.
"""

from __future__ import annotations

import argparse
import hashlib
import http.client
import json
import platform
import shutil
import subprocess
import sys
import threading
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import v2_device_server as device  # noqa: E402

MAX_STARTS = 12
TERMINALS = {
    "session.execution.succeeded", "session.execution.failed",
    "session.execution.interrupted",
}
OMIT = {"providerState", "providerContext", "authorization", "password", "token"}


def sanitized(value, root: Path):
    if isinstance(value, dict):
        return {k: sanitized(v, root) for k, v in value.items() if k not in OMIT}
    if isinstance(value, list):
        return [sanitized(v, root) for v in value]
    if isinstance(value, str):
        return value.replace(str(root), "<owned-root>")
    return value


class Events:
    def __init__(self, server: device.DeviceServer):
        self.server = server
        self.values: list[dict] = []
        self.failure: str | None = None
        self.ready = threading.Event()
        self.connection = http.client.HTTPConnection(
            "127.0.0.1", server.upstream_port, timeout=600,
        )
        self.thread = threading.Thread(target=self._read, daemon=True)

    def _read(self):
        try:
            self.connection.request("GET", "/api/event", headers={
                "Authorization": device.smoke._basic("opencode", self.server.password),
                "Accept": "text/event-stream",
            })
            response = self.connection.getresponse()
            if response.status != 200:
                raise RuntimeError("event stream refused")
            self.ready.set()
            while line := response.readline():
                if not line.startswith(b"data: "):
                    continue
                frame = json.loads(line[6:])
                # Native global stream can wrap the event with its location.
                event = frame.get("payload", frame)
                if not isinstance(event, dict) or "type" not in event:
                    raise RuntimeError("invalid event envelope")
                self.values.append(event)
                if len(self.values) > 10000:
                    raise RuntimeError("event budget exceeded")
                starts = sum(e["type"] == "session.execution.started" for e in self.values)
                if starts > MAX_STARTS:
                    raise RuntimeError("native execution budget exceeded")
        except (OSError, ValueError, RuntimeError) as error:
            self.failure = type(error).__name__
            self.ready.set()

    def start(self):
        self.thread.start()
        if not self.ready.wait(10) or self.failure:
            raise RuntimeError("event stream unavailable")

    def close(self):
        self.connection.close()
        self.thread.join(timeout=5)


class Capture:
    def __init__(self, server: device.DeviceServer, events: Events):
        self.server = server
        self.events = events
        self.calls: list[dict] = []
        self.sessions: list[str] = []

    def call(self, label, method, path, body=None, expected=None):
        status, raw = self.server.api(method, path, body)
        data = json.loads(raw) if raw else None
        self.calls.append({
            "label": label, "method": method, "path": path,
            "request": body, "status": status, "response": data,
        })
        if expected is not None and status != expected:
            raise RuntimeError(f"{label}: HTTP {status}, expected {expected}")
        return data

    def create(self, label):
        data = self.call(label, "POST", "/api/session", {
            "title": f"CW071G {label}",
            "location": {"directory": str(self.server.project)},
        }, 200)["data"]
        self.sessions.append(data["id"])
        return data["id"]

    def wait(self, predicate, label, seconds=60):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            if self.events.failure:
                raise RuntimeError("event collection failed")
            if predicate():
                return
            time.sleep(0.1)
        raise RuntimeError(f"{label}: observation timed out")

    def active(self, sid):
        status, raw = self.server.api("GET", "/api/session/active")
        if status != 200:
            raise RuntimeError("active session read failed")
        return sid in json.loads(raw)["data"]

    def idle(self, sid):
        self.wait(lambda: not self.active(sid), "session idle", 90)

    def prompt(self, sid, text, *, delivery="steer", resume=True, label="prompt"):
        return self.call(label, "POST", f"/api/session/{sid}/prompt", {
            "text": text, "delivery": delivery, "resume": resume,
        }, 200)["data"]

    def snapshot(self, label, sid):
        for suffix in ("", "/message?order=asc&limit=200", "/inbox"):
            self.call(label + suffix, "GET", f"/api/session/{sid}{suffix}", expected=200)

    def stage(self, label, sid, message):
        return self.call(label, "POST", f"/api/session/{sid}/revert/stage", {
            "messageID": message, "files": True,
        }, 200)

    def scenarios(self):
        sid = self.create("redo")
        first = self.prompt(sid, "CW071G first turn", label="first-turn")["id"]
        self.wait(lambda: any(e["type"] in TERMINALS and
                             e.get("data", {}).get("sessionID") == sid
                             for e in self.events.values), "first completion")
        self.idle(sid)
        second = self.prompt(sid, "CW071G second turn", label="second-turn")["id"]
        self.wait(lambda: sum(e["type"] in TERMINALS and
                             e.get("data", {}).get("sessionID") == sid
                             for e in self.events.values) >= 2, "second completion")
        self.idle(sid)
        self.snapshot("before-stage", sid)
        self.stage("undo-both", sid, first)
        self.snapshot("after-undo", sid)
        self.stage("redo-one", sid, second)
        self.snapshot("after-redo-one", sid)
        self.call("redo-all", "DELETE", f"/api/session/{sid}/revert", expected=204)
        self.idle(sid)
        self.stage("branch-stage", sid, first)
        self.call("branch-commit", "POST", f"/api/session/{sid}/revert/commit", expected=204)
        self.snapshot("after-commit", sid)
        self.prompt(sid, "CW071G replacement branch", label="branch-prompt")
        self.wait(lambda: sum(e["type"] in TERMINALS and
                             e.get("data", {}).get("sessionID") == sid
                             for e in self.events.values) >= 4, "branch completion")
        self.idle(sid)
        self.snapshot("after-branch", sid)

        # Busy compact is observed, not assumed to be a SessionBusy refusal.
        busy = self.create("busy")
        target = self.prompt(busy, "CW-SLOW8 CW071G busy", label="busy-prompt")["id"]
        self.wait(lambda: self.active(busy), "busy execution")
        self.call("busy-stage", "POST", f"/api/session/{busy}/revert/stage",
                  {"messageID": target, "files": True}, 409)
        self.call("busy-clear", "DELETE", f"/api/session/{busy}/revert", expected=409)
        self.call("busy-commit", "POST", f"/api/session/{busy}/revert/commit", expected=409)
        self.call("busy-compact", "POST", f"/api/session/{busy}/compact", {"delivery": "steer"}, 200)
        self.wait(lambda: any(e["type"] in TERMINALS and
                             e.get("data", {}).get("sessionID") == busy
                             for e in self.events.values), "busy completion")
        self.idle(busy)
        self.wait(lambda: any(e["type"] in {"session.compaction.ended", "session.compaction.failed"}
                             and e.get("data", {}).get("sessionID") == busy
                             for e in self.events.values), "busy compaction terminal")
        self.snapshot("after-busy", busy)

        compact = self.create("compact")
        self.prompt(compact, "CW071G context to compact", label="compact-prompt")
        self.wait(lambda: any(e["type"] in TERMINALS and
                             e.get("data", {}).get("sessionID") == compact
                             for e in self.events.values), "context completion")
        self.idle(compact)
        self.call("idle-compact", "POST", f"/api/session/{compact}/compact",
                  {"delivery": "steer"}, 200)
        self.wait(lambda: any(e["type"] in {"session.compaction.ended", "session.compaction.failed"}
                             and e.get("data", {}).get("sessionID") == compact
                             for e in self.events.values), "compaction terminal")
        self.idle(compact)
        self.snapshot("after-compact", compact)

    def cleanup(self):
        for sid in self.sessions:
            if self.active(sid):
                self.call("cleanup-interrupt", "POST", f"/api/session/{sid}/interrupt", {})
                self.idle(sid)
            self.call("cleanup-delete", "DELETE", f"/api/session/{sid}", expected=204)
            self.call("cleanup-absent", "GET", f"/api/session/{sid}", expected=404)
        self.call("cleanup-active", "GET", "/api/session/active", expected=200)


def problems(data: dict) -> list[str]:
    """Validate effects, not merely that requests completed or the script exited."""
    errors = []
    calls = {c["label"]: c for c in data.get("calls", [])}
    events = data.get("events", [])
    def require(condition, label):
        if not condition:
            errors.append(label)
    require(data.get("version") == "2.0.22", "version")
    pin = device.PINS.get(data.get("platform"), {})
    require(bool(pin) and data.get("binary_sha256") == pin.get("binary_sha256"), "binary pin")
    require(data.get("zero_spend_configuration") is True, "zero-spend configuration")
    require(isinstance(data.get("producer_sha256"), dict) and
            len(data["producer_sha256"]) == 2, "producer provenance")
    require(data.get("complete") is True, "collector did not complete")
    require(data.get("egress", {}).get("violation") is None and
            data.get("egress", {}).get("auditRuns", 0) > 1, "egress audit")
    require(data.get("provider_requests", MAX_STARTS + 1) <= MAX_STARTS, "provider request cap")
    require(data.get("user_servers_unchanged") is True, "user services changed")
    try:
        first = calls["first-turn"]["response"]["data"]["id"]
        second = calls["second-turn"]["response"]["data"]["id"]
        require(calls["undo-both"]["response"]["data"]["messageID"] == first, "stage boundary")
        require(calls["redo-one"]["response"]["data"]["messageID"] == second, "redo next boundary")
        require(calls["after-undo"]["response"]["data"]["revert"]["messageID"] == first,
                "authoritative staged state")
        require(calls["after-redo-one"]["response"]["data"]["revert"]["messageID"] == second,
                "authoritative redo state")
        require(calls["redo-all"]["status"] == 204, "clear response")
        require(calls["branch-commit"]["status"] == 204, "commit response")
        require(calls["after-commit/message?order=asc&limit=200"]["response"]["data"] == [],
                "commit did not remove tail")
        require(not calls["after-commit"]["response"]["data"].get("revert"), "commit retains revert")
        labels = [c["label"] for c in data["calls"]]
        require(labels.index("branch-commit") < labels.index("branch-prompt"), "commit-before-prompt")
        for label in ("busy-stage", "busy-clear", "busy-commit"):
            require(calls[label]["status"] == 409, label + " status")
            require("SessionBusy" in json.dumps(calls[label]["response"]), label + " error tag")
        admission = calls["idle-compact"]["response"]["data"]
        require(calls["idle-compact"]["status"] == 200 and admission["type"] == "compaction"
                and admission["delivery"] == "steer", "compact admission")
        require(any(e["type"] == "session.compaction.ended" and
                    e.get("data", {}).get("sessionID") == admission["sessionID"] for e in events),
                "compact successful completion")
        busy_admission = calls["busy-compact"]["response"]["data"]
        require(calls["busy-compact"]["status"] == 200
                and busy_admission["type"] == "compaction"
                and busy_admission["delivery"] == "steer", "busy compact admission")
        busy_starts = [i for i, e in enumerate(events)
                       if e["type"] == "session.compaction.started"
                       and e.get("data", {}).get("sessionID") == busy_admission["sessionID"]
                       and e.get("data", {}).get("inputID") == busy_admission["id"]]
        require(len(busy_starts) == 1 and any(
            e["type"] == "session.compaction.ended"
            and e.get("data", {}).get("sessionID") == busy_admission["sessionID"]
            for e in events[busy_starts[0] + 1:]
        ), "busy compact lifecycle")
        require(calls["cleanup-active"]["response"]["data"] == {}, "owned execution remains")
        require(len([c for c in data["calls"] if c["label"] == "cleanup-absent" and
                     c["status"] == 404]) == 3, "sessions not disposed")
    except (KeyError, TypeError, ValueError):
        errors.append("incomplete contract evidence")
    starts = [e for e in events if e.get("type") == "session.execution.started"]
    require(0 < len(starts) <= MAX_STARTS, "native execution cap")
    # This protocol has no executionID: pair starts and terminals in stream
    # order per session instead of matching an absent field (None == None).
    active = set()
    for event in events:
        sid = event.get("data", {}).get("sessionID")
        if event.get("type") == "session.execution.started":
            require(sid is not None and sid not in active, "overlapping native starts")
            active.add(sid)
        elif event.get("type") in TERMINALS:
            require(sid in active, "terminal without observed start")
            active.discard(sid)
    require(not active, "native executions without terminal")
    return errors


def run(root: Path, out: Path, binary: Path | None) -> int:
    if root.exists() or out.exists():
        raise RuntimeError("root and output must be new owned paths")
    if not root.is_relative_to(Path("/tmp/opencode")):
        raise RuntimeError("root must be under /tmp/opencode")
    root.mkdir(parents=True)
    if binary:
        (root / "bin").mkdir()
        shutil.copyfile(binary, root / "bin/opencode")
        (root / "bin/opencode").chmod(0o755)
    before = device.smoke._user_opencode_pids()
    server = device.DeviceServer(root, "127.0.0.1", 0)
    evidence = {"version": "2.0.22", "complete": False, "calls": [], "events": []}
    evidence["repo_commit"] = subprocess.check_output(
        ["git", "-C", str(Path(__file__).resolve().parents[2]), "rev-parse", "HEAD"], text=True,
    ).strip()
    evidence["producer_sha256"] = {
        name: hashlib.sha256(Path(__file__).with_name(name).read_bytes()).hexdigest()
        for name in ("capture_v2_turn_actions.py", "v2_device_server.py")
    }
    capture = events = auditor = None
    timer = threading.Timer(600, server.close)
    timer.daemon = True
    failure = None
    try:
        server.prepare()
        config = json.loads((root / "config.json").read_text())
        provider = config["providers"]["cw042c"]
        evidence["zero_spend_configuration"] = (
            set(config["providers"]) == {"cw042c"}
            and provider["models"]["stub"]["cost"] == {"input": 0, "output": 0}
            and provider["settings"]["baseURL"] == f"http://127.0.0.1:{server.stub.port}/v1"
            and config["permissions"] == [{"action": "*", "resource": "*", "effect": "deny"}]
            and config["experimental"]["policies"] == [
                {"action": "provider.use", "resource": "*", "effect": "deny"},
                {"action": "provider.use", "resource": "cw042c", "effect": "allow"},
            ]
        )
        if not evidence["zero_spend_configuration"]:
            raise RuntimeError("zero-spend configuration changed")
        server.start()
        timer.start()
        evidence["binary_sha256"] = hashlib.sha256(server.binary.read_bytes()).hexdigest()
        evidence["platform"] = platform.machine()
        auditor = device.smoke.EgressAuditor(server.process.pid)
        auditor.start()
        events = Events(server)
        events.start()
        capture = Capture(server, events)
        capture.scenarios()
        evidence["complete"] = True
    except (OSError, RuntimeError, ValueError, KeyError) as error:
        failure = error
    finally:
        try:
            if capture:
                capture.cleanup()
        except (OSError, RuntimeError, ValueError, KeyError) as error:
            failure = failure or error
            evidence["cleanup_failed"] = True
        finally:
            if capture:
                evidence["calls"] = capture.calls
            try:
                if auditor:
                    evidence["egress"] = auditor.stop()
            finally:
                server.close()
                timer.cancel()
                if events:
                    events.close()
                    evidence["events"] = events.values
        evidence["provider_requests"] = server.stub._requests if hasattr(server, "stub") else 0
        evidence["user_servers_unchanged"] = device.smoke._user_opencode_pids() == before
        out.mkdir(parents=True)
        raw = json.dumps(sanitized(evidence, root), indent=2) + "\n"
        (out / "capture.json").write_text(raw)
        (out / "SHA256SUMS").write_text(hashlib.sha256(raw.encode()).hexdigest() + "  capture.json\n")
    if failure:
        raise RuntimeError(str(failure)) from failure
    errors = problems(evidence)
    if errors:
        raise RuntimeError("; ".join(errors))
    print(f"V2-071G native evidence OK: {len(evidence['calls'])} calls, "
          f"{len(evidence['events'])} events, provider requests {evidence['provider_requests']}")
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--validate", type=Path)
    parser.add_argument("--root", type=Path)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--binary", type=Path)
    args = parser.parse_args()
    if args.validate:
        found = problems(json.loads(args.validate.read_text()))
        if found:
            parser.exit(1, "; ".join(found) + "\n")
        print("V2-071G captured contract OK")
    elif args.root and args.out:
        try:
            raise SystemExit(run(args.root.resolve(), args.out.resolve(), args.binary))
        except (OSError, RuntimeError, ValueError) as error:
            parser.exit(1, str(error) + "\n")
    else:
        parser.error("provide --validate, or --root and --out")
