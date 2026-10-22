#!/usr/bin/env python3
"""Compile the explicit v2 debug target in a fresh native output directory.

Use a fresh checkout/copy when native outputs already exist. This command never
cleans another build, installs dependencies, signs a release or uploads artifacts.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[2]
ENTRY_POINT = "lib/main_v2.dart"
# The owner's development preview: a profile (AOT) build that installs beside
# the production app. The arm64 split is delivered; the x86_64 split of the
# same build is the one an emulator can launch.
PREVIEW_APPLICATION_ID = "com.verseles.codewalk.v2preview"
PREVIEW_LABEL = "CodeWalk v2 Preview"
PREVIEW_ACTIVITY = "com.verseles.codewalk.MainActivity"
PREVIEW_APKS = {"arm64-v8a": "app-arm64-v8a-profile.apk", "x86_64": "app-x86_64-profile.apk"}


def command_for(target, system, machine):
    if system != "Linux":
        raise RuntimeError("Native MVP compiler targets require a Linux host.")
    architectures = {"x86_64": "x64", "amd64": "x64", "aarch64": "arm64", "arm64": "arm64"}
    arch = architectures.get(machine.lower())
    if arch is None:
        raise RuntimeError(f"Unsupported native compiler host architecture: {machine}")
    if target in ("android", "android-preview"):
        if arch != "x64":
            raise RuntimeError("Android APK compilation requires an x64 host; ARM64 is not supported here.")
        kind, target_platform = "apk", "android-arm64"
    elif target == "linux":
        kind, target_platform = "linux", f"linux-{arch}"
    else:
        raise ValueError("Unknown native build target.")
    mode = "--profile" if target == "android-preview" else "--debug"
    if target == "android-preview":
        target_platform = "android-arm64,android-x64"
    command = ["flutter", "build", kind, mode, "--no-pub", "--target", ENTRY_POINT,
               "--target-platform", target_platform]
    if target != "linux":
        # Native plugins can supply other ABIs even with one Flutter target.
        command.append("--split-per-abi")
    if target == "android-preview":
        command.append("--android-project-arg=codewalkPreview=true")
    return command, arch


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def inspect_preview_apks(root):
    """Each split carries only its ABI and a compiled AOT app, never a JIT kernel."""
    files = []
    for abi, name in PREVIEW_APKS.items():
        apk = root / "build/app/outputs/flutter-apk" / name
        with zipfile.ZipFile(apk) as archive:
            names = archive.namelist()
            abis = {name.split("/")[1] for name in names if name.startswith("lib/") and name.endswith(".so")}
            if abis != {abi}:
                raise RuntimeError(f"Unexpected preview APK ABIs: {sorted(abis)}")
            for library in ("libflutter.so", "libapp.so"):
                entry = f"lib/{abi}/{library}"
                if entry not in names or archive.getinfo(entry).file_size == 0:
                    raise RuntimeError(f"Preview APK is missing {entry}.")
            if "assets/flutter_assets/kernel_blob.bin" in names:
                raise RuntimeError("Preview APK carries a JIT kernel; it is not a profile build.")
        files.append(apk)
    return files


def android_tool(name):
    """The newest SDK build-tools copy of [name]."""
    sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    candidates = sorted(Path(sdk).glob(f"build-tools/*/{name}")) if sdk else []
    if not candidates:
        raise RuntimeError(f"Android SDK build tool not found: {name}")
    return str(candidates[-1])


def badging_value(text, pattern):
    match = re.search(pattern, text, re.MULTILINE)
    return match.group(1) if match else None


def preview_identity(apk, runner):
    """The installed identity of a preview split, refused unless it is the preview's."""
    badging = runner([android_tool("aapt2"), "dump", "badging", str(apk)],
                     check=True, text=True, capture_output=True).stdout
    identity = {
        "application_id": badging_value(badging, r"^package: name='([^']*)'"),
        "label": badging_value(badging, r"^application-label:'([^']*)'"),
        "launchable_activity": badging_value(badging, r"^launchable-activity: name='([^']*)'"),
        "version_code": badging_value(badging, r"versionCode='([^']*)'"),
        "min_sdk": badging_value(badging, r"^sdkVersion:'([^']*)'"),
        "target_sdk": badging_value(badging, r"^targetSdkVersion:'([^']*)'"),
    }
    if (identity["application_id"] != PREVIEW_APPLICATION_ID or identity["label"] != PREVIEW_LABEL
            or identity["launchable_activity"] != PREVIEW_ACTIVITY):
        raise RuntimeError(f"Preview APK identity is not the development preview: {identity}")
    # Provider authorities and declared permissions are device-wide: one the
    # production app also holds would make the preview uninstallable beside it.
    manifest = runner([android_tool("aapt2"), "dump", "xmltree", "--file", "AndroidManifest.xml", str(apk)],
                      check=True, text=True, capture_output=True).stdout
    authorities, permissions, element = [], [], None
    for line in manifest.splitlines():
        if line.strip().startswith("E: "):
            element = line.split()[1]
        elif element == "provider" and (match := re.search(r':authorities\([^)]*\)="([^"]*)"', line)):
            authorities += match.group(1).split(";")
        elif element == "permission" and (match := re.search(r':name\([^)]*\)="([^"]*)"', line)):
            permissions.append(match.group(1))
    shared = [name for name in authorities + permissions if PREVIEW_APPLICATION_ID not in name]
    if shared:
        raise RuntimeError(f"Preview APK declares device-wide names outside its own ID: {shared}")
    identity["provider_authorities"], identity["declared_permissions"] = authorities, permissions
    certificates = runner([android_tool("apksigner"), "verify", "--print-certs", str(apk)],
                          check=True, text=True, capture_output=True).stdout
    signer = badging_value(certificates, r"^Signer #1 certificate DN: (.*)$")
    if signer is None or "CN=Android Debug" not in signer:
        # The certificate lines are public and show which key was found.
        found = [line for line in certificates.splitlines() if "certificate" in line][:4]
        raise RuntimeError(f"Preview APK must be signed with the debug key, never the release key: {found}")
    identity["signer"] = signer
    return identity


def inspect_artifacts(root, target, arch):
    if target == "android-preview":
        files = inspect_preview_apks(root)
    elif target == "android":
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
    output = root / "build" / ("linux" if target == "linux" else "app")
    if output.exists() or output.is_symlink():
        raise RuntimeError(f"Native output already exists: {output}. Use a fresh checkout/copy.")
    entry = root / ENTRY_POINT
    if not entry.is_file():
        raise RuntimeError(f"Missing explicit v2 entry point: {ENTRY_POINT}")
    metadata = {
        "target": target, "mode": "profile" if target == "android-preview" else "debug", "entry_point": ENTRY_POINT,
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
        if target == "android-preview":
            metadata["identity"] = {abi: preview_identity(root / "build/app/outputs/flutter-apk" / name, runner)
                                    for abi, name in PREVIEW_APKS.items()}
        metadata["compiler"] = "pass"
    except Exception:
        metadata["compiler"] = "fail"
        raise
    finally:
        evidence.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print(f"V2 {target} {metadata['mode']} compilation verified; installed-device/release acceptance remains separate.", flush=True)
    return metadata


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", choices=("android", "android-preview", "linux"))
    args = parser.parse_args()
    build(target=args.target)


if __name__ == "__main__":
    main()
