"""V2 local `/` commands in the composer (#137), ported from the v1 picker."""

PORT_KEYS = {
    "chatSlashCommandNew",
    "chatSlashCommandModels",
    "chatSlashCommandSessions",
    "chatSlashCommandAgent",
    "chatSlashCommandHelp",
    "chatSlashCommandCompact",
    "chatSlashCommandThinking",
    "chatSlashCommandUndo",
    "chatSlashCommandRedo",
}

NEW_KEYS = (
    "commandsTitle",
    "commandsHint",
    "commandNotYetAvailable",
    "commandNeedsConversation",
    "commandUnavailableHere",
    "commandThinkingShown",
    "commandThinkingHidden",
)

COPY = {
 "en": ("Commands", "Type / in the message field to pick a command.", "This command is not available in this version yet.", "This command works inside a conversation. Send a first message to start one.", "This command is not available for this conversation.", "Thinking shown", "Thinking hidden"),
 "pt": ("Comandos", "Digite / no campo de mensagem para escolher um comando.", "Este comando ainda não está disponível nesta versão.", "Este comando funciona dentro de uma conversa. Envie uma primeira mensagem para começar uma.", "Este comando não está disponível para esta conversa.", "Raciocínio exibido", "Raciocínio oculto"),
 "es": ("Comandos", "Escribe / en el campo de mensaje para elegir un comando.", "Este comando aún no está disponible en esta versión.", "Este comando funciona dentro de una conversación. Envía un primer mensaje para iniciar una.", "Este comando no está disponible para esta conversación.", "Razonamiento visible", "Razonamiento oculto"),
 "fr": ("Commandes", "Tapez / dans le champ de message pour choisir une commande.", "Cette commande n’est pas encore disponible dans cette version.", "Cette commande fonctionne dans une conversation. Envoyez un premier message pour en démarrer une.", "Cette commande n’est pas disponible pour cette conversation.", "Raisonnement affiché", "Raisonnement masqué"),
 "de": ("Befehle", "Gib / in das Nachrichtenfeld ein, um einen Befehl zu wählen.", "Dieser Befehl ist in dieser Version noch nicht verfügbar.", "Dieser Befehl funktioniert in einer Unterhaltung. Sende eine erste Nachricht, um eine zu beginnen.", "Dieser Befehl ist für diese Unterhaltung nicht verfügbar.", "Denkprozess eingeblendet", "Denkprozess ausgeblendet"),
 "it": ("Comandi", "Digita / nel campo del messaggio per scegliere un comando.", "Questo comando non è ancora disponibile in questa versione.", "Questo comando funziona all’interno di una conversazione. Invia un primo messaggio per iniziarne una.", "Questo comando non è disponibile per questa conversazione.", "Ragionamento visibile", "Ragionamento nascosto"),
 "ru": ("Команды", "Введите / в поле сообщения, чтобы выбрать команду.", "Эта команда пока недоступна в этой версии.", "Эта команда работает внутри беседы. Отправьте первое сообщение, чтобы начать её.", "Эта команда недоступна для этой беседы.", "Рассуждения показаны", "Рассуждения скрыты"),
 "ja": ("コマンド", "メッセージ欄に / を入力してコマンドを選びます。", "このコマンドはこのバージョンではまだ使えません。", "このコマンドは会話の中で使えます。最初のメッセージを送って会話を始めてください。", "このコマンドはこの会話では使えません。", "思考を表示しました", "思考を非表示にしました"),
 "ko": ("명령", "메시지 입력란에 /를 입력해 명령을 선택하세요.", "이 명령은 이 버전에서 아직 사용할 수 없습니다.", "이 명령은 대화 안에서 작동합니다. 첫 메시지를 보내 대화를 시작하세요.", "이 명령은 이 대화에서 사용할 수 없습니다.", "사고 과정 표시됨", "사고 과정 숨겨짐"),
 "zh": ("命令", "在消息框中输入 / 以选择命令。", "此版本尚不支持该命令。", "该命令需在对话中使用。发送第一条消息以开始对话。", "该命令不适用于此对话。", "已显示思考过程", "已隐藏思考过程"),
 "hi": ("कमांड", "कमांड चुनने के लिए संदेश फ़ील्ड में / लिखें।", "यह कमांड इस संस्करण में अभी उपलब्ध नहीं है।", "यह कमांड बातचीत के अंदर काम करती है। बातचीत शुरू करने के लिए पहला संदेश भेजें।", "यह कमांड इस बातचीत के लिए उपलब्ध नहीं है।", "सोच दिखाई गई", "सोच छिपाई गई"),
 "bn": ("কমান্ড", "কমান্ড বেছে নিতে বার্তার ঘরে / লিখুন।", "এই কমান্ড এই সংস্করণে এখনও উপলব্ধ নয়।", "এই কমান্ড কথোপকথনের ভেতরে কাজ করে। একটি শুরু করতে প্রথম বার্তা পাঠান।", "এই কথোপকথনের জন্য এই কমান্ড উপলব্ধ নয়।", "চিন্তা দেখানো হচ্ছে", "চিন্তা লুকানো হয়েছে"),
 "ar": ("الأوامر", "اكتب / في حقل الرسالة لاختيار أمر.", "هذا الأمر غير متاح بعد في هذا الإصدار.", "يعمل هذا الأمر داخل محادثة. أرسل رسالة أولى لبدء محادثة.", "هذا الأمر غير متاح لهذه المحادثة.", "تم إظهار التفكير", "تم إخفاء التفكير"),
 "ur": ("کمانڈز", "کمانڈ چننے کے لیے پیغام کے خانے میں / لکھیں۔", "یہ کمانڈ اس ورژن میں ابھی دستیاب نہیں ہے۔", "یہ کمانڈ گفتگو کے اندر کام کرتی ہے۔ گفتگو شروع کرنے کے لیے پہلا پیغام بھیجیں۔", "یہ کمانڈ اس گفتگو کے لیے دستیاب نہیں ہے۔", "سوچ دکھائی گئی", "سوچ چھپائی گئی"),
}
