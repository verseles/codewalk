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
APPEARANCE_KEYS = {
    "settingsAppearanceSectionTitle", "settingsAppearanceTheme",
    "settingsAppearanceThemeDescription", "settingsAppearanceSystem",
    "settingsAppearanceLight", "settingsAppearanceDark",
    "settingsAppearanceCodeWalkClassic", "settingsAppearanceOpenCodePresets",
    "settingsAppearancePresetPalette", "settingsAppearancePresetHelper",
    "settingsAppearanceSearchPreset", "settingsAppearanceNoPresets",
    "settingsAppearanceVisualStyle", "settingsAppearanceVisualStyleDescription",
    "settingsAppearanceVisualStyleClassic", "settingsAppearanceVisualStyleRefined",
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
}
for name in (
    "NewConversation", "RefreshData", "FocusInput", "ToggleVoiceInput",
    "QuickOpenFiles", "OpenSettings", "NextRecentModel", "NextVariant",
    "FocusCloseDrawer", "NextAgent", "PreviousAgent", "NextTab",
    "PreviousTab", "CloseApp", "QuitApp",
):
    SETTINGS_KEYS |= {f"shortcut{name}", f"shortcut{name}Desc"}
SETTINGS_NEW_KEYS = (
    "shortcutsUnassigned", "shortcutsUnassign", "shortcutsUnavailable",
    "settingsStorageError", "settingsSearchClear",
)
SETTINGS_COPY = {
    "ar": ("غير معيّن", "إلغاء التعيين", "هذا الإجراء غير متاح في هذا الإصدار.", "تعذر تحميل الإعدادات أو حفظها. أعد المحاولة؛ قد تكون التغييرات مؤقتة.", "مسح البحث"),
    "bn": ("নির্ধারিত নয়", "নির্ধারণ সরান", "এই সংস্করণে কাজটি উপলব্ধ নয়।", "সেটিংস লোড বা সংরক্ষণ করা যায়নি। আবার চেষ্টা করুন; পরিবর্তন অস্থায়ী হতে পারে।", "অনুসন্ধান মুছুন"),
    "de": ("Nicht zugewiesen", "Zuweisung entfernen", "Diese Aktion ist in dieser Version nicht verfügbar.", "Einstellungen konnten nicht geladen oder gespeichert werden. Erneut versuchen; Änderungen können vorübergehend sein.", "Suche löschen"),
    "en": ("Unassigned", "Unassign", "This action is unavailable in this version.", "Settings could not be loaded or saved. Retry; changes may be temporary.", "Clear search"),
    "es": ("Sin asignar", "Quitar asignación", "Esta acción no está disponible en esta versión.", "No se pudieron cargar o guardar los ajustes. Reintenta; los cambios pueden ser temporales.", "Borrar búsqueda"),
    "fr": ("Non attribué", "Retirer l’attribution", "Cette action n’est pas disponible dans cette version.", "Impossible de charger ou d’enregistrer les réglages. Réessayez ; les modifications peuvent être temporaires.", "Effacer la recherche"),
    "hi": ("असाइन नहीं किया गया", "असाइनमेंट हटाएँ", "यह कार्रवाई इस संस्करण में उपलब्ध नहीं है।", "सेटिंग लोड या सहेजी नहीं जा सकीं। दोबारा कोशिश करें; बदलाव अस्थायी हो सकते हैं।", "खोज साफ़ करें"),
    "it": ("Non assegnato", "Rimuovi assegnazione", "Questa azione non è disponibile in questa versione.", "Impossibile caricare o salvare le impostazioni. Riprova; le modifiche possono essere temporanee.", "Cancella ricerca"),
    "ja": ("未割り当て", "割り当てを解除", "この操作はこのバージョンでは利用できません。", "設定を読み込むか保存できませんでした。再試行してください。変更は一時的な場合があります。", "検索をクリア"),
    "ko": ("할당되지 않음", "할당 해제", "이 버전에서는 이 작업을 사용할 수 없습니다.", "설정을 불러오거나 저장하지 못했습니다. 다시 시도하세요. 변경 사항은 임시일 수 있습니다.", "검색 지우기"),
    "pt": ("Não atribuído", "Desatribuir", "Esta ação não está disponível nesta versão.", "Não foi possível carregar ou salvar as configurações. Tente novamente; as alterações podem ser temporárias.", "Limpar busca"),
    "ru": ("Не назначено", "Снять назначение", "Это действие недоступно в этой версии.", "Не удалось загрузить или сохранить настройки. Повторите попытку; изменения могут быть временными.", "Очистить поиск"),
    "ur": ("تفویض نہیں کیا گیا", "تفویض ہٹائیں", "یہ عمل اس ورژن میں دستیاب نہیں ہے۔", "ترتیبات لوڈ یا محفوظ نہیں ہو سکیں۔ دوبارہ کوشش کریں؛ تبدیلیاں عارضی ہو سکتی ہیں۔", "تلاش صاف کریں"),
    "zh": ("未分配", "取消分配", "此版本不支持此操作。", "无法加载或保存设置。请重试；更改可能是临时的。", "清除搜索"),
}
KEYS |= SETTINGS_KEYS | set(SETTINGS_NEW_KEYS)
STORAGE_ERRORS = {
    "ar": "تعذر تحميل إعدادات المظهر أو حفظها. تظل التغييرات مؤقتة حتى تنجح إعادة المحاولة.",
    "bn": "চেহারার সেটিংস লোড বা সংরক্ষণ করা যায়নি। আবার চেষ্টা সফল না হওয়া পর্যন্ত পরিবর্তন অস্থায়ী থাকবে।",
    "de": "Darstellungseinstellungen konnten nicht geladen oder gespeichert werden. Änderungen bleiben bis zum erfolgreichen Wiederholen vorübergehend.",
    "en": "Appearance settings could not be loaded or saved. Changes remain temporary until retry succeeds.",
    "es": "No se pudo cargar o guardar la configuración de apariencia. Los cambios son temporales hasta que el reintento tenga éxito.",
    "fr": "Les réglages d’apparence n’ont pas pu être chargés ou enregistrés. Les modifications restent temporaires jusqu’à une nouvelle tentative réussie.",
    "hi": "दिखावट की सेटिंग लोड या सहेजी नहीं जा सकीं। दोबारा कोशिश सफल होने तक बदलाव अस्थायी रहेंगे।",
    "it": "Impossibile caricare o salvare le impostazioni dell’aspetto. Le modifiche restano temporanee finché il nuovo tentativo non riesce.",
    "ja": "外観設定を読み込むか保存できませんでした。再試行が成功するまで変更は一時的なものになります。",
    "ko": "모양 설정을 불러오거나 저장하지 못했습니다. 다시 시도에 성공할 때까지 변경 사항은 임시로 유지됩니다.",
    "pt": "Não foi possível carregar ou salvar as configurações de aparência. As alterações ficam temporárias até a nova tentativa funcionar.",
    "ru": "Не удалось загрузить или сохранить настройки внешнего вида. Изменения остаются временными до успешной повторной попытки.",
    "ur": "ظاہری شکل کی ترتیبات لوڈ یا محفوظ نہیں ہو سکیں۔ دوبارہ کوشش کامیاب ہونے تک تبدیلیاں عارضی رہیں گی۔",
    "zh": "无法加载或保存外观设置。重试成功之前，更改仅为临时更改。",
}


def port_appearance_copy() -> None:
    """Extend only the bounded v2 catalog from consolidated translations."""
    for locale in LOCALES:
        path = SOURCE / "arb" / f"app_{locale}.arb"
        arb = json.loads(path.read_text(encoding="utf-8"))
        legacy = json.loads((ROOT / "lib/l10n" / f"app_{locale}.arb").read_text(encoding="utf-8"))
        for key in sorted(APPEARANCE_KEYS):
            arb[key] = legacy[key]
            if "@" + key in legacy:
                arb["@" + key] = legacy["@" + key]
        arb["appearanceStorageError"] = STORAGE_ERRORS[locale]
        arb["@appearanceStorageError"] = {"description": "Appearance persistence failure; settings may be temporary"}
        path.write_text(json.dumps(arb, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def port_settings_copy() -> None:
    """Validate the entire selective port before writing its scoped catalogs."""
    ports = []
    for locale in LOCALES:
        path = SOURCE / "arb" / f"app_{locale}.arb"
        arb = json.loads(path.read_text(encoding="utf-8"))
        legacy = json.loads((ROOT / "lib/l10n" / f"app_{locale}.arb").read_text(encoding="utf-8"))
        missing = SETTINGS_KEYS - legacy.keys()
        if missing:
            raise ValueError(f"Missing settings source keys in {locale}: {sorted(missing)}")
        for key in sorted(SETTINGS_KEYS):
            arb[key] = legacy[key]
            if "@" + key in legacy:
                arb["@" + key] = legacy["@" + key]
        for key, value in zip(SETTINGS_NEW_KEYS, SETTINGS_COPY[locale], strict=True):
            arb[key] = value
            arb["@" + key] = {"description": "V2 local settings and shortcut UI"}
        ports.append((path, arb))
    for path, arb in ports:
        path.write_text(json.dumps(arb, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


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
    parser.add_argument("--port-appearance", action="store_true", help="Selectively import consolidated appearance translations into v2 sources.")
    parser.add_argument("--port-settings", action="store_true", help="Selectively import consolidated settings and shortcut translations into v2 sources.")
    args = parser.parse_args()
    try:
        if args.port_appearance:
            if args.check:
                raise ValueError("--port-appearance cannot be combined with --check")
            port_appearance_copy()
        if args.port_settings:
            if args.check:
                raise ValueError("--port-settings cannot be combined with --check")
            port_settings_copy()
        return generate(args.check)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"V2 localization generation failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
