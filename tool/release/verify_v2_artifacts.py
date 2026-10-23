#!/usr/bin/env python3
"""Verifies the v2 beta release artifacts and writes their manifest.

Exactly three assets ship: the Android arm64 APK and the Linux x64 and ARM64
bundles. Each must carry the v2 app compiled from lib/main_v2.dart: its AOT
library (libapp.so) names the v2 entry library and not the legacy one. The
APK must be the production package, signed with the production key (never
the debug key), arm64-only, with the planned versionName and versionCode. The
Linux executables must match their architectures. The manifest and
SHA256SUMS record what was verified, bound to each digest.

Usage:
  verify_v2_artifacts.py --tag T --version V --apk-version-code C --commit SHA
      --apk PATH --linux-x64 PATH --linux-arm64 PATH --out DIR
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import sys
import tarfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_codes import LEDGER, aapt2  # noqa: E402

ENTRY_POINT = "lib/main_v2.dart"
# Android installs an update only over an APK signed by the same key.
PRODUCTION_SIGNER = json.loads(LEDGER.read_text(encoding="utf-8"))["production_signer"]["sha256"]
APPLICATION_ID = "com.verseles.codewalk"
# Dart snapshots keep library URIs (private class names are not kept), so
# the entry library names the bootstrap: the published v1 libapp.so holds
# package:codewalk/main.dart, a v2 build holds main_v2.dart instead.
V2_MARKER = b"package:codewalk/main_v2.dart"
LEGACY_MARKER = b"package:codewalk/main.dart"
ASSETS = {
    "apk": "codewalk-android-arm64.apk",
    "linux-x64": "codewalk-linux-x64.tar.gz",
    "linux-arm64": "codewalk-linux-arm64.tar.gz",
}
ELF_MACHINE = {"linux-x64": 62, "linux-arm64": 183}


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def require_v2_aot(name: str, libapp: bytes) -> None:
    if not libapp:
        raise ValueError(f"{name}: missing libapp.so (not an AOT release build)")
    if V2_MARKER not in libapp:
        raise ValueError(f"{name}: libapp.so lacks the v2 bootstrap; it was not built from {ENTRY_POINT}")
    if LEGACY_MARKER in libapp:
        raise ValueError(f"{name}: libapp.so contains the legacy bootstrap")


def inspect_apk(path: Path, version: str, version_code: int, runner=subprocess.run) -> dict:
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        abis = {name.split("/")[1] for name in names if name.startswith("lib/") and name.endswith(".so")}
        if abis != {"arm64-v8a"}:
            raise ValueError(f"APK must hold only arm64-v8a libraries, found {sorted(abis)}")
        libapp = archive.read("lib/arm64-v8a/libapp.so") if "lib/arm64-v8a/libapp.so" in names else b""
    require_v2_aot(path.name, libapp)
    badging = runner([aapt2(), "dump", "badging", str(path)], check=True, text=True, capture_output=True).stdout
    package = re.search(r"^package: name='([^']*)' versionCode='([0-9]+)' versionName='([^']*)'", badging, re.M)
    if not package:
        raise ValueError("APK badging has no package line")
    if package.group(1) != APPLICATION_ID:
        raise ValueError(f"APK package is {package.group(1)}, not {APPLICATION_ID}")
    if int(package.group(2)) != version_code or package.group(3) != version:
        raise ValueError(f"APK is {package.group(3)} ({package.group(2)}), planned {version} ({version_code})")
    certificates = runner([str(Path(aapt2()).with_name("apksigner")), "verify", "--print-certs", str(path)],
                          check=True, text=True, capture_output=True).stdout
    signers = re.findall(r"^.*Signer.*certificate DN: (.*)$", certificates, re.M)
    digests = sorted(set(re.findall(r"^.*Signer.*certificate SHA-256 digest: ([0-9a-f]{64})$", certificates, re.M)))
    if not signers or any("CN=Android Debug" in signer for signer in signers):
        raise ValueError(f"APK must be release-signed, never with the debug key: {signers}")
    if len(digests) != 1:
        raise ValueError(f"APK must have exactly one signing certificate, found {digests}")
    if digests[0] != PRODUCTION_SIGNER:
        raise ValueError(f"APK signer {digests[0]} is not the production signer {PRODUCTION_SIGNER}")
    return {"abi": "arm64-v8a", "application_id": APPLICATION_ID, "version_name": version,
            "version_code": version_code, "signer_dn": signers[0], "signer_sha256": digests[0]}


def inspect_linux(path: Path, target: str) -> dict:
    with tarfile.open(path, "r:gz") as archive:
        members = {}
        for member in archive.getmembers():
            name = member.name[2:] if member.name.startswith("./") else member.name
            if name.startswith("/") or ".." in Path(name).parts:
                raise ValueError(f"{path.name}: unsafe path {member.name!r}")
            if member.issym() or member.islnk():
                continue
            members[name] = member

        def read(name: str) -> bytes:
            member = members.get(name)
            if member is None or not member.isfile():
                return b""
            return archive.extractfile(member).read()

        executable = read("codewalk")
        if (len(executable) < 20 or executable[:6] != b"\x7fELF\x02\x01"
                or int.from_bytes(executable[18:20], "little") != ELF_MACHINE[target]):
            raise ValueError(f"{path.name}: executable is not a {target} ELF")
        if "lib/libflutter_linux_gtk.so" not in members or not any(
                name.startswith("data/flutter_assets/") for name in members):
            raise ValueError(f"{path.name}: incomplete bundle (engine or Flutter assets missing)")
        require_v2_aot(path.name, read("lib/libapp.so"))
    return {"architecture": target.removeprefix("linux-"), "signature": "none (Linux bundles are not signed)"}


def verify(tag: str, version: str, version_code: int, commit: str, paths: dict, out: Path,
           runner=subprocess.run) -> dict:
    if tag != f"v{version}":
        raise ValueError(f"tag {tag} does not name version {version}")
    assets = {}
    for key, name in ASSETS.items():
        path = paths[key]
        if path.name != name:
            raise ValueError(f"asset {path} must be named {name}")
        details = (inspect_apk(path, version, version_code, runner) if key == "apk"
                   else inspect_linux(path, key))
        data = path.read_bytes()
        assets[name] = {"sha256": sha256_bytes(data), "size": len(data), **details}
    manifest = {
        "schema": 1, "tag": tag, "version": version, "commit": commit, "entry_point": ENTRY_POINT,
        "entry_point_sha256": sha256_bytes((ROOT / ENTRY_POINT).read_bytes()),
        "prerelease": True, "make_latest": False, "assets": assets,
    }
    out.mkdir(parents=True, exist_ok=True)
    (out / "release-manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    sums = io.StringIO()
    for name in sorted(assets):
        sums.write(f"{assets[name]['sha256']}  {name}\n")
    (out / "SHA256SUMS").write_text(sums.getvalue(), encoding="utf-8")
    return manifest


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    for flag in ("--tag", "--version", "--commit", "--apk", "--linux-x64", "--linux-arm64", "--out"):
        parser.add_argument(flag, required=True)
    parser.add_argument("--apk-version-code", required=True, type=int)
    args = parser.parse_args(argv[1:])
    paths = {"apk": Path(args.apk), "linux-x64": Path(args.linux_x64), "linux-arm64": Path(args.linux_arm64)}
    try:
        manifest = verify(args.tag, args.version, args.apk_version_code, args.commit, paths, Path(args.out))
    except (ValueError, OSError, KeyError, zipfile.BadZipFile, tarfile.TarError,
            subprocess.CalledProcessError) as error:
        print(f"Refusing to release: {error}", file=sys.stderr)
        return 1
    print(json.dumps({name: asset["sha256"] for name, asset in manifest["assets"].items()}))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
