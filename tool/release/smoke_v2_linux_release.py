#!/usr/bin/env python3
"""Launches the packaged v2 Linux release bundle and records what was seen.

The archive is the exact asset a beta ships: it must pass the same checks as
verify_v2_artifacts.py (architecture ELF, complete bundle, v2 AOT library).
It is then extracted into an owned temporary directory and its `codewalk`
executable is started on the current X display with HOME and every XDG
directory redirected there, so the host's own CodeWalk data is never read or
written. The launch passes only when a visible window of that process
appears and the process is still running after the settle period; it is then
terminated. The evidence JSON names the archive digest, the architecture, the
host and each observation; a failed launch is recorded, never skipped.

Usage:
  smoke_v2_linux_release.py --archive PATH --target linux-x64|linux-arm64 --evidence DIR
"""
import argparse
import json
import os
from pathlib import Path
import platform
import re
import shutil
import signal
import subprocess
import sys
import tarfile
import tempfile
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
from verify_v2_artifacts import ELF_MACHINE, inspect_linux, sha256_bytes  # noqa: E402

HOST_MACHINE = {"linux-x64": ("x86_64",), "linux-arm64": ("aarch64", "arm64")}
WINDOW_TIMEOUT = 60.0
SETTLE_SECONDS = 10.0
LOG_TAIL = 40


def extract(archive: Path, destination: Path) -> Path:
    with tarfile.open(archive, "r:gz") as bundle:
        for member in bundle.getmembers():
            name = member.name[2:] if member.name.startswith("./") else member.name
            if (name.startswith("/") or ".." in Path(name).parts
                    or not (member.isdir() or member.isfile() or member.issym())):
                raise ValueError(f"{archive.name}: unsafe entry {member.name!r}")
            if member.issym() and (member.linkname.startswith("/") or ".." in Path(member.linkname).parts):
                raise ValueError(f"{archive.name}: unsafe link {member.name!r}")
        bundle.extractall(destination)
    return destination


def isolated_env(root: Path) -> dict:
    env = {key: value for key, value in os.environ.items()
           if key in ("PATH", "DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "LANG", "LC_ALL")}
    home = root / "home"
    paths = {"HOME": home, "XDG_DATA_HOME": home / ".local/share", "XDG_CONFIG_HOME": home / ".config",
             "XDG_CACHE_HOME": home / ".cache", "XDG_STATE_HOME": home / ".local/state",
             "XDG_RUNTIME_DIR": root / "runtime"}
    for path in paths.values():
        path.mkdir(parents=True, exist_ok=True)
    (root / "runtime").chmod(0o700)
    env.update({key: str(path) for key, path in paths.items()})
    env.setdefault("LANG", "C.UTF-8")
    return env


def visible_windows(pid: int, runner=subprocess.run) -> list[str]:
    result = runner(["xdotool", "search", "--onlyvisible", "--pid", str(pid)],
                    capture_output=True, text=True, timeout=10)
    return [line for line in result.stdout.split() if line.isdigit()]


def sanitized(text: str) -> str:
    return re.sub(r"https?://(?:127\.0\.0\.1|localhost|\[::1\]):\d+/\S*", "[local debug service]", text)


def smoke(archive: Path, target: str, evidence: Path, runner=subprocess.run, popen=subprocess.Popen,
          clock=time.monotonic, sleep=time.sleep) -> dict:
    evidence.mkdir(parents=True, exist_ok=True)
    data = archive.read_bytes()
    report = {"asset": archive.name, "sha256": sha256_bytes(data), "target": target,
              "host_machine": platform.machine(), "checks": {}, "launch": "fail"}
    checks = report["checks"]
    try:
        if platform.machine() not in HOST_MACHINE[target]:
            raise RuntimeError(f"{target} must launch on its own architecture, not {platform.machine()}")
        checks["hostArchitecture"] = "passed"
        report.update(inspect_linux(archive, target))
        checks["bundleVerified"] = "passed"
        if shutil.which("xdotool") is None or not os.environ.get("DISPLAY"):
            raise RuntimeError("an X display and xdotool are required to observe the window")
        with tempfile.TemporaryDirectory(prefix="cw2-release-smoke-") as temporary:
            root = Path(temporary)
            bundle = extract(archive, root / "bundle")
            env = isolated_env(root)
            log_path = root / "app.log"
            with log_path.open("w") as log:
                process = popen([str(bundle / "codewalk")], cwd=bundle, env=env, stdout=log,
                                stderr=subprocess.STDOUT, start_new_session=True)
            try:
                deadline = clock() + WINDOW_TIMEOUT
                windows = []
                while clock() < deadline and process.poll() is None:
                    windows = visible_windows(process.pid, runner)
                    if windows:
                        break
                    sleep(1)
                if not windows:
                    raise RuntimeError("no visible window of the launched process appeared")
                checks["windowVisible"] = "passed"
                report["windows"] = len(windows)
                sleep(SETTLE_SECONDS)
                if process.poll() is not None:
                    raise RuntimeError(f"the app exited during the settle period (code {process.returncode})")
                checks["aliveAfterSettle"] = "passed"
                report["settle_seconds"] = SETTLE_SECONDS
                screenshot = evidence / f"{target}-window.png"
                if shutil.which("import"):
                    runner(["import", "-window", windows[0], str(screenshot)], capture_output=True, timeout=15)
                    if screenshot.exists():
                        report["screenshot"] = screenshot.name
                report["launch"] = "passed"
            finally:
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGTERM)
                    try:
                        process.wait(timeout=15)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait(timeout=15)
                lines = sanitized(log_path.read_text(errors="replace")).splitlines()
                report["log_tail"] = lines[-LOG_TAIL:]
            # The owned tree is removed with the temporary directory; nothing
            # outside it was given to the process.
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        report["error"] = str(error)
    (evidence / f"{target}-launch.json").write_text(json.dumps(report, indent=2) + "\n")
    return report


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--target", required=True, choices=sorted(ELF_MACHINE))
    parser.add_argument("--evidence", required=True, type=Path)
    args = parser.parse_args(argv)
    report = smoke(args.archive, args.target, args.evidence)
    print(json.dumps({key: report.get(key) for key in ("asset", "sha256", "target", "launch", "error")}))
    return 0 if report["launch"] == "passed" else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
