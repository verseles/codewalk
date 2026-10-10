#!/usr/bin/env python3
"""Compile the explicit v2 debug target in a fresh native output directory.

Use a fresh checkout/copy when native outputs already exist. This command never
cleans another build, installs dependencies, signs a release or uploads artifacts.
"""

import argparse
import hashlib
import json
from pathlib import Path
import platform
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[2]
ENTRY_POINT = "lib/main_v2.dart"


def command_for(target, system, machine):
    if system != "Linux":
        raise RuntimeError("Native MVP compiler targets require a Linux host.")
    architectures = {"x86_64": "x64", "amd64": "x64", "aarch64": "arm64", "arm64": "arm64"}
    arch = architectures.get(machine.lower())
    if arch is None:
        raise RuntimeError(f"Unsupported native compiler host architecture: {machine}")
    if target == "android":
        if arch != "x64":
            raise RuntimeError("Android APK compilation requires an x64 host; ARM64 is not supported here.")
        kind, target_platform = "apk", "android-arm64"
    elif target == "linux":
        kind, target_platform = "linux", f"linux-{arch}"
    else:
        raise ValueError("Unknown native build target.")
    command = ["flutter", "build", kind, "--debug", "--no-pub", "--target", ENTRY_POINT,
               "--target-platform", target_platform]
    if target == "android":
        # Native plugins can supply other ABIs even with one Flutter target.
        command.append("--split-per-abi")
    return command, arch


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def inspect_artifacts(root, target, arch):
    if target == "android":
        apk = root / "build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk"
        with zipfile.ZipFile(apk) as archive:
            abis = {name.split("/")[1] for name in archive.namelist()
                    if name.startswith("lib/") and name.endswith(".so")}
            if abis != {"arm64-v8a"} or "lib/arm64-v8a/libflutter.so" not in archive.namelist():
                raise RuntimeError(f"Unexpected debug APK ABIs: {sorted(abis)}")
            kernel = "assets/flutter_assets/kernel_blob.bin"
            if kernel not in archive.namelist() or archive.getinfo(kernel).file_size == 0:
                raise RuntimeError("Debug APK is missing its compiled Dart kernel.")
        files = [apk]
    else:
        bundle = root / f"build/linux/{arch}/debug/bundle"
        executable = bundle / "codewalk"
        header = executable.read_bytes()[:20]
        expected_machine = 183 if arch == "arm64" else 62
        if (len(header) < 20 or header[:6] != b"\x7fELF\x02\x01"
                or int.from_bytes(header[18:20], "little") != expected_machine):
            raise RuntimeError("Linux bundle executable architecture does not match the selected host.")
        if not (bundle / "lib/libflutter_linux_gtk.so").is_file() or not (bundle / "data/flutter_assets").is_dir():
            raise RuntimeError("Incomplete Linux bundle: engine or Flutter assets missing.")
        kernel = bundle / "data/flutter_assets/kernel_blob.bin"
        if not kernel.is_file() or kernel.stat().st_size == 0:
            raise RuntimeError("Linux debug bundle is missing its compiled Dart kernel.")
        files = sorted(path for path in bundle.rglob("*") if path.is_file())
    return {str(path.relative_to(root)): sha256(path) for path in files}


def build(root=ROOT, *, target, system=None, machine=None, runner=subprocess.run):
    system = system or platform.system()
    machine = machine or platform.machine()
    command, arch = command_for(target, system, machine)
    # Android output is build/app, not build/android. Refuse before any build
    # process so old legacy artifacts cannot be overwritten or counted as proof.
    output = root / "build" / ("app" if target == "android" else "linux")
    if output.exists() or output.is_symlink():
        raise RuntimeError(f"Native output already exists: {output}. Use a fresh checkout/copy.")
    entry = root / ENTRY_POINT
    if not entry.is_file():
        raise RuntimeError(f"Missing explicit v2 entry point: {ENTRY_POINT}")
    metadata = {
        "target": target, "mode": "debug", "entry_point": ENTRY_POINT,
        "entry_point_sha256": sha256(entry), "host": {"os": system, "architecture": machine},
        "command": command, "compiler": "not-run", "installation": "not-tested",
        "release_aot": "not-tested", "distribution": "not-tested",
    }
    evidence = root / "build/native-evidence" / f"{target}.json"
    evidence.parent.mkdir(parents=True, exist_ok=True)
    try:
        metadata["source_commit"] = runner(
            ["git", "rev-parse", "HEAD"], cwd=root, check=True, text=True, capture_output=True
        ).stdout.strip()
        metadata["source_dirty"] = bool(runner(
            ["git", "status", "--porcelain"], cwd=root, check=True, text=True, capture_output=True
        ).stdout.strip())
        metadata["flutter"] = json.loads(runner(
            ["flutter", "--version", "--machine"], cwd=root, check=True, text=True, capture_output=True
        ).stdout)
        print(json.dumps(metadata), flush=True)
        runner(command, cwd=root, check=True)
        metadata["artifacts_sha256"] = inspect_artifacts(root, target, arch)
        metadata["compiler"] = "pass"
    except Exception:
        metadata["compiler"] = "fail"
        raise
    finally:
        evidence.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print(f"V2 {target} debug compilation verified; installed-device/release acceptance remains separate.", flush=True)
    return metadata


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", choices=("android", "linux"))
    args = parser.parse_args()
    build(target=args.target)


if __name__ == "__main__":
    main()
