#!/usr/bin/env python3
"""Generate/check only v2 localizations using Flutter's official generator.

Run from any directory after activating the pinned Flutter toolchain:
    python3 tool/l10n/generate_v2_localizations.py [--check]

Generation runs in a temporary minimal Flutter project with the v2 l10n.yaml,
so no pub resolution or edit outside lib/shared/l10n is performed.
"""

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from hosts_catalog import PORT_KEYS as HOST_KEYS, NEW_KEYS as HOST_NEW_KEYS
from pairing_catalog import KEYS as PAIRING_KEYS
from diagnostics_catalog import PORT_KEYS as DIAGNOSTICS_KEYS, NEW_KEYS as DIAGNOSTICS_NEW_KEYS
from sessions_catalog import PORT_KEYS as SESSION_KEYS, NEW_KEYS as SESSION_NEW_KEYS
from session_history_catalog import PORT_KEYS as HISTORY_KEYS, NEW_KEYS as HISTORY_NEW_KEYS
from session_live_catalog import (
    PORT_KEYS as LIVE_PORT_KEYS,
    NEW_KEYS as LIVE_NEW_KEYS,
)
from session_composer_catalog import NEW_KEYS as COMPOSER_NEW_KEYS
from session_search_catalog import NEW_KEYS as SEARCH_NEW_KEYS, SWITCH_KEYS
from session_command_catalog import (
    PORT_KEYS as COMMAND_PORT_KEYS,
    NEW_KEYS as COMMAND_NEW_KEYS,
)
from session_permission_catalog import NEW_KEYS as PERMISSION_NEW_KEYS
from session_stop_catalog import NEW_KEYS as STOP_NEW_KEYS
from session_form_catalog import NEW_KEYS as FORM_NEW_KEYS
from session_selection_catalog import NEW_KEYS as SELECTION_NEW_KEYS
from session_error_catalog import NEW_KEYS as ERROR_NEW_KEYS
from updates_catalog import PORT_KEYS as UPDATES_KEYS, NEW_KEYS as UPDATES_NEW_KEYS
from rendering_catalog import (
    PORT_KEYS as RENDERING_KEYS,
    NEW_KEYS as RENDERING_NEW_KEYS,
)
from workspace_catalog import (
    PORT_KEYS as WORKSPACE_KEYS,
    NEW_KEYS as WORKSPACE_NEW_KEYS,
)
from session_turn_catalog import (
    PORT_KEYS as TURN_PORT_KEYS,
    NEW_KEYS as TURN_NEW_KEYS,
)


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
APPEARANCE_KEYS = {
    "settingsAppearanceSectionTitle", "settingsAppearanceTheme",
    "settingsAppearanceThemeDescription", "settingsAppearanceSystem",
    "settingsAppearanceLight", "settingsAppearanceDark",
    "settingsAppearanceCodeWalkClassic", "settingsAppearanceOpenCodePresets",
    "settingsAppearancePresetPalette", "settingsAppearancePresetHelper",
    "settingsAppearanceSearchPreset", "settingsAppearanceNoPresets",
    "settingsAppearanceAmoledDark", "settingsAppearanceAmoledDarkActive",
    "settingsAppearanceAmoledDarkInactive", "settingsAppearanceWallpaperColors",
    "settingsAppearanceWallpaperPresetBlocked", "settingsAppearanceWallpaperNormal",
    "settingsAppearanceBrandColor", "settingsAppearanceBrandColorDynamicBlocked",
    "settingsAppearanceBrandColorPresetBlocked", "settingsAppearanceBrandColorNormal",
    "settingsAppearanceContrast", "settingsAppearanceContrastDynamicBlocked",
    "settingsAppearanceContrastPresetBlocked", "settingsAppearanceContrastNormal",
    "settingsAppearanceContrastReduced", "settingsAppearanceContrastLow",
    "settingsAppearanceContrastStandard", "settingsAppearanceContrastMedium",
    "settingsAppearanceContrastMediumHigh", "settingsAppearanceContrastHigh",
    "settingsAppearanceDensity", "settingsAppearanceDensityDescription",
    "settingsAppearanceDensityExtraDense", "settingsAppearanceDensityDense",
    "settingsAppearanceDensityNormal", "settingsAppearanceDensitySpacious",
    "settingsAppearanceDensityExtraSpacious", "chatRetry",
    "settingsAppearanceMathRendering", "settingsAppearanceMathRenderingDescription",
    "settingsAppearanceFontSize", "settingsAppearanceSystemFontScale",
    "settingsAppearanceSystemFontScaleDescription", "settingsAppearanceChatFontScale",
    "settingsAppearanceChatFontScaleDescription",
    "settingsAppearanceThinkingBubbles",
    "settingsAppearanceThinkingBubblesDescription",
    "settingsAppearanceToolCallBubbles",
    "settingsAppearanceToolCallBubblesDescription",
    "settingsAppearanceComposerTips",
    "settingsAppearanceComposerTipsDescription",
    "settingsAppearanceSessionTabs",
    "settingsAppearanceSessionTabsDescription",
    "settingsAppearanceRecentSessions",
    "settingsAppearanceRecentSessionsDescription",
    "chatDisplayMenu",
    "sessionTabsGestureHint",
    "sessionTabsGestureHintDismiss",
}
KEYS |= APPEARANCE_KEYS | {"appearanceStorageError"}
SETTINGS_KEYS = {
    "settingsAppearanceTitle", "settingsAppearanceDescription",
    "settingsNavigationGroupSetup", "settingsNavigationGroupExperience",
    "settingsNavigationGroupInput", "settingsNavigationNoResults",
    "settingsNavigationSearchHint", "settingsShortcutsTitle",
    "settingsShortcutsDescription", "settingsShortcutsSearch",
    "settingsShortcutsEdit", "settingsShortcutsReset",
    "settingsProvenanceCodeWalkLocal", "shortcutsKeyboardShortcuts",
    "shortcutsSearchEditBindings", "shortcutsTheseBindingsStored",
    "shortcutsReset", "shortcutsApply", "shortcutsSetShortcutWidget",
    "shortcutsPressKeyCombination", "shortcutsErrorInvalid",
    "shortcutsErrorUnsupportedKey", "shortcutsErrorConflict",
    "shortcutsConflictConflict", "shortcutGroupSession",
    "shortcutGroupGeneral", "shortcutGroupPrompt", "shortcutGroupNavigation",
    "shortcutGroupModelAndAgent", "shortcutGroupApplication",
    "settingsAboutTitle", "settingsAboutDescription", "aboutGitHub",
    "aboutTelegram", "settingsAboutOurGroup", "searchableDropdownSearchHint",
    "searchableDropdownEmptyText", "chatMessageUnableToOpenLink",
    "settingsBehaviorTitle", "settingsBehaviorChatRenderMode",
    "settingsBehaviorChatRenderModeDescription",
    "settingsBehaviorChatRenderModeLive",
    "settingsBehaviorChatRenderModeLiveDescription",
    "settingsBehaviorChatRenderModeBlock",
    "settingsBehaviorChatRenderModeBlockDescription",
    "settingsBehaviorComposerSpellCheck",
    "settingsBehaviorComposerSpellCheckDescription",
    "settingsBehaviorLanguage",
    "settingsBehaviorLanguageDescription",
    "settingsLanguageSystemDefault",
}
for name in (
    "NewConversation", "RefreshData", "FocusInput", "ToggleVoiceInput",
    "QuickOpenFiles", "OpenSettings", "NextRecentModel", "NextVariant",
    "FocusCloseDrawer", "NextAgent", "PreviousAgent", "NextTab",
    "PreviousTab", "CloseApp", "QuitApp", "SearchConversation",
):
    SETTINGS_KEYS |= {f"shortcut{name}", f"shortcut{name}Desc"}
SETTINGS_NEW_KEYS = (
    "shortcutsUnassigned", "shortcutsUnassign", "shortcutsUnavailable",
    "settingsStorageError", "settingsSearchClear",
    # The desktop window band and its settings (#474).
    "desktopWindowMinimize", "desktopWindowMaximize", "desktopWindowRestore",
    "settingsBehaviorWindowChrome", "settingsBehaviorWindowChromeDescription",
    "settingsBehaviorWindowClose", "settingsBehaviorWindowCloseDescription",
)
KEYS |= SETTINGS_KEYS | set(SETTINGS_NEW_KEYS)
KEYS |= HOST_KEYS | set(HOST_NEW_KEYS)
KEYS |= set(PAIRING_KEYS)
KEYS |= DIAGNOSTICS_KEYS | set(DIAGNOSTICS_NEW_KEYS)
KEYS |= SESSION_KEYS | set(SESSION_NEW_KEYS)
KEYS |= HISTORY_KEYS | set(HISTORY_NEW_KEYS)
KEYS |= LIVE_PORT_KEYS | set(LIVE_NEW_KEYS)
KEYS |= set(COMPOSER_NEW_KEYS)
KEYS |= set(SEARCH_NEW_KEYS) | set(SWITCH_KEYS)
KEYS |= COMMAND_PORT_KEYS | set(COMMAND_NEW_KEYS)
KEYS |= set(PERMISSION_NEW_KEYS)
KEYS |= set(STOP_NEW_KEYS)
KEYS |= set(FORM_NEW_KEYS)
KEYS |= set(SELECTION_NEW_KEYS)
KEYS |= set(ERROR_NEW_KEYS)
KEYS |= UPDATES_KEYS | set(UPDATES_NEW_KEYS)
KEYS |= RENDERING_KEYS | set(RENDERING_NEW_KEYS)
KEYS |= WORKSPACE_KEYS | set(WORKSPACE_NEW_KEYS)
KEYS |= TURN_PORT_KEYS | set(TURN_NEW_KEYS)


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
