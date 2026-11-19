import io
import json
from pathlib import Path
import plistlib
import tarfile
import tempfile
import unittest
from unittest import mock
import zipfile

import verify_v2_artifacts as subject

V2_AOT = b"\0snapshot package:codewalk/main_v2.dart \0"
LEGACY_AOT = b"\0snapshot package:codewalk/main.dart \0"
SIGNER = ("Signer #1 certificate DN: CN=Helio, O=Verseles\n"
          "Signer #1 certificate SHA-256 digest: " + subject.PRODUCTION_SIGNER + "\n")
DEBUG_SIGNER = ("Signer #1 certificate DN: C=US, O=Android, CN=Android Debug\n"
                "Signer #1 certificate SHA-256 digest: " + "cd" * 32 + "\n")
VERSION, CODE = "2.0.0-beta.1", 1792802000


def elf(machine):
    header = bytearray(b"\x7fELF\x02\x01" + b"\0" * 58)
    header[18:20] = machine.to_bytes(2, "little")
    return bytes(header)


def pe_exe(machine=subject.PE_MACHINE_AMD64):
    pe_offset = 0x80
    buf = bytearray(pe_offset + 24)
    buf[0:2] = b"MZ"
    buf[60:64] = pe_offset.to_bytes(4, "little")
    buf[pe_offset:pe_offset + 4] = b"PE\x00\x00"
    buf[pe_offset + 4:pe_offset + 6] = machine.to_bytes(2, "little")
    return bytes(buf)


def macho_thin(cpu=subject.MACHO_CPU_TYPE_ARM64):
    return b"\xcf\xfa\xed\xfe" + cpu.to_bytes(4, "little") + b"\0" * 24


def macho_fat(cpus=(subject.MACHO_CPU_TYPE_ARM64, subject.MACHO_CPU_TYPE_X86_64)):
    buf = bytearray(b"\xca\xfe\xba\xbe" + len(cpus).to_bytes(4, "big"))
    for cpu in cpus:
        buf += cpu.to_bytes(4, "big") + b"\0" * 16
    return bytes(buf)


class ArtifactFixture:
    def __init__(self, root: Path, version=VERSION):
        self.root = root
        self.version = version
        self.badging = (f"package: name='com.verseles.codewalk' versionCode='{CODE}' "
                        f"versionName='{version}' platformBuildVersionName='16'\n")
        self.certs = SIGNER

    def apk(self, libs=None):
        path = self.root / "codewalk-android-arm64.apk"
        libs = {"lib/arm64-v8a/libapp.so": V2_AOT, "lib/arm64-v8a/libflutter.so": b"engine"} if libs is None else libs
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr("AndroidManifest.xml", b"manifest")
            for name, data in libs.items():
                archive.writestr(name, data)
        return path

    def linux(self, target, machine=None, libapp=V2_AOT, extra=None):
        path = self.root / f"codewalk-{target}.tar.gz"
        files = {"./codewalk": elf(machine or subject.ELF_MACHINE[target]),
                 "./updater/install.sh": (subject.ROOT / "install.sh").read_bytes(),
                 "./lib/libapp.so": libapp, "./lib/libflutter_linux_gtk.so": b"engine",
                 "./data/flutter_assets/AssetManifest.bin": b"assets",
                 "./data/flutter_assets/version.json": json.dumps({"version": self.version}).encode(),
                 **(extra or {})}
        with tarfile.open(path, "w:gz") as archive:
            for name, data in files.items():
                info = tarfile.TarInfo(name)
                info.size = len(data)
                archive.addfile(info, io.BytesIO(data))
        return path

    def windows(self, exe=None, app_so=V2_AOT, extra=None, backslash=False):
        path = self.root / "codewalk-windows-x64.zip"
        sep = "\\" if backslash else "/"
        files = {
            "codewalk.exe": pe_exe() if exe is None else exe,
            "flutter_windows.dll": b"engine",
            f"data{sep}icudtl.dat": b"icu",
            f"data{sep}app.so": app_so,
            f"data{sep}flutter_assets{sep}AssetManifest.bin": b"assets",
            **(extra or {}),
        }
        with zipfile.ZipFile(path, "w") as archive:
            for name, data in files.items():
                archive.writestr(name, data)
        return path

    def macos(self, binary=None, aot=V2_AOT, bundle_id=subject.APPLICATION_ID, version=None,
              plist_fmt=plistlib.FMT_XML, extra=None, symlinks=None):
        path = self.root / "codewalk-macos-arm64.tar.gz"
        plist_data = plistlib.dumps(
            {
                "CFBundleIdentifier": bundle_id,
                "CFBundleShortVersionString": self.version if version is None else version,
            },
            fmt=plist_fmt,
        )
        files = {
            "codewalk.app/Contents/MacOS/codewalk": macho_thin() if binary is None else binary,
            "codewalk.app/Contents/Info.plist": plist_data,
            "codewalk.app/Contents/Frameworks/App.framework/Versions/A/App": aot,
            "codewalk.app/Contents/Frameworks/App.framework/Versions/A/Resources/flutter_assets/AssetManifest.bin": b"a",
            "codewalk.app/Contents/Frameworks/FlutterMacOS.framework/Versions/A/FlutterMacOS": b"engine",
            **(extra or {}),
        }
        with tarfile.open(path, "w:gz") as archive:
            for name, data in files.items():
                info = tarfile.TarInfo(name)
                info.size = len(data)
                archive.addfile(info, io.BytesIO(data))
            for link_path, target in (symlinks or {"codewalk.app/Contents/Frameworks/App.framework/Versions/Current": "A"}).items():
                link = tarfile.TarInfo(link_path)
                link.type = tarfile.SYMTYPE
                link.linkname = target
                archive.addfile(link)
        return path

    def runner(self, command, **_):
        output = self.badging if command[1:3] == ["dump", "badging"] else self.certs
        return mock.Mock(stdout=output)

    def paths(self, **overrides):
        build = {
            "apk": self.apk,
            "linux-x64": lambda: self.linux("linux-x64"),
            "linux-arm64": lambda: self.linux("linux-arm64"),
            "windows-x64": self.windows,
            "macos-arm64": self.macos,
        }
        return {key: overrides[key] if key in overrides else make() for key, make in build.items()}


class VerifyV2ArtifactsTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.fixture = ArtifactFixture(self.root)
        patcher = mock.patch.object(subject, "aapt2", return_value="/sdk/build-tools/36.0.0/aapt2")
        patcher.start()
        self.addCleanup(patcher.stop)

    def verify(self, paths=None, tag="v2.0.0-beta.1", version=None, kind="beta"):
        resolved_version = self.fixture.version if version is None else version
        return subject.verify(tag, resolved_version, CODE, "f" * 40, paths or self.fixture.paths(),
                              self.root / "out", kind=kind, runner=self.fixture.runner)

    def test_all_five_v2_assets_produce_a_bound_beta_manifest(self):
        manifest = self.verify()
        self.assertEqual(sorted(manifest["assets"]), sorted(subject.ASSETS.values()))
        self.assertEqual(manifest["schema"], 1)
        self.assertEqual(manifest["entry_point"], "lib/main_v2.dart")
        self.assertTrue(manifest["prerelease"])
        self.assertFalse(manifest["make_latest"])
        apk = manifest["assets"]["codewalk-android-arm64.apk"]
        self.assertEqual((apk["version_code"], apk["signer_sha256"]), (CODE, subject.PRODUCTION_SIGNER))
        self.assertEqual(manifest["assets"]["codewalk-windows-x64.zip"]["architecture"], "x64")
        self.assertEqual(manifest["assets"]["codewalk-macos-arm64.tar.gz"]["architecture"], "arm64")
        written = json.loads((self.root / "out/release-manifest.json").read_text())
        self.assertEqual(written["commit"], "f" * 40)
        sums = (self.root / "out/SHA256SUMS").read_text().splitlines()
        self.assertEqual(len(sums), 5)
        self.assertIn(f"{apk['sha256']}  codewalk-android-arm64.apk", sums)

    def test_stable_v2_0_0_sets_non_prerelease_and_latest_flags(self):
        self.fixture = ArtifactFixture(self.root, version="2.0.0")
        manifest = self.verify(tag="v2.0.0", version="2.0.0", kind="stable")
        self.assertFalse(manifest["prerelease"])
        self.assertTrue(manifest["make_latest"])
        self.assertEqual(manifest["schema"], 1)

    def test_kind_and_version_must_agree(self):
        with self.assertRaisesRegex(ValueError, "stable kind requires 2.0.0"):
            self.verify(tag="v2.0.0-beta.1", version="2.0.0-beta.1", kind="stable")
        self.fixture = ArtifactFixture(self.root, version="2.0.0")
        with self.assertRaisesRegex(ValueError, "beta kind requires"):
            self.verify(tag="v2.0.0", version="2.0.0", kind="beta")

    def test_a_legacy_or_missing_bootstrap_is_refused(self):
        for libapp, message in ((LEGACY_AOT, "lacks the v2"), (V2_AOT + LEGACY_AOT, "legacy"), (b"", "missing")):
            with self.subTest(message=message):
                with self.assertRaisesRegex(ValueError, message):
                    self.verify(self.fixture.paths(**{"linux-arm64": self.fixture.linux("linux-arm64", libapp=libapp)}))
                with self.assertRaisesRegex(ValueError, message):
                    self.verify(self.fixture.paths(**{"windows-x64": self.fixture.windows(app_so=libapp)}))
                with self.assertRaisesRegex(ValueError, message):
                    self.verify(self.fixture.paths(**{"macos-arm64": self.fixture.macos(aot=libapp)}))
                with self.assertRaisesRegex(ValueError, message):
                    libs = {"lib/arm64-v8a/libflutter.so": b"engine"}
                    if libapp:
                        libs["lib/arm64-v8a/libapp.so"] = libapp
                    self.verify(self.fixture.paths(apk=self.fixture.apk(libs)))

    def test_windows_bundle_accepts_backslash_separators_and_refuses_bad_arch_or_unsafe(self):
        manifest = self.verify(self.fixture.paths(**{"windows-x64": self.fixture.windows(backslash=True)}))
        self.assertEqual(manifest["assets"]["codewalk-windows-x64.zip"]["architecture"], "x64")

        with self.assertRaisesRegex(ValueError, "Windows x64 PE"):
            self.verify(self.fixture.paths(**{"windows-x64": self.fixture.windows(exe=pe_exe(machine=0x014C))}))
        with self.assertRaisesRegex(ValueError, "unsafe"):
            self.verify(self.fixture.paths(**{"windows-x64": self.fixture.windows(extra={"../escape.dll": b"x"})}))

    def test_macos_bundle_accepts_universal_fat_and_binary_plist_and_refuses_x64_only_or_bad_metadata(self):
        fat = self.fixture.macos(binary=macho_fat(), plist_fmt=plistlib.FMT_BINARY)
        manifest = self.verify(self.fixture.paths(**{"macos-arm64": fat}))
        self.assertEqual(manifest["assets"]["codewalk-macos-arm64.tar.gz"]["architectures"], ["arm64", "x64"])

        x64_only = self.fixture.macos(binary=macho_thin(cpu=subject.MACHO_CPU_TYPE_X86_64))
        with self.assertRaisesRegex(ValueError, "macOS arm64 Mach-O"):
            self.verify(self.fixture.paths(**{"macos-arm64": x64_only}))

        wrong_id = self.fixture.macos(bundle_id="com.example.other")
        with self.assertRaisesRegex(ValueError, "bundle id"):
            self.verify(self.fixture.paths(**{"macos-arm64": wrong_id}))

        wrong_ver = self.fixture.macos(version="1.265.1")
        with self.assertRaisesRegex(ValueError, "CFBundleShortVersionString"):
            self.verify(self.fixture.paths(**{"macos-arm64": wrong_ver}))

        escape_link = self.fixture.macos(symlinks={"codewalk.app/Contents/evil": "../../../../etc/passwd"})
        with self.assertRaisesRegex(ValueError, "unsafe link"):
            self.verify(self.fixture.paths(**{"macos-arm64": escape_link}))

    def test_an_apk_with_other_abis_is_refused(self):
        libs = {"lib/arm64-v8a/libapp.so": V2_AOT, "lib/x86_64/libapp.so": V2_AOT}
        with self.assertRaisesRegex(ValueError, "only arm64-v8a"):
            self.verify(self.fixture.paths(apk=self.fixture.apk(libs)))

    def test_the_apk_identity_and_version_must_match_the_plan(self):
        for badging in ("package: name='com.verseles.codewalk.v2preview' versionCode='1792802000' versionName='2.0.0-beta.1'\n",
                        "package: name='com.verseles.codewalk' versionCode='1792800000' versionName='2.0.0-beta.1'\n",
                        "package: name='com.verseles.codewalk' versionCode='1792802000' versionName='1.265.0'\n",
                        "nothing\n"):
            with self.subTest(badging=badging), self.assertRaises(ValueError):
                self.fixture.badging = badging
                self.verify()

    def test_a_debug_or_ambiguous_signer_is_refused(self):
        for certs in (DEBUG_SIGNER, "", SIGNER + "Signer #2 certificate DN: CN=Other\n"
                      "Signer #2 certificate SHA-256 digest: " + "ef" * 32 + "\n"):
            with self.subTest(certs=certs), self.assertRaises(ValueError):
                self.fixture.certs = certs
                self.verify()

    def test_another_release_key_is_refused(self):
        self.fixture.certs = SIGNER.replace(subject.PRODUCTION_SIGNER, "ab" * 32)
        with self.assertRaisesRegex(ValueError, "not the production signer"):
            self.verify()

    def test_a_linux_bundle_for_the_wrong_architecture_is_refused(self):
        wrong = self.fixture.linux("linux-x64", machine=183)
        with self.assertRaisesRegex(ValueError, "linux-x64 ELF"):
            self.verify(self.fixture.paths(**{"linux-x64": wrong}))

    def test_an_incomplete_or_unsafe_bundle_is_refused(self):
        unsafe = self.fixture.linux("linux-x64", extra={"../escape": b"x"})
        with self.assertRaisesRegex(ValueError, "unsafe"):
            self.verify(self.fixture.paths(**{"linux-x64": unsafe}))

    def test_asset_names_and_the_tag_are_exact(self):
        renamed = self.root / "other.apk"
        self.fixture.apk().rename(renamed)
        with self.assertRaisesRegex(ValueError, "must be named"):
            self.verify(self.fixture.paths(apk=renamed))
        with self.assertRaisesRegex(ValueError, "does not name"):
            self.verify(tag="v2.0.0-beta.2")


if __name__ == "__main__":
    unittest.main()
