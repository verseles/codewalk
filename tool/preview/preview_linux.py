#!/usr/bin/env python3
"""Package and launch the native development preview without touching v1.

The private profile/session prevents normal application-storage interference;
it is not an operating-system sandbox against hostile code or same-user access.
"""

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import secrets
import selectors
import shutil
import signal
import subprocess
import sys
import tarfile
import tempfile
import time
from xml.sax.saxutils import escape

KIND = "codewalk-native-development-preview"
ARCHIVE_ROOT = "codewalk-v2-preview"
PROFILE_MARKER = ".codewalk-preview.json"
BASE_MARKER = ".codewalk-preview-root.json"


def digest(path):
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def files_under(root):
    for path in sorted(root.rglob("*")):
        if not path.resolve().is_relative_to(root.resolve()):
            raise RuntimeError("Bundle contains an external symlink.")
        if path.is_file():
            yield path
        elif not path.is_dir():
            raise RuntimeError("Bundle contains an unsupported file type.")


def verify_bundle(bundle):
    manifest = json.loads((bundle / "preview-manifest.json").read_text())
    if manifest.get("kind") != KIND or manifest.get("architecture") != "x64":
        raise RuntimeError("Not a Linux x64 development preview.")
    require_commit(manifest.get("source_commit"))
    hashes = manifest.get("files_sha256")
    if not isinstance(hashes, dict) or not {"codewalk", "preview.py", "Open-preview.sh", "PREVIEW.txt"} <= hashes.keys():
        raise RuntimeError("Preview manifest has an incomplete file inventory.")
    actual_names = {str(path.relative_to(bundle)) for path in files_under(bundle)} - {"preview-manifest.json"}
    if actual_names != set(hashes):
        raise RuntimeError("Preview files differ from the manifest inventory.")
    for name, expected in hashes.items():
        path = bundle / name
        if Path(name).is_absolute() or ".." in Path(name).parts or path.is_symlink():
            raise RuntimeError("Unsafe manifest path.")
        if not path.is_file() or digest(path) != expected:
            raise RuntimeError(f"Preview file integrity check failed: {name}")
    return manifest


def require_commit(value):
    if not isinstance(value, str) or re.fullmatch(r"[0-9a-f]{40}", value) is None:
        raise RuntimeError("Preview source revision must be an exact hexadecimal commit.")


def compiler_inventory(metadata):
    prefix = "build/linux/x64/debug/bundle/"
    recorded = metadata.get("artifacts_sha256")
    if not isinstance(recorded, dict) or not recorded:
        raise RuntimeError("Compiler bundle hashes are required.")
    expected = {}
    for name, checksum in recorded.items():
        if (not isinstance(name, str) or not name.startswith(prefix)
                or ".." in Path(name).parts or not isinstance(checksum, str)
                or re.fullmatch(r"[0-9a-f]{64}", checksum) is None):
            raise RuntimeError("Invalid compiler bundle inventory.")
        expected[name[len(prefix):]] = checksum
    return expected


def verify_compiler_files(bundle, expected):
    actual = {str(path.relative_to(bundle)): digest(path) for path in files_under(bundle)}
    if actual != expected:
        raise RuntimeError("Bundle differs from the recorded compiler file set or hashes.")


def package(bundle, metadata_path, output):
    bundle = bundle.resolve()
    metadata = json.loads(metadata_path.read_text())
    if (metadata.get("compiler") != "pass" or metadata.get("target") != "linux"
            or metadata.get("mode") != "debug" or metadata.get("entry_point") != "lib/main_v2.dart"):
        raise RuntimeError("A verified explicit v2 Linux debug build is required.")
    require_commit(metadata.get("source_commit"))
    expected = compiler_inventory(metadata)
    verify_compiler_files(bundle, expected)
    header = (bundle / "codewalk").read_bytes()[:20]
    if header[:6] != b"\x7fELF\x02\x01" or int.from_bytes(header[18:20], "little") != 62:
        raise RuntimeError("Preview executable is not Linux x64.")
    if output.exists() or output.is_symlink():
        raise RuntimeError("Refusing to overwrite an existing preview archive.")
    with tempfile.TemporaryDirectory(prefix="cw2-package-") as temporary:
        root = Path(temporary) / ARCHIVE_ROOT
        list(files_under(bundle))
        shutil.copytree(bundle, root, symlinks=False)
        verify_compiler_files(root, expected)
        here = Path(__file__).parent
        shutil.copyfile(Path(__file__), root / "preview.py")
        shutil.copyfile(here / "PREVIEW.txt", root / "PREVIEW.txt")
        launcher = root / "Open-preview.sh"
        launcher.write_text('#!/bin/sh\nset -eu\nbase=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)\nexec python3 "$base/preview.py" launch --bundle "$base" "$@"\n')
        launcher.chmod(0o755)
        (root / "codewalk").chmod(0o755)
        manifest = {
            "kind": KIND, "architecture": "x64", "runtime": "Ubuntu 24.04 X11/software",
            "source_commit": metadata["source_commit"], "source_dirty": metadata["source_dirty"],
            "entry_point": metadata["entry_point"], "flutter": metadata["flutter"],
            "credentials": "encrypted ephemeral keyring; cleared after each launcher session",
            "files_sha256": {str(path.relative_to(root)): digest(path) for path in files_under(root)},
        }
        (root / "preview-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        output.parent.mkdir(parents=True, exist_ok=True)
        with tarfile.open(output, "w:gz", dereference=True) as archive:
            archive.add(root, arcname=ARCHIVE_ROOT)
    checksum = digest(output)
    output.with_suffix(output.suffix + ".sha256").write_text(f"{checksum}  {output.name}\n")
    print(f"Packaged preview: {output.name} SHA256={checksum}", flush=True)


def managed_directory(path):
    if path.is_symlink():
        raise RuntimeError("Preview-managed paths must not be symlinks.")
    if path.exists():
        if not path.is_dir() or path.stat().st_uid != os.getuid():
            raise RuntimeError("Preview path is not an owned directory.")
    else:
        path.mkdir(parents=True, mode=0o700)
    path.chmod(0o700)


def prepare_profile(path):
    if path.is_symlink():
        raise RuntimeError("Preview profile must not be a symlink.")
    marker = path / PROFILE_MARKER
    if marker.is_symlink():
        raise RuntimeError("Unsafe profile marker.")
    if marker.exists():
        if not marker.is_file() or json.loads(marker.read_text()).get("kind") != KIND:
            raise RuntimeError("Profile marker does not identify this preview.")
    elif path.exists() and any(path.iterdir()):
        raise RuntimeError("Existing non-preview data directory will not be used.")
    # Validation above is read-only: rejected existing directories keep their
    # permissions and contents. Only recognized/new preview paths are managed.
    managed_directory(path)
    if not marker.exists():
        marker.write_text(json.dumps({"kind": KIND}) + "\n")
    marker.chmod(0o600)
    for name in ("home", "data", "config", "cache", "state"):
        managed_directory(path / name)


def default_profile(data_home, source_commit):
    require_commit(source_commit)
    base = data_home / "codewalk-v2-preview"
    marker = base / BASE_MARKER
    if base.is_symlink() or marker.is_symlink():
        raise RuntimeError("Preview base must not be a symlink.")
    if base.exists():
        if (not base.is_dir() or base.stat().st_uid != os.getuid()
                or not marker.is_file() or json.loads(marker.read_text()).get("kind") != KIND):
            raise RuntimeError("Existing directory is not an owned preview base.")
    managed_directory(base)
    if not marker.exists():
        marker.write_text(json.dumps({"kind": KIND}) + "\n")
        marker.chmod(0o600)
    profile = base / source_commit[:12]
    if not profile.resolve().is_relative_to(base.resolve()):
        raise RuntimeError("Preview profile escapes its dedicated base.")
    return profile


def isolated_environment(profile, runtime, inherited):
    env = dict(inherited)
    original_home = env.get("HOME", "")
    if not env.get("XAUTHORITY") and original_home:
        authority = Path(original_home) / ".Xauthority"
        if authority.is_file():
            env["XAUTHORITY"] = str(authority.resolve())
    for key in list(env):
        if key.startswith(("DBUS_", "GNOME_KEYRING_")):
            env.pop(key)
    env.update({
        "HOME": str(profile / "home"), "XDG_DATA_HOME": str(profile / "data"),
        "XDG_CONFIG_HOME": str(profile / "config"), "XDG_CACHE_HOME": str(profile / "cache"),
        "XDG_STATE_HOME": str(profile / "state"), "XDG_RUNTIME_DIR": str(runtime),
        "TMPDIR": str(runtime / "tmp"), "GDK_BACKEND": "x11",
        "FLUTTER_LINUX_RENDERER": "software",
    })
    return env


def stop_owned(process, *, timeout=5):
    if process is None or process.poll() is not None:
        return
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        process.wait(timeout=timeout)
        return
    try:
        process.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait(timeout=5)


def private_session(bundle, profile, runtime):
    if not os.environ.get("DBUS_SESSION_BUS_ADDRESS"):
        raise RuntimeError("Private session bus was not established.")
    keyring_env = dict(os.environ)
    keyring_data = runtime / "keyring-data"
    managed_directory(keyring_data)
    control = runtime / "keyring-control"
    managed_directory(control)
    keyring_env["XDG_DATA_HOME"] = str(keyring_data)
    daemon = app = None
    log_path = profile / "state/last-launch.log"
    log_fd = os.open(log_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    with os.fdopen(log_fd, "wb") as log:
        try:
            daemon = subprocess.Popen(
                ["gnome-keyring-daemon", "--foreground", "--unlock", "--components=secrets",
                 f"--control-directory={control}"], env=keyring_env, stdin=subprocess.PIPE,
                stdout=subprocess.DEVNULL, stderr=log, start_new_session=True,
            )
            # Unlock material exists only in memory and this private pipe.
            assert daemon.stdin is not None
            daemon.stdin.write(secrets.token_urlsafe(48).encode())
            daemon.stdin.close()
            deadline = time.monotonic() + 15
            while True:
                if daemon.poll() is not None:
                    raise RuntimeError("Private credential service exited before readiness.")
                owner = subprocess.run(
                    ["gdbus", "call", "--session", "--dest", "org.freedesktop.DBus",
                     "--object-path", "/org/freedesktop/DBus", "--method",
                     "org.freedesktop.DBus.GetConnectionUnixProcessID", "org.freedesktop.secrets"],
                    capture_output=True, text=True, timeout=3,
                )
                if owner.returncode == 0:
                    match = re.fullmatch(r"\(uint32 (\d+),\)\s*", owner.stdout)
                    if not match or int(match.group(1)) != daemon.pid:
                        raise RuntimeError("Private credential service has an unexpected owner.")
                    break
                if time.monotonic() >= deadline:
                    raise RuntimeError("Private credential service did not become ready.")
                time.sleep(0.2)
            if os.environ.get("CODEWALK_PREVIEW_ISOLATION_CHECK") == "1":
                value = "synthetic-preview-value"
                subprocess.run(["secret-tool", "store", "--label=Preview QA sentinel", "preview", "sentinel"],
                               input=value, text=True, check=True, timeout=10)
                result = subprocess.run(["secret-tool", "lookup", "preview", "sentinel"],
                                        text=True, capture_output=True, check=True, timeout=10)
                if result.stdout.strip() != value:
                    raise RuntimeError("Private credential service failed its synthetic check.")
                (profile / "state/private-credential-check.json").write_text(json.dumps({
                    "service_pid": daemon.pid, "bus_address": os.environ["DBUS_SESSION_BUS_ADDRESS"],
                    "keyring_data": str(keyring_data), "synthetic_roundtrip": True,
                }))
            app = subprocess.Popen([str(bundle / "codewalk")], stdout=log, stderr=log, start_new_session=True)
            return app.wait()
        finally:
            stop_owned(app)
            stop_owned(daemon)


def launch(bundle, profile=None):
    if platform.system() != "Linux" or platform.machine().lower() not in ("x86_64", "amd64"):
        raise RuntimeError("This prepared preview requires Linux x64.")
    if not os.environ.get("DISPLAY"):
        raise RuntimeError("This preview requires an available X11/XWayland display.")
    for program in ("dbus-daemon", "gnome-keyring-daemon", "gdbus"):
        if shutil.which(program) is None:
            raise RuntimeError(f"Required Ubuntu desktop runtime is missing: {program}")
    bundle = bundle.resolve()
    manifest = verify_bundle(bundle)
    if profile is None:
        data_home = Path(os.environ.get("XDG_DATA_HOME") or (Path.home() / ".local/share"))
        profile = default_profile(data_home, manifest["source_commit"])
    profile = profile.absolute()
    prepare_profile(profile)
    lock = profile / ".launch.lock"
    fd = os.open(lock, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "w"):
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise RuntimeError("This preview profile is already open.") from error
        with tempfile.TemporaryDirectory(prefix="cw2-preview-") as temporary:
            runtime = Path(temporary)
            managed_directory(runtime / "tmp")
            env = isolated_environment(profile, runtime, os.environ)
            config = runtime / "bus.conf"
            config.write_text(
                '<busconfig><type>session</type><auth>EXTERNAL</auth>'
                f'<listen>unix:tmpdir={escape(str(runtime))}</listen>'
                '<policy context="default"><allow own="*"/><allow send_destination="*"/>'
                '<allow receive_sender="*"/></policy></busconfig>'
            )
            bus = process = None
            try:
                bus = subprocess.Popen(
                    ["dbus-daemon", f"--config-file={config}", "--nofork", "--print-address=1"],
                    env=env, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, start_new_session=True,
                )
                assert bus.stdout is not None
                with selectors.DefaultSelector() as readiness:
                    readiness.register(bus.stdout, selectors.EVENT_READ)
                    if not readiness.select(timeout=10):
                        raise RuntimeError("Private bus did not publish its address.")
                    address = bus.stdout.readline().decode().strip()
                if not address.startswith(f"unix:path={runtime}/"):
                    raise RuntimeError("Private bus address is outside its owned runtime.")
                env["DBUS_SESSION_BUS_ADDRESS"] = address
                command = [sys.executable, str(bundle / "preview.py"), "_session", "--bundle", str(bundle),
                           "--profile", str(profile), "--runtime", str(runtime)]
                process = subprocess.Popen(command, env=env, start_new_session=True)
                return process.wait()
            finally:
                # Await the actual Python supervisor, not a bus-runner wrapper.
                # Its finally block reaps app and keyring before it can exit.
                stop_owned(process, timeout=20)
                stop_owned(bus)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="operation", required=True)
    packaging = sub.add_parser("package")
    packaging.add_argument("--bundle", required=True, type=Path)
    packaging.add_argument("--metadata", required=True, type=Path)
    packaging.add_argument("--output", required=True, type=Path)
    opening = sub.add_parser("launch")
    opening.add_argument("--bundle", type=Path, default=Path(__file__).parent)
    opening.add_argument("--profile", type=Path)
    internal = sub.add_parser("_session")
    for name in ("bundle", "profile", "runtime"):
        internal.add_argument(f"--{name}", required=True, type=Path)
    args = parser.parse_args()
    def interrupted(signum, frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, interrupted)
    try:
        if args.operation == "package":
            package(args.bundle, args.metadata, args.output)
            return 0
        if args.operation == "_session":
            return private_session(args.bundle, args.profile, args.runtime)
        return launch(args.bundle, args.profile)
    except KeyboardInterrupt:
        return 130
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Preview could not start: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
