// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get aboutGitHub => 'GitHub';

  @override
  String get appProviderCannotActivateUnhealthy =>
      'لا يمكن تنشيط خادم غير سليم';

  @override
  String get appProviderDesktopOnly =>
      'الخادم المحلي المدار متاح فقط على سطح المكتب.';

  @override
  String get appProviderDetectingCommand => 'جاري اكتشاف أمر OpenCode...';

  @override
  String get appProviderErrorCannotActivateUnhealthy =>
      'لا يمكن تنشيط خادم غير سليم';

  @override
  String get appProviderErrorCloudflareOAuthNotSupported =>
      'Cloudflare Access OAuth غير مدعوم على هذه المنصة';

  @override
  String get appProviderErrorInstallationFailed => 'فشل تثبيت OpenCode.';

  @override
  String get appProviderErrorInvalidServerUrl => 'عنوان URL للخادم غير صالح';

  @override
  String get appProviderErrorLocalServerHealthCheckFailed =>
      'بدأ الخادم المحلي ولكن لم يمر فحص الحالة.';

  @override
  String get appProviderErrorManagedDesktopOnly =>
      'الخادم المحلي المدار متاح فقط على سطح المكتب.';

  @override
  String get appProviderErrorServerAlreadyExists =>
      'يوجد خادم بهذا العنوان بالفعل';

  @override
  String get appProviderErrorServerProfileNotFound =>
      'لم يتم العثور على ملف تعريف الخادم';

  @override
  String get appProviderErrorServerUrlRequired => 'عنوان URL للخادم مطلوب';

  @override
  String get appProviderErrorTailscaleNotSupported =>
      'Tailscale غير مدعوم على هذه المنصة';

  @override
  String appProviderExitedWithCode(int code) {
    return 'خرج الخادم المحلي بالرمز $code.';
  }

  @override
  String get appProviderFailedToStart => 'فشل بدء خادم OpenCode المحلي.';

  @override
  String get appProviderInstallBinary => 'تثبيت الملف الثنائي';

  @override
  String get appProviderInstallBunOpenCode => 'تثبيت Bun + OpenCode';

  @override
  String get appProviderInstallSucceeded => 'نجح التثبيت.';

  @override
  String appProviderInstallSucceededWithPath(String path) {
    return 'نجح التثبيت. أمر OpenCode متاح في $path.';
  }

  @override
  String get appProviderInstallViaBun => 'التثبيت عبر Bun';

  @override
  String get appProviderInstallViaNpm => 'التثبيت عبر npm';

  @override
  String get appProviderInstallationFailed => 'فشل تثبيت OpenCode.';

  @override
  String get appProviderInstalledSuccessfully =>
      'تم تثبيت متطلبات OpenCode بنجاح.';

  @override
  String get appProviderInstallingRequirements =>
      'جاري تثبيت متطلبات OpenCode...';

  @override
  String get appProviderInvalidServerUrl => 'عنوان URL للخادم غير صالح';

  @override
  String get appProviderLabelLocalOpenCodeManaged => 'OpenCode محلي (مدار)';

  @override
  String get appProviderLabelPrimaryServer => 'الخادم الأساسي';

  @override
  String get appProviderLocalManaged => 'OpenCode محلي (مدار)';

  @override
  String get appProviderLocalServerStopped => 'الخادم المحلي متوقف.';

  @override
  String get appProviderNotDetectedInstall =>
      'لم يتم اكتشاف أمر OpenCode. قم بتشغيل التثبيت من المعالج.';

  @override
  String appProviderNotDetectedRefresh(String appName) {
    return 'لم يتم اكتشاف أمر OpenCode. إذا قمت بتثبيته للتو، فقم بتحديث الفحوصات أو أعد فتح $appName لإعادة تحميل PATH.';
  }

  @override
  String get appProviderOAuthNotSupported =>
      'Cloudflare Access OAuth غير مدعوم على هذه المنصة';

  @override
  String get appProviderOpenCodeDetected => 'تم اكتشاف OpenCode';

  @override
  String get appProviderOpenCodeNotDetected => 'لم يتم اكتشاف OpenCode';

  @override
  String get appProviderPrimaryServer => 'الخادم الأساسي';

  @override
  String get appProviderProfileNotFound => 'لم يتم العثور على ملف تعريف الخادم';

  @override
  String get appProviderRunDiagnostics =>
      'قم بتشغيل التشخيصات للتحقق من متطلبات OpenCode المحلية.';

  @override
  String appProviderRunningAt(String url) {
    return 'يعمل في $url';
  }

  @override
  String get appProviderSetupDetectingOpenCode => 'جاري اكتشاف أمر OpenCode...';

  @override
  String get appProviderSetupInstallationSucceeded => 'نجح التثبيت.';

  @override
  String appProviderSetupInstallationSucceededWithPath(String path) {
    return 'نجح التثبيت. أمر OpenCode متاح في $path.';
  }

  @override
  String get appProviderSetupInstallingRequirements =>
      'جاري تثبيت متطلبات OpenCode...';

  @override
  String get appProviderSetupOpenCodeDetected => 'تم اكتشاف OpenCode';

  @override
  String get appProviderSetupOpenCodeNotDetected => 'لم يتم اكتشاف OpenCode';

  @override
  String get appProviderSetupOpenCodeNotDetectedInstall =>
      'لم يتم اكتشاف أمر OpenCode. قم بتشغيل التثبيت من المعالج.';

  @override
  String get appProviderSetupOpenCodeNotDetectedRefresh =>
      'لم يتم اكتشاف أمر OpenCode. إذا قمت بتثبيته للتو، فقم بتحديث الفحوصات أو أعد فتح CodeWalk لإعادة تحميل PATH.';

  @override
  String get appProviderSetupRequirementsInstalled =>
      'تم تثبيت متطلبات OpenCode بنجاح.';

  @override
  String appProviderSetupUsingOpenCodeAt(String path) {
    return 'استخدام أمر OpenCode في $path';
  }

  @override
  String get appProviderStartingLocalServer => 'جاري بدء الخادم المحلي...';

  @override
  String appProviderStatusLocalServerExitedWithCode(int code) {
    return 'خرج الخادم المحلي بالرمز $code.';
  }

  @override
  String get appProviderStatusLocalServerStopped => 'الخادم المحلي متوقف.';

  @override
  String appProviderStatusRunningAt(String url) {
    return 'يعمل في $url';
  }

  @override
  String get appProviderStatusStartingLocalServer =>
      'جاري بدء الخادم المحلي...';

  @override
  String get appProviderStatusStoppingLocalServer =>
      'جاري إيقاف الخادم المحلي...';

  @override
  String get appProviderStoppingLocalServer => 'جاري إيقاف الخادم المحلي...';

  @override
  String get appProviderTailscaleNotSupported =>
      'Tailscale غير مدعوم على هذه المنصة';

  @override
  String appProviderUsingCommandAt(String path) {
    return 'استخدام أمر OpenCode في $path';
  }

  @override
  String get appShellDownloadingUpdate => 'جاري تنزيل التحديث';

  @override
  String get appShellInstall => 'تثبيت';

  @override
  String get appShellInstallFailed => 'فشل التثبيت';

  @override
  String get appShellInstallingUpdate => 'جاري تثبيت التحديث...';

  @override
  String get appShellRestart => 'إعادة تشغيل';

  @override
  String appShellUpdateAvailableResult(String latestVersion) {
    return 'تحديث متاح: v$latestVersion';
  }

  @override
  String get appShellUpdateInstalledRestartApp =>
      'تم تثبيت التحديث. أعد تشغيل التطبيق للتطبيق.';

  @override
  String get appShellUpdateInstalledRestartRequired =>
      'تم تثبيت التحديث. يلزم إعادة التشغيل لتطبيق الإصدار الجديد.';

  @override
  String get attachmentCouldNotDecode => 'تعذر فك تشفير بيانات المرفق.';

  @override
  String get attachmentCouldNotDownload => 'تعذر تنزيل المرفق.';

  @override
  String get attachmentCouldNotSave => 'تعذر حفظ المرفق على هذا الجهاز.';

  @override
  String get attachmentDownloadStarted => 'بدأ تنزيل المرفق.';

  @override
  String get attachmentLocalNotFound =>
      'لم يتم العثور على المرفق المحلي على هذا الجهاز.';

  @override
  String get attachmentNoValidLocation => 'المرفق لا يوفر موقعًا صالحًا.';

  @override
  String get attachmentNotAvailableOnPlatform =>
      'إجراءات المرفقات غير متاحة على هذه المنصة.';

  @override
  String get attachmentPathEmpty => 'مسار المرفق فارغ.';

  @override
  String get attachmentPayloadEmpty => 'حمولة المرفق فارغة.';

  @override
  String get attachmentSaveCanceled => 'تم إلغاء الحفظ.';

  @override
  String attachmentSavedAndOpened(String path) {
    return 'تم حفظ المرفق في $path وفتحه.';
  }

  @override
  String attachmentSavedPath(String path) {
    return 'تم حفظ المرفق في $path.';
  }

  @override
  String attachmentSavedTo(String path) {
    return 'تم حفظ المرفق في $path.';
  }

  @override
  String get attachmentUnableToOpenLink => 'تعذر فتح رابط المرفق.';

  @override
  String get attachmentUnableToOpenLocal => 'تعذر فتح المرفق المحلي.';

  @override
  String get behaviorAdvancedPermissionRule => 'قاعدة إذن متقدمة';

  @override
  String get behaviorAutomatic => 'تلقائي';

  @override
  String get behaviorAutomaticFallback => 'احتياطي تلقائي';

  @override
  String get behaviorCellularDataSaver => 'توفير بيانات الجوال';

  @override
  String get behaviorCellularDataSaverActive => 'موفر البيانات الخلوية نشط.';

  @override
  String get behaviorChatLevelShare => 'مشاركة على مستوى الدردشة';

  @override
  String get behaviorCodeWalkReleaseChecks => 'فحوصات إصدار CodeWalk';

  @override
  String get behaviorControlsOfficialGlobal =>
      'يتحكم في إعدادات OpenCode العالمية الرسمية';

  @override
  String get behaviorControlsUpstreamOpenCode =>
      'يتحكم في إعدادات OpenCode المنبع';

  @override
  String get behaviorCustomDisplayName => 'اسم العرض المخصص';

  @override
  String behaviorCutsAutomaticMobile(int inSeconds) {
    return 'يقلل استخدام البيانات المتنقلة التلقائي عن طريق إيقاف التنزيلات في الخلفية والحد من التحديثات التلقائية في المقدمة إلى دفعة واحدة كل $inSeconds ثانية.';
  }

  @override
  String get behaviorDataSaverActive => 'نشط الآن على بيانات المحمول.';

  @override
  String get behaviorDataSaverAggressive => 'صارم';

  @override
  String get behaviorDataSaverAggressiveDescription =>
      'وضع النطاق الترددي المنخفض: يبقى تدفق مساحة العمل المرئية فقط نشطًا، مع إيقاف التحديثات العالمية مؤقتًا وإطالة الفترات الزمنية للتحديث التلقائي.';

  @override
  String get behaviorDataSaverCellularOnly =>
      'ينطبق فقط عندما يكون الاتصال عبر شبكة المحمول/البيانات.';

  @override
  String get behaviorDataSaverOff => 'إيقاف';

  @override
  String get behaviorDataSaverOffHint =>
      'التحديث الفوري والتلقائي مفعّل بالكامل.';

  @override
  String get behaviorDataSaverStandard => 'قياسي';

  @override
  String get behaviorDataSaverWaiting =>
      'بانتظار نافذة مزامنة بيانات المحمول التالية.';

  @override
  String get behaviorDisabled => 'معطل';

  @override
  String get behaviorLightweightTasksLike => 'مهام خفيفة مثل';

  @override
  String get behaviorManual => 'يدوي';

  @override
  String get behaviorNotify => 'إعلام';

  @override
  String get behaviorOfficialOpenCodePermission =>
      'تُكوّن سياسة أذونات OpenCode الرسمية في `opencode.json` بقواعد السماح/السؤال/الرفض لكل أداة. يحتفظ CodeWalk ببطاقات طلب الأذونات الرسمية ويضيف استثناءً واحدًا معتمدًا من ADR-023: تبديل الموافقة التلقائية للملحِّن يرد بـ `Always` و `remember: true` دون قيد أو شرط لإنشاء منح متينة محددة النطاق بالجلسة، ويحافظ على تنشيط مسار الاستمرارية نفسه المحدد النطاق بالمؤشر في عامل الخلفية لنظام Android.';

  @override
  String get behaviorOpenCodeBackedDefaults =>
      'الافتراضيات المدعومة من OpenCode';

  @override
  String get behaviorPermissionHandlingProvenance => 'منشأ معالجة الأذونات';

  @override
  String get behaviorPermissionsVariantReasoning =>
      'تظل أذونات وتكافؤ المتغيرات/الاستدلال منفصلة حتى تتمكن واجهة المستخدم الخاصة بها من الحفاظ على التكوين المتقدم بأمان.';

  @override
  String get behaviorPrimaryAgentAgent =>
      'الوكيل الأساسي المستخدم عندما لا يتم اختيار وكيل صراحةً.';

  @override
  String get behaviorRefreshDefaults => 'تحديث الافتراضيات';

  @override
  String get behaviorSharedAcrossOpenCode =>
      'مشارك عبر عملاء OpenCode من خلال التكوين.';

  @override
  String get behaviorTheseValuesWrite =>
      'تُكتب هذه القيم في `/config` على الخادم النشط وتطابق تكوين OpenCode المشترك الرسمي.';

  @override
  String get cannedAddTitle => 'إضافة رد جاهز';

  @override
  String get cannedAppendAtCursor => 'إلحاق عند المؤشر';

  @override
  String get cannedAppendAtCursorSubtitle => 'إيقاف = استبدال نص المحرر الحالي';

  @override
  String get cannedAttachFiles => 'إرفاق ملفات';

  @override
  String get cannedEditTitle => 'تعديل الرد الجاهز';

  @override
  String get cannedNewQuickReply => 'رد سريع جديد';

  @override
  String get cannedNoSuggestions => 'لا توجد اقتراحات';

  @override
  String get cannedOffMeansReplace => 'الإيقاف يعني استبدال نص الملحِّن الحالي';

  @override
  String get cannedQuickReply => 'رد سريع جديد';

  @override
  String get cannedReplace => 'استبدال';

  @override
  String get cannedScopeGlobalSubtitle => 'عطّل لعنصر خاص بالمشروع فقط';

  @override
  String get cannedScopeGlobalUnavailableSubtitle =>
      'غير متاح في السياق الحالي';

  @override
  String get cannedSendAutomaticallySubtitle =>
      'إرسال فورًا بعد إدراج هذا الرد السريع';

  @override
  String get cannedSendImmediatelyInserting =>
      'الإرسال فوراً بعد إدراج هذا الرد السريع';

  @override
  String get cannedTextLabel => 'نص';

  @override
  String get chatActionNext => 'التالي';

  @override
  String get chatActiveServerUnhealthy =>
      'الخادم النشط غير سليم. ستحاول عمليات الإرسال مرة واحدة وتفشل بسرعة حتى يتم التعافي.';

  @override
  String get chatActiveServerUnhealthyLabel => 'الخادم النشط غير سليم';

  @override
  String get chatAddServerToStart => 'أضف خادماً لبدء الدردشة.';

  @override
  String get chatAppBarMoreActions => 'مزيد من الإجراءات';

  @override
  String get chatAppBarPinAction => 'تثبيت في شريط التطبيق';

  @override
  String get chatAppBarPinDescription =>
      'سيبقى هذا الإجراء مرئياً خارج القائمة.';

  @override
  String get chatAppBarUnpinAction => 'إلغاء التثبيت من شريط التطبيق';

  @override
  String get chatAppBarUnpinDescription =>
      'سينتقل هذا الإجراء مجدداً إلى القائمة.';

  @override
  String chatBadgeConversationError(String title) {
    return '\"$title\" به خطأ.';
  }

  @override
  String chatBadgeConversationNeedsInput(String title) {
    return '\"$title\" يحتاج إلى مدخلاتك.';
  }

  @override
  String chatBadgeConversationNewReply(String title) {
    return '\"$title\" به رد جديد.';
  }

  @override
  String get chatBadgeDataSaverActive => 'توفير بيانات الهاتف نشط.';

  @override
  String get chatBadgeServerNeedsAttention => 'اتصال الخادم يحتاج إلى انتباه.';

  @override
  String get chatBadgeSyncing => 'جاري مزامنة المحادثات...';

  @override
  String get chatBlockResponsePendingDescription =>
      'سيظهر الرد في كتلة واحدة عند اكتمال هذه الجولة.';

  @override
  String get chatBlockResponsePendingTitle => 'جارٍ إنشاء الرد';

  @override
  String get chatCachedConversationsYet => 'لا توجد محادثات مخزنة مؤقتاً بعد';

  @override
  String get chatChangedFilesAvailable => 'لا تتوفر ملفات مغيرة لهذه الجلسة.';

  @override
  String chatChildrenChatProviderCurrentSessionChildren(int length) {
    return 'أبناء: $length';
  }

  @override
  String get chatChooseAgent => 'اختيار الوكيل';

  @override
  String get chatChooseDirectory => 'اختر الدليل';

  @override
  String get chatChooseEffort => 'اختيار الجهد';

  @override
  String get chatChooseFolderOpen => 'اختر مجلداً لفتحه كسياق للمشروع.';

  @override
  String get chatChooseModel => 'اختيار النموذج';

  @override
  String get chatClose => 'إغلاق';

  @override
  String chatCloseProject(String project) {
    return 'إغلاق $project';
  }

  @override
  String get chatCollapseGroup => 'طي المجموعة';

  @override
  String get chatCommandDescriptionProject => 'أمر المشروع';

  @override
  String get chatCommandSourceGeneric => 'أمر';

  @override
  String get chatCommandSourceProject => 'مشروع';

  @override
  String get chatCompactContext => 'ضغط السياق';

  @override
  String get chatComposerHintShell => 'أمر شل (Esc للخروج)';

  @override
  String get chatComposerPlaceholder => 'اكتب احتياجاتك...';

  @override
  String get chatConversation => 'المحادثة';

  @override
  String get chatConversations => 'المحادثات';

  @override
  String get chatConversationsPane => 'المحادثات';

  @override
  String chatCostLabel(double cost) {
    return 'التكلفة: \$$cost';
  }

  @override
  String get chatCouldNotRefreshSession => 'تعذر تحديث هذه المحادثة';

  @override
  String get chatCurrent => 'استخدام الحالي';

  @override
  String chatDescriptionChildren(int count) {
    return 'الأبناء: $count';
  }

  @override
  String get chatDescriptionCloseApp =>
      'إغلاق التطبيق باستخدام سلوك الإغلاق الخاص بالمنصة';

  @override
  String get chatDescriptionCycleModels => 'تبديل النماذج الحديثة';

  @override
  String get chatDescriptionCycleVariant => 'تبديل متغير النموذج';

  @override
  String get chatDescriptionDiffFilesZero => 'ملفات الاختلاف: 0';

  @override
  String get chatDescriptionFocusInput => 'التركيز على مدخلات الرسالة';

  @override
  String get chatDescriptionFocusOrCloseDrawer =>
      'التركيز على المدخلات (أو إغلاق الدرج عندما يكون مفتوحاً)';

  @override
  String get chatDescriptionForceExit => 'فرض الخروج من التطبيق';

  @override
  String get chatDescriptionNewConversation => 'محادثة جديدة';

  @override
  String get chatDescriptionNextAgent => 'العميل التالي';

  @override
  String get chatDescriptionOpenProjects =>
      'استخدم هذا الزر لفتح مشاريعك ومحادثاتك.';

  @override
  String get chatDescriptionOpenSettings => 'افتح الإعدادات';

  @override
  String get chatDescriptionPreviousAgent => 'العميل السابق';

  @override
  String get chatDescriptionProjectCommand => 'أمر المشروع';

  @override
  String get chatDescriptionQuickOpen => 'فتح سريع للملفات';

  @override
  String get chatDescriptionRefreshData => 'تحديث بيانات الدردشة';

  @override
  String get chatDescriptionStopResponse =>
      'إيقاف الاستجابة النشطة (أثناء الاستجابة)';

  @override
  String get chatDescriptionSwitchProject =>
      'استخدم هذا الزر لتبديل مجلدات المشروع والسياق.';

  @override
  String get chatDescriptionVoiceInput => 'بدء أو إيقاف الإدخال الصوتي';

  @override
  String get chatDiffFiles => 'ملفات الفروقات: 0';

  @override
  String get chatDisplay => 'العرض';

  @override
  String get chatDisplayToggles => 'مفاتيح تبديل العرض';

  @override
  String get chatDoubleESCStop => 'نقرتا ESC للإيقاف';

  @override
  String get chatEffortLockedSubConversation => 'الجهد مقفل في محادثة فرعية';

  @override
  String get chatExpandGroup => 'توسيع المجموعة';

  @override
  String get chatExportCanceled => 'تم إلغاء تصدير الجلسة';

  @override
  String get chatFailedToLoadDirectories => 'فشل تحميل الأدلة';

  @override
  String get chatFailedToLoadFile => 'فشل تحميل الملف';

  @override
  String get chatFailedToRefreshProviders => 'فشل تحديث المزودين والنماذج';

  @override
  String get chatFailedToRefreshSubConversations =>
      'فشل تحديث المحادثات الفرعية. حاول مرة أخرى.';

  @override
  String get chatFailedToStopResponse => 'فشل إيقاف الاستجابة الحالية';

  @override
  String get chatFileExplorerContents => 'المحتويات';

  @override
  String get chatFileExplorerNames => 'الأسماء';

  @override
  String get chatFilterActive => 'نشط';

  @override
  String get chatFilterAll => 'الكل';

  @override
  String get chatFilterArchived => 'مؤرشف';

  @override
  String get chatFilterDirectories => 'تصفية الأدلة';

  @override
  String get chatFilterSessions => 'تصفية الجلسات';

  @override
  String get chatForkFailed => 'فشل تفرع المحادثة';

  @override
  String get chatForked => 'تم تفرع المحادثة';

  @override
  String get chatGoToFirst => 'الانتقال إلى الرسالة الأولى';

  @override
  String get chatGoToLatest => 'الانتقال إلى أحدث رسالة';

  @override
  String chatGroupMessageCountMessages(
    String compactionLabel,
    String messageCount,
  ) {
    return '$messageCount رسائل مخفية قبل ضغط $compactionLabel';
  }

  @override
  String get chatHelloAssistant =>
      'مرحباً! أنا مساعد الذكاء الاصطناعي الخاص بك';

  @override
  String get chatHelp => 'كيف يمكنني مساعدتك؟';

  @override
  String get chatHelpMessage => 'استخدم @ للإشارات، ! للشل، / للأوامر';

  @override
  String get chatHideConversationsSidebar => 'إخفاء شريط المحادثات الجانبي';

  @override
  String get chatHideUtilitySidebar => 'إخفاء شريط الأدوات الجانبي';

  @override
  String get chatHistoryCollapsed => 'تم طي السجل السابق';

  @override
  String get chatHistoryHideEarlier => 'إخفاء الرسائل السابقة';

  @override
  String chatHistoryMessagesHidden(int count, String label) {
    return 'تم إخفاء $count رسائل قبل ضغط $label';
  }

  @override
  String get chatHistoryShowEarlier => 'إظهار الرسائل السابقة';

  @override
  String get chatKeepWorking => 'مواصلة العمل';

  @override
  String get chatLargeContentSkipped =>
      'تم تخطي المحتوى الكبير أو المشوه من أجل الاستقرار.';

  @override
  String get chatLatestToolActivity =>
      'تظل أحدث أنشطة الأدوات داخل هذه اللوحة المحدودة للحفاظ على استقرار منطقة عرض الدردشة.';

  @override
  String get chatLoadMore => 'تحميل المزيد';

  @override
  String get chatLoadingProjectContext => 'جاري تحميل سياق المشروع...';

  @override
  String get chatMainConversationUnavailable =>
      'المحادثة الرئيسية غير متاحة بعد.';

  @override
  String get chatParentConversationUnavailable =>
      'المحادثة الأصلية غير متاحة بعد.';

  @override
  String get chatMentionAgentSubtitle => 'وكيل';

  @override
  String get chatMentionFileSubtitle => 'ملف';

  @override
  String get chatMentionSymbolSubtitle => 'رمز';

  @override
  String get chatMessageAttachedFile => 'ملف مرفق';

  @override
  String get chatMessageDetails => 'تفاصيل';

  @override
  String get chatMessageHide => 'إخفاء';

  @override
  String get chatMessageLess => 'أقل';

  @override
  String get chatMessageMessagePartUnavailable => 'جزء الرسالة غير متوفر';

  @override
  String get chatMessageMetadataAvailable => 'لا تتوفر بيانات تعريفية';

  @override
  String chatMessageModelMessageModelId(String modelId) {
    return 'النموذج: $modelId';
  }

  @override
  String get chatMessageMore => 'المزيد';

  @override
  String get chatMessageOpenFile => 'فتح الملف';

  @override
  String chatMessageProviderMessageProviderId(String providerId) {
    return 'المزود: $providerId';
  }

  @override
  String get chatMessageRewindEdit => 'تراجع وتحرير من هنا';

  @override
  String get chatMessageRunningTask => 'مهمة قيد التشغيل';

  @override
  String get chatMessageSaveFile => 'حفظ الملف';

  @override
  String get chatMessageShow => 'إظهار';

  @override
  String get chatMessageShowLess => 'عرض أقل';

  @override
  String get chatMessageShowLessCompact => 'أقل';

  @override
  String get chatMessageShowMore => 'عرض المزيد';

  @override
  String get chatMessageShowMoreCompact => 'المزيد';

  @override
  String get chatMessageThinking => 'يفكر';

  @override
  String get chatMessageThinkingProcess => 'عملية التفكير';

  @override
  String get chatMessageToolCall => 'استدعاء أداة واحد';

  @override
  String chatMessageToolCalls(int count) {
    return '$count استدعاءات أدوات';
  }

  @override
  String get chatMessageToolCommand => 'أمر';

  @override
  String get chatMessageToolCommandTruncated =>
      'تم اقتطاع معاينة الأمر لتحقيق الاستقرار.';

  @override
  String get chatMessageToolDiffOmitted =>
      'تم حذف معاينة الفرق: حمولة التعديل كبيرة جدًا بحيث لا يمكن عرضها بأمان على الجوال.';

  @override
  String get chatMessageToolInput => 'الإدخال';

  @override
  String get chatMessageToolInputTruncated =>
      'تم اقتطاع معاينة الإدخال لتحقيق الاستقرار.';

  @override
  String get chatMessageToolOutputTruncated =>
      'تم اقتطاع معاينة إخراج الأداة الكبيرة لاستقرار التطبيق.';

  @override
  String chatMessageToolQueuedCount(int count) {
    return '$count في قائمة الانتظار';
  }

  @override
  String chatMessageToolRunningCount(int count) {
    return '$count قيد التشغيل';
  }

  @override
  String get chatMessageToolStatusInProgress => 'قيد المعالجة';

  @override
  String get chatMessageToolStatusNeedsAttention => 'يحتاج إلى انتباه';

  @override
  String get chatMessageToolStatusQueued => 'في الانتظار';

  @override
  String get chatMessageYou => 'أنت';

  @override
  String get chatModelLockedSubConversation => 'النموذج مقفل في محادثة فرعية';

  @override
  String get chatNewChat => 'دردشة جديدة';

  @override
  String get chatNewChatTourDescription => 'ابدأ محادثة جديدة هنا.';

  @override
  String get chatNewChatTourTitle => 'دردشة جديدة';

  @override
  String get chatNoConversationsInProject => 'لا توجد محادثات في هذا المشروع.';

  @override
  String get chatNoServerYet => 'لم يتم تكوين أي خادم بعد';

  @override
  String get chatNoSessionSelected => 'اختر أو أنشئ محادثة لبدء الدردشة';

  @override
  String get chatNoSubConversationFound =>
      'لم يتم العثور على محادثة فرعية لهذه المهمة.';

  @override
  String get chatOpenFiles => 'الملفات المفتوحة';

  @override
  String get chatOpenProject => 'فتح المشروع';

  @override
  String get chatOpenProjectFolder => 'فتح مجلد المشروع...';

  @override
  String get chatOpenProjectToLoad => 'افتح المشروع لتحميل المحادثات.';

  @override
  String get chatOpenSidebar => 'فتح الشريط الجانبي';

  @override
  String get chatPageStatusAutomaticCompactionExplanation =>
      'يحدث الضغط التلقائي مع نمو استخدام السياق.';

  @override
  String get chatPageStatusCompactNow => 'اضغط الآن';

  @override
  String get chatPageStatusCompacting => 'جاري الضغط...';

  @override
  String get chatPageStatusCompactingContextNow => 'جاري ضغط السياق الآن...';

  @override
  String get chatPageStatusContextCompacted => 'تم ضغط السياق';

  @override
  String get chatPageStatusContextUsage => 'استخدام السياق';

  @override
  String get chatPageStatusCost => 'التكلفة';

  @override
  String get chatPageStatusFailedToCompactContext => 'فشل ضغط السياق';

  @override
  String get chatPageStatusLimit => 'الحد';

  @override
  String get chatPageStatusManageServers => 'إدارة الخوادم';

  @override
  String get chatPageStatusSaver => 'موفر';

  @override
  String get chatPageStatusServer => 'الخادم';

  @override
  String get chatPageStatusSwitchServer => 'تبديل الخادم';

  @override
  String get chatPageStatusTokens => 'رموز';

  @override
  String get chatPageStatusUsage => 'الاستخدام';

  @override
  String chatPageStatusUsagePercent(int usagePercent) {
    return '$usagePercent';
  }

  @override
  String get chatPermissionAutoApproveOff =>
      'الموافقة التلقائية على الأذونات غير مفعلة';

  @override
  String get chatPermissionAutoApproveOn =>
      'الموافقة التلقائية على الأذونات مفعلة';

  @override
  String get chatProjectContext => 'سياق المشروع';

  @override
  String get chatProjectContext2 => 'سياق المشروع';

  @override
  String get chatRealtimeGlobalEvent => 'حدث عام';

  @override
  String chatRealtimeGlobalEventReason(String reason) {
    return 'حدث عام ($reason)';
  }

  @override
  String get chatRealtimeGlobalEventStale => 'حدث عام (جيل قديم)';

  @override
  String chatRealtimeMessageStreamReason(String reason) {
    return 'تدفق الرسائل ($reason)';
  }

  @override
  String get chatRealtimeRealtimeEvent => 'حدث في الوقت الفعلي';

  @override
  String chatRealtimeRealtimeEventReason(String reason) {
    return 'حدث في الوقت الفعلي ($reason)';
  }

  @override
  String get chatRealtimeRealtimeEventStale => 'حدث في الوقت الفعلي (جيل قديم)';

  @override
  String get chatRealtimeReconnectingServerTry =>
      'إعادة الاتصال بالخادم. حاول مرة أخرى بعد لحظة.';

  @override
  String get chatReasoning => 'تفكير...';

  @override
  String get chatRecentSessions => 'الجلسات الأخيرة';

  @override
  String get chatRecentSessionsToggle => 'الجلسات الأخيرة';

  @override
  String get chatRedoLastTurn => 'إعادة إجراء الدور الأخير المتراجع عنه';

  @override
  String get chatRedoNothing => 'لا يوجد شيء لإعادة فعله في هذه الجلسة';

  @override
  String get chatRefresh => 'تحديث';

  @override
  String get chatRefreshConversation => 'تعذر تحديث هذه المحادثة';

  @override
  String get chatRefreshProjects => 'تحديث المشاريع';

  @override
  String get chatRefreshSessionDetails => 'تحديث تفاصيل الجلسة';

  @override
  String chatRemoveDisplayNameHistory(String displayName) {
    return 'إزالة $displayName من السجل';
  }

  @override
  String get chatRetry => 'إعادة المحاولة';

  @override
  String get chatRetry2 => 'إعادة محاولة';

  @override
  String get chatRetryRefresh => 'إعادة محاولة التحديث';

  @override
  String get chatRetryingModelRequest => 'إعادة محاولة طلب النموذج...';

  @override
  String get chatReturnToMainConversation => 'العودة إلى المحادثة الرئيسية';

  @override
  String get chatReturnToParentConversation => 'العودة إلى المحادثة الأصلية';

  @override
  String get chatReviewChanges => 'مراجعة التغييرات';

  @override
  String get chatSearchConversations => 'البحث في المحادثات';

  @override
  String get chatSearchNextResult => 'النتيجة التالية';

  @override
  String get chatSearchNoResults => 'لا توجد نتائج';

  @override
  String get chatSearchPreviousResult => 'النتيجة السابقة';

  @override
  String chatSearchResultCount(int current, int total) {
    return 'الرسالة $current من $total';
  }

  @override
  String get chatSearchTimeline => 'البحث في المخطط الزمني';

  @override
  String get chatSelectDirectory => 'تحديد الدليل';

  @override
  String get chatSelectOrCreate => 'حدد محادثة أو أنشئ واحدة لبدء الدردشة';

  @override
  String get chatSelectProjectBelow => 'حدد مشروعاً أدناه.';

  @override
  String get chatServerSelectedModel => 'النموذج المختار من الخادم';

  @override
  String get chatSessionActions => 'إجراءات الجلسة';

  @override
  String chatSessionChatSessionSession(String title) {
    return 'جلسة الدردشة: $title';
  }

  @override
  String chatSessionConversationNextAction(String nextAction) {
    return 'محادثة $nextAction';
  }

  @override
  String get chatSessionConversations => 'لا توجد محادثات';

  @override
  String get chatSessionCreateConversationStart =>
      'أنشئ محادثة جديدة لبدء الدردشة';

  @override
  String get chatSessionTabsToggle => 'علامات تبويب الجلسات';

  @override
  String chatSessionsLength(int length) {
    return '$length';
  }

  @override
  String get chatSetUpServer => 'إعداد الخادم';

  @override
  String get chatSettings => 'الإعدادات';

  @override
  String get chatShortcutsCloseApp =>
      'إغلاق التطبيق باستخدام سلوك إغلاق المنصة';

  @override
  String get chatShortcutsCycleModels => 'تبديل النماذج الأخيرة';

  @override
  String get chatShortcutsCycleVariant => 'تبديل متغير النموذج';

  @override
  String get chatShortcutsFocusInput => 'التركيز على إدخال الرسالة';

  @override
  String get chatShortcutsFocusInputCloseDrawer =>
      'التركيز على الإدخال (أو إغلاق الدرج عند فتحه)';

  @override
  String get chatShortcutsForceExit => 'فرض الخروج من التطبيق';

  @override
  String get chatShortcutsNewConversation => 'محادثة جديدة';

  @override
  String get chatShortcutsNextAgent => 'الوكيل التالي';

  @override
  String get chatShortcutsOpenSettings => 'فتح الإعدادات';

  @override
  String get chatShortcutsPreviousAgent => 'الوكيل السابق';

  @override
  String get chatShortcutsQuickOpen => 'فتح الملفات بسرعة';

  @override
  String get chatShortcutsRefreshChat => 'تحديث بيانات الدردشة';

  @override
  String get chatShortcutsStartStopVoice => 'بدء أو إيقاف الإدخال الصوتي';

  @override
  String get chatShortcutsStopResponse =>
      'إيقاف الاستجابة النشطة (أثناء الاستجابة)';

  @override
  String get chatSidebarAccess => 'الوصول إلى الشريط الجانبي';

  @override
  String get chatSortMostRecent => 'الأحدث';

  @override
  String get chatSortOldest => 'الأقدم';

  @override
  String get chatSortRecent => 'الأخيرة';

  @override
  String get chatSortSessions => 'ترتيب الجلسات';

  @override
  String get chatSortTitle => 'العنوان';

  @override
  String get chatStartVoiceInput => 'بدء الإدخال الصوتي';

  @override
  String get chatStartingVoiceInput => 'جاري بدء الإدخال الصوتي';

  @override
  String get chatStatusBusy => 'الحالة: مشغول';

  @override
  String get chatStatusPatching => 'جاري الترقيع';

  @override
  String chatStatusPatchingMultipleFiles(int count) {
    return 'جاري ترقيع $count ملفات';
  }

  @override
  String get chatStatusPatchingOneFile => 'جاري ترقيع ملف واحد';

  @override
  String get chatStatusRetry => 'الحالة: إعادة المحاولة';

  @override
  String chatStatusRetryCount(int count) {
    return 'الحالة: إعادة المحاولة #$count';
  }

  @override
  String get chatStatusSubsession => 'جلسة فرعية';

  @override
  String get chatStatusThinking => 'جاري التفكير...';

  @override
  String get chatStopVoiceInput => 'إيقاف الإدخال الصوتي';

  @override
  String chatSyncLabel(String label) {
    return 'مزامنة: $label';
  }

  @override
  String get chatTasks => 'المهام';

  @override
  String get chatTasksAvailableSession => 'لا تتوفر مهام لهذه الجلسة.';

  @override
  String get chatTipAcceptanceCriteria =>
      'نصيحة: أضف معايير قبول للتغييرات الكبيرة';

  @override
  String get chatTipAskForPlan => 'نصيحة: اطلب خطة أولا للمهام الكبيرة';

  @override
  String get chatTipBeSpecific =>
      'نصيحة: كن محددًا - المطالبات الأقصر تحصل على إجابات أسرع';

  @override
  String get chatTipBreakTasks => 'نصيحة: قسم المهام الكبيرة إلى مطالبات أصغر';

  @override
  String get chatTipCompareOptions =>
      'نصيحة: اطلب بدائل عندما تكون المفاضلات غير واضحة';

  @override
  String get chatTipContextKnob =>
      'نصيحة: اضغط على مقبض السياق لرؤية تفاصيل الاستخدام';

  @override
  String get chatTipDefineVerification =>
      'نصيحة: قل أي اختبارات أو فحوصات يجب أن تنجح';

  @override
  String get chatTipLongPressSend =>
      'نصيحة: اضغط مطولاً على إرسال لإدراج سطر جديد';

  @override
  String get chatTipMentionFiles =>
      'نصيحة: استخدم @ للإشارة إلى الملفات في مطالبك';

  @override
  String get chatTipNameRelevantFiles =>
      'نصيحة: اذكر الملفات أو الشاشات أو الأوامر ذات الصلة';

  @override
  String get chatTipProvideContext =>
      'نصيحة: قدم سياقًا - الصق رسائل الخطأ والسجلات';

  @override
  String get chatTipRenameConversation =>
      'نصيحة: اضغط على العنوان لإعادة تسمية المحادثة';

  @override
  String get chatTipRequestDocs => 'نصيحة: اطلب تحديث الوثائق عند تغير السلوك';

  @override
  String get chatTipShareAttempts => 'نصيحة: شارك ما جربته والخطأ الدقيق';

  @override
  String get chatTipShellCommands =>
      'نصيحة: استخدم ! في البداية لتشغيل أوامر شل';

  @override
  String get chatTipSlashCommands =>
      'نصيحة: استخدم / للوصول إلى أوامر الشرطة المائلة';

  @override
  String get chatTipStartWithGoal => 'نصيحة: ابدأ بالهدف النهائي';

  @override
  String get chatTipStateConstraints =>
      'نصيحة: اذكر القيود التي يجب على الوكيل الحفاظ عليها';

  @override
  String get chatTipStepByStep =>
      'نصيحة: اطلب خطوة بخطوة عند تصحيح المشكلات المعقدة';

  @override
  String get chatTipUseFocusedAgents =>
      'نصيحة: اختر وكيلا مركزا للتخطيط أو المراجعة أو البناء';

  @override
  String get chatToggleSidebars => 'تبديل الأشرطة الجانبية';

  @override
  String chatTokensLabel(int total) {
    return 'الرموز: $total';
  }

  @override
  String get chatTourProjectsConversations =>
      'استخدم هذا الزر لفتح مشاريعك ومحادثاتك.';

  @override
  String get chatTourSidebarProjectTools =>
      'استخدم هذه القائمة لإظهار الشريط الجانبي للمحادثات وأدوات المشروع.';

  @override
  String get chatTourSwitchFolders =>
      'استخدم هذا الزر لتبديل مجلدات المشروع والسياق.';

  @override
  String get chatUndoLastTurn => 'التراجع عن الدور الأخير';

  @override
  String get chatUndoNothing => 'لا يوجد شيء للتراجع عنه في هذه الجلسة';

  @override
  String get chatUseCurrent => 'استخدام الحالي';

  @override
  String get chatWaitingForNetworkConnection => 'انتظار الاتصال بالشبكة...';

  @override
  String get chatWelcomeMessage => 'مرحباً! أنا مساعدك الذكي.';

  @override
  String get chatWelcomeSubmessage => 'كيف يمكنني مساعدتك اليوم؟';

  @override
  String get chatWorkBoundedPanelExplanation =>
      'تظل أحدث أنشطة الأدوات داخل هذه اللوحة المحدودة للحفاظ على استقرار منطقة عرض الدردشة.';

  @override
  String get chatWorkExpand => 'توسيع';

  @override
  String get chatWorkHide => 'إخفاء';

  @override
  String get chatWorkMessageOne => 'رسالة عمل واحدة';

  @override
  String chatWorkMessagesMultiple(int count) {
    return '$count رسائل عمل';
  }

  @override
  String get chatWorkShow => 'إظهار';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonCopiedToClipboard => 'تم النسخ إلى الحافظة';

  @override
  String get commonDelete => 'حذف';

  @override
  String get commonFile => 'ملف';

  @override
  String get commonReset => 'إعادة تعيين';

  @override
  String get commonSave => 'حفظ';

  @override
  String get compactionAutomatic => 'تلقائي';

  @override
  String get compactionManual => 'يدوي';

  @override
  String get composerAddAttachment => 'إضافة مرفق';

  @override
  String get composerAttachFiles => 'إرفاق ملفات';

  @override
  String get composerCannedAppendAtCursor => 'إلحاق عند المؤشر';

  @override
  String get composerCannedLabel => 'تسمية (اختياري)';

  @override
  String get composerCannedNoReplies => 'لا توجد ردود سريعة بعد.';

  @override
  String get composerCannedReplace => 'استبدال';

  @override
  String get composerCannedSave => 'حفظ';

  @override
  String get composerCannedScopeGlobal => 'عام';

  @override
  String get composerCannedScopeProject => 'للمشروع فقط';

  @override
  String get composerCannedSendAutomatically => 'إرسال تلقائياً';

  @override
  String get composerCannedText => 'النص';

  @override
  String get composerChatInput => 'مدخلات الدردشة';

  @override
  String get composerDeleteAction => 'حذف';

  @override
  String get composerDropHint => 'أفلت الصور أو ملفات PDF للإرفاق';

  @override
  String get composerPastedImageName => 'صورة ملصقة';

  @override
  String get composerEdit => 'تعديل';

  @override
  String get composerExtras => 'إضافات';

  @override
  String get composerExtrasHide => 'إخفاء الإضافات';

  @override
  String get composerNewQuickReply => 'رد سريع جديد';

  @override
  String get composerSelectImages => 'تحديد صور';

  @override
  String get composerSelectPdf => 'تحديد PDF';

  @override
  String get composerSend => 'إرسال';

  @override
  String get composerShellMode => 'وضع الصدفة (Shell)';

  @override
  String get desktopWindowClose => 'إغلاق';

  @override
  String get desktopWindowMaximize => 'تكبير';

  @override
  String get desktopWindowMinimize => 'تصغير';

  @override
  String get desktopWindowRestore => 'استعادة';

  @override
  String get dialogDownload => 'تنزيل';

  @override
  String get dialogLanguage => 'اللغة';

  @override
  String get dialogMoonshineModelSize => 'حجم النموذج';

  @override
  String get dialogMoonshineVoiceSetup => 'إعداد صوت Moonshine';

  @override
  String get dialogParakeetModel => 'نموذج Parakeet';

  @override
  String get dialogParakeetVoiceSetup => 'إعداد صوت Parakeet';

  @override
  String get dialogSenseVoiceModel => 'نموذج SenseVoice';

  @override
  String get dialogSenseVoiceSetup => 'إعداد SenseVoice';

  @override
  String get dialogVoiceInputSetup => 'إعداد الإدخال الصوتي';

  @override
  String get errorAnErrorOccurred => 'حدث خطأ';

  @override
  String get errorAuthRequired => 'المصادقة مطلوبة';

  @override
  String get errorAuthRequiredDesc =>
      'فشلت المصادقة. أعد توصيل المزود وحاول مرة أخرى.';

  @override
  String get errorConnectionFailed => 'فشل الاتصال';

  @override
  String get errorConnectionFailedDesc =>
      'تعذر الوصول إلى الخادم. تحقق من الاتصال وحالة الخادم.';

  @override
  String get errorFormatAuthenticationFailedReconnect =>
      'فشلت المصادقة. أعد توصيل المزود وحاول مجدداً.';

  @override
  String get errorFormatProviderTemporarilyUnavailable =>
      'المزود غير متوفر مؤقتاً. حاول مجدداً بعد قليل.';

  @override
  String get errorFormatQuotaExceededCheck =>
      'تم تجاوز الحصة النسبية. تحقق من خطة المزود أو الفواتير الخاصة بك.';

  @override
  String get errorFormatRateLimitExceeded =>
      'تم تجاوز حد المعدل. انتظر لحظة وحاول مجدداً.';

  @override
  String get errorFormatServerErrorPlease =>
      'خطأ في الخادم. يرجى المحاولة مرة أخرى.';

  @override
  String get errorFormatServiceTemporarilyUnavailable =>
      'الخدمة غير متوفرة مؤقتاً. قد يكون الخادم قيد التشغيل - يرجى المحاولة مجدداً بعد قليل.';

  @override
  String get errorFormatUnableReachServer =>
      'تعذر الوصول إلى الخادم. تحقق من الاتصال وحالة الخادم.';

  @override
  String get errorProviderUnavailable => 'المزود غير متاح';

  @override
  String get errorProviderUnavailableDesc =>
      'المزود غير متاح مؤقتًا. حاول مرة أخرى قريبًا.';

  @override
  String get errorQuotaExceeded => 'تم تجاوز الحصة';

  @override
  String get errorQuotaExceededDesc =>
      'تم تجاوز الحصة. تحقق من خطة المزود أو الفوترة الخاصة بك.';

  @override
  String get errorRateLimitExceeded => 'تم تجاوز حد المعدل';

  @override
  String get errorRateLimitExceededDesc =>
      'تم تجاوز حد المعدل. انتظر لحظة وحاول مرة أخرى.';

  @override
  String get errorServerError => 'خطأ في الخادم';

  @override
  String get errorServerErrorDesc => 'خطأ في الخادم. يرجى المحاولة مرة أخرى.';

  @override
  String get errorServiceUnavailable => 'الخدمة غير متاحة';

  @override
  String get errorServiceUnavailableDesc =>
      'الخدمة غير متاحة مؤقتًا. قد يكون الخادم قيد التشغيل - يرجى المحاولة مرة أخرى قريبًا.';

  @override
  String get fileActionAttachmentDataDecoded => 'تعذر فك تشفير بيانات المرفق.';

  @override
  String get fileActionAttachmentPathEmpty => 'مسار المرفق فارغ.';

  @override
  String get fileActionAttachmentPayloadEmpty => 'حمولة المرفق فارغة.';

  @override
  String get fileActionAttachmentProvideValid =>
      'المرفق لا يوفر موقعاً صالحاً.';

  @override
  String get fileActionAttachmentSavedDevice =>
      'تعذر حفظ المرفق على هذا الجهاز.';

  @override
  String fileActionAttachmentSavedOutputFile(String path) {
    return 'تم حفظ المرفق في $path وفتحه.';
  }

  @override
  String fileActionAttachmentSavedOutputFile2(String path) {
    return 'تم حفظ المرفق في $path.';
  }

  @override
  String fileActionAttachmentSavedSavedPath(String savedPath) {
    return 'تم حفظ المرفق في $savedPath.';
  }

  @override
  String get fileActionLocalAttachmentFound =>
      'لم يتم العثور على المرفق المحلي على هذا الجهاز.';

  @override
  String get fileActionSaveCanceled => 'تم إلغاء الحفظ.';

  @override
  String get fileActionUnableOpenLocal => 'تعذر فتح المرفق المحلي.';

  @override
  String get filesAddChat => 'إضافة إلى الدردشة';

  @override
  String get filesAutosave => 'حفظ تلقائي';

  @override
  String get filesAutosaveOn => 'تم تفعيل الحفظ التلقائي';

  @override
  String get filesAutosaveOff => 'تم إيقاف الحفظ التلقائي';

  @override
  String get filesRedo => 'إعادة';

  @override
  String get filesUndo => 'تراجع';

  @override
  String get filesBinaryFilePreview => 'معاينة الملف الثنائي غير متوفرة.';

  @override
  String get filesClear => 'مسح';

  @override
  String get filesContents => 'المحتويات';

  @override
  String get filesDuplicate => 'تكرار';

  @override
  String get filesDuplicated => 'تم تكرار الملف';

  @override
  String get filesFileEmpty => 'الملف فارغ.';

  @override
  String get filesAlreadyExists => 'يوجد ملف أو مجلد بهذا الاسم بالفعل.';

  @override
  String get filesCopyPath => 'نسخ المسار';

  @override
  String get filesCreateFileTitle => 'إنشاء ملف';

  @override
  String get filesCreateFolderTitle => 'إنشاء مجلد';

  @override
  String get filesDelete => 'حذف';

  @override
  String filesDeleteConfirm(String name) {
    return 'حذف $name؟ لا يمكن التراجع عن هذا. سيتم حذف المجلدات ومحتوياتها.';
  }

  @override
  String filesDeleteTitle(String name) {
    return 'حذف $name';
  }

  @override
  String get filesFilesFound => 'لم يتم العثور على ملفات';

  @override
  String get filesFileCreated => 'تم إنشاء الملف.';

  @override
  String get filesFolderCreated => 'تم إنشاء المجلد.';

  @override
  String get filesHideSidebar => 'إخفاء شريط الملفات الجانبي';

  @override
  String get filesInvalidName => 'أدخل اسمًا صالحًا دون فواصل مسار.';

  @override
  String get filesNameHint => 'الاسم';

  @override
  String get filesNew => 'جديد';

  @override
  String get filesNewFile => 'ملف جديد';

  @override
  String get filesNewFolder => 'مجلد جديد';

  @override
  String get filesNames => 'الأسماء';

  @override
  String filesOpenFilesFileState(int length) {
    return 'الملفات المفتوحة ($length)';
  }

  @override
  String get filesQuickOpen => 'فتح سريع';

  @override
  String get filesQuickOpenFile => 'فتح ملف سريع';

  @override
  String get filesOperationFailed => 'فشلت عملية الملفات.';

  @override
  String get filesOperationUnavailable =>
      'عمليات الملفات غير متاحة لهذا الخادم.';

  @override
  String get filesOutsideRoot => 'المسار خارج جذر المشروع.';

  @override
  String get filesPathCopied => 'تم نسخ المسار.';

  @override
  String get filesPathMissing => 'المسار غير موجود.';

  @override
  String get filesPermissionDenied => 'تم رفض الإذن.';

  @override
  String get filesRefresh => 'تحديث الملفات';

  @override
  String get filesRename => 'إعادة تسمية';

  @override
  String filesRenameTitle(String name) {
    return 'إعادة تسمية $name';
  }

  @override
  String get filesRenamed => 'تمت إعادة التسمية.';

  @override
  String get filesRootDeleteBlocked => 'لا يمكن حذف جذر المشروع.';

  @override
  String get filesSearchHint => 'البحث في الملفات بالاسم أو المسار';

  @override
  String get filesDeleted => 'تم الحذف.';

  @override
  String get filesTitle => 'الملفات';

  @override
  String get forwardAction => 'إعادة توجيه';

  @override
  String get forwardAllFailed => 'تعذّر إعادة التوجيه إلى أي جلسة';

  @override
  String get forwardCancel => 'إلغاء';

  @override
  String get forwardDialogSubtitle => 'حدّد محادثة واحدة أو أكثر';

  @override
  String get forwardDialogTitle => 'إعادة توجيه إلى…';

  @override
  String get forwardLoading => 'جارٍ تحميل الجلسات…';

  @override
  String get forwardNoOpenProjects => 'لا توجد مشاريع مفتوحة فيها جلسات';

  @override
  String get forwardNoProviderModel => 'حدّد مزودًا ونموذجًا قبل إعادة التوجيه';

  @override
  String get forwardNoSessions => 'لا توجد جلسات حديثة';

  @override
  String forwardPartial(int success, int total) {
    return 'تمت إعادة التوجيه إلى $success من $total';
  }

  @override
  String forwardProvenanceLabel(String origin) {
    return 'أُعيدت التوجيه من: $origin';
  }

  @override
  String get forwardRetry => 'إعادة المحاولة';

  @override
  String get forwardSearchHint => 'بحث';

  @override
  String forwardSelectedCount(int count) {
    return 'تم تحديد $count';
  }

  @override
  String get forwardSend => 'إرسال';

  @override
  String get forwardServerOffline => 'الخادم غير متصل';

  @override
  String get forwardShortcutHint => 'Ctrl+Shift+F';

  @override
  String forwardSuccess(int count) {
    return 'تمت إعادة التوجيه إلى $count جلسات';
  }

  @override
  String get forwardUndo => 'تراجع';

  @override
  String get forwardUndoFailed => 'تعذّر التراجع عن إعادة التوجيه';

  @override
  String get logsAppLogs => 'سجلات التطبيق';

  @override
  String get logsClear => 'مسح السجلات';

  @override
  String get logsCloseSearch => 'إغلاق البحث';

  @override
  String get logsCopyFiltered => 'نسخ السجلات المصفاة';

  @override
  String get logsEnableLogging => 'تفعيل سجلات التطبيق';

  @override
  String get logsEnableLoggingAction => 'تفعيل السجلات';

  @override
  String get logsEnableLoggingDescription =>
      'يجمع سجلات تشخيصية في الذاكرة. اتركه معطلاً إلا عند استكشاف مشكلة.';

  @override
  String get logsEntryContext => 'السياق';

  @override
  String get logsEntryTags => 'الوسوم';

  @override
  String get logsFilterAll => 'الكل';

  @override
  String get logsFilterByTag => 'الوسم';

  @override
  String get logsLevel => 'المستوى';

  @override
  String get logsLoggingDisabledDescription =>
      'لا يجمع CodeWalk سجلات تفصيلية للتطبيق. فعّل السجلات فقط عند الحاجة إلى التشخيص.';

  @override
  String get logsLoggingDisabledTitle => 'السجلات معطلة';

  @override
  String get logsMeasurePerformance => 'قياس الأداء';

  @override
  String get logsMeasurePerformanceDescription =>
      'يسجل زمن العمليات المكلفة في التطبيق. اتركه معطلاً إلا عند تشخيص البطء.';

  @override
  String get logsNoLogsYet => 'لم يتم التقاط أي سجلات بعد.';

  @override
  String get logsNoMatchingLogs => 'لا توجد سجلات تطابق الفلاتر الحالية.';

  @override
  String get logsNoPerformanceData =>
      'لا توجد سجلات أداء تطابق عوامل التصفية الحالية.';

  @override
  String get logsNoTaskData => 'لا توجد مهام تطابق عوامل التصفية الحالية.';

  @override
  String logsPerformanceDuration(int elapsedMs) {
    return '$elapsedMs ms';
  }

  @override
  String get logsPerformanceFilter => 'الأداء';

  @override
  String logsPerformanceTileTitle(
    int elapsedMs,
    String operation,
    String status,
  ) {
    return 'الأداء $operation | $elapsedMs ms | $status';
  }

  @override
  String get logsSearch => 'البحث في السجلات';

  @override
  String logsShowingOrderedLength(int length, int length2) {
    return 'عرض $length من $length2 إدخالات';
  }

  @override
  String get logsSlowestPerformance => 'أبطأ سجلات الأداء';

  @override
  String get logsSlowestTasks => 'أبطأ المهام';

  @override
  String get logsTagCustomHint => 'اسم الوسم (مثال: task:select_session)';

  @override
  String get logsTagCustomAction => 'مخصص...';

  @override
  String logsTaskDuration(int elapsedMs, String operation) {
    return '$operation — $elapsedMs مللي ثانية';
  }

  @override
  String get logsTaskStatusCanceled => 'ملغاة';

  @override
  String get logsTaskStatusError => 'خطأ';

  @override
  String get logsTaskStatusOk => 'حسنًا';

  @override
  String get logsTimeRange => 'النطاق الزمني';

  @override
  String get mathExpressionLabel => 'رياضيات';

  @override
  String get mermaidCopySourceTooltip => 'نسخ المصدر';

  @override
  String get mermaidDiagramLabel => 'مخطط Mermaid';

  @override
  String get modelAuto => 'تلقائي';

  @override
  String get modelChooseAgent => 'اختر الوكيل';

  @override
  String get modelFavorites => 'المفضلة';

  @override
  String get modelFree => 'مجاني';

  @override
  String get modelLabelBaseEnglish => 'أساسي (إنجليزي)';

  @override
  String get modelLabelParakeet => 'Parakeet V3 (25 لغة أوروبية)';

  @override
  String get modelLabelSenseVoice => 'SenseVoice (zh/en/ja/ko/yue)';

  @override
  String get modelLabelTinyEnglish => 'Tiny (إنجليزي)';

  @override
  String get modelLoadingModels => 'جاري تحميل النماذج';

  @override
  String get modelModelsFound => 'لم يتم العثور على نماذج';

  @override
  String get modelRetryModels => 'إعادة محاولة تحميل النماذج';

  @override
  String get modelSearchHint => 'البحث عن نموذج أو مزود';

  @override
  String get msgBatterySettingsFailed =>
      'تعذر فتح إعدادات تحسين بطارية Android.';

  @override
  String get msgBatterySettingsOpened =>
      'تم فتح إعدادات بطارية Android. اسمح باستهلاك غير مقيد للبطارية لتطبيق CodeWalk.';

  @override
  String get msgClearUsernameNeedsConfigEdit =>
      'لا يزال مسح اسم مستخدم محادثة OpenCode يتطلب تعديل التكوين خارج التطبيق.';

  @override
  String get msgCommandCopied => 'تم نسخ الأمر';

  @override
  String get msgCopiedToClipboard => 'تم النسخ إلى الحافظة';

  @override
  String get msgEnterUsernameToSave =>
      'أدخل اسم مستخدم لحفظ اسم مخصص لمحادثة OpenCode.';

  @override
  String get msgFailedToSendMessage =>
      'فشل إرسال الرسالة. تم الاحتفاظ بالمسودة لإعادة المحاولة.';

  @override
  String get msgFailedToStartVoiceInput => 'فشل بدء الإدخال الصوتي';

  @override
  String msgFilePathNotFound(String path) {
    return 'الملف غير موجود: $path';
  }

  @override
  String get msgFilteredLogsCopied => 'تم نسخ السجلات المصفاة إلى الحافظة';

  @override
  String get msgInfoAgent => 'الوكيل';

  @override
  String get msgInfoCompaction => 'ضغط';

  @override
  String msgInfoCost(String cost) {
    return 'التكلفة: \$$cost';
  }

  @override
  String get msgInfoMessageInfo => 'معلومات الرسالة';

  @override
  String msgInfoModel(String modelId) {
    return 'النموذج: $modelId';
  }

  @override
  String get msgInfoNoMetadata => 'لا تتوفر بيانات تعريفية';

  @override
  String msgInfoPartDescriptionModel(String description, String model) {
    return '$description$model';
  }

  @override
  String get msgInfoPatch => 'تصحيح';

  @override
  String msgInfoProvider(String providerId) {
    return 'المزود: $providerId';
  }

  @override
  String get msgInfoRetry => 'إعادة محاولة';

  @override
  String get msgInfoSnapshot => 'لقطة';

  @override
  String msgInfoSubtaskPartAgent(String agent) {
    return 'مهمة فرعية ($agent)';
  }

  @override
  String msgInfoTokens(int total) {
    return 'الرموز (Tokens): $total';
  }

  @override
  String get msgInfoUndoThisTurn => 'تراجع عن هذا الدور';

  @override
  String get msgInfoView => 'عرض';

  @override
  String get msgNoSystemSoundsFound =>
      'لم يتم العثور على أي صوت للنظام على هذا الجهاز.';

  @override
  String get msgNoValidFilesSelected => 'لم يتم تحديد ملفات صالحة';

  @override
  String get msgSomeSelectedFilesNotAttached =>
      'تعذر إرفاق بعض الملفات المحددة.';

  @override
  String get msgReadAloud => 'القراءة بصوت عالٍ';

  @override
  String get msgReadAloudNotAvailable =>
      'ميزة تحويل النص إلى كلام غير متوفرة على هذا الجهاز.';

  @override
  String get msgSetupDebugCopied => 'تم نسخ تشخيص إعداد OpenCode إلى الحافظة';

  @override
  String get msgShareAsImage => 'مشاركة كصورة';

  @override
  String get msgShareAsImageFailed => 'تعذر مشاركة الرسالة كصورة.';

  @override
  String get msgShareAsImageSubject => 'رسالة CodeWalk';

  @override
  String get msgShareAsImageTooTall => 'الرسالة طويلة جداً لمشاركتها كصورة.';

  @override
  String get msgStopReadAloud => 'إيقاف القراءة';

  @override
  String get msgSystemSoundPickerUnavailable =>
      'منتقي أصوات النظام غير متوفر على هذه المنصة.';

  @override
  String get msgUpdatedButRefreshFailed =>
      'تم تحديث إعداد الخادم، ولكن تعذر تحديث مزودي الدردشة.';

  @override
  String get msgVoiceInputUnavailable =>
      'الإدخال الصوتي غير متوفر على هذا الجهاز';

  @override
  String get notifAndroidBatteryOptimization => 'تحسين بطارية Android';

  @override
  String get notifConversationUpdates => 'تحديثات المحادثة';

  @override
  String get notifNotificationsArriveReopening =>
      'إذا كانت الإشعارات تصل فقط عند إعادة فتح التطبيق، فاسمح لـ CodeWalk بالتشغيل دون تحسين على هذا الجهاز.';

  @override
  String get notifResponseRunningKeep =>
      'عندما تكون الاستجابة قيد التشغيل، احتفظ بالوقت الفعلي نشطاً لفترة وجيزة بعد مغادرة التطبيق.';

  @override
  String notifSelectedSoundLabel(String soundLabel) {
    return 'محدد: $soundLabel';
  }

  @override
  String get notificationAgentFinished => 'أنهى العميل الاستجابة الحالية.';

  @override
  String get notificationConversationUpdates => 'تحديثات المحادثة';

  @override
  String get notificationOpenToClear =>
      'افتح هذه المحادثة لمسح الإشعارات ذات الصلة.';

  @override
  String get notificationSession => 'جلسة';

  @override
  String get notificationSoundLoadFailed => 'فشل تحميل أصوات نظام أندرويد';

  @override
  String get onboardingAIGeneratedTitles =>
      'العناوين المولدة بالذكاء الاصطناعي';

  @override
  String get onboardingAddServerLater =>
      'يمكنك إضافة خادم لاحقاً من الإعدادات > الخوادم.';

  @override
  String get onboardingAddedButHealthCheckFailed =>
      'تمت إضافة الخادم ولكن فشل فحص الحالة. قد لا يزال قيد التشغيل.';

  @override
  String get onboardingAlmostInstallOpenCode =>
      'لقد اقتربت من الانتهاء. قم بتثبيت OpenCode أولاً، ثم قم بتوصيل CodeWalk بعنوان URL للخادم.';

  @override
  String onboardingAppProviderLocalSetupLogsLength(int length, int length2) {
    return '$length سطور سجل الإعداد و $length2 أحداث الإعداد متاحة في شاشة تصحيح الإعداد المنفصلة.';
  }

  @override
  String get onboardingAuthenticate => 'المصادقة';

  @override
  String get onboardingAvailable => 'متاح';

  @override
  String get onboardingAvailableOnlyDesktop =>
      'متاح فقط على أجهزة الكمبيوتر (Linux/macOS/Windows).';

  @override
  String get onboardingBasicAuthTip =>
      'قم بتمكين المصادقة الأساسية فقط إذا كان خادم OpenCode الخاص بك محميًا بكلمة مرور.';

  @override
  String get onboardingChooseAnotherPath => 'اختر مساراً آخر';

  @override
  String get onboardingChooseHowToSetup => 'اختر كيفية إعداد الخادم الخاص بك';

  @override
  String get onboardingClear => 'مسح';

  @override
  String get onboardingCloudflareAuthFailed => 'فشلت مصادقة Cloudflare Access.';

  @override
  String get onboardingCodeWalkAppOpenCode =>
      'CodeWalk هو التطبيق. OpenCode هو المحرك الذي يتصل به.';

  @override
  String get onboardingConnectRunningServer => 'الاتصال بخادم قيد التشغيل';

  @override
  String get onboardingConnectionIssue => 'مشكلة في الاتصال';

  @override
  String get onboardingConnectionSaved => 'تم حفظ اتصال الخادم بنجاح.';

  @override
  String get onboardingConnectionTips => 'نصائح الاتصال';

  @override
  String get onboardingConnectionUpdated => 'تم تحديث اتصال الخادم بنجاح.';

  @override
  String get onboardingContinue => 'استمرار';

  @override
  String get onboardingContinueServerURL => 'المتابعة إلى عنوان URL للخادم';

  @override
  String get onboardingCopyLoginURL => 'نسخ عنوان URL لتسجيل الدخول';

  @override
  String get onboardingCouldNotVerify => 'تعذر التحقق من اتصال الخادم.';

  @override
  String get onboardingDefaultURLEmulator =>
      'عنوان URL الافتراضي، واسترجاع المحاكي، والمصادقة، ومساعدة استكشاف الأخطاء.';

  @override
  String onboardingDesktopOnlyDiagnose(String appName) {
    return 'سطح المكتب فقط: يمكن لـ $appName تشخيص وتثبيت وتشغيل OpenCode نيابة عنك.';
  }

  @override
  String get onboardingDetailedSetupEvents =>
      'تم التقاط أحداث إعداد مفصلة لاستكشاف الأخطاء وإصلاحها.';

  @override
  String get onboardingDonShowAgain => 'عدم الإظهار مرة أخرى';

  @override
  String get onboardingDone => 'تم';

  @override
  String get onboardingEditServer => 'تعديل الخادم';

  @override
  String get onboardingEditServerConnection => 'تعديل اتصال الخادم';

  @override
  String get onboardingEmulatorRemap =>
      'على محاكي أندرويد، يتم إعادة تعيين localhost و 127.0.0.1 إلى 10.0.2.2 تلقائيًا.';

  @override
  String get onboardingEnterServerUrl => 'أدخل عنوان URL للخادم';

  @override
  String get onboardingExisting => 'استخدام الحالي';

  @override
  String get onboardingExplainInstallOpenCode =>
      'شرح كيفية تثبيت OpenCode، وبدء تشغيل الخادم، ثم الاتصال من CodeWalk.';

  @override
  String get onboardingFailed => 'فشل';

  @override
  String get onboardingGoodOptionDesktop => 'خيار أول جيد على سطح المكتب';

  @override
  String get onboardingHealthCheckFailedMayBeStarting =>
      'فشل فحص حالة الخادم. قد لا يزال قيد التشغيل.';

  @override
  String get onboardingInstallBinary => 'تثبيت الملف الثنائي (Binary)';

  @override
  String get onboardingInstallBun => 'التثبيت عبر Bun';

  @override
  String get onboardingInstallBunOpenCode => 'تثبيت Bun + OpenCode';

  @override
  String get onboardingInstallNpm => 'التثبيت عبر npm';

  @override
  String get onboardingInstallRunOpenCode =>
      'تثبيت وتشغيل OpenCode مباشرة من CodeWalk على سطح المكتب.';

  @override
  String get onboardingInvalidUrl => 'عنوان URL غير صالح';

  @override
  String get onboardingLabel => 'تسمية (اختياري)';

  @override
  String get onboardingLabelHint => 'خادمي';

  @override
  String onboardingLatestOutputAppProvider(String localServerLastOutput) {
    return 'آخر إخراج: $localServerLastOutput';
  }

  @override
  String get onboardingLetCodeWalkSet => 'دع CodeWalk يقوم بإعداده محلياً';

  @override
  String get onboardingLocalServerSetup => 'إعداد الخادم المحلي';

  @override
  String get onboardingManagedLocalServer => 'خادم محلي مدار';

  @override
  String get onboardingManagedLocalServer2 =>
      'يتوفر وضع الخادم المحلي المدار فقط في نسخ سطح المكتب (Linux/macOS/Windows).';

  @override
  String onboardingNeedsOpenCodeServer(String appName) {
    return 'يحتاج $appName إلى خادم OpenCode قبل أن يتمكن من مساعدتك في التعليمات البرمجية الخاصة بك.';
  }

  @override
  String get onboardingNotAvailable => 'غير متاح';

  @override
  String get onboardingNotWritable => 'غير قابل للكتابة';

  @override
  String get onboardingOpenCode => 'ما هو OpenCode؟';

  @override
  String get onboardingOpenCodeRunningDevice =>
      'لدي بالفعل OpenCode يعمل على هذا الجهاز أو في مكان ما على شبكتي.';

  @override
  String get onboardingOpenCodeRunsLocally =>
      'يعمل OpenCode محلياً أو على خادم ويشغل ميزات ترميز الذكاء الاصطناعي داخل CodeWalk. إذا كان OpenCode يعمل بالفعل، فاتصل به. وإلا، فاختر أحد مسارات الإعداد الإرشادية أدناه.';

  @override
  String get onboardingOpenTailscaleLogin =>
      'تعذر فتح عنوان URL لتسجيل الدخول إلى Tailscale.';

  @override
  String get onboardingPassword => 'كلمة المرور';

  @override
  String get onboardingPasswordRequired => 'أدخل كلمة المرور';

  @override
  String get onboardingPickSetupPath =>
      'اختر مسار الإعداد الذي يطابق إعداد OpenCode الحالي الخاص بك.';

  @override
  String get onboardingPreconditionDirectoryNotWritable =>
      'مجلد التثبيت غير قابل للكتابة. تحقق من صلاحيات المستخدم.';

  @override
  String get onboardingPreconditionInstallViaBunRecommendation =>
      'يوصي مطورو OpenCode بالتثبيت عبر Bun.';

  @override
  String get onboardingPreconditionNetworkFailed =>
      'فشل الوصول إلى الشبكة. تحقق من الاتصال قبل تثبيت OpenCode.';

  @override
  String get onboardingPreconditionNoRuntimeDetected =>
      'لم يتم الكشف عن بيئة تشغيل. قم بتثبيت ملف OpenCode الثنائي مباشرة أو قم بتهيئة Bun أولاً.';

  @override
  String get onboardingPreconditionNodeNpmAvailable =>
      'تتوفر أدوات Node + npm. قم بتثبيت OpenCode عبر npm أو قم بتثبيت Bun للمسار الموصى به.';

  @override
  String get onboardingPreconditionOpenCodeAlreadyAvailable =>
      'OpenCode متاح بالفعل. يمكنك استخدام الأمر المكتشف فورًا.';

  @override
  String get onboardingPreconditionWindowsPathLagHint =>
      ' على نظام التشغيل Windows، قم بتحديث الفحوصات بعد التثبيت لأن تحديثات PATH قد تتأخر في التطبيقات المفتوحة بالفعل.';

  @override
  String get onboardingPreconditionWindowsWslRecommendation =>
      'تم الكشف عن إصدار Windows. يوصى باستخدام WSL وفقًا لمستندات OpenCode، ولكن يمكن استخدام npm install كبديل.';

  @override
  String get onboardingReachable => 'يمكن الوصول إليه';

  @override
  String get onboardingReady => 'جاهز';

  @override
  String get onboardingRecommendedOrderTry =>
      'الترتيب الموصى به: جرب تثبيت Bun + OpenCode إذا كنت تريد أن يقوم CodeWalk بإعداد كل شيء لك. استخدم \'استخدام الحالي\' إذا كان OpenCode ثابتاً بالفعل.';

  @override
  String get onboardingRefreshChecks => 'تحديث الفحوصات';

  @override
  String get onboardingRunDiagnosticsToVerify =>
      'قم بتشغيل التشخيصات للتحقق من متطلبات OpenCode المحلية.';

  @override
  String get onboardingSaveAndTest => 'حفظ واختبار';

  @override
  String get onboardingServerConnectedReady => 'خادمك متصل وجاهز للاستخدام.';

  @override
  String get onboardingServerConnection => 'اتصال الخادم';

  @override
  String get onboardingServerSettingsSaved =>
      'تم حفظ إعدادات الخادم وتحديث فحوصات الحالة.';

  @override
  String get onboardingServerSetup => 'إعداد الخادم';

  @override
  String get onboardingServerUpdated => 'تم تحديث الخادم';

  @override
  String get onboardingServerUrl => 'عنوان URL للخادم';

  @override
  String get onboardingSetup => 'إعداد';

  @override
  String get onboardingSetupWizard => 'معالج الإعداد';

  @override
  String get onboardingShowSetupSteps => 'أظهر لي خطوات الإعداد';

  @override
  String get onboardingShowSetupSteps2 => 'إظهار خطوات الإعداد';

  @override
  String get onboardingSkip => 'تخطي الآن';

  @override
  String get onboardingSkipSetup => 'تخطي الإعداد؟';

  @override
  String get onboardingStart => 'بدء';

  @override
  String onboardingStartUsing(String appName) {
    return 'ابدأ استخدام $appName';
  }

  @override
  String get onboardingStarting => 'بدء التشغيل';

  @override
  String get onboardingStop => 'إيقاف';

  @override
  String get onboardingStopped => 'متوقف';

  @override
  String get onboardingStopping => 'إيقاف';

  @override
  String onboardingSuggestedUrl(String url) {
    return 'عنوان URL المقترح لخادم OpenCode المحلي: $url';
  }

  @override
  String get onboardingTailscaleAdminApproval =>
      'موافقة مسؤول Tailscale مطلوبة';

  @override
  String get onboardingTailscaleAuthAfterSave =>
      'سيقوم Tailscale بالمصادقة بعد الحفظ';

  @override
  String onboardingTailscaleAuthAfterSaveTest(String appName) {
    return 'بعد حفظ واختبار هذا الخادم، سيفتح $appName تسجيل الدخول إلى Tailscale إذا لم يكن هذا الجهاز مصادقًا عليه بعد.';
  }

  @override
  String get onboardingTailscaleConnected => 'Tailscale متصل';

  @override
  String get onboardingTailscaleConnecting => 'Tailscale يتصل';

  @override
  String get onboardingTailscaleConnectionFailed => 'فشل اتصال Tailscale';

  @override
  String get onboardingTailscaleLoginRequired =>
      'تسجيل الدخول إلى Tailscale مطلوب';

  @override
  String get onboardingTailscaleOpenLoginUrl =>
      'افتح عنوان URL لتسجيل الدخول لإضافة هذا الجهاز إلى tailnet الخاصة بك. إذا لم يفتح المتصفح، فقم بنسخ عنوان URL أدناه.';

  @override
  String get onboardingTailscaleUnsupported => 'Tailscale غير مدعوم';

  @override
  String get onboardingTestConnection => 'اختبار الاتصال';

  @override
  String get onboardingTesting => 'جاري الاختبار...';

  @override
  String get onboardingUnreachable => 'لا يمكن الوصول إليه';

  @override
  String get onboardingUseBasicAuth => 'استخدام المصادقة الأساسية (Basic Auth)';

  @override
  String get onboardingUsername => 'اسم المستخدم';

  @override
  String get onboardingUsernameRequired => 'أدخل اسم المستخدم';

  @override
  String get onboardingUsesServerTitle =>
      'يستخدم وكيل العنوان الخاص بالخادم لتسمية المحادثات';

  @override
  String get onboardingUsingDetectedCommand => 'استخدام أمر OpenCode المكتشف.';

  @override
  String get onboardingViewSetupDebug => 'عرض تشخيص الإعداد';

  @override
  String onboardingWelcomeTo(String appName) {
    return 'مرحبًا بك في $appName';
  }

  @override
  String get onboardingWindowsTipInstalling =>
      'نصيحة لنظام التشغيل Windows: بعد التثبيت، انقر فوق تحديث الفحوصات. إذا استمر فشل الكشف، أعد فتح CodeWalk لإعادة تحميل تغييرات المسار PATH.';

  @override
  String get onboardingWritable => 'قابل للكتابة';

  @override
  String get onboardingYoureAllSet => 'أنت جاهز تمامًا!';

  @override
  String get permissionAllowOnce => 'السماح لمرة واحدة';

  @override
  String get permissionAlways => 'دائماً';

  @override
  String get permissionBack => 'رجوع';

  @override
  String get permissionConfirmReject => 'تأكيد الرفض';

  @override
  String get permissionReject => 'رفض';

  @override
  String get permissionReopen => 'إعادة فتح';

  @override
  String get questionAnswerSelected => 'لم يتم تحديد إجابة.';

  @override
  String get questionCommaSeparatedValues => 'قيم مفصولة بفواصل';

  @override
  String get questionQuestionGroupMarked =>
      'تم وضع علامة الرفض على مجموعة الأسئلة. يمكنك مواصلة الدردشة وإعادة فتح هذه المجموعة في أي وقت قبل التأكيد.';

  @override
  String get questionQuestionRequest => 'طلب سؤال';

  @override
  String get questionQuestionsProvidedSubmit =>
      'لم يتم تقديم أسئلة. يمكنك إرسال استجابة فارغة.';

  @override
  String get questionReviewAnswersSubmitting => 'راجع إجاباتك قبل الإرسال.';

  @override
  String get quotaAuthCookie => 'ملف تعريف ارتباط المصادقة (Auth cookie)';

  @override
  String get quotaConnect => 'اتصال';

  @override
  String get quotaForget => 'نسيان';

  @override
  String get quotaOpenCodeGoConnectDescription =>
      'صل لوحة معلومات الاستخدام لعرض الحدود المتحركة والأسبوعية والشهرية.';

  @override
  String get quotaOpenCodeGoDetected => 'تم اكتشاف OpenCode Go';

  @override
  String get quotaOpenCodeGoNeedsReconnect =>
      'يحتاج OpenCode Go إلى إعادة الاتصال';

  @override
  String get quotaOpenCodeGoReconnectDescription =>
      'حدّث بيانات اعتماد لوحة المعلومات لاستعادة أشرطة الاستخدام.';

  @override
  String get quotaOpenCodeGoUsage => 'استخدام OpenCode Go';

  @override
  String get quotaOpenDashboard => 'فتح لوحة معلومات OpenCode';

  @override
  String get quotaPaceExplanation =>
      'تتوقع الوتيرة إجمالي الاستخدام بنهاية نافذة الحد الحالية بناءً على المعدل الحالي.';

  @override
  String quotaPacePercent(String percent) {
    return 'الوتيرة $percent%';
  }

  @override
  String get quotaRateLimits => 'حدود الاستخدام';

  @override
  String get quotaReconnect => 'إعادة الاتصال';

  @override
  String get quotaRefreshing => 'جارٍ التحديث...';

  @override
  String quotaResetsIn(String time) {
    return 'يُعاد الضبط خلال $time';
  }

  @override
  String get quotaSaving => 'جاري الحفظ...';

  @override
  String get quotaWorkspaceId => 'معرف مساحة العمل';

  @override
  String get serverClearOAuth => 'مسح مصادقة OAuth';

  @override
  String get serverConnectionAttention => 'اتصال الخادم يحتاج إلى انتباه.';

  @override
  String get serverHealthHealthy => 'سليم';

  @override
  String get serverHealthUnhealthy => 'غير سليم';

  @override
  String get serverHealthUnknown => 'غير معروف';

  @override
  String get serverOAuthAuthFailed => 'فشلت مصادقة OAuth';

  @override
  String get serverOAuthChip => 'OAuth';

  @override
  String get serverOAuthNotSupported =>
      'مصادقة Cloudflare Access OAuth غير مدعومة على هذه المنصة';

  @override
  String get serverReauthenticate => 'إعادة المصادقة';

  @override
  String get serverTailscaleChip => 'Tailscale';

  @override
  String get serversActive => 'نشط';

  @override
  String get serversActiveServer => 'الخادم النشط';

  @override
  String get serversAddLeastOpenCode =>
      'أضف خادم OpenCode واحداً على الأقل لبدء استخدام التطبيق.';

  @override
  String get serversAddServer => 'إضافة خادم';

  @override
  String get serversCancel => 'إلغاء';

  @override
  String get serversCannotActivateUnhealthy => 'لا يمكن تفعيل خادم غير سليم';

  @override
  String get serversCheckHealth => 'التحقق من الحالة';

  @override
  String get serversClearDefault => 'مسح الافتراضي';

  @override
  String serversCommandAppProviderLocalServerCommandPath(
    String localServerCommandPath,
  ) {
    return 'الأمر: $localServerCommandPath';
  }

  @override
  String get serversCopy => 'نسخ';

  @override
  String get serversDefault => 'افتراضي';

  @override
  String get serversDelete => 'حذف';

  @override
  String get serversDeleteServer => 'حذف الخادم';

  @override
  String get serversDesktopModeExplanation =>
      'يمكن لوضع سطح المكتب تشغيل وإدارة `opencode serve` مباشرة من CodeWalk.';

  @override
  String get serversEdit => 'تعديل';

  @override
  String get serversLocalOpenCodeServer => 'خادم OpenCode المحلي';

  @override
  String get serversManagedModeAvailable =>
      'يتوفر هذا الوضع المدار فقط في نسخ سطح المكتب (Linux/macOS/Windows).';

  @override
  String get serversNoServersFound => 'لم يتم العثور على خوادم';

  @override
  String get serversRefreshHealth => 'تحديث الحالة الصحية';

  @override
  String serversRemoveProfileDisplayName(String displayName) {
    return 'إزالة \"$displayName\"؟';
  }

  @override
  String get serversSearchActiveHint => 'ابحث في الخادم النشط';

  @override
  String get serversServersConfigured => 'لم يتم تكوين خوادم';

  @override
  String get serversSetActive => 'تعيين كنشط';

  @override
  String get serversSetDefault => 'تعيين كافتراضي';

  @override
  String get serversSetupDebug => 'تشخيص الإعداد';

  @override
  String get serversSetupWizard => 'معالج الإعداد';

  @override
  String get serversTailscaleAdminApprovalRequired =>
      'مطلوب موافقة مسؤول Tailscale';

  @override
  String get serversTailscaleAuthRequired => 'مطلوب مصادقة Tailscale';

  @override
  String get serversTailscaleConnectExplanation =>
      'سيتصل Tailscale عند استخدام هذا الملف الشخصي النشط.';

  @override
  String get serversTailscaleConnected => 'Tailscale متصل';

  @override
  String get serversTailscaleConnecting => 'Tailscale جارٍ الاتصال';

  @override
  String get serversTailscaleConnectionFailed => 'فشل اتصال Tailscale';

  @override
  String get serversTailscaleDisconnected => 'Tailscale غير متصل';

  @override
  String get serversTailscaleLoginExplanation =>
      'افتح رابط تسجيل الدخول إلى Tailscale لإضافة هذا الجهاز إلى شبكتك.';

  @override
  String get serversTailscaleTrafficExplanation =>
      'يتم توجيه حركة OpenCode لهذا الملف الشخصي النشط عبر Tailscale.';

  @override
  String get serversTailscaleUnsupported => 'Tailscale غير مدعوم';

  @override
  String get serversUnhealthyActivateError =>
      'هذا الخادم غير سليم. استخدم فحص الصحة أو حرر الإعدادات قبل التفعيل.';

  @override
  String get sessionActionArchived => 'تمت أرشفتها';

  @override
  String get sessionActionDeleted => 'تم حذفها';

  @override
  String get sessionActionForked => 'تم تفريعها';

  @override
  String get sessionActionPinned => 'مثبتة';

  @override
  String get sessionActionUnarchived => 'تم إلغاء أرشفتها';

  @override
  String get sessionActionUnpinned => 'غير مثبتة';

  @override
  String get sessionArchive => 'أرشفة';

  @override
  String get sessionCancelRename => 'إلغاء إعادة التسمية';

  @override
  String sessionChildrenCount(int count) {
    return 'المحادثات الفرعية: $count';
  }

  @override
  String get sessionCompactContext => 'ضغط السياق';

  @override
  String get sessionCopyLink => 'نسخ رابط المشاركة';

  @override
  String get sessionDelete => 'حذف';

  @override
  String sessionDeleteConfirm(String title) {
    return 'هل تريد بالتأكيد حذف المحادثة \"$title\"؟ لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String get sessionDeleteTitle => 'حذف المحادثة';

  @override
  String get sessionDiffChangedFile => 'ملف تم تغييره';

  @override
  String get sessionDiffContentNotCaptured =>
      'محتوى الملف لم يتم التقاطه بواسطة الخادم';

  @override
  String sessionDiffFilesChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملفات تم تغييرها',
      one: 'ملف واحد تم تغييره',
    );
    return '$_temp0';
  }

  @override
  String sessionDiffFilesCount(int count) {
    return 'ملفات الفرق: $count';
  }

  @override
  String sessionDiffLinesAddedRemoved(int added, int removed) {
    return '+$added أسطر تم إضافتها -$removed أسطر تم إزالتها';
  }

  @override
  String sessionDiffLinesCollapsed(int count) {
    return '$count أسطر مطوية — اضغط للتوسيع';
  }

  @override
  String get sessionDiffLoading => 'جارٍ تحميل الملفات المعدّلة…';

  @override
  String get sessionDiffReview => 'مراجعة التغييرات';

  @override
  String get sessionDiffSplit => 'تقسيم';

  @override
  String get sessionDiffSummary => 'ملخص';

  @override
  String get sessionDiffUnified => 'موحد';

  @override
  String get sessionExportAssistant => 'المساعد';

  @override
  String get sessionExportCanceled => 'تم إلغاء تصدير الجلسة';

  @override
  String get sessionExportDebugJson => 'تصدير JSON للتصحيح';

  @override
  String get sessionExportDebugJsonErrorClipboard =>
      'تعذر حفظ الملف؛ تم نسخ JSON للتصحيح إلى الحافظة';

  @override
  String get sessionExportDebugJsonSaved => 'تم حفظ تصدير JSON للتصحيح';

  @override
  String get sessionExportDebugJsonTitle => 'تصدير الجلسة بصيغة JSON للتصحيح';

  @override
  String get sessionExportError => 'خطأ:';

  @override
  String get sessionExportInput => 'المدخلات:';

  @override
  String get sessionExportMarkdown => 'تصدير Markdown';

  @override
  String get sessionExportMarkdownErrorClipboard =>
      'تعذر حفظ الملف؛ تم نسخ Markdown إلى الحافظة';

  @override
  String get sessionExportMarkdownSaved => 'تم حفظ تصدير Markdown';

  @override
  String get sessionExportMarkdownTitle => 'تصدير الجلسة بصيغة Markdown';

  @override
  String get sessionExportOutput => 'المخرجات:';

  @override
  String get sessionExportUntitled => 'جلسة بدون عنوان';

  @override
  String get sessionExportUser => 'المستخدم';

  @override
  String get sessionFailedRename => 'فشلت إعادة تسمية المحادثة';

  @override
  String get sessionFailedUpdateArchive => 'فشل تحديث حالة الأرشفة';

  @override
  String get sessionFailedUpdateSharing => 'فشل تحديث حالة المشاركة';

  @override
  String get sessionFork => 'تفرع';

  @override
  String get sessionForkFailed => 'فشلت عملية تفريع المحادثة';

  @override
  String get sessionForked => 'تم تفريع المحادثة';

  @override
  String sessionHasError(String title) {
    return '\"$title\" به خطأ.';
  }

  @override
  String sessionHasNewReply(String title) {
    return '\"$title\" لديه رد جديد.';
  }

  @override
  String get sessionKeyboardShortcuts => 'اختصارات لوحة المفاتيح';

  @override
  String sessionNeedsInput(String title) {
    return '\"$title\" يحتاج إلى إدخالك.';
  }

  @override
  String get sessionNoCachedConversations => 'لا توجد محادثات مخزنة مؤقتًا بعد';

  @override
  String get sessionNoConversationsInProject =>
      'لا توجد محادثات في هذا المشروع.';

  @override
  String get sessionNotAvailable => 'المحادثة غير متوفرة لهذا المشروع بعد';

  @override
  String get sessionOpenProjectToLoad => 'افتح المشروع لتحميل المحادثات.';

  @override
  String get sessionPin => 'تثبيت';

  @override
  String get sessionRename => 'إعادة تسمية';

  @override
  String get sessionRenameHint => 'أدخل اسماً جديداً للمحادثة';

  @override
  String get sessionRenameTitle => 'إعادة تسمية المحادثة';

  @override
  String get sessionSaveTitle => 'حفظ العنوان';

  @override
  String get sessionShare => 'مشاركة الجلسة';

  @override
  String get sessionShareAction => 'مشاركة';

  @override
  String get sessionShareLinkCopied => 'تم نسخ رابط المشاركة';

  @override
  String get sessionShareLinkUnavailable =>
      'رابط المشاركة غير متاح لهذه الجلسة';

  @override
  String get sessionShared => 'تمت مشاركة المحادثة';

  @override
  String get sessionSyncing => 'جاري مزامنة المحادثات...';

  @override
  String get sessionTitleHint => 'عنوان المحادثة';

  @override
  String get sessionUnarchive => 'إلغاء الأرشفة';

  @override
  String get sessionUnpin => 'إلغاء التثبيت';

  @override
  String get sessionUnshare => 'إلغاء مشاركة الجلسة';

  @override
  String get sessionUnshareAction => 'إلغاء المشاركة';

  @override
  String get sessionUnshared => 'تم إلغاء مشاركة المحادثة';

  @override
  String get sessionViewTasks => 'عرض المهام';

  @override
  String get settingsAboutCheckForUpdates => 'التحقق من وجود تحديثات';

  @override
  String get settingsAboutCheckOnOpen => 'التحقق من التحديثات عند الفتح';

  @override
  String get settingsAboutCheckOnOpenDescription =>
      'التحقق تلقائياً عند بدء تشغيل التطبيق';

  @override
  String get settingsAboutChecking => 'جاري التحقق...';

  @override
  String get settingsAboutDescription =>
      'الإصدار والتحديثات والمساعدة وبيانات التطبيق';

  @override
  String get settingsAboutDismiss => 'تجاهل';

  @override
  String settingsAboutDownloading(String percent) {
    return 'جاري التنزيل... $percent%';
  }

  @override
  String get settingsAboutEraseAllData => 'مسح جميع البيانات وإعادة التشغيل';

  @override
  String get settingsAboutInstallUpdate => 'تثبيت التحديث';

  @override
  String get settingsAboutInstalling => 'جاري التثبيت...';

  @override
  String settingsAboutLatestVersion(String version) {
    return 'الإصدار v$version هو أحدث إصدار';
  }

  @override
  String get settingsAboutLoading => 'جاري التحميل...';

  @override
  String get settingsAboutReplayChatTour => 'إعادة تشغيل جولة الدردشة';

  @override
  String get settingsAboutReplayChatTourDescription =>
      'إغلاق الإعدادات وإظهار جولة الدردشة الإرشادية';

  @override
  String get settingsAboutResetApp => 'إعادة تعيين التطبيق';

  @override
  String get settingsAboutResetAppQuestion => 'إعادة تعيين التطبيق؟';

  @override
  String get settingsAboutResetAppWarning =>
      'سيؤدي هذا إلى مسح جميع الخوادم والإعدادات والبيانات المخزنة مؤقتاً. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get settingsAboutRetryInstall => 'إعادة محاولة التثبيت';

  @override
  String get settingsAboutTapToCheck => 'انقر للتحقق من وجود إصدارات جديدة';

  @override
  String get settingsAboutTitle => 'حول';

  @override
  String get settingsAboutUpToDate => 'أنت تستخدم أحدث إصدار';

  @override
  String settingsAboutUpdateAvailable(String version) {
    return 'تحديث متوفر: v$version';
  }

  @override
  String get settingsAboutUpdateInstalled =>
      'تم تثبيت التحديث. أعد تشغيل التطبيق للتطبيق.';

  @override
  String settingsAboutUpdateVersionSummary(
    String installedVersion,
    String latestVersion,
  ) {
    return 'الحالي: $installedVersion؛ المتاح: v$latestVersion';
  }

  @override
  String get settingsAboutVersion => 'الإصدار';

  @override
  String settingsAboutVersionBuild(String buildNumber, String version) {
    return '‏$version (البناء $buildNumber)';
  }

  @override
  String get settingsAppearanceAmoledDark => 'وضع AMOLED الداكن';

  @override
  String get settingsAppearanceAmoledDarkActive =>
      'استخدم أسطحًا سوداء نقية أثناء تنشيط الوضع الداكن.';

  @override
  String get settingsAppearanceAmoledDarkInactive =>
      'قم بالتحويل إلى الوضع الداكن لتمكين أسطح AMOLED.';

  @override
  String get settingsAppearanceBrandColor => 'لون العلامة التجارية';

  @override
  String get settingsAppearanceBrandColorDynamicBlocked =>
      'قم بتعطيل ألوان الخلفية لاختيار لون العلامة التجارية.';

  @override
  String get settingsAppearanceBrandColorNormal =>
      'اختر لوناً أساسياً للوحة ألوان التطبيق.';

  @override
  String get settingsAppearanceBrandColorPresetBlocked =>
      'قم بالتحويل إلى CodeWalk Classic لاختيار لون العلامة التجارية.';

  @override
  String get settingsAppearanceChatFontScale => 'حجم نص المحادثة';

  @override
  String get settingsAppearanceChatFontScaleDescription =>
      'غيّر حجم نص الرسائل والمحرر في الدردشة بالإضافة إلى حجم نص النظام.';

  @override
  String get settingsAppearanceCodeWalkClassic =>
      'كود ووك الكلاسيكي (CodeWalk Classic)';

  @override
  String get settingsAppearanceComposerTips => 'نصائح الملحِّن';

  @override
  String get settingsAppearanceComposerTipsDescription =>
      'إظهار أو إخفاء النصائح الدوارة أثناء استدلال المساعد.';

  @override
  String get settingsAppearanceContrast => 'التباين';

  @override
  String get settingsAppearanceContrastDynamicBlocked =>
      'قم بتعطيل ألوان الخلفية لضبط التباين.';

  @override
  String get settingsAppearanceContrastHigh => 'مرتفع';

  @override
  String get settingsAppearanceContrastNormal =>
      'ضبط مستوى التباين لمخطط الألوان.';

  @override
  String get settingsAppearanceContrastPresetBlocked =>
      'قم بالتحويل إلى CodeWalk Classic لضبط التباين.';

  @override
  String get settingsAppearanceContrastReduced => 'منخفض';

  @override
  String get settingsAppearanceDark => 'داكن';

  @override
  String get settingsAppearanceDensity => 'الكثافة';

  @override
  String get settingsAppearanceDensityDense => 'كثيف';

  @override
  String get settingsAppearanceDensityDescription =>
      'تطبيق التباعد وكثافة المكونات عبر التطبيق.';

  @override
  String get settingsAppearanceDensityExtraDense => 'كثيف جداً';

  @override
  String get settingsAppearanceDensityExtraSpacious => 'متسع جداً';

  @override
  String get settingsAppearanceDensityNormal => 'عادي';

  @override
  String get settingsAppearanceDensitySpacious => 'متسع';

  @override
  String get settingsAppearanceDescription =>
      'اختر المظاهر والألوان وحجم النص وعرض الدردشة';

  @override
  String get settingsAppearanceFontSize => 'حجم النص';

  @override
  String get settingsAppearanceFontSizeDescription =>
      'اضبط حجم نص النظام ونص المحادثة ونص الطرفية.';

  @override
  String get settingsAppearanceLight => 'فاتح';

  @override
  String get settingsAppearanceMathRendering => 'عرض الرياضيات';

  @override
  String get settingsAppearanceMathRenderingDescription =>
      'عرض تعبيرات LaTeX الرياضية كمعادلات منسقة في رسائل الدردشة.';

  @override
  String get settingsAppearanceNoPresets =>
      'لم يتم العثور على لوحات ألوان جاهزة';

  @override
  String get settingsAppearanceOpenCodePresets => 'إعدادات OpenCode المسبقة';

  @override
  String get settingsAppearancePresetHelper =>
      'يعكس قائمة السمات المدمجة الرسمية لـ OpenCode Web.';

  @override
  String get settingsAppearancePresetNote =>
      'تتبع ألوان السمة الآن سجل OpenCode Web الرسمي وتتحكم في أسطح الـ markdown والتعليمات البرمجية أيضًا.';

  @override
  String get settingsAppearancePresetPalette => 'لوحة الألوان الجاهزة';

  @override
  String get settingsAppearanceSearchPreset => 'البحث عن لوحة ألوان جاهزة';

  @override
  String get settingsAppearanceSectionDescription =>
      'ضبط الكثافة البصرية وأسطح الرسائل لسير عملك.';

  @override
  String get settingsAppearanceSectionTitle => 'المظهر';

  @override
  String get settingsAppearanceSystem => 'النظام';

  @override
  String get settingsAppearanceSystemFontScale => 'حجم نص النظام';

  @override
  String get settingsAppearanceSystemFontScaleDescription =>
      'غيّر حجم جميع النصوص في واجهة التطبيق، بما في ذلك القوائم والحوارات والأشرطة الجانبية.';

  @override
  String get settingsAppearanceTaskList => 'قائمة المهام';

  @override
  String get settingsAppearanceTaskListDescription =>
      'إظهار أو إخفاء عنصر واجهة مستخدم قائمة المهام للجلسة.';

  @override
  String get settingsAppearanceTerminalFontSize => 'حجم نص الطرفية';

  @override
  String get settingsAppearanceTerminalFontSizeDescription =>
      'غيّر حجم خط الطرفية المدمجة. يُطبَّق فورًا على الجلسات قيد التشغيل.';

  @override
  String get settingsAppearanceTheme => 'السمة';

  @override
  String get settingsAppearanceThemeDescription =>
      'اختر الوضع الفاتح، أو الداكن، أو وضع النظام، ثم احتفظ بلوحة ألوان CodeWalk الكلاسيكية أو انتقل إلى إعداد مسبق لـ OpenCode.';

  @override
  String get settingsAppearanceVisualStyle => 'النمط المرئي';

  @override
  String get settingsAppearanceVisualStyleDescription =>
      'اختر المظهر الكلاسيكي أو أسطحًا محسّنة أكثر نعومة.';

  @override
  String get settingsAppearanceVisualStyleClassic => 'كلاسيكي';

  @override
  String get settingsAppearanceVisualStyleRefined => 'محسّن';

  @override
  String get settingsAppearanceThinkingBubbles => 'فقاعات التفكير';

  @override
  String get settingsAppearanceThinkingBubblesDescription =>
      'إظهار أو إخفاء كتل الاستدلال في رسائل المساعد.';

  @override
  String get settingsAppearanceTitle => 'المظهر';

  @override
  String get settingsAppearanceToolCallBubbles => 'فقاعات استدعاء الأدوات';

  @override
  String get settingsAppearanceToolCallBubblesDescription =>
      'إظهار أو إخفاء بطاقات تنفيذ الأدوات في رسائل المساعد.';

  @override
  String get settingsAppearanceWallpaperColors => 'استخدام ألوان الخلفية';

  @override
  String get settingsAppearanceWallpaperNormal =>
      'استخراج مخطط الألوان من خلفية جهازك.';

  @override
  String get settingsAppearanceWallpaperPresetBlocked =>
      'قم بالتحويل إلى CodeWalk Classic لاستخدام ألوان الخلفية.';

  @override
  String get settingsAppearanceWindowChrome => 'علامات تبويب النافذة';

  @override
  String get settingsAppearanceWindowChromeDescription =>
      'اختر كيفية دمج علامات تبويب الجلسات مع شريط العنوان على سطح المكتب.';

  @override
  String get settingsAppearanceWindowChromeIntegrated => 'علامات تبويب مدمجة';

  @override
  String get settingsAppearanceWindowChromeIntegratedDescription =>
      'تظهر علامات التبويب أعلى النافذة ويُخفى شريط عنوان النظام.';

  @override
  String get settingsAppearanceWindowChromeSystem => 'زخرفة النظام';

  @override
  String get settingsAppearanceWindowChromeSystemDescription =>
      'يحتفظ بشريط العنوان الأصلي ويعرض علامات التبويب أسفل شريط التطبيق.';

  @override
  String get settingsBack => 'رجوع';

  @override
  String get settingsBehaviorAutoupdateCaveat =>
      'استخدم \'حول\' لفحص إصدارات CodeWalk. يعكس هذا الإعداد فقط تكوين `autoupdate` الرسمي لـ OpenCode.';

  @override
  String get settingsBehaviorAutoupdateHelp =>
      'يتحكم في تحديثات وقت تشغيل OpenCode في المنبع، وليس في فحوصات تحديث تطبيق CodeWalk.';

  @override
  String get settingsBehaviorCellularDataSaver => 'موفر بيانات المحمول';

  @override
  String get settingsBehaviorChatRenderMode => 'وضع عرض الدردشة';

  @override
  String get settingsBehaviorChatRenderModeBlock => 'كتلة';

  @override
  String get settingsBehaviorChatRenderModeBlockDescription =>
      'أخفِ النص المباشر للمساعد والاستدلال وبطاقات الأدوات حتى يمكن عرض الجولة الحالية ككتلة واحدة.';

  @override
  String get settingsBehaviorChatRenderModeDescription =>
      'اختر ما إذا كانت ردود المساعد تظهر أثناء البث أو تُعرض بعد اكتمال الجولة الحالية.';

  @override
  String get settingsBehaviorChatRenderModeLive => 'مباشر';

  @override
  String get settingsBehaviorChatRenderModeLiveDescription =>
      'اعرض نص المساعد واستدلالاته ونشاط الأدوات أثناء بث الأحداث من OpenCode.';

  @override
  String get settingsBehaviorComposerSpellCheck => 'التدقيق الإملائي في المحرر';

  @override
  String get settingsBehaviorComposerSpellCheckDescription =>
      'استخدم التدقيق الإملائي والاقتراحات والتصحيح التلقائي من المنصة في محرر الدردشة.';

  @override
  String get settingsBehaviorConfigDeferred =>
      'سيقوم CodeWalk بتطبيق إعداد OpenCode هذا بعد انتهاء الاستجابة الحالية.';

  @override
  String settingsBehaviorConfigUpdateFailed(String field) {
    return 'تعذر تحديث $field لـ OpenCode.';
  }

  @override
  String get settingsBehaviorConversationUsername => 'اسم مستخدم المحادثة';

  @override
  String get settingsBehaviorConversationUsernameHelp =>
      'اسم عرض مخصص يظهر في المحادثات بدلاً من اسم مستخدم النظام.';

  @override
  String get settingsBehaviorDataSaverActive => 'نشط الآن على بيانات المحمول.';

  @override
  String get settingsBehaviorDataSaverCellularOnly =>
      'ينطبق فقط عندما يكون الاتصال عبر شبكة المحمول/البيانات.';

  @override
  String get settingsBehaviorDataSaverDescription =>
      'يقلل استخدام بيانات المحمول التلقائي عن طريق إيقاف عمليات التنزيل في الخلفية وتقييد عمليات التحديث التلقائي في المقدمة.';

  @override
  String get settingsBehaviorDataSaverWaiting =>
      'بانتظار نافذة مزامنة بيانات المحمول التالية.';

  @override
  String get settingsBehaviorDefaultAgent => 'الوكيل الافتراضي';

  @override
  String get settingsBehaviorDefaultAgentHelp =>
      'الوكيل الأساسي المستخدم عندما لا يتم اختيار وكيل صراحةً.';

  @override
  String get settingsBehaviorDefaultModel => 'النموذج الافتراضي';

  @override
  String get settingsBehaviorDefaultModelHelp =>
      'مشارك عبر عملاء OpenCode من خلال التكوين.';

  @override
  String get settingsBehaviorDescription =>
      'تحكم في اللغة وسلوك الدردشة واستخدام البيانات وإعدادات OpenCode الافتراضية';

  @override
  String get settingsBehaviorEnableDataSaver => 'تمكين موفر بيانات المحمول';

  @override
  String get settingsBehaviorMultiDeviceSync =>
      'تمكين المزامنة التجريبية متعددة الأجهزة';

  @override
  String get settingsBehaviorMultiDeviceSyncDescription =>
      'مزامنة اختيار الملحِّن (الوكيل/النموذج/المتغير) مع تكوين الخادم النشط.';

  @override
  String get settingsBehaviorMultiDeviceSyncWarning =>
      'يمكن أن يؤدي ذلك إلى إلغاء الجلسات الجارية عند العمل في أكثر من جلسة واحدة في نفس الوقت.';

  @override
  String get settingsBehaviorNoAgents => 'لم يتم العثور على وكلاء';

  @override
  String get settingsBehaviorNoModels => 'لم يتم العثور على نماذج';

  @override
  String get settingsBehaviorOpenCodeAutoupdate =>
      'التحديث التلقائي لـ OpenCode';

  @override
  String get settingsBehaviorOpenCodeDefaults =>
      'الافتراضيات المدعومة من OpenCode';

  @override
  String get settingsBehaviorOpenCodeDefaultsDescription =>
      'تُكتب هذه القيم في `/config` على الخادم النشط وتطابق تكوين OpenCode المشترك الرسمي.';

  @override
  String get settingsBehaviorOpenCodeSnapshots => 'لقطات OpenCode';

  @override
  String get settingsBehaviorOpenCodeSnapshotsDescription =>
      'الاحتفاظ بتمكين اللقطات المدعومة من git المنبع لعمليات التراجع/الإعادة وسجل الاسترداد.';

  @override
  String get settingsBehaviorPermissionDeferred =>
      'يظل تحرير قواعد الأذونات المتقدمة خارج الإعدادات في الوقت الحالي ويتم تأجيله إلى أعمال التكافؤ اللاحقة.';

  @override
  String get settingsBehaviorPermissionProvenance => 'منشأ معالجة الأذونات';

  @override
  String get settingsBehaviorPermissionProvenanceDescription =>
      'تُكوّن سياسة أذونات OpenCode الرسمية في `opencode.json` بقواعد السماح/السؤال/الرفض لكل أداة. يحتفظ CodeWalk ببطاقات طلب الأذونات الرسمية ويضيف استثناءً واحدًا معتمدًا من ADR-023: تبديل الموافقة التلقائية للملحِّن يرد بـ `Always` و `remember: true` دون قيد أو شرط لإنشاء منح متينة محددة النطاق بالجلسة، ويحافظ على تنشيط مسار الاستمرارية نفسه المحدد النطاق بالمؤشر في عامل الخلفية لنظام Android.';

  @override
  String get settingsBehaviorRefreshDefaults => 'تحديث الافتراضيات';

  @override
  String get settingsBehaviorSaveUsername => 'حفظ اسم المستخدم';

  @override
  String get settingsBehaviorSearchAutoupdate =>
      'البحث في وضع التحديث التلقائي';

  @override
  String get settingsBehaviorSearchDefaultAgent => 'البحث عن الوكيل الافتراضي';

  @override
  String get settingsBehaviorSearchDefaultModel => 'البحث عن النموذج الافتراضي';

  @override
  String get settingsBehaviorSearchShareMode => 'البحث في وضع المشاركة';

  @override
  String get settingsBehaviorSearchSmallModel => 'البحث عن النموذج الصغير';

  @override
  String get settingsBehaviorShareMode => 'افتراضي المشاركة لـ OpenCode';

  @override
  String get settingsBehaviorShareModeCaveat =>
      'استخدم إجراء المشاركة على مستوى الدردشة لنشر جلسة واحدة الآن. يغير هذا الإعداد فقط سياسة المشاركة الافتراضية لـ OpenCode.';

  @override
  String get settingsBehaviorShareModeHelp =>
      'يتحكم في تكوين `share` العالمي الرسمي، وليس زر المشاركة لدردشة فردية.';

  @override
  String get settingsBehaviorSmallModel => 'النموذج الصغير';

  @override
  String get settingsBehaviorSmallModelAutoFallback => 'التراجع التلقائي';

  @override
  String get settingsBehaviorSmallModelFallbackActive =>
      'تراجع OpenCode التلقائي نشط لأن `small_model` غير محدد.';

  @override
  String get settingsBehaviorSmallModelHelp =>
      'يُستخدم للمهام الخفيفة مثل توليد العناوين.';

  @override
  String get settingsBehaviorSmallModelResetCaveat =>
      'إعادة تعيين `small_model` إلى التراجع التلقائي لا تزال تتطلب تحرير التكوين خارج التطبيق لأن تحديثات تصحيح `/config` لا يمكنها إزالة المفاتيح.';

  @override
  String get settingsBehaviorSnapshotCaveat =>
      'يتحكم هذا في تخزين لقطات OpenCode ودعم التراجع/الإعادة، وليس في لقطات ذاكرة التخزين المؤقت المحلية لـ CodeWalk.';

  @override
  String get settingsBehaviorTitle => 'السلوك';

  @override
  String get settingsBehaviorUsernameFallback =>
      'يستخدم OpenCode اسم مستخدم النظام لأن `username` غير محدد.';

  @override
  String get settingsBehaviorUsernamePatchCaveat =>
      'إعادة تعيين `username` إلى افتراضي النظام لا تزال تتطلب تحرير التكوين خارج التطبيق لأن تحديثات تصحيح (patch) `/config` لا يمكنها إزالة المفاتيح.';

  @override
  String get settingsConfigRefreshFailed =>
      'تم تحديث إعداد الخادم، ولكن تعذر تحديث مزودي الدردشة.';

  @override
  String get settingsConfigUpdateDeferred =>
      'سيقوم CodeWalk بتطبيق إعداد OpenCode هذا بعد انتهاء الاستجابة الحالية.';

  @override
  String get settingsConversationUsername => 'اسم مستخدم المحادثة';

  @override
  String get settingsDefaultAgent => 'الوكيل الافتراضي';

  @override
  String get settingsDefaultModel => 'النموذج الافتراضي';

  @override
  String get settingsLanguageDescription =>
      'اختر اللغة المستخدمة في CodeWalk. يتبع افتراضي النظام لغة جهازك.';

  @override
  String get settingsLanguageEmptyText => 'لم يتم العثور على لغات';

  @override
  String get settingsLanguageFieldHelper =>
      'يُطبّق على الفور ويستمر عبر عمليات إعادة التشغيل.';

  @override
  String get settingsLanguageFieldLabel => 'لغة التطبيق';

  @override
  String get settingsLanguageSearchHint => 'البحث في اللغات';

  @override
  String get settingsLanguageSystemDefault => 'افتراضي النظام';

  @override
  String get settingsLanguageTitle => 'اللغة';

  @override
  String get settingsLogsDescription =>
      'راجع التشخيصات وتفاصيل استكشاف الأخطاء وإصلاحها';

  @override
  String get settingsLogsTitle => 'Registros';

  @override
  String get settingsNoAgentsFound => 'لم يتم العثور على وكلاء';

  @override
  String get settingsNotificationsAgentSubtitle => 'عند انتهاء الاستجابة';

  @override
  String get settingsNotificationsAgentUpdates => 'تحديثات الوكيل';

  @override
  String get settingsNotificationsAnotherConversation => 'محادثة أخرى';

  @override
  String get settingsNotificationsAppInBackground => 'التطبيق في الخلفية';

  @override
  String get settingsNotificationsBackgroundAlerts => 'تنبيهات خلفية Android';

  @override
  String get settingsNotificationsBackgroundBehavior => 'سلوك الخلفية';

  @override
  String get settingsNotificationsBackgroundBehaviorDescription =>
      'اختر كيف يتصرف CodeWalk بعد مغادرة التطبيق للواجهة.';

  @override
  String get settingsNotificationsBackgroundDescription =>
      'استخدم مراقبة الخلفية منخفضة البيانات لاكتمال الاستجابة، وطلبات الأذونات، والأسئلة، والأخطاء عندما لا تكون الشاشة قيد الاستخدام.';

  @override
  String get settingsNotificationsBackgroundToggle =>
      'تنبيهات الخلفية على Android';

  @override
  String get settingsNotificationsBackgroundToggleDescription =>
      'إيقاف تشغيل جميع عمليات فحص الخلفية لنظام Android وإخفاء إشعار المراقبة المستمر.';

  @override
  String get settingsNotificationsBatteryDescription =>
      'إذا كانت الإشعارات تصل فقط عند إعادة فتح التطبيق، فاسمح لـ CodeWalk بالتشغيل دون تحسين على هذا الجهاز.';

  @override
  String get settingsNotificationsBatteryDisabled =>
      'تم تعطيل تحسين البطارية لـ CodeWalk.';

  @override
  String get settingsNotificationsBatteryEnabled =>
      'تم تمكين تحسين البطارية. قد تؤخر بعض الأجهزة تنبيهات الخلفية.';

  @override
  String get settingsNotificationsBatteryOptimization =>
      'تحسين البطارية في Android';

  @override
  String get settingsNotificationsBatteryUnknown =>
      'تعذر قراءة حالة تحسين البطارية بعد.';

  @override
  String get settingsNotificationsChooseAudioFile => 'اختر ملفاً صوتياً';

  @override
  String get settingsNotificationsChooseSystemSound => 'اختر صوت النظام';

  @override
  String get settingsNotificationsCloseToTray => 'الإغلاق إلى علبة النظام';

  @override
  String get settingsNotificationsCloseToTrayDescription =>
      'إخفاء النافذة ومتابعة التشغيل في علبة النظام.';

  @override
  String get settingsNotificationsDescription =>
      'اختر الأحداث التي تنبهك وطريقة التنبيه';

  @override
  String get settingsNotificationsDisableOptimization => 'تعطيل التحسين';

  @override
  String get settingsNotificationsErrors => 'الأخطاء';

  @override
  String get settingsNotificationsErrorsSubtitle => 'عندما تبلغ جلسة ما عن فشل';

  @override
  String get settingsNotificationsJustClose => 'إغلاق فقط';

  @override
  String get settingsNotificationsJustCloseDescription =>
      'الخروج من التطبيق تماماً.';

  @override
  String get settingsNotificationsKeepLive =>
      'الاحتفاظ بالتنبيهات نشطة لمدة 3 دقائق';

  @override
  String get settingsNotificationsKeepLiveDescription =>
      'عندما تكون الاستجابة قيد التشغيل بالفعل، احتفظ بالوقت الفعلي نشطاً لفترة وجيزة بعد مغادرة التطبيق.';

  @override
  String get settingsNotificationsLocal => 'محلي';

  @override
  String get settingsNotificationsMinimizeWhenClose => 'التصغير عند الإغلاق';

  @override
  String get settingsNotificationsMinimizeWhenCloseDescription =>
      'التصغير إلى شريط المهام/المنصة ومتابعة التشغيل.';

  @override
  String get settingsNotificationsNoCondition =>
      'إذا لم يتم تحديد أي شرط، فسيتم السماح بالتنبيهات في أي سياق.';

  @override
  String get settingsNotificationsNotify => 'إشعار';

  @override
  String get settingsNotificationsNotifyOnlyWhen => 'إشعار فقط عندما';

  @override
  String get settingsNotificationsOpenBatterySettings => 'فتح إعدادات البطارية';

  @override
  String get settingsNotificationsPermissions => 'الأذونات والأسئلة';

  @override
  String get settingsNotificationsPermissionsSubtitle =>
      'عندما تطلب الأدوات مدخلاتك';

  @override
  String get settingsNotificationsPreview => 'معاينة';

  @override
  String get settingsNotificationsRefreshStatus => 'تحديث الحالة';

  @override
  String get settingsNotificationsSearchSoundType => 'البحث عن نوع الصوت';

  @override
  String get settingsNotificationsSectionDescription =>
      'التحكم في وقت ظهور التنبيهات ووقت تشغيل الصوت.';

  @override
  String get settingsNotificationsSectionTitle => 'الإشعارات';

  @override
  String settingsNotificationsSelectedSound(String label) {
    return 'المحدد: $label';
  }

  @override
  String get settingsNotificationsServer => 'خادم';

  @override
  String get settingsNotificationsSound => 'الصوت';

  @override
  String get settingsNotificationsSoundBuiltInAlert => 'تنبيه مدمج';

  @override
  String get settingsNotificationsSoundBuiltInClick => 'نقرة مدمجة';

  @override
  String get settingsNotificationsSoundOff => 'إيقاف';

  @override
  String get settingsNotificationsSoundOnlyWhen => 'صوت فقط عندما';

  @override
  String get settingsNotificationsSoundPickAudioFile => 'اختر ملف صوتي';

  @override
  String get settingsNotificationsSoundPickFromSystem => 'اختر من النظام';

  @override
  String get settingsNotificationsSoundSystemDefault => 'الافتراضي للنظام';

  @override
  String get settingsNotificationsSoundType => 'نوع الصوت';

  @override
  String get settingsNotificationsSyncInfo =>
      'يتم مزامنة بعض مفاتيح تشغيل/إيقاف الفئات من `/config` على الخادم النشط.';

  @override
  String get settingsNotificationsSyncInfoLocal =>
      'لا يعرض الخادم الحالي مفاتيح تبديل الإشعارات في `/config`؛ القيم المحلية نشطة.';

  @override
  String get settingsNotificationsSystemSoundPickerTitle => 'اختر صوت النظام';

  @override
  String get settingsNotificationsTitle => 'الإشعارات';

  @override
  String get settingsNotificationsWhenClosing => 'عند إغلاق النافذة';

  @override
  String get settingsOpenCodeAutoUpdate => 'تحديث OpenCode التلقائي';

  @override
  String get settingsOpenCodeSharingDefault => 'افتراضي مشاركة OpenCode';

  @override
  String get settingsReadAloudEnabled => 'القراءة بصوت عالٍ';

  @override
  String get settingsReadAloudEnabledDescription =>
      'إظهار زر القراءة بصوت عالٍ في رسائل المساعد.';

  @override
  String get settingsReadAloudPitch => 'طبقة الصوت';

  @override
  String get settingsReadAloudPitchDescription => 'ضبط طبقة الصوت.';

  @override
  String get settingsReadAloudSectionDescription =>
      'قراءة استجابات المساعد بصوت عالٍ. قم بتكوين السرعة والطبقة والصوت.';

  @override
  String get settingsReadAloudSectionTitle => 'تحويل النص إلى كلام';

  @override
  String get settingsReadAloudSpeed => 'السرعة';

  @override
  String get settingsReadAloudSpeedDescription => 'ضبط معدل التحدث.';

  @override
  String get settingsReadAloudVoice => 'الصوت';

  @override
  String get settingsReadAloudVoiceHint => 'حدد صوتاً للقراءة بصوت عالٍ.';

  @override
  String get settingsSearchAutoUpdateMode => 'البحث عن وضع التحديث التلقائي';

  @override
  String get settingsSearchDefaultAgent => 'البحث عن الوكيل الافتراضي';

  @override
  String get settingsSearchDefaultModel => 'البحث عن النموذج الافتراضي';

  @override
  String get settingsSearchSharingMode => 'البحث عن وضع المشاركة';

  @override
  String get settingsSearchSmallModel => 'البحث عن نموذج صغير';

  @override
  String get settingsServersActive => 'نشط';

  @override
  String get settingsServersChooseActive => 'اختر الخادم النشط';

  @override
  String get settingsServersDefault => 'افتراضي';

  @override
  String get settingsServersDescription => 'اتصل بـ OpenCode وأدر خوادمك';

  @override
  String get settingsServersTitle => 'الخوادم';

  @override
  String get settingsSessionAttentionSize => 'حجم الفقاعة';

  @override
  String get settingsSessionAttentionSizeExtraLarge => 'كبير جدًا';

  @override
  String get settingsSessionAttentionSizeExtraSmall => 'صغير جدًا';

  @override
  String get settingsSessionAttentionSizeLarge => 'كبير';

  @override
  String get settingsSessionAttentionSizeSmall => 'صغير';

  @override
  String get settingsSessionAttentionSizeStandard => 'قياسي';

  @override
  String get settingsSetupWizard => 'معالج الإعداد';

  @override
  String get settingsShortcutsDescription =>
      'ابحث عن اختصارات لوحة المفاتيح وخصصها';

  @override
  String get settingsShortcutsEdit => 'تعديل الاختصار';

  @override
  String get settingsShortcutsKeyboard => 'اختصارات لوحة المفاتيح';

  @override
  String get settingsShortcutsReset => 'إعادة تعيين الاختصار';

  @override
  String get settingsShortcutsSearch => 'البحث في الاختصارات';

  @override
  String get settingsShortcutsTitle => 'الاختصارات';

  @override
  String get settingsSmallModel => 'نموذج صغير';

  @override
  String get settingsSmallModelResetExplanation =>
      'لا تزال إعادة تعيين `small_model` إلى التراجع التلقائي تتطلب تحرير التكوين خارج التطبيق لأن تحديثات `/config` لا يمكنها إزالة المفاتيح.';

  @override
  String get settingsSmallModelUnsetExplanation =>
      'التراجع التلقائي لـ OpenCode نشط لأن `small_model` غير محدد.';

  @override
  String get settingsSoundPickerNotAvailable =>
      'منتقي أصوات النظام غير متاح على هذه المنصة.';

  @override
  String get settingsSpeechDescription =>
      'اضبط الإدخال الصوتي والنماذج دون اتصال والقراءة بصوت عالٍ';

  @override
  String get settingsSpeechRefreshStatus => 'تحديث الحالة';

  @override
  String settingsSpeechSilenceTimeout(String value) {
    return 'مهلة الصمت: $value ثانية';
  }

  @override
  String get settingsSpeechTitle => 'تحويل الكلام إلى نص';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsGroupAlertTypes => 'أنواع التنبيهات';

  @override
  String get settingsGroupBackgroundBehavior => 'السلوك في الخلفية';

  @override
  String get settingsGroupChatDisplay => 'عرض الدردشة';

  @override
  String get settingsGroupCurrentConnection => 'الاتصال الحالي';

  @override
  String get settingsGroupDataAndSync => 'البيانات والمزامنة';

  @override
  String get settingsGroupDataReset => 'البيانات وإعادة التعيين';

  @override
  String get settingsGroupDelivery => 'التوصيل';

  @override
  String get settingsGroupHelp => 'المساعدة';

  @override
  String get settingsGroupLanguageAndChat => 'اللغة والدردشة';

  @override
  String get settingsGroupLayoutAndText => 'التخطيط والنص';

  @override
  String get settingsGroupOfflineModels => 'النماذج دون اتصال';

  @override
  String get settingsGroupOpenCodeDefaults => 'إعدادات OpenCode الافتراضية';

  @override
  String get settingsGroupReadAloud => 'القراءة بصوت عالٍ';

  @override
  String get settingsGroupSavedServers => 'الخوادم المحفوظة';

  @override
  String get settingsGroupThemeAndColor => 'المظهر واللون';

  @override
  String get settingsGroupThisDevice => 'هذا الجهاز';

  @override
  String get settingsGroupVersionUpdates => 'الإصدار والتحديثات';

  @override
  String get settingsGroupVoiceInput => 'الإدخال الصوتي';

  @override
  String get settingsNavigationGroupExperience => 'التجربة';

  @override
  String get settingsNavigationGroupInput => 'الإدخال';

  @override
  String get settingsNavigationGroupSetup => 'الإعداد';

  @override
  String get settingsNavigationGroupSupport => 'المساعدة والتشخيص';

  @override
  String get settingsNavigationNoResults => 'لا توجد إعدادات';

  @override
  String get settingsNavigationSearchHint => 'ابحث في الإعدادات';

  @override
  String get settingsUsernameClearHint =>
      'لا يزال مسح اسم مستخدم محادثة OpenCode يتطلب تعديل التكوين خارج التطبيق.';

  @override
  String get settingsUsernameEnterHint =>
      'أدخل اسم مستخدم لحفظ اسم مخصص لمحادثة OpenCode.';

  @override
  String get settingsUsernameResetExplanation =>
      'لا تزال إعادة تعيين `username` إلى الافتراضي تتطلب تحرير التكوين خارج التطبيق لأن تحديثات `/config` لا يمكنها إزالة المفاتيح.';

  @override
  String get settingsUsernameUnsetExplanation =>
      'يستخدم OpenCode اسم مستخدم النظام لأن `username` غير محدد.';

  @override
  String get setupDebugBun => 'Bun';

  @override
  String get setupDebugBun2 => 'Bun';

  @override
  String get setupDebugCapturedSetupDetails =>
      'لا توجد تفاصيل إعداد ملتقطة بعد';

  @override
  String get setupDebugCapturedSetupLogs => 'سجلات الإعداد الملتقطة';

  @override
  String get setupDebugClear => 'مسح تشخيص الإعداد';

  @override
  String get setupDebugClearSetupDebug => 'مسح تشخيص الإعداد';

  @override
  String get setupDebugCodeWalkCaptureEnough =>
      'إذا لم يلتقط CodeWalk سياقاً كافياً، فتحقق من سجلات OpenCode الرسمية ونقاط نهاية الحالة الصحية مباشرةً:';

  @override
  String get setupDebugCommandPath => 'مسار الأمر';

  @override
  String get setupDebugCommandPath2 => 'مسار الأمر';

  @override
  String get setupDebugCopy => 'نسخ تشخيص الإعداد';

  @override
  String get setupDebugCopySetupDebug => 'نسخ تشخيص الإعداد';

  @override
  String get setupDebugCurrentStatus => 'الحالة الحالية';

  @override
  String get setupDebugDiagnosticsLoading => 'التشخيصات لا تزال قيد التحميل.';

  @override
  String get setupDebugEnvironment => 'تشخيص البيئة';

  @override
  String get setupDebugEnvironmentDiagnostics => 'تشخيص البيئة';

  @override
  String get setupDebugFocusedOpenCodeSetup => 'مُركّز على إعداد OpenCode';

  @override
  String get setupDebugInstallDir => 'دليل التثبيت';

  @override
  String get setupDebugInstallDirectory => 'دليل التثبيت';

  @override
  String get setupDebugLatestLocalServer => 'أحدث مخرجات الخادم المحلي';

  @override
  String get setupDebugLogs => 'سجلات الإعداد الملتقطة';

  @override
  String get setupDebugManual => 'استكشاف الأخطاء وإصلاحها يدوياً';

  @override
  String get setupDebugManualTroubleshooting =>
      'استكشاف الأخطاء وإصلاحها يدوياً';

  @override
  String get setupDebugNetwork => 'الشبكة';

  @override
  String get setupDebugNetwork2 => 'الشبكة';

  @override
  String get setupDebugNoDetails => 'لا توجد تفاصيل إعداد ملتقطة بعد';

  @override
  String get setupDebugNode => 'Node.js';

  @override
  String get setupDebugNodeJs => 'Node.js';

  @override
  String get setupDebugNpm => 'npm';

  @override
  String get setupDebugNpm2 => 'npm';

  @override
  String get setupDebugOpenCode => 'OpenCode';

  @override
  String get setupDebugOpenCode2 => 'OpenCode';

  @override
  String get setupDebugOpenCodeSetupDebug => 'تشخيص إعداد OpenCode';

  @override
  String get setupDebugPlatform => 'المنصة';

  @override
  String get setupDebugPlatform2 => 'المنصة';

  @override
  String get setupDebugRunDiagnosticsTry =>
      'قم بتشغيل التشخيصات، أو جرب طريقة تثبيت، أو حاول تنفيذ تدفق إعداد لالتقاط تفاصيل استكشاف الأخطاء وإصلاحها الخاصة بـ OpenCode هنا.';

  @override
  String get setupDebugScreenCoversOpenCode =>
      'تغطي هذه الشاشة فقط تثبيت OpenCode وتDiagnostics واستكشاف أخطاء الإعداد المحلي وإصلاحها. استخدم سجلات التطبيق لمشكلات وقت تشغيل CodeWalk العامة.';

  @override
  String get setupDebugServerOutput => 'أحدث مخرجات الخادم المحلي';

  @override
  String get setupDebugStatus => 'الحالة الحالية';

  @override
  String setupDebugTimeEntrySource(String source, String time) {
    return '$time - $source';
  }

  @override
  String get setupDebugTimeline => 'المخطط الزمني';

  @override
  String get setupDebugTimeline2 => 'المخطط الزمني';

  @override
  String get setupDebugTitle => 'مُركّز على إعداد OpenCode';

  @override
  String get setupDebugWSL => 'WSL';

  @override
  String get setupDebugWsl => 'WSL';

  @override
  String get shortcutCloseApp => 'إغلاق علامة التبويب/التطبيق';

  @override
  String get shortcutCloseAppDesc =>
      'إغلاق علامة تبويب الجلسة الحالية عند توفرها، وإلا إغلاق التطبيق وفق سلوك المنصة';

  @override
  String get shortcutFocusCloseDrawer => 'تركيز/إغلاق الدرج';

  @override
  String get shortcutFocusCloseDrawerDesc =>
      'التركيز على المدخلات افتراضياً، أو إغلاق الدرج عندما يكون مفتوحاً';

  @override
  String get shortcutFocusInput => 'التركيز على المدخلات';

  @override
  String get shortcutFocusInputDesc => 'نقل التركيز إلى مدخلات النص';

  @override
  String get shortcutGroupApplication => 'التطبيق';

  @override
  String get shortcutGroupGeneral => 'عام';

  @override
  String get shortcutGroupModelAndAgent => 'النموذج والعميل';

  @override
  String get shortcutGroupNavigation => 'التنقل';

  @override
  String get shortcutGroupPrompt => 'المطالبة';

  @override
  String get shortcutGroupSession => 'الجلسة';

  @override
  String get shortcutNewConversation => 'محادثة جديدة';

  @override
  String get shortcutNewConversationDesc => 'إنشاء جلسة دردشة جديدة';

  @override
  String get shortcutNextAgent => 'العميل التالي';

  @override
  String get shortcutNextAgentDesc => 'التبديل إلى العميل المتاح التالي';

  @override
  String get shortcutNextRecentModel => 'النموذج الحديث التالي';

  @override
  String get shortcutNextRecentModelDesc =>
      'التبديل بين النماذج المستخدمة مؤخراً';

  @override
  String get shortcutNextVariant => 'المتغير التالي';

  @override
  String get shortcutNextVariantDesc => 'التبديل بين متغيرات النموذج المتاحة';

  @override
  String get shortcutOpenSettings => 'افتح الإعدادات';

  @override
  String get shortcutOpenSettingsDesc => 'افتح صفحة الإعدادات';

  @override
  String get shortcutPreviousAgent => 'العميل السابق';

  @override
  String get shortcutPreviousAgentDesc => 'التبديل إلى العميل المتاح السابق';

  @override
  String get shortcutQuickOpenFiles => 'فتح سريع للملفات';

  @override
  String get shortcutQuickOpenFilesDesc => 'افتح البحث السريع عن الملفات';

  @override
  String get shortcutQuitApp => 'إنهاء التطبيق';

  @override
  String get shortcutQuitAppDesc => 'فرض الخروج من التطبيق';

  @override
  String get shortcutRefreshData => 'تحديث البيانات';

  @override
  String get shortcutRefreshDataDesc => 'تحديث بيانات الدردشة الحالية';

  @override
  String get shortcutStopResponse => 'إيقاف الاستجابة';

  @override
  String get shortcutStopResponseDesc =>
      'إيقاف الاستجابة النشطة (أثناء الاستجابة)';

  @override
  String get shortcutToggleVoiceInput => 'تبديل الإدخال الصوتي';

  @override
  String get shortcutToggleVoiceInputDesc =>
      'بدء أو إيقاف الإملاء الصوتي في المحرر';

  @override
  String get shortcutsApply => 'تطبيق';

  @override
  String shortcutsConflictConflict(String conflict) {
    return 'تعارض مع $conflict';
  }

  @override
  String get shortcutsKeyboardShortcuts => 'اختصارات لوحة المفاتيح';

  @override
  String get shortcutsReset => 'إعادة تعيين الكل';

  @override
  String get shortcutsSearchEditBindings =>
      'البحث، وتعديل الروابط، وحل التعارضات قبل الحفظ.';

  @override
  String shortcutsSetShortcutWidget(String label) {
    return 'تعيين اختصار: $label';
  }

  @override
  String get shortcutsTheseBindingsStored =>
      'يتم تخزين هذه الروابط في CodeWalk لوقت تشغيل التطبيق الحالي ولا تقوم بتعديل روابط مفاتيح `tui.json` لـ OpenCode.';

  @override
  String get speechAutoStopSilence => 'مهلة صمت الإيقاف التلقائي';

  @override
  String get speechChooseRecognitionEngine =>
      'اختر محرك التعرف، ومهلة الصمت، وخيارات النموذج.';

  @override
  String speechDesktopOnly(String service) {
    return '$service متاح على سطح المكتب فقط.';
  }

  @override
  String get speechDownload => 'تنزيل';

  @override
  String get speechEngine => 'المحرك';

  @override
  String get speechInstalledLanguages => 'اللغات المثبتة';

  @override
  String get speechListeningStopsAutomatically =>
      'يتوقف الاستماع تلقائياً بعد هذا العدد من ثوانٍ من الصمت.';

  @override
  String get speechMicPermissionDisabled => 'إذن الميكروفون معطل.';

  @override
  String speechModelFilesIncomplete(String service) {
    return 'ملفات نموذج $service غير مكتملة.';
  }

  @override
  String get speechMoonshine => 'Moonshine';

  @override
  String get speechMoonshineModelsDesktop => 'نماذج Moonshine (سطح المكتب)';

  @override
  String get speechMoonshineStaysDownloadable =>
      'تظل نماذج Moonshine قابلة للتنزيل وخارج حزمة التطبيق. اختر نموذجاً واحداً لجهاز سطح المكتب هذا وقم بإزالته لاحقاً إذا كنت تريد استعادة المساحة.';

  @override
  String get speechNative => 'أصلي (Native)';

  @override
  String get speechNativeSTTDisabled =>
      'ميزة تحويل الكلام إلى نص الأصلية (Native STT) معطلة على Linux في هذا التطبيق. محرك Parakeet هو المحرك الافتراضي للتثبيتات الجديدة.';

  @override
  String get speechNativeSTTWorks =>
      'على نظام Windows، يستخدم CodeWalk التعرف على الكلام محليًا على الجهاز عبر واجهة الميكروفون WASAPI. التعرف الأصلي على الكلام في Windows معطّل لضمان الاستقرار.';

  @override
  String get speechNativeStartsFaster =>
      'الخيار الأصلي يبدأ بشكل أسرع. يعمل Sherpa بالكامل على الجهاز بإعداد أثقل وتحكم أعمق في النموذج.';

  @override
  String get speechOpenMicrophoneSettings => 'فتح إعدادات الميكروفون';

  @override
  String get speechOpenSpeechPrivacy => 'فتح إعدادات خصوصية الكلام';

  @override
  String get speechOpenSpeechSettings => 'فتح إعدادات الكلام';

  @override
  String get speechParakeet => 'Parakeet';

  @override
  String get speechParakeetModelsDesktop => 'نماذج Parakeet (سطح المكتب)';

  @override
  String get speechParakeetStaysDownloadable =>
      'يظل Parakeet قابلاً للتنزيل وخارج حزمة التطبيق. يعرض حالياً نموذجاً واحداً متعدد اللغات محسناً لـ 25 لغة أوروبية.';

  @override
  String get speechPickLanguagePacks =>
      'اختر حزم اللغات وقم بتنزيل/إزالة النماذج للتعرف على الجهاز.';

  @override
  String get speechRemove => 'إزالة';

  @override
  String speechRuntimeFailed(String service) {
    return 'فشل بدء تشغيل $service.';
  }

  @override
  String get speechSelectSherpaAbove =>
      'حدد Sherpa أعلاه لإدارة حزم اللغات وتنزيل النماذج.';

  @override
  String get speechSenseVoice => 'SenseVoice';

  @override
  String get speechSenseVoiceModelsDesktop => 'نماذج SenseVoice (سطح المكتب)';

  @override
  String get speechSenseVoiceStaysDownloadable =>
      'يظل SenseVoice قابلاً للتنزيل وخارج حزمة التطبيق. وهو أقوى خيار لسطح المكتب هنا للصينية، والكانتونية، واليابانية، والكورية، والإنجليزية.';

  @override
  String get speechSherpa => 'Sherpa';

  @override
  String get speechSherpaExperimentalFail =>
      'محرك Sherpa تجريبي ويمكن أن يفشل في بعض الأجهزة. يفضل استخدام الخيار الأصلي (Native) إذا كنت تريد السلوك الأكثر استقراراً.';

  @override
  String get speechSherpaModelsLinux => 'نماذج Sherpa (Linux)';

  @override
  String get speechSpeechText => 'تحويل الكلام إلى نص';

  @override
  String speechUnavailableOnPlatform(String service) {
    return 'كلام $service غير متاح على هذه المنصة.';
  }

  @override
  String get speechWindowsSetupHint =>
      'يستخدم الإدخال الصوتي في Windows التقاط WASAPI من CodeWalk مع نماذج على الجهاز. أبقِ وصول الميكروفون لتطبيقات سطح المكتب مفعّلًا؛ تفتح الأزرار أدناه إعدادات Windows لاستكشاف الأخطاء وإصلاحها.';

  @override
  String get statusConnected => 'متصل';

  @override
  String get statusDelayed => 'متأخر';

  @override
  String get statusFailed => 'فشل';

  @override
  String get statusOffline => 'غير متصل';

  @override
  String get statusOnline => 'متصل';

  @override
  String get statusReconnecting => 'إعادة الاتصال';

  @override
  String get statusStarting => 'بدء';

  @override
  String get statusStopped => 'متوقف';

  @override
  String get statusStopping => 'إيقاف';

  @override
  String get statusSyncDelayed => 'المزامنة متأخرة';

  @override
  String get tailscaleNoPeers => 'لم يتم العثور على أقران';

  @override
  String get tailscaleNotSupportedOnPlatform =>
      'Tailscale غير مدعوم على هذه المنصة.';

  @override
  String get tailscaleNotSupportedOnWindows =>
      'Tailscale غير مدعوم على ويندوز.';

  @override
  String get tailscalePeerOffline => 'غير متصل';

  @override
  String get tailscaleSelectPeer => 'حدد قرين Tailscale';

  @override
  String get tailscaleWaitingAdminApproval =>
      'عقدة Tailscale هذه تنتظر موافقة المسؤول.';

  @override
  String get terminalClose => 'إغلاق الطرفية';

  @override
  String terminalConnectingTo(String serverName) {
    return 'جاري الاتصال بـ $serverName terminal...';
  }

  @override
  String terminalConnectionFailed(String error) {
    return 'فشل اتصال الطرفية: $error';
  }

  @override
  String get terminalDisconnected => 'تم قطع اتصال الطرفية.';

  @override
  String terminalEmbeddedUnavailable(String serverName) {
    return 'الطرفية المدمجة غير متوفرة بعد في هذا الوقت من التشغيل. استمر في استخدام وضع شل الملحن للأوامر الفردية أو افتح الطرفية من تطبيق CodeWalk مدعوم لـ $serverName.';
  }

  @override
  String get terminalExtraKeyAlt => 'مفتاح Alt';

  @override
  String get terminalExtraKeyArrowDown => 'السهم لأسفل';

  @override
  String get terminalExtraKeyArrowLeft => 'السهم لليسار';

  @override
  String get terminalExtraKeyArrowRight => 'السهم لليمين';

  @override
  String get terminalExtraKeyArrowUp => 'السهم لأعلى';

  @override
  String get terminalExtraKeyControl => 'مفتاح Control';

  @override
  String get terminalExtraKeyEscape => 'مفتاح Escape';

  @override
  String get terminalExtraKeyTab => 'مفتاح Tab';

  @override
  String get terminalExtraKeys => 'مفاتيح إضافية للطرفية';

  @override
  String get terminalHide => 'إخفاء الطرفية';

  @override
  String get terminalMaximize => 'تكبير';

  @override
  String get terminalMinimize => 'تصغير الطرفية';

  @override
  String get terminalNotAvailableYet =>
      'الطرفية المضمنة غير متاحة بعد في وقت التشغيل هذا.';

  @override
  String get terminalOpen => 'فتح الطرفية';

  @override
  String get terminalOpenInfo => 'فتح معلومات الطرفية';

  @override
  String get terminalOpenProjectFirst =>
      'افتح مجلد المشروع قبل بدء طرفية الخادم.';

  @override
  String get terminalOpenToConnect =>
      'افتح الطرفية للاتصال بطرفية مشروع الخادم.';

  @override
  String get terminalReconnect => 'إعادة اتصال الطرفية (Terminal)';

  @override
  String get terminalRestoreSize => 'استعادة الحجم';

  @override
  String get terminalSelectServer => 'حدد خادمًا نشطًا قبل فتح الطرفية.';

  @override
  String get terminalSessionClosed => 'تم إغلاق جلسة الطرفية.';

  @override
  String get terminalTerminal => 'الطرفية';

  @override
  String get terminalTitle => 'طرفية';

  @override
  String get terminalTryAgain => 'حاول مجدداً';

  @override
  String get toolAwaitingInput => 'بانتظار المدخلات';

  @override
  String get toolEditing => 'جاري التعديل';

  @override
  String get toolEditingFiles => 'جاري تعديل الملفات';

  @override
  String get toolFinding => 'جاري البحث عن ملفات';

  @override
  String get toolFindingFiles => 'جاري العثور على الملفات';

  @override
  String get toolPresentationAwaitingInput => 'بانتظار المدخلات';

  @override
  String get toolPresentationEditing => 'جاري التعديل';

  @override
  String get toolPresentationEditingFiles => 'جاري تعديل الملفات';

  @override
  String get toolPresentationFinding => 'جاري البحث';

  @override
  String get toolPresentationFindingFiles => 'جاري العثور على الملفات';

  @override
  String get toolPresentationReading => 'جاري القراءة';

  @override
  String get toolPresentationReadingFile => 'جاري قراءة الملف';

  @override
  String get toolPresentationRunning => 'جاري التشغيل';

  @override
  String get toolPresentationRunningCommand => 'جاري تشغيل الأمر';

  @override
  String toolPresentationRunningTool(String toolName) {
    return 'تشغيل $toolName';
  }

  @override
  String get toolPresentationSearching => 'جاري البحث';

  @override
  String get toolPresentationSearchingCode => 'جاري البحث في الأكواد';

  @override
  String get toolPresentationSearchingWeb => 'جاري البحث في الويب';

  @override
  String get toolPresentationTool => 'أداة';

  @override
  String get toolPresentationUpdatingTaskList => 'جاري تحديث قائمة المهام';

  @override
  String get toolPresentationUpdatingTasks => 'جاري تحديث المهام';

  @override
  String get toolPresentationWaitingInput => 'بانتظار مدخلاتك';

  @override
  String get toolPresentationWriting => 'جاري الكتابة';

  @override
  String get toolPresentationWritingFile => 'جاري كتابة الملف';

  @override
  String get toolReading => 'جاري القراءة';

  @override
  String get toolReadingFile => 'جاري قراءة الملف';

  @override
  String get toolRunning => 'جاري التشغيل';

  @override
  String get toolRunningCommand => 'جاري تشغيل الأمر';

  @override
  String get toolRunningTask => 'جاري تشغيل المهمة';

  @override
  String get toolSearching => 'جاري البحث';

  @override
  String get toolSearchingCode => 'جاري البحث في الأكواد';

  @override
  String get toolSearchingWeb => 'جاري البحث في الويب';

  @override
  String get toolUpdatingTaskList => 'جاري تحديث قائمة المهام';

  @override
  String get toolUpdatingTasks => 'جاري تحديث المهام';

  @override
  String get toolWaitingForInput => 'بانتظار مدخلاتك';

  @override
  String get toolWriting => 'جاري الكتابة';

  @override
  String get toolWritingFile => 'جاري كتابة الملف';

  @override
  String get tourBack => 'رجوع';

  @override
  String get tourSkip => 'تخطي';

  @override
  String get trayQuit => 'خروج';

  @override
  String get trayShow => 'إظهار';

  @override
  String get useOAuthCloudflareAccess => 'استخدام OAuth (Cloudflare Access)';

  @override
  String get useOAuthCloudflareAccessSubtitle =>
      'يفتح متصفحاً لمصادقة Cloudflare Access Managed OAuth المدارة.';

  @override
  String get useOAuthCloudflareAccessUnsupported =>
      'مصادقة Cloudflare Access OAuth غير متوفرة على هذه المنصة. استخدم المصادقة الأساسية (Basic Auth) بدلاً من ذلك.';

  @override
  String get useTailscale => 'استخدام Tailscale';

  @override
  String get useTailscaleSubtitle =>
      'توجيه حركة المرور عبر شبكة Tailscale بدون شبكة VPN للنظام.';

  @override
  String get useTailscaleUnsupported =>
      'شبكة Tailscale غير مدعومة على هذه المنصة.';

  @override
  String get utilityTitle => 'أداة';

  @override
  String get workspaceBrowseDirs => 'تصفح الأدلة';

  @override
  String get workspaceChooseFolderOpen => 'اختر أي مجلد لفتحه كسياق للمشروع.';

  @override
  String workspaceCloseProject(String project) {
    return 'إغلاق $project';
  }

  @override
  String get workspaceClosedProjects => 'المشاريع المغلقة';

  @override
  String workspaceCurrentDirectory(String path) {
    return 'المجلد الحالي: $path';
  }

  @override
  String get workspaceFilterDirs => 'تصفية الأدلة';

  @override
  String get workspaceOpenFolder => 'فتح مجلد';

  @override
  String get workspaceOpenProjectFolder => 'فتح مجلد المشروع';

  @override
  String get workspaceOpenProjects => 'المشاريع المفتوحة';

  @override
  String get workspaceProjectDirectory => 'دليل المشروع';

  @override
  String get workspaceProjectHint => '/repo/my-project';

  @override
  String workspaceRemoveFromHistory(String name) {
    return 'إزالة $name من السجل';
  }

  @override
  String get settingsSessionAttentionTitle => 'تنبيهات الجلسات';

  @override
  String get settingsSessionAttentionDescription =>
      'تعرض حالة الجلسات الجذرية في فقاعة أو لوحة اختيارية.';

  @override
  String get settingsSessionAttentionOff => 'إيقاف';

  @override
  String get settingsSessionAttentionBubble => 'فقاعة';

  @override
  String get settingsSessionAttentionPanel => 'لوحة';

  @override
  String get settingsSessionAttentionPrivacy =>
      'على Android، يؤدي التفعيل إلى تشغيل خدمة مستمرة في المقدمة. يُخزّن نص الرد مشفراً، ولا ترسله خدمة النطق السحابية إلا بعد الضغط على قراءة.';

  @override
  String get settingsSessionAttentionUnavailable =>
      'تنبيهات الجلسات غير متاحة على هذه المنصة.';

  @override
  String get settingsSessionAttentionOpenSettings => 'فتح إعدادات العرض';

  @override
  String get settingsSessionAttentionStop => 'إيقاف تنبيهات الجلسات';

  @override
  String get settingsSessionAttentionThirdPartyTtsWarning =>
      'عند الضغط على قراءة، قد يُرسل نص الرد إلى مزود النطق الخارجي المُعد.';

  @override
  String get workspaceSuggestions => 'اقتراحات';

  @override
  String get sessionTabsGestureHintTitle =>
      'تبويبات الجلسات تحوي عناصر تحكم جديدة';

  @override
  String get sessionTabsGestureHintBody =>
      'انقر نقرًا مزدوجًا أو اضغط بلمسة مزدوجة على تبويب لإغلاقه. انقر بزر الماوس الأيمن أو اضغط مطولاً لفتح إجراءات الجلسة. يمكنك تعطيل التبويبات من مفاتيح تبديل العرض.';

  @override
  String get sessionTabsGestureHintAcknowledge => 'فهمت';

  @override
  String get sessionTabsGestureHintDisableTabs => 'تعطيل التبويبات';

  @override
  String get sessionTabRenameAction => 'إعادة تسمية الجلسة';

  @override
  String sessionTabClosedMessage(String title) {
    return 'تم إغلاق التبويب \"$title\"';
  }

  @override
  String get sessionTabUndo => 'تراجع';

  @override
  String get sessionTabRestoreFailed => 'تعذر استعادة التبويب.';

  @override
  String get sessionTabChangeIconAction => 'تغيير الأيقونة';

  @override
  String get sessionTabIconPickerTitle => 'اختر أيقونة التبويب';

  @override
  String get sessionTabIconUseProjectIcon => 'استخدام أيقونة المشروع';

  @override
  String get sessionTabIconApplied => 'تم تحديث أيقونة التبويب.';

  @override
  String get sessionTabIconSaveFailed => 'تعذر حفظ أيقونة التبويب.';

  @override
  String get sessionTabIconPresetCode => 'الكود';

  @override
  String get sessionTabIconPresetTerminal => 'الطرفية';

  @override
  String get sessionTabIconPresetBug => 'خلل';

  @override
  String get sessionTabIconPresetTasks => 'المهام';

  @override
  String get sessionTabIconPresetLaunch => 'إطلاق';

  @override
  String get sessionTabIconPresetIdea => 'فكرة';

  @override
  String get sessionTabIconPresetResearch => 'بحث';

  @override
  String get sessionTabIconPresetDesign => 'التصميم';

  @override
  String get sessionTabIconPresetData => 'البيانات';

  @override
  String get sessionTabIconPresetCloud => 'سحابة';

  @override
  String get sessionTabIconPresetSecurity => 'الأمان';

  @override
  String get sessionTabIconPresetTools => 'الأدوات';

  @override
  String get workspaceNoActiveContext => 'لا يوجد سياق نشط';

  @override
  String get settingsAppearanceContrastLow => 'منخفض';

  @override
  String get settingsAppearanceContrastStandard => 'قياسي';

  @override
  String get settingsAppearanceContrastMedium => 'متوسط';

  @override
  String get settingsAppearanceContrastMediumHigh => 'متوسط مرتفع';

  @override
  String get settingsNotificationsSystemSoundsWebUnavailable =>
      'غير متاح على الويب.';

  @override
  String get settingsNotificationsSystemSoundsAndroid =>
      'أصوات إشعارات Android من النظام.';

  @override
  String get settingsNotificationsSystemSoundsFreedesktop =>
      'أصوات Freedesktop من /usr/share/sounds/freedesktop/stereo.';

  @override
  String get settingsNotificationsSystemSoundsPlatform =>
      'مدعوم حيثما يكشف نظام التشغيل عن أصوات النظام.';

  @override
  String get serversQuickGuideTitle => 'إعداد سريع';

  @override
  String get serversQuickGuideIntro =>
      'CodeWalk هو التطبيق، وOpenCode هو المحرك الذي يجب أن يكون قيد التشغيل قبل أن يعمل هذا الاتصال.';

  @override
  String get serversQuickGuideStepInstallCli => '1. ثبّت OpenCode CLI.';

  @override
  String get serversQuickGuideRunPowerShell => '2. شغّل في PowerShell:';

  @override
  String get serversQuickGuideRunTerminal => '2. شغّل في الطرفية:';

  @override
  String get serversQuickGuideProtectPassword => 'احمِ الوصول بكلمة مرور';

  @override
  String get serversQuickGuideServerPassword => 'كلمة مرور الخادم';

  @override
  String get serversQuickGuideInstallOptions =>
      'خيارات التثبيت الرسمية الأخرى: سكربت التثبيت، npm، bun، pnpm، Homebrew، أو ملف ثنائي من GitHub Releases.';

  @override
  String get serversQuickGuideVerifyHint =>
      'بعد بدء الخادم، تأكد من استجابة /global/health أو /doc قبل لصق العنوان في CodeWalk.';

  @override
  String get shortcutsPressKeyCombination => 'اضغط مجموعة المفاتيح الآن';

  @override
  String get settingsProvenanceOpenCodeBacked => 'مدعوم من OpenCode';

  @override
  String get settingsProvenanceCodeWalkLocal => 'محلي في CodeWalk';

  @override
  String get settingsProvenanceCodeWalkException => 'استثناء CodeWalk';

  @override
  String get shortcutsErrorInvalid => 'اختصار غير صالح';

  @override
  String get shortcutsErrorUnsupportedKey => 'مفتاح اختصار غير مدعوم';

  @override
  String shortcutsErrorConflict(String conflict) {
    return 'يتعارض مع \"$conflict\"';
  }

  @override
  String get settingsSessionAttentionStopSaveFailed =>
      'تم إيقاف تنبيه الجلسة ولكن تعذّر حفظ الإعداد.';

  @override
  String get settingsSessionAttentionEnableFailed =>
      'تعذّر تمكين تنبيه الجلسة.';

  @override
  String get settingsSessionAttentionSaveFailedStopped =>
      'تعذّر حفظ إعداد تنبيه الجلسة وتم إيقافه.';

  @override
  String get settingsSessionAttentionStillRunning =>
      'تنبيه الجلسة ما زال قيد التشغيل. حاول إيقافه مرة أخرى.';

  @override
  String get settingsSessionAttentionStopFailed =>
      'تعذّر إيقاف تنبيه الجلسة. حاول مرة أخرى.';

  @override
  String get settingsSessionAttentionCapabilityUnavailable =>
      'إمكانية استضافة تنبيه الجلسة غير متاحة.';

  @override
  String get settingsServerFallbackProviderName => 'مُهيأ على الخادم';

  @override
  String get composerStopResponse => 'إيقاف الرد';

  @override
  String get composerSendMessageWhileResponding =>
      'إرسال رسالة أثناء تشغيل الرد';

  @override
  String get composerSendMessage => 'إرسال الرسالة';

  @override
  String get chatTourComposerDescription => 'اكتب طلبك هنا.';

  @override
  String get chatTourSendDescription => 'أرسل رسالتك من هنا.';

  @override
  String get composerAttachmentFallbackName => 'مرفق';

  @override
  String get composerContextFallbackName => 'سياق';

  @override
  String get searchableDropdownSearchHint => 'بحث';

  @override
  String get searchableDropdownEmptyText => 'لا توجد نتائج مطابقة';

  @override
  String get speechApiKeyStorageUnavailable =>
      'التخزين الآمن لمفتاح TTS API غير متاح.';

  @override
  String get speechApiKeyRemoved => 'تمت إزالة مفتاح API.';

  @override
  String get speechApiKeySaved => 'تم حفظ مفتاح API بأمان على هذا الجهاز.';

  @override
  String get speechReadAloudTestText =>
      'هذا اختبار تحويل النص إلى كلام من CodeWalk.';

  @override
  String get speechNativeDisabledWindows =>
      'معطّل على Windows من أجل الاستقرار. استخدم Parakeet أو محركًا آخر محليًا عبر التقاط WASAPI في CodeWalk.';

  @override
  String get speechNativeUnavailableLinux =>
      'غير متاح على Linux. استخدم Parakeet لإدخال الصوت.';

  @override
  String get speechNotAvailableOnPlatform => 'غير متاح على هذه المنصة.';

  @override
  String get speechSherpaUnavailableAndroid =>
      'غير متاح على إصدارات Android المحسّنة لحجم APK صغير.';

  @override
  String get speechMoonshineDesktopOnlyHint =>
      'متاح على سطح المكتب فقط. يبقى Android بالإصدار الأصلي فقط.';

  @override
  String get speechParakeetDesktopOnlyHint =>
      'متاح على سطح المكتب فقط. يستخدم تعرّفًا متعدد اللغات دون اتصال.';

  @override
  String get speechSenseVoiceDesktopOnlyHint =>
      'متاح على سطح المكتب فقط. أقوى ما يكون للصينية والكانتونية واليابانية والكورية والإنجليزية.';

  @override
  String get speechNativeSubtitle => 'بدء تشغيل أبسط وأسرع.';

  @override
  String get speechSherpaSubtitle =>
      'أثقل وتجريبي وعرضة للأخطاء، وغالبًا أكثر دقة مع النماذج التي يتم تنزيلها.';

  @override
  String get speechMoonshineSubtitle =>
      'مسار تجريبي لسطح المكتب فقط يستخدم تعرّف sherpa_onnx دون اتصال ونماذج قابلة للتنزيل.';

  @override
  String get speechParakeetSubtitle =>
      'مسار NeMo transducer دون اتصال لسطح المكتب فقط مع نموذج واحد متعدد اللغات قابل للتنزيل.';

  @override
  String get speechSenseVoiceSubtitle =>
      'مسار دون اتصال لسطح المكتب فقط مضبوط للصينية والكانتونية واليابانية والكورية والإنجليزية.';

  @override
  String get speechMoonshineModel => 'نموذج Moonshine';

  @override
  String get speechSherpaLanguage => 'لغة Sherpa';

  @override
  String get speechSearchSherpaLanguage => 'ابحث عن لغة Sherpa';

  @override
  String get speechNoLanguagePacksFound => 'لم يتم العثور على حزم لغات';

  @override
  String get speechTextToSpeechProvider => 'مزوّد تحويل النص إلى كلام';

  @override
  String get speechProviderSystemNative => 'النظام / الأصلي';

  @override
  String get speechProviderEdgeExperimental => 'Microsoft Edge Speech (تجريبي)';

  @override
  String get speechProviderOpenAiCompatible => 'متوافق مع OpenAI';

  @override
  String get speechEdgeExperimentalTitle => 'Microsoft Edge Speech تجريبي';

  @override
  String get speechEdgeExperimentalDescription =>
      'يستخدم خدمة القراءة بصوت عالٍ غير الرسمية من Edge مباشرة من هذا الجهاز. يُرسل نص الرسالة إلى Microsoft عند استخدام القراءة بصوت عالٍ، وقد تتعطل الخدمة إذا غيّرت Microsoft البروتوكول الخاص.';

  @override
  String get speechEdgeVoice => 'صوت Edge';

  @override
  String get speechEdgeVoiceListUnavailable =>
      'يتم استخدام صوت Edge الافتراضي. تعذّر تحميل قائمة الأصوات الآن.';

  @override
  String get speechEdgeVoicesLoaded =>
      'تم التحميل من أصوات Microsoft Edge Speech.';

  @override
  String get speechCloudTtsPrivacy => 'خصوصية TTS السحابي';

  @override
  String get speechCloudTtsPrivacyDescription =>
      'يرسل TTS السحابي نص رسالة المساعد المحددة إلى المزوّد المُهيأ. تُخزَّن مفاتيح API في تخزين آمن على هذا الجهاز.';

  @override
  String get speechBaseUrl => 'العنوان الأساسي';

  @override
  String get speechApiKey => 'مفتاح API';

  @override
  String get speechApiKeySavedHelper =>
      'يوجد مفتاح محفوظ. أدخل قيمة جديدة لاستبداله، أو احفظ قيمة فارغة لإزالته.';

  @override
  String get speechNoApiKeySaved => 'لا يوجد مفتاح API محفوظ.';

  @override
  String get speechSaveApiKey => 'حفظ مفتاح API';

  @override
  String get speechModel => 'النموذج';

  @override
  String get speechPitchNotSupported =>
      'نبرة الصوت غير مدعومة في TTS المتوافق مع OpenAI وتكون مخفية لهذا المزوّد.';

  @override
  String get speechTestVoice => 'اختبار الصوت';

  @override
  String get dialogMoonshineVoiceSetupDescription =>
      'يعمل Moonshine محليًا عبر sherpa_onnx. اختر نموذجًا مرة واحدة ونزّله لهذا الجهاز المكتبي فقط.';

  @override
  String get dialogParakeetVoiceSetupDescription =>
      'يعمل Parakeet محليًا عبر تعرّف sherpa_onnx دون اتصال. نزّله مرة واحدة لهذا الجهاز المكتبي لتفعيل التعرف على الكلام متعدد اللغات.';

  @override
  String get dialogSenseVoiceSetupDescription =>
      'يعمل SenseVoice محليًا عبر تعرّف sherpa_onnx دون اتصال. وهو أقوى ما يكون للصينية والكانتونية واليابانية والكورية والإنجليزية.';

  @override
  String get dialogSherpaVoiceSetupDescription =>
      'يتطلب إدخال الصوت عبر Sherpa نموذج كلام محليًا على الجهاز. اختر لغتك ونزّله مرة واحدة (~147 MB).';

  @override
  String speechSilenceSeconds(String value) {
    return '$value ثانية';
  }

  @override
  String speechModelInstalled(String modelId) {
    return 'تم تثبيت النموذج ($modelId)';
  }

  @override
  String speechModelMissing(String modelId) {
    return 'النموذج مفقود ($modelId)';
  }

  @override
  String speechModelSizeMb(String sizeMb) {
    return '~$sizeMb MB';
  }

  @override
  String speechSystemDefaultLanguage(String language) {
    return 'الافتراضي في النظام ($language)';
  }

  @override
  String speechModelListLoadFailed(String error, String service) {
    return 'فشل تحميل قائمة نماذج $service: $error';
  }

  @override
  String speechDownloadFailed(String error) {
    return 'فشل التنزيل: $error';
  }

  @override
  String speechFailedToRemoveModel(String error) {
    return 'فشل إزالة النموذج: $error';
  }

  @override
  String speechBaseUrlExample(String url) {
    return 'مثال: $url';
  }

  @override
  String speechModelDefaultHelper(String model) {
    return 'الافتراضي: $model';
  }

  @override
  String get notificationPermissionOrQuestionNeedsInput =>
      'إذن أداة أو سؤال يحتاج إلى إدخال منك.';

  @override
  String get notificationPermissionNeedsInput =>
      'إذن أداة يحتاج إلى إدخال منك.';

  @override
  String get notificationQuestionNeedsInput => 'سؤال أداة يحتاج إلى إدخال منك.';

  @override
  String get notificationSessionError => 'أبلغت إحدى الجلسات عن خطأ.';

  @override
  String get notificationChannelErrors => 'أخطاء CodeWalk';

  @override
  String get notificationChannelErrorsDescription => 'تنبيهات أخطاء CodeWalk';

  @override
  String get notificationChannelPermissions => 'أذونات CodeWalk';

  @override
  String get notificationChannelPermissionsDescription =>
      'تنبيهات CodeWalk التي تتطلب إجراءً';

  @override
  String get notificationChannelAgent => 'وكيل CodeWalk';

  @override
  String get notificationChannelAgentDescription =>
      'تنبيهات اكتمال وكيل CodeWalk';

  @override
  String get notificationActionOpen => 'فتح';

  @override
  String get foregroundMonitorNotificationBody =>
      'التنبيهات الخلفية الموثوقة نشطة';

  @override
  String get foregroundMonitorNotificationTitle => 'المراقبة الخلفية نشطة';

  @override
  String get foregroundMonitorNotificationOneSession => 'مراقبة جلسة واحدة';

  @override
  String foregroundMonitorNotificationSessionCount(int count) {
    return 'مراقبة $count جلسات';
  }

  @override
  String sessionAttentionSemanticLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جلسات تحتاج إلى انتباه',
      one: 'جلسة واحدة تحتاج إلى انتباه',
    );
    return '$_temp0';
  }

  @override
  String get sessionAttentionOverlayPermissionRequired =>
      'مطلوب إذن العرض فوق التطبيقات الأخرى.';

  @override
  String get sessionAttentionIosInAppOnly =>
      'تنبيه الجلسة متاح داخل CodeWalk فقط.';

  @override
  String get sessionAttentionOverlayPermissionGrantPrompt =>
      'امنح إذن العرض فوق التطبيقات الأخرى، ثم حاول مرة أخرى.';

  @override
  String get sessionAttentionAndroidStartFailed =>
      'تعذّر بدء خدمة تنبيه الجلسة على Android.';

  @override
  String chatMessageTruncatedChars(int count, String reason) {
    return '[تم اقتطاع $count حرفًا] $reason';
  }

  @override
  String get chatMessageJustNow => 'الآن';

  @override
  String chatMessageMinutesAgo(int count) {
    return 'قبل $count د';
  }

  @override
  String chatMessageHoursAgo(int count) {
    return 'قبل $count س';
  }

  @override
  String chatMessageDaysAgo(int count) {
    return 'قبل $count يوم';
  }

  @override
  String chatMessageDateTime(int day, int hour, int minute, int month) {
    return '$month/$day $hour:$minute';
  }

  @override
  String get chatMessageYourMessage => 'رسالتك';

  @override
  String get chatMessageAssistantMessage => 'رسالة المساعد';

  @override
  String chatMessageStepStarted(int step) {
    return 'بدأت الخطوة #$step';
  }

  @override
  String chatMessageStepStartedWithSnapshot(String snapshot, int step) {
    return 'بدأت الخطوة #$step: $snapshot';
  }

  @override
  String chatMessageStepFinished(
    String cost,
    String reason,
    int step,
    int tokens,
  ) {
    return 'انتهت الخطوة #$step: $reason • رموز $tokens • \$$cost';
  }

  @override
  String chatMessagePatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تصحيحات',
      one: 'تصحيح واحد',
    );
    return '$_temp0';
  }

  @override
  String get chatMessageToolRun => 'تشغيل الأداة';

  @override
  String get chatMessageToolExecution => 'تنفيذ الأداة';

  @override
  String chatMessageToolChainMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count إضافي',
      one: '+1 إضافي',
    );
    return '$_temp0';
  }

  @override
  String chatMessageToolChainExtraTypes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count أنواع',
      one: '+1 نوع',
    );
    return '$_temp0';
  }

  @override
  String chatMessageToolAttentionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count بحاجة إلى انتباه',
      one: '1 بحاجة إلى انتباه',
    );
    return '$_temp0';
  }

  @override
  String chatMessageToolDoneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مكتملة',
      one: '1 مكتمل',
    );
    return '$_temp0';
  }

  @override
  String get chatMessageToolCallsTitle => 'استدعاءات الأدوات';

  @override
  String get chatMessageDiffPreviewTruncated =>
      'تم اقتطاع معاينة الفرق من أجل استقرار التطبيق.';

  @override
  String get chatMessageLargeMessageTruncated =>
      'تم اقتطاع معاينة الرسالة الكبيرة من أجل استقرار التطبيق.';

  @override
  String get chatMessageInvalidLinkFormat => 'تنسيق رابط غير صالح';

  @override
  String get chatMessageUnableToOpenLink => 'تعذّر فتح الرابط';

  @override
  String sessionTodoInProgressCompact(int current, int total) {
    return '$current/$total قيد التنفيذ';
  }

  @override
  String sessionTodoTaskProgress(String content, int index, int total) {
    return 'المهمة $index/$total $content';
  }

  @override
  String sessionTodoDoneCompact(int count, int total) {
    return '$count/$total منجز';
  }

  @override
  String sessionTodoCompletedCount(int count, int total) {
    return 'المهام $count/$total مكتملة';
  }

  @override
  String sessionTodoTasksCount(int count) {
    return 'المهام ($count)';
  }

  @override
  String questionStepOfReview(int current, int total) {
    return 'الخطوة $current من $total - مراجعة';
  }

  @override
  String questionStepOfQuestion(int current, int total) {
    return 'الخطوة $current من $total - سؤال';
  }

  @override
  String get questionCustomAnswer => 'إجابة مخصصة';

  @override
  String get questionSubmitAnswers => 'إرسال الإجابات';

  @override
  String get questionReviewAnswers => 'مراجعة الإجابات';

  @override
  String permissionRequestTitle(String permission) {
    return 'طلب إذن: $permission';
  }

  @override
  String get sessionTitleCannotBeEmpty => 'لا يمكن أن يكون العنوان فارغًا';

  @override
  String get filesFailedToLoad => 'فشل تحميل الملفات';

  @override
  String get filesFailedToSearch => 'فشل البحث في الملفات';

  @override
  String get filesNoOpenFilesHint => 'لا توجد ملفات مفتوحة بعد. اكتب للبحث.';

  @override
  String get filesNoContentMatches => 'لم يتم العثور على تطابقات في المحتوى';

  @override
  String filesOpenFilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملفات مفتوحة',
      one: 'ملف واحد مفتوح',
    );
    return '$_temp0';
  }

  @override
  String filesLinesSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أسطر محددة',
      one: 'سطر واحد محدد',
    );
    return '$_temp0';
  }

  @override
  String get filesDraftTooLargeToSave =>
      'المسودة كبيرة جداً بحيث لا يمكن حفظها من المحرر.';

  @override
  String get filesSaveChangesBeforeClose =>
      'احفظ التغييرات قبل إغلاق هذا الملف.';

  @override
  String get filesSaveChangesBeforePathChange =>
      'احفظ التغييرات قبل تغيير هذا المسار.';

  @override
  String get filesWaitForSaveBeforePathChange =>
      'انتظر انتهاء حفظ الملف قبل تغيير هذا المسار.';

  @override
  String get filesWaitForFileOperation => 'انتظر انتهاء عملية الملف.';

  @override
  String get filesLargeFileReadOnly =>
      'تُفتح الملفات الكبيرة للقراءة فقط للحفاظ على استجابة التحرير.';

  @override
  String get filesCheckingWriteSupport =>
      'جاري التحقق من دعم الكتابة للملفات...';

  @override
  String get filesActiveProjectRequired =>
      'تتطلب عمليات الملفات مجلد مشروع نشطاً.';

  @override
  String get filesReloadSkippedUnsavedChanges =>
      'توجد تغييرات غير محفوظة؛ تم تخطي إعادة التحميل.';

  @override
  String get filesFailedToLoadContent => 'فشل تحميل محتوى الملف';

  @override
  String get filesFileSaved => 'تم حفظ الملف.';

  @override
  String get filesParentNotDirectory => 'المجلد الأصلي ليس دليلاً.';

  @override
  String get filesMalformedResponse => 'أعادت عملية الملفات استجابة غير صالحة.';

  @override
  String get filesShellCommandDidNotComplete =>
      'لم يكتمل أمر الشل الخاص بعملية الملفات.';

  @override
  String get filesShellCommandNoResult =>
      'لم يُرجع أمر الشل الخاص بعملية الملفات أي نتيجة.';

  @override
  String get filesShellCommandTruncated =>
      'تم اقتطاع أمر الشل الخاص بعملية الملفات بواسطة الخادم.';

  @override
  String get filesShellCommandSyntaxError =>
      'فشل أمر الشل الخاص بعملية الملفات بسبب خطأ في بناء الجملة.';

  @override
  String get filesShellUtilityNotFound => 'لم يتم العثور على أداة شل مطلوبة.';

  @override
  String get filesShellCommandFailed =>
      'فشل أمر الشل الخاص بعملية الملفات قبل إرجاع نتيجة.';

  @override
  String get attachmentSaveTitle => 'حفظ المرفق';

  @override
  String get attachmentBrowserSandboxLocalFile =>
      'يمنع صندوق حماية المتصفح فتح المرفقات المحلية file:// مباشرة.';

  @override
  String get attachmentLocalPathBrowserBlocked =>
      'يشير هذا المرفق إلى مسار محلي لا يمكن فتحه من المتصفح.';

  @override
  String terminalConnectedTo(String directory, String serverName) {
    return 'متصل بـ $serverName في $directory';
  }

  @override
  String get terminalTransportUnavailable => 'ناقل الطرفية غير متاح.';

  @override
  String get chatSlashCommandNew => 'إنشاء جلسة دردشة جديدة';

  @override
  String get chatSlashCommandModels => 'فتح محدد النماذج';

  @override
  String get chatSlashCommandSessions => 'فتح قائمة المحادثات';

  @override
  String get chatSlashCommandAgent => 'فتح محدد الوكلاء';

  @override
  String get chatSlashCommandOpen => 'إجراء سريع لفتح ملف';

  @override
  String get chatSlashCommandHelp => 'إظهار تعليمات الأمر';

  @override
  String get chatSlashCommandCompact => 'ضغط سياق الجلسة الحالية';

  @override
  String get chatSlashCommandThinking => 'تبديل فقاعات التفكير';

  @override
  String get chatSlashCommandUndo => 'التراجع عن آخر دور ظاهر للمستخدم';

  @override
  String get chatSlashCommandRedo => 'إعادة إجراء آخر دور تم التراجع عنه';

  @override
  String chatSessionSubConversationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count محادثات فرعية',
      one: 'محادثة فرعية واحدة',
    );
    return '$_temp0';
  }

  @override
  String chatMessageWeeksAgo(int count) {
    return 'قبل $count أ';
  }

  @override
  String chatMessageShortDate(int day, int month) {
    return '$month/$day';
  }

  @override
  String get chatProviderErrorLoadSessionStatus => 'فشل تحميل حالة الجلسة';

  @override
  String get chatProviderErrorLoadSessionDetails =>
      'تعذر تحميل بعض تفاصيل الجلسة';

  @override
  String chatProviderErrorLoadSessionList(String error) {
    return 'فشل تحميل قائمة الجلسات: $error';
  }

  @override
  String get chatProviderErrorCreateSession => 'فشل إنشاء الجلسة';

  @override
  String get chatProviderErrorSelectProviderModelBeforeSend =>
      'حدد مزوداً متصلاً أو نموذج OpenCode مجاني قبل الإرسال';

  @override
  String get chatProviderErrorStartMessageSend => 'فشل بدء إرسال الرسالة';

  @override
  String get chatProviderErrorStopUnavailable =>
      'الإيقاف غير متاح للجلسة الحالية';

  @override
  String get chatProviderErrorWaitForResponseFinish =>
      'انتظر انتهاء الاستجابة الحالية قبل الضغط';

  @override
  String get chatProviderErrorCompactUnavailable =>
      'ضغط السياق غير متاح للجلسة الحالية';

  @override
  String get chatProviderErrorSelectModelBeforeCompact =>
      'حدد نموذجاً قبل ضغط السياق';

  @override
  String get chatProviderErrorCompactSessionContext => 'فشل ضغط سياق الجلسة';

  @override
  String get chatProviderErrorNetwork =>
      'فشل الاتصال بالشبكة. يرجى التحقق من إعدادات الشبكة';

  @override
  String get chatProviderErrorServer => 'خطأ في الخادم. يرجى المحاولة لاحقاً';

  @override
  String get chatProviderErrorNotFound => 'المورد غير موجود';

  @override
  String get chatProviderErrorInvalidInput => 'معلمات إدخال غير صالحة';

  @override
  String get chatProviderErrorUnknown => 'خطأ غير معروف. يرجى المحاولة لاحقاً';

  @override
  String get chatProviderErrorSessionFallback => 'خطأ في الجلسة';

  @override
  String get projectProviderErrorNoProjectContext =>
      'لا يتوفر سياق مشروع من الخادم';

  @override
  String projectProviderErrorInitializeFailed(String error) {
    return 'فشل تهيئة سياق المشروع: $error';
  }

  @override
  String get projectProviderErrorSwitchProjectNotFound =>
      'فشل تبديل المشروع: المشروع غير موجود';

  @override
  String get projectProviderErrorSwitchDirectoryEmpty =>
      'فشل تبديل المشروع: الدليل فارغ';

  @override
  String get projectProviderErrorAtLeastOneContext =>
      'يجب أن يبقى سياق واحد على الأقل مفتوحاً';

  @override
  String get projectProviderErrorReopenProjectNotFound =>
      'فشل إعادة فتح المشروع: المشروع غير موجود';

  @override
  String get projectProviderErrorOnlyClosedArchivable =>
      'يمكن أرشفة المشاريع المغلقة فقط';

  @override
  String get projectProviderErrorArchiveProjectNotFound =>
      'فشل أرشفة المشروع: المشروع غير موجود';

  @override
  String get projectProviderErrorArchiveProjectPathInvalid =>
      'فشل أرشفة المشروع: مسار المشروع غير صالح';

  @override
  String projectProviderErrorLoadWorkspaces(String error) {
    return 'فشل تحميل مساحات العمل: $error';
  }

  @override
  String get projectProviderErrorWorkspaceNameEmpty =>
      'لا يمكن أن يكون اسم مساحة العمل فارغاً';

  @override
  String projectProviderErrorCreateWorkspace(String error) {
    return 'فشل إنشاء مساحة العمل: $error';
  }

  @override
  String projectProviderErrorResetWorkspace(String error) {
    return 'فشل إعادة تعيين مساحة العمل: $error';
  }

  @override
  String projectProviderErrorDeleteWorkspace(String error) {
    return 'فشل حذف مساحة العمل: $error';
  }

  @override
  String get projectProviderErrorDirectoryEmpty =>
      'لا يمكن أن يكون الدليل فارغاً';

  @override
  String projectProviderErrorListDirectories(String error) {
    return 'فشل سرد الأدلة: $error';
  }

  @override
  String projectProviderErrorValidateDirectory(String error) {
    return 'فشل التحقق من الدليل: $error';
  }

  @override
  String get projectProviderErrorPathEmpty => 'لا يمكن أن يكون المسار فارغاً';

  @override
  String projectProviderErrorListFiles(String error) {
    return 'فشل سرد الملفات: $error';
  }

  @override
  String projectProviderErrorSearchFiles(String error) {
    return 'فشل البحث في الملفات: $error';
  }

  @override
  String projectProviderErrorContentSearchUnavailable(String error) {
    return 'البحث في المحتوى غير متاح: $error';
  }

  @override
  String projectProviderErrorSearchSymbols(String error) {
    return 'فشل البحث عن الرموز: $error';
  }

  @override
  String projectProviderErrorReadFile(String error) {
    return 'فشل قراءة الملف: $error';
  }

  @override
  String projectProviderErrorLoadProjectList(String error) {
    return 'فشل تحميل قائمة المشاريع: $error';
  }

  @override
  String get workspaceProjectRemovedFromHistory => 'تمت إزالة المشروع من السجل';

  @override
  String workspaceProjectContextOpened(String directory) {
    return 'تم فتح سياق المشروع: $directory';
  }

  @override
  String workspaceFailedToOpenProjectContext(String directory) {
    return 'فشل فتح سياق المشروع: $directory';
  }

  @override
  String get chatAbortNotice => 'ما الذي تريد فعله بشكل مختلف؟';

  @override
  String sessionTitleToday(String date, String time) {
    return 'اليوم $time ($date)';
  }

  @override
  String sessionTitleYesterday(String date, String time) {
    return 'أمس $time ($date)';
  }

  @override
  String sessionTitleWeekday(String date, String time, String weekday) {
    return '$weekday $time ($date)';
  }

  @override
  String sessionTitleDateAndTime(String date, String time) {
    return '$date $time';
  }

  @override
  String get sessionWeekdayMon => 'الاثنين';

  @override
  String get sessionWeekdayTue => 'الثلاثاء';

  @override
  String get sessionWeekdayWed => 'الأربعاء';

  @override
  String get sessionWeekdayThu => 'الخميس';

  @override
  String get sessionWeekdayFri => 'الجمعة';

  @override
  String get sessionWeekdaySat => 'السبت';

  @override
  String get sessionWeekdaySun => 'الأحد';

  @override
  String get forwardTimeNow => 'الآن';

  @override
  String forwardTimeMinutes(int count) {
    return '$count د';
  }

  @override
  String forwardTimeHours(int count) {
    return '$count س';
  }

  @override
  String forwardTimeDays(int count) {
    return '$count يوم';
  }

  @override
  String forwardTimeWeeks(int count) {
    return '$count أ';
  }

  @override
  String get settingsBehaviorConfigFieldDefaultModel => 'النموذج الافتراضي';

  @override
  String get settingsBehaviorConfigFieldDefaultAgent => 'الوكيل الافتراضي';

  @override
  String get settingsBehaviorConfigFieldSmallModel => 'النموذج الصغير';

  @override
  String get settingsBehaviorConfigFieldAutoUpdateMode =>
      'وضع التحديث التلقائي';

  @override
  String get settingsBehaviorConfigFieldSnapshotSetting => 'إعداد اللقطة';

  @override
  String get settingsBehaviorConfigFieldConversationUsername =>
      'اسم مستخدم المحادثة';

  @override
  String get settingsBehaviorConfigFieldSharingDefault => 'الافتراضي للمشاركة';

  @override
  String get speechMicNoInputDevice => 'لا يتوفر جهاز إدخال ميكروفون.';

  @override
  String get speechMicDeviceBusy =>
      'الميكروفون الافتراضي قيد الاستخدام حالياً بواسطة تطبيق آخر.';

  @override
  String get speechMicUnsupportedFormat =>
      'تنسيق الميكروفون الافتراضي غير مدعوم.';

  @override
  String get speechMicSpeechPrivacy =>
      'قد تكون خدمات الكلام في Windows معطلة (خصوصية الكلام، أو التعرف على الكلام عبر الإنترنت، أو حزم اللغات).';

  @override
  String get speechMicBackendUnavailable =>
      'الواجهة الخلفية لميكروفون Windows غير متاحة في هذا الإصدار.';

  @override
  String speechEngineFallbackNotice(String fallback, String reason) {
    return 'محرك تحويل الكلام إلى نص المحدد غير متاح ($reason). سيتم استخدام $fallback بدلاً منه.';
  }

  @override
  String get oauthFlowSecureStorageUnavailable =>
      'التخزين الآمن لبيانات الاعتماد غير متاح لـ OAuth.';

  @override
  String get oauthFlowUnexpectedError =>
      'فشل تدفق OAuth بشكل غير متوقع. يرجى المحاولة مرة أخرى.';

  @override
  String get oauthFlowNoEndpointsDiscovered =>
      'لم يتم اكتشاف نقاط نهاية OAuth. فعّل Managed OAuth في لوحة تحكم Cloudflare → Access → Applications → [هذا التطبيق].';

  @override
  String get oauthFlowTokenResponseMissingAccessToken =>
      'لم تتضمن استجابة رمز OAuth رمز وصول.';

  @override
  String get oauthFlowProfileChanged =>
      'تغير ملف تعريف الخادم قبل اكتمال OAuth.';

  @override
  String get oauthFlowMetadataMissingEndpoints =>
      'تفتقر بيانات OAuth الوصفية إلى نقاط نهاية التفويض/الرموز.';

  @override
  String get oauthFlowCallbackNotCompleted =>
      'لم يكتمل رد الاتصال الخاص بالتفويض';

  @override
  String get oauthFlowProviderDeclined =>
      'رفض خادم التفويض طلب OAuth. يرجى المحاولة مرة أخرى.';

  @override
  String get oauthFlowCallbackValidationFailed =>
      'فشل التحقق من رد اتصال OAuth. يرجى المحاولة مرة أخرى.';

  @override
  String get oauthFlowCallbackServerStartFailed =>
      'فشل بدء خادم رد الاتصال المحلي لـ OAuth.';

  @override
  String get oauthFlowSignInCanceled => 'تم إلغاء تسجيل الدخول عبر OAuth.';

  @override
  String get oauthFlowBrowserOpenFailed =>
      'تعذر فتح متصفح النظام لتسجيل الدخول عبر OAuth.';

  @override
  String get oauthFlowCallbackTimeout =>
      'لم يصل أي رد تفويض إلى التطبيق خلال 5 دقائق. كان من المتوقع أن يعيد المتصفح التوجيه إلى عنوان رد الاتصال المحلي بعد الموافقة. إذا أظهر المتصفح خطأ اتصال بدلاً من ذلك، فإن هذا الجهاز أو الشبكة تحظر عمليات إعادة التوجيه إلى الحلقة المحلية.';

  @override
  String oauthFlowTokenExchangeTransientFailure(int maxAttempts) {
    return 'فشل تبادل الرمز بعد $maxAttempts محاولات بسبب مشكلة شبكة مؤقتة. يرجى المحاولة مرة أخرى.';
  }

  @override
  String oauthFlowTokenExchangeHttpFailure(int statusCode) {
    return 'فشل تبادل الرمز (HTTP $statusCode). يرجى المحاولة مرة أخرى.';
  }

  @override
  String get oauthFlowTokenExchangeUnexpectedFailure =>
      'فشل تبادل الرمز بشكل غير متوقع. يرجى المحاولة مرة أخرى.';

  @override
  String get oauthFlowTokenExchangeIncomplete =>
      'لم يكتمل تبادل الرمز بعد إرسال رمز التفويض. يرجى بدء تسجيل الدخول عبر OAuth مرة أخرى.';

  @override
  String get speechReadAloudFailed => 'فشل تحويل النص إلى كلام.';

  @override
  String get speechReadAloudNoText => 'لا يوجد نص للقراءة بصوت عالٍ.';

  @override
  String get speechEdgeTextTooLong =>
      'يمكن لـ Microsoft Edge Speech قراءة ما يصل إلى 4096 بايت في المرة الواحدة.';

  @override
  String get speechEdgeMalformedAudio =>
      'أعاد Microsoft Edge Speech بيانات صوتية تالفة.';

  @override
  String get speechEdgeUnsupportedAudio =>
      'أعاد Microsoft Edge Speech بيانات صوتية غير مدعومة.';

  @override
  String get speechEdgeUnsupportedFrame =>
      'أعاد Microsoft Edge Speech إطار websocket غير مدعوم.';

  @override
  String get speechEdgeSynthesisInterrupted =>
      'انتهى Microsoft Edge Speech قبل اكتمال التوليف الصوتي.';

  @override
  String get speechEdgeEmptyAudio =>
      'أعاد Microsoft Edge Speech استجابة صوتية فارغة.';

  @override
  String get speechEdgeTimedOut => 'انتهت مهلة Microsoft Edge Speech.';

  @override
  String get speechEdgeUnreachable => 'تعذر الوصول إلى Microsoft Edge Speech.';

  @override
  String get speechApiKeyMissing =>
      'أضف مفتاح API في الإعدادات > الكلام لاستخدام مزود TTS هذا.';

  @override
  String get speechProviderEmptyAudio => 'أعاد مزود TTS استجابة صوتية فارغة.';

  @override
  String get speechProviderRequestRejected => 'رفض مزود TTS طلب الكلام.';

  @override
  String get speechApiKeyRejected => 'رفض المزود مفتاح API الخاص بـ TTS.';

  @override
  String get speechProviderQuotaRateLimit => 'أبلغ مزود TTS عن حصة أو حد معدل.';

  @override
  String get speechProviderTemporarilyUnavailable =>
      'مزود TTS غير متاح مؤقتاً.';

  @override
  String get speechProviderUnreachable => 'تعذر الوصول إلى مزود TTS.';

  @override
  String appProviderErrorFailedToStartProcess(String tool) {
    return 'فشل بدء عملية $tool.';
  }

  @override
  String appProviderErrorToolNotAvailable(String runtime, String tool) {
    return '$tool غير متوفر. ثبّت $runtime أولاً.';
  }

  @override
  String appProviderErrorToolInstallFailed(int exitCode, String tool) {
    return 'فشل تثبيت $tool برمز الخروج $exitCode.';
  }

  @override
  String appProviderErrorBunBootstrapFailed(int exitCode) {
    return 'فشل إقلاع Bun برمز الخروج $exitCode.';
  }

  @override
  String get appProviderErrorInstalledButNotFoundInPath =>
      'اكتمل تثبيت OpenCode لكن الأمر لم يُعثر عليه في PATH.';

  @override
  String get appProviderErrorInstalledButPathNotResolved =>
      'اكتمل تثبيت OpenCode لكن تعذر تحديد مسار الأمر.';

  @override
  String appProviderErrorConfiguredCommandNotFound(String tool) {
    return 'لم يُعثر على الأمر المُهيأ و$tool غير موجود في PATH.';
  }

  @override
  String get appProviderErrorConfiguredCommandPathMissing =>
      'مسار الأمر المُهيأ غير موجود.';

  @override
  String get appProviderErrorConfiguredCommandVersionCheckFailed =>
      'الأمر المُهيأ موجود لكن فشل فحص الإصدار.';

  @override
  String get appProviderErrorConfiguredCommandExecutionFailed =>
      'تعذر تنفيذ الأمر المُهيأ.';

  @override
  String get appProviderWslCheckWindowsOnly =>
      'فحص WSL ينطبق على نظام Windows فقط.';

  @override
  String get appProviderDesktopBuildRequired =>
      'استخدم نسخة سطح المكتب لتهيئة خادم محلي مُدار.';

  @override
  String get appProviderKnownInstallationDirectoryDetected =>
      'تم الاكتشاف من دليل تثبيت معروف.';

  @override
  String appProviderKnownInstallationPathRefreshHint(String appName) {
    return 'تم الاكتشاف من دليل تثبيت معروف. قد تحتاج PATH إلى التحديث؛ أعد فتح $appName إذا لم يُكتشف تثبيت حديث بعد.';
  }

  @override
  String get appProviderErrorReleaseMetadataFetchFailed =>
      'فشل جلب بيانات أحدث إصدار من GitHub.';

  @override
  String get appProviderErrorReleaseAssetListMissing =>
      'لم تتضمن بيانات أحدث إصدار قائمة الأصول.';

  @override
  String get appProviderErrorNoCompatibleAsset =>
      'لم يُعثر على أصل ثنائي متوافق لـ OpenCode.';

  @override
  String get appProviderErrorDownloadAssetFailed =>
      'فشل تنزيل أصل OpenCode المحدد.';

  @override
  String get appProviderErrorChecksumVerificationFailed =>
      'فشل التحقق من المجموع الاختباري للأصل الذي تم تنزيله.';

  @override
  String get appProviderErrorExtractArchiveFailed =>
      'فشل استخراج أرشيف OpenCode الثنائي.';

  @override
  String appProviderErrorExecutableNotFound(String tool) {
    return 'تعذر العثور على الملف التنفيذي لـ $tool في الملفات المستخرجة.';
  }

  @override
  String get chatNoResponseFromServer =>
      'لا توجد استجابة من الخادم. يرجى المحاولة مرة أخرى.';

  @override
  String get chatNoResponseFromModel =>
      'لا توجد استجابة من النموذج. يرجى المحاولة مرة أخرى.';

  @override
  String get speechJobCancelled => 'تم إلغاء مهمة الكلام.';

  @override
  String get speechEdgeCancelled => 'تم إلغاء Microsoft Edge Speech.';

  @override
  String get sessionAttentionKindActive => 'نشط';

  @override
  String get sessionAttentionKindReceiving => 'استقبال';

  @override
  String get sessionAttentionKindDelayed => 'متأخر';

  @override
  String get sessionAttentionKindCompleted => 'مكتمل';

  @override
  String get sessionAttentionKindPendingInteraction => 'بانتظار التفاعل';

  @override
  String get sessionAttentionKindError => 'خطأ';

  @override
  String get sessionAttentionPauseCellularDataSaver =>
      'موفر البيانات الخلوية نشط';

  @override
  String get sessionAttentionPauseOauthReopenRequired =>
      'مطلوب تسجيل دخول OAuth';

  @override
  String get sessionAttentionPauseTailscaleReopenRequired =>
      'مطلوب اتصال Tailscale';

  @override
  String get sessionAttentionPauseOffline => 'غير متصل';

  @override
  String get sessionAttentionPausePermissionRevoked => 'تم سحب الإذن';

  @override
  String get sessionAttentionPauseServiceStopped => 'توقفت الخدمة';

  @override
  String get sessionAttentionPauseHostUnavailable => 'المضيف غير متاح';

  @override
  String get errorRequestCancelled => 'تم إلغاء الطلب';

  @override
  String errorUnknownNetworkError(String error) {
    return 'خطأ شبكة غير معروف: $error';
  }

  @override
  String get errorCertificateError => 'خطأ في الشهادة';

  @override
  String get errorSessionBusy => 'الجلسة مشغولة بمعالجة طلب آخر.';

  @override
  String get errorRunShellCommandFailed => 'فشل تشغيل أمر شل';

  @override
  String get errorRunSlashCommandFailed => 'فشل تشغيل أمر الشرطة المائلة';

  @override
  String get settingsBehaviorOpenCodeDefaultsLoadError =>
      'تعذر تحميل الإعدادات الافتراضية المدعومة من OpenCode من الخادم النشط.';

  @override
  String get sessionTabIconRemoveFailed =>
      'فشل إزالة بيانات أيقونة تبويب الجلسة المحلية';

  @override
  String get forwardUntitled => 'بدون عنوان';

  @override
  String setupDebugLinuxLogsPath(String path) {
    return 'سجلات Linux: $path';
  }

  @override
  String setupDebugRunOpenCodeCommand(String command) {
    return 'شغّل OpenCode باستخدام: $command';
  }

  @override
  String setupDebugServerHealthEndpoint(String endpoint) {
    return 'صحة الخادم: $endpoint';
  }

  @override
  String setupDebugServerDocsEndpoint(String endpoint) {
    return 'وثائق الخادم: $endpoint';
  }

  @override
  String get logsEntryError => 'خطأ';

  @override
  String get logsEntryStack => 'المكدس';

  @override
  String get setupDebugSourceDiagnostics => 'التشخيصات';

  @override
  String get setupDebugSourceUseExisting => 'استخدام الحالي';

  @override
  String get setupDebugSourceLocalServer => 'خادم محلي';

  @override
  String get setupDebugSourceOnboarding => 'الإعداد الأولي';

  @override
  String get setupDebugSourceManualConnection => 'اتصال يدوي';

  @override
  String setupDebugMessageDiagnosticsResult(
    String availability,
    String platform,
    String recommendation,
  ) {
    return '$availability على $platform. $recommendation';
  }

  @override
  String get setupDebugMessageDetectAttempt =>
      'محاولة اكتشاف أمر OpenCode موجود من البيئة الحالية.';

  @override
  String get setupDebugMessageInstallStarted =>
      'بدأ تثبيت OpenCode من CodeWalk.';

  @override
  String setupDebugMessageStartLocalServer(String url) {
    return 'جارٍ تشغيل خادم OpenCode المُدار على $url.';
  }

  @override
  String setupDebugMessageHealthyRunning(String url) {
    return 'خادم OpenCode المُدار سليم ويعمل على $url.';
  }

  @override
  String get setupDebugMessageStoppingLocalServer =>
      'جارٍ إيقاف خادم OpenCode المُدار.';

  @override
  String get setupDebugMessageStoppedCleanly =>
      'توقف خادم OpenCode المُدار بشكل سليم.';

  @override
  String get setupDebugMessageExitedAfterRequestedStop =>
      'خرج خادم OpenCode المُدار بعد إيقاف مطلوب.';

  @override
  String get setupDebugMessageOnboardingConnectExisting =>
      'اختار المستخدم الاتصال بخادم OpenCode موجود.';

  @override
  String get setupDebugMessageOnboardingGuidedPath =>
      'فتح المستخدم مسار إعداد OpenCode الموجّه.';

  @override
  String get setupDebugMessageOnboardingManagedLocal =>
      'فتح المستخدم إعداد OpenCode المحلي المُدار.';

  @override
  String get setupDebugMessageOnboardingOpenedServerSettings =>
      'فتح المستخدم إعدادات الخادم بعد فشل فحص الحالة.';

  @override
  String get setupDebugMessageOnboardingAddAnotherServer =>
      'اختار المستخدم إضافة خادم آخر بعد فشل فحص الحالة.';

  @override
  String setupDebugMessageTestingServerUrl(String url) {
    return 'اختبار عنوان URL لخادم OpenCode $url من الإعداد الأولي.';
  }

  @override
  String get chatProviderErrorSessionNotFound => 'الجلسة غير موجودة';

  @override
  String get chatProviderErrorInvalidMessageFormat => 'تنسيق رسالة غير صالح';

  @override
  String get chatProviderErrorNetworkShort => 'فشل الاتصال بالشبكة';

  @override
  String get chatProviderErrorUnknownShort => 'خطأ غير معروف';

  @override
  String get terminalCreateFailed => 'فشل إنشاء جلسة الطرفية';

  @override
  String get terminalEndpointUnavailable => 'نقطة نهاية الطرفية غير متاحة';

  @override
  String get terminalInvalidDirectory => 'دليل الطرفية غير صالح';

  @override
  String get terminalWebsocketUnavailable => 'WebSocket الطرفية غير متاح هنا.';

  @override
  String chatMessageToolChainCallsCompact(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count استدعاءات',
      one: 'استدعاء واحد',
    );
    return '$_temp0';
  }

  @override
  String get errorConnectionTimeout => 'انتهت مهلة الاتصال';

  @override
  String get errorClientError => 'خطأ من العميل';

  @override
  String get chatProviderErrorSendMessage => 'فشل إرسال الرسالة';

  @override
  String get speechApiEngine => 'API';

  @override
  String get speechApiEngineSubtitle =>
      'OpenAI أو Groq أو نقطة نهاية مخصصة متوافقة مع OpenAI.';

  @override
  String get speechApiProvider => 'موفر تحويل الكلام إلى نص';

  @override
  String get speechCloudSttPrivacy => 'خصوصية تحويل الكلام إلى نص في السحابة';

  @override
  String get speechCloudSttPrivacyDescription =>
      'يُرسل الصوت المسجل من الميكروفون إلى الموفر المُعد. تبقى مفاتيح API في التخزين الآمن على هذا الجهاز.';

  @override
  String get speechApiKeyOptional => 'اختياري لنقاط النهاية المخصصة.';

  @override
  String speechApiBatchHint(String provider) {
    return 'يستخدم $provider التحويل الدفعي. انقر على الميكروفون مرة أخرى للإيقاف والتحويل.';
  }

  @override
  String get speechApiWebUnavailable =>
      'تحويل الكلام إلى نص عبر API غير متاح في إصدار الويب.';

  @override
  String get speechApiConfigInvalid =>
      'تحقق من نقطة النهاية والنموذج لـ API الكلام. يجب أن تستخدم نقاط النهاية البعيدة HTTPS.';

  @override
  String get speechApiRequestInvalid => 'تم رفض نقطة نهاية الكلام أو النموذج.';

  @override
  String get speechApiRateLimited => 'أبلغ موفر الكلام عن حصة أو حد معدل.';

  @override
  String get speechApiUnavailable => 'موفر الكلام غير متاح مؤقتًا.';

  @override
  String get speechApiNetwork => 'تعذر الوصول إلى موفر الكلام.';

  @override
  String get speechApiInvalidResponse => 'أعاد موفر الكلام استجابة غير صالحة.';

  @override
  String get speechApiEmptyAudio => 'لم يتم التقاط أي صوت من الميكروفون.';

  @override
  String get speechApiEmptyTranscript => 'لم يُرجع موفر الكلام أي نص محول.';

  @override
  String get speechApiCustomProvider => 'مخصص متوافق مع OpenAI';

  @override
  String get speechApiMaxDuration =>
      'يتوقف التسجيل عبر API تلقائيًا بعد دقيقتين.';

  @override
  String get speechApiLanguageHint =>
      'يُرسل لغة التطبيق النشطة كتلميح للتحويل.';

  @override
  String get speechSttApiKeyStorageUnavailable =>
      'التخزين الآمن لمفتاح API الخاص بالكلام غير متاح.';

  @override
  String get speechSttApiKeyMissing =>
      'أضف مفتاح API للكلام في الإعدادات > الكلام.';

  @override
  String get speechSttApiKeyRejected => 'تم رفض مفتاح API الخاص بالكلام.';
}
