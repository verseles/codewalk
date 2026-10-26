"""V2 chat-first workspace copy, ported from the v1 home and drawer."""

PORT_KEYS = {
    "chatNoServerYet",
    "chatSetUpServer",
    "chatNewChat",
    "chatSelectOrCreate",
    "statusOnline", "statusDelayed", "statusOffline",
    "serversSearchActiveHint", "serversSetActive",
    "chatAppBarMoreActions", "chatAppBarPinAction", "chatAppBarUnpinAction",
    "chatBadgeConversationError", "chatBadgeConversationNeedsInput",
    "chatBadgeConversationNewReply", "chatBadgeServerNeedsAttention",
    "chatBadgeSyncing",
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

NEW_KEYS += (
    "healthCredentialMissing", "healthCredentialUnreadable", "healthCredentialExpired",
)
_CREDENTIAL_COPY = {
 "en": ("This server has no saved credential. Pair again or enter its password.", "The saved credential could not be read. Open Servers to recover access.", "The saved pairing credential has expired. Pair again or renew it in Servers."),
 "pt": ("Este servidor não tem credencial salva. Pareie novamente ou informe a senha.", "Não foi possível ler a credencial salva. Abra Servidores para recuperar o acesso.", "A credencial de pareamento expirou. Pareie novamente ou renove em Servidores."),
 "es": ("Este servidor no tiene credencial guardada. Vuelve a vincularlo o introduce su contraseña.", "No se pudo leer la credencial guardada. Abre Servidores para recuperar el acceso.", "La credencial de vinculación caducó. Vuelve a vincularlo o renuévala en Servidores."),
 "fr": ("Ce serveur n’a pas d’identifiant enregistré. Associez-le à nouveau ou saisissez son mot de passe.", "Impossible de lire l’identifiant enregistré. Ouvrez Serveurs pour rétablir l’accès.", "L’identifiant d’association a expiré. Associez à nouveau le serveur ou renouvelez-le dans Serveurs."),
 "de": ("Für diesen Server sind keine Zugangsdaten gespeichert. Erneut koppeln oder das Passwort eingeben.", "Die gespeicherten Zugangsdaten konnten nicht gelesen werden. Öffne Server, um den Zugriff wiederherzustellen.", "Die Kopplungsdaten sind abgelaufen. Erneut koppeln oder unter Server erneuern."),
 "it": ("Questo server non ha credenziali salvate. Abbinalo di nuovo o inserisci la password.", "Impossibile leggere le credenziali salvate. Apri Server per ripristinare l’accesso.", "Le credenziali di abbinamento sono scadute. Abbina di nuovo il server o rinnovale in Server."),
 "ar": ("لا توجد بيانات اعتماد محفوظة لهذا الخادم. أعد الإقران أو أدخل كلمة مروره.", "تعذرت قراءة بيانات الاعتماد المحفوظة. افتح الخوادم لاستعادة الوصول.", "انتهت صلاحية بيانات الإقران. أعد الإقران أو جددها في الخوادم."),
 "ur": ("اس سرور کی محفوظ اسناد موجود نہیں۔ دوبارہ پیئر کریں یا پاس ورڈ درج کریں۔", "محفوظ اسناد پڑھی نہیں جا سکیں۔ رسائی بحال کرنے کے لیے سرورز کھولیں۔", "پیئرنگ کی اسناد کی میعاد ختم ہو گئی۔ دوبارہ پیئر کریں یا سرورز میں تجدید کریں۔"),
 "hi": ("इस सर्वर के लिए कोई सहेजा गया क्रेडेंशियल नहीं है। फिर से पेयर करें या पासवर्ड डालें।", "सहेजा गया क्रेडेंशियल पढ़ा नहीं जा सका। पहुँच बहाल करने के लिए सर्वर खोलें।", "पेयरिंग क्रेडेंशियल की समय सीमा समाप्त हो गई है। फिर से पेयर करें या सर्वर में नवीनीकृत करें।"),
 "bn": ("এই সার্ভারের কোনো সংরক্ষিত পরিচয়পত্র নেই। আবার পেয়ার করুন বা পাসওয়ার্ড দিন।", "সংরক্ষিত পরিচয়পত্র পড়া যায়নি। প্রবেশাধিকার ফেরাতে সার্ভার খুলুন।", "পেয়ারিং পরিচয়পত্রের মেয়াদ শেষ হয়েছে। আবার পেয়ার করুন বা সার্ভারে নবায়ন করুন।"),
 "ja": ("このサーバーの認証情報は保存されていません。再ペアリングするかパスワードを入力してください。", "保存された認証情報を読み取れません。サーバー設定からアクセスを復旧してください。", "ペアリング認証情報の有効期限が切れました。サーバー設定で再ペアリングするか更新してください。"),
 "ko": ("이 서버에 저장된 인증 정보가 없습니다. 다시 페어링하거나 비밀번호를 입력하세요.", "저장된 인증 정보를 읽을 수 없습니다. 서버 설정에서 접근을 복구하세요.", "페어링 인증 정보가 만료되었습니다. 서버 설정에서 다시 페어링하거나 갱신하세요."),
 "zh": ("此服务器没有已保存的凭据。请重新配对或输入密码。", "无法读取已保存的凭据。请打开服务器设置以恢复访问。", "配对凭据已过期。请在服务器设置中重新配对或续期。"),
 "ru": ("Для этого сервера нет сохранённых учётных данных. Выполните сопряжение заново или введите пароль.", "Не удалось прочитать сохранённые учётные данные. Откройте раздел «Серверы», чтобы восстановить доступ.", "Срок действия данных сопряжения истёк. Выполните сопряжение заново или обновите их в разделе «Серверы»."),
}
for _locale, _copy in _CREDENTIAL_COPY.items():
    COPY[_locale] += _copy
