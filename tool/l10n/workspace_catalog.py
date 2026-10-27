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

# The project drawer (#453 S4): the list of the open project contexts, its
# search, filter and sort, Recent and context-scoped pins.
PORT_KEYS |= {
    "chatSearchConversations", "chatRecentSessions", "workspaceOpenProjects",
    "chatOpenProjectToLoad", "chatCloseProject",
    "projectProviderErrorAtLeastOneContext", "chatSortSessions",
    "chatSortRecent", "chatSortOldest", "chatSortTitle", "chatFilterSessions",
    "sessionPin", "sessionUnpin", "chatNoConversationsInProject",
}
NEW_KEYS += (
    "projectsCapacity", "projectsUnavailable", "sessionsListState",
    "sessionsPinnedMark", "projectsSessionCount", "projectsSessionCountAtLeast",
)
_DRAWER_COPY = {
 "en": ("The open projects or pins reached their limit. Close a project or unpin a session first.", "Projects could not be read or saved. Try again.", "Filter: {filter}. Sort: {sort}.", "Pinned", "Conversations: {count}", "Conversations: {count} or more"),
 "pt": ("Os projetos abertos ou fixados atingiram o limite. Feche um projeto ou desafixe uma conversa antes.", "Não foi possível ler ou salvar os projetos. Tente novamente.", "Filtro: {filter}. Ordem: {sort}.", "Fixada", "Conversas: {count}", "Conversas: {count} ou mais"),
 "es": ("Los proyectos abiertos o fijados alcanzaron su límite. Cierra un proyecto o desfija una conversación primero.", "No se pudieron leer ni guardar los proyectos. Inténtalo de nuevo.", "Filtro: {filter}. Orden: {sort}.", "Fijada", "Conversaciones: {count}", "Conversaciones: {count} o más"),
 "fr": ("Les projets ouverts ou les épingles ont atteint leur limite. Fermez un projet ou désépinglez une conversation d’abord.", "Impossible de lire ou d’enregistrer les projets. Réessayez.", "Filtre : {filter}. Tri : {sort}.", "Épinglée", "Conversations : {count}", "Conversations : {count} ou plus"),
 "de": ("Die offenen Projekte oder Anheftungen haben ihr Limit erreicht. Schließe zuerst ein Projekt oder löse eine Unterhaltung.", "Die Projekte konnten nicht gelesen oder gespeichert werden. Versuche es erneut.", "Filter: {filter}. Sortierung: {sort}.", "Angeheftet", "Unterhaltungen: {count}", "Unterhaltungen: {count} oder mehr"),
 "it": ("I progetti aperti o i fissati hanno raggiunto il limite. Chiudi prima un progetto o sblocca una conversazione.", "Impossibile leggere o salvare i progetti. Riprova.", "Filtro: {filter}. Ordine: {sort}.", "Fissata", "Conversazioni: {count}", "Conversazioni: {count} o più"),
 "ar": ("بلغت المشاريع المفتوحة أو المثبتات حدها. أغلق مشروعًا أو ألغِ تثبيت محادثة أولًا.", "تعذرت قراءة المشاريع أو حفظها. حاول مرة أخرى.", "التصفية: {filter}. الترتيب: {sort}.", "مثبتة", "المحادثات: {count}", "المحادثات: {count} أو أكثر"),
 "ur": ("کھلے پروجیکٹس یا پنز اپنی حد تک پہنچ گئے۔ پہلے کوئی پروجیکٹ بند کریں یا کسی گفتگو کا پن ہٹائیں۔", "پروجیکٹس پڑھے یا محفوظ نہیں کیے جا سکے۔ دوبارہ کوشش کریں۔", "فلٹر: {filter}۔ ترتیب: {sort}۔", "پن شدہ", "گفتگوئیں: {count}", "گفتگوئیں: {count} یا زیادہ"),
 "hi": ("खुले प्रोजेक्ट या पिन अपनी सीमा तक पहुँच गए हैं। पहले कोई प्रोजेक्ट बंद करें या किसी बातचीत को अनपिन करें।", "प्रोजेक्ट पढ़े या सहेजे नहीं जा सके। फिर से कोशिश करें।", "फ़िल्टर: {filter}। क्रम: {sort}।", "पिन की गई", "बातचीत: {count}", "बातचीत: {count} या अधिक"),
 "bn": ("খোলা প্রকল্প বা পিন সীমায় পৌঁছেছে। আগে একটি প্রকল্প বন্ধ করুন বা একটি কথোপকথন আনপিন করুন।", "প্রকল্পগুলো পড়া বা সংরক্ষণ করা যায়নি। আবার চেষ্টা করুন।", "ফিল্টার: {filter}। ক্রম: {sort}।", "পিন করা", "কথোপকথন: {count}", "কথোপকথন: {count} বা তার বেশি"),
 "ja": ("開いているプロジェクトまたはピン留めが上限に達しました。先にプロジェクトを閉じるか、会話のピン留めを外してください。", "プロジェクトを読み込みまたは保存できませんでした。もう一度お試しください。", "フィルター: {filter}。並べ替え: {sort}。", "ピン留め済み", "会話: {count}", "会話: {count} 件以上"),
 "ko": ("열린 프로젝트 또는 고정 항목이 한도에 도달했습니다. 먼저 프로젝트를 닫거나 대화 고정을 해제하세요.", "프로젝트를 읽거나 저장할 수 없습니다. 다시 시도하세요.", "필터: {filter}. 정렬: {sort}.", "고정됨", "대화: {count}", "대화: {count}개 이상"),
 "zh": ("打开的项目或置顶已达上限。请先关闭一个项目或取消置顶一个对话。", "无法读取或保存项目。请重试。", "筛选：{filter}。排序：{sort}。", "已置顶", "对话：{count}", "对话：{count} 个或更多"),
 "ru": ("Открытые проекты или закрепления достигли предела. Сначала закройте проект или открепите беседу.", "Не удалось прочитать или сохранить проекты. Повторите попытку.", "Фильтр: {filter}. Сортировка: {sort}.", "Закреплена", "Беседы: {count}", "Беседы: {count} или больше"),
}
for _locale, _copy in _DRAWER_COPY.items():
    COPY[_locale] += _copy

# The project picker (#453 S4): known projects, the server's folders, the
# directory browser and a manual absolute path.
PORT_KEYS |= {
    "chatChooseDirectory", "chatChooseFolderOpen", "chatFailedToLoadDirectories",
    "workspaceBrowseDirs", "workspaceCurrentDirectory",
    "workspaceFailedToOpenProjectContext", "workspaceFilterDirs",
    "workspaceOpenFolder", "workspaceProjectHint", "workspaceRemoveFromHistory",
}

# Session tab glyph picker and local restore errors (#453 S5).
PORT_KEYS |= {
    "sessionTabChangeIconAction", "sessionTabIconPickerTitle",
    "sessionTabIconUseProjectIcon", "sessionTabRestoreFailed",
    "sessionTabIconSaveFailed",
    "sessionTabIconPresetCode",
    "sessionTabIconPresetTerminal",
    "sessionTabIconPresetBug",
    "sessionTabIconPresetTasks",
    "sessionTabIconPresetLaunch",
    "sessionTabIconPresetIdea",
    "sessionTabIconPresetResearch",
    "sessionTabIconPresetDesign",
    "sessionTabIconPresetData",
    "sessionTabIconPresetCloud",
    "sessionTabIconPresetSecurity",
    "sessionTabIconPresetTools",
}

# Sub-conversation navigation from a subagent card (#453 S6).
PORT_KEYS |= {
    "chatReturnToParentConversation", "chatNoSubConversationFound",
    "chatModelLockedSubConversation", "chatEffortLockedSubConversation",
}

# Desktop conversations pane and its hidden-pane toolbar access (#453 S7).
PORT_KEYS |= {
    "chatConversationsPane", "chatHideConversationsSidebar", "chatOpenSidebar",
    "chatProjectContext",
}
