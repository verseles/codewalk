#!/usr/bin/env python3
"""V2-042C emulator cells: one run of the device reliability matrix on the
Android emulator the CI job started.

Starts tool/ci/v2_device_server.py on the runner (loopback, reached from the
emulator as 10.0.2.2) with its adb host actions, runs
integration_test/device_reliability_test.dart against it, stops the server
and writes the evidence: the device identity, the app's per-cell results, the
host actions with the transports Android reported, the relay's event-stream
log and the server's per-session prompt counts. The password is never
written to the evidence.

Usage:
  python3 tool/ci/device_reliability_android.py --root /tmp/cw-device \\
      --serial emulator-5554 --out device-evidence
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
TEST = "integration_test/device_reliability_test.dart"
PACKAGE = "com.verseles.codewalk"


def adb(serial: str, *args: str) -> str:
    return subprocess.run(
        ["adb", "-s", serial, "shell", *args],
        capture_output=True,
        text=True,
        timeout=120,
    ).stdout.strip()


def control(port: int, command: str) -> dict:
    request = urllib.request.Request(
        f"http://127.0.0.1:{port}/{command}", data=b"{}", method="POST"
    )
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with opener.open(request, timeout=120) as response:
        return json.loads(response.read().decode())


def free_port() -> int:
    import socket

    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return int(s.getsockname()[1])


def jsonl(path: Path) -> list[dict]:
    if not path.is_file():
        return []
    return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True)
    parser.add_argument("--serial", default="emulator-5554")
    parser.add_argument("--out", required=True)
    parser.add_argument("--timeout", type=int, default=2400)
    args = parser.parse_args(argv)
    root = Path(args.root).resolve()
    out = Path(args.out).resolve()
    root.mkdir(parents=True, exist_ok=True)
    out.mkdir(parents=True, exist_ok=True)
    control_port = free_port()
    server = subprocess.Popen(
        [
            sys.executable,
            str(REPO_ROOT / "tool/ci/v2_device_server.py"),
            "serve",
            "--root", str(root),
            "--control-port", str(control_port),
            "--no-console",
            "--adb-serial", args.serial,
            "--app-package", PACKAGE,
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        cwd=str(REPO_ROOT),
    )
    first = server.stdout.readline() if server.stdout else ""
    try:
        status = json.loads(first)
    except ValueError:
        server.kill()
        print(first + (server.stdout.read() if server.stdout else ""), file=sys.stderr)
        return 2
    port = int(status["endpoint"].rsplit(":", 1)[1].strip("/"))
    password = (root / "password").read_text().strip()
    device = {
        "serial_kind": "emulator",
        "api": adb(args.serial, "getprop", "ro.build.version.sdk"),
        "release": adb(args.serial, "getprop", "ro.build.version.release"),
        "abi": adb(args.serial, "getprop", "ro.product.cpu.abi"),
        "model": adb(args.serial, "getprop", "ro.product.model"),
    }
    started = time.time()
    flutter = shutil.which("flutter") or "flutter"
    try:
        test = subprocess.run(
            [
                flutter, "test", TEST, "-d", args.serial,
                f"--dart-define=CW_DEVICE_ENDPOINT=http://10.0.2.2:{port}/",
                f"--dart-define=CW_DEVICE_PASSWORD={password}",
                f"--dart-define=CW_DEVICE_CONTROL=http://10.0.2.2:{control_port}",
            ],
            capture_output=True,
            text=True,
            timeout=args.timeout,
            cwd=str(REPO_ROOT),
        )
        rc, output = test.returncode, test.stdout + test.stderr
    except subprocess.TimeoutExpired as expired:
        # The server is still stopped below, and the partial run is evidence.
        rc = 124
        output = "".join(
            part.decode() if isinstance(part, bytes) else part or ""
            for part in (expired.stdout, expired.stderr)
        ) + f"\nflutter test timed out after {args.timeout} s\n"
    log = output.replace(password, "[REDACTED]")
    (out / "flutter-test.log").write_text(log)
    try:
        control(control_port, "quit")
        server.wait(timeout=120)
    except Exception:  # noqa: BLE001 - the evidence still records the run
        server.kill()
    records = jsonl(root / "requests.jsonl")
    report = json.loads((root / "report.json").read_text()) if (root / "report.json").is_file() else {}
    evidence = {
        "device": device,
        "server_version": report.get("version"),
        "flutter_test_rc": rc,
        "duration_seconds": round(time.time() - started),
        "results": jsonl(root / "results.jsonl"),
        "host_actions": [r for r in records if r.get("kind") == "host-action"],
        "restarts": report.get("restarts", []),
        "sessions": report.get("sessions", {}),
        "event_streams": report.get("event_streams", {}),
    }
    text = json.dumps(evidence, indent=2) + "\n"
    if password in text:
        print("refusing to write evidence containing the password", file=sys.stderr)
        return 2
    (out / "device-report.json").write_text(text)
    if (root / "requests.jsonl").is_file():
        shutil.copy(root / "requests.jsonl", out / "requests.jsonl")
    print(json.dumps({k: evidence[k] for k in ("device", "flutter_test_rc", "results")}, indent=2))
    return rc


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
