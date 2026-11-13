"""Search in the open conversation (#462)."""

NEW_KEYS = (
    "liveSearch", "liveSearchCount", "liveSearchNone", "liveSearchOlder",
    "liveSearchNewer", "liveSearchClose",
)
COPY = {
    "en": ("Search conversation", "{current} of {total}", "No results", "Older match", "Newer match", "Close search"),
    "pt": ("Buscar na conversa", "{current} de {total}", "Nenhum resultado", "Resultado mais antigo", "Resultado mais recente", "Fechar busca"),
    "es": ("Buscar en la conversación", "{current} de {total}", "Sin resultados", "Coincidencia más antigua", "Coincidencia más reciente", "Cerrar búsqueda"),
    "fr": ("Rechercher dans la conversation", "{current} sur {total}", "Aucun résultat", "Résultat plus ancien", "Résultat plus récent", "Fermer la recherche"),
    "de": ("Im Gespräch suchen", "{current} von {total}", "Keine Treffer", "Älterer Treffer", "Neuerer Treffer", "Suche schließen"),
    "it": ("Cerca nella conversazione", "{current} di {total}", "Nessun risultato", "Risultato più vecchio", "Risultato più recente", "Chiudi ricerca"),
    "ru": ("Поиск в разговоре", "{current} из {total}", "Нет результатов", "Более раннее совпадение", "Более позднее совпадение", "Закрыть поиск"),
    "ja": ("会話内を検索", "{current} / {total}", "結果なし", "古い一致", "新しい一致", "検索を閉じる"),
    "ko": ("대화에서 검색", "{current}/{total}", "결과 없음", "이전 일치 항목", "최근 일치 항목", "검색 닫기"),
    "zh": ("在对话中搜索", "第 {current} 个，共 {total} 个", "无结果", "较早的匹配", "较新的匹配", "关闭搜索"),
    "hi": ("बातचीत में खोजें", "{total} में से {current}", "कोई परिणाम नहीं", "पुराना मिलान", "नया मिलान", "खोज बंद करें"),
    "bn": ("কথোপকথনে খুঁজুন", "{total}টির মধ্যে {current}", "কোনো ফলাফল নেই", "পুরোনো মিল", "নতুন মিল", "খোঁজা বন্ধ করুন"),
    "ar": ("البحث في المحادثة", "{current} من {total}", "لا نتائج", "تطابق أقدم", "تطابق أحدث", "إغلاق البحث"),
    "ur": ("گفتگو میں تلاش کریں", "{total} میں سے {current}", "کوئی نتیجہ نہیں", "پرانا مماثل", "نیا مماثل", "تلاش بند کریں"),
}
SHORTCUT = {
    "en": ("Search conversation", "Find text in the open conversation; F3 and Shift+F3 move between matches"),
    "pt": ("Buscar na conversa", "Encontrar texto na conversa aberta; F3 e Shift+F3 navegam entre os resultados"),
    "es": ("Buscar en la conversación", "Busca texto en la conversación abierta; F3 y Mayús+F3 recorren las coincidencias"),
    "fr": ("Rechercher dans la conversation", "Trouver du texte dans la conversation ouverte ; F3 et Maj+F3 passent d'un résultat à l'autre"),
    "de": ("Im Gespräch suchen", "Text im geöffneten Gespräch finden; F3 und Umschalt+F3 springen zwischen Treffern"),
    "it": ("Cerca nella conversazione", "Trova testo nella conversazione aperta; F3 e Maiusc+F3 passano tra i risultati"),
    "ru": ("Поиск в разговоре", "Найти текст в открытом разговоре; F3 и Shift+F3 переходят между совпадениями"),
    "ja": ("会話内を検索", "開いている会話内のテキストを検索します。F3 と Shift+F3 で一致箇所を移動します"),
    "ko": ("대화에서 검색", "열린 대화에서 텍스트를 찾습니다. F3과 Shift+F3으로 일치 항목 사이를 이동합니다"),
    "zh": ("在对话中搜索", "在当前对话中查找文本；F3 和 Shift+F3 在匹配项之间切换"),
    "hi": ("बातचीत में खोजें", "खुली बातचीत में टेक्स्ट खोजें; F3 और Shift+F3 मिलानों के बीच ले जाते हैं"),
    "bn": ("কথোপকথনে খুঁজুন", "খোলা কথোপকথনে লেখা খুঁজুন; F3 ও Shift+F3 মিলগুলোর মধ্যে সরায়"),
    "ar": ("البحث في المحادثة", "ابحث عن نص في المحادثة المفتوحة؛ ينتقل F3 وShift+F3 بين التطابقات"),
    "ur": ("گفتگو میں تلاش کریں", "کھلی گفتگو میں متن تلاش کریں؛ F3 اور Shift+F3 مماثلتوں کے درمیان لے جاتے ہیں"),
}

# Model and agent switches in the conversation (#426).
SWITCH_KEYS = ("liveSwitchedModel", "liveSwitchedAgent")
SWITCH = {
    "en": ("Model switched to {name}", "Agent switched to {name}"),
    "pt": ("Modelo trocado para {name}", "Agente trocado para {name}"),
    "es": ("Modelo cambiado a {name}", "Agente cambiado a {name}"),
    "fr": ("Modèle changé pour {name}", "Agent changé pour {name}"),
    "de": ("Modell gewechselt zu {name}", "Agent gewechselt zu {name}"),
    "it": ("Modello cambiato in {name}", "Agente cambiato in {name}"),
    "ru": ("Модель изменена на {name}", "Агент изменён на {name}"),
    "ja": ("モデルを {name} に切り替えました", "エージェントを {name} に切り替えました"),
    "ko": ("모델을 {name}(으)로 전환함", "에이전트를 {name}(으)로 전환함"),
    "zh": ("模型已切换为 {name}", "智能体已切换为 {name}"),
    "hi": ("मॉडल {name} पर बदला गया", "एजेंट {name} पर बदला गया"),
    "bn": ("মডেল {name}-এ বদলানো হয়েছে", "এজেন্ট {name}-এ বদলানো হয়েছে"),
    "ar": ("تم تبديل النموذج إلى {name}", "تم تبديل الوكيل إلى {name}"),
    "ur": ("ماڈل {name} پر بدل دیا گیا", "ایجنٹ {name} پر بدل دیا گیا"),
}

# The composer's mic through the platform's speech recognizer (#307).
VOICE_KEYS = ('composerVoice', 'composerVoiceStop', 'composerVoiceUnavailable', 'composerVoiceDenied', 'composerVoiceFailed')
VOICE = {
    "en": ("Voice input", "Stop voice input", "Voice input isn’t available on this device", "Allow microphone access to use voice input", "Voice input stopped unexpectedly"),
    "pt": ("Entrada por voz", "Parar entrada por voz", "A entrada por voz não está disponível neste dispositivo", "Permita o acesso ao microfone para usar a entrada por voz", "A entrada por voz parou inesperadamente"),
    "es": ("Entrada de voz", "Detener entrada de voz", "La entrada de voz no está disponible en este dispositivo", "Permite el acceso al micrófono para usar la entrada de voz", "La entrada de voz se detuvo inesperadamente"),
    "fr": ("Saisie vocale", "Arrêter la saisie vocale", "La saisie vocale n’est pas disponible sur cet appareil", "Autorisez l’accès au micro pour utiliser la saisie vocale", "La saisie vocale s’est arrêtée de façon inattendue"),
    "de": ("Spracheingabe", "Spracheingabe beenden", "Spracheingabe ist auf diesem Gerät nicht verfügbar", "Erlaube den Mikrofonzugriff, um die Spracheingabe zu nutzen", "Die Spracheingabe wurde unerwartet beendet"),
    "it": ("Input vocale", "Interrompi input vocale", "L’input vocale non è disponibile su questo dispositivo", "Consenti l’accesso al microfono per usare l’input vocale", "L’input vocale si è interrotto inaspettatamente"),
    "ru": ("Голосовой ввод", "Остановить голосовой ввод", "Голосовой ввод недоступен на этом устройстве", "Разрешите доступ к микрофону, чтобы использовать голосовой ввод", "Голосовой ввод неожиданно остановился"),
    "ja": ("音声入力", "音声入力を停止", "このデバイスでは音声入力を利用できません", "音声入力を使うにはマイクへのアクセスを許可してください", "音声入力が予期せず停止しました"),
    "ko": ("음성 입력", "음성 입력 중지", "이 기기에서는 음성 입력을 사용할 수 없습니다", "음성 입력을 사용하려면 마이크 접근을 허용하세요", "음성 입력이 예기치 않게 중지되었습니다"),
    "zh": ("语音输入", "停止语音输入", "此设备不支持语音输入", "请允许访问麦克风以使用语音输入", "语音输入意外停止"),
    "hi": ("वॉइस इनपुट", "वॉइस इनपुट रोकें", "इस डिवाइस पर वॉइस इनपुट उपलब्ध नहीं है", "वॉइस इनपुट के लिए माइक्रोफ़ोन की अनुमति दें", "वॉइस इनपुट अचानक रुक गया"),
    "bn": ("ভয়েস ইনপুট", "ভয়েস ইনপুট বন্ধ করুন", "এই ডিভাইসে ভয়েস ইনপুট উপলব্ধ নয়", "ভয়েস ইনপুট ব্যবহার করতে মাইক্রোফোনের অনুমতি দিন", "ভয়েস ইনপুট অপ্রত্যাশিতভাবে বন্ধ হয়েছে"),
    "ar": ("الإدخال الصوتي", "إيقاف الإدخال الصوتي", "الإدخال الصوتي غير متاح على هذا الجهاز", "اسمح بالوصول إلى الميكروفون لاستخدام الإدخال الصوتي", "توقف الإدخال الصوتي بشكل غير متوقع"),
    "ur": ("آواز سے اندراج", "آواز سے اندراج روکیں", "اس ڈیوائس پر آواز سے اندراج دستیاب نہیں", "آواز سے اندراج کے لیے مائیکروفون تک رسائی کی اجازت دیں", "آواز سے اندراج اچانک رک گیا"),
}

BUBBLE_KEYS = ('messageCopyAll', 'messageSelectText')
BUBBLE = {
    "en": ("Copy all text", "Select text"),
    "pt": ("Copiar todo o texto", "Selecionar texto"),
    "es": ("Copiar todo el texto", "Seleccionar texto"),
    "fr": ("Copier tout le texte", "Sélectionner le texte"),
    "de": ("Gesamten Text kopieren", "Text auswählen"),
    "it": ("Copia tutto il testo", "Seleziona testo"),
    "ru": ("Скопировать весь текст", "Выделить текст"),
    "ja": ("テキストをすべてコピー", "テキストを選択"),
    "ko": ("전체 텍스트 복사", "텍스트 선택"),
    "zh": ("复制全部文本", "选择文本"),
    "hi": ("पूरा टेक्स्ट कॉपी करें", "टेक्स्ट चुनें"),
    "bn": ("সব লেখা কপি করুন", "লেখা নির্বাচন করুন"),
    "ar": ("نسخ النص بالكامل", "تحديد النص"),
    "ur": ("پورا متن کاپی کریں", "متن منتخب کریں"),
}

SERVER_RULE_KEYS = ('livePermissionServerRule',)
SERVER_RULE = {
    "en": ("Saved on the server for every client. The agent asks nothing, even in Plan mode.",),
    "pt": ("Salvo no servidor para todos os clientes. O agente não pergunta nada, nem no modo Plan.",),
    "es": ("Guardado en el servidor para todos los clientes. El agente no pregunta nada, ni en el modo Plan.",),
    "fr": ("Enregistré sur le serveur pour tous les clients. L’agent ne demande rien, même en mode Plan.",),
    "de": ("Auf dem Server für alle Clients gespeichert. Der Agent fragt nichts, auch nicht im Plan-Modus.",),
    "it": ("Salvato sul server per tutti i client. L’agente non chiede nulla, nemmeno in modalità Plan.",),
    "ru": ("Сохранено на сервере для всех клиентов. Агент ничего не спрашивает, даже в режиме Plan.",),
    "ja": ("すべてのクライアント向けにサーバーに保存されます。Plan モードでも、エージェントは何も確認しません。",),
    "ko": ("모든 클라이언트를 위해 서버에 저장됩니다. Plan 모드에서도 에이전트가 아무것도 묻지 않습니다.",),
    "zh": ("已保存在服务器上，对所有客户端生效。即使在 Plan 模式下，代理也不会询问任何事。",),
    "hi": ("सभी क्लाइंट के लिए सर्वर पर सहेजा गया। एजेंट कुछ नहीं पूछता, Plan मोड में भी नहीं।",),
    "bn": ("সব ক্লায়েন্টের জন্য সার্ভারে সংরক্ষিত। এজেন্ট কিছুই জিজ্ঞেস করে না, Plan মোডেও না।",),
    "ar": ("محفوظ على الخادم لجميع العملاء. لا يسأل الوكيل عن أي شيء، حتى في وضع Plan.",),
    "ur": ("تمام کلائنٹس کے لیے سرور پر محفوظ۔ ایجنٹ کچھ نہیں پوچھتا، Plan موڈ میں بھی نہیں۔",),
}
