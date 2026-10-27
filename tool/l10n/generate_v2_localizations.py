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

from hosts_catalog import PORT_KEYS as HOST_KEYS, NEW_KEYS as HOST_NEW_KEYS, COPY as HOST_COPY
from pairing_catalog import KEYS as PAIRING_KEYS, COPY as PAIRING_COPY
from diagnostics_catalog import PORT_KEYS as DIAGNOSTICS_KEYS, NEW_KEYS as DIAGNOSTICS_NEW_KEYS, COPY as DIAGNOSTICS_COPY
from sessions_catalog import PORT_KEYS as SESSION_KEYS, NEW_KEYS as SESSION_NEW_KEYS, COPY as SESSION_COPY
from session_history_catalog import PORT_KEYS as HISTORY_KEYS, NEW_KEYS as HISTORY_NEW_KEYS, COPY as HISTORY_COPY
from session_live_catalog import (
    PORT_KEYS as LIVE_PORT_KEYS,
    NEW_KEYS as LIVE_NEW_KEYS,
    COPY as LIVE_COPY,
)
from session_composer_catalog import NEW_KEYS as COMPOSER_NEW_KEYS, COPY as COMPOSER_COPY
from session_permission_catalog import NEW_KEYS as PERMISSION_NEW_KEYS, COPY as PERMISSION_COPY
from session_stop_catalog import NEW_KEYS as STOP_NEW_KEYS, COPY as STOP_COPY
from session_form_catalog import NEW_KEYS as FORM_NEW_KEYS, COPY as FORM_COPY
from session_selection_catalog import NEW_KEYS as SELECTION_NEW_KEYS, COPY as SELECTION_COPY
from session_error_catalog import NEW_KEYS as ERROR_NEW_KEYS, COPY as ERROR_COPY
from updates_catalog import PORT_KEYS as UPDATES_KEYS, NEW_KEYS as UPDATES_NEW_KEYS, COPY as UPDATES_COPY
from rendering_catalog import (
    PORT_KEYS as RENDERING_KEYS,
    NEW_KEYS as RENDERING_NEW_KEYS,
    COPY as RENDERING_COPY,
)
from workspace_catalog import (
    PORT_KEYS as WORKSPACE_KEYS,
    NEW_KEYS as WORKSPACE_NEW_KEYS,
    COPY as WORKSPACE_COPY,
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
    "settingsAppearanceMathRendering", "settingsAppearanceMathRenderingDescription",
    "settingsAppearanceFontSize", "settingsAppearanceSystemFontScale",
    "settingsAppearanceSystemFontScaleDescription", "settingsAppearanceChatFontScale",
    "settingsAppearanceChatFontScaleDescription",
    "settingsAppearanceThinkingBubbles",
    "settingsAppearanceThinkingBubblesDescription",
    "settingsAppearanceToolCallBubbles",
    "settingsAppearanceToolCallBubblesDescription",
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
KEYS |= HOST_KEYS | set(HOST_NEW_KEYS)
KEYS |= set(PAIRING_KEYS)
KEYS |= DIAGNOSTICS_KEYS | set(DIAGNOSTICS_NEW_KEYS)
KEYS |= SESSION_KEYS | set(SESSION_NEW_KEYS)
KEYS |= HISTORY_KEYS | set(HISTORY_NEW_KEYS)
KEYS |= LIVE_PORT_KEYS | set(LIVE_NEW_KEYS)
KEYS |= set(COMPOSER_NEW_KEYS)
KEYS |= set(PERMISSION_NEW_KEYS)
KEYS |= set(STOP_NEW_KEYS)
KEYS |= set(FORM_NEW_KEYS)
KEYS |= set(SELECTION_NEW_KEYS)
KEYS |= set(ERROR_NEW_KEYS)
KEYS |= UPDATES_KEYS | set(UPDATES_NEW_KEYS)
KEYS |= RENDERING_KEYS | set(RENDERING_NEW_KEYS)
KEYS |= WORKSPACE_KEYS | set(WORKSPACE_NEW_KEYS)
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


def port_hosts_copy() -> None:
    ports = []
    for locale in LOCALES:
        path = SOURCE / "arb" / f"app_{locale}.arb"
        arb = json.loads(path.read_text(encoding="utf-8"))
        legacy = json.loads((ROOT / "lib/l10n" / f"app_{locale}.arb").read_text(encoding="utf-8"))
        for key in sorted(HOST_KEYS):
            arb[key] = legacy[key]
            if "@" + key in legacy:
                arb["@" + key] = legacy["@" + key]
        for key, value in zip(HOST_NEW_KEYS, HOST_COPY[locale], strict=True):
            arb[key] = value
            arb["@" + key] = {"description": "V2 endpoint profile and compatibility UI"}
        ports.append((path, arb))
    for path, arb in ports:
        path.write_text(json.dumps(arb, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def port_diagnostics_copy() -> None:
    ports = []
    for locale in LOCALES:
        path = SOURCE / "arb" / f"app_{locale}.arb"
        arb = json.loads(path.read_text(encoding="utf-8"))
        legacy = json.loads((ROOT / "lib/l10n" / f"app_{locale}.arb").read_text(encoding="utf-8"))
        missing = DIAGNOSTICS_KEYS - legacy.keys()
        if missing:
            raise ValueError(f"Missing diagnostics source keys in {locale}: {sorted(missing)}")
        for key in sorted(DIAGNOSTICS_KEYS):
            arb[key] = legacy[key]
            if "@" + key in legacy:
                arb["@" + key] = legacy["@" + key]
        for key, value in zip(DIAGNOSTICS_NEW_KEYS, DIAGNOSTICS_COPY[locale], strict=True):
            arb[key] = value
            arb["@" + key] = {"description": "V2 finite diagnostics and archive UI"}
        ports.append((path, arb))
    for path, arb in ports:
        path.write_text(json.dumps(arb, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def port_sessions_copy() -> None:
    ports = []
    for locale in LOCALES:
        path = SOURCE / "arb" / f"app_{locale}.arb"
        arb = json.loads(path.read_text(encoding="utf-8"))
        legacy = json.loads((ROOT / "lib/l10n" / f"app_{locale}.arb").read_text(encoding="utf-8"))
        for key in sorted(SESSION_KEYS):
            arb[key] = legacy[key]
            if "@" + key in legacy:
                arb["@" + key] = legacy["@" + key]
        for key, value in zip(SESSION_NEW_KEYS, SESSION_COPY[locale], strict=True):
            arb[key] = value
            arb["@" + key] = {"description": "V2 bounded read-only session catalog"}
        ports.append((path, arb))
    for path, arb in ports:
        path.write_text(json.dumps(arb, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def port_pairing_copy() -> None:
    for locale in LOCALES:
        path = SOURCE / "arb" / f"app_{locale}.arb"
        arb = json.loads(path.read_text(encoding="utf-8"))
        for key, value in zip(PAIRING_KEYS, PAIRING_COPY[locale], strict=True):
            arb[key] = value
            arb["@" + key] = {"description": "V2 pairing and credential lifecycle"}
        path.write_text(json.dumps(arb, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def port_history_copy() -> None:
    ports = []
    for locale in LOCALES:
        path = SOURCE / "arb" / f"app_{locale}.arb"
        arb = json.loads(path.read_text(encoding="utf-8"))
        legacy = json.loads((ROOT / "lib/l10n" / f"app_{locale}.arb").read_text(encoding="utf-8"))
        for key in sorted(HISTORY_KEYS):
            arb[key] = legacy[key]
            if "@" + key in legacy:
                arb["@" + key] = legacy["@" + key]
        for key, value in zip(HISTORY_NEW_KEYS, HISTORY_COPY[locale], strict=True):
            arb[key] = value
            arb["@" + key] = {"description": "V2 auxiliary read-only history preview"}
        ports.append((path, arb))
    for path, arb in ports:
        path.write_text(json.dumps(arb, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def port_live_copy() -> None:
    ports = []
    for locale in LOCALES:
        path = SOURCE / "arb" / f"app_{locale}.arb"
        arb = json.loads(path.read_text(encoding="utf-8"))
        legacy = json.loads(
            (ROOT / "lib/l10n" / f"app_{locale}.arb").read_text(encoding="utf-8")
        )
        for key in sorted(LIVE_PORT_KEYS):
            arb[key] = legacy[key]
            if "@" + key in legacy:
                arb["@" + key] = legacy["@" + key]
        for key, value in zip(LIVE_NEW_KEYS, LIVE_COPY[locale], strict=True):
            arb[key] = value
            arb["@" + key] = {"description": "V2 live read-only session view"}
        ports.append((path, arb))
    for path, arb in ports:
        path.write_text(json.dumps(arb, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def port_composer_copy() -> None:
    ports = []
    for locale in LOCALES:
        path = SOURCE / "arb" / f"app_{locale}.arb"
        arb = json.loads(path.read_text(encoding="utf-8"))
        for key, value in zip(COMPOSER_NEW_KEYS, COMPOSER_COPY[locale], strict=True):
            arb[key] = value
            arb["@" + key] = {"description": "V2 live session composer"}
        ports.append((path, arb))
    for path, arb in ports:
        path.write_text(json.dumps(arb, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def port_permission_copy() -> None:
    ports = []
    for locale in LOCALES:
        path = SOURCE / "arb" / f"app_{locale}.arb"
        arb = json.loads(path.read_text(encoding="utf-8"))
        for key, value in zip(PERMISSION_NEW_KEYS, PERMISSION_COPY[locale], strict=True):
            arb[key] = value
            arb["@" + key] = {"description": "V2 manual permission cards"}
        ports.append((path, arb))
    for path, arb in ports:
        path.write_text(json.dumps(arb, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def port_stop_copy() -> None:
    ports = []
    for locale in LOCALES:
        path = SOURCE / "arb" / f"app_{locale}.arb"
        arb = json.loads(path.read_text(encoding="utf-8"))
        for key, value in zip(STOP_NEW_KEYS, STOP_COPY[locale], strict=True):
            arb[key] = value
            arb["@" + key] = {"description": "V2 explicit execution stop control"}
        ports.append((path, arb))
    for path, arb in ports:
        path.write_text(json.dumps(arb, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def port_form_copy() -> None:
    ports = []
    for locale in LOCALES:
        path = SOURCE / "arb" / f"app_{locale}.arb"
        arb = json.loads(path.read_text(encoding="utf-8"))
        for key, value in zip(FORM_NEW_KEYS, FORM_COPY[locale], strict=True):
            arb[key] = value
            arb["@" + key] = {"description": "V2 interactive form cards"}
        ports.append((path, arb))
    for path, arb in ports:
        path.write_text(json.dumps(arb, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def port_selection_copy() -> None:
    ports = []
    for locale in LOCALES:
        path = SOURCE / "arb" / f"app_{locale}.arb"
        arb = json.loads(path.read_text(encoding="utf-8"))
        for key, value in zip(SELECTION_NEW_KEYS, SELECTION_COPY[locale], strict=True):
            arb[key] = value
            arb["@" + key] = {"description": "V2 live session model and agent selection"}
        ports.append((path, arb))
    for path, arb in ports:
        path.write_text(json.dumps(arb, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def port_error_copy() -> None:
    ports = []
    for locale in LOCALES:
        path = SOURCE / "arb" / f"app_{locale}.arb"
        arb = json.loads(path.read_text(encoding="utf-8"))
        for key, value in zip(ERROR_NEW_KEYS, ERROR_COPY[locale], strict=True):
            arb[key] = value
            arb["@" + key] = {"description": "V2 typed error cards"}
        ports.append((path, arb))
    for path, arb in ports:
        path.write_text(json.dumps(arb, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def port_updates_copy() -> None:
    ports = []
    for locale in LOCALES:
        path = SOURCE / "arb" / f"app_{locale}.arb"
        arb = json.loads(path.read_text(encoding="utf-8"))
        legacy = json.loads((ROOT / "lib/l10n" / f"app_{locale}.arb").read_text(encoding="utf-8"))
        for key in sorted(UPDATES_KEYS):
            arb[key] = legacy[key]
            if "@" + key in legacy:
                arb["@" + key] = legacy["@" + key]
        for key, value in zip(UPDATES_NEW_KEYS, UPDATES_COPY[locale], strict=True):
            arb[key] = value
            arb["@" + key] = {"description": "V2 update check"}
        ports.append((path, arb))
    for path, arb in ports:
        path.write_text(json.dumps(arb, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def port_rendering_copy() -> None:
    ports = []
    for locale in LOCALES:
        path = SOURCE / "arb" / f"app_{locale}.arb"
        arb = json.loads(path.read_text(encoding="utf-8"))
        legacy = json.loads(
            (ROOT / "lib/l10n" / f"app_{locale}.arb").read_text(encoding="utf-8")
        )
        for key in sorted(RENDERING_KEYS):
            arb[key] = legacy[key]
            if "@" + key in legacy:
                arb["@" + key] = legacy["@" + key]
        for key, value in zip(
            RENDERING_NEW_KEYS, RENDERING_COPY.get(locale, ()), strict=True
        ):
            arb[key] = value
            arb["@" + key] = {"description": "V2 canonical rich rendering"}
        ports.append((path, arb))
    for path, arb in ports:
        path.write_text(json.dumps(arb, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def port_workspace_copy() -> None:
    ports = []
    for locale in LOCALES:
        path = SOURCE / "arb" / f"app_{locale}.arb"
        arb = json.loads(path.read_text(encoding="utf-8"))
        legacy = json.loads((ROOT / "lib/l10n" / f"app_{locale}.arb").read_text(encoding="utf-8"))
        for key in sorted(WORKSPACE_KEYS):
            arb[key] = legacy[key]
            if "@" + key in legacy:
                arb["@" + key] = legacy["@" + key]
        for key, value in zip(WORKSPACE_NEW_KEYS, WORKSPACE_COPY[locale], strict=True):
            arb[key] = value
            arb["@" + key] = {"description": "V2 chat-first workspace"}
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
    parser.add_argument("--port-hosts", action="store_true", help="Selectively import endpoint copy into v2 sources.")
    parser.add_argument("--port-pairing", action="store_true", help="Add scoped pairing copy only.")
    parser.add_argument("--port-diagnostics", action="store_true", help="Add scoped diagnostics and archive copy only.")
    parser.add_argument("--port-sessions", action="store_true", help="Add scoped read-only session catalog copy only.")
    parser.add_argument("--port-history", action="store_true", help="Add scoped read-only history copy only.")
    parser.add_argument("--port-live", action="store_true", help="Add scoped live read-only session copy only.")
    parser.add_argument("--port-composer", action="store_true", help="Add scoped live composer copy only.")
    parser.add_argument("--port-permission", action="store_true", help="Add scoped manual permission card copy only.")
    parser.add_argument("--port-stop", action="store_true", help="Add scoped execution stop copy only.")
    parser.add_argument("--port-form", action="store_true", help="Add scoped interactive form card copy only.")
    parser.add_argument("--port-selection", action="store_true", help="Add scoped live model and agent selection copy only.")
    parser.add_argument("--port-error", action="store_true", help="Add scoped typed error card copy only.")
    parser.add_argument("--port-rendering", action="store_true", help="Add scoped canonical rich rendering copy only.")
    parser.add_argument("--port-updates", action="store_true", help="Add scoped update check copy only.")
    parser.add_argument("--port-workspace", action="store_true", help="Add scoped chat-first workspace copy only.")
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
        if args.port_hosts:
            if args.check:
                raise ValueError("--port-hosts cannot be combined with --check")
            port_hosts_copy()
        if args.port_pairing:
            if args.check:
                raise ValueError("--port-pairing cannot be combined with --check")
            port_pairing_copy()
        if args.port_diagnostics:
            if args.check:
                raise ValueError("--port-diagnostics cannot be combined with --check")
            port_diagnostics_copy()
        if args.port_sessions:
            if args.check:
                raise ValueError("--port-sessions cannot be combined with --check")
            port_sessions_copy()
        if args.port_history:
            if args.check:
                raise ValueError("--port-history cannot be combined with --check")
            port_history_copy()
        if args.port_live:
            if args.check:
                raise ValueError("--port-live cannot be combined with --check")
            port_live_copy()
        if args.port_composer:
            if args.check:
                raise ValueError("--port-composer cannot be combined with --check")
            port_composer_copy()
        if args.port_permission:
            if args.check:
                raise ValueError("--port-permission cannot be combined with --check")
            port_permission_copy()
        if args.port_stop:
            if args.check:
                raise ValueError("--port-stop cannot be combined with --check")
            port_stop_copy()
        if args.port_form:
            if args.check:
                raise ValueError("--port-form cannot be combined with --check")
            port_form_copy()
        if args.port_selection:
            if args.check:
                raise ValueError("--port-selection cannot be combined with --check")
            port_selection_copy()
        if args.port_error:
            if args.check:
                raise ValueError("--port-error cannot be combined with --check")
            port_error_copy()
        if args.port_updates:
            if args.check:
                raise ValueError("--port-updates cannot be combined with --check")
            port_updates_copy()
        if args.port_rendering:
            if args.check:
                raise ValueError("--port-rendering cannot be combined with --check")
            port_rendering_copy()
        if args.port_workspace:
            if args.check:
                raise ValueError("--port-workspace cannot be combined with --check")
            port_workspace_copy()
        return generate(args.check)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"V2 localization generation failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
