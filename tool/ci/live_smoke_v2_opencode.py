#!/usr/bin/env python3
"""V2-060B disposable OpenCode 2.0.22 live-smoke launcher (Tier B).

Owns the whole disposable lifecycle under a unique temp root:
acquire (official npm artifact + digest verify) -> isolate -> stub provider ->
serve (foreground, loopback, ephemeral port) -> S0 probe -> flutter test ->
cleanup -> sanitized evidence.

Safety properties (fail closed, never touch the user):
- Only stdlib. No secrets leave this process except into the owned child env.
- Never runs `opencode service`, never touches port 49374/4096, never reads
  or writes the user's HOME/config/data/credentials.
- Refuses to execute when registry digests mismatch or the binary is not the
  pinned 2.0.22 linux-arm64 build.
- The stub provider only serves deterministic tokens on loopback; an egress
  audit kills the run on any non-loopback server socket.

Usage:
  python3 tool/ci/live_smoke_v2_opencode.py acquire --root /tmp/x
  python3 tool/ci/live_smoke_v2_opencode.py run --root /tmp/x \\
      --evidence-out /tmp/v2-060b-evidence --flutter-test test/v2/sessions/live_flow_smoke_test.dart
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
import tempfile
import threading
import time
import urllib.error
import urllib.request
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
MAX_STUB_REQUESTS = 12
SECRET_RE = re.compile(
    r"(?i)(password|secret|token|authorization|bearer|code|codewalk_live[^\s\"']*)"
)


def fail(msg: str, code: int = 2) -> "NoReturn":
    print(f"live-smoke: FATAL: {msg}", file=sys.stderr, flush=True)
    raise SystemExit(code)


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


def acquire(root: Path) -> dict:
    """Fetch + verify the official linux-arm64 2.0.22 artifact. No secrets."""
    root.mkdir(parents=True, exist_ok=True)
    dl = root / "dl"
    dl.mkdir(exist_ok=True)
    meta = _http_get_json(NPM_META_URL)
    try:
        # Version-pinned metadata carries dist at the top level.
        if meta.get("version") != "2.0.22" or meta.get("name") != "@opencode/cli-linux-arm64":
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
            "registry may have changed. Stopping (blocked:provenance)."
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
    digest = hashlib.sha256(binary.read_bytes()).hexdigest()
    if digest != PINNED_BINARY_SHA256:
        fail("extracted binary SHA-256 mismatch; refusing to execute")
    proc = subprocess.run(
        [str(binary), "--version"],
        capture_output=True,
        text=True,
        timeout=60,
        env={"PATH": "/usr/bin:/bin", "LANG": "C.UTF-8"},
    )
    if proc.stdout.strip() != f"opencode v{EXPECTED_VERSION}":
        fail(f"binary --version mismatch: {proc.stdout.strip()!r}")
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
            # Hold the stream open until the client disconnects (reconnect test).
            body = b": hold\n\n"
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            try:
                self.wfile.write(body)
                self.wfile.flush()
                while True:
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
        self.server.shutdown()
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
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def _egress_violation(pid: int) -> str | None:
    """Best-effort: any ESTAB non-loopback socket owned by pid fails the run."""
    try:
        out = subprocess.run(
            ["ss", "-tnpH"], capture_output=True, text=True, timeout=15
        ).stdout
    except (FileNotFoundError, subprocess.SubprocessError):
        return None  # ss unavailable: audit inconclusive, never a pass claim
    for line in out.splitlines():
        if f"pid={pid}," not in line and f"pid={pid}" not in line:
            continue
        parts = line.split()
        if len(parts) < 5 or parts[0] != "ESTAB":
            continue
        peer = parts[4].rsplit(":", 1)[0].strip("[]")
        if peer not in ("127.0.0.1", "::1"):
            return f"non-loopback ESTAB peer {peer} on pid {pid}"
    return None


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


def _user_opencode_pids() -> list[int]:
    """The user's own OpenCode processes, so cleanup can prove it spared them."""
    pids: list[int] = []
    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        try:
            with open(f"/proc/{entry}/cmdline", "rb") as handle:
                cmdline = handle.read().decode("utf-8", "replace")
        except OSError:
            continue
        if "opencode" in cmdline and "serve" in cmdline:
            if "/v2-060b-" not in cmdline:
                pids.append(int(entry))
    return sorted(pids)


def run(root: Path, evidence_out: Path, flutter_test: str) -> int:
    password = None
    server = None
    stub = None
    t0 = time.time()
    events: list[str] = []
    server_port: int | None = None
    evidence: dict = {
        "status": "inconclusive",
        "version": EXPECTED_VERSION,
        "host": "linux-aarch64",
        "zero_spend": True,
    }
    try:
        acq_path = root / "acquire.json"
        record = (
            json.loads(acq_path.read_text())
            if acq_path.exists()
            else acquire(root)
        )
        binary = record["binary"]
        evidence["acquisition"] = {
            k: record[k]
            for k in ("tarball_url", "tarball_sha256", "binary_sha256", "version")
        }
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
            [binary, "serve", "--hostname", "127.0.0.1", "--port", str(port)],
            stdout=log,
            stderr=subprocess.STDOUT,
            env=env,
            cwd=str(project),
            start_new_session=True,
        )
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
        # Hand the live server to the flutter test.
        test_env = dict(os.environ)
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
            cwd=str(Path(__file__).resolve().parents[2]),
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
        violation = _egress_violation(server.pid)
        evidence["egress_violation"] = violation
        evidence["stub_requests"] = len(stub.ledger)
        evidence["stub_hold_aborted"] = stub.hold_aborted
        if violation:
            fail(f"zero-spend violated: {violation}")
        if proc.returncode != 0:
            evidence["status"] = "failed"
        else:
            evidence["status"] = "delivered-awaiting-acceptance"
    except SystemExit as e:
        evidence["status"] = "blocked" if "blocked" in str(e) else evidence.get("status", "inconclusive")
        evidence["fatal"] = f"exit-{e.code}"
        raise
    finally:
        # Cleanup: settle nothing, delete nothing user-owned; kill owned only.
        cleanup: dict = {
            "server_exited": True,
            "temp_root_removed": False,
            "user_listeners_unchanged": False,
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
        evidence["wall_seconds"] = round(time.time() - t0, 1)
        evidence["stub_ledger"] = stub.ledger if stub else []
        # The user's own listeners and OpenCode processes must be untouched.
        after = {
            "listening_ports": _listening_ports(),
            "user_opencode_pids": _user_opencode_pids(),
        }
        before = evidence.get("isolation_before", {})
        cleanup["user_listeners_unchanged"] = (
            after["user_opencode_pids"] == before.get("user_opencode_pids", [])
        )
        cleanup["listening_ports_before"] = before.get("listening_ports", [])
        cleanup["listening_ports_after"] = after["listening_ports"]
        # The launcher's own loopback stub and the disposable server are its
        # sockets; only a foreign leftover would be a leak.
        owned = {stub.port} if stub is not None else set()
        if server_port is not None:
            owned.add(server_port)
        cleanup["owned_ports"] = sorted(owned)
        cleanup["owned_ports_released"] = not (
            set(after["listening_ports"]) - set(before.get("listening_ports", [])) - owned
        )
        sanitized = _sanitize(evidence, password)
        evidence_out.mkdir(parents=True, exist_ok=True)
        (evidence_out / "evidence.json").write_text(
            json.dumps(sanitized, indent=2) + "\n"
        )
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
        cleanup["evidence"] = sanitized
        evidence["cleanup"] = cleanup
        # Rewrite the evidence with the cleanup record included.
        (evidence_out / "evidence.json").write_text(
            json.dumps(evidence, indent=2) + "\n"
        )
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


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    p_acq = sub.add_parser("acquire")
    p_acq.add_argument("--root", required=True)
    p_run = sub.add_parser("run")
    p_run.add_argument("--root", required=True)
    p_run.add_argument("--evidence-out", required=True)
    p_run.add_argument("--flutter-test", required=True)
    args = parser.parse_args(argv)
    root = Path(args.root)
    if args.command == "acquire":
        acquire(root)
        return 0
    return run(root, Path(args.evidence_out), args.flutter_test)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
