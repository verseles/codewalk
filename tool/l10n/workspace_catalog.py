"""V2 chat-first workspace copy, ported from the v1 home and drawer."""

PORT_KEYS = {
    "chatNoServerYet",
    "chatSetUpServer",
    "chatNewChat",
    "chatSelectOrCreate",
}

NEW_KEYS = ("workspaceDraftUncertain", "workspaceDraftReset")

COPY = {
 "en": ("Session creation is unconfirmed. Your text was kept; a session may already exist.", "Discard attempt and keep text"),
 "pt": ("A criação da conversa não foi confirmada. Seu texto foi mantido; a conversa pode já existir.", "Descartar tentativa e manter texto"),
 "es": ("No se confirmó la creación de la conversación. Se conservó tu texto; la conversación podría existir.", "Descartar intento y conservar texto"),
 "fr": ("La création de la conversation n’est pas confirmée. Votre texte est conservé ; la conversation existe peut-être déjà.", "Abandonner la tentative et garder le texte"),
 "de": ("Die Erstellung wurde nicht bestätigt. Dein Text wurde behalten; die Unterhaltung könnte bereits existieren.", "Versuch verwerfen und Text behalten"),
 "it": ("La creazione della conversazione non è confermata. Il testo è stato conservato; la conversazione potrebbe già esistere.", "Scarta il tentativo e conserva il testo"),
 "ar": ("لم يتم تأكيد إنشاء المحادثة. تم الاحتفاظ بالنص؛ قد تكون المحادثة موجودة بالفعل.", "تجاهل المحاولة والاحتفاظ بالنص"),
 "ur": ("گفتگو بننے کی تصدیق نہیں ہوئی۔ آپ کا متن محفوظ ہے؛ گفتگو پہلے سے موجود ہو سکتی ہے۔", "کوشش ترک کریں اور متن رکھیں"),
 "hi": ("बातचीत बनने की पुष्टि नहीं हुई। आपका पाठ रखा गया है; बातचीत पहले से मौजूद हो सकती है।", "प्रयास छोड़ें और पाठ रखें"),
 "bn": ("কথোপকথন তৈরি নিশ্চিত হয়নি। আপনার লেখা রাখা হয়েছে; কথোপকথনটি ইতিমধ্যে থাকতে পারে।", "চেষ্টা বাতিল করে লেখা রাখুন"),
 "ja": ("会話の作成を確認できません。入力内容は保持されています。会話は既に存在する可能性があります。", "試行を破棄して入力内容を保持"),
 "ko": ("대화 생성이 확인되지 않았습니다. 입력한 내용은 유지되며 대화가 이미 존재할 수 있습니다.", "시도를 취소하고 입력 유지"),
 "zh": ("无法确认会话是否已创建。输入内容已保留；会话可能已存在。", "放弃本次尝试并保留输入"),
 "ru": ("Создание беседы не подтверждено. Текст сохранён; беседа, возможно, уже существует.", "Отменить попытку и сохранить текст"),
}
