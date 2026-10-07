#!/usr/bin/env python3
"""Reproduce the bounded v2 appearance port from the retained v1 snapshot.

This offline operation never fetches upstream or modifies the retained sources.
Remove the retained-source dependency when the v2 cutover owns these leaves.
"""

import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HEADER = "// GENERATED CODE - DO NOT MODIFY BY HAND.\n// Offline selective port: tool/theme/port_v2_appearance.py\n\n"


def outputs():
    legacy = ROOT / "lib/presentation/theme"
    target = ROOT / "lib/shared/theme"
    for name in ("brand_colors.dart", "opencode_web_theme_registry.dart"):
        content = (legacy / name).read_text()
        # Flutter Color keeps the low 32 bits of oversized legacy literals.
        # Spell that same value explicitly so the port adds no analyzer debt.
        content = re.sub(
            r"Color\(0x([0-9A-Fa-f]+)\)",
            lambda match: f"Color(0x{int(match[1], 16) & 0xFFFFFFFF:08X})",
            content,
        )
        yield target / name, HEADER + content
    presets = (legacy / "opencode_theme_presets.dart").read_text().replace(
        "../../domain/entities/experience_settings.dart", "opencode_theme_preferences.dart"
    )
    yield target / "opencode_theme_presets.dart", HEADER + presets
    model = (ROOT / "lib/domain/entities/experience_settings.dart").read_text()
    enum = model[model.index("enum OpenCodeThemePreset {"):model.index("enum SpeechToTextEngine")]
    codecs = model[model.index("String openCodeThemePresetKey("):model.index("NotificationCategory? notificationCategoryFromKey")]
    yield target / "opencode_theme_preferences.dart", (HEADER + enum + codecs).rstrip() + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    stale = []
    for path, content in outputs():
        if not path.exists() or path.read_text() != content:
            stale.append(str(path.relative_to(ROOT)))
            if not args.check:
                path.write_text(content)
    if args.check and stale:
        print("Stale appearance port: " + ", ".join(stale))
        return 1
    print("V2 appearance snapshot " + ("checked" if args.check else "ported"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
