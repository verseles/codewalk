"""Bounded v2 diagnostics/archive copy; no retained catalog writes."""

PORT_KEYS = {
    "logsAppLogs", "logsClear", "logsCopyFiltered", "logsEnableLogging",
    "logsEnableLoggingDescription", "logsLoggingDisabledTitle",
    "logsLoggingDisabledDescription", "logsNoLogsYet", "logsNoMatchingLogs",
    "logsFilterAll", "logsLevel", "logsPerformanceDuration", "logsTaskStatusOk", "logsTaskStatusError",
    "logsTaskStatusCanceled", "releaseHistoryTitle", "releaseHistoryDescription",
    "releaseHistoryLoadError", "releaseHistoryStale", "settingsGroupHelp",
    "commonCopiedToClipboard", "chatRefresh", "chatLoadMore",
}
NEW_KEYS = (
    "diagnosticsHostCatalog", "diagnosticsHostProbe", "diagnosticsProfileSave",
    "diagnosticsProfileRemove", "diagnosticsPreferencesLoad",
    "diagnosticsPreferencesSave", "diagnosticsArchiveLoad", "diagnosticsArchiveSave",
    "diagnosticsInfo", "diagnosticsWarning", "diagnosticsError",
    "diagnosticsCopyFailed", "diagnosticsCopyTruncated", "diagnosticsPrivacy",
)
COPY = {
    "en": ("Load host catalog", "Check host", "Save profile", "Remove profile", "Load preferences", "Save preferences", "Load release history", "Save release history", "Information", "Warning", "Error", "Unable to copy logs.", "Logs copied; the copy was limited to 64 KiB.", "Memory only: operation, outcome, severity, UTC time and bounded duration. No content, credentials or addresses are collected."),
    "pt": ("Carregar catálogo de servidores", "Verificar servidor", "Salvar perfil", "Remover perfil", "Carregar preferências", "Salvar preferências", "Carregar histórico de versões", "Salvar histórico de versões", "Informação", "Aviso", "Erro", "Não foi possível copiar os logs.", "Logs copiados; a cópia foi limitada a 64 KiB.", "Somente em memória: operação, resultado, nível, horário UTC e duração limitada. Conteúdo, credenciais e endereços não são coletados."),
    "es": ("Cargar catálogo de servidores", "Comprobar servidor", "Guardar perfil", "Eliminar perfil", "Cargar preferencias", "Guardar preferencias", "Cargar historial de versiones", "Guardar historial de versiones", "Información", "Advertencia", "Error", "No se pudieron copiar los registros.", "Registros copiados; la copia se limitó a 64 KiB.", "Solo en memoria: operación, resultado, nivel, hora UTC y duración limitada. No se recopilan contenido, credenciales ni direcciones."),
    "fr": ("Charger le catalogue des serveurs", "Vérifier le serveur", "Enregistrer le profil", "Supprimer le profil", "Charger les préférences", "Enregistrer les préférences", "Charger l’historique des versions", "Enregistrer l’historique des versions", "Information", "Avertissement", "Erreur", "Impossible de copier les journaux.", "Journaux copiés ; la copie est limitée à 64 KiB.", "En mémoire uniquement : opération, résultat, niveau, heure UTC et durée limitée. Aucun contenu, identifiant secret ou adresse n’est collecté."),
    "de": ("Serverkatalog laden", "Server prüfen", "Profil speichern", "Profil entfernen", "Einstellungen laden", "Einstellungen speichern", "Versionsverlauf laden", "Versionsverlauf speichern", "Information", "Warnung", "Fehler", "Protokolle konnten nicht kopiert werden.", "Protokolle kopiert; die Kopie wurde auf 64 KiB begrenzt.", "Nur im Speicher: Vorgang, Ergebnis, Stufe, UTC-Zeit und begrenzte Dauer. Keine Inhalte, Zugangsdaten oder Adressen werden erfasst."),
    "it": ("Carica catalogo server", "Verifica server", "Salva profilo", "Rimuovi profilo", "Carica preferenze", "Salva preferenze", "Carica cronologia versioni", "Salva cronologia versioni", "Informazione", "Avviso", "Errore", "Impossibile copiare i registri.", "Registri copiati; la copia è limitata a 64 KiB.", "Solo in memoria: operazione, esito, livello, ora UTC e durata limitata. Non vengono raccolti contenuti, credenziali o indirizzi."),
    "ru": ("Загрузка списка серверов", "Проверка сервера", "Сохранение профиля", "Удаление профиля", "Загрузка настроек", "Сохранение настроек", "Загрузка истории версий", "Сохранение истории версий", "Информация", "Предупреждение", "Ошибка", "Не удалось скопировать журналы.", "Журналы скопированы; копия ограничена 64 KiB.", "Только в памяти: операция, результат, уровень, время UTC и ограниченная длительность. Содержимое, учётные данные и адреса не собираются."),
    "ar": ("تحميل قائمة الخوادم", "فحص الخادم", "حفظ الملف", "إزالة الملف", "تحميل التفضيلات", "حفظ التفضيلات", "تحميل سجل الإصدارات", "حفظ سجل الإصدارات", "معلومات", "تحذير", "خطأ", "تعذر نسخ السجلات.", "تم نسخ السجلات؛ اقتصر النسخ على 64 KiB.", "في الذاكرة فقط: العملية والنتيجة والمستوى ووقت UTC ومدة محدودة. لا يُجمع المحتوى أو بيانات الاعتماد أو العناوين."),
    "ur": ("سرور فہرست لوڈ کریں", "سرور کی جانچ", "پروفائل محفوظ کریں", "پروفائل ہٹائیں", "ترجیحات لوڈ کریں", "ترجیحات محفوظ کریں", "ورژن کی تاریخ لوڈ کریں", "ورژن کی تاریخ محفوظ کریں", "معلومات", "انتباہ", "خرابی", "لاگز کاپی نہیں ہو سکے۔", "لاگز کاپی ہو گئے؛ کاپی 64 KiB تک محدود ہے۔", "صرف میموری میں: عمل، نتیجہ، سطح، UTC وقت اور محدود دورانیہ۔ مواد، اسناد یا پتے جمع نہیں کیے جاتے۔"),
    "bn": ("সার্ভার তালিকা লোড", "সার্ভার পরীক্ষা", "প্রোফাইল সংরক্ষণ", "প্রোফাইল সরান", "পছন্দ লোড", "পছন্দ সংরক্ষণ", "সংস্করণের ইতিহাস লোড", "সংস্করণের ইতিহাস সংরক্ষণ", "তথ্য", "সতর্কতা", "ত্রুটি", "লগ কপি করা যায়নি।", "লগ কপি হয়েছে; কপি 64 KiB-তে সীমিত।", "শুধু মেমরিতে: কাজ, ফলাফল, স্তর, UTC সময় ও সীমিত সময়কাল। বিষয়বস্তু, পরিচয়পত্র বা ঠিকানা সংগ্রহ করা হয় না।"),
    "hi": ("सर्वर सूची लोड करें", "सर्वर जाँचें", "प्रोफ़ाइल सहेजें", "प्रोफ़ाइल हटाएँ", "प्राथमिकताएँ लोड करें", "प्राथमिकताएँ सहेजें", "संस्करण इतिहास लोड करें", "संस्करण इतिहास सहेजें", "जानकारी", "चेतावनी", "त्रुटि", "लॉग कॉपी नहीं हो सके।", "लॉग कॉपी हुए; कॉपी 64 KiB तक सीमित है।", "केवल मेमोरी में: कार्य, परिणाम, स्तर, UTC समय और सीमित अवधि। सामग्री, क्रेडेंशियल या पते एकत्र नहीं किए जाते।"),
    "ja": ("サーバー一覧を読み込む", "サーバーを確認", "プロファイルを保存", "プロファイルを削除", "設定を読み込む", "設定を保存", "バージョン履歴を読み込む", "バージョン履歴を保存", "情報", "警告", "エラー", "ログをコピーできませんでした。", "ログをコピーしました。コピーは64 KiBに制限されました。", "メモリのみ：操作、結果、レベル、UTC時刻、制限付き所要時間。内容、認証情報、アドレスは収集しません。"),
    "ko": ("서버 목록 불러오기", "서버 확인", "프로필 저장", "프로필 삭제", "환경설정 불러오기", "환경설정 저장", "버전 기록 불러오기", "버전 기록 저장", "정보", "경고", "오류", "로그를 복사할 수 없습니다.", "로그를 복사했습니다. 복사는 64 KiB로 제한되었습니다.", "메모리에만 저장: 작업, 결과, 수준, UTC 시간과 제한된 소요 시간. 콘텐츠, 인증 정보 또는 주소는 수집하지 않습니다."),
    "zh": ("加载服务器列表", "检查服务器", "保存配置", "删除配置", "加载偏好设置", "保存偏好设置", "加载版本历史", "保存版本历史", "信息", "警告", "错误", "无法复制日志。", "日志已复制；副本限制为64 KiB。", "仅保存在内存中：操作、结果、级别、UTC时间和有限时长。不收集内容、凭据或地址。"),
}
