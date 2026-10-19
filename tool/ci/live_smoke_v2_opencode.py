#!/usr/bin/env python3
"""V2-060B disposable OpenCode 2.0.22 live-smoke launcher (Tier B).

Owns the whole disposable lifecycle under a unique temp root:
acquire (official npm artifact + digest verify) -> isolate -> stub provider ->
serve (foreground, loopback, ephemeral port) -> S0 probe -> flutter test ->
cleanup -> sanitized evidence -> the committed evidence fixture.

Safety properties (fail closed, never touch the user):
- Only stdlib. No secrets leave this process except into the owned child env.
- Never runs `opencode service`, never touches port 49374/4096, never reads
  or writes the user's HOME/config/data/credentials.
- Refuses to execute when registry digests mismatch or the binary is not the
  pinned 2.0.22 linux-arm64 build. An acquisition record left behind by an
  earlier run is never trusted on its own: the binary digest and version are
  re-verified before it runs.
- The stub provider only serves deterministic tokens on loopback; an egress
  audit samples the owned server's sockets while the live suite runs and
  kills the run on any non-loopback peer, including when the audit itself
  cannot run.
- A failed cleanup fails the run, and the emitted evidence never claims more
  than the run proved.

Usage:
  python3 tool/ci/live_smoke_v2_opencode.py acquire --root /tmp/x
  python3 tool/ci/live_smoke_v2_opencode.py run --root /tmp/x \\
      --evidence-out /tmp/v2-060b-evidence \\
      --fixture-out test/contract/fixtures/opencode/2.0.22/live-smoke-060b \\
      --flutter-test test/v2/sessions/live_flow_smoke_test.dart
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import re
import shutil
import signal
import socket
import subprocess
import sys
import tarfile
import threading
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import NoReturn

NPM_META_URL = "https://registry.npmjs.org/@opencode%2fcli-linux-arm64/2.0.22"
# Historical pins (d-retry-quota/acquisition.json). A live-registry mismatch
# is a hard failure, never a silent substitution.
PINNED_TARBALL_SHA256 = (
    "49e5466de60f65001cddd7583419f842140697daead2b4d8826be54d9056e70b"
)
PINNED_BINARY_SHA256 = (
    "f27539d9c05c970d3eb9ad6a7724b75d3e638932c5423554f5ecbfe0ee2e8815"
)
EXPECTED_VERSION = "2.0.22"
NPM_PACKAGE = "@opencode/cli-linux-arm64"
MAX_STUB_REQUESTS = 12
ISSUE_URL = "https://github.com/verseles/codewalk/issues/300"
REPO_ROOT = Path(__file__).resolve().parents[2]
LAUNCHER_PATH = "tool/ci/live_smoke_v2_opencode.py"
LIVE_SUITE_PATH = "test/v2/sessions/live_flow_smoke_test.dart"

# The marker phase of every capability, and the capability it proves. The map
# is explicit: the marker phases and the capability names differ on purpose,
# so the fixture never infers one from the other by string equality.
CAPABILITY_PHASES = {
    "pairing": "pairing",
    "send": "send",
    "approval": "approval",
    "approval-manual": "approvalManual",
    "approval-auto": "approvalAuto",
    "reconnect-detection": "reconnect",
    "stop-reconnect": "stop",
    "stop-idle": "stopIdle",
}

FIXTURE_LIMITATIONS = [
    "The disposable server ran on this Linux aarch64 host; no Android device, "
    "installed client or Windows/macOS target was exercised.",
    "The provider was a loopback stub (deterministic tokens, cost 0); no real "
    "model turn and no provider credential were used, so the live evidence "
    "proves the CodeWalk client contract, not provider behaviour.",
    "The turn that produced the tool-originated permission was served by the "
    "stub; the model-origin continuation after approval is a stub behaviour.",
    "The screenshots and installed-native acceptance of the same screens stay "
    "with V2-060A (accepted) and the MVP platform checkpoints.",
]

FIXTURE_TOPOLOGY = (
    "owned foreground `opencode serve` on 127.0.0.1 with an ephemeral port, "
    "isolated HOME/XDG, a fresh password and a loopback stub provider"
)

FIXTURE_REDACTIONS = [
    "The disposable password never left the launcher child environment.",
    "No Authorization header, pairing code or paired token was recorded.",
]

# Loopback calls must never traverse a proxy: the environment may carry the
# user's http_proxy/ALL_PROXY, and the loopback traffic carries the Basic
# auth of the disposable password. The registry download keeps the default
# opener, which may legitimately need the user's proxy.
_LOOPBACK_OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}))

# The proxy variables are stripped from the live-suite child environment for
# the same reason: dart:io's HttpClient honours them by default.
_PROXY_VARS = (
    "http_proxy",
    "https_proxy",
    "all_proxy",
    "HTTP_PROXY",
    "HTTPS_PROXY",
    "ALL_PROXY",
)


class Fatal(SystemExit):
    """A fatal launcher error that keeps its message and its reason.

    `SystemExit(code)` alone loses the message, which made a provenance
    block indistinguishable from a run that never reached a verdict.
    """

    def __init__(self, message: str, code: int = 2, blocked: bool = False) -> None:
        super().__init__(code)
        self.message = message
        self.blocked = blocked


def fail(msg: str, code: int = 2, blocked: bool = False) -> "NoReturn":
    print(f"live-smoke: FATAL: {msg}", file=sys.stderr, flush=True)
    raise Fatal(msg, code=code, blocked=blocked)


def _failure_status(error: "Fatal") -> str:
    """A blocked provenance or registry stop is not an inconclusive run."""
    return "blocked" if error.blocked else "failed"


def _cleanup_ok(cleanup: dict) -> bool:
    """The isolation proof: everything the run owned is gone again.

    The gates are the facts the launcher can attribute to itself: its own
    process group, its own ports, its own tree, and the user's service still
    running. A port or a process the user opened during the run is recorded
    as an observation, never as a leak of ours.
    """
    return bool(
        cleanup.get("server_exited")
        and cleanup.get("temp_root_removed")
        and cleanup.get("owned_ports_released")
        and not (cleanup.get("owned_process_group_survivors") or [])
        and cleanup.get("user_opencode_service_alive")
        and cleanup.get("user_listening_ports_preserved")
    )


def _child_env(base: dict) -> dict:
    """The live-suite child environment: no proxy, loopback explicitly exempt."""
    env = dict(base)
    for name in _PROXY_VARS:
        env.pop(name, None)
    env["NO_PROXY"] = "127.0.0.1,localhost"
    env["no_proxy"] = "127.0.0.1,localhost"
    return env


def _http_get_json(url: str, timeout: int = 60) -> dict:
    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        if resp.status != 200:
            fail(f"registry metadata HTTP {resp.status} for {url}")
        return json.loads(resp.read().decode("utf-8"))


def _sha512_sri(data: bytes) -> str:
    return "sha512-" + base64.b64encode(hashlib.sha512(data).digest()).decode()


def _is_safe_binary_member(m: tarfile.TarInfo) -> bool:
    name = m.name
    if name.startswith("/") or ".." in Path(name).parts:
        return False
    if m.issym() or m.islnk() or not m.isfile():
        return False
    return name == "package/bin/opencode"


def _build_server_config(stub_port: int) -> dict:
    return {
        "update": "disable",
        "share": "disabled",
        "snapshots": False,
        "warming": False,
        "model": "cw060b/stub",
        "providers": {
            "cw060b": {
                "package": "@opencode/ai/providers/openai-compatible",
                "settings": {
                    "baseURL": f"http://127.0.0.1:{stub_port}/v1",
                    "headerTimeout": False,
                    "chunkTimeout": False,
                },
                "models": {
                    "stub": {
                        "name": "cw060b stub",
                        "cost": {"input": 0, "output": 0},
                        "capabilities": {"tools": True},
                    }
                },
            }
        },
        "experimental": {
            "policies": [
                {"action": "provider.use", "resource": "*", "effect": "deny"},
                {"action": "provider.use", "resource": "cw060b", "effect": "allow"},
            ]
        },
        "permissions": [
            {"action": "*", "resource": "*", "effect": "deny"},
            {"action": "read", "resource": "*", "effect": "ask"},
            {"action": "cw060b_smoke", "resource": "*", "effect": "ask"},
        ],
    }


def _verify_binary(binary: Path) -> str:
    """Refuse to execute anything that is not the pinned 2.0.22 binary.

    Called for a freshly acquired binary and for one named by a record left
    behind by an earlier run: a record is a hint, never a proof.
    """
    if not binary.is_file():
        fail(
            f"the acquired binary is missing: {binary} (blocked:provenance).",
            blocked=True,
        )
    digest = hashlib.sha256(binary.read_bytes()).hexdigest()
    if digest != PINNED_BINARY_SHA256:
        fail(
            "binary SHA-256 differs from the pinned acquisition record; "
            "refusing to execute (blocked:provenance).",
            blocked=True,
        )
    proc = subprocess.run(
        [str(binary), "--version"],
        capture_output=True,
        text=True,
        timeout=60,
        env={"PATH": "/usr/bin:/bin", "LANG": "C.UTF-8"},
    )
    if proc.stdout.strip() != f"opencode v{EXPECTED_VERSION}":
        fail(
            f"binary --version mismatch: {proc.stdout.strip()!r} "
            "(blocked:provenance).",
            blocked=True,
        )
    return digest


def acquire(root: Path) -> dict:
    """Fetch + verify the official linux-arm64 2.0.22 artifact. No secrets."""
    root.mkdir(parents=True, exist_ok=True)
    dl = root / "dl"
    dl.mkdir(exist_ok=True)
    meta = _http_get_json(NPM_META_URL)
    try:
        # Version-pinned metadata carries dist at the top level.
        if meta.get("version") != "2.0.22" or meta.get("name") != NPM_PACKAGE:
            fail("npm metadata is not @opencode/cli-linux-arm64@2.0.22")
        dist = meta["dist"]
        tarball_url, integrity, shasum = (
            dist["tarball"],
            dist["integrity"],
            dist.get("shasum", ""),
        )
    except KeyError:
        fail("npm metadata lacks dist{tarball,integrity}")
    if "linux-arm64" not in tarball_url:
        fail(f"tarball URL is not linux-arm64: {tarball_url}")
    if not integrity.startswith("sha512-"):
        fail(f"unexpected integrity algorithm: {integrity[:32]}")
    archive = dl / "cli-linux-arm64-2.0.22.tgz"
    req = urllib.request.Request(tarball_url)
    with urllib.request.urlopen(req, timeout=300) as resp, open(archive, "wb") as f:
        shutil.copyfileobj(resp, f, length=1024 * 256)
    data = archive.read_bytes()
    if _sha512_sri(data) != integrity:
        fail("tarball SHA-512 integrity mismatch; refusing to execute")
    tarball_sha256 = hashlib.sha256(data).hexdigest()
    if tarball_sha256 != PINNED_TARBALL_SHA256:
        fail(
            "tarball SHA-256 differs from the pinned acquisition record; "
            "registry may have changed. Stopping (blocked:provenance).",
            blocked=True,
        )
    bin_dir = root / "bin"
    bin_dir.mkdir(exist_ok=True)
    safe_members = []
    with tarfile.open(archive, "r:gz") as tf:
        for m in tf.getmembers():
            if not _is_safe_binary_member(m):
                if m.name.startswith("/") or ".." in Path(m.name).parts:
                    fail(f"unsafe tar member path: {m.name!r}")
                continue
            safe_members.append(m)
    if len(safe_members) != 1:
        fail("expected exactly one package/bin/opencode member")
    with tarfile.open(archive, "r:gz") as tf:
        tf.extract(safe_members[0], path=dl, filter="data")
    binary = dl / "package" / "bin" / "opencode"
    binary.chmod(0o755)
    digest = _verify_binary(binary)
    record = {
        "tarball_url": tarball_url,
        "tarball_integrity": integrity,
        "tarball_sha256": tarball_sha256,
        "binary_sha256": digest,
        "version": EXPECTED_VERSION,
        "binary": str(binary),
    }
    (root / "acquire.json").write_text(json.dumps(record, indent=2) + "\n")
    print(f"live-smoke: acquired 2.0.22 linux-arm64 ({digest[:16]}...)")
    return record


class _StubHandler(BaseHTTPRequestHandler):
    """Deterministic zero-spend token source. Records scenario + tool use."""

    server_version = "CW060BStub/1"
    protocol_version = "HTTP/1.1"

    def log_message(self, *args, **kwargs):  # noqa: ANN - quiet
        return

    def _send_json(self, code: int, obj: dict) -> None:
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):  # noqa: N802
        stub = self.server.stub  # type: ignore[attr-defined]
        length = int(self.headers.get("Content-Length", "0") or 0)
        raw = self.rfile.read(length) if length > 0 else b""
        try:
            payload = json.loads(raw.decode("utf-8") or "{}")
        except (ValueError, UnicodeDecodeError):
            payload = {}
        texts = []
        for m in payload.get("messages", []) or []:
            c = m.get("content")
            if isinstance(c, str):
                texts.append(c)
            elif isinstance(c, list):
                texts += [p.get("text", "") for p in c if isinstance(p, dict)]
        # The history accumulates every prompt of the session; the scenario
        # is driven by the most recent marker, never the first.
        marker = next(
            (t for t in reversed(texts) if "CW060B_SCENARIO_" in t),
            "",
        )
        tools = [t.get("function", {}).get("name") for t in payload.get("tools", []) or []]
        messages = payload.get("messages", []) or []
        # Tool results arrive as role:"tool" messages (OpenAI wire shape), not
        # as content parts typed tool_result; accept both shapes explicitly.
        has_tool_result = any(
            (isinstance(m, dict) and m.get("role") == "tool")
            or (
                isinstance(m, dict)
                and isinstance(m.get("content"), list)
                and any(
                    isinstance(p, dict)
                    and p.get("type")
                    in ("tool_result", "toolResult", "function_call_output")
                    for p in m["content"]
                )
            )
            for m in messages
        )
        roles = [
            m.get("role") if isinstance(m, dict) else type(m).__name__
            for m in messages
        ]
        n = stub.record(marker, tools, has_tool_result, roles)
        if n > MAX_STUB_REQUESTS:
            self._send_json(429, {"error": "stub request cap exceeded"})
            return
        if self.path != "/v1/chat/completions":
            self._send_json(404, {"error": "stub serves only chat completions"})
            return
        if "HOLD" in marker:
            # Hold the stream open until the client disconnects (reconnect
            # test). The stream has no Content-Length: a heartbeat keeps it
            # writing, so a client that goes away surfaces here as a broken
            # pipe instead of hanging forever.
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.end_headers()
            self.close_connection = True
            deadline = time.time() + 120
            try:
                while time.time() < deadline:
                    self.wfile.write(b": hold\n\n")
                    self.wfile.flush()
                    time.sleep(0.5)
            except (BrokenPipeError, ConnectionResetError):
                pass
            stub.record_hold_aborted()
            return
        if "APPROVAL" in marker and not has_tool_result:
            fn = next((t for t in tools if t), "read")
            chunk = {
                "id": f"chatcmpl-cw060b-{n}",
                "object": "chat.completion.chunk",
                "created": int(time.time()),
                "model": payload.get("model", "cw060b/stub"),
                "choices": [
                    {
                        "index": 0,
                        "delta": {
                            "tool_calls": [
                                {
                                    "id": f"call_{n}",
                                    "type": "function",
                                    "function": {
                                        "name": fn,
                                        "arguments": json.dumps(
                                            {"path": "approval-marker.txt"}
                                        ),
                                    },
                                }
                            ]
                        },
                        "finish_reason": "tool_calls",
                    }
                ],
            }
            line = f"data: {json.dumps(chunk)}\n\ndata: [DONE]\n\n".encode()
        else:
            text = (
                "CW060B_STUB_APPROVAL_OK"
                if "APPROVAL" in marker
                else "CW060B_STUB_SEND_OK"
            )
            chunk = {
                "id": f"chatcmpl-cw060b-{n}",
                "object": "chat.completion.chunk",
                "created": int(time.time()),
                "model": payload.get("model", "cw060b/stub"),
                "choices": [
                    {
                        "index": 0,
                        "delta": {"content": text},
                        "finish_reason": "stop",
                    }
                ],
                "usage": {
                    "prompt_tokens": 0,
                    "completion_tokens": 0,
                    "cost": 0,
                },
            }
            line = f"data: {json.dumps(chunk)}\n\ndata: [DONE]\n\n".encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Content-Length", str(len(line)))
        self.end_headers()
        self.wfile.write(line)


class StubProvider:
    def __init__(self) -> None:
        self.ledger: list[dict] = []
        self.hold_aborted = 0
        self._lock = threading.Lock()
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), _StubHandler)
        self.server.stub = self  # type: ignore[attr-defined]
        self.server.daemon_threads = True
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)

    @property
    def port(self) -> int:
        addr = self.server.server_address
        return int(addr[1])

    def start(self) -> None:
        self.thread.start()

    def stop(self) -> None:
        # server_close() releases the listening socket: without it the stub
        # port stays LISTEN and the isolation proof would claim a port that
        # is still open.
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=10)

    def record(
        self, marker: str, tools: list, has_tool_result: bool, roles: list | None = None
    ) -> int:
        with self._lock:
            self.ledger.append(
                {
                    "n": len(self.ledger) + 1,
                    "marker": marker[-64:],
                    "tools": tools,
                    "has_tool_result": has_tool_result,
                    "roles": roles or [],
                }
            )
            return len(self.ledger)

    def record_hold_aborted(self) -> None:
        with self._lock:
            self.hold_aborted += 1


def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return int(s.getsockname()[1])


def _basic(user: str, secret: str) -> str:
    return "Basic " + base64.b64encode(f"{user}:{secret}".encode()).decode()


def _api(endpoint: str, secret: str, method: str, path: str, body=None) -> tuple[int, bytes]:
    data = None
    headers = {"Accept": "application/json", "Authorization": _basic("opencode", secret)}
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(endpoint + path, data=data, headers=headers, method=method)
    try:
        with _LOOPBACK_OPENER.open(req, timeout=30) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def _egress_audit(pid: int) -> tuple[str | None, int]:
    """Audit the owned server's sockets once.

    Returns (violation, observed_sockets). The audit fails closed: an
    unavailable `ss` is a violation, never a clean result.
    """
    try:
        proc = subprocess.run(
            ["ss", "-tnpH"], capture_output=True, text=True, timeout=15
        )
    except (FileNotFoundError, subprocess.SubprocessError):
        return ("egress audit unavailable: ss could not be executed", 0)
    if proc.returncode != 0:
        return (f"egress audit unavailable: ss exited {proc.returncode}", 0)
    # The pid must match exactly: a substring form (pid=123 matching
    # pid=1234) would audit the wrong process.
    pattern = re.compile(rf"pid={pid}(?=[,)])")
    observed = 0
    for line in proc.stdout.splitlines():
        if not pattern.search(line):
            continue
        parts = line.split()
        if len(parts) < 5 or parts[0] != "ESTAB":
            continue
        observed += 1
        peer = parts[4].rsplit(":", 1)[0].strip("[]")
        if peer not in ("127.0.0.1", "::1"):
            return (f"non-loopback ESTAB peer {peer} on pid {pid}", observed)
    return (None, observed)


class EgressAuditor:
    """Samples the owned server's sockets while the live suite runs.

    A single post-run sample cannot support a "never observed" claim, so the
    audit samples continuously and keeps the first violation it sees.
    """

    def __init__(self, pid: int, interval: float = 2.0) -> None:
        self.pid = pid
        self.interval = interval
        self.samples = 0
        self.violation: str | None = None
        self._stop = threading.Event()
        self._stopped = False
        self._thread = threading.Thread(target=self._loop, daemon=True)

    def _loop(self) -> None:
        while not self._stop.is_set():
            violation, observed = _egress_audit(self.pid)
            self.samples += observed
            if violation and not self.violation:
                self.violation = violation
            self._stop.wait(self.interval)

    def start(self) -> None:
        self._thread.start()

    def stop(self) -> tuple[str | None, int]:
        # Idempotent: the finally block stops the auditor even when the run
        # already stopped it, and a second audit must not double-count.
        if self._stopped:
            return self.violation, self.samples
        self._stopped = True
        self._stop.set()
        self._thread.join(timeout=15)
        violation, observed = _egress_audit(self.pid)
        self.samples += observed
        if violation and not self.violation:
            self.violation = violation
        return self.violation, self.samples


def _listening_ports() -> list[int]:
    """The loopback/listening ports of this host, for the isolation audit."""
    ports: list[int] = []
    try:
        with open("/proc/net/tcp", encoding="utf-8") as handle:
            next(handle, None)
            for line in handle:
                fields = line.split()
                if len(fields) > 3 and fields[3] == "0A":
                    ports.append(int(fields[1].split(":")[1], 16))
    except OSError:
        return ports
    return sorted(ports)


def _is_opencode_server(argv: list[str]) -> bool:
    """True when the process is an `opencode serve` server.

    The match is on the argv shape, never on a substring: a shell or an agent
    that merely mentions "opencode" and "serve" in its command line is not a
    server, and counting it made the isolation proof depend on whatever the
    user happened to be running.
    """
    if len(argv) < 2:
        return False
    if Path(argv[0]).name != "opencode":
        return False
    return argv[1] == "serve"


def _user_opencode_pids(exclude_pids: set[int] | None = None) -> list[int]:
    """The user's own OpenCode servers, so cleanup can prove it spared them.

    The owned disposable server is excluded by pid, never by a path fragment:
    the root directory is chosen by the caller.
    """
    exclude = exclude_pids or set()
    pids: list[int] = []
    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        if int(entry) in exclude:
            continue
        try:
            with open(f"/proc/{entry}/cmdline", "rb") as handle:
                raw = handle.read().decode("utf-8", "replace")
        except OSError:
            continue
        argv = [part for part in raw.split("\x00") if part]
        if _is_opencode_server(argv):
            pids.append(int(entry))
    return sorted(pids)


def _processes_in_group(pgid: int) -> list[int]:
    """The pids still alive in a process group."""
    pids: list[int] = []
    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        try:
            with open(f"/proc/{entry}/stat", "rb") as handle:
                stat = handle.read().decode("utf-8", "replace")
            fields = stat.rsplit(") ", 1)[-1].split()
            if int(fields[2]) == pgid:
                pids.append(int(entry))
        except (OSError, ValueError, IndexError):
            continue
    return sorted(pids)


def _repo_head() -> str:
    """The commit the run was made from; provenance for the fixture."""
    try:
        proc = subprocess.run(
            ["git", "-C", str(REPO_ROOT), "rev-parse", "HEAD"],
            capture_output=True,
            text=True,
            timeout=15,
        )
        return proc.stdout.strip() if proc.returncode == 0 else "unknown"
    except (OSError, subprocess.SubprocessError):
        return "unknown"


def _parse_markers(events: list[str]) -> tuple[list[dict], dict[str, str]]:
    """The QA markers of the live suite, as records and as phase->status."""
    records: list[dict] = []
    for line in events:
        if "CODEWALK_LIVE_QA " not in line:
            continue
        try:
            records.append(json.loads(line.split("CODEWALK_LIVE_QA ", 1)[1]))
        except ValueError:
            continue
    observed: dict[str, str] = {}
    for record in records:
        observed[record.get("phase", "")] = record.get("status", "")
    return records, observed


def _write_fixture(evidence: dict, out: Path) -> None:
    """Write the committed evidence fixture from this run.

    The fixture is generated, never hand-edited: every value comes from the
    recorded run, so it cannot claim more than the run proved.
    """
    records, observed = _parse_markers(evidence.get("events", []))
    capabilities = {
        capability: observed.get(phase, "missing")
        for phase, capability in CAPABILITY_PHASES.items()
    }
    native_cost = 0.0
    for record in records:
        if record.get("phase") == "native-cost" and "cost" in record:
            native_cost = float(record["cost"])
    cleanup = evidence.get("cleanup", {})
    egress = evidence.get("egress", {})
    acquisition = evidence.get("acquisition", {})
    results = {
        "unit": "V2-060B",
        "issue": ISSUE_URL,
        "status": evidence.get("status"),
        "serverVersion": evidence.get("version"),
        "host": evidence.get("host"),
        "zeroSpend": evidence.get("zero_spend"),
        "capabilities": capabilities,
        "limitations": list(FIXTURE_LIMITATIONS),
    }
    provenance = {
        "unit": "V2-060B",
        "issue": ISSUE_URL,
        "status": evidence.get("status"),
        "capturedOn": datetime.now(timezone.utc).date().isoformat(),
        "platform": "Linux aarch64",
        "runtimeVersion": evidence.get("version"),
        "implementationLine": "main",
        "repoCommit": _repo_head(),
        "artifact": {
            "package": f"{NPM_PACKAGE}@{EXPECTED_VERSION}",
            "tarballUrl": acquisition.get("tarball_url"),
            "tarballSha256": acquisition.get("tarball_sha256"),
            "binarySha256": acquisition.get("binary_sha256"),
        },
        "topology": FIXTURE_TOPOLOGY,
        "nativeCostUSD": native_cost,
        "stubRequests": evidence.get("stub_requests"),
        "wallSeconds": evidence.get("wall_seconds"),
        "launcher": LAUNCHER_PATH,
        "suite": LIVE_SUITE_PATH,
        "redactions": list(FIXTURE_REDACTIONS),
    }
    events_doc = {
        "markers": records,
        "flutterExit": evidence.get("flutter_exit"),
        "s0Probe": evidence.get("s0_probe"),
    }
    ledger_doc = {
        "requests": evidence.get("stub_ledger", []),
        "holdAborted": evidence.get("stub_hold_aborted"),
        "cap": MAX_STUB_REQUESTS,
    }
    egress_doc = {
        "violation": egress.get("violation"),
        "nonLoopbackPeers": egress.get("nonLoopbackPeers"),
        "samples": egress.get("samples"),
        "auditedAt": egress.get("auditedAt"),
        "policy": (
            "provider.use deny for every provider except the loopback stub; a "
            "proxy black hole and a continuous egress audit fail the run closed"
        ),
    }
    cleanup_doc = {
        "serverExited": cleanup.get("server_exited"),
        "tempRootRemoved": cleanup.get("temp_root_removed"),
        "userOpencodeServiceAlive": cleanup.get("user_opencode_service_alive"),
        "userOpencodeProcessesBefore": cleanup.get("user_opencode_processes_before"),
        "userOpencodeProcessesAfter": cleanup.get("user_opencode_processes_after"),
        "ownedPorts": cleanup.get("owned_ports"),
        "ownedPortsStillListening": cleanup.get("owned_ports_still_listening"),
        "ownedPortsReleased": cleanup.get("owned_ports_released"),
        "ownedProcessGroupSurvivors": cleanup.get("owned_process_group_survivors"),
        "userListeningPortsBefore": cleanup.get("listening_ports_before"),
        "userListeningPortsAfter": cleanup.get("listening_ports_after"),
        "userListeningPortsPreserved": cleanup.get("user_listening_ports_preserved"),
        "foreignPortsLeft": cleanup.get("foreign_ports_left"),
    }
    files = {
        "capabilities.json": {"unit": "V2-060B", "phases": CAPABILITY_PHASES},
        "results.json": results,
        "provenance.json": provenance,
        "events.json": events_doc,
        "stub-ledger.json": ledger_doc,
        "egress.json": egress_doc,
        "cleanup.json": cleanup_doc,
    }
    out.mkdir(parents=True, exist_ok=True)
    for name, doc in files.items():
        (out / name).write_text(json.dumps(doc, indent=2) + "\n")
    (out / "markers.txt").write_text(
        "\n".join(
            "CODEWALK_LIVE_QA " + json.dumps(record) for record in records
        )
        + "\n"
    )
    # The digests pin the evidence files; the derived report and the
    # documentation tools stay out of the list.
    digests = []
    for name in sorted(files) + ["markers.txt"]:
        digests.append(
            f"{hashlib.sha256((out / name).read_bytes()).hexdigest()}  {name}"
        )
    (out / "SHA256SUMS").write_text("\n".join(digests) + "\n")


def run(
    root: Path,
    evidence_out: Path,
    flutter_test: str,
    fixture_out: Path | None = None,
) -> int:
    password = None
    server = None
    stub = None
    auditor = None
    server_pgid: int | None = None
    t0 = time.time()
    events: list[str] = []
    server_port: int | None = None
    evidence: dict = {
        "status": "inconclusive",
        "version": EXPECTED_VERSION,
        "host": "linux-aarch64",
        "zero_spend": False,
    }
    try:
        acq_path = root / "acquire.json"
        record = None
        if acq_path.exists():
            try:
                candidate = json.loads(acq_path.read_text())
                if isinstance(candidate.get("binary"), str):
                    record = candidate
            except (OSError, ValueError):
                record = None
        if record is None:
            record = acquire(root)
        binary = Path(record["binary"])
        # A record from an earlier run is a hint, never a proof: the binary
        # digest and version are re-verified before it runs.
        digest = _verify_binary(binary)
        evidence["acquisition"] = {
            k: record[k]
            for k in ("tarball_url", "tarball_sha256", "binary_sha256", "version")
        }
        evidence["acquisition"]["binary_sha256"] = digest
        # Isolation baseline: the user's own listeners and OpenCode processes
        # must be identical before and after the run.
        evidence["isolation_before"] = {
            "listening_ports": _listening_ports(),
            "user_opencode_pids": _user_opencode_pids(),
        }
        # Isolated tree.
        home = root / "home"
        for name in ("home", "xdg-config", "xdg-data", "xdg-state", "xdg-cache", "tmp", "project"):
            (root / name).mkdir(parents=True, exist_ok=True)
        project = root / "project"
        subprocess.run(
            ["git", "init", "-q", str(project)],
            check=True,
            timeout=60,
            env={"PATH": "/usr/bin:/bin", "HOME": str(home)},
        )
        (project / "approval-marker.txt").write_text("CW060B_APPROVAL_MARKER\n")
        subprocess.run(
            ["git", "-C", str(project), "-c", "user.email=cw060b@invalid",
             "-c", "user.name=cw060b", "add", "-A"],
            check=True,
            timeout=60,
            env={"PATH": "/usr/bin:/bin", "HOME": str(home)},
        )
        subprocess.run(
            ["git", "-C", str(project), "-c", "user.email=cw060b@invalid",
             "-c", "user.name=cw060b", "commit", "-qm", "cw060b disposable"],
            check=True,
            timeout=60,
            env={"PATH": "/usr/bin:/bin", "HOME": str(home)},
        )
        import secrets as _secrets

        password = _secrets.token_urlsafe(32)
        stub = StubProvider()
        stub.start()
        config = _build_server_config(stub.port)
        (root / "config.json").write_text(json.dumps(config, indent=2) + "\n")
        env = {
            "PATH": "/usr/bin:/bin",
            "LANG": "C.UTF-8",
            "HOME": str(home),
            "TMPDIR": str(root / "tmp"),
            "XDG_CONFIG_HOME": str(root / "xdg-config"),
            "XDG_DATA_HOME": str(root / "xdg-data"),
            "XDG_CACHE_HOME": str(root / "xdg-cache"),
            "XDG_STATE_HOME": str(root / "xdg-state"),
            "OPENCODE_SERVER_PASSWORD": password,
            "OPENCODE_CONFIG": str(root / "config.json"),
            "OPENCODE_DISABLE_MODELS_FETCH": "1",
            "OPENCODE_DISABLE_AUTOUPDATE": "1",
            "OPENCODE_DISABLE_PROJECT_CONFIG": "1",
            "HTTP_PROXY": "http://127.0.0.1:9",
            "HTTPS_PROXY": "http://127.0.0.1:9",
            "ALL_PROXY": "http://127.0.0.1:9",
            "NO_PROXY": "127.0.0.1,localhost",
        }
        port = _free_port()
        server_port = port
        if port in (49374, 4096):
            fail("refusing reserved port")
        log = open(root / "server.log", "wb")
        server = subprocess.Popen(
            [str(binary), "serve", "--hostname", "127.0.0.1", "--port", str(port)],
            stdout=log,
            stderr=subprocess.STDOUT,
            env=env,
            cwd=str(project),
            start_new_session=True,
        )
        # The owned process group: the only group the launcher ever signals.
        server_pgid = os.getpgid(server.pid)
        endpoint = ""
        info: dict = {}
        for _ in range(60):
            time.sleep(0.5)
            if server.poll() is not None:
                fail("owned server exited during boot; see server.log")
            line = (root / "server.log").read_bytes().decode("utf-8", "replace")
            m = re.search(r"server listening on (http://127\.0\.0\.1:\d+)", line)
            if m:
                endpoint = m.group(1)
                break
        if not endpoint:
            fail("owned server never printed a loopback listening URL")
        for _ in range(60):
            status, body = _api(endpoint, password, "GET", "/api/info")
            if status == 200:
                info = json.loads(body.decode())
                break
            time.sleep(0.5)
        if info.get("version") != EXPECTED_VERSION:
            fail(f"disposable /api/info is not 2.0.22: {str(info)[:200]}")
        evidence["endpoint_loopback"] = True
        evidence["server_pid"] = server.pid
        # S0 probe: session + native permission evaluates to ask, then settle.
        status, body = _api(
            endpoint, password, "POST", "/api/session",
            {"title": "cw060b-probe", "location": {"directory": str(project)},
             # Without an explicit ask rule the native create evaluates to
             # deny; verified live (Tier B probe): the rule below yields ask.
             "permissions": [{"action": "cw060b_smoke", "resource": "*",
                              "effect": "ask"}]},
        )
        if status != 200:
            fail(f"S0 session create rejected: HTTP {status}")
        s0 = json.loads(body.decode())["data"]["id"]
        status, body = _api(
            endpoint, password, "POST", f"/api/session/{s0}/permission",
            {"action": "cw060b_smoke", "resources": ["s0-marker"], "save": ["s0-marker"]},
        )
        if status != 200:
            fail(f"S0 native permission create rejected: HTTP {status}")
        per0 = json.loads(body.decode())["data"]["id"]
        status, _ = _api(
            endpoint, password, "POST",
            f"/api/session/{s0}/permission/{per0}/reply", {"decision": "once"},
        )
        if status != 204:
            fail(f"S0 permission reply did not settle: HTTP {status}")
        _api(endpoint, password, "DELETE", f"/api/session/{s0}")
        evidence["s0_probe"] = "passed"
        # The egress audit samples the owned server's sockets while the live
        # suite runs: one sample at the end cannot support a "never observed"
        # claim.
        auditor = EgressAuditor(server.pid)
        auditor.start()
        # Hand the live server to the flutter test.
        test_env = _child_env(os.environ)
        test_env.update(
            {
                "CODEWALK_LIVE_SMOKE_UPSTREAM": endpoint,
                "CODEWALK_LIVE_SMOKE_PASSWORD": password,
                "CODEWALK_LIVE_SMOKE_PROJECT_DIR": str(project),
            }
        )
        cmd_flutter = shutil.which("flutter") or os.path.expanduser(
            "~/flutter/bin/flutter"
        )
        proc = subprocess.run(
            [cmd_flutter, "test", "--no-pub", flutter_test, "--timeout=600s"],
            cwd=str(REPO_ROOT),
            env=test_env,
            capture_output=True,
            text=True,
            timeout=900,
        )
        for line in (proc.stdout + proc.stderr).splitlines():
            if "CODEWALK_LIVE_QA " in line:
                events.append(line[line.index("CODEWALK_LIVE_QA "):])
        evidence["flutter_exit"] = proc.returncode
        (root / "flutter-stdout.log").write_text(proc.stdout[-65536:])
        (root / "flutter-stderr.log").write_text(proc.stderr[-65536:])
        violation, samples = auditor.stop()
        evidence["egress"] = {
            "violation": violation,
            "nonLoopbackPeers": 0 if violation is None else 1,
            "samples": samples,
            "auditedAt": datetime.now(timezone.utc).isoformat(),
        }
        evidence["stub_requests"] = len(stub.ledger)
        evidence["stub_hold_aborted"] = stub.hold_aborted
        if violation:
            fail(f"zero-spend violated: {violation}")
        if proc.returncode != 0:
            evidence["status"] = "failed"
        else:
            evidence["status"] = "delivered-awaiting-acceptance"
    except Fatal as e:
        evidence["status"] = _failure_status(e)
        evidence["fatal"] = e.message
        raise
    finally:
        # Cleanup: settle nothing, delete nothing user-owned; kill owned only.
        cleanup: dict = {
            "server_exited": True,
            "temp_root_removed": False,
            "user_opencode_processes_unchanged": False,
        }
        try:
            if server is not None and server.poll() is None:
                os.killpg(os.getpgid(server.pid), signal.SIGINT)
                try:
                    server.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    os.killpg(os.getpgid(server.pid), signal.SIGKILL)
                    server.wait(timeout=10)
        except (ProcessLookupError, PermissionError, OSError):
            pass
        if server is not None:
            cleanup["server_exited"] = server.poll() is not None
            cleanup["server_pid"] = server.pid
        try:
            if stub is not None:
                stub.stop()
        except OSError:
            pass
        if auditor is not None and "egress" not in evidence:
            # The run stopped before the audit could be closed: close it here
            # so the evidence still carries the audit result.
            violation, samples = auditor.stop()
            evidence["egress"] = {
                "violation": violation,
                "nonLoopbackPeers": 0 if violation is None else 1,
                "samples": samples,
                "auditedAt": datetime.now(timezone.utc).isoformat(),
            }
        evidence["wall_seconds"] = round(time.time() - t0, 1)
        evidence["stub_ledger"] = stub.ledger if stub else []
        evidence["events"] = events
        # Zero spend is derived, never asserted: the egress audit found no
        # violation and the live suite observed a native cost of zero.
        native_cost = None
        for record in _parse_markers(events)[0]:
            if record.get("phase") == "native-cost":
                native_cost = record.get("cost")
        evidence["native_cost_usd"] = native_cost
        evidence["zero_spend"] = (
            evidence.get("egress", {}).get("violation") is None and native_cost == 0
        )
        # The user's own listeners and OpenCode servers must be untouched.
        # The owned server is excluded by pid: the root directory is chosen
        # by the caller and cannot be recognised by path.
        owned_pid = {server.pid} if server is not None else set()
        after = {
            "listening_ports": _listening_ports(),
            "user_opencode_pids": _user_opencode_pids(owned_pid),
        }
        before = evidence.get("isolation_before", {})
        before_servers = set(before.get("user_opencode_pids", []))
        after_servers = set(after["user_opencode_pids"])
        cleanup["user_opencode_processes_before"] = sorted(before_servers)
        cleanup["user_opencode_processes_after"] = sorted(after_servers)
        # The launcher only ever signals its own process group, so the proof
        # it can offer is that the user's own service is still running: the
        # user may restart it during the run, and a restart is not a leak.
        cleanup["user_opencode_service_alive"] = (
            not before_servers or bool(after_servers)
        )
        cleanup["listening_ports_before"] = before.get("listening_ports", [])
        cleanup["listening_ports_after"] = after["listening_ports"]
        # The run never took a listener away from the host.
        cleanup["user_listening_ports_preserved"] = set(
            before.get("listening_ports", [])
        ) <= set(after["listening_ports"])
        # The launcher's own loopback stub and the disposable server are its
        # sockets; only a foreign leftover would be a leak.
        owned = {stub.port} if stub is not None else set()
        if server_port is not None:
            owned.add(server_port)
        cleanup["owned_ports"] = sorted(owned)
        # The owned ports must actually be gone: subtracting them from the
        # delta would hide a surviving owned port.
        still_listening = sorted(set(after["listening_ports"]) & owned)
        cleanup["owned_ports_still_listening"] = still_listening
        cleanup["owned_ports_released"] = not still_listening
        # A new port that is not ours cannot be attributed to the run: the
        # user may open one while it runs. It is recorded, not gated.
        cleanup["foreign_ports_left"] = sorted(
            set(after["listening_ports"])
            - set(before.get("listening_ports", []))
            - owned
        )
        # The owned process group must be empty: a survivor there is the one
        # thing that could still hold an owned socket.
        cleanup["owned_process_group_survivors"] = (
            _processes_in_group(server_pgid) if server_pgid is not None else []
        )
        evidence_out.mkdir(parents=True, exist_ok=True)
        (evidence_out / "markers.txt").write_text("\n".join(events) + "\n")
        # Always preserve the client output tails (sanitized): on failure
        # they are the only diagnosis; on success they are the record.
        for name in ("flutter-stdout.log", "flutter-stderr.log"):
            src = root / name
            if src.exists():
                text = src.read_text(encoding="utf-8", errors="replace")
                if password:
                    text = text.replace(password, "[REDACTED]")
                (evidence_out / name).write_text(text[-65536:])
        # Scrub the temp root (evidence_out lives outside it).
        if root.exists() and password is not None:
            shutil.rmtree(root, ignore_errors=True)
        cleanup["temp_root_removed"] = not root.exists()
        cleanup["ok"] = _cleanup_ok(cleanup)
        evidence["cleanup"] = cleanup
        # A failed cleanup is a failed run: the evidence must never report a
        # success the host state does not support.
        if not cleanup["ok"] and evidence.get("status") == "delivered-awaiting-acceptance":
            evidence["status"] = "failed"
            evidence["cleanup_failure"] = (
                "the cleanup proof failed; the run is not a delivery"
            )
        # An egress violation seen while the run was closing is a violation.
        if (
            evidence.get("egress", {}).get("violation")
            and evidence.get("status") == "delivered-awaiting-acceptance"
        ):
            evidence["status"] = "failed"
            evidence["egress_violation"] = evidence["egress"]["violation"]
        # The emitted bundle is sanitized as a whole, once.
        final = _sanitize(evidence, password)
        (evidence_out / "evidence.json").write_text(
            json.dumps(final, indent=2) + "\n"
        )
        for name in (
            "evidence.json",
            "markers.txt",
            "flutter-stdout.log",
            "flutter-stderr.log",
        ):
            path = evidence_out / name
            if path.exists():
                _assert_no_secret(
                    path.read_text(encoding="utf-8", errors="replace"),
                    password,
                    name,
                )
        if fixture_out is not None and evidence.get("status") == "delivered-awaiting-acceptance":
            _write_fixture(final, fixture_out)
            for path in sorted(fixture_out.glob("*")):
                if path.is_file():
                    _assert_no_secret(
                        path.read_text(encoding="utf-8", errors="replace"),
                        password,
                        str(path),
                    )
            print(f"live-smoke: fixture written to {fixture_out}")
    print(json.dumps({"status": evidence.get("status")}))
    return 0 if evidence.get("status") == "delivered-awaiting-acceptance" else 1


def _sanitize(obj: object, password: str | None) -> object:
    """Redact the disposable secret; field names may mention tokens, values may not."""

    def scrub(o: object) -> object:
        if isinstance(o, dict):
            return {
                k: (
                    "[REDACTED]"
                    if k.lower() in ("password", "secret", "authorization", "token")
                    and k.lower() != "status"
                    else scrub(v)
                )
                for k, v in o.items()
            }
        if isinstance(o, list):
            return [scrub(v) for v in o]
        if isinstance(o, str) and password and password in o:
            return o.replace(password, "[REDACTED]")
        return o

    return scrub(obj)


def _assert_no_secret(text: str, password: str | None, where: str) -> None:
    """The disposable password must not reach any emitted file."""
    if password and password in text:
        fail(f"the disposable password leaked into {where}")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    p_acq = sub.add_parser("acquire")
    p_acq.add_argument("--root", required=True)
    p_run = sub.add_parser("run")
    p_run.add_argument("--root", required=True)
    p_run.add_argument("--evidence-out", required=True)
    p_run.add_argument("--flutter-test", required=True)
    p_run.add_argument(
        "--fixture-out",
        default=None,
        help="write the committed evidence fixture from this run (successful runs only)",
    )
    args = parser.parse_args(argv)
    root = Path(args.root)
    if args.command == "acquire":
        acquire(root)
        return 0
    return run(
        root,
        Path(args.evidence_out),
        args.flutter_test,
        Path(args.fixture_out) if args.fixture_out else None,
    )


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
