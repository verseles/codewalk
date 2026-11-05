#!/usr/bin/env python3
"""Launches the packaged v2 Linux release bundle and records what was seen.

The archive is the exact asset a beta ships: it must pass the same checks as
verify_v2_artifacts.py (architecture ELF, complete bundle, v2 AOT library).
It is then extracted into an owned temporary directory and its `codewalk`
executable is started on the current X display with HOME and every XDG
directory redirected there, so the host's own CodeWalk data is never read or
written. The launch passes only when a visible window of that process
appears and the process is still running after the settle period. A second
launch inherits a removed working directory, as an older updater can do, and
must recover it, retain the saved preferences on disk, and read the installed
version. Applied channel/theme selections require separate GUI evidence. Both
owned processes are terminated. Failed checks are recorded, never skipped.

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
PREFERENCES_ID = "com.verseles.codewalk"


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
    # XAUTHORITY carries the display cookie (xvfb-run sets it); the file stays
    # outside the redirected HOME. Rendering matches the proven preview launch.
    env = {key: value for key, value in os.environ.items()
           if key in ("PATH", "DISPLAY", "XAUTHORITY", "XAUTHLOCALHOSTNAME", "DBUS_SESSION_BUS_ADDRESS",
                      "LANG", "LC_ALL")}
    home = root / "home"
    paths = {"HOME": home, "XDG_DATA_HOME": home / ".local/share", "XDG_CONFIG_HOME": home / ".config",
             "XDG_CACHE_HOME": home / ".cache", "XDG_STATE_HOME": home / ".local/state",
             "XDG_RUNTIME_DIR": root / "runtime"}
    for path in paths.values():
        path.mkdir(parents=True, exist_ok=True)
    (root / "runtime").chmod(0o700)
    env.update({key: str(path) for key, path in paths.items()})
    env.update({"GDK_BACKEND": "x11"})
    # The default renderer: a forced software renderer aborts on Flutter 3.47.9 under Xvfb.
    env.pop("FLUTTER_LINUX_RENDERER", None)
    env.setdefault("LANG", "C.UTF-8")
    return env


def visible_windows(pid: int, runner=subprocess.run) -> list[str]:
    result = runner(["xdotool", "search", "--onlyvisible", "--pid", str(pid)],
                    capture_output=True, text=True, timeout=10)
    return [line for line in result.stdout.split() if line.isdigit()]


def sanitized(text: str) -> str:
    return re.sub(r"https?://(?:127\.0\.0\.1|localhost|\[::1\]):\d+/\S*", "[local debug service]", text)


def preferences_path(env: dict) -> Path:
    return Path(env["XDG_DATA_HOME"]) / PREFERENCES_ID / "shared_preferences.json"


def process_cwd(pid: int) -> Path:
    return Path(os.readlink(f"/proc/{pid}/cwd"))


def check_startup_preferences(env: dict, version: str) -> None:
    try:
        path = preferences_path(env)
        if path.stat().st_size > 4 * 1024 * 1024:
            raise ValueError("oversized startup metadata")
        preferences = json.loads(path.read_text())
        if not isinstance(preferences, dict):
            raise ValueError("invalid startup metadata")
        state = json.loads(preferences.get("cw2.updates.installedRelease", "null"))
    except (OSError, ValueError, TypeError) as error:
        raise RuntimeError("startup metadata is unreadable") from error
    if (preferences.get("cw2.updates.channel") != "beta"
            or preferences.get("cw2.settings.themeMode") != "light"
            or not isinstance(state, dict) or state.get("schema") != 1
            or state.get("to") != version):
        raise RuntimeError("startup did not retain Beta preferences on disk or read the installed version")


def smoke(archive: Path, target: str, evidence: Path, runner=subprocess.run, popen=subprocess.Popen,
          clock=time.monotonic, sleep=time.sleep) -> dict:
    report = {"asset": archive.name, "target": target, "host_machine": platform.machine(),
              "checks": {}, "launch": "fail"}
    checks = report["checks"]
    try:
        evidence.mkdir(parents=True, exist_ok=True)
        report["sha256"] = sha256_bytes(archive.read_bytes())
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
            version_metadata = json.loads((bundle / "data/flutter_assets/version.json").read_text())
            version = version_metadata.get("version") if isinstance(version_metadata, dict) else None
            if not isinstance(version, str) or not version:
                raise ValueError("bundle version metadata is absent")
            for removed_cwd in (False, True):
                case = "deleted" if removed_cwd else "valid"
                case_root = root / case
                env = isolated_env(case_root)
                preferences = preferences_path(env)
                preferences.parent.mkdir(parents=True, exist_ok=True)
                preferences.write_text(json.dumps({"cw2.schema": 1, "cw2.updates.channel": "beta",
                                                   "cw2.updates.checkOnOpen": False,
                                                   "cw2.settings.themeMode": "light"}))
                command = [str(bundle / "codewalk")]
                cwd = bundle
                if removed_cwd:
                    launcher = Path(env["HOME"]) / ".local/bin/codewalk"
                    launcher.parent.mkdir(parents=True)
                    launcher.symlink_to(bundle / "codewalk")
                    # Positional arguments keep the owned paths out of shell code.
                    command = ["/bin/sh", "-c",
                               'mkdir "$1" && cd "$1" && rmdir "$1" && exec "$2"',
                               "codewalk-deleted-cwd", str(case_root / "removed-cwd"), str(launcher)]
                    cwd = case_root
                log_path = case_root / "app.log"
                with log_path.open("w") as log:
                    process = popen(command, cwd=cwd, env=env, stdout=log,
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
                        raise RuntimeError(f"{case}: no visible window of the launched process appeared")
                    checks["deletedWindowVisible" if removed_cwd else "windowVisible"] = "passed"
                    report["windows"] = len(windows)
                    sleep(SETTLE_SECONDS)
                    if process.poll() is not None:
                        raise RuntimeError(f"{case}: the app exited during the settle period (code {process.returncode})")
                    checks["deletedAliveAfterSettle" if removed_cwd else "aliveAfterSettle"] = "passed"
                    actual_cwd = process_cwd(process.pid)
                    expected_cwd = Path(env["HOME"]) if removed_cwd else bundle
                    if not actual_cwd.is_dir() or actual_cwd.resolve() != expected_cwd.resolve():
                        raise RuntimeError(f"{case}: native working directory was not retained/repaired")
                    checks["deletedCwdRepaired" if removed_cwd else "validCwdRetained"] = "passed"
                    check_startup_preferences(env, version)
                    checks["deletedPreferencesRetained" if removed_cwd else "preferencesRetained"] = "passed"
                    report["settle_seconds"] = SETTLE_SECONDS
                    screenshot = evidence / f"{target}{'-deleted' if removed_cwd else ''}-window.png"
                    if shutil.which("import"):
                        runner(["import", "-window", windows[0], str(screenshot)], capture_output=True, timeout=15)
                        if screenshot.exists():
                            report["deleted_screenshot" if removed_cwd else "screenshot"] = screenshot.name
                finally:
                    if process.poll() is None:
                        try:
                            os.killpg(process.pid, signal.SIGTERM)
                            try:
                                process.wait(timeout=15)
                            except subprocess.TimeoutExpired:
                                os.killpg(process.pid, signal.SIGKILL)
                                process.wait(timeout=15)
                        except ProcessLookupError:
                            process.wait(timeout=15)
                    lines = sanitized(log_path.read_text(errors="replace")).splitlines()
                    report["deleted_log_tail" if removed_cwd else "log_tail"] = lines[-LOG_TAIL:]
            report["launch"] = "passed"
            # The owned tree is removed with the temporary directory; nothing
            # outside it was given to the process.
    except (OSError, RuntimeError, ValueError, tarfile.TarError, subprocess.SubprocessError) as error:
        report["error"] = str(error)
        report["launch"] = "fail"
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
