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
