"""V2 update check copy (Settings > Version and updates)."""

PORT_KEYS = {
    "settingsGroupVersionUpdates",
    "settingsAboutCheckForUpdates",
    "settingsAboutUpdateAvailable",
}

NEW_KEYS = (
    "updatesDescription", "updatesChannel", "updatesChannelStable",
    "updatesChannelBeta", "updatesBetaHint", "updatesInstalledVersion",
    "updatesUpToDate", "updatesCheckFailed", "updatesDownload",
    "updatesLinuxInstallHint", "updatesCopyCommand", "updatesCommandCopied",
    "updatesUnsupported",
)

COPY = {
    "en": ("Check for new CodeWalk versions", "Update channel", "Stable", "Beta", "Beta versions are previews and may have problems.", "Installed version", "CodeWalk is up to date.", "Unable to check for updates. Check your connection and try again.", "Download", "Run this command to install this exact version:", "Copy command", "Command copied", "Updates on this platform are not available yet."),
    "pt": ("Verificar novas versões do CodeWalk", "Canal de atualização", "Estável", "Beta", "Versões beta são prévias e podem ter problemas.", "Versão instalada", "O CodeWalk está atualizado.", "Não foi possível verificar atualizações. Verifique sua conexão e tente novamente.", "Baixar", "Execute este comando para instalar exatamente esta versão:", "Copiar comando", "Comando copiado", "Atualizações nesta plataforma ainda não estão disponíveis."),
    "es": ("Buscar nuevas versiones de CodeWalk", "Canal de actualización", "Estable", "Beta", "Las versiones beta son previas y pueden tener problemas.", "Versión instalada", "CodeWalk está actualizado.", "No se pudo buscar actualizaciones. Revisa tu conexión e inténtalo de nuevo.", "Descargar", "Ejecuta este comando para instalar exactamente esta versión:", "Copiar comando", "Comando copiado", "Las actualizaciones en esta plataforma aún no están disponibles."),
    "fr": ("Rechercher de nouvelles versions de CodeWalk", "Canal de mise à jour", "Stable", "Bêta", "Les versions bêta sont des préversions et peuvent présenter des problèmes.", "Version installée", "CodeWalk est à jour.", "Impossible de rechercher des mises à jour. Vérifiez votre connexion et réessayez.", "Télécharger", "Exécutez cette commande pour installer exactement cette version :", "Copier la commande", "Commande copiée", "Les mises à jour ne sont pas encore disponibles sur cette plateforme."),
    "de": ("Nach neuen CodeWalk-Versionen suchen", "Update-Kanal", "Stabil", "Beta", "Beta-Versionen sind Vorabversionen und können Probleme haben.", "Installierte Version", "CodeWalk ist auf dem neuesten Stand.", "Updates konnten nicht geprüft werden. Prüfe die Verbindung und versuche es erneut.", "Herunterladen", "Führe diesen Befehl aus, um genau diese Version zu installieren:", "Befehl kopieren", "Befehl kopiert", "Updates sind auf dieser Plattform noch nicht verfügbar."),
    "it": ("Cerca nuove versioni di CodeWalk", "Canale di aggiornamento", "Stabile", "Beta", "Le versioni beta sono anteprime e possono avere problemi.", "Versione installata", "CodeWalk è aggiornato.", "Impossibile cercare aggiornamenti. Controlla la connessione e riprova.", "Scarica", "Esegui questo comando per installare esattamente questa versione:", "Copia comando", "Comando copiato", "Gli aggiornamenti su questa piattaforma non sono ancora disponibili."),
    "ru": ("Проверить новые версии CodeWalk", "Канал обновлений", "Стабильный", "Бета", "Бета-версии — предварительные и могут работать с ошибками.", "Установленная версия", "CodeWalk обновлён.", "Не удалось проверить обновления. Проверьте подключение и повторите попытку.", "Скачать", "Выполните эту команду, чтобы установить именно эту версию:", "Скопировать команду", "Команда скопирована", "Обновления на этой платформе пока недоступны."),
    "ja": ("CodeWalk の新しいバージョンを確認", "アップデートチャンネル", "安定版", "ベータ版", "ベータ版はプレビューであり、問題が発生する場合があります。", "インストール済みのバージョン", "CodeWalk は最新です。", "アップデートを確認できませんでした。接続を確認して、もう一度お試しください。", "ダウンロード", "このバージョンを正確にインストールするには、次のコマンドを実行してください:", "コマンドをコピー", "コマンドをコピーしました", "このプラットフォームのアップデートはまだ利用できません。"),
    "ko": ("CodeWalk 새 버전 확인", "업데이트 채널", "안정", "베타", "베타 버전은 미리보기이며 문제가 있을 수 있습니다.", "설치된 버전", "CodeWalk가 최신 상태입니다.", "업데이트를 확인할 수 없습니다. 연결을 확인하고 다시 시도하세요.", "다운로드", "이 버전을 정확히 설치하려면 다음 명령을 실행하세요:", "명령 복사", "명령을 복사했습니다", "이 플랫폼에서는 아직 업데이트를 사용할 수 없습니다."),
    "zh": ("检查 CodeWalk 新版本", "更新渠道", "稳定版", "测试版", "测试版是预览版本，可能存在问题。", "已安装的版本", "CodeWalk 已是最新版本。", "无法检查更新。请检查网络连接后重试。", "下载", "运行此命令以安装此确切版本：", "复制命令", "命令已复制", "此平台暂不支持更新。"),
    "hi": ("CodeWalk के नए संस्करण जाँचें", "अपडेट चैनल", "स्थिर", "बीटा", "बीटा संस्करण पूर्वावलोकन हैं और उनमें समस्याएँ हो सकती हैं।", "इंस्टॉल किया गया संस्करण", "CodeWalk अप टू डेट है।", "अपडेट जाँचे नहीं जा सके। अपना कनेक्शन जाँचें और फिर से कोशिश करें।", "डाउनलोड करें", "ठीक यही संस्करण इंस्टॉल करने के लिए यह कमांड चलाएँ:", "कमांड कॉपी करें", "कमांड कॉपी हो गया", "इस प्लेटफ़ॉर्म पर अपडेट अभी उपलब्ध नहीं हैं।"),
    "bn": ("CodeWalk-এর নতুন সংস্করণ খুঁজুন", "আপডেট চ্যানেল", "স্থিতিশীল", "বিটা", "বিটা সংস্করণগুলো প্রিভিউ এবং এতে সমস্যা থাকতে পারে।", "ইনস্টল করা সংস্করণ", "CodeWalk হালনাগাদ আছে।", "আপডেট পরীক্ষা করা যায়নি। সংযোগ পরীক্ষা করে আবার চেষ্টা করুন।", "ডাউনলোড", "ঠিক এই সংস্করণটি ইনস্টল করতে এই কমান্ডটি চালান:", "কমান্ড কপি করুন", "কমান্ড কপি হয়েছে", "এই প্ল্যাটফর্মে আপডেট এখনও উপলব্ধ নয়।"),
    "ar": ("التحقق من إصدارات CodeWalk الجديدة", "قناة التحديث", "مستقر", "تجريبي", "الإصدارات التجريبية معاينات وقد تحتوي على مشكلات.", "الإصدار المثبّت", "CodeWalk محدّث.", "تعذّر التحقق من التحديثات. تحقّق من اتصالك وحاول مرة أخرى.", "تنزيل", "شغّل هذا الأمر لتثبيت هذا الإصدار تحديدًا:", "نسخ الأمر", "تم نسخ الأمر", "التحديثات على هذه المنصة غير متاحة بعد."),
    "ur": ("CodeWalk کے نئے ورژن چیک کریں", "اپڈیٹ چینل", "مستحکم", "بیٹا", "بیٹا ورژن پیش نظارہ ہیں اور ان میں مسائل ہو سکتے ہیں۔", "انسٹال شدہ ورژن", "CodeWalk تازہ ترین ہے۔", "اپڈیٹس چیک نہیں ہو سکیں۔ اپنا کنکشن چیک کریں اور دوبارہ کوشش کریں۔", "ڈاؤن لوڈ کریں", "بالکل یہی ورژن انسٹال کرنے کے لیے یہ کمانڈ چلائیں:", "کمانڈ کاپی کریں", "کمانڈ کاپی ہو گئی", "اس پلیٹ فارم پر اپڈیٹس ابھی دستیاب نہیں ہیں۔"),
}
