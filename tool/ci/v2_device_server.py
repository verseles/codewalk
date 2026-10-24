#!/usr/bin/env python3
"""V2-042C disposable OpenCode 2.0.22 server for the device reliability matrix.

One pinned, isolated `opencode serve` on loopback with a zero-spend stub
provider. Devices reach it only through a relay that records request metadata
(time, method, route template, status, stream open and close, a per-run client
alias); bodies, headers, credentials and client addresses are never recorded.

The relay listens on --bind (loopback by default). Listening on a tailnet or
LAN address is an explicit operator choice for a disposable run.

Commands, typed on stdin or POSTed to the loopback --control-port:
  status    the endpoint, the server state and the relay counters
  session   create a session as another client would (TUI-equivalent) and
            send it one marker prompt
  permission
            open a native pending permission request (action read) on
            body.session, or on the session a client prompted last; only
            sessions from `create` ask, any other evaluates to deny
  permissions
            the pending requests of body.session (or that same session), the
            replies a client sent for it and the number of persistent
            approvals the server saved
  restart   stop the server gracefully (SIGTERM) and start it again on the
            same state; the relay endpoint does not change
  tui       the command that attaches the official TUI through the relay
  report    the per-session user prompts (duplicates, active state) and
            the event-stream reconnect gaps per client, as JSON
  quit      stop everything and clean the owned processes
The control port also accepts, with a JSON body:
  create    an empty session, for a client to prompt (also typed on stdin)
  result    one result record, appended to results.jsonl
  host/drop, host/handover, host/background
            emulator controls through adb (only with --adb-serial): airplane
            mode, Wi-Fi off with mobile data on, or Home then relaunch, each
            for body.seconds, with the device's transports captured before
            and after
Prompts containing CW-SLOW make the stub answer for 30 s (CW-SLOW90 for 90 s),
so a scenario can disturb a running turn. CW-RICH answers a fixed Markdown,
code, table, math and Mermaid sample, for comparing how each block renders.
Any other prompt is answered at once.

Usage:
  python3 tool/ci/v2_device_server.py serve --root /tmp/x [--bind ADDR]
      [--port N] [--control-port N]
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import http.client
import io
import json
import os
import platform
import re
import secrets
import signal
import socket
import subprocess
import sys
import tarfile
import threading
import time
import urllib.request
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import live_smoke_v2_opencode as smoke  # noqa: E402

VERSION = smoke.EXPECTED_VERSION
# The arm64 pins are the launcher's accepted acquisition record; the x64 pins
# were taken from the registry with a matching SHA-512 integrity for the CI
# emulator host. A mismatch is a hard failure, never a substitution.
PINS = {
    "aarch64": {
        "package": "@opencode/cli-linux-arm64",
        "integrity": None,
        "tarball_sha256": smoke.PINNED_TARBALL_SHA256,
        "binary_sha256": smoke.PINNED_BINARY_SHA256,
    },
    "x86_64": {
        "package": "@opencode/cli-linux-x64",
        "integrity": (
            "sha512-DlV1qgEDDnVqpTWMPqv7tCHCcXodzZBFaMcxjsiYdY6E5gHH2Q68Jfas"
            "VksyQ1nu6m1887WQKGhOsepE+oKyYw=="
        ),
        "tarball_sha256": (
            "65434cbe256f23df397a4941039e5eee28b1a37c1bad5376a5217f583a353583"
        ),
        "binary_sha256": (
            "32cf5aa0a69a650e36277e3315d189835ddc79fb9aa1d0aef5025be5af5ad122"
        ),
    },
}
RESERVED_PORTS = {49374, 4096}
STUB_REQUEST_CAP = 2000
# "CW-SLOW" answers for 30 s; "CW-SLOW90" for 90 s (at most 120).
SLOW_MARKER = re.compile(r"CW-SLOW(\d+)?")
HOP_HEADERS = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailer",
    "transfer-encoding",
    "upgrade",
    "host",
    "content-length",
}
ID_SEGMENT = re.compile(r"^[a-z]{2,4}_[A-Za-z0-9]+$")
# "CW-RICH" answers this fixed sample, so a person can compare how each
# block renders (V2-071 visual parity); it streams line by line.
RICH_MARKER = "CW-RICH"
RICH_SAMPLE = """# Heading 1
## Heading 2

Plain text with **bold**, *italic*, `inline code`, ~~strike~~, H<sub>2</sub>O, x<sup>2</sup> and a [link](https://example.com).

- First item
- Second item
  - Nested item
1. One
2. Two

- [x] Done task
- [ ] Open task

> A quoted line.

| Name | Value |
|---|---:|
| alpha | 1 |
| beta | 22 |

```dart
void main() {
  final greeting = 'Hello, CodeWalk';
  print(greeting);
}
```

Inline math $e^{i\\pi} + 1 = 0$ and a block:

$$
\\int_0^1 x^2\\,dx = \\frac{1}{3}
$$

```mermaid
graph TD
  A[Prompt] --> B{Model}
  B --> C[Answer]
```

<progress value="40" max="100">40%</progress>

---

Last line.
"""


def now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")


def die(message: str) -> "None":
    print(f"device-server: {message}", file=sys.stderr)
    raise SystemExit(2)


def acquire(root: Path) -> Path:
    """The pinned binary for this host, downloaded and verified once."""
    arch = platform.machine()
    pin = PINS.get(arch)
    if pin is None:
        die(f"no pinned 2.0.22 build for {arch}")
    binary = root / "bin" / "opencode"
    if not binary.is_file():
        name = pin["package"].replace("/", "%2f")
        with urllib.request.urlopen(
            f"https://registry.npmjs.org/{name}/{VERSION}", timeout=60
        ) as resp:
            meta = json.loads(resp.read().decode())
        if meta.get("name") != pin["package"] or meta.get("version") != VERSION:
            die("registry metadata is not the pinned package")
        dist = meta.get("dist") or {}
        integrity = dist.get("integrity", "")
        if pin["integrity"] and integrity != pin["integrity"]:
            die("registry integrity differs from the pin")
        with urllib.request.urlopen(dist["tarball"], timeout=600) as resp:
            data = resp.read()
        sri = "sha512-" + base64.b64encode(hashlib.sha512(data).digest()).decode()
        if sri != integrity:
            die("tarball SHA-512 integrity mismatch; refusing to execute")
        if hashlib.sha256(data).hexdigest() != pin["tarball_sha256"]:
            die("tarball SHA-256 differs from the pin; refusing to execute")
        with tarfile.open(fileobj=io.BytesIO(data)) as archive:
            member = archive.getmember("package/bin/opencode")
            if not member.isfile():
                die("unexpected binary member")
            content = archive.extractfile(member).read()
        binary.parent.mkdir(parents=True, exist_ok=True)
        binary.write_bytes(content)
        binary.chmod(0o755)
    if hashlib.sha256(binary.read_bytes()).hexdigest() != pin["binary_sha256"]:
        die("binary SHA-256 differs from the pin; refusing to execute")
    out = subprocess.run(
        [str(binary), "--version"],
        capture_output=True,
        text=True,
        timeout=60,
        env={"PATH": "/usr/bin:/bin", "LANG": "C.UTF-8"},
    ).stdout.strip()
    if out != f"opencode v{VERSION}":
        die(f"binary --version is {out!r}")
    return binary


class StubHandler(BaseHTTPRequestHandler):
    """Deterministic, zero-cost chat completions on loopback."""

    protocol_version = "HTTP/1.1"

    def log_message(self, *args) -> None:
        return

    def do_POST(self) -> None:  # noqa: N802
        stub = self.server.stub  # type: ignore[attr-defined]
        length = int(self.headers.get("Content-Length", "0") or 0)
        try:
            payload = json.loads(self.rfile.read(length).decode() or "{}")
        except (ValueError, UnicodeDecodeError):
            payload = {}
        if self.path != "/v1/chat/completions" or stub.count() > STUB_REQUEST_CAP:
            body = b'{"error":"refused"}'
            self.send_response(429 if self.path.startswith("/v1/") else 404)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        prompt = ""
        for message in reversed(payload.get("messages") or []):
            if isinstance(message, dict) and message.get("role") == "user":
                content = message.get("content")
                if isinstance(content, list):
                    content = " ".join(
                        p.get("text", "") for p in content if isinstance(p, dict)
                    )
                prompt = content if isinstance(content, str) else ""
                break
        match = SLOW_MARKER.search(prompt)
        slow = match is not None
        seconds = min(int(match.group(1) or 30), 120) if match else 0
        if slow:
            parts = [f"tick {i} " for i in range(1, seconds + 1)]
        elif RICH_MARKER in prompt:
            parts = RICH_SAMPLE.splitlines(keepends=True)
        else:
            parts = ["CW-OK"]
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.close_connection = True
        model = payload.get("model", "cw042c/stub")
        try:
            for index, text in enumerate(parts):
                last = index == len(parts) - 1
                chunk = {
                    "id": "chatcmpl-cw042c",
                    "object": "chat.completion.chunk",
                    "created": int(time.time()),
                    "model": model,
                    "choices": [
                        {
                            "index": 0,
                            "delta": {"content": text},
                            "finish_reason": "stop" if last else None,
                        }
                    ],
                }
                if last:
                    chunk["usage"] = {
                        "prompt_tokens": 0,
                        "completion_tokens": 0,
                        "cost": 0,
                    }
                self.wfile.write(f"data: {json.dumps(chunk)}\n\n".encode())
                self.wfile.flush()
                if slow and not last:
                    time.sleep(1)
            self.wfile.write(b"data: [DONE]\n\n")
            self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            return


class Stub:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._requests = 0
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), StubHandler)
        self.server.stub = self  # type: ignore[attr-defined]
        self.server.daemon_threads = True
        threading.Thread(target=self.server.serve_forever, daemon=True).start()

    @property
    def port(self) -> int:
        return int(self.server.server_address[1])

    def count(self) -> int:
        with self._lock:
            self._requests += 1
            return self._requests

    def stop(self) -> None:
        self.server.shutdown()
        self.server.server_close()


def server_config(stub_port: int) -> dict:
    return {
        "update": "disable",
        "share": "disabled",
        "snapshots": False,
        "warming": False,
        "model": "cw042c/stub",
        "providers": {
            "cw042c": {
                "package": "@opencode/ai/providers/openai-compatible",
                "settings": {
                    "baseURL": f"http://127.0.0.1:{stub_port}/v1",
                    "headerTimeout": False,
                    "chunkTimeout": False,
                },
                "models": {
                    "stub": {
                        "name": "cw042c stub",
                        "cost": {"input": 0, "output": 0},
                        "capabilities": {"tools": True},
                    }
                },
            }
        },
        "experimental": {
            "policies": [
                {"action": "provider.use", "resource": "*", "effect": "deny"},
                {"action": "provider.use", "resource": "cw042c", "effect": "allow"},
            ]
        },
        "permissions": [{"action": "*", "resource": "*", "effect": "deny"}],
    }


def free_port() -> int:
    while True:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.bind(("127.0.0.1", 0))
            port = int(s.getsockname()[1])
        if port not in RESERVED_PORTS:
            return port


def read_body(handler: BaseHTTPRequestHandler) -> bytes | None:
    """The request body, framed by Content-Length or chunked; never dropped."""
    if "chunked" in (handler.headers.get("Transfer-Encoding") or "").lower():
        data = b""
        while True:
            size = int(handler.rfile.readline().split(b";", 1)[0].strip() or b"0", 16)
            if size == 0:
                while handler.rfile.readline() not in (b"\r\n", b"\n", b""):
                    pass
                return data
            data += handler.rfile.read(size)
            handler.rfile.readline()
    length = int(handler.headers.get("Content-Length", "0") or 0)
    return handler.rfile.read(length) if length > 0 else None


def route(path: str) -> str:
    """The path with native ids templated and the query dropped."""
    segments = path.split("?", 1)[0].split("/")
    return "/".join("{id}" if ID_SEGMENT.match(s) else s for s in segments)


def session_of(path: str) -> str | None:
    segments = path.split("?", 1)[0].split("/")
    if len(segments) > 3 and segments[1:3] == ["api", "session"]:
        if ID_SEGMENT.match(segments[3]):
            return segments[3]
    return None


class Log:
    """Append-only request metadata; never bodies, headers or addresses."""

    def __init__(self, path: Path) -> None:
        self.path = path
        self._lock = threading.Lock()
        self._aliases: dict[str, str] = {}
        self.records: list[dict] = []

    def alias(self, address: str) -> str:
        with self._lock:
            return self._aliases.setdefault(
                address, f"client-{len(self._aliases) + 1}"
            )

    def write(self, **record) -> None:
        record = {"t": now(), **record}
        with self._lock:
            self.records.append(record)
            with self.path.open("a") as f:
                f.write(json.dumps(record) + "\n")


class RelayHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args) -> None:
        return

    def _relay(self) -> None:
        device = self.server.device  # type: ignore[attr-defined]
        log: Log = device.log
        client = log.alias(self.client_address[0])
        body = read_body(self)
        headers = {k: v for k, v in self.headers.items() if k.lower() not in HOP_HEADERS}
        if getattr(device, "open_relay", False):
            # Any password a device sends is replaced by the real one.
            headers = {k: v for k, v in headers.items() if k.lower() != "authorization"}
            token = base64.b64encode(f"opencode:{device.password}".encode()).decode()
            headers["Authorization"] = f"Basic {token}"
        templated = route(self.path)
        meta = {
            "client": client,
            "method": self.command,
            "route": templated,
            "session": session_of(self.path),
        }
        upstream = http.client.HTTPConnection("127.0.0.1", device.upstream_port, timeout=None)
        try:
            upstream.request(self.command, self.path, body=body, headers=headers)
            response = upstream.getresponse()
        except OSError:
            upstream.close()
            log.write(kind="request", status=502, **meta)
            self.send_response(502)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        # A bodiless status is never framed as a stream.
        bodiless = response.status in (204, 304) or response.status < 200
        streaming = response.getheader("Content-Length") is None and not bodiless
        events = "text/event-stream" in (response.getheader("Content-Type") or "")
        self.send_response(response.status)
        for key, value in response.getheaders():
            if key.lower() not in HOP_HEADERS:
                self.send_header(key, value)
        if bodiless:
            response.read()
            upstream.close()
            self.end_headers()
            log.write(kind="request", status=response.status, **meta)
            return
        if not streaming:
            data = response.read()
            upstream.close()
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            log.write(kind="request", status=response.status, **meta)
            return
        self.send_header("Transfer-Encoding", "chunked")
        self.end_headers()
        if events:
            log.write(kind="stream-open", status=response.status, **meta)
        reason = "upstream-end"
        try:
            while True:
                try:
                    chunk = response.read1(65536)
                except (http.client.HTTPException, OSError):
                    # The server died mid-stream (a restart): the client sees
                    # the stream cut, as it would from the server itself.
                    reason = "upstream-broken"
                    break
                if not chunk:
                    break
                self.wfile.write(f"{len(chunk):x}\r\n".encode() + chunk + b"\r\n")
                self.wfile.flush()
            if reason == "upstream-end":
                self.wfile.write(b"0\r\n\r\n")
                self.wfile.flush()
            else:
                self.close_connection = True
        except (BrokenPipeError, ConnectionResetError, TimeoutError, OSError):
            reason = "client-gone"
            self.close_connection = True
        finally:
            upstream.close()
            if events:
                log.write(kind="stream-close", reason=reason, **meta)
            else:
                log.write(kind="request", status=response.status, **meta)

    do_GET = do_POST = do_PATCH = do_PUT = do_DELETE = _relay  # noqa: N815


class DeviceServer:
    def __init__(self, root: Path, bind: str, port: int) -> None:
        self.root = root
        self.bind = bind
        self.port = port
        self.password = secrets.token_urlsafe(24)
        self.open_relay = False
        self.log = Log(root / "requests.jsonl")
        self.process: subprocess.Popen | None = None
        self.upstream_port = 0
        # Restart, stop and close take the same lock, so a restart racing
        # quit cannot start a server after close returned.
        self.lock = threading.RLock()
        self.closed = False
        self.restarts: list[dict] = []

    # The isolated tree survives restarts: the restarted server recovers the
    # same sessions.
    def prepare(self) -> None:
        self.binary = acquire(self.root)
        for name in ("home", "xdg-config", "xdg-data", "xdg-state", "xdg-cache", "tmp", "project"):
            (self.root / name).mkdir(parents=True, exist_ok=True)
        self.project = self.root / "project"
        git = {"PATH": "/usr/bin:/bin", "HOME": str(self.root / "home")}
        if not (self.project / ".git").exists():
            subprocess.run(["git", "init", "-q", str(self.project)], check=True, env=git)
            (self.project / "README.md").write_text("CodeWalk V2-042C disposable project\n")
            for args in (["add", "-A"], ["commit", "-qm", "disposable"]):
                subprocess.run(
                    ["git", "-C", str(self.project), "-c", "user.email=cw042c@invalid",
                     "-c", "user.name=cw042c", *args],
                    check=True,
                    env=git,
                )
        self.stub = Stub()
        (self.root / "config.json").write_text(
            json.dumps(server_config(self.stub.port), indent=2) + "\n"
        )

    def env(self) -> dict:
        r = self.root
        return {
            "PATH": "/usr/bin:/bin",
            "LANG": "C.UTF-8",
            "HOME": str(r / "home"),
            "TMPDIR": str(r / "tmp"),
            "XDG_CONFIG_HOME": str(r / "xdg-config"),
            "XDG_DATA_HOME": str(r / "xdg-data"),
            "XDG_CACHE_HOME": str(r / "xdg-cache"),
            "XDG_STATE_HOME": str(r / "xdg-state"),
            "OPENCODE_SERVER_PASSWORD": self.password,
            "OPENCODE_CONFIG": str(r / "config.json"),
            "OPENCODE_DISABLE_MODELS_FETCH": "1",
            "OPENCODE_DISABLE_AUTOUPDATE": "1",
            "OPENCODE_DISABLE_PROJECT_CONFIG": "1",
            "HTTP_PROXY": "http://127.0.0.1:9",
            "HTTPS_PROXY": "http://127.0.0.1:9",
            "ALL_PROXY": "http://127.0.0.1:9",
            "NO_PROXY": "127.0.0.1,localhost",
        }

    def api(self, method: str, path: str, body=None) -> tuple[int, bytes]:
        return smoke._api(
            f"http://127.0.0.1:{self.upstream_port}", self.password, method, path, body
        )

    def start(self) -> None:
        with self.lock:
            if self.closed:
                die("the server is closed")
            self._start()

    def _start(self) -> None:
        self.upstream_port = free_port()
        log = (self.root / "server.log").open("ab")
        self.process = subprocess.Popen(
            [str(self.binary), "serve", "--hostname", "127.0.0.1", "--port", str(self.upstream_port)],
            stdout=log,
            stderr=subprocess.STDOUT,
            env=self.env(),
            cwd=str(self.project),
            start_new_session=True,
        )
        deadline = time.time() + 60
        while time.time() < deadline:
            if self.process.poll() is not None:
                self.stop()
                die("the server exited during boot; see server.log")
            try:
                status, body = self.api("GET", "/api/info")
                if status == 200 and json.loads(body).get("version") == VERSION:
                    return
            except OSError:
                pass
            time.sleep(0.5)
        self.stop()
        die("the server never answered /api/info")

    def stop(self) -> float:
        """Graceful SIGTERM; the owned group is killed only after 30 s."""
        with self.lock:
            return self._stop()

    def _stop(self) -> float:
        process = self.process
        if process is None or process.poll() is not None:
            return 0.0
        started = time.time()
        process.send_signal(signal.SIGTERM)
        try:
            process.wait(timeout=30)
        except subprocess.TimeoutExpired:
            os.killpg(os.getpgid(process.pid), signal.SIGKILL)
            process.wait(timeout=10)
        return time.time() - started

    def restart(self) -> dict:
        with self.lock:
            if self.closed:
                return {"error": "the server is closed"}
            record = {"requested": now()}
            record["stop_seconds"] = round(self._stop(), 3)
            record["stopped"] = now()
            self._start()
            record["ready"] = now()
            self.restarts.append(record)
            self.log.write(kind="restart", **record)
            return record

    def create(self) -> dict:
        status, body = self.api(
            "POST",
            "/api/session",
            {
                "title": "CW device cell",
                "location": {"directory": str(self.project)},
                # A native request evaluates to deny without a session rule
                # (verified live); this one lets `permission` open a real ask.
                # The stub never calls a tool, so nothing else asks.
                "permissions": [{"action": "read", "resource": "*", "effect": "ask"}],
            },
        )
        if status != 200:
            return {"error": f"create HTTP {status}"}
        session = json.loads(body)["data"]["id"]
        self.log.write(kind="created-session", session=session)
        return {"session": session, "directory": str(self.project)}

    def session(self, title: str = "CW TUI-equivalent", text: str | None = None) -> dict:
        marker = text or f"CW-TUI {secrets.token_hex(3)}"
        status, body = self.api(
            "POST",
            "/api/session",
            {"title": title, "location": {"directory": str(self.project)}},
        )
        if status != 200:
            return {"error": f"create HTTP {status}"}
        session = json.loads(body)["data"]["id"]
        status, _ = self.api("POST", f"/api/session/{session}/prompt", {"text": marker})
        record = {"session": session, "prompt": marker, "prompt_status": status}
        self.log.write(kind="external-session", **record)
        return record

    def _target(self, body: dict | None) -> str | None:
        if "session" in (body or {}):
            # An explicit session is that session or nothing, never another.
            session = body["session"]
            return session if isinstance(session, str) and ID_SEGMENT.match(session) else None
        prompted = [
            r["session"]
            for r in self.log.records
            if r.get("session") and r.get("method") == "POST"
            and r.get("route", "").endswith("/prompt")
        ]
        return prompted[-1] if prompted else None

    def permission(self, body: dict | None = None) -> dict:
        session = self._target(body)
        if session is None:
            return {"error": "no session: pass body.session or prompt one first"}
        # A real native action, so the client sees the shape a tool call makes.
        resource = f"cw-device-{secrets.token_hex(3)}"
        status, raw = self.api(
            "POST",
            f"/api/session/{session}/permission",
            {"action": "read", "resources": [resource], "save": [resource]},
        )
        try:
            data = json.loads(raw)["data"] if status == 200 else None
            record = {"session": session, "permission": data["id"], "effect": data["effect"]}
        except (ValueError, KeyError, TypeError):
            return {"error": f"permission HTTP {status}"}
        self.log.write(kind="permission-created", **record)
        return record

    def permissions(self, body: dict | None = None) -> dict:
        session = self._target(body)
        if session is None:
            return {"error": "no session: pass body.session or prompt one first"}
        try:
            status, raw = self.api("GET", f"/api/session/{session}/permission")
            pending = [p["id"] for p in json.loads(raw)["data"]] if status == 200 else None
            status, raw = self.api("GET", "/api/permission/saved")
            saved = json.loads(raw).get("data") if status == 200 else None
        except (ValueError, KeyError, TypeError, AttributeError):
            pending = saved = None
        if pending is None or not isinstance(saved, list):
            return {"error": f"permission list HTTP {status}"}
        # A reply the client sent through the relay; an empty pending list
        # alone could also be the server rejecting the request by itself.
        replies = sum(
            1
            for r in list(self.log.records)
            if r.get("session") == session and r.get("method") == "POST"
            and r.get("route", "").endswith("/reply") and 200 <= r.get("status", 0) < 300
        )
        return {"session": session, "pending": pending, "saved": len(saved), "client_replies": replies}

    def report(self) -> dict:
        records = list(self.log.records)
        status, body = self.api("GET", "/api/session/active")
        try:
            active = json.loads(body).get("data") if status == 200 else None
        except (ValueError, AttributeError):
            active = None
        # 2.0.22 answers a map keyed by the running session ids. An
        # unreadable answer is unknown (None), never "nothing is running".
        active_ids = sorted(active) if isinstance(active, dict) else None
        sessions = {}
        ids = {r["session"] for r in records if r.get("session")}
        for session in sorted(ids):
            status, body = self.api(
                "GET", f"/api/session/{session}/message?order=asc&limit=200"
            )
            if status != 200:
                sessions[session] = {"error": f"history HTTP {status}"}
                continue
            texts = [
                m.get("text")
                for m in json.loads(body).get("data", [])
                if isinstance(m, dict) and m.get("type", "user") == "user" and m.get("text")
            ]
            counts: dict[str, int] = {}
            for text in texts:
                counts[text] = counts.get(text, 0) + 1
            sessions[session] = {
                "user_prompts": len(texts),
                # Extra copies only: the prompt text never leaves memory.
                "duplicates": sum(n - 1 for n in counts.values()),
                "prompt_posts": sum(
                    1
                    for r in records
                    if r.get("session") == session
                    and r.get("method") == "POST"
                    and r.get("route", "").endswith("/prompt")
                ),
                "active": None if active_ids is None else session in active_ids,
            }
        streams: dict[str, list[dict]] = {}
        for r in records:
            if r.get("route") == "/api/event" and r.get("kind") in ("stream-open", "stream-close"):
                streams.setdefault(r["client"], []).append(
                    {"t": r["t"], "kind": r["kind"], "reason": r.get("reason")}
                )
        return {
            "version": VERSION,
            "restarts": self.restarts,
            "active_sessions": active_ids,
            "sessions": sessions,
            "event_streams": streams,
        }

    def tui(self) -> str:
        """The official TUI attached through the relay, in its own isolated
        home so it never reads or writes the user's OpenCode state."""
        r = self.root
        homes = " ".join(
            f"{name}={r / 'tui' / folder}"
            for name, folder in (
                ("HOME", "home"),
                ("XDG_CONFIG_HOME", "config"),
                ("XDG_DATA_HOME", "data"),
                ("XDG_STATE_HOME", "state"),
                ("XDG_CACHE_HOME", "cache"),
            )
        )
        for folder in ("home", "config", "data", "state", "cache"):
            (r / "tui" / folder).mkdir(parents=True, exist_ok=True)
        return (
            f'env {homes} OPENCODE_SERVER_PASSWORD="$(cat {r / "password"})" '
            f"{self.binary} --server http://{self.bind}:{self.port} {self.project}"
        )

    def status(self) -> dict:
        return {
            "endpoint": f"http://{self.bind}:{self.port}/",
            "server_running": self.process is not None and self.process.poll() is None,
            "requests": len(self.log.records),
            "restarts": len(self.restarts),
        }

    def command(self, name: str, body: dict | None = None) -> dict:
        if name == "create":
            return self.create()
        if name == "result":
            record = {"t": now(), **(body or {})}
            with (self.root / "results.jsonl").open("a") as f:
                f.write(json.dumps(record) + "\n")
            return {"recorded": True}
        if name == "status":
            return self.status()
        if name == "session":
            return self.session()
        if name == "permission":
            return self.permission(body)
        if name == "permissions":
            return self.permissions(body)
        if name == "restart":
            return self.restart()
        if name == "report":
            return self.report()
        if name == "tui":
            return {"command": self.tui()}
        return {"error": f"unknown command {name!r}"}

    def close(self) -> None:
        with self.lock:
            self.closed = True
            self._stop()
        stub = getattr(self, "stub", None)
        if stub is not None:
            stub.stop()


class HostActions:
    """Emulator controls for the CI cells; each runs after the reply is sent,
    so a request made just before the network drops still gets its answer."""

    def __init__(self, serial: str, package: str, log: Log) -> None:
        self.serial = serial
        self.package = package
        self.log = log

    def adb(self, *args: str) -> str:
        return self.shell(*args)[1]

    def shell(self, *args: str) -> tuple[bool, str]:
        """Runs one adb shell command; ok is False on a non-zero exit or adb
        itself failing. A warning on stderr alone is not a failure."""
        try:
            done = subprocess.run(
                ["adb", "-s", self.serial, "shell", *args],
                capture_output=True,
                text=True,
                timeout=120,
            )
        except (OSError, subprocess.TimeoutExpired):
            return False, ""
        return done.returncode == 0, done.stdout

    def transports(self) -> str:
        """The default network's transports, as Android reports them."""
        text = self.adb("dumpsys", "connectivity")
        match = re.search(r"Active default network: (\d+)", text)
        if not match:
            return "none"
        for line in text.splitlines():
            if f"network{{{match.group(1)}}}" in line:
                found = re.search(r"Transports: ([A-Z|]+)", line)
                if found:
                    return found.group(1)
        return f"network {match.group(1)}: transports not reported"

    @staticmethod
    def parsed(transport: str) -> bool:
        """A default network whose transports were read."""
        return transport != "none" and not transport.startswith("network ")

    @classmethod
    def changed(cls, before: str, during: str) -> bool:
        """Whether one read transport became another; an unparsed value
        never counts as a change."""
        return cls.parsed(before) and cls.parsed(during) and during != before

    def run(self, name: str, body: dict) -> dict:
        try:
            seconds = int(body.get("seconds", 10))
        except (TypeError, ValueError):
            seconds = 0
        if not 1 <= seconds <= 300:
            return {"error": "seconds must be 1..300"}
        action = {
            "drop": self._drop,
            "handover": self._handover,
            "background": self._background,
        }.get(name)
        if action is None:
            return {"error": f"unknown host action {name!r}"}
        threading.Thread(target=action, args=(seconds,), daemon=True).start()
        return {"scheduled": name, "seconds": seconds}

    # Each record says whether every command applied and whether the default
    # transport actually changed; a cell without both is not a disturbance.
    def _drop(self, seconds: int) -> None:
        time.sleep(1)
        before = self.transports()
        off_ok, _ = self.shell("cmd", "connectivity", "airplane-mode", "enable")
        off = now()
        time.sleep(3)
        during = self.transports()
        time.sleep(max(seconds - 3, 1))
        on_ok, _ = self.shell("cmd", "connectivity", "airplane-mode", "disable")
        restored = now()
        time.sleep(5)
        self.log.write(kind="host-action", action="drop", off=off, restored=restored,
                       applied=off_ok and on_ok, before=before, during=during,
                       after=self.transports(),
                       changed=self.parsed(before) and during == "none")

    def _handover(self, seconds: int) -> None:
        time.sleep(1)
        # The baseline is Wi-Fi's, taken before mobile data is switched on.
        before = self.transports()
        data_ok, _ = self.shell("svc", "data", "enable")
        _, mobile = self.shell("settings", "get", "global", "mobile_data")
        off_ok, _ = self.shell("svc", "wifi", "disable")
        cellular = now()
        time.sleep(3)
        during = self.transports()
        time.sleep(max(seconds - 3, 1))
        on_ok, _ = self.shell("svc", "wifi", "enable")
        wifi = now()
        time.sleep(5)
        self.log.write(kind="host-action", action="handover", cellular=cellular,
                       wifi=wifi, applied=data_ok and off_ok and on_ok,
                       mobile_data=mobile.strip(), before=before, during=during,
                       after=self.transports(),
                       changed=self.changed(before, during))

    def _background(self, seconds: int) -> None:
        time.sleep(1)
        home_ok, _ = self.shell("input", "keyevent", "KEYCODE_HOME")
        home = now()
        time.sleep(seconds)
        back_ok, _ = self.shell(
            "monkey", "-p", self.package, "-c", "android.intent.category.LAUNCHER", "1"
        )
        self.log.write(kind="host-action", action="background", home=home,
                       relaunched=now(), applied=home_ok and back_ok)


class ControlHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args) -> None:
        return

    def do_POST(self) -> None:  # noqa: N802
        device: DeviceServer = self.server.device  # type: ignore[attr-defined]
        name = self.path.strip("/")
        try:
            body = json.loads((read_body(self) or b"{}").decode())
        except (ValueError, UnicodeDecodeError):
            body = None
        if not isinstance(body, dict):
            name, body = "", {}
            result = {"error": "the body must be a JSON object"}
        elif name == "quit":
            result = {"quit": True}
        elif name.startswith("host/"):
            actions = self.server.actions  # type: ignore[attr-defined]
            result = (
                actions.run(name[len("host/"):], body)
                if actions is not None
                else {"error": "host actions need --adb-serial"}
            )
        else:
            result = device.command(name, body)
        body = json.dumps(result).encode()
        self.send_response(200 if "error" not in result else 400)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
        if name == "quit":
            self.server.stopping.set()  # type: ignore[attr-defined]


def serve(args: argparse.Namespace) -> int:
    root = Path(args.root).resolve()
    root.mkdir(parents=True, exist_ok=True)
    if args.port in RESERVED_PORTS:
        die("refusing a reserved port")
    device = DeviceServer(root, args.bind, args.port)
    device.open_relay = args.open
    secret = root / "password"
    servers: list[ThreadingHTTPServer] = []
    stopping = threading.Event()
    serving = threading.Event()

    # Installed before anything is owned: a SIGTERM while booting unwinds
    # through the cleanup below; once serving, it ends the run with a report.
    def terminate(*_) -> None:
        stopping.set()
        if not serving.is_set():
            raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, terminate)
    # Whatever fails, the owned server stops and the password file goes.
    try:
        device.prepare()
        device.start()
        relay = ThreadingHTTPServer((args.bind, args.port), RelayHandler)
        servers.append(relay)
        relay.daemon_threads = True
        relay.device = device  # type: ignore[attr-defined]
        device.port = int(relay.server_address[1])
        threading.Thread(target=relay.serve_forever, daemon=True).start()
        control = None
        if args.control_port is not None:
            control = ThreadingHTTPServer(("127.0.0.1", args.control_port), ControlHandler)
            servers.append(control)
            control.daemon_threads = True
            control.device = device  # type: ignore[attr-defined]
            control.stopping = stopping  # type: ignore[attr-defined]
            control.actions = (  # type: ignore[attr-defined]
                HostActions(args.adb_serial, args.app_package, device.log)
                if args.adb_serial
                else None
            )
            threading.Thread(target=control.serve_forever, daemon=True).start()
        # Created owner-only, never readable by others even for a moment.
        fd = os.open(secret, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        os.fchmod(fd, 0o600)  # a file left by an earlier run keeps no wider mode
        with os.fdopen(fd, "w") as f:
            f.write(device.password + "\n")
        print(json.dumps({**device.status(), "control_port": control and control.server_address[1]}))
        print(f"device-server: password in {secret} (pair with user opencode)", flush=True)

        def console() -> None:
            for line in sys.stdin:
                name = line.strip()
                if name == "quit":
                    break
                if name:
                    print(json.dumps(device.command(name), indent=2), flush=True)
            stopping.set()

        if args.console:
            threading.Thread(target=console, daemon=True).start()
        serving.set()
        try:
            while not stopping.wait(0.5):
                pass
        except KeyboardInterrupt:
            pass
        try:
            (root / "report.json").write_text(json.dumps(device.report(), indent=2) + "\n")
        except (OSError, ValueError) as error:
            print(f"device-server: no report: {error}", file=sys.stderr)
    except KeyboardInterrupt:
        print("device-server: interrupted", file=sys.stderr)
        return 130
    finally:
        for server in servers:
            server.shutdown()
            server.server_close()
        device.close()
        secret.unlink(missing_ok=True)
    print(f"device-server: stopped; report in {root / 'report.json'}", flush=True)
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    p_serve = sub.add_parser("serve")
    p_serve.add_argument("--root", required=True)
    p_serve.add_argument("--bind", default="127.0.0.1")
    p_serve.add_argument("--port", type=int, default=0)
    p_serve.add_argument("--control-port", type=int, default=None)
    p_serve.add_argument("--no-console", dest="console", action="store_false")
    p_serve.add_argument(
        "--open",
        action="store_true",
        help="the relay authenticates every client, whatever password it sends (private network only)",
    )
    p_serve.add_argument("--adb-serial", default=None, help="enable emulator host actions")
    p_serve.add_argument("--app-package", default="com.verseles.codewalk")
    p_acq = sub.add_parser("acquire")
    p_acq.add_argument("--root", required=True)
    args = parser.parse_args(argv)
    if args.command == "acquire":
        print(acquire(Path(args.root).resolve()))
        return 0
    return serve(args)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
