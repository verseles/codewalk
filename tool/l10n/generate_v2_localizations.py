#!/usr/bin/env python3
"""Generate/check only v2 localizations using Flutter's official generator.

Run from any directory after activating the pinned Flutter toolchain:
    python3 tool/l10n/generate_v2_localizations.py [--check]

The root l10n.yaml belongs to the retained app. Flutter prioritizes that file
over CLI options, so generation runs in a temporary minimal Flutter project.
No pub resolution, retained ARB edit, or retained generated edit is performed.
"""

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "lib/shared/l10n"
LOCALES = ("ar", "bn", "de", "en", "es", "fr", "hi", "it", "ja", "ko", "pt", "ru", "ur", "zh")
KEYS = {
    "chatConversations",
    "chatConversation",
    "settingsTitle",
    "settingsServersTitle",
    "onboardingConnectRunningServer",
    "chatAddServerToStart",
    "commonCancel",
    "serversCopy",
    "settingsBack",
    "unsupportedLink",
}
OUTPUT_NAMES = {"v2_localizations.dart"} | {
    f"v2_localizations_{locale}.dart" for locale in LOCALES
}


def validate_sources() -> None:
    arb_paths = {path.name for path in (SOURCE / "arb").glob("*.arb")}
    expected = {f"app_{locale}.arb" for locale in LOCALES}
    if arb_paths != expected:
        raise ValueError(f"Unexpected v2 ARB file set: {sorted(arb_paths ^ expected)}")
    for locale in LOCALES:
        path = SOURCE / "arb" / f"app_{locale}.arb"
        arb = json.loads(path.read_text(encoding="utf-8"))
        message_keys = {key for key in arb if not key.startswith("@")}
        if message_keys != KEYS:
            raise ValueError(f"Unexpected message keys in {path.name}: {sorted(message_keys ^ KEYS)}")
        if any(not isinstance(arb[key], str) or not arb[key].strip() for key in KEYS):
            raise ValueError(f"Missing translated UI copy in {path.name}")


def generate(check: bool) -> int:
    validate_sources()
    flutter = shutil.which("flutter")
    if flutter is None:
        raise ValueError("Flutter is not on PATH; activate the cloud/repository toolchain first.")
    with tempfile.TemporaryDirectory(prefix="codewalk-v2-l10n-") as directory:
        project = Path(directory)
        (project / "pubspec.yaml").write_text(
            "name: codewalk_v2_l10n_codegen\n"
            "publish_to: none\n"
            "environment:\n  sdk: ^3.12.0\n"
            "dependencies:\n  flutter:\n    sdk: flutter\n"
            "flutter:\n  generate: true\n",
            encoding="utf-8",
        )
        shutil.copyfile(SOURCE / "l10n.yaml", project / "l10n.yaml")
        shutil.copytree(SOURCE / "arb", project / "lib/l10n/arb")
        subprocess.run([flutter, "gen-l10n"], cwd=project, check=True)
        generated = project / "lib/l10n/generated"
        actual = {path.name for path in generated.iterdir() if path.is_file()}
        if actual != OUTPUT_NAMES:
            raise ValueError(f"Unexpected generated files: {sorted(actual ^ OUTPUT_NAMES)}")
        destination = SOURCE / "generated"
        existing = {path.name for path in destination.glob("*") if path.is_file()}
        stale = existing - OUTPUT_NAMES
        if stale:
            raise ValueError(f"Remove unexpected v2 generated files after review: {sorted(stale)}")
        changed = [
            name for name in sorted(OUTPUT_NAMES)
            if not (destination / name).is_file()
            or (destination / name).read_bytes() != (generated / name).read_bytes()
        ]
        if check and changed:
            print("V2 localizations are stale: " + ", ".join(changed), file=sys.stderr)
            return 1
        if not check:
            destination.mkdir(parents=True, exist_ok=True)
            for name in changed:
                shutil.copyfile(generated / name, destination / name)
        print(f"V2 localizations {'checked' if check else 'generated'}: {len(OUTPUT_NAMES)} files.")
        return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Fail on stale outputs without editing files.")
    args = parser.parse_args()
    try:
        return generate(args.check)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"V2 localization generation failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
