// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppLocalizationsUr extends AppLocalizations {
  AppLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String get aboutGitHub => 'گٹ ہب';

  @override
  String get appProviderCannotActivateUnhealthy =>
      'غیر صحت مند سرور کو فعال نہیں کیا جا سکتا';

  @override
  String get appProviderDesktopOnly =>
      'منظم مقامی سرور صرف ڈیسک ٹاپ پر دستیاب ہے۔';

  @override
  String get appProviderDetectingCommand =>
      'OpenCode کمانڈ کا پتہ لگایا جا رہا ہے...';

  @override
  String get appProviderErrorCannotActivateUnhealthy =>
      'غیر صحت مند سرور کو فعال نہیں کیا جا سکتا';

  @override
  String get appProviderErrorCloudflareOAuthNotSupported =>
      'Cloudflare Access OAuth اس پلیٹ فارم پر تعاون یافتہ نہیں ہے';

  @override
  String get appProviderErrorInstallationFailed =>
      'OpenCode کی انسٹالیشن ناکام ہوگئی۔';

  @override
  String get appProviderErrorInvalidServerUrl => 'غلط سرور URL';

  @override
  String get appProviderErrorLocalServerHealthCheckFailed =>
      'مقامی سرور شروع ہوا لیکن ہیلتھ چیک پاس نہیں ہوا۔';

  @override
  String get appProviderErrorManagedDesktopOnly =>
      'منظم مقامی سرور صرف ڈیسک ٹاپ پر دستیاب ہے۔';

  @override
  String get appProviderErrorServerAlreadyExists =>
      'اس URL والا سرور پہلے سے موجود ہے';

  @override
  String get appProviderErrorServerProfileNotFound => 'سرور پروفائل نہیں ملا';

  @override
  String get appProviderErrorServerUrlRequired => 'سرور کا URL درکار ہے';

  @override
  String get appProviderErrorTailscaleNotSupported =>
      'Tailscale اس پلیٹ فارم پر تعاون یافتہ نہیں ہے';

  @override
  String appProviderExitedWithCode(int code) {
    return 'مقامی سرور کوڈ $code کے ساتھ بند ہوا۔';
  }

  @override
  String get appProviderFailedToStart =>
      'مقامی OpenCode سرور شروع کرنے میں ناکام۔';

  @override
  String get appProviderInstallBinary => 'بائنری انسٹال کریں';

  @override
  String get appProviderInstallBunOpenCode => 'Bun + OpenCode انسٹال کریں';

  @override
  String get appProviderInstallSucceeded => 'انسٹالیشن کامیاب رہی۔';

  @override
  String appProviderInstallSucceededWithPath(String path) {
    return 'انسٹالیشن کامیاب رہی۔ OpenCode کمانڈ $path پر دستیاب ہے۔';
  }

  @override
  String get appProviderInstallViaBun => 'Bun کے ذریعے انسٹال کریں';

  @override
  String get appProviderInstallViaNpm => 'npm کے ذریعے انسٹال کریں';

  @override
  String get appProviderInstallationFailed =>
      'OpenCode کی انسٹالیشن ناکام ہوگئی۔';

  @override
  String get appProviderInstalledSuccessfully =>
      'OpenCode کی ضروریات کامیابی سے انسٹال ہو گئیں۔';

  @override
  String get appProviderInstallingRequirements =>
      'OpenCode کی ضروریات انسٹال ہو رہی ہیں...';

  @override
  String get appProviderInvalidServerUrl => 'غلط سرور URL';

  @override
  String get appProviderLabelLocalOpenCodeManaged => 'مقامی OpenCode (منظم)';

  @override
  String get appProviderLabelPrimaryServer => 'بنیادی سرور';

  @override
  String get appProviderLocalManaged => 'مقامی OpenCode (منظم)';

  @override
  String get appProviderLocalServerStopped => 'مقامی سرور روکا ہوا ہے۔';

  @override
  String get appProviderNotDetectedInstall =>
      'OpenCode کمانڈ کا پتہ نہیں چلا۔ وزرڈ سے انسٹالیشن چلائیں۔';

  @override
  String appProviderNotDetectedRefresh(String appName) {
    return 'OpenCode کمانڈ کا پتہ نہیں چلا۔ اگر آپ نے اسے تھوڑی دیر پہلے انسٹال کیا ہے تو، چیکس کو ریفریش کریں یا PATH کو دوبارہ لوڈ کرنے کے لیے $appName کو دوبارہ کھولیں۔';
  }

  @override
  String get appProviderOAuthNotSupported =>
      'Cloudflare Access OAuth اس پلیٹ فارم پر تعاون یافتہ نہیں ہے';

  @override
  String get appProviderOpenCodeDetected => 'OpenCode کا پتہ چل گیا';

  @override
  String get appProviderOpenCodeNotDetected => 'OpenCode کا پتہ نہیں چلا';

  @override
  String get appProviderPrimaryServer => 'بنیادی سرور';

  @override
  String get appProviderProfileNotFound => 'سرور پروفائل نہیں ملا';

  @override
  String get appProviderRunDiagnostics =>
      'مقامی OpenCode ضروریات کی تصدیق کے لیے تشخیص چلائیں۔';

  @override
  String appProviderRunningAt(String url) {
    return '$url پر چل رہا ہے';
  }

  @override
  String get appProviderSetupDetectingOpenCode =>
      'OpenCode کمانڈ کا پتہ لگایا جا رہا ہے...';

  @override
  String get appProviderSetupInstallationSucceeded => 'انسٹالیشن کامیاب رہی۔';

  @override
  String appProviderSetupInstallationSucceededWithPath(String path) {
    return 'انسٹالیشن کامیاب رہی۔ OpenCode کمانڈ $path پر دستیاب ہے۔';
  }

  @override
  String get appProviderSetupInstallingRequirements =>
      'OpenCode کی ضروریات انسٹال ہو رہی ہیں...';

  @override
  String get appProviderSetupOpenCodeDetected => 'OpenCode کا پتہ چل گیا';

  @override
  String get appProviderSetupOpenCodeNotDetected => 'OpenCode کا پتہ نہیں چلا';

  @override
  String get appProviderSetupOpenCodeNotDetectedInstall =>
      'OpenCode کمانڈ کا پتہ نہیں چلا۔ وزرڈ سے انسٹالیشن چلائیں۔';

  @override
  String get appProviderSetupOpenCodeNotDetectedRefresh =>
      'OpenCode کمانڈ کا پتہ نہیں چلا۔ اگر آپ نے اسے تھوڑی دیر پہلے انسٹال کیا ہے تو، چیکس کو ریفریش کریں یا PATH کو دوبارہ لوڈ کرنے کے لیے CodeWalk کو دوبارہ کھولیں۔';

  @override
  String get appProviderSetupRequirementsInstalled =>
      'OpenCode کی ضروریات کامیابی سے انسٹال ہو گئیں۔';

  @override
  String appProviderSetupUsingOpenCodeAt(String path) {
    return '$path پر OpenCode کمانڈ استعمال ہو رہی ہے';
  }

  @override
  String get appProviderStartingLocalServer => 'مقامی سرور شروع ہو رہا ہے...';

  @override
  String appProviderStatusLocalServerExitedWithCode(int code) {
    return 'مقامی سرور کوڈ $code کے ساتھ بند ہوا۔';
  }

  @override
  String get appProviderStatusLocalServerStopped => 'مقامی سرور روکا ہوا ہے۔';

  @override
  String appProviderStatusRunningAt(String url) {
    return '$url پر چل رہا ہے';
  }

  @override
  String get appProviderStatusStartingLocalServer =>
      'مقامی سرور شروع ہو رہا ہے...';

  @override
  String get appProviderStatusStoppingLocalServer =>
      'مقامی سرور روکا جا رہا ہے...';

  @override
  String get appProviderStoppingLocalServer => 'مقامی سرور روکا جا رہا ہے...';

  @override
  String get appProviderTailscaleNotSupported =>
      'Tailscale اس پلیٹ فارم پر تعاون یافتہ نہیں ہے';

  @override
  String appProviderUsingCommandAt(String path) {
    return '$path پر OpenCode کمانڈ استعمال ہو رہی ہے';
  }

  @override
  String get appShellDownloadingUpdate => 'اپ ڈیٹ ڈاؤن لوڈ ہو رہا ہے';

  @override
  String get appShellInstall => 'انسٹال کریں';

  @override
  String get appShellInstallFailed => 'انسٹالیشن ناکام';

  @override
  String get appShellInstallingUpdate => 'اپ ڈیٹ انسٹال ہو رہا ہے...';

  @override
  String get appShellRestart => 'دوبارہ شروع کریں';

  @override
  String appShellUpdateAvailableResult(String latestVersion) {
    return 'اپ ڈیٹ دستیاب: v$latestVersion';
  }

  @override
  String get appShellUpdateInstalledRestartApp =>
      'اپ ڈیٹ انسٹال ہو گئی۔ لاگو کرنے کے لیے ایپ دوبارہ شروع کریں۔';

  @override
  String get appShellUpdateInstalledRestartRequired =>
      'اپ ڈیٹ انسٹال ہو گئی۔ نیا ورژن لاگو کرنے کے لیے دوبارہ شروع کرنا ضروری ہے۔';

  @override
  String get attachmentCouldNotDecode =>
      'منسلک ڈیٹا کو ڈی کوڈ نہیں کیا جا سکا۔';

  @override
  String get attachmentCouldNotDownload => 'منسلکہ ڈاؤن لوڈ نہیں کیا جا سکا۔';

  @override
  String get attachmentCouldNotSave =>
      'اس ڈیوائس پر منسلک فائل محفوظ نہیں کی جا سکی۔';

  @override
  String get attachmentDownloadStarted => 'منسلکہ ڈاؤن لوڈ شروع ہو گیا۔';

  @override
  String get attachmentLocalNotFound =>
      'اس ڈیوائس پر مقامی منسلک فائل نہیں ملی۔';

  @override
  String get attachmentNoValidLocation =>
      'منسلکہ کوئی درست مقام فراہم نہیں کرتا۔';

  @override
  String get attachmentNotAvailableOnPlatform =>
      'اس پلیٹ فارم پر منسلک فائل کے اقدامات دستیاب نہیں ہیں۔';

  @override
  String get attachmentPathEmpty => 'منسلکہ کا راستہ خالی ہے۔';

  @override
  String get attachmentPayloadEmpty => 'منسلکہ کا پے لوڈ خالی ہے۔';

  @override
  String get attachmentSaveCanceled => 'محفوظ کرنا منسوخ کر دیا گیا۔';

  @override
  String attachmentSavedAndOpened(String path) {
    return 'منسلکہ $path میں محفوظ اور کھول دیا گیا۔';
  }

  @override
  String attachmentSavedPath(String path) {
    return 'منسلکہ $path میں محفوظ کر دیا گیا۔';
  }

  @override
  String attachmentSavedTo(String path) {
    return 'منسلکہ $path میں محفوظ کر دیا گیا۔';
  }

  @override
  String get attachmentUnableToOpenLink => 'منسلکہ لنک کھولنے میں ناکام۔';

  @override
  String get attachmentUnableToOpenLocal =>
      'مقامی منسلک فائل کھولنے میں ناکام۔';

  @override
  String get behaviorAdvancedPermissionRule => 'اعلی درجے کی اجازت کا قاعدہ';

  @override
  String get behaviorAutomatic => 'خودکار';

  @override
  String get behaviorAutomaticFallback => 'خودکار فال بیک';

  @override
  String get behaviorCellularDataSaver => 'موبائل ڈیٹا سیور';

  @override
  String get behaviorCellularDataSaverActive => 'سیلولر ڈیٹا سیور فعال ہے۔';

  @override
  String get behaviorChatLevelShare => 'چیٹ لیول شیئرنگ';

  @override
  String get behaviorCodeWalkReleaseChecks => 'CodeWalk ریلیز چیکس';

  @override
  String get behaviorControlsOfficialGlobal =>
      'OpenCode کی آفیشل گلوبل سیٹنگز کنٹرول کرتا ہے';

  @override
  String get behaviorControlsUpstreamOpenCode =>
      'اپ اسٹریم OpenCode سیٹنگز کنٹرول کرتا ہے';

  @override
  String get behaviorCustomDisplayName => 'حسب ضرورت ڈسپلے نام';

  @override
  String behaviorCutsAutomaticMobile(int inSeconds) {
    return 'بیک گراؤنڈ ڈاؤن لوڈز روک کر اور پیش منظر کے خودکار تازہ کاریوں کو ہر $inSeconds سیکنڈ پر ایک رسے تک محدود کر کے خودکار موبائل ڈیٹا استعمال کو کم کرتا ہے۔';
  }

  @override
  String get behaviorDataSaverActive => 'اب موبائل ڈیٹا پر فعال ہے۔';

  @override
  String get behaviorDataSaverAggressive => 'Aggressive';

  @override
  String get behaviorDataSaverAggressiveDescription =>
      'Low-bandwidth mode: only the visible workspace stream stays live, global updates are paused, and automatic refreshes are stretched.';

  @override
  String get behaviorDataSaverCellularOnly =>
      'صرف اس وقت لاگو ہوتا ہے جب کنکشن سیلولر/موبائل ہو۔';

  @override
  String get behaviorDataSaverOff => 'Off';

  @override
  String get behaviorDataSaverOffHint =>
      'Full realtime and automatic refreshes are enabled.';

  @override
  String get behaviorDataSaverStandard => 'Standard';

  @override
  String get behaviorDataSaverWaiting =>
      'اگلی موبائل ڈیٹا سنک ونڈو کا انتظار ہے۔';

  @override
  String get behaviorDisabled => 'غیر فعال';

  @override
  String get behaviorLightweightTasksLike => 'ہلکے کام جیسے';

  @override
  String get behaviorManual => 'دستی';

  @override
  String get behaviorNotify => 'اطلاع دیں';

  @override
  String get behaviorOfficialOpenCodePermission =>
      'آفیشل اوپن کوڈ کی اجازت کی پالیسی کو `opencode.json` میں اجازت/پوچھیں/منکر کے اصولوں کے ساتھ ترتیب دیا گیا ہے۔ CodeWalk سرکاری اجازت کی درخواست کے کارڈز کو رکھتا ہے اور ایک منظور شدہ ADR-023 استثناء شامل کرتا ہے: کمپوزر آٹو-منظوری ٹوگل جوابات کو \'ہمیشہ\' اور \'یاد رکھیں: سچ\' کے ساتھ غیر مشروط طور پر پائیدار سیشن کے دائرہ کار والے گرانٹس کو تخلیق کرتا ہے، اور بیک گراؤنڈ ورک کے اسی تھریڈ اسکوپڈ کنٹیوٹی پاتھ کو فعال رکھتا ہے۔';

  @override
  String get behaviorOpenCodeBackedDefaults =>
      'اوپن کوڈ کی حمایت یافتہ ڈیفالٹس';

  @override
  String get behaviorPermissionHandlingProvenance => 'اجازت ہینڈلنگ پروونانس';

  @override
  String get behaviorPermissionsVariantReasoning =>
      'اجازتیں اور ویرینٹ/ریزننگ برابری اس وقت تک الگ رہتی ہیں جب تک کہ ان کا UI اعلی درجے کی تشکیل کو محفوظ طریقے سے محفوظ نہ کر سکے۔';

  @override
  String get behaviorPrimaryAgentAgent =>
      'پرائمری ایجنٹ استعمال کیا جاتا ہے جب کوئی ایجنٹ واضح طور پر منتخب نہیں کیا جاتا ہے۔';

  @override
  String get behaviorRefreshDefaults => 'ڈیفالٹس ریفریش کریں۔';

  @override
  String get behaviorSharedAcrossOpenCode =>
      'تشکیل کے ذریعے اوپن کوڈ کلائنٹس میں اشتراک کیا گیا۔';

  @override
  String get behaviorTheseValuesWrite =>
      'یہ قدریں فعال سرور پر `/config` پر لکھتی ہیں اور آفیشل اوپن کوڈ کی مشترکہ تشکیل سے ملتی ہیں۔';

  @override
  String get cannedAddTitle => 'فوری جواب شامل کریں';

  @override
  String get cannedAppendAtCursor => 'کرسر پر شامل کریں';

  @override
  String get cannedAppendAtCursorSubtitle =>
      'بند = موجودہ کمپوزر متن تبدیل کریں';

  @override
  String get cannedAttachFiles => 'فائلیں منسلک کریں۔';

  @override
  String get cannedEditTitle => 'فوری جواب میں ترمیم کریں';

  @override
  String get cannedNewQuickReply => 'نیا فوری جواب';

  @override
  String get cannedNoSuggestions => 'کوئی تجویز نہیں۔';

  @override
  String get cannedOffMeansReplace =>
      'آف کا مطلب موجودہ کمپوزر ٹیکسٹ کو تبدیل کرنا ہے۔';

  @override
  String get cannedQuickReply => 'نیا فوری جواب';

  @override
  String get cannedReplace => 'تبدیل کریں';

  @override
  String get cannedScopeGlobalSubtitle =>
      'صرف پروجیکٹ آئٹم کے لیے غیر فعال کریں';

  @override
  String get cannedScopeGlobalUnavailableSubtitle =>
      'موجودہ سیاق میں صرف پروجیکٹ دستیاب نہیں';

  @override
  String get cannedSendAutomaticallySubtitle =>
      'فوری جواب ڈالنے کے فوراً بعد بھیجیں';

  @override
  String get cannedSendImmediatelyInserting =>
      'یہ فوری جواب داخل کرنے کے فوراً بعد بھیجیں۔';

  @override
  String get cannedTextLabel => 'متن';

  @override
  String get chatActionNext => 'اگلا';

  @override
  String get chatActiveServerUnhealthy =>
      'فعال سرور غیر صحت بخش ہے۔ بھیجیں ایک بار کوشش کریں گے اور بازیابی تک تیزی سے ناکام ہوجائیں گے۔';

  @override
  String get chatActiveServerUnhealthyLabel => 'فعال سرور غیر صحت مند ہے';

  @override
  String get chatAddServerToStart =>
      'چیٹنگ شروع کرنے کے لیے ایک سرور شامل کریں۔';

  @override
  String get chatAppBarMoreActions => 'مزید کارروائیاں';

  @override
  String get chatAppBarPinAction => 'ایپ بار پر پن کریں۔';

  @override
  String get chatAppBarPinDescription => 'یہ عمل مینو سے باہر نظر آئے گا۔';

  @override
  String get chatAppBarUnpinAction => 'ایپ بار سے پن ہٹا دیں۔';

  @override
  String get chatAppBarUnpinDescription => 'یہ عمل مینو میں واپس چلا جائے گا۔';

  @override
  String chatBadgeConversationError(String title) {
    return '\"$title\" میں ایک خرابی ہے۔';
  }

  @override
  String chatBadgeConversationNeedsInput(String title) {
    return '\"$title\" کو آپ کے ان پٹ کی ضرورت ہے۔';
  }

  @override
  String chatBadgeConversationNewReply(String title) {
    return '\"$title\" کا ایک نیا جواب آیا ہے۔';
  }

  @override
  String get chatBadgeDataSaverActive => 'سیلولر ڈیٹا سیور فعال ہے۔';

  @override
  String get chatBadgeServerNeedsAttention => 'سرور کنکشن پر توجہ کی ضرورت ہے۔';

  @override
  String get chatBadgeSyncing => 'گفتگو کی مطابقت پذیری ہو رہی ہے...';

  @override
  String get chatBlockResponsePendingDescription =>
      'The answer will appear as a single block when this turn finishes.';

  @override
  String get chatBlockResponsePendingTitle => 'Generating response';

  @override
  String get chatCachedConversationsYet =>
      'ابھی تک کوئی کیش شدہ گفتگو نہیں ہے۔';

  @override
  String get chatChangedFilesAvailable =>
      'اس سیشن کے لیے کوئی تبدیل شدہ فائل دستیاب نہیں ہے۔';

  @override
  String chatChildrenChatProviderCurrentSessionChildren(int length) {
    return 'بچے: $length';
  }

  @override
  String get chatChooseAgent => 'ایجنٹ منتخب کریں';

  @override
  String get chatChooseDirectory => 'ڈائرکٹری کا انتخاب کریں۔';

  @override
  String get chatChooseEffort => 'کوشش منتخب کریں';

  @override
  String get chatChooseFolderOpen =>
      'پروجیکٹ سیاق و سباق کے طور پر کھولنے کے لیے فولڈر کا انتخاب کریں۔';

  @override
  String get chatChooseModel => 'ماڈل منتخب کریں';

  @override
  String get chatClose => 'بند';

  @override
  String chatCloseProject(String project) {
    return '$project بند کریں';
  }

  @override
  String get chatCollapseGroup => 'گروپ کو سکیڑیں';

  @override
  String get chatCommandDescriptionProject => 'پروجیکٹ کمانڈ';

  @override
  String get chatCommandSourceGeneric => 'کمانڈ';

  @override
  String get chatCommandSourceProject => 'پروجیکٹ';

  @override
  String get chatCompactContext => 'کومپیکٹ سیاق و سباق';

  @override
  String get chatComposerHintShell => 'شیل کمانڈ (باہر نکلنے کے لیے Esc)';

  @override
  String get chatComposerPlaceholder => 'اپنی ضروریات ٹائپ کریں...';

  @override
  String get chatConversation => 'بات چیت';

  @override
  String get chatConversations => 'بات چیت';

  @override
  String get chatConversationsPane => 'بات چیت';

  @override
  String chatCostLabel(double cost) {
    return 'لاگت: \$$cost';
  }

  @override
  String get chatCouldNotRefreshSession => 'یہ گفتگو تازہ نہیں کی جا سکی';

  @override
  String get chatCurrent => 'موجودہ استعمال کریں۔';

  @override
  String chatDescriptionChildren(int count) {
    return 'ذیلی عناصر: $count';
  }

  @override
  String get chatDescriptionCloseApp =>
      'پلیٹ فارم کے بند کرنے کے رویے کا استعمال کرتے ہوئے ایپ بند کریں';

  @override
  String get chatDescriptionCycleModels => 'حالیہ ماڈلز کو تبدیل کریں';

  @override
  String get chatDescriptionCycleVariant => 'ماڈل کی قسم کو تبدیل کریں';

  @override
  String get chatDescriptionDiffFilesZero => 'ڈیف فائلیں: 0';

  @override
  String get chatDescriptionFocusInput => 'پیغام کے ان پٹ پر توجہ مرکوز کریں';

  @override
  String get chatDescriptionFocusOrCloseDrawer =>
      'ان پٹ پر توجہ مرکوز کریں (یا دراز کھلا ہونے پر بند کریں)';

  @override
  String get chatDescriptionForceExit => 'ایپ سے زبردستی باہر نکلیں';

  @override
  String get chatDescriptionNewConversation => 'نئی گفتگو';

  @override
  String get chatDescriptionNextAgent => 'اگلا ایجنٹ';

  @override
  String get chatDescriptionOpenProjects =>
      'اپنے پروجیکٹس اور گفتگو کو کھولنے کے لیے یہ بٹن استعمال کریں۔';

  @override
  String get chatDescriptionOpenSettings => 'ترتیبات کھولیں';

  @override
  String get chatDescriptionPreviousAgent => 'پچھلا ایجنٹ';

  @override
  String get chatDescriptionProjectCommand => 'پروجیکٹ کمانڈ';

  @override
  String get chatDescriptionQuickOpen => 'فائلیں جلدی کھولیں';

  @override
  String get chatDescriptionRefreshData => 'چیٹ ڈیٹا کو ریفریش کریں';

  @override
  String get chatDescriptionStopResponse =>
      'فعال جواب کو روکیں (جواب دیتے وقت)';

  @override
  String get chatDescriptionSwitchProject =>
      'پروجیکٹ فولڈرز اور سیاق و سباق کو تبدیل کرنے کے لیے یہ بٹن استعمال کریں۔';

  @override
  String get chatDescriptionVoiceInput => 'صوتی ان پٹ شروع کریں یا روکیں';

  @override
  String get chatDiffFiles => 'مختلف فائلیں: 0';

  @override
  String get chatDisplay => 'ڈسپلے';

  @override
  String get chatDisplayToggles => 'ڈسپلے ٹوگلز';

  @override
  String get chatDoubleESCStop => 'رکنے کے لیے دو بار ESC';

  @override
  String get chatEffortLockedSubConversation => 'ذیلی گفتگو میں کوشش مقفل ہے';

  @override
  String get chatExpandGroup => 'گروپ کو پھیلائیں';

  @override
  String get chatExportCanceled => 'سیشن ایکسپورٹ منسوخ کر دیا گیا';

  @override
  String get chatFailedToLoadDirectories => 'ڈائریکٹریز لوڈ کرنے میں ناکام';

  @override
  String get chatFailedToLoadFile => 'فائل لوڈ کرنے میں ناکام';

  @override
  String get chatFailedToRefreshProviders =>
      'فراہم کنندگان اور ماڈلز تازہ کرنے میں ناکامی';

  @override
  String get chatFailedToRefreshSubConversations =>
      'ذیلی گفتگو تازہ کرنے میں ناکامی۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get chatFailedToStopResponse => 'موجودہ جواب کو روکنے میں ناکام';

  @override
  String get chatFileExplorerContents => 'مشمولات';

  @override
  String get chatFileExplorerNames => 'نام';

  @override
  String get chatFilterActive => 'فعال';

  @override
  String get chatFilterAll => 'تمام';

  @override
  String get chatFilterArchived => 'محفوظ شدہ';

  @override
  String get chatFilterDirectories => 'ڈائریکٹریز کو فلٹر کریں۔';

  @override
  String get chatFilterSessions => 'فلٹر سیشنز';

  @override
  String get chatForkFailed => 'گفتگو کو فورک کرنے میں ناکام';

  @override
  String get chatForked => 'گفتگو فورک کر دی گئی';

  @override
  String get chatGoToFirst => 'پہلے پیغام پر جائیں۔';

  @override
  String get chatGoToLatest => 'تازہ ترین پیغام پر جائیں۔';

  @override
  String chatGroupMessageCountMessages(
    String compactionLabel,
    String messageCount,
  ) {
    return '$compactionLabel کمپیکشن سے پہلے $messageCount پیغامات چھپائے گئے';
  }

  @override
  String get chatHelloAssistant => 'ہیلو! میں آپ کا AI اسسٹنٹ ہوں۔';

  @override
  String get chatHelp => 'میں آپ کی مدد کیسے کر سکتا ہوں؟';

  @override
  String get chatHelpMessage =>
      'ذکر کے لیے @، شیل کے لیے !، کمانڈز کے لیے / استعمال کریں';

  @override
  String get chatHideConversationsSidebar => 'گفتگو کا سائڈبار چھپائیں۔';

  @override
  String get chatHideUtilitySidebar => 'یوٹیلیٹی سائڈبار چھپائیں۔';

  @override
  String get chatHistoryCollapsed => 'پچھلی تاریخ کو منہدم کر دیا گیا ہے۔';

  @override
  String get chatHistoryHideEarlier => 'پہلے کے پیغامات چھپائیں۔';

  @override
  String chatHistoryMessagesHidden(int count, String label) {
    return '$count پیغامات $label کمپیکشن سے پہلے چھپے ہوئے ہیں۔';
  }

  @override
  String get chatHistoryShowEarlier => 'پہلے کے پیغامات دکھائیں۔';

  @override
  String get chatKeepWorking => 'کام کرتے رہیں';

  @override
  String get chatLargeContentSkipped =>
      'استحکام کے لیے بڑے یا ناقص مواد کو چھوڑ دیا گیا۔';

  @override
  String get chatLatestToolActivity =>
      'چیٹ ویو پورٹ کو مستحکم رکھنے کے لیے ٹول کی تازہ ترین سرگرمی اس باؤنڈڈ پینل کے اندر رہتی ہے۔';

  @override
  String get chatLoadMore => 'مزید لوڈ کریں۔';

  @override
  String get chatLoadingProjectContext =>
      'پروجیکٹ کا سیاق و سباق لوڈ ہو رہا ہے...';

  @override
  String get chatMainConversationUnavailable =>
      'مرکزی گفتگو ابھی دستیاب نہیں ہے۔';

  @override
  String get chatParentConversationUnavailable =>
      'والد گفتگو ابھی دستیاب نہیں ہے۔';

  @override
  String get chatMentionAgentSubtitle => 'ایجنٹ';

  @override
  String get chatMentionFileSubtitle => 'فائل';

  @override
  String get chatMentionSymbolSubtitle => 'علامت';

  @override
  String get chatMessageAttachedFile => 'منسلک فائل';

  @override
  String get chatMessageDetails => 'تفصیلات';

  @override
  String get chatMessageHide => 'چھپائیں';

  @override
  String get chatMessageLess => 'کم';

  @override
  String get chatMessageMessagePartUnavailable =>
      'پیغام کا حصہ دستیاب نہیں ہے۔';

  @override
  String get chatMessageMetadataAvailable => 'کوئی میٹا ڈیٹا دستیاب نہیں ہے۔';

  @override
  String chatMessageModelMessageModelId(String modelId) {
    return 'ماڈل: $modelId';
  }

  @override
  String get chatMessageMore => 'مزید';

  @override
  String get chatMessageOpenFile => 'فائل کھولیں۔';

  @override
  String chatMessageProviderMessageProviderId(String providerId) {
    return 'فراہم کنندہ: $providerId';
  }

  @override
  String get chatMessageRewindEdit => 'ریوائنڈ اور یہاں سے ترمیم کریں۔';

  @override
  String get chatMessageRunningTask => 'رننگ ٹاسک';

  @override
  String get chatMessageSaveFile => 'فائل محفوظ کریں۔';

  @override
  String get chatMessageShow => 'دکھائیں';

  @override
  String get chatMessageShowLess => 'کم دکھائیں';

  @override
  String get chatMessageShowLessCompact => 'کم';

  @override
  String get chatMessageShowMore => 'مزید دکھائیں';

  @override
  String get chatMessageShowMoreCompact => 'مزید';

  @override
  String get chatMessageThinking => 'سوچ رہا ہے';

  @override
  String get chatMessageThinkingProcess => 'سوچنے کا عمل';

  @override
  String get chatMessageToolCall => '1 ٹول کال';

  @override
  String chatMessageToolCalls(int count) {
    return '$count ٹول کالز';
  }

  @override
  String get chatMessageToolCommand => 'کمانڈ';

  @override
  String get chatMessageToolCommandTruncated =>
      'کمانڈ کا پیش نظارہ استحکام کے لیے مختصر کیا گیا۔';

  @override
  String get chatMessageToolDiffOmitted =>
      'Diff پیش نظارہ خارج کر دیا گیا: ترمیم کا پے لوڈ موبائل پر محفوظ طریقے سے دکھانے کے لیے بہت بڑا ہے۔';

  @override
  String get chatMessageToolInput => 'ان پٹ';

  @override
  String get chatMessageToolInputTruncated =>
      'ان پٹ کا پیش نظارہ استحکام کے لیے مختصر کیا گیا۔';

  @override
  String get chatMessageToolOutputTruncated =>
      'بڑے آؤٹ پٹ کا پیش نظارہ استحکام کے لیے مختصر کیا گیا۔';

  @override
  String chatMessageToolQueuedCount(int count) {
    return '$count قطار میں ہیں';
  }

  @override
  String chatMessageToolRunningCount(int count) {
    return '$count چل رہے ہیں';
  }

  @override
  String get chatMessageToolStatusInProgress => 'جاری ہے۔';

  @override
  String get chatMessageToolStatusNeedsAttention => 'توجہ کی ضرورت ہے۔';

  @override
  String get chatMessageToolStatusQueued => 'قطار میں لگ گیا۔';

  @override
  String get chatMessageYou => 'آپ';

  @override
  String get chatModelLockedSubConversation => 'ذیلی گفتگو میں ماڈل مقفل ہے';

  @override
  String get chatNewChat => 'نئی چیٹ';

  @override
  String get chatNewChatTourDescription => 'یہاں ایک نئی گفتگو شروع کریں۔';

  @override
  String get chatNewChatTourTitle => 'نئی چیٹ';

  @override
  String get chatNoConversationsInProject =>
      'اس پروجیکٹ میں کوئی گفتگو نہیں ہے۔';

  @override
  String get chatNoServerYet => 'ابھی تک کوئی سرور کنفیگر نہیں ہوا۔';

  @override
  String get chatNoSessionSelected =>
      'چیٹ شروع کرنے کے لیے گفتگو منتخب یا بنائیں';

  @override
  String get chatNoSubConversationFound =>
      'اس کام کے لیے کوئی ذیلی گفتگو نہیں ملی۔';

  @override
  String get chatOpenFiles => 'فائلیں کھولیں۔';

  @override
  String get chatOpenProject => 'پروجیکٹ کھولیں';

  @override
  String get chatOpenProjectFolder => 'پروجیکٹ فولڈر کھولیں...';

  @override
  String get chatOpenProjectToLoad => 'گفتگو لوڈ کرنے کے لیے پروجیکٹ کھولیں۔';

  @override
  String get chatOpenSidebar => 'سائیڈ بار کھولیں';

  @override
  String get chatPageStatusAutomaticCompactionExplanation =>
      'سیاق و سباق کا استعمال بڑھنے کے ساتھ ہی خودکار کمپیکشن ہوتا ہے۔';

  @override
  String get chatPageStatusCompactNow => 'اب کمپیکٹ';

  @override
  String get chatPageStatusCompacting => 'کمپیکٹ ہو رہا ہے...';

  @override
  String get chatPageStatusCompactingContextNow =>
      'سیاق و سباق کو اب کمپیکٹ کر رہا ہے...';

  @override
  String get chatPageStatusContextCompacted => 'سیاق و سباق کو کمپیکٹ کیا گیا۔';

  @override
  String get chatPageStatusContextUsage => 'سیاق استعمال';

  @override
  String get chatPageStatusCost => 'لاگت';

  @override
  String get chatPageStatusFailedToCompactContext =>
      'سیاق و سباق کو کمپیکٹ کرنے میں ناکام';

  @override
  String get chatPageStatusLimit => 'حد';

  @override
  String get chatPageStatusManageServers => 'سرورز کا نظم کریں';

  @override
  String get chatPageStatusSaver => 'سیور';

  @override
  String get chatPageStatusServer => 'سرور';

  @override
  String get chatPageStatusSwitchServer => 'سرور تبدیل کریں';

  @override
  String get chatPageStatusTokens => 'ٹوکنز';

  @override
  String get chatPageStatusUsage => 'استعمال';

  @override
  String chatPageStatusUsagePercent(int usagePercent) {
    return '$usagePercent';
  }

  @override
  String get chatPermissionAutoApproveOff => 'اجازت خودکار منظوری آف ہے';

  @override
  String get chatPermissionAutoApproveOn => 'اجازت خودکار منظوری آن ہے';

  @override
  String get chatProjectContext => 'پروجیکٹ کا سیاق و سباق';

  @override
  String get chatProjectContext2 => 'پروجیکٹ سیاق';

  @override
  String get chatRealtimeGlobalEvent => 'عالمی واقعہ';

  @override
  String chatRealtimeGlobalEventReason(String reason) {
    return 'عالمی واقعہ ($reason)';
  }

  @override
  String get chatRealtimeGlobalEventStale => 'عالمی واقعہ (پرانی نسل)';

  @override
  String chatRealtimeMessageStreamReason(String reason) {
    return 'پیغام کا بہاؤ ($reason)';
  }

  @override
  String get chatRealtimeRealtimeEvent => 'ریئل ٹائم واقعہ';

  @override
  String chatRealtimeRealtimeEventReason(String reason) {
    return 'ریئل ٹائم واقعہ ($reason)';
  }

  @override
  String get chatRealtimeRealtimeEventStale => 'ریئل ٹائم واقعہ (پرانی نسل)';

  @override
  String get chatRealtimeReconnectingServerTry =>
      'سرور سے دوبارہ کنیکٹ ہو رہا ہے۔ ایک لمحے بعد دوبارہ کوشش کریں۔';

  @override
  String get chatReasoning => 'استدلال...';

  @override
  String get chatRecentSessions => 'حالیہ سیشنز';

  @override
  String get chatRecentSessionsToggle => 'حالیہ سیشنز';

  @override
  String get chatRedoLastTurn => 'آخری کالعدم موڑ کو دوبارہ کریں۔';

  @override
  String get chatRedoNothing => 'اس سیشن میں دوبارہ کرنے کے لیے کچھ نہیں ہے';

  @override
  String get chatRefresh => 'ریفریش کریں۔';

  @override
  String get chatRefreshConversation => 'اس گفتگو کو ریفریش نہیں کیا جا سکا';

  @override
  String get chatRefreshProjects => 'پروجیکٹس کو ریفریش کریں۔';

  @override
  String get chatRefreshSessionDetails => 'سیشن کی تفصیلات تازہ کریں۔';

  @override
  String chatRemoveDisplayNameHistory(String displayName) {
    return 'تاریخ سے $displayName ہٹائیں';
  }

  @override
  String get chatRetry => 'دوبارہ کوشش کریں۔';

  @override
  String get chatRetry2 => 'دوبارہ کوشش کریں۔';

  @override
  String get chatRetryRefresh => 'دوبارہ ریفریش کرنے کی کوشش کریں۔';

  @override
  String get chatRetryingModelRequest =>
      'ماڈل کی درخواست کی دوبارہ کوشش کی جا رہی ہے...';

  @override
  String get chatReturnToMainConversation => 'مرکزی گفتگو پر واپس جائیں۔';

  @override
  String get chatReturnToParentConversation => 'والد گفتگو پر واپس جائیں۔';

  @override
  String get chatReviewChanges => 'تبدیلیوں کا جائزہ لیں۔';

  @override
  String get chatSearchConversations => 'مکالمات تلاش کریں۔';

  @override
  String get chatSearchNextResult => 'اگلا نتیجہ';

  @override
  String get chatSearchNoResults => 'کوئی نتیجہ نہیں۔';

  @override
  String get chatSearchPreviousResult => 'پچھلا نتیجہ';

  @override
  String chatSearchResultCount(int current, int total) {
    return 'پیغام $current از $total';
  }

  @override
  String get chatSearchTimeline => 'ٹائم لائن تلاش کریں۔';

  @override
  String get chatSelectDirectory => 'ڈائریکٹری منتخب کریں۔';

  @override
  String get chatSelectOrCreate =>
      'چیٹنگ شروع کرنے کے لیے ایک گفتگو کو منتخب کریں یا تخلیق کریں۔';

  @override
  String get chatSelectProjectBelow => 'ذیل میں ایک پروجیکٹ منتخب کریں۔';

  @override
  String get chatServerSelectedModel => 'سرور کے ذریعے منتخب کردہ ماڈل';

  @override
  String get chatSessionActions => 'سیشن کے اعمال';

  @override
  String chatSessionChatSessionSession(String title) {
    return 'چیٹ سیشن: $title';
  }

  @override
  String chatSessionConversationNextAction(String nextAction) {
    return 'گفتگو $nextAction';
  }

  @override
  String get chatSessionConversations => 'کوئی بات چیت نہیں۔';

  @override
  String get chatSessionCreateConversationStart =>
      'چیٹنگ شروع کرنے کے لیے ایک نئی گفتگو بنائیں';

  @override
  String get chatSessionTabsToggle => 'سیشن ٹیبز';

  @override
  String chatSessionsLength(int length) {
    return '$length';
  }

  @override
  String get chatSetUpServer => 'سرور مرتب کریں۔';

  @override
  String get chatSettings => 'ترتیبات';

  @override
  String get chatShortcutsCloseApp =>
      'پلیٹ فارم کا رویہ استعمال کرتے ہوئے ایپ بند کریں';

  @override
  String get chatShortcutsCycleModels => 'حالیہ ماڈلز تبدیل کریں';

  @override
  String get chatShortcutsCycleVariant => 'ماڈل کی قسم تبدیل کریں';

  @override
  String get chatShortcutsFocusInput => 'پیغام ان پٹ پر فوکس کریں';

  @override
  String get chatShortcutsFocusInputCloseDrawer =>
      'ان پٹ پر فوکس کریں (یا کھلا ہونے پر دراز بند کریں)';

  @override
  String get chatShortcutsForceExit => 'ایپ سے زبردستی باہر نکلیں';

  @override
  String get chatShortcutsNewConversation => 'نئی گفتگو';

  @override
  String get chatShortcutsNextAgent => 'اگلا ایجنٹ';

  @override
  String get chatShortcutsOpenSettings => 'ترتیبات کھولیں';

  @override
  String get chatShortcutsPreviousAgent => 'پچھلا ایجنٹ';

  @override
  String get chatShortcutsQuickOpen => 'فائلیں جلدی کھولیں';

  @override
  String get chatShortcutsRefreshChat => 'چیٹ ڈیٹا ریفریش کریں';

  @override
  String get chatShortcutsStartStopVoice => 'وائس ان پٹ شروع یا بند کریں';

  @override
  String get chatShortcutsStopResponse => 'فعال جواب روکیں (جواب دیتے وقت)';

  @override
  String get chatSidebarAccess => 'سائیڈ بار رسائی';

  @override
  String get chatSortMostRecent => 'تازہ ترین';

  @override
  String get chatSortOldest => 'قدیم ترین';

  @override
  String get chatSortRecent => 'حالیہ';

  @override
  String get chatSortSessions => 'سیشن ترتیب دیں۔';

  @override
  String get chatSortTitle => 'عنوان';

  @override
  String get chatStartVoiceInput => 'صوتی ان پٹ شروع کریں';

  @override
  String get chatStartingVoiceInput => 'صوتی ان پٹ شروع ہو رہا ہے';

  @override
  String get chatStatusBusy => 'حالت: مصروف';

  @override
  String get chatStatusPatching => 'پیچنگ ہو رہی ہے';

  @override
  String chatStatusPatchingMultipleFiles(int count) {
    return '$count فائلیں پیچ ہو رہی ہیں';
  }

  @override
  String get chatStatusPatchingOneFile => '1 فائل پیچ ہو رہی ہے';

  @override
  String get chatStatusRetry => 'حالت: دوبارہ کوشش';

  @override
  String chatStatusRetryCount(int count) {
    return 'حالت: دوبارہ کوشش #$count';
  }

  @override
  String get chatStatusSubsession => 'سب سیشن';

  @override
  String get chatStatusThinking => 'سوچ رہا ہے...';

  @override
  String get chatStopVoiceInput => 'صوتی ان پٹ روکیں';

  @override
  String chatSyncLabel(String label) {
    return 'مطابقت: $label';
  }

  @override
  String get chatTasks => 'کام';

  @override
  String get chatTasksAvailableSession =>
      'اس سیشن کے لیے کوئی کام دستیاب نہیں ہیں۔';

  @override
  String get chatTipAcceptanceCriteria =>
      'مشورہ: بڑی تبدیلیوں کے لیے قبولیت کے معیار شامل کریں';

  @override
  String get chatTipAskForPlan => 'مشورہ: بڑے کاموں میں پہلے منصوبہ مانگیں';

  @override
  String get chatTipBeSpecific =>
      'مشورہ: مخصوص بنیں — چھوٹے پرامپٹ کا جواب تیزی سے ملتا ہے';

  @override
  String get chatTipBreakTasks =>
      'مشورہ: بڑے کاموں کو چھوٹے پرامپٹ میں تقسیم کریں';

  @override
  String get chatTipCompareOptions =>
      'مشورہ: ٹریڈ آف واضح نہ ہوں تو متبادل مانگیں';

  @override
  String get chatTipContextKnob =>
      'مشورہ: استعمال کی تفصیلات دیکھنے کے لیے سیاق و سباق کے نوب پر ٹیپ کریں';

  @override
  String get chatTipDefineVerification =>
      'مشورہ: بتائیں کون سے ٹیسٹ یا چیکس پاس ہونے چاہئیں';

  @override
  String get chatTipLongPressSend =>
      'مشورہ: نئی لائن ڈالنے کے لیے سینڈ کو دیر تک دبائیں';

  @override
  String get chatTipMentionFiles =>
      'مشورہ: اپنے پرامپٹ میں فائلوں کا ذکر کرنے کے لیے @ استعمال کریں';

  @override
  String get chatTipNameRelevantFiles =>
      'مشورہ: متعلقہ فائلیں، اسکرینیں یا کمانڈز بتائیں';

  @override
  String get chatTipProvideContext =>
      'مشورہ: سیاق و سباق فراہم کریں — غلطی کے پیغامات اور لاگز پیسٹ کریں';

  @override
  String get chatTipRenameConversation =>
      'مشورہ: گفتگو کا نام بدلنے کے لیے عنوان پر ٹیپ کریں';

  @override
  String get chatTipRequestDocs => 'مشورہ: رویہ بدلے تو docs اپ ڈیٹ مانگیں';

  @override
  String get chatTipShareAttempts =>
      'مشورہ: جو آزمایا اور درست خرابی شیئر کریں';

  @override
  String get chatTipShellCommands =>
      'مشورہ: شیل کمانڈز چلانے کے لیے شروع میں ! استعمال کریں';

  @override
  String get chatTipSlashCommands =>
      'مشورہ: سلیش کمانڈز تک رسائی کے لیے / استعمال کریں';

  @override
  String get chatTipStartWithGoal => 'مشورہ: آخری مقصد سے شروع کریں';

  @override
  String get chatTipStateConstraints =>
      'مشورہ: وہ پابندیاں بتائیں جو ایجنٹ کو برقرار رکھنی ہیں';

  @override
  String get chatTipStepByStep =>
      'مشورہ: پیچیدہ مسائل کو ڈیبگ کرتے وقت مرحلہ وار پوچھیں';

  @override
  String get chatTipUseFocusedAgents =>
      'مشورہ: پلان، ریویو یا بلڈ کے لیے مرکوز ایجنٹ چنیں';

  @override
  String get chatToggleSidebars => 'سائڈبارز کو ٹوگل کریں۔';

  @override
  String chatTokensLabel(int total) {
    return 'ٹوکنز: $total';
  }

  @override
  String get chatTourProjectsConversations =>
      'اپنے پروجیکٹس اور گفتگو کو کھولنے کے لیے اس بٹن کا استعمال کریں۔';

  @override
  String get chatTourSidebarProjectTools =>
      'گفتگو کا سائڈبار اور پروجیکٹ ٹولز دکھانے کے لیے اس مینو کا استعمال کریں۔';

  @override
  String get chatTourSwitchFolders =>
      'پروجیکٹ فولڈرز اور سیاق و سباق کو تبدیل کرنے کے لیے اس بٹن کا استعمال کریں۔';

  @override
  String get chatUndoLastTurn => 'آخری موڑ کو کالعدم کریں۔';

  @override
  String get chatUndoNothing => 'اس سیشن میں کالعدم کرنے کے لیے کچھ نہیں ہے';

  @override
  String get chatUseCurrent => 'موجودہ استعمال کریں۔';

  @override
  String get chatWaitingForNetworkConnection => 'نیٹ ورک کنکشن کا انتظار...';

  @override
  String get chatWelcomeMessage => 'ہیلو! میں آپ کا AI معاون ہوں۔';

  @override
  String get chatWelcomeSubmessage => 'آج میں آپ کی کس طرح مدد کر سکتا ہوں؟';

  @override
  String get chatWorkBoundedPanelExplanation =>
      'چیٹ ویو پورٹ کو مستحکم رکھنے کے لیے ٹول کی تازہ ترین سرگرمی اس باؤنڈڈ پینل کے اندر رہتی ہے۔';

  @override
  String get chatWorkExpand => 'پھیلائیں۔';

  @override
  String get chatWorkHide => 'چھپائیں';

  @override
  String get chatWorkMessageOne => '1 کام کا پیغام';

  @override
  String chatWorkMessagesMultiple(int count) {
    return '$count کام کے پیغامات';
  }

  @override
  String get chatWorkShow => 'دکھائیں۔';

  @override
  String get commonCancel => 'منسوخ کریں۔';

  @override
  String get commonCopiedToClipboard => 'کلپ بورڈ پر کاپی ہو گیا';

  @override
  String get commonDelete => 'حذف کریں۔';

  @override
  String get commonFile => 'فائل';

  @override
  String get commonReset => 'دوبارہ ترتیب دیں۔';

  @override
  String get commonSave => 'محفوظ کریں۔';

  @override
  String get compactionAutomatic => 'خودکار';

  @override
  String get compactionManual => 'دستی';

  @override
  String get composerAddAttachment => 'منسلکہ شامل کریں۔';

  @override
  String get composerAttachFiles => 'فائلیں منسلک کریں۔';

  @override
  String get composerCannedAppendAtCursor => 'کرسر پر شامل کریں۔';

  @override
  String get composerCannedLabel => 'لیبل (اختیاری)';

  @override
  String get composerCannedNoReplies => 'ابھی تک کوئی فوری جواب نہیں ہے۔';

  @override
  String get composerCannedReplace => 'بدل دیں۔';

  @override
  String get composerCannedSave => 'محفوظ کریں۔';

  @override
  String get composerCannedScopeGlobal => 'عالمی';

  @override
  String get composerCannedScopeProject => 'صرف پروجیکٹ';

  @override
  String get composerCannedSendAutomatically => 'خود بخود بھیجیں۔';

  @override
  String get composerCannedText => 'متن';

  @override
  String get composerChatInput => 'چیٹ ان پٹ';

  @override
  String get composerDeleteAction => 'حذف کریں۔';

  @override
  String get composerDropHint => 'منسلک کرنے کے لیے تصاویر یا PDF چھوڑیں';

  @override
  String get composerPastedImageName => 'چسپاں کردہ تصویر';

  @override
  String get composerEdit => 'ترمیم کریں۔';

  @override
  String get composerExtras => 'اضافی';

  @override
  String get composerExtrasHide => 'اضافی چھپائیں';

  @override
  String get composerNewQuickReply => 'نیا فوری جواب';

  @override
  String get composerSelectImages => 'امیجز کو منتخب کریں۔';

  @override
  String get composerSelectPdf => 'پی ڈی ایف منتخب کریں۔';

  @override
  String get composerSend => 'بھیجیں۔';

  @override
  String get composerShellMode => 'شیل موڈ';

  @override
  String get desktopWindowClose => 'بند کریں';

  @override
  String get desktopWindowMaximize => 'بڑا کریں';

  @override
  String get desktopWindowMinimize => 'چھوٹا کریں';

  @override
  String get desktopWindowRestore => 'بحال کریں';

  @override
  String get dialogDownload => 'ڈاؤن لوڈ کریں۔';

  @override
  String get dialogLanguage => 'زبان';

  @override
  String get dialogMoonshineModelSize => 'ماڈل کا سائز';

  @override
  String get dialogMoonshineVoiceSetup => 'مونشائن وائس سیٹ اپ';

  @override
  String get dialogParakeetModel => 'پیراکیٹ ماڈل';

  @override
  String get dialogParakeetVoiceSetup => 'پیراکیٹ وائس سیٹ اپ';

  @override
  String get dialogSenseVoiceModel => 'SenseVoice ماڈل';

  @override
  String get dialogSenseVoiceSetup => 'SenseVoice سیٹ اپ';

  @override
  String get dialogVoiceInputSetup => 'وائس ان پٹ سیٹ اپ';

  @override
  String get errorAnErrorOccurred => 'ایک خرابی پیش آگئی';

  @override
  String get errorAuthRequired => 'تصدیق درکار ہے';

  @override
  String get errorAuthRequiredDesc =>
      'تصدیق ناکام ہوگئی۔ فراہم کنندہ کو دوبارہ منسلک کریں اور دوبارہ کوشش کریں۔';

  @override
  String get errorConnectionFailed => 'کنکشن ناکام ہوگیا';

  @override
  String get errorConnectionFailedDesc =>
      'سرور تک پہنچنے میں ناکام۔ کنکشن اور سرور کی حیثیت چیک کریں۔';

  @override
  String get errorFormatAuthenticationFailedReconnect =>
      'تصدیق ناکام ہوگئی۔ فراہم کنندہ کو دوبارہ جوڑیں اور دوبارہ کوشش کریں۔';

  @override
  String get errorFormatProviderTemporarilyUnavailable =>
      'فراہم کنندہ عارضی طور پر دستیاب نہیں ہے۔ تھوڑی دیر میں دوبارہ کوشش کریں۔';

  @override
  String get errorFormatQuotaExceededCheck =>
      'کوٹہ سے تجاوز کر گیا۔ اپنے فراہم کنندہ کا منصوبہ یا بلنگ چیک کریں۔';

  @override
  String get errorFormatRateLimitExceeded =>
      'شرح کی حد سے تجاوز کر گیا۔ ایک لمحہ انتظار کریں اور دوبارہ کوشش کریں۔';

  @override
  String get errorFormatServerErrorPlease =>
      'سرور کی خرابی۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get errorFormatServiceTemporarilyUnavailable =>
      'سروس عارضی طور پر دستیاب نہیں ہے۔ ہو سکتا ہے سرور شروع ہو رہا ہو — براہ کرم جلد ہی دوبارہ کوشش کریں۔';

  @override
  String get errorFormatUnableReachServer =>
      'سرور تک پہنچنے سے قاصر۔ کنکشن اور سرور کی حیثیت چیک کریں۔';

  @override
  String get errorProviderUnavailable => 'فراہم کنندہ دستیاب نہیں ہے';

  @override
  String get errorProviderUnavailableDesc =>
      'فراہم کنندہ عارضی طور پر دستیاب نہیں ہے۔ تھوڑی دیر میں دوبارہ کوشش کریں۔';

  @override
  String get errorQuotaExceeded => 'کوٹہ ختم ہو گیا';

  @override
  String get errorQuotaExceededDesc =>
      'کوٹہ ختم ہو گیا۔ اپنے فراہم کنندہ کا پلان یا بلنگ چیک کریں۔';

  @override
  String get errorRateLimitExceeded => 'ریٹ کی حد سے تجاوز کر گیا';

  @override
  String get errorRateLimitExceededDesc =>
      'ریٹ کی حد سے تجاوز کر گیا۔ تھوڑی دیر انتظار کریں اور دوبارہ کوشش کریں۔';

  @override
  String get errorServerError => 'سرور کی خرابی';

  @override
  String get errorServerErrorDesc =>
      'سرور کی خرابی۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get errorServiceUnavailable => 'سروس دستیاب نہیں ہے';

  @override
  String get errorServiceUnavailableDesc =>
      'سروس عارضی طور پر دستیاب نہیں ہے۔ سرور شروع ہو رہا ہو سکتا ہے — براہ کرم تھوڑی دیر میں دوبارہ کوشش کریں۔';

  @override
  String get fileActionAttachmentDataDecoded =>
      'منسلکہ ڈیٹا کو ڈی کوڈ نہیں کیا جا سکا۔';

  @override
  String get fileActionAttachmentPathEmpty => 'منسلکہ راستہ خالی ہے۔';

  @override
  String get fileActionAttachmentPayloadEmpty => 'اٹیچمنٹ پے لوڈ خالی ہے۔';

  @override
  String get fileActionAttachmentProvideValid =>
      'منسلکہ درست مقام فراہم نہیں کرتا ہے۔';

  @override
  String get fileActionAttachmentSavedDevice =>
      'اٹیچمنٹ کو اس ڈیوائس پر محفوظ نہیں کیا جا سکا۔';

  @override
  String fileActionAttachmentSavedOutputFile(String path) {
    return 'منسلک $path میں محفوظ اور کھولا گیا۔';
  }

  @override
  String fileActionAttachmentSavedOutputFile2(String path) {
    return 'منسلک $path میں محفوظ ہوا۔';
  }

  @override
  String fileActionAttachmentSavedSavedPath(String savedPath) {
    return 'منسلک $savedPath میں محفوظ ہوا۔';
  }

  @override
  String get fileActionLocalAttachmentFound =>
      'اس آلہ پر مقامی منسلکہ نہیں ملا۔';

  @override
  String get fileActionSaveCanceled => 'محفوظ کرنا منسوخ ہو گیا۔';

  @override
  String get fileActionUnableOpenLocal => 'مقامی منسلکہ کھولنے سے قاصر۔';

  @override
  String get filesAddChat => 'چیٹ میں شامل کریں۔';

  @override
  String get filesAutosave => 'خودکار محفوظ';

  @override
  String get filesAutosaveOn => 'خودکار محفوظ فعال';

  @override
  String get filesAutosaveOff => 'خودکار محفوظ غیر فعال';

  @override
  String get filesRedo => 'دوبارہ کریں';

  @override
  String get filesUndo => 'واپس کریں';

  @override
  String get filesBinaryFilePreview =>
      'بائنری فائل کا پیش نظارہ دستیاب نہیں ہے۔';

  @override
  String get filesClear => 'صاف';

  @override
  String get filesContents => 'مشمولات';

  @override
  String get filesDuplicate => 'نقل بنائیں';

  @override
  String get filesDuplicated => 'فائل کی نقل بن گئی';

  @override
  String get filesFileEmpty => 'فائل خالی ہے۔';

  @override
  String get filesAlreadyExists =>
      'A file or folder with that name already exists.';

  @override
  String get filesCopyPath => 'Copy path';

  @override
  String get filesCreateFileTitle => 'Create file';

  @override
  String get filesCreateFolderTitle => 'Create folder';

  @override
  String get filesDelete => 'Delete';

  @override
  String filesDeleteConfirm(String name) {
    return 'Delete $name? This cannot be undone. Folders and their contents will be deleted.';
  }

  @override
  String filesDeleteTitle(String name) {
    return 'Delete $name';
  }

  @override
  String get filesFilesFound => 'کوئی فائل نہیں ملی';

  @override
  String get filesFileCreated => 'File created.';

  @override
  String get filesFolderCreated => 'Folder created.';

  @override
  String get filesHideSidebar => 'فائلوں کی سائڈبار کو چھپائیں۔';

  @override
  String get filesInvalidName => 'Enter a valid name without path separators.';

  @override
  String get filesNameHint => 'Name';

  @override
  String get filesNew => 'New';

  @override
  String get filesNewFile => 'New file';

  @override
  String get filesNewFolder => 'New folder';

  @override
  String get filesNames => 'نام';

  @override
  String filesOpenFilesFileState(int length) {
    return 'کھلی فائلیں ($length)';
  }

  @override
  String get filesQuickOpen => 'فوری کھولیں۔';

  @override
  String get filesQuickOpenFile => 'فوری کھولیں فائل';

  @override
  String get filesOperationFailed => 'File operation failed.';

  @override
  String get filesOperationUnavailable =>
      'File operations are not available for this server.';

  @override
  String get filesOutsideRoot => 'The path is outside the project root.';

  @override
  String get filesPathCopied => 'Path copied.';

  @override
  String get filesPathMissing => 'Path does not exist.';

  @override
  String get filesPermissionDenied => 'Permission denied.';

  @override
  String get filesRefresh => 'فائلوں کو ریفریش کریں۔';

  @override
  String get filesRename => 'Rename';

  @override
  String filesRenameTitle(String name) {
    return 'Rename $name';
  }

  @override
  String get filesRenamed => 'Renamed.';

  @override
  String get filesRootDeleteBlocked => 'The project root cannot be deleted.';

  @override
  String get filesSearchHint => 'نام یا راستے سے فائلیں تلاش کریں۔';

  @override
  String get filesDeleted => 'Deleted.';

  @override
  String get filesTitle => 'فائلیں';

  @override
  String get forwardAction => 'Forward';

  @override
  String get forwardAllFailed => 'Could not forward to any session';

  @override
  String get forwardCancel => 'Cancel';

  @override
  String get forwardDialogSubtitle => 'Select one or more conversations';

  @override
  String get forwardDialogTitle => 'Forward to…';

  @override
  String get forwardLoading => 'Loading sessions…';

  @override
  String get forwardNoOpenProjects => 'No open projects with sessions';

  @override
  String get forwardNoProviderModel =>
      'Select a provider and model before forwarding';

  @override
  String get forwardNoSessions => 'No recent sessions';

  @override
  String forwardPartial(int success, int total) {
    return 'Forwarded to $success of $total';
  }

  @override
  String forwardProvenanceLabel(String origin) {
    return 'Forwarded from: $origin';
  }

  @override
  String get forwardRetry => 'Retry';

  @override
  String get forwardSearchHint => 'Search';

  @override
  String forwardSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get forwardSend => 'Forward';

  @override
  String get forwardServerOffline => 'Server offline';

  @override
  String get forwardShortcutHint => 'Ctrl+Shift+F';

  @override
  String forwardSuccess(int count) {
    return 'Forwarded to $count sessions';
  }

  @override
  String get forwardUndo => 'Undo';

  @override
  String get forwardUndoFailed => 'Could not undo the forward';

  @override
  String get logsAppLogs => 'ایپ لاگز';

  @override
  String get logsClear => 'نوشتہ جات صاف کریں۔';

  @override
  String get logsCloseSearch => 'تلاش بند کریں۔';

  @override
  String get logsCopyFiltered => 'فلٹر شدہ لاگز کو کاپی کریں۔';

  @override
  String get logsEnableLogging => 'ایپ لاگز فعال کریں';

  @override
  String get logsEnableLoggingAction => 'لاگز فعال کریں';

  @override
  String get logsEnableLoggingDescription =>
      'میموری میں تشخیصی لاگز جمع کرتا ہے۔ مسئلہ حل کرنے کے علاوہ اسے بند رکھیں۔';

  @override
  String get logsEntryContext => 'سیاق';

  @override
  String get logsEntryTags => 'ٹیگز';

  @override
  String get logsFilterAll => 'تمام';

  @override
  String get logsFilterByTag => 'ٹیگ';

  @override
  String get logsLevel => 'سطح';

  @override
  String get logsLoggingDisabledDescription =>
      'CodeWalk تفصیلی ایپ لاگز جمع نہیں کر رہا۔ تشخیص کی ضرورت ہو تو ہی لاگز فعال کریں۔';

  @override
  String get logsLoggingDisabledTitle => 'لاگز غیر فعال ہیں';

  @override
  String get logsMeasurePerformance => 'کارکردگی ناپیں';

  @override
  String get logsMeasurePerformanceDescription =>
      'ایپ کے مہنگے آپریشنز کا وقت محفوظ کرتا ہے۔ سستی کی تشخیص کے علاوہ بند رکھیں۔';

  @override
  String get logsNoLogsYet => 'ابھی تک کوئی لاگز جمع نہیں ہوئے۔';

  @override
  String get logsNoMatchingLogs =>
      'موجودہ فلٹرز سے کوئی لاگز مطابقت نہیں رکھتے۔';

  @override
  String get logsNoPerformanceData =>
      'موجودہ فلٹرز سے کوئی کارکردگی لاگ نہیں ملتا۔';

  @override
  String get logsNoTaskData => 'موجودہ فلٹرز سے کوئی ٹاسک نہیں ملتا۔';

  @override
  String logsPerformanceDuration(int elapsedMs) {
    return '$elapsedMs ms';
  }

  @override
  String get logsPerformanceFilter => 'کارکردگی';

  @override
  String logsPerformanceTileTitle(
    int elapsedMs,
    String operation,
    String status,
  ) {
    return 'کارکردگی $operation | $elapsedMs ms | $status';
  }

  @override
  String get logsSearch => 'لاگز تلاش کریں۔';

  @override
  String logsShowingOrderedLength(int length, int length2) {
    return '$length2 اندراجات میں سے $length دکھائے گئے';
  }

  @override
  String get logsSlowestPerformance => 'سب سے سست کارکردگی لاگز';

  @override
  String get logsSlowestTasks => 'سب سے سست ٹاسکس';

  @override
  String get logsTagCustomHint => 'ٹیگ کا نام (مثلاً: task:select_session)';

  @override
  String get logsTagCustomAction => 'حسب ضرورت...';

  @override
  String logsTaskDuration(int elapsedMs, String operation) {
    return '$operation — $elapsedMs ms';
  }

  @override
  String get logsTaskStatusCanceled => 'منسوخ';

  @override
  String get logsTaskStatusError => 'خرابی';

  @override
  String get logsTaskStatusOk => 'ٹھیک';

  @override
  String get logsTimeRange => 'وقت کی حد';

  @override
  String get mathExpressionLabel => 'ریاضی';

  @override
  String get mermaidCopySourceTooltip => 'ماخذ کاپی کریں۔';

  @override
  String get mermaidDiagramLabel => 'متسیستری خاکہ';

  @override
  String get modelAuto => 'آٹو';

  @override
  String get modelChooseAgent => 'ایجنٹ کا انتخاب کریں۔';

  @override
  String get modelFavorites => 'پسندیدہ';

  @override
  String get modelFree => 'مفت';

  @override
  String get modelLabelBaseEnglish => 'بنیادی (انگریزی)';

  @override
  String get modelLabelParakeet => 'Parakeet V3 (25 یورپی زبانیں)';

  @override
  String get modelLabelSenseVoice => 'SenseVoice (zh/en/ja/ko/yue)';

  @override
  String get modelLabelTinyEnglish => 'Tiny (انگریزی)';

  @override
  String get modelLoadingModels => 'ماڈلز لوڈ ہو رہے ہیں۔';

  @override
  String get modelModelsFound => 'کوئی ماڈل نہیں ملا';

  @override
  String get modelRetryModels => 'ماڈلز کی دوبارہ کوشش کریں۔';

  @override
  String get modelSearchHint => 'ماڈل یا فراہم کنندہ تلاش کریں۔';

  @override
  String get msgBatterySettingsFailed =>
      'اینڈرائیڈ بیٹری آپٹیمائزیشن سیٹنگز کو نہیں کھولا جا سکا۔';

  @override
  String get msgBatterySettingsOpened =>
      'اینڈرائیڈ بیٹری کی سیٹنگز کھل گئیں۔ کوڈ واک کے لیے غیر محدود بیٹری کی اجازت دیں۔';

  @override
  String get msgClearUsernameNeedsConfigEdit =>
      'اوپن کوڈ گفتگو کے صارف نام کو صاف کرنے کے لیے اب بھی ایپ کے باہر کنفیگریشن میں ترمیم کی ضرورت ہے۔';

  @override
  String get msgCommandCopied => 'کمانڈ کاپی ہو گیا۔';

  @override
  String get msgCopiedToClipboard => 'کلپ بورڈ پر کاپی ہو گیا۔';

  @override
  String get msgEnterUsernameToSave =>
      'اپنی مرضی کے اوپن کوڈ گفتگو کا نام محفوظ کرنے کے لیے صارف نام درج کریں۔';

  @override
  String get msgFailedToSendMessage =>
      'پیغام بھیجنے میں ناکام۔ مسودہ دوبارہ کوشش کے لیے رکھا گیا۔';

  @override
  String get msgFailedToStartVoiceInput => 'صوتی ان پٹ شروع کرنے میں ناکام';

  @override
  String msgFilePathNotFound(String path) {
    return 'فائل نہیں ملی: $path';
  }

  @override
  String get msgFilteredLogsCopied =>
      'فلٹر شدہ لاگز کو کلپ بورڈ پر کاپی کیا گیا۔';

  @override
  String get msgInfoAgent => 'ایجنٹ';

  @override
  String get msgInfoCompaction => 'کومپیکشن';

  @override
  String msgInfoCost(double cost) {
    return 'لاگت: \\\$ $cost';
  }

  @override
  String get msgInfoMessageInfo => 'پیغام کی معلومات';

  @override
  String msgInfoModel(String modelId) {
    return 'ماڈل: $modelId';
  }

  @override
  String get msgInfoNoMetadata => 'کوئی میٹا ڈیٹا دستیاب نہیں ہے۔';

  @override
  String msgInfoPartDescriptionModel(String description, String model) {
    return '$description $model';
  }

  @override
  String get msgInfoPatch => 'پیوند';

  @override
  String msgInfoProvider(String providerId) {
    return 'فراہم کنندہ: $providerId';
  }

  @override
  String get msgInfoRetry => 'دوبارہ کوشش کریں۔';

  @override
  String get msgInfoSnapshot => 'سنیپ شاٹ';

  @override
  String msgInfoSubtaskPartAgent(String agent) {
    return 'ذیلی کام ($agent)';
  }

  @override
  String msgInfoTokens(int total) {
    return 'ٹوکنز: $total';
  }

  @override
  String get msgInfoUndoThisTurn => 'اس موڑ کو کالعدم کریں۔';

  @override
  String get msgInfoView => 'دیکھیں';

  @override
  String get msgNoSystemSoundsFound => 'اس ڈیوائس پر کوئی سسٹم ساؤنڈ نہیں ملا۔';

  @override
  String get msgNoValidFilesSelected => 'کوئی درست فائلیں منتخب نہیں کی گئیں۔';

  @override
  String get msgSomeSelectedFilesNotAttached =>
      'کچھ منتخب فائلیں منسلک نہیں کی جا سکیں۔';

  @override
  String get msgReadAloud => 'بلند آواز سے پڑھیں';

  @override
  String get msgReadAloudNotAvailable =>
      'اس ڈیوائس پر ٹیکسٹ ٹو اسپیچ دستیاب نہیں ہے۔';

  @override
  String get msgSetupDebugCopied =>
      'اوپن کوڈ سیٹ اپ ڈیبگ کلپ بورڈ پر کاپی ہو گیا۔';

  @override
  String get msgShareAsImage => 'تصویر کے طور پر شیئر کریں۔';

  @override
  String get msgShareAsImageFailed =>
      'تصویر کے بطور پیغام کا اشتراک نہیں کیا جا سکا۔';

  @override
  String get msgShareAsImageSubject => 'کوڈ واک پیغام';

  @override
  String get msgShareAsImageTooTall =>
      'پیغام تصویر کے بطور اشتراک کرنے کے لیے بہت لمبا ہے۔';

  @override
  String get msgStopReadAloud => 'پڑھنا بند کرو';

  @override
  String get msgSystemSoundPickerUnavailable =>
      'سسٹم ساؤنڈ چننے والا اس پلیٹ فارم پر دستیاب نہیں ہے۔';

  @override
  String get msgUpdatedButRefreshFailed =>
      'سرور کی ترتیب کو اپ ڈیٹ کیا، لیکن چیٹ فراہم کرنے والوں کو ریفریش نہیں کیا جا سکا۔';

  @override
  String get msgVoiceInputUnavailable => 'اس آلہ پر صوتی ان پٹ دستیاب نہیں ہے۔';

  @override
  String get notifAndroidBatteryOptimization => 'اینڈرائیڈ بیٹری آپٹیمائزیشن';

  @override
  String get notifConversationUpdates => 'بات چیت کی تازہ کاری';

  @override
  String get notifNotificationsArriveReopening =>
      'اگر اطلاعات صرف ایپ کو دوبارہ کھولنے پر پہنچتی ہیں، تو CodeWalk کو اس ڈیوائس پر آپٹیمائزیشن کے بغیر چلنے دیں۔';

  @override
  String get notifResponseRunningKeep =>
      'جب کوئی جواب چل رہا ہو، ایپ چھوڑنے کے بعد مختصر وقت کے لیے ریئل ٹائم کو فعال رکھیں۔';

  @override
  String notifSelectedSoundLabel(String soundLabel) {
    return 'منتخب: $soundLabel';
  }

  @override
  String get notificationAgentFinished =>
      'ایجنٹ نے موجودہ جواب مکمل کر لیا ہے۔';

  @override
  String get notificationConversationUpdates => 'گفتگو کی اپ ڈیٹس';

  @override
  String get notificationOpenToClear =>
      'متعلقہ اطلاعات کو صاف کرنے کے لیے یہ گفتگو کھولیں۔';

  @override
  String get notificationSession => 'سیشن';

  @override
  String get notificationSoundLoadFailed =>
      'اینڈرائیڈ سسٹم کی آوازیں لوڈ کرنے میں ناکام';

  @override
  String get onboardingAIGeneratedTitles => 'AI نے عنوانات بنائے';

  @override
  String get onboardingAddServerLater =>
      'آپ بعد میں ترتیبات > سرورز میں سرور شامل کر سکتے ہیں۔';

  @override
  String get onboardingAddedButHealthCheckFailed =>
      'سرور شامل کر دیا گیا لیکن ہیلتھ چیک ناکام رہا۔ یہ ابھی شروع ہو رہا ہو سکتا ہے۔';

  @override
  String get onboardingAlmostInstallOpenCode =>
      'آپ تقریباً وہاں پہنچ چکے ہیں۔ پہلے OpenCode انسٹال کریں، پھر CodeWalk کو سرور URL سے جوڑیں۔';

  @override
  String onboardingAppProviderLocalSetupLogsLength(int length, int length2) {
    return '$length سیٹ اپ لاگ سطریں اور $length2 سیٹ اپ واقعات الگ سیٹ اپ ڈی بگ اسکرین میں دستیاب ہیں۔';
  }

  @override
  String get onboardingAuthenticate => 'تصدیق کریں۔';

  @override
  String get onboardingAvailable => 'دستیاب';

  @override
  String get onboardingAvailableOnlyDesktop =>
      'صرف ڈیسک ٹاپ (Linux/macOS/Windows) پر دستیاب ہے۔';

  @override
  String get onboardingBasicAuthTip =>
      'بنیادی تصدیق صرف اس صورت میں فعال کریں جب آپ کا OpenCode سرور پاس ورڈ سے محفوظ ہو۔';

  @override
  String get onboardingChooseAnotherPath => 'کوئی اور راستہ چنیں۔';

  @override
  String get onboardingChooseHowToSetup =>
      'اپنا سرور سیٹ اپ کرنے کا طریقہ منتخب کریں';

  @override
  String get onboardingClear => 'صاف';

  @override
  String get onboardingCloudflareAuthFailed =>
      'Cloudflare Access کی تصدیق ناکام ہوگئی۔';

  @override
  String get onboardingCodeWalkAppOpenCode =>
      'کوڈ واک ایک ایپ ہے۔ اوپن کوڈ وہ انجن ہے جس سے یہ جڑتا ہے۔';

  @override
  String get onboardingConnectRunningServer => 'چلتے ہوئے سرور سے جڑیں۔';

  @override
  String get onboardingConnectionIssue => 'کنکشن کا مسئلہ';

  @override
  String get onboardingConnectionSaved => 'سرور کنکشن کامیابی سے محفوظ ہو گیا۔';

  @override
  String get onboardingConnectionTips => 'کنکشن کی تجاویز';

  @override
  String get onboardingConnectionUpdated =>
      'سرور کنکشن کامیابی سے اپ ڈیٹ ہو گیا۔';

  @override
  String get onboardingContinue => 'جاری رکھیں';

  @override
  String get onboardingContinueServerURL => 'سرور URL پر جاری رکھیں';

  @override
  String get onboardingCopyLoginURL => 'لاگ ان URL کاپی کریں۔';

  @override
  String get onboardingCouldNotVerify => 'سرور کنکشن کی تصدیق نہیں ہو سکی۔';

  @override
  String get onboardingDefaultURLEmulator =>
      'ڈیفالٹ یو آر ایل، ایمولیٹر لوپ بیک، تصدیق، اور ڈیبگ مدد۔';

  @override
  String onboardingDesktopOnlyDiagnose(String appName) {
    return 'صرف ڈیسک ٹاپ: $appName آپ کے لیے OpenCode کی تشخیص، انسٹال اور چلا سکتا ہے۔';
  }

  @override
  String get onboardingDetailedSetupEvents =>
      'ٹربل شوٹنگ کے لیے تفصیلی سیٹ اپ ایونٹس کیپچر کیے گئے۔';

  @override
  String get onboardingDonShowAgain => 'دوبارہ مت دکھائیں۔';

  @override
  String get onboardingDone => 'مکمل';

  @override
  String get onboardingEditServer => 'سرور میں ترمیم کریں';

  @override
  String get onboardingEditServerConnection => 'سرور کنکشن میں ترمیم کریں';

  @override
  String get onboardingEmulatorRemap =>
      'اینڈرائیڈ ایمولیٹر پر، localhost اور 127.0.0.1 خود بخود 10.0.2.2 پر ری میپ ہو جاتے ہیں۔';

  @override
  String get onboardingEnterServerUrl => 'سرور کا URL درج کریں';

  @override
  String get onboardingExisting => 'موجودہ استعمال کریں۔';

  @override
  String get onboardingExplainInstallOpenCode =>
      'اوپن کوڈ کو انسٹال کرنے، سرور کو شروع کرنے اور پھر CodeWalk سے جڑنے کا طریقہ بتائیں۔';

  @override
  String get onboardingFailed => 'ناکام';

  @override
  String get onboardingGoodOptionDesktop => 'ڈیسک ٹاپ پر پہلا اچھا آپشن';

  @override
  String get onboardingHealthCheckFailedMayBeStarting =>
      'سرور ہیلتھ چیک ناکام رہا۔ یہ ابھی شروع ہو رہا ہو سکتا ہے۔';

  @override
  String get onboardingInstallBinary => 'بائنری انسٹال کریں۔';

  @override
  String get onboardingInstallBun => 'بن کے ذریعے انسٹال کریں۔';

  @override
  String get onboardingInstallBunOpenCode => 'بن + اوپن کوڈ انسٹال کریں۔';

  @override
  String get onboardingInstallNpm => 'npm کے ذریعے انسٹال کریں۔';

  @override
  String get onboardingInstallRunOpenCode =>
      'ڈیسک ٹاپ پر CodeWalk سے براہ راست OpenCode انسٹال اور چلائیں۔';

  @override
  String get onboardingInvalidUrl => 'غلط URL';

  @override
  String get onboardingLabel => 'لیبل (اختیاری)';

  @override
  String get onboardingLabelHint => 'میرا سرور';

  @override
  String onboardingLatestOutputAppProvider(String localServerLastOutput) {
    return 'تازہ ترین آؤٹ پٹ: $localServerLastOutput';
  }

  @override
  String get onboardingLetCodeWalkSet =>
      'CodeWalk کو اسے مقامی طور پر ترتیب دینے دیں۔';

  @override
  String get onboardingLocalServerSetup => 'مقامی سرور سیٹ اپ';

  @override
  String get onboardingManagedLocalServer => 'منظم مقامی سرور';

  @override
  String get onboardingManagedLocalServer2 =>
      'مینیجڈ لوکل سرور موڈ صرف ڈیسک ٹاپ بلڈز (Linux/macOS/Windows) پر دستیاب ہے۔';

  @override
  String onboardingNeedsOpenCodeServer(String appName) {
    return '$appName کو آپ کے کوڈ میں مدد کرنے سے پہلے ایک OpenCode سرور کی ضرورت ہے۔';
  }

  @override
  String get onboardingNotAvailable => 'دستیاب نہیں';

  @override
  String get onboardingNotWritable => 'قابل تحریر نہیں';

  @override
  String get onboardingOpenCode => 'اوپن کوڈ کیا ہے؟';

  @override
  String get onboardingOpenCodeRunningDevice =>
      'میرے پاس پہلے سے ہی اس ڈیوائس پر یا میرے نیٹ ورک پر کہیں OpenCode چل رہا ہے۔';

  @override
  String get onboardingOpenCodeRunsLocally =>
      'OpenCode مقامی طور پر یا سرور پر چلتا ہے اور CodeWalk کے اندر AI کوڈنگ کی خصوصیات کو طاقت دیتا ہے۔ اگر اوپن کوڈ پہلے سے چل رہا ہے تو اس سے جڑیں۔ اگر نہیں، تو ذیل میں ہدایت یافتہ سیٹ اپ کے راستوں میں سے ایک کو منتخب کریں۔';

  @override
  String get onboardingOpenTailscaleLogin =>
      'Tailscale لاگ ان URL نہیں کھول سکا۔';

  @override
  String get onboardingPassword => 'پاس ورڈ';

  @override
  String get onboardingPasswordRequired => 'پاس ورڈ درج کریں۔';

  @override
  String get onboardingPickSetupPath =>
      'وہ سیٹ اپ راستہ منتخب کریں جو آپ کے موجودہ OpenCode سیٹ اپ سے میل کھاتا ہو۔';

  @override
  String get onboardingPreconditionDirectoryNotWritable =>
      'انسٹالیشن ڈائریکٹری لکھنے کے قابل نہیں ہے۔ صارف کی اجازتیں چیک کریں۔';

  @override
  String get onboardingPreconditionInstallViaBunRecommendation =>
      'OpenCode کے نگہبانوں کی طرف سے Bun کے ذریعے انسٹالیشن تجویز کی گئی ہے۔';

  @override
  String get onboardingPreconditionNetworkFailed =>
      'نیٹ ورک تک رسائی ناکام ہو گئی۔ OpenCode انسٹال کرنے سے پہلے رابطہ چیک کریں۔';

  @override
  String get onboardingPreconditionNoRuntimeDetected =>
      'کوئی رن ٹائم نہیں ملا۔ براہ راست OpenCode بائنری انسٹال کریں یا پہلے Bun بوٹسٹریپ کریں۔';

  @override
  String get onboardingPreconditionNodeNpmAvailable =>
      'Node اور npm دستیاب ہیں۔ OpenCode کو npm کے ذریعے انسٹال کریں یا تجویز کردہ طریقہ کار کے لیے Bun انسٹال کریں۔';

  @override
  String get onboardingPreconditionOpenCodeAlreadyAvailable =>
      'OpenCode پہلے ہی دستیاب ہے۔ آپ دریافت شدہ کمانڈ کو فوری طور پر استعمال کر سکتے ہیں۔';

  @override
  String get onboardingPreconditionWindowsPathLagHint =>
      ' ونڈوز پر، انسٹالیشن کے بعد چیک کو ریفریش کریں کیونکہ پہلے سے کھلی ایپس میں PATH اپ ڈیٹس میں تاخیر ہو سکتی ہے۔';

  @override
  String get onboardingPreconditionWindowsWslRecommendation =>
      'ونڈوز بلڈ کا پتہ چلا ہے۔ OpenCode دستاویزات کی رو سے WSL تجویز کردہ ہے، لیکن متبادل کے طور پر npm install استعمال کیا جا سکتا ہے۔';

  @override
  String get onboardingReachable => 'قابل رسائی';

  @override
  String get onboardingReady => 'تیار';

  @override
  String get onboardingRecommendedOrderTry =>
      'تجویز کردہ آرڈر: Bun + OpenCode انسٹال کرنے کی کوشش کریں اگر آپ چاہتے ہیں کہ CodeWalk آپ کے لیے ہر چیز کو بوٹسٹریپ کرے۔ اگر OpenCode پہلے سے انسٹال ہے تو Existing استعمال کریں۔';

  @override
  String get onboardingRefreshChecks => 'چیک ریفریش کریں۔';

  @override
  String get onboardingRunDiagnosticsToVerify =>
      'مقامی OpenCode ضروریات کی تصدیق کے لیے تشخیص چلائیں۔';

  @override
  String get onboardingSaveAndTest => 'محفوظ کریں اور ٹیسٹ کریں';

  @override
  String get onboardingServerConnectedReady =>
      'آپ کا سرور منسلک اور استعمال کے لیے تیار ہے۔';

  @override
  String get onboardingServerConnection => 'سرور کنکشن';

  @override
  String get onboardingServerSettingsSaved =>
      'آپ کی سرور کی ترتیبات محفوظ کر لی گئیں اور ہیلتھ چیک اپ ڈیٹ کر دیے گئے۔';

  @override
  String get onboardingServerSetup => 'سرور سیٹ اپ';

  @override
  String get onboardingServerUpdated => 'سرور اپ ڈیٹ ہو گیا';

  @override
  String get onboardingServerUrl => 'سرور URL';

  @override
  String get onboardingSetup => 'سیٹ اپ';

  @override
  String get onboardingSetupWizard => 'سیٹ اپ وزرڈ';

  @override
  String get onboardingShowSetupSteps => 'مجھے سیٹ اپ کے اقدامات دکھائیں۔';

  @override
  String get onboardingShowSetupSteps2 => 'سیٹ اپ کے اقدامات دکھائیں۔';

  @override
  String get onboardingSkip => 'ابھی کے لیے چھوڑ دیں۔';

  @override
  String get onboardingSkipSetup => 'سیٹ اپ چھوڑ دیں؟';

  @override
  String get onboardingStart => 'شروع کریں۔';

  @override
  String onboardingStartUsing(String appName) {
    return '$appName کا استعمال شروع کریں';
  }

  @override
  String get onboardingStarting => 'شروع ہو رہا ہے';

  @override
  String get onboardingStop => 'رک جاؤ';

  @override
  String get onboardingStopped => 'روکا ہوا';

  @override
  String get onboardingStopping => 'روک رہا ہے';

  @override
  String onboardingSuggestedUrl(String url) {
    return 'تجویز کردہ مقامی OpenCode سرور URL: $url';
  }

  @override
  String get onboardingTailscaleAdminApproval =>
      'Tailscale ایڈمن کی منظوری درکار ہے';

  @override
  String get onboardingTailscaleAuthAfterSave =>
      'محفوظ کرنے کے بعد Tailscale کی تصدیق ہوگی';

  @override
  String onboardingTailscaleAuthAfterSaveTest(String appName) {
    return 'اس سرور کو محفوظ کرنے اور ٹیسٹ کرنے کے بعد، $appName Tailscale لاگ ان کھولے گا اگر یہ ڈیوائس ابھی تک تصدیق شدہ نہیں ہے۔';
  }

  @override
  String get onboardingTailscaleConnected => 'Tailscale منسلک ہے';

  @override
  String get onboardingTailscaleConnecting => 'Tailscale منسلک ہو رہا ہے';

  @override
  String get onboardingTailscaleConnectionFailed => 'Tailscale کنکشن ناکام رہا';

  @override
  String get onboardingTailscaleLoginRequired => 'Tailscale لاگ ان درکار ہے';

  @override
  String get onboardingTailscaleOpenLoginUrl =>
      'اس ڈیوائس کو اپنے tailnet میں شامل کرنے کے لیے لاگ ان URL کھولیں۔ اگر براؤزر نہیں کھلا تو نیچے دیے گئے URL کو کاپی کریں۔';

  @override
  String get onboardingTailscaleUnsupported => 'Tailscale غیر تعاون یافتہ ہے';

  @override
  String get onboardingTestConnection => 'کنکشن ٹیسٹ کریں';

  @override
  String get onboardingTesting => 'ٹیسٹنگ...';

  @override
  String get onboardingUnreachable => 'ناقابل رسائی';

  @override
  String get onboardingUseBasicAuth => 'بنیادی سند استعمال کریں۔';

  @override
  String get onboardingUsername => 'صارف نام';

  @override
  String get onboardingUsernameRequired => 'صارف نام درج کریں۔';

  @override
  String get onboardingUsesServerTitle =>
      'بات چیت کو نام دینے کے لیے آپ کے سرور کے ٹائٹل ایجنٹ کا استعمال کرتا ہے۔';

  @override
  String get onboardingUsingDetectedCommand =>
      'پتہ لگائی گئی OpenCode کمانڈ کا استعمال کر رہا ہے۔';

  @override
  String get onboardingViewSetupDebug => 'سیٹ اپ ڈیبگ دیکھیں';

  @override
  String onboardingWelcomeTo(String appName) {
    return '$appName میں خوش آمدید';
  }

  @override
  String get onboardingWindowsTipInstalling =>
      'ونڈوز ٹپ: انسٹال کرنے کے بعد، ریفریش چیکز پر کلک کریں۔ اگر پتہ لگانے میں اب بھی ناکام ہو جاتا ہے، تو PATH تبدیلیوں کو دوبارہ لوڈ کرنے کے لیے CodeWalk کو دوبارہ کھولیں۔';

  @override
  String get onboardingWritable => 'قابل تحریر';

  @override
  String get onboardingYoureAllSet => 'آپ بالکل تیار ہیں!';

  @override
  String get permissionAllowOnce => 'ایک بار اجازت دیں۔';

  @override
  String get permissionAlways => 'ہمیشہ';

  @override
  String get permissionBack => 'پیچھے';

  @override
  String get permissionConfirmReject => 'مسترد کرنے کی تصدیق کریں۔';

  @override
  String get permissionReject => 'رد کرنا';

  @override
  String get permissionReopen => 'دوبارہ کھولیں۔';

  @override
  String get questionAnswerSelected => 'کوئی جواب منتخب نہیں کیا گیا۔';

  @override
  String get questionCommaSeparatedValues => 'کوما سے الگ کردہ اقدار';

  @override
  String get questionQuestionGroupMarked =>
      'سوالیہ گروپ کو مسترد شدہ کے بطور نشان زد کیا گیا۔ تصدیق کرنے سے پہلے آپ کسی بھی وقت چیٹنگ جاری رکھ سکتے ہیں اور اس گروپ کو دوبارہ کھول سکتے ہیں۔';

  @override
  String get questionQuestionRequest => 'سوال کی درخواست';

  @override
  String get questionQuestionsProvidedSubmit =>
      'کوئی سوالات فراہم نہیں کیے گئے۔ آپ خالی جواب جمع کرا سکتے ہیں۔';

  @override
  String get questionReviewAnswersSubmitting =>
      'جمع کرانے سے پہلے اپنے جوابات کا جائزہ لیں۔';

  @override
  String get quotaAuthCookie => 'اوتھ کوکی';

  @override
  String get quotaConnect => 'کنیکٹ کریں';

  @override
  String get quotaForget => 'بھول جاؤ';

  @override
  String get quotaOpenCodeGoConnectDescription =>
      'رولنگ، ہفتہ وار اور ماہانہ حدود دکھانے کے لیے استعمال کا ڈیش بورڈ کنیکٹ کریں۔';

  @override
  String get quotaOpenCodeGoDetected => 'OpenCode Go کا پتہ چلا';

  @override
  String get quotaOpenCodeGoNeedsReconnect =>
      'OpenCode Go کو دوبارہ کنیکٹ کرنے کی ضرورت ہے';

  @override
  String get quotaOpenCodeGoReconnectDescription =>
      'استعمال کی بارز بحال کرنے کے لیے ڈیش بورڈ اسناد کو ریفریش کریں۔';

  @override
  String get quotaOpenCodeGoUsage => 'اوپن کوڈ گو کا استعمال';

  @override
  String get quotaOpenDashboard => 'اوپن کوڈ ڈیش بورڈ کھولیں۔';

  @override
  String get quotaPaceExplanation =>
      'رفتار موجودہ شرح کی بنیاد پر موجودہ حد ونڈو کے آخر تک کل استعمال کی پیش گوئی کرتی ہے۔';

  @override
  String quotaPacePercent(String percent) {
    return 'رفتار $percent%';
  }

  @override
  String get quotaRateLimits => 'استعمال کی حدود';

  @override
  String get quotaReconnect => 'دوبارہ کنیکٹ کریں';

  @override
  String get quotaRefreshing => 'تازہ ہو رہا ہے...';

  @override
  String quotaResetsIn(String time) {
    return '$time میں ری سیٹ ہوگا';
  }

  @override
  String get quotaSaving => 'محفوظ کر رہا ہے...';

  @override
  String get quotaWorkspaceId => 'ورک اسپیس ID';

  @override
  String get serverClearOAuth => 'OAuth کو صاف کریں۔';

  @override
  String get serverConnectionAttention => 'سرور کنکشن پر توجہ درکار ہے۔';

  @override
  String get serverHealthHealthy => 'صحت مند';

  @override
  String get serverHealthUnhealthy => 'غیر صحت مند';

  @override
  String get serverHealthUnknown => 'نامعلوم';

  @override
  String get serverOAuthAuthFailed => 'OAuth کی توثیق ناکام ہوگئی';

  @override
  String get serverOAuthChip => 'OAuth';

  @override
  String get serverOAuthNotSupported =>
      'Cloudflare رسائی OAuth اس پلیٹ فارم پر تعاون یافتہ نہیں ہے۔';

  @override
  String get serverReauthenticate => 'دوبارہ تصدیق کریں۔';

  @override
  String get serverTailscaleChip => 'دم کا پیمانہ';

  @override
  String get serversActive => 'فعال';

  @override
  String get serversActiveServer => 'ایکٹو سرور';

  @override
  String get serversAddLeastOpenCode =>
      'ایپ کا استعمال شروع کرنے کے لیے کم از کم ایک OpenCode سرور شامل کریں۔';

  @override
  String get serversAddServer => 'سرور شامل کریں۔';

  @override
  String get serversCancel => 'منسوخ کریں۔';

  @override
  String get serversCannotActivateUnhealthy =>
      'غیر صحت مند سرور کو فعال نہیں کیا جا سکتا';

  @override
  String get serversCheckHealth => 'صحت کی جانچ کریں۔';

  @override
  String get serversClearDefault => 'ڈیفالٹ صاف کریں۔';

  @override
  String serversCommandAppProviderLocalServerCommandPath(
    String localServerCommandPath,
  ) {
    return 'کمانڈ: $localServerCommandPath';
  }

  @override
  String get serversCopy => 'کاپی';

  @override
  String get serversDefault => 'طے شدہ';

  @override
  String get serversDelete => 'حذف کریں۔';

  @override
  String get serversDeleteServer => 'سرور کو حذف کریں۔';

  @override
  String get serversDesktopModeExplanation =>
      'ڈیسک ٹاپ موڈ CodeWalk سے براہ راست `opencode serve` لانچ اور منظم کر سکتا ہے۔';

  @override
  String get serversEdit => 'ترمیم کریں۔';

  @override
  String get serversLocalOpenCodeServer => 'مقامی اوپن کوڈ سرور';

  @override
  String get serversManagedModeAvailable =>
      'یہ نظم شدہ وضع صرف ڈیسک ٹاپ بلڈز (Linux/macOS/Windows) پر دستیاب ہے۔';

  @override
  String get serversNoServersFound => 'کوئی سرور نہیں ملا';

  @override
  String get serversRefreshHealth => 'صحت کو تازہ کریں۔';

  @override
  String serversRemoveProfileDisplayName(String displayName) {
    return '\"$displayName\" ہٹائیں؟';
  }

  @override
  String get serversSearchActiveHint => 'فعال سرور تلاش کریں';

  @override
  String get serversServersConfigured => 'کوئی سرور کنفیگر نہیں ہے۔';

  @override
  String get serversSetActive => 'ایکٹو سیٹ کریں۔';

  @override
  String get serversSetDefault => 'ڈیفالٹ سیٹ کریں۔';

  @override
  String get serversSetupDebug => 'ڈیبگ سیٹ اپ کریں۔';

  @override
  String get serversSetupWizard => 'سیٹ اپ وزرڈ';

  @override
  String get serversTailscaleAdminApprovalRequired =>
      'Tailscale ایڈمن کی منظوری درکار';

  @override
  String get serversTailscaleAuthRequired => 'Tailscale تصدیق درکار';

  @override
  String get serversTailscaleConnectExplanation =>
      'जब یہ فعال پروفائل استعمال کیا جائے گا تو Tailscale منسلک ہو جائے گا۔';

  @override
  String get serversTailscaleConnected => 'Tailscale منسلک';

  @override
  String get serversTailscaleConnecting => 'Tailscale منسلک ہو رہا ہے';

  @override
  String get serversTailscaleConnectionFailed => 'Tailscale کنکشن ناکام';

  @override
  String get serversTailscaleDisconnected => 'Tailscale منقطع';

  @override
  String get serversTailscaleLoginExplanation =>
      'اس ڈیوائس کو اپنے tailnet میں شامل کرنے کے لیے Tailscale لاگ ان URL کھولیں۔';

  @override
  String get serversTailscaleTrafficExplanation =>
      'اس فعال پروفائل کے لیے OpenCode ٹریفک Tailscale کے ذریعے روٹ کی جاتی ہے۔';

  @override
  String get serversTailscaleUnsupported => 'Tailscale تعاون یافتہ نہیں';

  @override
  String get serversUnhealthyActivateError =>
      'یہ سرور غیر صحت مند ہے۔ فعال کرنے سے پہلے صحت چیک کریں یا ترتیبات میں ترمیم کریں۔';

  @override
  String get sessionActionArchived => 'محفوظ شدہ';

  @override
  String get sessionActionDeleted => 'حذف کر دیا گیا';

  @override
  String get sessionActionForked => 'کانٹے دار';

  @override
  String get sessionActionPinned => 'پن شدہ';

  @override
  String get sessionActionUnarchived => 'غیر محفوظ شدہ';

  @override
  String get sessionActionUnpinned => 'پن سے ہٹایا گیا';

  @override
  String get sessionArchive => 'آرکائیو کریں';

  @override
  String get sessionCancelRename => 'نام تبدیل کرنا منسوخ کریں۔';

  @override
  String sessionChildrenCount(int count) {
    return 'ذیلی گفتگو: $count';
  }

  @override
  String get sessionCompactContext => 'سیاق و سباق کمپیکٹ کریں';

  @override
  String get sessionCopyLink => 'لنک کاپی کریں';

  @override
  String get sessionDelete => 'حذف کریں۔';

  @override
  String sessionDeleteConfirm(String title) {
    return 'کیا آپ واقعی گفتگو \"$title\" حذف کرنا چاہتے ہیں؟ یہ عمل واپس نہیں کیا جا سکتا۔';
  }

  @override
  String get sessionDeleteTitle => 'گفتگو کو حذف کریں۔';

  @override
  String get sessionDiffChangedFile => 'فائل تبدیل کر دی گئی۔';

  @override
  String get sessionDiffContentNotCaptured =>
      'فائل کا مواد سرور کے ذریعے حاصل نہیں کیا گیا ہے۔';

  @override
  String sessionDiffFilesChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فائلیں تبدیل ہوئیں',
      one: '1 فائل تبدیل ہوئی',
    );
    return '$_temp0';
  }

  @override
  String sessionDiffFilesCount(int count) {
    return 'Diff فائلیں: $count';
  }

  @override
  String sessionDiffLinesAddedRemoved(int added, int removed) {
    return '+ $added لائنیں شامل کی گئیں - $removed لائنیں ہٹا دی گئیں۔';
  }

  @override
  String sessionDiffLinesCollapsed(int count) {
    return '$count لائنیں سمٹ گئیں — پھیلانے کے لیے تھپتھپائیں۔';
  }

  @override
  String get sessionDiffLoading => 'Loading changed files…';

  @override
  String get sessionDiffReview => 'تبدیلیوں کا جائزہ لیں۔';

  @override
  String get sessionDiffSplit => 'تقسیم';

  @override
  String get sessionDiffSummary => 'خلاصہ';

  @override
  String get sessionDiffUnified => 'متحد';

  @override
  String get sessionExportAssistant => 'اسسٹنٹ';

  @override
  String get sessionExportCanceled => 'برآمد منسوخ کر دی گئی';

  @override
  String get sessionExportDebugJson => 'ڈیبگ JSON برآمد کریں';

  @override
  String get sessionExportDebugJsonErrorClipboard =>
      'فائل محفوظ نہیں ہو سکی؛ ڈیبگ JSON کلپ بورڈ پر کاپی کر دیا گیا';

  @override
  String get sessionExportDebugJsonSaved => 'ڈیبگ JSON برآمد محفوظ ہو گئی';

  @override
  String get sessionExportDebugJsonTitle =>
      'سیشن کو ڈیبگ JSON کے طور پر برآمد کریں';

  @override
  String get sessionExportError => 'خرابی:';

  @override
  String get sessionExportInput => 'ان پٹ:';

  @override
  String get sessionExportMarkdown => 'Markdown برآمد کریں';

  @override
  String get sessionExportMarkdownErrorClipboard =>
      'فائل محفوظ نہیں ہو سکی؛ Markdown کلپ بورڈ پر کاپی کر دیا گیا';

  @override
  String get sessionExportMarkdownSaved => 'Markdown برآمد محفوظ ہو گئی';

  @override
  String get sessionExportMarkdownTitle =>
      'سیشن کو Markdown کے طور پر برآمد کریں';

  @override
  String get sessionExportOutput => 'آؤٹ پٹ:';

  @override
  String get sessionExportUntitled => 'بغیر عنوان والا سیشن';

  @override
  String get sessionExportUser => 'صارف';

  @override
  String get sessionFailedRename => 'گفتگو کا نام تبدیل کرنے میں ناکام';

  @override
  String get sessionFailedUpdateArchive =>
      'محفوظ شدہ دستاویزات کی حالت کو اپ ڈیٹ کرنے میں ناکام';

  @override
  String get sessionFailedUpdateSharing =>
      'اشتراک کی حالت کو اپ ڈیٹ کرنے میں ناکام';

  @override
  String get sessionFork => 'کانٹا';

  @override
  String get sessionForkFailed => 'گفتگو کا فورک ناکام ہوا';

  @override
  String get sessionForked => 'گفتگو فورک ہو گئی';

  @override
  String sessionHasError(String title) {
    return '\"$title\" میں خرابی ہے۔';
  }

  @override
  String sessionHasNewReply(String title) {
    return '\"$title\" میں نیا جواب ہے۔';
  }

  @override
  String get sessionKeyboardShortcuts => 'کی بورڈ شارٹ کٹس';

  @override
  String sessionNeedsInput(String title) {
    return '\"$title\" کو آپ کے ان پٹ کی ضرورت ہے۔';
  }

  @override
  String get sessionNoCachedConversations =>
      'ابھی تک کوئی محفوظ کردہ گفتگو نہیں';

  @override
  String get sessionNoConversationsInProject =>
      'اس پروجیکٹ میں کوئی گفتگو نہیں۔';

  @override
  String get sessionNotAvailable =>
      'اس پروجیکٹ کے لیے ابھی تک بات چیت دستیاب نہیں ہے۔';

  @override
  String get sessionOpenProjectToLoad =>
      'گفتگو لوڈ کرنے کے لیے پروجیکٹ کھولیں۔';

  @override
  String get sessionPin => 'پن کریں';

  @override
  String get sessionRename => 'نام تبدیل کریں۔';

  @override
  String get sessionRenameHint => 'گفتگو کا نیا نام درج کریں۔';

  @override
  String get sessionRenameTitle => 'بات چیت کا نام تبدیل کریں۔';

  @override
  String get sessionSaveTitle => 'عنوان محفوظ کریں۔';

  @override
  String get sessionShare => 'سیشن شیئر کریں';

  @override
  String get sessionShareAction => 'شیئر کریں';

  @override
  String get sessionShareLinkCopied => 'اشتراک کا لنک کاپی ہو گیا۔';

  @override
  String get sessionShareLinkUnavailable => 'اس سیشن کے لیے لنک دستیاب نہیں';

  @override
  String get sessionShared => 'گفتگو مشترکہ ہو گئی';

  @override
  String get sessionSyncing => 'گفتگو ہم آہنگ ہو رہی ہے...';

  @override
  String get sessionTitleHint => 'گفتگو کا عنوان';

  @override
  String get sessionUnarchive => 'آرکائیو سے نکالیں';

  @override
  String get sessionUnpin => 'ان پن کریں';

  @override
  String get sessionUnshare => 'شیئرنگ ختم کریں';

  @override
  String get sessionUnshareAction => 'شیئرنگ بند کریں';

  @override
  String get sessionUnshared => 'گفتگو غیر مشترکہ ہو گئی';

  @override
  String get sessionViewTasks => 'کام دیکھیں';

  @override
  String get settingsAboutCheckForUpdates => 'اپ ڈیٹس کے لیے چیک کریں۔';

  @override
  String get settingsAboutCheckOnOpen => 'اوپن پر اپ ڈیٹس کی جانچ کریں۔';

  @override
  String get settingsAboutCheckOnOpenDescription =>
      'ایپ کب شروع ہوتی ہے خود بخود چیک کریں۔';

  @override
  String get settingsAboutChecking => 'چیک کر رہا ہے...';

  @override
  String get settingsAboutDescription => 'ورژن، اپ ڈیٹس، مدد اور ایپ کا ڈیٹا';

  @override
  String get settingsAboutDismiss => 'برطرف کرنا';

  @override
  String settingsAboutDownloading(String percent) {
    return 'ڈاؤن لوڈ ہو رہا ہے... $percent %';
  }

  @override
  String get settingsAboutEraseAllData =>
      'تمام ڈیٹا مٹائیں اور دوبارہ شروع کریں۔';

  @override
  String get settingsAboutInstallUpdate => 'اپ ڈیٹ انسٹال کریں۔';

  @override
  String get settingsAboutInstalling => 'انسٹال ہو رہا ہے...';

  @override
  String settingsAboutLatestVersion(String version) {
    return 'v $version تازہ ترین ورژن ہے۔';
  }

  @override
  String get settingsAboutLoading => 'لوڈ ہو رہا ہے...';

  @override
  String get settingsAboutReplayChatTour => 'چیٹ ٹور کو دوبارہ چلائیں۔';

  @override
  String get settingsAboutReplayChatTourDescription =>
      'سیٹنگز بند کریں اور گائیڈڈ چیٹ واک تھرو دکھائیں۔';

  @override
  String get settingsAboutResetApp => 'ایپ کو ری سیٹ کریں۔';

  @override
  String get settingsAboutResetAppQuestion => 'ایپ کو ری سیٹ کریں؟';

  @override
  String get settingsAboutResetAppWarning =>
      'یہ تمام سرورز، سیٹنگز اور کیشڈ ڈیٹا کو مٹا دے گا۔ اس کارروائی کو کالعدم نہیں کیا جا سکتا۔';

  @override
  String get settingsAboutRetryInstall => 'دوبارہ انسٹال کرنے کی کوشش کریں۔';

  @override
  String get settingsAboutTapToCheck => 'نئے ورژن چیک کرنے کے لیے تھپتھپائیں۔';

  @override
  String get settingsAboutTitle => 'کے بارے میں';

  @override
  String get settingsAboutUpToDate => 'آپ اپ ٹو ڈیٹ ہیں۔';

  @override
  String settingsAboutUpdateAvailable(String version) {
    return 'اپ ڈیٹ دستیاب ہے: v $version';
  }

  @override
  String get settingsAboutUpdateInstalled =>
      'اپ ڈیٹ انسٹال ہو گیا۔ درخواست دینے کے لیے ایپ کو دوبارہ شروع کریں۔';

  @override
  String settingsAboutUpdateVersionSummary(
    String installedVersion,
    String latestVersion,
  ) {
    return 'موجودہ: $installedVersion؛ دستیاب: v$latestVersion';
  }

  @override
  String get settingsAboutVersion => 'ورژن';

  @override
  String settingsAboutVersionBuild(String buildNumber, String version) {
    return '$version (تعمیر $buildNumber )';
  }

  @override
  String get settingsAppearanceAmoledDark => 'AMOLED ڈارک موڈ';

  @override
  String get settingsAppearanceAmoledDarkActive =>
      'سیاہ موڈ فعال ہونے کے دوران خالص سیاہ سطحوں کا استعمال کریں۔';

  @override
  String get settingsAppearanceAmoledDarkInactive =>
      'AMOLED سطحوں کو فعال کرنے کے لیے ڈارک موڈ پر سوئچ کریں۔';

  @override
  String get settingsAppearanceBrandColor => 'برانڈ کا رنگ';

  @override
  String get settingsAppearanceBrandColorDynamicBlocked =>
      'برانڈ کا رنگ منتخب کرنے کے لیے وال پیپر کے رنگوں کو غیر فعال کریں۔';

  @override
  String get settingsAppearanceBrandColorNormal =>
      'ایپ پیلیٹ کے لیے بیج کا رنگ چنیں۔';

  @override
  String get settingsAppearanceBrandColorPresetBlocked =>
      'برانڈ کا رنگ منتخب کرنے کے لیے CodeWalk Classic پر جائیں۔';

  @override
  String get settingsAppearanceChatFontScale => 'Conversation text size';

  @override
  String get settingsAppearanceChatFontScaleDescription =>
      'Scale the chat message and composer text on top of the system text size.';

  @override
  String get settingsAppearanceCodeWalkClassic => 'کوڈ واک کلاسک';

  @override
  String get settingsAppearanceComposerTips => 'کمپوزر ٹپس';

  @override
  String get settingsAppearanceComposerTipsDescription =>
      'اسسٹنٹ کے استدلال کے دوران گھومنے والی تجاویز دکھائیں یا چھپائیں۔';

  @override
  String get settingsAppearanceContrast => 'کنٹراسٹ';

  @override
  String get settingsAppearanceContrastDynamicBlocked =>
      'کنٹراسٹ کو ایڈجسٹ کرنے کے لیے وال پیپر کے رنگوں کو غیر فعال کریں۔';

  @override
  String get settingsAppearanceContrastHigh => 'اعلی';

  @override
  String get settingsAppearanceContrastNormal =>
      'رنگ سکیم کے کنٹراسٹ لیول کو ایڈجسٹ کریں۔';

  @override
  String get settingsAppearanceContrastPresetBlocked =>
      'کنٹراسٹ ایڈجسٹ کرنے کے لیے CodeWalk Classic پر جائیں۔';

  @override
  String get settingsAppearanceContrastReduced => 'کم کر دیا';

  @override
  String get settingsAppearanceDark => 'اندھیرا';

  @override
  String get settingsAppearanceDensity => 'کثافت';

  @override
  String get settingsAppearanceDensityDense => 'گھنا';

  @override
  String get settingsAppearanceDensityDescription =>
      'پوری ایپ میں وقفہ کاری اور اجزاء کی کثافت کا اطلاق کریں۔';

  @override
  String get settingsAppearanceDensityExtraDense => 'اضافی گھنے';

  @override
  String get settingsAppearanceDensityExtraSpacious => 'اضافی کشادہ';

  @override
  String get settingsAppearanceDensityNormal => 'نارمل';

  @override
  String get settingsAppearanceDensitySpacious => 'کشادہ';

  @override
  String get settingsAppearanceDescription =>
      'تھیمز، رنگ، متن کا سائز اور چیٹ ڈسپلے منتخب کریں';

  @override
  String get settingsAppearanceFontSize => 'Text size';

  @override
  String get settingsAppearanceFontSizeDescription =>
      'Adjust the size of system text, conversation text, and terminal text.';

  @override
  String get settingsAppearanceLight => 'روشنی';

  @override
  String get settingsAppearanceMathRendering => 'ریاضی رینڈرنگ';

  @override
  String get settingsAppearanceMathRenderingDescription =>
      'چیٹ پیغامات میں LaTeX ریاضی اظہار کو ٹائپ سیٹ مساوات کے طور پر رینڈر کریں۔';

  @override
  String get settingsAppearanceNoPresets => 'کوئی پیش سیٹ پیلیٹس نہیں ملے';

  @override
  String get settingsAppearanceOpenCodePresets => 'اوپن کوڈ پیش سیٹ';

  @override
  String get settingsAppearancePresetHelper =>
      'آفیشل اوپن کوڈ ویب بلٹ ان تھیم لسٹ کا عکس دیتا ہے۔';

  @override
  String get settingsAppearancePresetNote =>
      'تھیم کے رنگ اب آفیشل اوپن کوڈ ویب رجسٹری کی پیروی کرتے ہیں اور مارک ڈاؤن/کوڈ سطحوں کو بھی چلاتے ہیں۔';

  @override
  String get settingsAppearancePresetPalette => 'پیش سیٹ پیلیٹ';

  @override
  String get settingsAppearanceSearchPreset => 'پیش سیٹ پیلیٹ تلاش کریں۔';

  @override
  String get settingsAppearanceSectionDescription =>
      'اپنے ورک فلو کے لیے بصری کثافت اور پیغام کی سطحوں کو ٹیون کریں۔';

  @override
  String get settingsAppearanceSectionTitle => 'ظاہری شکل';

  @override
  String get settingsAppearanceSystem => 'سسٹم';

  @override
  String get settingsAppearanceSystemFontScale => 'System text size';

  @override
  String get settingsAppearanceSystemFontScaleDescription =>
      'Scale all text in the app shell, including menus, dialogs, and sidebars.';

  @override
  String get settingsAppearanceTaskList => 'ٹاسک لسٹ';

  @override
  String get settingsAppearanceTaskListDescription =>
      'سیشن ٹاسک لسٹ ویجیٹ دکھائیں یا چھپائیں۔';

  @override
  String get settingsAppearanceTerminalFontSize => 'Terminal text size';

  @override
  String get settingsAppearanceTerminalFontSizeDescription =>
      'Resize the embedded terminal font. Applies immediately to running sessions.';

  @override
  String get settingsAppearanceTheme => 'تھیم';

  @override
  String get settingsAppearanceThemeDescription =>
      'لائٹ، ڈارک، یا سسٹم موڈ کا انتخاب کریں، پھر CodeWalk کلاسک پیلیٹ رکھیں یا اوپن کوڈ پری سیٹ پر سوئچ کریں۔';

  @override
  String get settingsAppearanceVisualStyle => 'بصری انداز';

  @override
  String get settingsAppearanceVisualStyleDescription =>
      'کلاسک شکل یا زیادہ نرم بہتر سطحوں کا انتخاب کریں۔';

  @override
  String get settingsAppearanceVisualStyleClassic => 'کلاسک';

  @override
  String get settingsAppearanceVisualStyleRefined => 'بہتر';

  @override
  String get settingsAppearanceThinkingBubbles => 'سوچنے والے بلبلے۔';

  @override
  String get settingsAppearanceThinkingBubblesDescription =>
      'اسسٹنٹ پیغامات میں ریجننگ بلاکس دکھائیں یا چھپائیں۔';

  @override
  String get settingsAppearanceTitle => 'ظاہری شکل';

  @override
  String get settingsAppearanceToolCallBubbles => 'ٹول کال بلبلے۔';

  @override
  String get settingsAppearanceToolCallBubblesDescription =>
      'معاون پیغامات میں ٹول ایگزیکیوشن کارڈز دکھائیں یا چھپائیں۔';

  @override
  String get settingsAppearanceWallpaperColors =>
      'وال پیپر کے رنگ استعمال کریں۔';

  @override
  String get settingsAppearanceWallpaperNormal =>
      'اپنے آلے کے وال پیپر سے رنگ سکیم نکالیں۔';

  @override
  String get settingsAppearanceWallpaperPresetBlocked =>
      'وال پیپر کے رنگ استعمال کرنے کے لیے CodeWalk Classic پر جائیں۔';

  @override
  String get settingsAppearanceWindowChrome => 'ونڈو ٹیبز';

  @override
  String get settingsAppearanceWindowChromeDescription =>
      'منتخب کریں کہ ڈیسک ٹاپ پر سیشن ٹیبز اور ٹائٹل بار کیسے یکجا ہوں۔';

  @override
  String get settingsAppearanceWindowChromeIntegrated => 'مربوط ٹیبز';

  @override
  String get settingsAppearanceWindowChromeIntegratedDescription =>
      'ٹیبز ونڈو کے اوپر ہوتے ہیں اور سسٹم ٹائٹل بار چھپ جاتا ہے۔';

  @override
  String get settingsAppearanceWindowChromeSystem => 'سسٹم سجاوٹ';

  @override
  String get settingsAppearanceWindowChromeSystemDescription =>
      'مقامی ٹائٹل بار برقرار رکھتا ہے اور ٹیبز کو ایپ بار کے نیچے دکھاتا ہے۔';

  @override
  String get settingsBack => 'پیچھے';

  @override
  String get settingsBehaviorAutoupdateCaveat =>
      'CodeWalk ریلیز چیک کے لیے About استعمال کریں۔ یہ ترتیب صرف آفیشل اوپن کوڈ `آٹو اپ ڈیٹ` کنفیگریشن کی آئینہ دار ہے۔';

  @override
  String get settingsBehaviorAutoupdateHelp =>
      'اپ اسٹریم اوپن کوڈ رن ٹائم اپ ڈیٹس کو کنٹرول کرتا ہے، کوڈ واک ایپ اپ ڈیٹ چیک کو نہیں۔';

  @override
  String get settingsBehaviorCellularDataSaver => 'سیلولر ڈیٹا سیور';

  @override
  String get settingsBehaviorChatRenderMode => 'Chat render mode';

  @override
  String get settingsBehaviorChatRenderModeBlock => 'Block';

  @override
  String get settingsBehaviorChatRenderModeBlockDescription =>
      'Hide live assistant text, reasoning, and tool cards until the current turn can be shown as one block.';

  @override
  String get settingsBehaviorChatRenderModeDescription =>
      'Choose whether assistant responses appear as they stream or reveal after the current turn settles.';

  @override
  String get settingsBehaviorChatRenderModeLive => 'Live';

  @override
  String get settingsBehaviorChatRenderModeLiveDescription =>
      'Show assistant text, reasoning, and tool activity as OpenCode streams events.';

  @override
  String get settingsBehaviorComposerSpellCheck => 'Composer spell check';

  @override
  String get settingsBehaviorComposerSpellCheckDescription =>
      'Use native platform spell check, suggestions, and autocorrect in the chat composer.';

  @override
  String get settingsBehaviorConfigDeferred =>
      'CodeWalk موجودہ جواب کے ختم ہونے کے بعد اس OpenCode ترتیب کو لاگو کرے گا۔';

  @override
  String settingsBehaviorConfigUpdateFailed(String field) {
    return 'اوپن کوڈ $field کو اپ ڈیٹ نہیں کیا جا سکا۔';
  }

  @override
  String get settingsBehaviorConversationUsername => 'گفتگو کا صارف نام';

  @override
  String get settingsBehaviorConversationUsernameHelp =>
      'سسٹم کے صارف نام کے بجائے گفتگو میں دکھایا گیا حسب ضرورت ڈسپلے نام۔';

  @override
  String get settingsBehaviorDataSaverActive => 'اب موبائل ڈیٹا پر فعال ہے۔';

  @override
  String get settingsBehaviorDataSaverCellularOnly =>
      'صرف اس وقت لاگو ہوتا ہے جب کنکشن سیلولر/موبائل ہو۔';

  @override
  String get settingsBehaviorDataSaverDescription =>
      'پس منظر کے ڈاؤن لوڈز کو روک کر اور خودکار پیش منظر کی تازہ کاری کو تھروٹلنگ کرکے خودکار موبائل ڈیٹا کے استعمال کو کم کرتا ہے۔';

  @override
  String get settingsBehaviorDataSaverWaiting =>
      'اگلی موبائل ڈیٹا سنک ونڈو کا انتظار ہے۔';

  @override
  String get settingsBehaviorDefaultAgent => 'پہلے سے طے شدہ ایجنٹ';

  @override
  String get settingsBehaviorDefaultAgentHelp =>
      'پرائمری ایجنٹ استعمال کیا جاتا ہے جب کوئی ایجنٹ واضح طور پر منتخب نہیں کیا جاتا ہے۔';

  @override
  String get settingsBehaviorDefaultModel => 'پہلے سے طے شدہ ماڈل';

  @override
  String get settingsBehaviorDefaultModelHelp =>
      'تشکیل کے ذریعے اوپن کوڈ کلائنٹس میں اشتراک کیا گیا۔';

  @override
  String get settingsBehaviorDescription =>
      'زبان، چیٹ رویے، ڈیٹا کے استعمال اور OpenCode ڈیفالٹس کو کنٹرول کریں';

  @override
  String get settingsBehaviorEnableDataSaver =>
      'سیلولر ڈیٹا سیور کو فعال کریں۔';

  @override
  String get settingsBehaviorMultiDeviceSync =>
      'تجرباتی ملٹی ڈیوائس مطابقت پذیری کو فعال کریں۔';

  @override
  String get settingsBehaviorMultiDeviceSyncDescription =>
      'ایکٹو سرور کنفیگریشن کے ساتھ کمپوزر سلیکشن (ایجنٹ/ماڈل/ویرینٹ) کو سنک کریں۔';

  @override
  String get settingsBehaviorMultiDeviceSyncWarning =>
      'ایک ہی وقت میں ایک سے زیادہ سیشن میں کام کرتے وقت جاری سیشنز کو روک سکتا ہے۔';

  @override
  String get settingsBehaviorNoAgents => 'کوئی ایجنٹ نہیں ملا';

  @override
  String get settingsBehaviorNoModels => 'کوئی ماڈل نہیں ملا';

  @override
  String get settingsBehaviorOpenCodeAutoupdate => 'اوپن کوڈ آٹو اپ ڈیٹ';

  @override
  String get settingsBehaviorOpenCodeDefaults =>
      'اوپن کوڈ کی حمایت یافتہ ڈیفالٹس';

  @override
  String get settingsBehaviorOpenCodeDefaultsDescription =>
      'یہ قدریں فعال سرور پر `/config` پر لکھتی ہیں اور آفیشل اوپن کوڈ کی مشترکہ تشکیل سے ملتی ہیں۔';

  @override
  String get settingsBehaviorOpenCodeSnapshots => 'اوپن کوڈ سنیپ شاٹس';

  @override
  String get settingsBehaviorOpenCodeSnapshotsDescription =>
      'اپ اسٹریم گٹ بیکڈ سنیپ شاٹس کو کالعدم/دوبارہ کرنے اور بازیافت کی تاریخ کے لیے فعال رکھیں۔';

  @override
  String get settingsBehaviorPermissionDeferred =>
      'اعلی درجے کی اجازت کے اصول میں ترمیم ابھی کے لیے ترتیبات سے باہر رہتی ہے اور بعد میں برابری کے کام کے لیے موخر کر دی جاتی ہے۔';

  @override
  String get settingsBehaviorPermissionProvenance => 'اجازت ہینڈلنگ پروونانس';

  @override
  String get settingsBehaviorPermissionProvenanceDescription =>
      'آفیشل اوپن کوڈ کی اجازت کی پالیسی کو `opencode.json` میں اجازت/پوچھیں/منکر کے اصولوں کے ساتھ ترتیب دیا گیا ہے۔ CodeWalk سرکاری اجازت کی درخواست کے کارڈز کو رکھتا ہے اور ایک منظور شدہ ADR-023 استثناء شامل کرتا ہے: کمپوزر آٹو-منظوری ٹوگل جوابات کو \'ہمیشہ\' اور \'یاد رکھیں: سچ\' کے ساتھ غیر مشروط طور پر پائیدار سیشن کے دائرہ کار والے گرانٹس کو تخلیق کرتا ہے، اور بیک گراؤنڈ ورک کے اسی تھریڈ اسکوپڈ کنٹیوٹی پاتھ کو فعال رکھتا ہے۔';

  @override
  String get settingsBehaviorRefreshDefaults => 'ڈیفالٹس ریفریش کریں۔';

  @override
  String get settingsBehaviorSaveUsername => 'صارف نام محفوظ کریں۔';

  @override
  String get settingsBehaviorSearchAutoupdate => 'خودکار اپ ڈیٹ موڈ تلاش کریں۔';

  @override
  String get settingsBehaviorSearchDefaultAgent => 'ڈیفالٹ ایجنٹ تلاش کریں۔';

  @override
  String get settingsBehaviorSearchDefaultModel => 'ڈیفالٹ ماڈل تلاش کریں۔';

  @override
  String get settingsBehaviorSearchShareMode => 'شیئرنگ موڈ تلاش کریں۔';

  @override
  String get settingsBehaviorSearchSmallModel => 'چھوٹا ماڈل تلاش کریں۔';

  @override
  String get settingsBehaviorShareMode => 'اوپن کوڈ شیئرنگ ڈیفالٹ';

  @override
  String get settingsBehaviorShareModeCaveat =>
      'ابھی ایک سیشن شائع کرنے کے لیے چیٹ لیول شیئر ایکشن کا استعمال کریں۔ یہ ترتیب صرف OpenCode کی ڈیفالٹ شیئرنگ پالیسی کو تبدیل کرتی ہے۔';

  @override
  String get settingsBehaviorShareModeHelp =>
      'آفیشل عالمی `شیئر` کنفیگریشن کو کنٹرول کرتا ہے، انفرادی چیٹ کے لیے شیئر بٹن کو نہیں۔';

  @override
  String get settingsBehaviorSmallModel => 'چھوٹا ماڈل';

  @override
  String get settingsBehaviorSmallModelAutoFallback => 'خودکار فال بیک';

  @override
  String get settingsBehaviorSmallModelFallbackActive =>
      'OpenCode خودکار فال بیک فعال ہے کیونکہ `small_model` سیٹ نہیں ہے۔';

  @override
  String get settingsBehaviorSmallModelHelp =>
      'ٹائٹل جنریشن جیسے ہلکے وزن کے کاموں کے لیے استعمال کیا جاتا ہے۔';

  @override
  String get settingsBehaviorSmallModelResetCaveat =>
      '`small_model` کو دوبارہ خودکار فال بیک پر دوبارہ ترتیب دینے کے لیے ابھی بھی ایپ سے باہر کنفیگریشن میں ترمیم کی ضرورت ہے کیونکہ `/config` پیچ اپ ڈیٹ کلیدوں کو نہیں ہٹا سکتے ہیں۔';

  @override
  String get settingsBehaviorSnapshotCaveat =>
      'یہ اوپن کوڈ اسنیپ شاٹ سٹوریج کو کنٹرول کرتا ہے اور سپورٹ کو کالعدم/دوبارہ کرنا، نہ کہ CodeWalk مقامی کیش اسنیپ شاٹس کو۔';

  @override
  String get settingsBehaviorTitle => 'رویہ';

  @override
  String get settingsBehaviorUsernameFallback =>
      'OpenCode سسٹم کا صارف نام استعمال کرتا ہے کیونکہ `صارف نام` سیٹ نہیں ہے۔';

  @override
  String get settingsBehaviorUsernamePatchCaveat =>
      '\'صارف نام\' کو سسٹم ڈیفالٹ پر دوبارہ ترتیب دینے کے لیے اب بھی ایپ سے باہر کنفیگریشن میں ترمیم کی ضرورت ہوتی ہے کیونکہ `/config` پیچ اپ ڈیٹ کلیدوں کو نہیں ہٹا سکتے ہیں۔';

  @override
  String get settingsConfigRefreshFailed =>
      'سرور کی ترتیب کو اپ ڈیٹ کیا، لیکن چیٹ فراہم کرنے والوں کو ریفریش نہیں کیا جا سکا۔';

  @override
  String get settingsConfigUpdateDeferred =>
      'CodeWalk موجودہ جواب کے ختم ہونے کے بعد اس OpenCode ترتیب کو لاگو کرے گا۔';

  @override
  String get settingsConversationUsername => 'گفتگو کا صارف نام';

  @override
  String get settingsDefaultAgent => 'ڈیفالٹ ایجنٹ';

  @override
  String get settingsDefaultModel => 'ڈیفالٹ ماڈل';

  @override
  String get settingsLanguageDescription =>
      'CodeWalk کے ذریعے استعمال ہونے والی زبان کا انتخاب کریں۔ سسٹم ڈیفالٹ آپ کے آلے کی زبان کی پیروی کرتا ہے۔';

  @override
  String get settingsLanguageEmptyText => 'کوئی زبانیں نہیں ملی';

  @override
  String get settingsLanguageFieldHelper =>
      'فوری طور پر لاگو ہوتا ہے اور دوبارہ شروع ہونے پر برقرار رہتا ہے۔';

  @override
  String get settingsLanguageFieldLabel => 'ایپ کی زبان';

  @override
  String get settingsLanguageSearchHint => 'زبانیں تلاش کریں۔';

  @override
  String get settingsLanguageSystemDefault => 'سسٹم ڈیفالٹ';

  @override
  String get settingsLanguageTitle => 'زبان';

  @override
  String get settingsLogsDescription =>
      'ایپ کی تشخیصات اور خرابیوں کے حل کی تفصیلات دیکھیں';

  @override
  String get settingsLogsTitle => 'Registros';

  @override
  String get settingsNoAgentsFound => 'کوئی ایجنٹ نہیں ملا';

  @override
  String get settingsNotificationsAgentSubtitle => 'جب جواب ختم ہوتا ہے۔';

  @override
  String get settingsNotificationsAgentUpdates => 'ایجنٹ کی تازہ کاری';

  @override
  String get settingsNotificationsAnotherConversation => 'ایک اور گفتگو';

  @override
  String get settingsNotificationsAppInBackground => 'پس منظر میں ایپ';

  @override
  String get settingsNotificationsBackgroundAlerts =>
      'Android پس منظر کے انتباہات';

  @override
  String get settingsNotificationsBackgroundBehavior => 'پس منظر کا رویہ';

  @override
  String get settingsNotificationsBackgroundBehaviorDescription =>
      'منتخب کریں کہ ایپ کے پیش منظر سے نکلنے کے بعد CodeWalk کیسا برتاؤ کرتا ہے۔';

  @override
  String get settingsNotificationsBackgroundDescription =>
      'جب ایپ اسکرین پر نہ ہو تو جواب کی تکمیل، اجازت کی درخواستوں، سوالات اور غلطیوں کے لیے کم ڈیٹا والے پس منظر کی نگرانی کا استعمال کریں۔';

  @override
  String get settingsNotificationsBackgroundToggle =>
      'اینڈرائیڈ پر بیک گراؤنڈ الرٹس';

  @override
  String get settingsNotificationsBackgroundToggleDescription =>
      'تمام اینڈرائیڈ بیک گراؤنڈ چیک کو آف کریں اور مسلسل مانیٹر کی اطلاع کو چھپائیں۔';

  @override
  String get settingsNotificationsBatteryDescription =>
      'اگر اطلاعات صرف ایپ کو دوبارہ کھولنے پر پہنچتی ہیں، تو CodeWalk کو اس ڈیوائس پر آپٹیمائزیشن کے بغیر چلنے دیں۔';

  @override
  String get settingsNotificationsBatteryDisabled =>
      'کوڈ واک کے لیے بیٹری کی اصلاح کو غیر فعال کر دیا گیا ہے۔';

  @override
  String get settingsNotificationsBatteryEnabled =>
      'بیٹری آپٹیمائزیشن فعال ہے۔ کچھ آلات پس منظر کے انتباہات میں تاخیر کر سکتے ہیں۔';

  @override
  String get settingsNotificationsBatteryOptimization =>
      'اینڈرائیڈ بیٹری آپٹیمائزیشن';

  @override
  String get settingsNotificationsBatteryUnknown =>
      'ابھی تک بیٹری کی اصلاح کی صورتحال کو نہیں پڑھ سکا۔';

  @override
  String get settingsNotificationsChooseAudioFile =>
      'آڈیو فائل کا انتخاب کریں۔';

  @override
  String get settingsNotificationsChooseSystemSound =>
      'سسٹم ساؤنڈ کا انتخاب کریں۔';

  @override
  String get settingsNotificationsCloseToTray => 'ٹرے کے قریب';

  @override
  String get settingsNotificationsCloseToTrayDescription =>
      'ونڈو کو چھپائیں اور سسٹم ٹرے میں چلتے رہیں۔';

  @override
  String get settingsNotificationsDescription =>
      'منتخب کریں کہ کون سے واقعات آپ کو آگاہ کریں اور کیسے';

  @override
  String get settingsNotificationsDisableOptimization =>
      'اصلاح کو غیر فعال کریں۔';

  @override
  String get settingsNotificationsErrors => 'غلطیاں';

  @override
  String get settingsNotificationsErrorsSubtitle =>
      'جب کوئی سیشن ناکامی کی اطلاع دیتا ہے۔';

  @override
  String get settingsNotificationsJustClose => 'بس بند کرو';

  @override
  String get settingsNotificationsJustCloseDescription =>
      'ایپلیکیشن سے مکمل طور پر باہر نکلیں۔';

  @override
  String get settingsNotificationsKeepLive => 'الرٹس کو 3 منٹ تک لائیو رکھیں';

  @override
  String get settingsNotificationsKeepLiveDescription =>
      'جب کوئی جواب پہلے سے چل رہا ہو، تو ایپ چھوڑنے کے بعد مختصر وقت کے لیے ریئل ٹائم کو فعال رکھیں۔';

  @override
  String get settingsNotificationsLocal => 'مقامی';

  @override
  String get settingsNotificationsMinimizeWhenClose =>
      'بند ہونے پر کم سے کم کریں۔';

  @override
  String get settingsNotificationsMinimizeWhenCloseDescription =>
      'ٹاسک بار/ڈاک کو کم سے کم کریں اور چلتے رہیں۔';

  @override
  String get settingsNotificationsNoCondition =>
      'اگر کوئی شرط منتخب نہیں کی جاتی ہے، تو کسی بھی تناظر میں الرٹس کی اجازت ہے۔';

  @override
  String get settingsNotificationsNotify => 'اطلاع دیں۔';

  @override
  String get settingsNotificationsNotifyOnlyWhen => 'صرف اس وقت اطلاع دیں۔';

  @override
  String get settingsNotificationsOpenBatterySettings =>
      'بیٹری کی ترتیبات کھولیں۔';

  @override
  String get settingsNotificationsPermissions => 'اجازتیں اور سوالات';

  @override
  String get settingsNotificationsPermissionsSubtitle =>
      'جب ٹولز آپ کے ان پٹ کی درخواست کرتے ہیں۔';

  @override
  String get settingsNotificationsPreview => 'پیش نظارہ';

  @override
  String get settingsNotificationsRefreshStatus => 'حالت تازہ کریں۔';

  @override
  String get settingsNotificationsSearchSoundType => 'آواز کی قسم تلاش کریں۔';

  @override
  String get settingsNotificationsSectionDescription =>
      'کنٹرول کریں کہ انتباہات کب ظاہر ہوتے ہیں اور کب وہ آواز چلا سکتے ہیں۔';

  @override
  String get settingsNotificationsSectionTitle => 'اطلاعات';

  @override
  String settingsNotificationsSelectedSound(String label) {
    return 'منتخب کردہ: $label';
  }

  @override
  String get settingsNotificationsServer => 'سرور';

  @override
  String get settingsNotificationsSound => 'آواز';

  @override
  String get settingsNotificationsSoundBuiltInAlert => 'بلٹ ان الرٹ';

  @override
  String get settingsNotificationsSoundBuiltInClick => 'بلٹ ان کلک';

  @override
  String get settingsNotificationsSoundOff => 'بند';

  @override
  String get settingsNotificationsSoundOnlyWhen => 'آواز صرف اس وقت';

  @override
  String get settingsNotificationsSoundPickAudioFile => 'آڈیو فائل منتخب کریں';

  @override
  String get settingsNotificationsSoundPickFromSystem => 'سسٹم سے منتخب کریں';

  @override
  String get settingsNotificationsSoundSystemDefault => 'سسٹم ڈیفالٹ';

  @override
  String get settingsNotificationsSoundType => 'آواز کی قسم';

  @override
  String get settingsNotificationsSyncInfo =>
      'کچھ زمرہ آن/آف ٹوگلز کو فعال سرور پر /config سے ہم آہنگ کیا جاتا ہے۔';

  @override
  String get settingsNotificationsSyncInfoLocal =>
      'موجودہ سرور /config میں نوٹیفکیشن ٹوگلز کو ظاہر نہیں کرتا ہے۔ مقامی اقدار فعال ہیں۔';

  @override
  String get settingsNotificationsSystemSoundPickerTitle =>
      'سسٹم ساؤنڈ کا انتخاب کریں۔';

  @override
  String get settingsNotificationsTitle => 'اطلاعات';

  @override
  String get settingsNotificationsWhenClosing => 'کھڑکی بند کرتے وقت';

  @override
  String get settingsOpenCodeAutoUpdate => 'OpenCode خودکار اپ ڈیٹ';

  @override
  String get settingsOpenCodeSharingDefault => 'OpenCode شیئرنگ ڈیفالٹ';

  @override
  String get settingsReadAloudEnabled => 'بلند آواز سے پڑھیں';

  @override
  String get settingsReadAloudEnabledDescription =>
      'معاون پیغامات پر بلند آواز میں پڑھنے کا بٹن دکھائیں۔';

  @override
  String get settingsReadAloudPitch => 'پچ';

  @override
  String get settingsReadAloudPitchDescription => 'آواز کی پچ کو ایڈجسٹ کریں۔';

  @override
  String get settingsReadAloudSectionDescription =>
      'معاون جوابات کو بلند آواز سے پڑھیں۔ رفتار، پچ اور آواز کو ترتیب دیں۔';

  @override
  String get settingsReadAloudSectionTitle => 'متن سے تقریر';

  @override
  String get settingsReadAloudSpeed => 'رفتار';

  @override
  String get settingsReadAloudSpeedDescription =>
      'بولنے کی شرح کو ایڈجسٹ کریں۔';

  @override
  String get settingsReadAloudVoice => 'آواز';

  @override
  String get settingsReadAloudVoiceHint =>
      'بلند آواز سے پڑھنے کے لیے آواز منتخب کریں۔';

  @override
  String get settingsSearchAutoUpdateMode => 'خودکار اپ ڈیٹ موڈ تلاش کریں';

  @override
  String get settingsSearchDefaultAgent => 'ڈیفالٹ ایجنٹ تلاش کریں';

  @override
  String get settingsSearchDefaultModel => 'ڈیفالٹ ماڈل تلاش کریں';

  @override
  String get settingsSearchSharingMode => 'شیئرنگ موڈ تلاش کریں';

  @override
  String get settingsSearchSmallModel => 'چھوٹا ماڈل تلاش کریں';

  @override
  String get settingsServersActive => 'فعال';

  @override
  String get settingsServersChooseActive => 'فعال سرور کا انتخاب کریں۔';

  @override
  String get settingsServersDefault => 'طے شدہ';

  @override
  String get settingsServersDescription =>
      'OpenCode سے جڑیں اور اپنے سرورز کا نظم کریں';

  @override
  String get settingsServersTitle => 'سرورز';

  @override
  String get settingsSessionAttentionSize => 'ببل کا سائز';

  @override
  String get settingsSessionAttentionSizeExtraLarge => 'بہت بڑا';

  @override
  String get settingsSessionAttentionSizeExtraSmall => 'بہت چھوٹا';

  @override
  String get settingsSessionAttentionSizeLarge => 'بڑا';

  @override
  String get settingsSessionAttentionSizeSmall => 'چھوٹا';

  @override
  String get settingsSessionAttentionSizeStandard => 'معیاری';

  @override
  String get settingsSetupWizard => 'سیٹ اپ وزرڈ';

  @override
  String get settingsShortcutsDescription =>
      'کی بورڈ شارٹ کٹس تلاش کریں اور اپنی مرضی کے مطابق بنائیں';

  @override
  String get settingsShortcutsEdit => 'شارٹ کٹ میں ترمیم کریں۔';

  @override
  String get settingsShortcutsKeyboard => 'کی بورڈ شارٹ کٹس';

  @override
  String get settingsShortcutsReset => 'شارٹ کٹ کو دوبارہ ترتیب دیں۔';

  @override
  String get settingsShortcutsSearch => 'شارٹ کٹ تلاش کریں۔';

  @override
  String get settingsShortcutsTitle => 'شارٹ کٹس';

  @override
  String get settingsSmallModel => 'چھوٹا ماڈل';

  @override
  String get settingsSmallModelResetExplanation =>
      '`/config` پیچ اپ ڈیٹس کیز کو حذف نہیں کر سکتے، اس لیے `small_model` کو خودکار فال بیک پر ری سیٹ کرنے کے لیے اب بھی ایپ سے باہر ترتیب میں ترمیم کی ضرورت ہے۔';

  @override
  String get settingsSmallModelUnsetExplanation =>
      'OpenCode خودکار فال بیک فعال ہے کیونکہ `small_model` سیٹ نہیں ہے۔';

  @override
  String get settingsSoundPickerNotAvailable =>
      'سسٹم ساؤنڈ پیکر اس پلیٹ فارم پر دستیاب نہیں ہے۔';

  @override
  String get settingsSpeechDescription =>
      'وائس ان پٹ، آف لائن ماڈلز اور پڑھ کر سنانا سیٹ اپ کریں';

  @override
  String get settingsSpeechRefreshStatus => 'حالت تازہ کریں۔';

  @override
  String settingsSpeechSilenceTimeout(String value) {
    return 'خاموشی کا ٹائم آؤٹ: $value s';
  }

  @override
  String get settingsSpeechTitle => 'متن سے تقریر';

  @override
  String get settingsTitle => 'ترتیبات';

  @override
  String get settingsGroupAlertTypes => 'الرٹ کی اقسام';

  @override
  String get settingsGroupBackgroundBehavior => 'بیک گراؤنڈ رویہ';

  @override
  String get settingsGroupChatDisplay => 'چیٹ ڈسپلے';

  @override
  String get settingsGroupCurrentConnection => 'موجودہ کنکشن';

  @override
  String get settingsGroupDataAndSync => 'ڈیٹا اور سنک';

  @override
  String get settingsGroupDataReset => 'ڈیٹا اور ری سیٹ';

  @override
  String get settingsGroupDelivery => 'ڈیلیوری';

  @override
  String get settingsGroupHelp => 'مدد';

  @override
  String get settingsGroupLanguageAndChat => 'زبان اور چیٹ';

  @override
  String get settingsGroupLayoutAndText => 'لے آؤٹ اور متن';

  @override
  String get settingsGroupOfflineModels => 'آف لائن ماڈلز';

  @override
  String get settingsGroupOpenCodeDefaults => 'OpenCode ڈیفالٹس';

  @override
  String get settingsGroupReadAloud => 'پڑھ کر سنانا';

  @override
  String get settingsGroupSavedServers => 'محفوظ شدہ سرورز';

  @override
  String get settingsGroupThemeAndColor => 'تھیم اور رنگ';

  @override
  String get settingsGroupThisDevice => 'یہ ڈیوائس';

  @override
  String get settingsGroupVersionUpdates => 'ورژن اور اپ ڈیٹس';

  @override
  String get settingsGroupVoiceInput => 'وائس ان پٹ';

  @override
  String get settingsNavigationGroupExperience => 'تجربہ';

  @override
  String get settingsNavigationGroupInput => 'ان پٹ';

  @override
  String get settingsNavigationGroupSetup => 'سیٹ اپ';

  @override
  String get settingsNavigationGroupSupport => 'مدد اور تشخیص';

  @override
  String get settingsNavigationNoResults => 'کوئی سیٹنگز نہیں ملیں';

  @override
  String get settingsNavigationSearchHint => 'سیٹنگز تلاش کریں';

  @override
  String get settingsUsernameClearHint =>
      'اوپن کوڈ گفتگو کے صارف نام کو صاف کرنے کے لیے اب بھی ایپ کے باہر کنفیگریشن میں ترمیم کی ضرورت ہے۔';

  @override
  String get settingsUsernameEnterHint =>
      'اپنی مرضی کے اوپن کوڈ گفتگو کا نام محفوظ کرنے کے لیے صارف نام درج کریں۔';

  @override
  String get settingsUsernameResetExplanation =>
      '`/config` پیچ اپ ڈیٹس کیز کو حذف نہیں کر سکتے، اس لیے `username` کو سسٹم ڈیفالٹ پر ری سیٹ کرنے کے لیے اب بھی ایپ سے باہر ترتیب میں ترمیم کی ضرورت ہے۔';

  @override
  String get settingsUsernameUnsetExplanation =>
      'OpenCode سسٹم کا صارف نام استعمال کرتا ہے کیونکہ `username` سیٹ نہیں ہے۔';

  @override
  String get setupDebugBun => 'بن';

  @override
  String get setupDebugBun2 => 'بن';

  @override
  String get setupDebugCapturedSetupDetails =>
      'ابھی تک کوئی کیپچر سیٹ اپ تفصیلات نہیں ہیں۔';

  @override
  String get setupDebugCapturedSetupLogs => 'کیپچر کردہ سیٹ اپ لاگز';

  @override
  String get setupDebugClear => 'سیٹ اپ ڈیبگ صاف کریں۔';

  @override
  String get setupDebugClearSetupDebug => 'سیٹ اپ ڈیبگ صاف کریں۔';

  @override
  String get setupDebugCodeWalkCaptureEnough =>
      'اگر CodeWalk نے کافی سیاق و سباق کو حاصل نہیں کیا تو، آفیشل اوپن کوڈ لاگز اور ہیلتھ اینڈ پوائنٹس کو براہ راست چیک کریں:';

  @override
  String get setupDebugCommandPath => 'کمانڈ کا راستہ';

  @override
  String get setupDebugCommandPath2 => 'کمانڈ کا راستہ';

  @override
  String get setupDebugCopy => 'سیٹ اپ ڈیبگ کاپی کریں۔';

  @override
  String get setupDebugCopySetupDebug => 'سیٹ اپ ڈیبگ کاپی کریں۔';

  @override
  String get setupDebugCurrentStatus => 'موجودہ حیثیت';

  @override
  String get setupDebugDiagnosticsLoading => 'تشخیص اب بھی لوڈ ہو رہا ہے۔';

  @override
  String get setupDebugEnvironment => 'ماحولیاتی تشخیص';

  @override
  String get setupDebugEnvironmentDiagnostics => 'ماحولیاتی تشخیص';

  @override
  String get setupDebugFocusedOpenCodeSetup =>
      'اوپن کوڈ سیٹ اپ پر فوکس کیا گیا۔';

  @override
  String get setupDebugInstallDir => 'ڈائرکٹری انسٹال کریں۔';

  @override
  String get setupDebugInstallDirectory => 'ڈائرکٹری انسٹال کریں۔';

  @override
  String get setupDebugLatestLocalServer => 'تازہ ترین مقامی سرور آؤٹ پٹ';

  @override
  String get setupDebugLogs => 'کیپچر کردہ سیٹ اپ لاگز';

  @override
  String get setupDebugManual => 'دستی خرابیوں کا سراغ لگانا';

  @override
  String get setupDebugManualTroubleshooting => 'دستی خرابیوں کا سراغ لگانا';

  @override
  String get setupDebugNetwork => 'نیٹ ورک';

  @override
  String get setupDebugNetwork2 => 'نیٹ ورک';

  @override
  String get setupDebugNoDetails =>
      'ابھی تک کوئی کیپچر سیٹ اپ تفصیلات نہیں ہیں۔';

  @override
  String get setupDebugNode => 'Node.js';

  @override
  String get setupDebugNodeJs => 'Node.js';

  @override
  String get setupDebugNpm => 'این پی ایم';

  @override
  String get setupDebugNpm2 => 'این پی ایم';

  @override
  String get setupDebugOpenCode => 'اوپن کوڈ';

  @override
  String get setupDebugOpenCode2 => 'اوپن کوڈ';

  @override
  String get setupDebugOpenCodeSetupDebug => 'اوپن کوڈ سیٹ اپ ڈیبگ';

  @override
  String get setupDebugPlatform => 'پلیٹ فارم';

  @override
  String get setupDebugPlatform2 => 'پلیٹ فارم';

  @override
  String get setupDebugRunDiagnosticsTry =>
      'تشخیص چلائیں، انسٹالیشن کا طریقہ آزمائیں، یا OpenCode کے لیے مخصوص ٹربل شوٹنگ کی تفصیلات کو یہاں حاصل کرنے کے لیے سیٹ اپ فلو کی کوشش کریں۔';

  @override
  String get setupDebugScreenCoversOpenCode =>
      'یہ اسکرین صرف اوپن کوڈ کی تنصیب، تشخیص، اور مقامی سیٹ اپ کی خرابیوں کا سراغ لگاتی ہے۔ عام CodeWalk رن ٹائم مسائل کے لیے App Logs استعمال کریں۔';

  @override
  String get setupDebugServerOutput => 'تازہ ترین مقامی سرور آؤٹ پٹ';

  @override
  String get setupDebugStatus => 'موجودہ حیثیت';

  @override
  String setupDebugTimeEntrySource(String source, String time) {
    return '$time - $source';
  }

  @override
  String get setupDebugTimeline => 'ٹائم لائن';

  @override
  String get setupDebugTimeline2 => 'ٹائم لائن';

  @override
  String get setupDebugTitle => 'اوپن کوڈ سیٹ اپ پر فوکس کیا گیا۔';

  @override
  String get setupDebugWSL => 'ڈبلیو ایس ایل';

  @override
  String get setupDebugWsl => 'ڈبلیو ایس ایل';

  @override
  String get shortcutCloseApp => 'ٹیب/ایپلیکیشن بند کریں';

  @override
  String get shortcutCloseAppDesc =>
      'موجودہ سیشن ٹیب دستیاب ہو تو اسے بند کریں؛ ورنہ پلیٹ فارم کے رویے کے مطابق ایپ بند کریں';

  @override
  String get shortcutFocusCloseDrawer => 'دراز پر توجہ مرکوز کریں/بند کریں';

  @override
  String get shortcutFocusCloseDrawerDesc =>
      'ڈیفالٹ کے طور پر ان پٹ پر توجہ مرکوز کریں، یا دراز کھلا ہونے پر بند کریں';

  @override
  String get shortcutFocusInput => 'ان پٹ پر توجہ مرکوز کریں';

  @override
  String get shortcutFocusInputDesc => 'توجہ کو ٹیکسٹ ان پٹ پر منتقل کریں';

  @override
  String get shortcutGroupApplication => 'ایپلیکیشن';

  @override
  String get shortcutGroupGeneral => 'عمومی';

  @override
  String get shortcutGroupModelAndAgent => 'ماڈل اور ایجنٹ';

  @override
  String get shortcutGroupNavigation => 'نیویگیشن';

  @override
  String get shortcutGroupPrompt => 'پرامپٹ';

  @override
  String get shortcutGroupSession => 'سیشن';

  @override
  String get shortcutNewConversation => 'نئی گفتگو';

  @override
  String get shortcutNewConversationDesc => 'ایک نیا چیٹ سیشن شروع کریں';

  @override
  String get shortcutNextAgent => 'اگلا ایجنٹ';

  @override
  String get shortcutNextAgentDesc => 'اگلے دستیاب ایجنٹ پر جائیں';

  @override
  String get shortcutNextRecentModel => 'اگلا حالیہ ماڈل';

  @override
  String get shortcutNextRecentModelDesc =>
      'حالیہ استعمال شدہ ماڈلز کے درمیان سوئچ کریں';

  @override
  String get shortcutNextVariant => 'اگلی قسم';

  @override
  String get shortcutNextVariantDesc =>
      'دستیاب ماڈل کی اقسام کے درمیان سوئچ کریں';

  @override
  String get shortcutOpenSettings => 'ترتیبات کھولیں';

  @override
  String get shortcutOpenSettingsDesc => 'ترتیبات کا صفحہ کھولیں';

  @override
  String get shortcutPreviousAgent => 'پچھلا ایجنٹ';

  @override
  String get shortcutPreviousAgentDesc => 'پچھلے دستیاب ایجنٹ پر جائیں';

  @override
  String get shortcutQuickOpenFiles => 'فائلیں جلدی کھولیں';

  @override
  String get shortcutQuickOpenFilesDesc => 'فائلوں کی فوری تلاش کھولیں';

  @override
  String get shortcutQuitApp => 'ایپلیکیشن سے باہر نکلیں';

  @override
  String get shortcutQuitAppDesc => 'ایپ سے زبردستی باہر نکلیں';

  @override
  String get shortcutRefreshData => 'ڈیٹا ریفریش کریں';

  @override
  String get shortcutRefreshDataDesc => 'موجودہ چیٹ کے ڈیٹا کو ریفریش کریں';

  @override
  String get shortcutStopResponse => 'جواب روکیں';

  @override
  String get shortcutStopResponseDesc => 'فعال جواب کو روکیں (جواب دیتے وقت)';

  @override
  String get shortcutToggleVoiceInput => 'صوتی ان پٹ کو تبدیل کریں';

  @override
  String get shortcutToggleVoiceInputDesc =>
      'ایڈیٹر میں صوتی ڈکٹیشن شروع کریں یا روکیں';

  @override
  String get shortcutsApply => 'لگائیں';

  @override
  String shortcutsConflictConflict(String conflict) {
    return '$conflict کے ساتھ تصادم';
  }

  @override
  String get shortcutsKeyboardShortcuts => 'کی بورڈ شارٹ کٹس';

  @override
  String get shortcutsReset => 'سب کو ری سیٹ کریں۔';

  @override
  String get shortcutsSearchEditBindings =>
      'تلاش کریں، بائنڈنگز میں ترمیم کریں، اور محفوظ کرنے سے پہلے تنازعات کو حل کریں۔';

  @override
  String shortcutsSetShortcutWidget(String label) {
    return 'شارٹ کٹ سیٹ کریں: $label';
  }

  @override
  String get shortcutsTheseBindingsStored =>
      'یہ بائنڈنگز موجودہ ایپ رن ٹائم کے لیے CodeWalk میں محفوظ ہیں اور OpenCode `tui.json` کی بائنڈز میں ترمیم نہیں کرتی ہیں۔';

  @override
  String get speechAutoStopSilence => 'خود بخود خاموشی کا ٹائم آؤٹ';

  @override
  String get speechChooseRecognitionEngine =>
      'شناختی انجن، خاموشی کا ٹائم آؤٹ، اور ماڈل کے اختیارات کا انتخاب کریں۔';

  @override
  String speechDesktopOnly(String service) {
    return '$service صرف ڈیسک ٹاپ پر دستیاب ہے۔';
  }

  @override
  String get speechDownload => 'ڈاؤن لوڈ کریں۔';

  @override
  String get speechEngine => 'انجن';

  @override
  String get speechInstalledLanguages => 'انسٹال شدہ زبانیں۔';

  @override
  String get speechListeningStopsAutomatically =>
      'اس کئی سیکنڈ کی خاموشی کے بعد سننا خود بخود رک جاتا ہے۔';

  @override
  String get speechMicPermissionDisabled => 'مائیکروفون کی اجازت غیر فعال ہے۔';

  @override
  String speechModelFilesIncomplete(String service) {
    return '$service ماڈل فائلیں نامکمل ہیں۔';
  }

  @override
  String get speechMoonshine => 'چاندنی';

  @override
  String get speechMoonshineModelsDesktop => 'مونشائن ماڈلز (ڈیسک ٹاپ)';

  @override
  String get speechMoonshineStaysDownloadable =>
      'Moonshine ڈاؤن لوڈ کے قابل اور ایپ بنڈل سے باہر رہتی ہے۔ اس ڈیسک ٹاپ ڈیوائس کے لیے ایک ماڈل منتخب کریں اور اگر آپ جگہ واپس چاہتے ہیں تو اسے بعد میں ہٹا دیں۔';

  @override
  String get speechNative => 'مقامی';

  @override
  String get speechNativeSTTDisabled =>
      'اس ایپ میں لینکس پر مقامی STT غیر فعال ہے۔ پیراکیٹ نئے انسٹالز کے لیے ڈیفالٹ انجن ہے۔';

  @override
  String get speechNativeSTTWorks =>
      'On Windows, CodeWalk uses local on-device speech recognition through its WASAPI microphone backend. Native Windows speech recognition is disabled for stability.';

  @override
  String get speechNativeStartsFaster =>
      'مقامی تیزی سے شروع ہوتا ہے۔ شیرپا بھاری سیٹ اپ اور گہرے ماڈل کنٹرول کے ساتھ مکمل طور پر آن ڈیوائس چلاتا ہے۔';

  @override
  String get speechOpenMicrophoneSettings => 'Open microphone settings';

  @override
  String get speechOpenSpeechPrivacy => 'Open speech privacy';

  @override
  String get speechOpenSpeechSettings => 'Open speech settings';

  @override
  String get speechParakeet => 'طوطا';

  @override
  String get speechParakeetModelsDesktop => 'پیراکیٹ ماڈل (ڈیسک ٹاپ)';

  @override
  String get speechParakeetStaysDownloadable =>
      'پیراکیٹ ڈاؤن لوڈ کے قابل اور ایپ بنڈل سے باہر رہتا ہے۔ یہ فی الحال 25 یورپی زبانوں کے لیے موزوں ایک کثیر لسانی ماڈل کو بے نقاب کرتا ہے۔';

  @override
  String get speechPickLanguagePacks =>
      'زبان کے پیک کو منتخب کریں اور ڈیوائس پر شناخت کے لیے ماڈلز ڈاؤن لوڈ/ہٹائیں۔';

  @override
  String get speechRemove => 'ہٹا دیں۔';

  @override
  String speechRuntimeFailed(String service) {
    return '$service رن ٹائم شروع ہونے میں ناکام رہا۔';
  }

  @override
  String get speechSelectSherpaAbove =>
      'لینگویج پیک کا نظم کرنے اور ماڈل ڈاؤن لوڈ کرنے کے لیے اوپر شیرپا کو منتخب کریں۔';

  @override
  String get speechSenseVoice => 'سینس وائس';

  @override
  String get speechSenseVoiceModelsDesktop => 'SenseVoice ماڈلز (ڈیسک ٹاپ)';

  @override
  String get speechSenseVoiceStaysDownloadable =>
      'SenseVoice ڈاؤن لوڈ کے قابل اور ایپ بنڈل سے باہر رہتا ہے۔ یہ چینی، کینٹونیز، جاپانی، کورین اور انگریزی کے لیے یہاں کا سب سے مضبوط ڈیسک ٹاپ آپشن ہے۔';

  @override
  String get speechSherpa => 'شیرپا';

  @override
  String get speechSherpaExperimentalFail =>
      'شیرپا تجرباتی ہے اور کچھ آلات پر ناکام ہو سکتا ہے۔ اگر آپ سب سے زیادہ مستحکم سلوک چاہتے ہیں تو مقامی کو ترجیح دیں۔';

  @override
  String get speechSherpaModelsLinux => 'شیرپا ماڈلز (لینکس)';

  @override
  String get speechSpeechText => 'متن سے تقریر';

  @override
  String speechUnavailableOnPlatform(String service) {
    return 'اس پلیٹ فارم پر $service اسپیچ دستیاب نہیں ہے۔';
  }

  @override
  String get speechWindowsSetupHint =>
      'Windows voice input uses CodeWalk WASAPI capture with on-device models. Keep microphone access for desktop apps enabled; the buttons below open Windows settings for troubleshooting.';

  @override
  String get statusConnected => 'منسلک';

  @override
  String get statusDelayed => 'تاخیر شدہ';

  @override
  String get statusFailed => 'ناکام';

  @override
  String get statusOffline => 'آف لائن';

  @override
  String get statusOnline => 'آن لائن';

  @override
  String get statusReconnecting => 'دوبارہ منسلک ہو رہا ہے';

  @override
  String get statusStarting => 'شروع ہو رہا ہے';

  @override
  String get statusStopped => 'روک دیا گیا';

  @override
  String get statusStopping => 'روکا جا رہا ہے';

  @override
  String get statusSyncDelayed => 'ہم آہنگی میں تاخیر';

  @override
  String get tailscaleNoPeers => 'کوئی ہم عمر نہیں ملا';

  @override
  String get tailscaleNotSupportedOnPlatform =>
      'اس پلیٹ فارم پر Tailscale سپورٹ نہیں ہے۔';

  @override
  String get tailscaleNotSupportedOnWindows =>
      'ونڈوز پر Tailscale سپورٹ نہیں ہے۔';

  @override
  String get tailscalePeerOffline => 'آف لائن';

  @override
  String get tailscaleSelectPeer => 'ٹیل اسکیل پیئر کو منتخب کریں۔';

  @override
  String get tailscaleWaitingAdminApproval =>
      'یہ Tailscale نوڈ ایڈمن کی منظوری کا منتظر ہے۔';

  @override
  String get terminalClose => 'ٹرمینل بند کریں۔';

  @override
  String terminalConnectingTo(String serverName) {
    return '$serverName ٹرمینل سے منسلک ہو رہا ہے...';
  }

  @override
  String terminalConnectionFailed(String error) {
    return 'ٹرمینل کنکشن ناکام رہا: $error';
  }

  @override
  String get terminalDisconnected => 'ٹرمینل منقطع ہو گیا۔';

  @override
  String terminalEmbeddedUnavailable(String serverName) {
    return 'ایمبیڈڈ ٹرمینل ابھی اس رن ٹائم پر دستیاب نہیں ہے۔ ایک بار کی کمانڈز کے لیے کمپوزر شیل موڈ کا استعمال جاری رکھیں یا $serverName کے لیے سپورٹڈ CodeWalk ایپ رن ٹائم سے ٹرمینل کھولیں۔';
  }

  @override
  String get terminalExtraKeyAlt => 'Alt کی';

  @override
  String get terminalExtraKeyArrowDown => 'نیچے کا تیر';

  @override
  String get terminalExtraKeyArrowLeft => 'بائیں تیر';

  @override
  String get terminalExtraKeyArrowRight => 'دائیں تیر';

  @override
  String get terminalExtraKeyArrowUp => 'اوپر کا تیر';

  @override
  String get terminalExtraKeyControl => 'Control کی';

  @override
  String get terminalExtraKeyEscape => 'Escape کی';

  @override
  String get terminalExtraKeyTab => 'Tab کی';

  @override
  String get terminalExtraKeys => 'ٹرمینل کی اضافی کیز';

  @override
  String get terminalHide => 'ٹرمینل چھپائیں';

  @override
  String get terminalMaximize => 'زیادہ سے زیادہ کرنا';

  @override
  String get terminalMinimize => 'ٹرمینل کو کم سے کم کریں۔';

  @override
  String get terminalNotAvailableYet =>
      'اس رن ٹائم پر ابھی ایمبیڈڈ ٹرمینل دستیاب نہیں ہے۔';

  @override
  String get terminalOpen => 'ٹرمینل کھولیں';

  @override
  String get terminalOpenInfo => 'ٹرمینل کی معلومات کھولیں';

  @override
  String get terminalOpenProjectFirst =>
      'سرور ٹرمینل شروع کرنے سے پہلے پروجیکٹ فولڈر کھولیں۔';

  @override
  String get terminalOpenToConnect =>
      'سرور پروجیکٹ ٹرمینل سے منسلک ہونے کے لیے ٹرمینل کھولیں۔';

  @override
  String get terminalReconnect => 'ٹرمینل کو دوبارہ جوڑیں۔';

  @override
  String get terminalRestoreSize => 'سائز کو بحال کریں۔';

  @override
  String get terminalSelectServer =>
      'ٹرمینل کھولنے سے پہلے ایک فعال سرور منتخب کریں۔';

  @override
  String get terminalSessionClosed => 'ٹرمینل سیشن بند کر دیا گیا۔';

  @override
  String get terminalTerminal => 'ٹرمینل';

  @override
  String get terminalTitle => 'ٹرمینل';

  @override
  String get terminalTryAgain => 'دوبارہ کوشش کریں۔';

  @override
  String get toolAwaitingInput => 'ان پٹ کا انتظار ہے۔';

  @override
  String get toolEditing => 'ایڈیٹنگ';

  @override
  String get toolEditingFiles => 'فائلوں میں ترمیم کرنا';

  @override
  String get toolFinding => 'تلاش کرنا';

  @override
  String get toolFindingFiles => 'فائلیں تلاش کرنا';

  @override
  String get toolPresentationAwaitingInput => 'ان پٹ کا انتظار ہے۔';

  @override
  String get toolPresentationEditing => 'ایڈیٹنگ';

  @override
  String get toolPresentationEditingFiles => 'فائلوں میں ترمیم کرنا';

  @override
  String get toolPresentationFinding => 'تلاش کرنا';

  @override
  String get toolPresentationFindingFiles => 'فائلیں تلاش کرنا';

  @override
  String get toolPresentationReading => 'پڑھنا';

  @override
  String get toolPresentationReadingFile => 'فائل پڑھنا';

  @override
  String get toolPresentationRunning => 'چل رہا ہے۔';

  @override
  String get toolPresentationRunningCommand => 'رننگ کمانڈ';

  @override
  String toolPresentationRunningTool(String toolName) {
    return '$toolName چلا رہا ہے';
  }

  @override
  String get toolPresentationSearching => 'تلاش کر رہا ہے۔';

  @override
  String get toolPresentationSearchingCode => 'تلاش کا کوڈ';

  @override
  String get toolPresentationSearchingWeb => 'ویب پر تلاش کر رہا ہے۔';

  @override
  String get toolPresentationTool => 'ٹول';

  @override
  String get toolPresentationUpdatingTaskList =>
      'کام کی فہرست کو اپ ڈیٹ کیا جا رہا ہے۔';

  @override
  String get toolPresentationUpdatingTasks => 'کاموں کو اپ ڈیٹ کرنا';

  @override
  String get toolPresentationWaitingInput => 'آپ کے ان پٹ کا انتظار ہے۔';

  @override
  String get toolPresentationWriting => 'تحریر';

  @override
  String get toolPresentationWritingFile => 'تحریری فائل';

  @override
  String get toolReading => 'پڑھنا';

  @override
  String get toolReadingFile => 'فائل پڑھنا';

  @override
  String get toolRunning => 'چل رہا ہے۔';

  @override
  String get toolRunningCommand => 'رننگ کمانڈ';

  @override
  String get toolRunningTask => 'رننگ ٹاسک';

  @override
  String get toolSearching => 'تلاش کر رہا ہے۔';

  @override
  String get toolSearchingCode => 'تلاش کا کوڈ';

  @override
  String get toolSearchingWeb => 'ویب پر تلاش کر رہا ہے۔';

  @override
  String get toolUpdatingTaskList => 'کام کی فہرست کو اپ ڈیٹ کیا جا رہا ہے۔';

  @override
  String get toolUpdatingTasks => 'کاموں کو اپ ڈیٹ کرنا';

  @override
  String get toolWaitingForInput => 'آپ کے ان پٹ کا انتظار ہے۔';

  @override
  String get toolWriting => 'تحریر';

  @override
  String get toolWritingFile => 'تحریری فائل';

  @override
  String get tourBack => 'پیچھے';

  @override
  String get tourSkip => 'چھوڑیں۔';

  @override
  String get trayQuit => 'چھوڑو';

  @override
  String get trayShow => 'دکھائیں۔';

  @override
  String get useOAuthCloudflareAccess =>
      'OAuth استعمال کریں (Cloudflare Access)';

  @override
  String get useOAuthCloudflareAccessSubtitle =>
      'Cloudflare Access Managed OAuth کے لیے ایک براؤزر کھولتا ہے۔';

  @override
  String get useOAuthCloudflareAccessUnsupported =>
      'Cloudflare Access OAuth اس پلیٹ فارم پر دستیاب نہیں ہے۔ اس کے بجائے Basic Auth استعمال کریں۔';

  @override
  String get useTailscale => 'ٹیل اسکیل کا استعمال کریں۔';

  @override
  String get useTailscaleSubtitle =>
      'بغیر سسٹم VPN کے ٹیل اسکیل نیٹ ورک کے ذریعے ٹریفک کو روٹ کرتا ہے۔';

  @override
  String get useTailscaleUnsupported =>
      'ٹیل اسکیل اس پلیٹ فارم پر تعاون یافتہ نہیں ہے۔';

  @override
  String get utilityTitle => 'افادیت';

  @override
  String get workspaceBrowseDirs => 'ڈائریکٹریز کو براؤز کریں۔';

  @override
  String get workspaceChooseFolderOpen =>
      'پروجیکٹ سیاق و سباق کے طور پر کھولنے کے لیے کوئی بھی فولڈر منتخب کریں۔';

  @override
  String workspaceCloseProject(String project) {
    return 'بند کریں $project';
  }

  @override
  String get workspaceClosedProjects => 'بند منصوبے';

  @override
  String workspaceCurrentDirectory(String path) {
    return 'موجودہ ڈائریکٹری: $path';
  }

  @override
  String get workspaceFilterDirs => 'ڈائریکٹریز کو فلٹر کریں۔';

  @override
  String get workspaceOpenFolder => 'فولڈر کھولیں۔';

  @override
  String get workspaceOpenProjectFolder => 'پروجیکٹ فولڈر کھولیں۔';

  @override
  String get workspaceOpenProjects => 'کھلے منصوبے';

  @override
  String get workspaceProjectDirectory => 'پروجیکٹ ڈائرکٹری';

  @override
  String get workspaceProjectHint => '/repo/my-project';

  @override
  String workspaceRemoveFromHistory(String name) {
    return 'تاریخ سے $name کو ہٹا دیں۔';
  }

  @override
  String get settingsSessionAttentionTitle => 'سیشن توجہ';

  @override
  String get settingsSessionAttentionDescription =>
      'روٹ سیشن کی حالت اختیاری ببل یا پینل میں دکھاتا ہے۔';

  @override
  String get settingsSessionAttentionOff => 'بند';

  @override
  String get settingsSessionAttentionBubble => 'ببل';

  @override
  String get settingsSessionAttentionPanel => 'پینل';

  @override
  String get settingsSessionAttentionPrivacy =>
      'Android پر اسے فعال کرنے سے مستقل فورگراؤنڈ سروس شروع ہوتی ہے۔ جواب کا متن خفیہ کر کے محفوظ ہوتا ہے؛ کلاؤڈ TTS صرف پڑھیں دبانے کے بعد متن بھیجتا ہے۔';

  @override
  String get settingsSessionAttentionUnavailable =>
      'اس پلیٹ فارم پر سیشن توجہ دستیاب نہیں ہے۔';

  @override
  String get settingsSessionAttentionOpenSettings => 'ڈسپلے سیٹنگز کھولیں';

  @override
  String get settingsSessionAttentionStop => 'سیشن توجہ روکیں';

  @override
  String get settingsSessionAttentionThirdPartyTtsWarning =>
      'پڑھیں دبانے پر جواب کا متن ترتیب دیے گئے فریق ثالث TTS فراہم کنندہ کو بھیجا جا سکتا ہے۔';

  @override
  String get workspaceSuggestions => 'تجاویز';

  @override
  String get sessionTabsGestureHintTitle => 'Session tabs have new controls';

  @override
  String get sessionTabsGestureHintBody =>
      'Double-click or double-tap a tab to close it. Right-click or touch and hold to open session actions. You can disable tabs in Display Toggles.';

  @override
  String get sessionTabsGestureHintAcknowledge => 'Got it';

  @override
  String get sessionTabsGestureHintDisableTabs => 'Disable tabs';

  @override
  String get sessionTabRenameAction => 'Rename session';

  @override
  String sessionTabClosedMessage(String title) {
    return 'Tab \"$title\" closed';
  }

  @override
  String get sessionTabUndo => 'Undo';

  @override
  String get sessionTabRestoreFailed => 'Tab could not be restored.';
}
