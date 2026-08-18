// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get aboutGitHub => 'গিটহাব';

  @override
  String get appProviderCannotActivateUnhealthy =>
      'একটি অস্বাস্থ্যকর সার্ভার সক্রিয় করা যাবে না';

  @override
  String get appProviderDesktopOnly =>
      'পরিচালিত স্থানীয় সার্ভার শুধুমাত্র ডেস্কটপে উপলব্ধ।';

  @override
  String get appProviderDetectingCommand =>
      'OpenCode কমান্ড সনাক্ত করা হচ্ছে...';

  @override
  String get appProviderErrorCannotActivateUnhealthy =>
      'একটি অস্বাস্থ্যকর সার্ভার সক্রিয় করা যাবে না';

  @override
  String get appProviderErrorCloudflareOAuthNotSupported =>
      'Cloudflare Access OAuth এই প্ল্যাটফর্মে সমর্থিত নয়';

  @override
  String get appProviderErrorInstallationFailed =>
      'OpenCode ইনস্টলেশন ব্যর্থ হয়েছে।';

  @override
  String get appProviderErrorInvalidServerUrl => 'অকার্যকর সার্ভার URL';

  @override
  String get appProviderErrorLocalServerHealthCheckFailed =>
      'স্থানীয় সার্ভার শুরু হয়েছে কিন্তু হেলথ চেক পাস করেনি।';

  @override
  String get appProviderErrorManagedDesktopOnly =>
      'পরিচালিত স্থানীয় সার্ভার শুধুমাত্র ডেস্কটপে উপলব্ধ।';

  @override
  String get appProviderErrorServerAlreadyExists =>
      'এই URL সহ একটি সার্ভার ইতিমধ্যে বিদ্যমান';

  @override
  String get appProviderErrorServerProfileNotFound =>
      'সার্ভার প্রোফাইল পাওয়া যায়নি';

  @override
  String get appProviderErrorServerUrlRequired => 'সার্ভার URL প্রয়োজন';

  @override
  String get appProviderErrorTailscaleNotSupported =>
      'Tailscale এই প্ল্যাটফর্মে সমর্থित নয়';

  @override
  String appProviderExitedWithCode(int code) {
    return 'স্থানীয় সার্ভার কোড $code সহ বন্ধ হয়েছে।';
  }

  @override
  String get appProviderFailedToStart =>
      'স্থানীয় OpenCode সার্ভার শুরু করতে ব্যর্থ হয়েছে।';

  @override
  String get appProviderInstallBinary => 'বাইনারি ইনস্টল করুন';

  @override
  String get appProviderInstallBunOpenCode => 'Bun + OpenCode ইনস্টল করুন';

  @override
  String get appProviderInstallSucceeded => 'ইনস্টলেশন সফল হয়েছে।';

  @override
  String appProviderInstallSucceededWithPath(String path) {
    return 'ইনস্টলেশন সফল হয়েছে। OpenCode কমান্ড $path-এ উপলব্ধ।';
  }

  @override
  String get appProviderInstallViaBun => 'Bun-এর মাধ্যমে ইনস্টল করুন';

  @override
  String get appProviderInstallViaNpm => 'npm-এর মাধ্যমে ইনস্টল করুন';

  @override
  String get appProviderInstallationFailed =>
      'OpenCode ইনস্টলেশন ব্যর্থ হয়েছে।';

  @override
  String get appProviderInstalledSuccessfully =>
      'OpenCode প্রয়োজনীয়তা সফলভাবে ইনস্টল করা হয়েছে।';

  @override
  String get appProviderInstallingRequirements =>
      'OpenCode প্রয়োজনীয়তা ইনস্টল করা হচ্ছে...';

  @override
  String get appProviderInvalidServerUrl => 'অকার্যকর সার্ভার URL';

  @override
  String get appProviderLabelLocalOpenCodeManaged =>
      'স্থানীয় OpenCode (পরিচালিত)';

  @override
  String get appProviderLabelPrimaryServer => 'প্রাথমিক সার্ভার';

  @override
  String get appProviderLocalManaged => 'স্থানীয় OpenCode (পরিচালিত)';

  @override
  String get appProviderLocalServerStopped => 'স্থানীয় সার্ভার বন্ধ আছে।';

  @override
  String get appProviderNotDetectedInstall =>
      'OpenCode কমান্ড সনাক্ত করা যায়নি। উইজার্ড থেকে ইনস্টলেশন চালান।';

  @override
  String appProviderNotDetectedRefresh(String appName) {
    return 'OpenCode কমান্ড সনাক্ত করা যায়নি। আপনি যদি এটি কিছুক্ষণ আগে ইনস্টল করে থাকেন তবে চেকগুলি রিফ্রেশ করুন বা PATH পুনরায় লোড করতে $appName পুনরায় খুলুন।';
  }

  @override
  String get appProviderOAuthNotSupported =>
      'Cloudflare Access OAuth এই প্ল্যাটফর্মে সমর্থিত নয়';

  @override
  String get appProviderOpenCodeDetected => 'OpenCode সনাক্ত করা হয়েছে';

  @override
  String get appProviderOpenCodeNotDetected => 'OpenCode সনাক্ত করা যায়নি';

  @override
  String get appProviderPrimaryServer => 'প্রাথমিক সার্ভার';

  @override
  String get appProviderProfileNotFound => 'সার্ভার প্রোফাইল পাওয়া যায়নি';

  @override
  String get appProviderRunDiagnostics =>
      'স্থানীয় OpenCode প্রয়োজনীয়তা যাচাই করতে ডায়াগনস্টিকস চালান।';

  @override
  String appProviderRunningAt(String url) {
    return '$url-এ চলছে';
  }

  @override
  String get appProviderSetupDetectingOpenCode =>
      'OpenCode কমান্ড সনাক্ত করা হচ্ছে...';

  @override
  String get appProviderSetupInstallationSucceeded => 'ইনস্টলেশন সফল হয়েছে।';

  @override
  String appProviderSetupInstallationSucceededWithPath(String path) {
    return 'ইনস্টলেশন সফল হয়েছে। OpenCode কমান্ড $path-এ উপলব্ধ।';
  }

  @override
  String get appProviderSetupInstallingRequirements =>
      'OpenCode প্রয়োজনীয়তা ইনস্টল করা হচ্ছে...';

  @override
  String get appProviderSetupOpenCodeDetected => 'OpenCode সনাক্ত করা হয়েছে';

  @override
  String get appProviderSetupOpenCodeNotDetected =>
      'OpenCode সনাক্ত করা যায়নি';

  @override
  String get appProviderSetupOpenCodeNotDetectedInstall =>
      'OpenCode কমান্ড সনাক্ত করা যায়নি। উইজার্ড থেকে ইনস্টলেশন চালান।';

  @override
  String get appProviderSetupOpenCodeNotDetectedRefresh =>
      'OpenCode কমান্ড সনাক্ত করা যায়নি। আপনি যদি এটি কিছুক্ষণ আগে ইনস্টল করে থাকেন তবে চেকগুলি রিফ্রেশ করুন বা PATH পুনরায় লোড করতে CodeWalk পুনরায় খুলুন।';

  @override
  String get appProviderSetupRequirementsInstalled =>
      'OpenCode প্রয়োজনীয়তা সফলভাবে ইনস্টল করা হয়েছে।';

  @override
  String appProviderSetupUsingOpenCodeAt(String path) {
    return '$path-এ OpenCode কমান্ড ব্যবহার করা হচ্ছে';
  }

  @override
  String get appProviderStartingLocalServer => 'স্থানীয় সার্ভার শুরু হচ্ছে...';

  @override
  String appProviderStatusLocalServerExitedWithCode(int code) {
    return 'স্থানীয় সার্ভার কো드 $code সহ বন্ধ হয়েছে।';
  }

  @override
  String get appProviderStatusLocalServerStopped =>
      'স্থানীয় সার্ভার বন্ধ আছে।';

  @override
  String appProviderStatusRunningAt(String url) {
    return '$url-এ চলছে';
  }

  @override
  String get appProviderStatusStartingLocalServer =>
      'স্থানীয় সার্ভার শুরু হচ্ছে...';

  @override
  String get appProviderStatusStoppingLocalServer =>
      'স্থানীয় সার্ভار বন্ধ করা হচ্ছে...';

  @override
  String get appProviderStoppingLocalServer =>
      'স্থানীয় সার্ভার বন্ধ করা হচ্ছে...';

  @override
  String get appProviderTailscaleNotSupported =>
      'Tailscale এই প্ল্যাটফর্মে সমর্থিত নয়';

  @override
  String appProviderUsingCommandAt(String path) {
    return '$path-এ OpenCode কমান্ড ব্যবহার করা হচ্ছে';
  }

  @override
  String get appShellDownloadingUpdate => 'আপডেট ডাউনলোড হচ্ছে';

  @override
  String get appShellInstall => 'ইনস্টল করুন';

  @override
  String get appShellInstallFailed => 'ইনস্টলেশন ব্যর্থ';

  @override
  String get appShellInstallingUpdate => 'আপডেট ইনস্টল হচ্ছে...';

  @override
  String get appShellRestart => 'পুনরায় শুরু করুন';

  @override
  String appShellUpdateAvailableResult(String latestVersion) {
    return 'আপডেট পাওয়া যাচ্ছে: v$latestVersion';
  }

  @override
  String get appShellUpdateInstalledRestartApp =>
      'আপডেট ইনস্টল করা হয়েছে। প্রয়োগ করতে অ্যাপটি পুনরায় শুরু করুন।';

  @override
  String get appShellUpdateInstalledRestartRequired =>
      'আপডেট ইনস্টল করা হয়েছে। নতুন সংস্করণ প্রয়োগ করতে পুনরায় শুরু করা প্রয়োজন।';

  @override
  String get attachmentCouldNotDecode => 'সংযুক্তি ডেটা ডিকোড করা যায়নি।';

  @override
  String get attachmentCouldNotDownload => 'সংযুক্তি ডাউনলোড করা যায়নি।';

  @override
  String get attachmentCouldNotSave =>
      'এই ডিভাইসে সংযুক্তি সংরক্ষণ করা যায়নি।';

  @override
  String get attachmentDownloadStarted => 'সংযুক্তি ডাউনলোড শুরু হয়েছে।';

  @override
  String get attachmentLocalNotFound =>
      'এই ডিভাইসে স্থানীয় সংযুক্তি পাওয়া যায়নি।';

  @override
  String get attachmentNoValidLocation =>
      'সংযুক্তি একটি বৈধ অবস্থান প্রদান করে না।';

  @override
  String get attachmentNotAvailableOnPlatform =>
      'এই প্ল্যাটফর্মে সংযুক্তি ক্রিয়াগুলি উপলব্ধ নয়।';

  @override
  String get attachmentPathEmpty => 'সংযুক্তি পাথ খালি।';

  @override
  String get attachmentPayloadEmpty => 'সংযুক্তি পে-লোড খালি।';

  @override
  String get attachmentSaveCanceled => 'সংরক্ষণ বাতিল করা হয়েছে।';

  @override
  String attachmentSavedAndOpened(String path) {
    return 'সংযুক্তি $path-এ সংরক্ষিত এবং খোলা হয়েছে।';
  }

  @override
  String attachmentSavedPath(String path) {
    return 'সংযুক্তি $path-এ সংরক্ষিত হয়েছে।';
  }

  @override
  String attachmentSavedTo(String path) {
    return 'সংযুক্তি $path-এ সংরক্ষিত হয়েছে।';
  }

  @override
  String get attachmentUnableToOpenLink => 'সংযুক্তি লিঙ্ক খুলতে অক্ষম।';

  @override
  String get attachmentUnableToOpenLocal => 'স্থানীয় সংযুক্তি খুলতে অক্ষম।';

  @override
  String get behaviorAdvancedPermissionRule => 'উন্নত অনুমতি নিয়ম';

  @override
  String get behaviorAutomatic => 'স্বয়ংক্রিয়';

  @override
  String get behaviorAutomaticFallback => 'স্বয়ংক্রিয় ফলব্যাক';

  @override
  String get behaviorCellularDataSaver => 'মোবাইল ডেটা সেভার';

  @override
  String get behaviorCellularDataSaverActive =>
      'সেলুলার ডেটা সেভার সক্রিয় আছে।';

  @override
  String get behaviorChatLevelShare => 'চ্যাট-স্তর শেয়ারিং';

  @override
  String get behaviorCodeWalkReleaseChecks => 'CodeWalk রিলিজ চেক';

  @override
  String get behaviorControlsOfficialGlobal =>
      'OpenCode অফিসিয়াল গ্লোবাল সেটিংস নিয়ন্ত্রণ করে';

  @override
  String get behaviorControlsUpstreamOpenCode =>
      'আপস্ট্রিম OpenCode সেটিংস নিয়ন্ত্রণ করে';

  @override
  String get behaviorCustomDisplayName => 'কাস্টম প্রদর্শন নাম';

  @override
  String behaviorCutsAutomaticMobile(int inSeconds) {
    return 'ব্যাকগ্রাউন্ড ডাউনলোড বন্ধ করে এবং ফোরগ্রাউন্ড স্বয়ংক্রিয় রিফ্রেশ প্রতি $inSeconds সেকেন্ডে একটি বার্স্টে সীমাবদ্ধ করে স্বয়ংক্রিয় মোবাইল ডেটা ব্যবহার কমায়।';
  }

  @override
  String get behaviorDataSaverActive => 'মোবাইল ডেটাতে এখন সক্রিয়।';

  @override
  String get behaviorDataSaverAggressive => 'আক্রমনাত্মক';

  @override
  String get behaviorDataSaverAggressiveDescription =>
      'কম-ব্যান্ডউইথ মোড: শুধুমাত্র দৃশ্যমান ওয়ার্কস্পেস স্ট্রিম সক্রিয় থাকে, বৈশ্বিক আপডেট বিরতিতে রাখা হয় এবং স্বয়ংক্রিয় রিফ্রেশ দীর্ঘ বিরতিতে হয়।';

  @override
  String get behaviorDataSaverCellularOnly =>
      'সংযোগটি সেলুলার/মোবাইল হলেই প্রযোজ্য।';

  @override
  String get behaviorDataSaverOff => 'বন্ধ';

  @override
  String get behaviorDataSaverOffHint =>
      'সম্পূর্ণ রিয়েলটাইম এবং স্বয়ংক্রিয় রিফ্রেশ সক্রিয় রয়েছে।';

  @override
  String get behaviorDataSaverStandard => 'মানক';

  @override
  String get behaviorDataSaverWaiting =>
      'পরবর্তী মোবাইল-ডেটা সিঙ্ক উইন্ডোর জন্য অপেক্ষা করা হচ্ছে।';

  @override
  String get behaviorDisabled => 'নিষ্ক্রিয়';

  @override
  String get behaviorLightweightTasksLike => 'হালকা কাজ যেমন';

  @override
  String get behaviorManual => 'ম্যানুয়াল';

  @override
  String get behaviorNotify => 'বিজ্ঞপ্তি দিন';

  @override
  String get behaviorOfficialOpenCodePermission =>
      'অফিসিয়াল OpenCode অনুমতি নীতি \'opencode.json\'-এ কনফিগার করা হয়েছে প্রতি টুলের অনুমতি/চাওয়া/অস্বীকার করার নিয়মের সাথে। CodeWalk অফিসিয়াল অনুমতি-অনুরোধের কার্ডগুলি রাখে এবং একটি অনুমোদিত ADR-023 ব্যতিক্রম যোগ করে: সুরকার স্বয়ংক্রিয়ভাবে অনুমোদিত টগল উত্তরগুলি \'সর্বদা\' এবং \'মনে রাখবেন: সত্য\' সহ টেকসই সেশন-স্কোপড অনুদান তৈরি করতে শর্তহীনভাবে এবং একই থ্রেড-স্কোপড ধারাবাহিকতা পাথ অ্যান্ড্রয়েড ওয়ার্ক-এ সক্রিয় রাখে।';

  @override
  String get behaviorOpenCodeBackedDefaults => 'OpenCode-ব্যাকড ডিফল্ট';

  @override
  String get behaviorPermissionHandlingProvenance => 'অনুমতি হ্যান্ডলিং মূল';

  @override
  String get behaviorPermissionsVariantReasoning =>
      'অনুমতি এবং বৈকল্পিক/রিজনিং প্যারিটি আলাদা থাকে যতক্ষণ না তাদের UI উন্নত কনফিগার নিরাপদে সংরক্ষণ করতে পারে।';

  @override
  String get behaviorPrimaryAgentAgent =>
      'কোন এজেন্ট স্পষ্টভাবে নির্বাচিত না হলে প্রাথমিক এজেন্ট ব্যবহার করা হয়।';

  @override
  String get behaviorRefreshDefaults => 'ডিফল্ট রিফ্রেশ করুন';

  @override
  String get behaviorSharedAcrossOpenCode =>
      'কনফিগারের মাধ্যমে OpenCode ক্লায়েন্ট জুড়ে শেয়ার করা হয়েছে।';

  @override
  String get behaviorTheseValuesWrite =>
      'এই মানগুলি সক্রিয় সার্ভারে `/config` তে লিখবে এবং অফিসিয়াল OpenCode শেয়ার করা কনফিগারের সাথে মেলে।';

  @override
  String get cannedAddTitle => 'ক্যানড উত্তর যোগ করুন';

  @override
  String get cannedAppendAtCursor => 'কার্সারে যুক্ত করুন';

  @override
  String get cannedAppendAtCursorSubtitle =>
      'বন্ধ = বর্তমান কম্পোজার টেক্সট প্রতিস্থাপন করুন';

  @override
  String get cannedAttachFiles => 'ফাইল সংযুক্ত করুন';

  @override
  String get cannedEditTitle => 'ক্যানড উত্তর সম্পাদনা করুন';

  @override
  String get cannedNewQuickReply => 'নতুন দ্রুত উত্তর';

  @override
  String get cannedNoSuggestions => 'কোন পরামর্শ নেই';

  @override
  String get cannedOffMeansReplace =>
      'বন্ধ মানে বর্তমান কম্পোজার টেক্সট প্রতিস্থাপন';

  @override
  String get cannedQuickReply => 'নতুন দ্রুত উত্তর';

  @override
  String get cannedReplace => 'প্রতিস্থাপন করুন';

  @override
  String get cannedScopeGlobalSubtitle =>
      'শুধুমাত্র প্রজেক্ট আইটেমের জন্য নিষ্ক্রিয় করুন';

  @override
  String get cannedScopeGlobalUnavailableSubtitle =>
      'বর্তমান প্রসঙ্গে শুধুমাত্র প্রজেক্ট উপলব্ধ নয়';

  @override
  String get cannedSendAutomaticallySubtitle =>
      'এই দ্রুত উত্তর সন্নিবেশ করার সাথে সাথেই পাঠান';

  @override
  String get cannedSendImmediatelyInserting =>
      'এই দ্রুত উত্তর সন্নিবেশ করার পর অবিলম্বে পাঠান';

  @override
  String get cannedTextLabel => 'টেক্সট';

  @override
  String get chatActionNext => 'পরবর্তী';

  @override
  String get chatActiveServerUnhealthy =>
      'সক্রিয় সার্ভার অস্বাস্থ্যকর। সেন্ড একবার চেষ্টা করবে এবং পুনরুদ্ধার না হওয়া পর্যন্ত দ্রুত ব্যর্থ হবে।';

  @override
  String get chatActiveServerUnhealthyLabel => 'সক্রিয় সার্ভার অস্বাস্থ্যকর';

  @override
  String get chatAddServerToStart => 'চ্যাটিং শুরু করতে একটি সার্ভার যোগ করুন।';

  @override
  String get chatAppBarMoreActions => 'আরো কর্ম';

  @override
  String get chatAppBarPinAction => 'অ্যাপ বারে পিন করুন';

  @override
  String get chatAppBarPinDescription =>
      'এই ক্রিয়াটি মেনুর বাইরে দৃশ্যমান থাকবে।';

  @override
  String get chatAppBarUnpinAction => 'অ্যাপ বার থেকে আনপিন করুন';

  @override
  String get chatAppBarUnpinDescription => 'এই ক্রিয়াটি মেনুতে ফিরে যাবে।';

  @override
  String chatBadgeConversationError(String title) {
    return '\"$title\"-এ একটি ত্রুটি রয়েছে।';
  }

  @override
  String chatBadgeConversationNeedsInput(String title) {
    return '\"$title\"-এর আপনার ইনপুট প্রয়োজন।';
  }

  @override
  String chatBadgeConversationNewReply(String title) {
    return '\"$title\"-এ একটি নতুন উত্তর রয়েছে।';
  }

  @override
  String get chatBadgeDataSaverActive => 'সেলুলার ডেটা সেভার সক্রিয়।';

  @override
  String get chatBadgeServerNeedsAttention => 'সার্ভার সংযোগে মনোযোগ প্রয়োজন।';

  @override
  String get chatBadgeSyncing => 'কথোপকথন সিঙ্ক হচ্ছে...';

  @override
  String get chatBlockResponsePendingDescription =>
      'এই টার্ন শেষ হলে উত্তরটি একটি একক ব্লক হিসেবে প্রদর্শিত হবে।';

  @override
  String get chatBlockResponsePendingTitle => 'উত্তর তৈরি হচ্ছে';

  @override
  String get chatCachedConversationsYet => 'এখনও কোনো ক্যাশ করা কথোপকথন নেই৷';

  @override
  String get chatChangedFilesAvailable =>
      'এই অধিবেশনের জন্য কোন পরিবর্তিত ফাইল উপলব্ধ নেই.';

  @override
  String chatChildrenChatProviderCurrentSessionChildren(int length) {
    return 'চাইল্ড: $length';
  }

  @override
  String get chatChooseAgent => 'এজেন্ট নির্বাচন করুন';

  @override
  String get chatChooseDirectory => 'ডিরেক্টরি নির্বাচন করুন';

  @override
  String get chatChooseEffort => 'প্রচেষ্টা নির্বাচন করুন';

  @override
  String get chatChooseFolderOpen =>
      'প্রকল্পের প্রসঙ্গ হিসাবে খুলতে একটি ফোল্ডার চয়ন করুন।';

  @override
  String get chatChooseModel => 'মডেল নির্বাচন করুন';

  @override
  String get chatClose => 'বন্ধ';

  @override
  String chatCloseProject(String project) {
    return '$project বন্ধ করুন';
  }

  @override
  String get chatCollapseGroup => 'গ্রুপ গুটিয়ে নিন';

  @override
  String get chatCommandDescriptionProject => 'প্রজেক্ট কমান্ড';

  @override
  String get chatCommandSourceGeneric => 'কমান্ড';

  @override
  String get chatCommandSourceProject => 'প্রজেক্ট';

  @override
  String get chatCompactContext => 'কমপ্যাক্ট প্রসঙ্গ';

  @override
  String get chatComposerHintShell => 'শেল কমান্ড (Esc প্রস্থান)';

  @override
  String get chatComposerPlaceholder => 'আপনার প্রয়োজন টাইপ করুন...';

  @override
  String get chatConversation => 'কথোপকথন';

  @override
  String get chatConversations => 'কথোপকথন';

  @override
  String get chatConversationsPane => 'কথোপকথন';

  @override
  String chatCostLabel(double cost) {
    return 'খরচ: \$$cost';
  }

  @override
  String get chatCouldNotRefreshSession => 'এই কথোপকথন রিফ্রেশ করা যায়নি';

  @override
  String get chatCurrent => 'বর্তমান ব্যবহার করুন';

  @override
  String chatDescriptionChildren(int count) {
    return 'চিলড্রেন: $count';
  }

  @override
  String get chatDescriptionCloseApp =>
      'প্ল্যাটফর্ম বন্ধ করার আচরণ ব্যবহার করে অ্যাপ বন্ধ করুন';

  @override
  String get chatDescriptionCycleModels => 'সাম্প্রতিক মডেলগুলি পরিবর্তন করুন';

  @override
  String get chatDescriptionCycleVariant => 'মডেল ভেরিয়েন্ট পরিবর্তন করুন';

  @override
  String get chatDescriptionDiffFilesZero => 'ডিফ ফাইল: ০';

  @override
  String get chatDescriptionFocusInput => 'বার্তা ইনপুটে ফোকাস করুন';

  @override
  String get chatDescriptionFocusOrCloseDrawer =>
      'ইনপুটে ফোকাস করুন (বা খোলা থাকলে ড্রয়ার বন্ধ করুন)';

  @override
  String get chatDescriptionForceExit => 'অ্যাপ থেকে জোরপূর্বক প্রস্থান করুন';

  @override
  String get chatDescriptionNewConversation => 'নতুন কথোপকথন';

  @override
  String get chatDescriptionNextAgent => 'পরবর্তী এজেন্ট';

  @override
  String get chatDescriptionOpenProjects =>
      'আপনার প্রজেক্ট এবং কথোপকথন খুলতে এই বোতামটি ব্যবহার করুন।';

  @override
  String get chatDescriptionOpenSettings => 'সেটিংস খুলুন';

  @override
  String get chatDescriptionPreviousAgent => 'পূর্ববর্তী এজেন্ট';

  @override
  String get chatDescriptionProjectCommand => 'প্রজেক্ট কমান্ড';

  @override
  String get chatDescriptionQuickOpen => 'ফাইলগুলি দ্রুত খুলুন';

  @override
  String get chatDescriptionRefreshData => 'চ্যাট ডেটা রিফ্রেশ করুন';

  @override
  String get chatDescriptionStopResponse =>
      'সক্রিয় প্রতিক্রিয়া বন্ধ করুন (প্রতিক্রিয়া দেওয়ার সময়)';

  @override
  String get chatDescriptionSwitchProject =>
      'প্রজেক্ট ফোল্ডার এবং প্রসঙ্গ পরিবর্তন করতে এই বোতামটি ব্যবহার করুন।';

  @override
  String get chatDescriptionVoiceInput => 'ভয়েস ইনপুট শুরু বা বন্ধ করুন';

  @override
  String get chatDiffFiles => 'পার্থক্য ফাইল: 0';

  @override
  String get chatDisplay => 'প্রদর্শন';

  @override
  String get chatDisplayToggles => 'প্রদর্শন টগল';

  @override
  String get chatDoubleESCStop => 'থামতে দুইবার ESC';

  @override
  String get chatEffortLockedSubConversation =>
      'উপ-কথোপকথনে প্রচেষ্টা লক করা আছে';

  @override
  String get chatExpandGroup => 'গ্রুপ প্রসারিত করুন';

  @override
  String get chatExportCanceled => 'সেশন এক্সপোর্ট বাতিল করা হয়েছে';

  @override
  String get chatFailedToLoadDirectories => 'ডিরেক্টরি লোড করতে ব্যর্থ';

  @override
  String get chatFailedToLoadFile => 'ফাইল লোড করতে ব্যর্থ';

  @override
  String get chatFailedToRefreshProviders =>
      'প্রদানকারী এবং মডেল রিফ্রেশ করতে ব্যর্থ';

  @override
  String get chatFailedToRefreshSubConversations =>
      'উপ-কথোপকথন রিফ্রেশ করতে ব্যর্থ। আবার চেষ্টা করুন।';

  @override
  String get chatFailedToStopResponse =>
      'বর্তমান প্রতিক্রিয়া থামাতে ব্যর্থ হয়েছে৷';

  @override
  String get chatFileExplorerContents => 'বিষয়বস্তু';

  @override
  String get chatFileExplorerNames => 'নাম';

  @override
  String get chatFilterActive => 'সক্রিয়';

  @override
  String get chatFilterAll => 'সব';

  @override
  String get chatFilterArchived => 'সংরক্ষণাগারভুক্ত';

  @override
  String get chatFilterDirectories => 'ফিল্টার ডিরেক্টরি';

  @override
  String get chatFilterSessions => 'ফিল্টার সেশন';

  @override
  String get chatForkFailed => 'কথোপকথন ফোর্ক করতে ব্যর্থ হয়েছে';

  @override
  String get chatForked => 'কথোপকথন ফোর্ক করা হয়েছে';

  @override
  String get chatGoToFirst => 'প্রথম মেসেজে যান';

  @override
  String get chatGoToLatest => 'সর্বশেষ বার্তা যান';

  @override
  String chatGroupMessageCountMessages(
    String compactionLabel,
    String messageCount,
  ) {
    return '$compactionLabel কম্প্যাকশনের আগে $messageCountটি বার্তা লুকানো হয়েছে';
  }

  @override
  String get chatHelloAssistant => 'নমস্কার! আমি আপনার এআই সহকারী';

  @override
  String get chatHelp => 'আমি কিভাবে আপনাকে সাহায্য করতে পারি?';

  @override
  String get chatHelpMessage =>
      'উল্লেখের জন্য @, শেলের জন্য !, কমান্ডের জন্য / ব্যবহার করুন';

  @override
  String get chatHideConversationsSidebar => 'কথোপকথন সাইডবার লুকান';

  @override
  String get chatHideUtilitySidebar => 'ইউটিলিটি সাইডবার লুকান';

  @override
  String get chatHistoryCollapsed => 'আগের ইতিহাস ভেঙ্গে গেছে';

  @override
  String get chatHistoryHideEarlier => 'আগের বার্তা লুকান';

  @override
  String chatHistoryMessagesHidden(int count, String label) {
    return '$count বার্তা $label কমপ্যাকশনের আগে লুকানো';
  }

  @override
  String get chatHistoryShowEarlier => 'আগের বার্তাগুলি দেখান';

  @override
  String get chatKeepWorking => 'কাজ করতে থাকুন';

  @override
  String get chatLargeContentSkipped =>
      'স্থিতিশীলতার জন্য বড় বা ত্রুটিপূর্ণ বিষয়বস্তু এড়িয়ে যাওয়া হয়েছে।';

  @override
  String get chatLatestToolActivity =>
      'চ্যাট ভিউপোর্ট স্থিতিশীল রাখতে সর্বশেষ টুল কার্যকলাপ এই আবদ্ধ প্যানেলের ভিতরে থাকে।';

  @override
  String get chatLoadMore => 'আরো লোড';

  @override
  String get chatLoadingProjectContext => 'প্রকল্পের প্রসঙ্গ লোড হচ্ছে...';

  @override
  String get chatMainConversationUnavailable => 'মূল কথোপকথন এখনও উপলব্ধ নয়।';

  @override
  String get chatParentConversationUnavailable =>
      'প্যারেন্ট কথোপকথন এখনও উপলব্ধ নয়।';

  @override
  String get chatMentionAgentSubtitle => 'এজেন্ট';

  @override
  String get chatMentionFileSubtitle => 'ফাইল';

  @override
  String get chatMentionSymbolSubtitle => 'প্রতীক';

  @override
  String get chatMessageAttachedFile => 'সংযুক্ত ফাইল';

  @override
  String get chatMessageDetails => 'বিবরণ';

  @override
  String get chatMessageHide => 'লুকান';

  @override
  String get chatMessageLess => 'কম';

  @override
  String get chatMessageMessagePartUnavailable => 'বার্তা অংশ অনুপলব্ধ';

  @override
  String get chatMessageMetadataAvailable => 'কোন মেটাডেটা উপলব্ধ নেই';

  @override
  String chatMessageModelMessageModelId(String modelId) {
    return 'মডেল: $modelId';
  }

  @override
  String get chatMessageMore => 'আরও';

  @override
  String get chatMessageOpenFile => 'ফাইল খুলুন';

  @override
  String chatMessageProviderMessageProviderId(String providerId) {
    return 'প্রদানকারী: $providerId';
  }

  @override
  String get chatMessageRewindEdit =>
      'রিওয়াইন্ড করুন এবং এখান থেকে সম্পাদনা করুন';

  @override
  String get chatMessageRunningTask => 'চলমান টাস্ক';

  @override
  String get chatMessageSaveFile => 'ফাইল সংরক্ষণ করুন';

  @override
  String get chatMessageShow => 'দেখান';

  @override
  String get chatMessageShowQuestion => 'প্রশ্ন দেখুন';

  @override
  String get chatMessageShowLess => 'কম দেখান';

  @override
  String get chatMessageShowLessCompact => 'কম';

  @override
  String get chatMessageShowMore => 'আরও দেখান';

  @override
  String get chatMessageShowMoreCompact => 'আরও';

  @override
  String get chatMessageThinking => 'চিন্তা করছে';

  @override
  String get chatMessageThinkingProcess => 'চিন্তা প্রক্রিয়া';

  @override
  String get chatMessageToolCall => '1 টুল কল';

  @override
  String chatMessageToolCalls(int count) {
    return '$count টুল কল';
  }

  @override
  String get chatMessageToolCommand => 'কমান্ড';

  @override
  String get chatMessageToolCommandTruncated =>
      'স্থিতিশীলতার জন্য কমান্ড প্রিভিউ ছাঁটা হয়েছে।';

  @override
  String get chatMessageToolDiffOmitted =>
      'ডিফ প্রিভিউ বাদ দেওয়া হয়েছে: এডিট পেলোড মোবাইলে নিরাপদে রেন্ডার করতে খুব বড়।';

  @override
  String get chatMessageToolInput => 'ইনপুট';

  @override
  String get chatMessageToolInputTruncated =>
      'স্থিতিশীলতার জন্য ইনপুট প্রিভিউ ছাঁটা হয়েছে।';

  @override
  String get chatMessageToolOutputTruncated =>
      'বড় টুল আউটপুট প্রিভিউ অ্যাপ স্থিতিশীলতার জন্য ছাঁটা হয়েছে।';

  @override
  String chatMessageToolQueuedCount(int count) {
    return '$count সারিবদ্ধ';
  }

  @override
  String chatMessageToolRunningCount(int count) {
    return '$count চলছে';
  }

  @override
  String get chatMessageToolStatusInProgress => 'চলছে';

  @override
  String get chatMessageToolStatusNeedsAttention => 'মনোযোগ প্রয়োজন';

  @override
  String get chatMessageToolStatusQueued => 'সারিবদ্ধ';

  @override
  String get chatMessageYou => 'আপনি';

  @override
  String get chatModelLockedSubConversation => 'উপ-কথোপকথনে মডেল লক করা আছে';

  @override
  String get chatNewChat => 'নতুন চ্যাট';

  @override
  String get chatNewChatTourDescription => 'এখানে একটি নতুন কথোপকথন শুরু করুন.';

  @override
  String get chatNewChatTourTitle => 'নতুন আড্ডা';

  @override
  String get chatNoConversationsInProject => 'এই প্রজেক্টে কোনো কথোপকথন নেই।';

  @override
  String get chatNoServerYet => 'কোন সার্ভার এখনো কনফিগার করা হয়নি';

  @override
  String get chatNoSessionSelected =>
      'চ্যাট শুরু করতে একটি কথোপকথন নির্বাচন বা তৈরি করুন';

  @override
  String get chatNoSubConversationFound =>
      'এই টাস্কের জন্য কোনো উপ-কথোপকথন পাওয়া যায়নি।';

  @override
  String get chatOpenFiles => 'ফাইল খুলুন';

  @override
  String get chatOpenProject => 'প্রজেক্ট খুলুন';

  @override
  String get chatOpenProjectFolder => 'প্রকল্প ফোল্ডার খুলুন...';

  @override
  String get chatOpenProjectToLoad => 'কথোপকথন লোড করতে প্রজেক্ট খুলুন।';

  @override
  String get chatOpenSidebar => 'সাইডবার খুলুন';

  @override
  String get chatPageStatusAutomaticCompactionExplanation =>
      'প্রসঙ্গ ব্যবহার বাড়ার সাথে সাথে স্বয়ংক্রিয় সংকোচন ঘটে।';

  @override
  String get chatPageStatusCompactNow => 'এখন কম্প্যাক্ট';

  @override
  String get chatPageStatusCompacting => 'কম্প্যাক্ট হচ্ছে...';

  @override
  String get chatPageStatusCompactingContextNow =>
      'এখন প্রসঙ্গ কম্প্যাক্ট করা হচ্ছে...';

  @override
  String get chatPageStatusContextCompacted => 'প্রসঙ্গ কম্প্যাক্ট করা হয়েছে';

  @override
  String get chatPageStatusContextUsage => 'কনটেক্সট ব্যবহার';

  @override
  String get chatPageStatusCost => 'খরচ';

  @override
  String get chatPageStatusFailedToCompactContext =>
      'কম্প্যাক্ট প্রসঙ্গ করতে ব্যর্থ হয়েছে';

  @override
  String get chatPageStatusLimit => 'সীমা';

  @override
  String get chatPageStatusManageServers => 'সার্ভার পরিচালনা করুন';

  @override
  String get chatPageStatusSaver => 'সেভার';

  @override
  String get chatPageStatusServer => 'সার্ভার';

  @override
  String get chatPageStatusSwitchServer => 'সার্ভার পরিবর্তন করুন';

  @override
  String get chatPageStatusTokens => 'টোকেন';

  @override
  String get chatPageStatusUsage => 'ব্যবহার';

  @override
  String chatPageStatusUsagePercent(int usagePercent) {
    return '$usagePercent';
  }

  @override
  String get chatPermissionAutoApproveOff =>
      'অনুমতি স্বয়ংক্রিয়-অনুমোদন বন্ধ আছে';

  @override
  String get chatPermissionAutoApproveOn =>
      'অনুমতি স্বয়ংক্রিয়-অনুমোদন চালু আছে';

  @override
  String get chatProjectContext => 'প্রকল্প প্রসঙ্গ';

  @override
  String get chatProjectContext2 => 'প্রজেক্ট কনটেক্সট';

  @override
  String get chatRealtimeGlobalEvent => 'গ্লোবাল ইভেন্ট';

  @override
  String chatRealtimeGlobalEventReason(String reason) {
    return 'গ্লোবাল ইভেন্ট ($reason)';
  }

  @override
  String get chatRealtimeGlobalEventStale => 'গ্লোবাল ইভেন্ট (পুরনো প্রজন্ম)';

  @override
  String chatRealtimeMessageStreamReason(String reason) {
    return 'বার্তা স্ট্রিম ($reason)';
  }

  @override
  String get chatRealtimeRealtimeEvent => 'রিয়েলটাইম ইভেন্ট';

  @override
  String chatRealtimeRealtimeEventReason(String reason) {
    return 'রিয়েলটাইম ইভেন্ট ($reason)';
  }

  @override
  String get chatRealtimeRealtimeEventStale =>
      'রিয়েলটাইম ইভেন্ট (পুরনো প্রজন্ম)';

  @override
  String get chatRealtimeReconnectingServerTry =>
      'সার্ভারে পুনরায় সংযোগ হচ্ছে। কিছুক্ষণ পরে আবার চেষ্টা করুন।';

  @override
  String get chatReasoning => 'যুক্তি করছে...';

  @override
  String get chatRecentSessions => 'সাম্প্রতিক সেশন';

  @override
  String get chatRecentSessionsToggle => 'সাম্প্রতিক সেশন';

  @override
  String get chatRedoLastTurn => 'শেষ পূর্বাবস্থায় ফেরানো পালা পুনরায় করুন';

  @override
  String get chatRedoNothing => 'এই সেশনে পুনরায় করার কিছু নেই';

  @override
  String get chatRefresh => 'রিফ্রেশ';

  @override
  String get chatRefreshConversation => 'এই কথোপকথন রিফ্রেশ করা যায়নি';

  @override
  String get chatRefreshProjects => 'রিফ্রেশ প্রকল্প';

  @override
  String get chatRefreshSessionDetails => 'সেশনের বিবরণ রিফ্রেশ করুন';

  @override
  String chatRemoveDisplayNameHistory(String displayName) {
    return 'ইতিহাস থেকে $displayName সরান';
  }

  @override
  String get chatRetry => 'আবার চেষ্টা করুন';

  @override
  String get chatRetry2 => 'আবার চেষ্টা করুন';

  @override
  String get chatRetryRefresh => 'রিফ্রেশ করার চেষ্টা করুন';

  @override
  String get chatRetryingModelRequest =>
      'মডেল অনুরোধ পুনরায় চেষ্টা করা হচ্ছে...';

  @override
  String get chatReturnToMainConversation => 'মূল কথোপকথনে ফিরে যান';

  @override
  String get chatReturnToParentConversation => 'প্যারেন্ট কথোপকথনে ফিরে যান';

  @override
  String get chatReviewChanges => 'পরিবর্তনগুলি পর্যালোচনা করুন';

  @override
  String get chatSearchConversations => 'কথোপকথন অনুসন্ধান করুন';

  @override
  String get chatSearchNextResult => 'পরবর্তী ফলাফল';

  @override
  String get chatSearchNoResults => 'কোনো ফলাফল নেই';

  @override
  String get chatSearchPreviousResult => 'পূর্ববর্তী ফলাফল';

  @override
  String chatSearchResultCount(int current, int total) {
    return 'বার্তা $current এর $total';
  }

  @override
  String get chatSearchTimeline => 'টাইমলাইন অনুসন্ধান করুন';

  @override
  String get chatSelectDirectory => 'ডিরেক্টরি নির্বাচন করুন';

  @override
  String get chatSelectOrCreate =>
      'চ্যাটিং শুরু করতে একটি কথোপকথন নির্বাচন করুন বা তৈরি করুন';

  @override
  String get chatSelectProjectBelow => 'নীচে একটি প্রকল্প নির্বাচন করুন.';

  @override
  String get chatServerSelectedModel => 'সার্ভার-নির্বাচিত মডেল';

  @override
  String get chatSessionActions => 'অধিবেশন কর্ম';

  @override
  String chatSessionChatSessionSession(String title) {
    return 'চ্যাট সেশন: $title';
  }

  @override
  String chatSessionConversationNextAction(String nextAction) {
    return 'কথোপকথন $nextAction';
  }

  @override
  String get chatSessionConversations => 'কোনো কথোপকথন নেই';

  @override
  String get chatSessionCreateConversationStart =>
      'চ্যাটিং শুরু করতে একটি নতুন কথোপকথন তৈরি করুন';

  @override
  String get chatSessionTabsToggle => 'সেশন ট্যাব';

  @override
  String chatSessionsLength(int length) {
    return '$length';
  }

  @override
  String get chatSetUpServer => 'সার্ভার সেট আপ করুন';

  @override
  String get chatSettings => 'সেটিংস';

  @override
  String get chatShortcutsCloseApp =>
      'প্ল্যাটফর্ম আচরণ ব্যবহার করে অ্যাপ বন্ধ করুন';

  @override
  String get chatShortcutsCycleModels => 'সাম্প্রতিক মডেলগুলি পরিবর্তন করুন';

  @override
  String get chatShortcutsCycleVariant => 'মডেল ভেরিয়েন্ট পরিবর্তন করুন';

  @override
  String get chatShortcutsFocusInput => 'বার্তা ইনপুটে ফোকাস করুন';

  @override
  String get chatShortcutsFocusInputCloseDrawer =>
      'ইনপুটে ফোকাস করুন (অথবা খোলা থাকলে ড্রয়ার বন্ধ করুন)';

  @override
  String get chatShortcutsForceExit => 'অ্যাপ থেকে জোরপূর্বক প্রস্থান করুন';

  @override
  String get chatShortcutsNewConversation => 'নতুন কথোপকথন';

  @override
  String get chatShortcutsNextAgent => 'পরবর্তী এজেন্ট';

  @override
  String get chatShortcutsOpenSettings => 'সেটিংস খুলুন';

  @override
  String get chatShortcutsPreviousAgent => 'পূর্ববর্তী এজেন্ট';

  @override
  String get chatShortcutsQuickOpen => 'ফাইল দ্রুত খুলুন';

  @override
  String get chatShortcutsRefreshChat => 'চ্যাট ডেটা রিফ্রেশ করুন';

  @override
  String get chatShortcutsStartStopVoice => 'ভয়েস ইনপুট শুরু বা বন্ধ করুন';

  @override
  String get chatShortcutsStopResponse =>
      'সক্রিয় প্রতিক্রিয়া বন্ধ করুন (প্রতিক্রিয়া দেওয়ার সময়)';

  @override
  String get chatSidebarAccess => 'সাইডবার অ্যাক্সেস';

  @override
  String get chatSortMostRecent => 'অতি সাম্প্রতিক';

  @override
  String get chatSortOldest => 'প্রাচীনতম';

  @override
  String get chatSortRecent => 'সাম্প্রতিক';

  @override
  String get chatSortSessions => 'সেশন সাজান';

  @override
  String get chatSortTitle => 'শিরোনাম';

  @override
  String get chatStartVoiceInput => 'ভয়েস ইনপুট শুরু করুন';

  @override
  String get chatStartingVoiceInput => 'ভয়েস ইনপুট শুরু হচ্ছে';

  @override
  String get chatStatusBusy => 'অবস্থা: ব্যস্ত';

  @override
  String get chatStatusPatching => 'প্যাচ করা হচ্ছে';

  @override
  String chatStatusPatchingMultipleFiles(int count) {
    return '$countটি ফাইল প্যাচ করা হচ্ছে';
  }

  @override
  String get chatStatusPatchingOneFile => '১টি ফাইল প্যাচ করা হচ্ছে';

  @override
  String get chatStatusRetry => 'অবস্থা: পুনরায় চেষ্টা';

  @override
  String chatStatusRetryCount(int count) {
    return 'অবস্থা: পুনরায় চেষ্টা #$count';
  }

  @override
  String get chatStatusSubsession => 'উপ-সেশন';

  @override
  String get chatStatusThinking => 'চিন্তা করছে...';

  @override
  String get chatStopVoiceInput => 'ভয়েস ইনপুট বন্ধ করুন';

  @override
  String chatSyncLabel(String label) {
    return 'সিঙ্ক: $label';
  }

  @override
  String get chatTasks => 'কাজ';

  @override
  String get chatTasksAvailableSession =>
      'এই অধিবেশনের জন্য কোন কাজ উপলব্ধ নেই.';

  @override
  String get chatTipAcceptanceCriteria =>
      'পরামর্শ: বড় পরিবর্তনে গ্রহণযোগ্যতার শর্ত যোগ করুন';

  @override
  String get chatTipAskForPlan => 'পরামর্শ: বড় কাজের আগে একটি পরিকল্পনা চাইুন';

  @override
  String get chatTipBeSpecific =>
      'পরামর্শ: সুনির্দিষ্ট হোন — ছোট প্রম্পট দ্রুত উত্তর পায়';

  @override
  String get chatTipBreakTasks =>
      'পরামর্শ: বড় কাজগুলিকে ছোট প্রম্পটে ভাগ করুন';

  @override
  String get chatTipCompareOptions => 'পরামর্শ: ট্রেডঅফ অস্পষ্ট হলে বিকল্প চান';

  @override
  String get chatTipContextKnob =>
      'পরামর্শ: ব্যবহারের বিবরণ দেখতে প্রসঙ্গ নবটিতে ট্যাপ করুন';

  @override
  String get chatTipDefineVerification =>
      'পরামর্শ: কোন পরীক্ষা বা চেক পাস করতে হবে বলুন';

  @override
  String get chatTipLongPressSend =>
      'পরামর্শ: নতুন লাইন সন্নিবেশ করতে সেন্ড বোতামটি দীর্ঘক্ষণ টিপুন';

  @override
  String get chatTipMentionFiles =>
      'পরামর্শ: আপনার প্রম্পটে ফাইলের উল্লেখ করতে @ ব্যবহার করুন';

  @override
  String get chatTipNameRelevantFiles =>
      'পরামর্শ: প্রাসঙ্গিক ফাইল, স্ক্রিন বা কমান্ডের নাম দিন';

  @override
  String get chatTipProvideContext =>
      'পরামর্শ: প্রসঙ্গ প্রদান করুন — ত্রুটি বার্তা এবং লগ পেস্ট করুন';

  @override
  String get chatTipRenameConversation =>
      'পরামর্শ: কথোপকথনের নাম পরিবর্তন করতে শিরোনামে ট্যাপ করুন';

  @override
  String get chatTipRequestDocs => 'পরামর্শ: আচরণ বদলালে ডকস আপডেট চাইুন';

  @override
  String get chatTipShareAttempts =>
      'পরামর্শ: কী চেষ্টা করেছেন এবং সঠিক ত্রুটি জানান';

  @override
  String get chatTipShellCommands =>
      'পরামর্শ: শেল কমান্ড চালাতে শুরুতে ! ব্যবহার করুন';

  @override
  String get chatTipSlashCommands =>
      'পরামর্শ: স্ল্যাশ কমান্ড অ্যাক্সেস করতে / ব্যবহার করুন';

  @override
  String get chatTipStartWithGoal => 'পরামর্শ: শেষ লক্ষ্য দিয়ে শুরু করুন';

  @override
  String get chatTipStateConstraints =>
      'পরামর্শ: এজেন্টকে যে সীমা মানতে হবে তা বলুন';

  @override
  String get chatTipStepByStep =>
      'পরামর্শ: জটিল সমস্যা ডিবাগ করার সময় ধাপে ধাপে জিজ্ঞাসা করুন';

  @override
  String get chatTipUseFocusedAgents =>
      'পরামর্শ: পরিকল্পনা, রিভিউ বা বিল্ডের জন্য ফোকাসড এজেন্ট বেছে নিন';

  @override
  String get chatToggleSidebars => 'সাইডবার টগল করুন';

  @override
  String chatTokensLabel(int total) {
    return 'টোকেন: $total';
  }

  @override
  String get chatTourProjectsConversations =>
      'আপনার প্রজেক্ট এবং কথোপকথন খুলতে এই বোতামটি ব্যবহার করুন।';

  @override
  String get chatTourSidebarProjectTools =>
      'কথোপকথন সাইডবার এবং প্রজেক্ট টুল দেখাতে এই মেনুটি ব্যবহার করুন।';

  @override
  String get chatTourSwitchFolders =>
      'প্রজেক্ট ফোল্ডার এবং প্রসঙ্গ পরিবর্তন করতে এই বোতামটি ব্যবহার করুন।';

  @override
  String get chatUndoLastTurn => 'শেষ মোড় পূর্বাবস্থায় ফেরান';

  @override
  String get chatUndoNothing => 'এই সেশনে পূর্বাবস্থায় ফিরিয়ে আনার কিছু নেই';

  @override
  String get chatUseCurrent => 'বর্তমান ব্যবহার করুন';

  @override
  String get chatWaitingForNetworkConnection =>
      'নেটওয়ার্ক সংযোগের জন্য অপেক্ষা করছে...';

  @override
  String get chatWelcomeMessage => 'হ্যালো! আমি আপনার AI সহায়ক।';

  @override
  String get chatWelcomeSubmessage => 'আজ আমি কিভাবে আপনাকে সাহায্য করতে পারি?';

  @override
  String get chatWorkBoundedPanelExplanation =>
      'চ্যাট ভিউপোর্ট স্থিতিশীল রাখতে সর্বশেষ টুল কার্যকলাপ এই আবদ্ধ প্যানেলের ভিতরে থাকে।';

  @override
  String get chatWorkExpand => 'প্রসারিত করুন';

  @override
  String get chatWorkHide => 'লুকান';

  @override
  String get chatWorkMessageOne => '1 কাজের বার্তা';

  @override
  String chatWorkMessagesMultiple(int count) {
    return '$count কাজের বার্তা';
  }

  @override
  String get chatWorkShow => 'দেখান';

  @override
  String get commonCancel => 'বাতিল করুন';

  @override
  String get commonCopiedToClipboard => 'ক্লিপবোর্ডে কপি করা হয়েছে';

  @override
  String get commonDelete => 'মুছে দিন';

  @override
  String get commonFile => 'ফাইল';

  @override
  String get commonReset => 'রিসেট করুন';

  @override
  String get commonSave => 'সংরক্ষণ করুন';

  @override
  String get compactionAutomatic => 'স্বয়ংক্রিয়';

  @override
  String get compactionManual => 'ম্যানুয়াল';

  @override
  String get composerAddAttachment => 'সংযুক্তি যোগ করুন';

  @override
  String get composerAttachFiles => 'ফাইল সংযুক্ত করুন';

  @override
  String get composerCannedAppendAtCursor => 'কার্সারে যোগ করুন';

  @override
  String get composerCannedLabel => 'লেবেল (ঐচ্ছিক)';

  @override
  String get composerCannedNoReplies => 'এখনও কোন দ্রুত উত্তর.';

  @override
  String get composerCannedReplace => 'প্রতিস্থাপন করুন';

  @override
  String get composerCannedSave => 'সংরক্ষণ করুন';

  @override
  String get composerCannedScopeGlobal => 'গ্লোবাল';

  @override
  String get composerCannedScopeProject => 'শুধুমাত্র প্রকল্প';

  @override
  String get composerCannedSendAutomatically => 'স্বয়ংক্রিয়ভাবে পাঠান';

  @override
  String get composerCannedText => 'পাঠ্য';

  @override
  String get composerChatInput => 'চ্যাট ইনপুট';

  @override
  String get composerDeleteAction => 'মুছে দিন';

  @override
  String get composerDropHint => 'সংযুক্ত করতে ছবি বা PDF ছাড়ুন';

  @override
  String get composerPastedImageName => 'পেস্ট করা ছবি';

  @override
  String get composerEdit => 'সম্পাদনা করুন';

  @override
  String get composerExtras => 'অতিরিক্ত';

  @override
  String get composerExtrasHide => 'অতিরিক্ত লুকান';

  @override
  String get composerNewQuickReply => 'নতুন দ্রুত উত্তর';

  @override
  String get composerSelectImages => 'ছবি নির্বাচন করুন';

  @override
  String get composerSelectPdf => 'PDF নির্বাচন করুন';

  @override
  String get composerSend => 'পাঠান';

  @override
  String get composerShellMode => 'শেল মোড';

  @override
  String get desktopWindowClose => 'বন্ধ';

  @override
  String get desktopWindowMaximize => 'ম্যাক্সিমাইজ';

  @override
  String get desktopWindowMinimize => 'মিনিমাইজ';

  @override
  String get desktopWindowRestore => 'পুনরুদ্ধার';

  @override
  String get dialogDownload => 'ডাউনলোড করুন';

  @override
  String get dialogLanguage => 'ভাষা';

  @override
  String get dialogMoonshineModelSize => 'মডেলের আকার';

  @override
  String get dialogMoonshineVoiceSetup => 'মুনশাইন ভয়েস সেটআপ';

  @override
  String get dialogParakeetModel => 'প্যারাকিট মডেল';

  @override
  String get dialogParakeetVoiceSetup => 'প্যারাকিট ভয়েস সেটআপ';

  @override
  String get dialogSenseVoiceModel => 'সেন্সভয়েস মডেল';

  @override
  String get dialogSenseVoiceSetup => 'সেন্সভয়েস সেটআপ';

  @override
  String get dialogVoiceInputSetup => 'ভয়েস ইনপুট সেটআপ';

  @override
  String get errorAnErrorOccurred => 'একটি ত্রুটি ঘটেছে';

  @override
  String get errorAuthRequired => 'প্রমাণীকরণ প্রয়োজন';

  @override
  String get errorAuthRequiredDesc =>
      'প্রমাণীকরণ ব্যর্থ হয়েছে। প্রদানকারীকে পুনরায় সংযোগ করুন এবং আবার চেষ্টা করুন।';

  @override
  String get errorConnectionFailed => 'সংযোগ ব্যর্থ হয়েছে';

  @override
  String get errorConnectionFailedDesc =>
      'সার্ভারের সাথে যোগাযোগ করতে অক্ষম। সংযোগ এবং সার্ভারের স্থিতি পরীক্ষা করুন।';

  @override
  String get errorFormatAuthenticationFailedReconnect =>
      'প্রমাণীকরণ ব্যর্থ হয়েছে৷ প্রদানকারীর সাথে পুনরায় সংযোগ করুন এবং আবার চেষ্টা করুন।';

  @override
  String get errorFormatProviderTemporarilyUnavailable =>
      'প্রদানকারী সাময়িকভাবে অনুপলব্ধ. শীঘ্রই আবার চেষ্টা করুন.';

  @override
  String get errorFormatQuotaExceededCheck =>
      'কোটা ছাড়িয়ে গেছে। আপনার প্রদানকারীর প্ল্যান বা বিলিং চেক করুন।';

  @override
  String get errorFormatRateLimitExceeded =>
      'হার সীমা অতিক্রম করেছে. কিছুক্ষণ অপেক্ষা করুন এবং আবার চেষ্টা করুন।';

  @override
  String get errorFormatServerErrorPlease =>
      'সার্ভার ত্রুটি. আবার চেষ্টা করুন.';

  @override
  String get errorFormatServiceTemporarilyUnavailable =>
      'পরিষেবা সাময়িকভাবে অনুপলব্ধ. সার্ভার শুরু হতে পারে — অনুগ্রহ করে শীঘ্রই আবার চেষ্টা করুন।';

  @override
  String get errorFormatUnableReachServer =>
      'সার্ভারে পৌঁছাতে অক্ষম। সংযোগ এবং সার্ভার স্থিতি পরীক্ষা করুন।';

  @override
  String get errorProviderUnavailable => 'প্রদানকারী অনুপলব্ধ';

  @override
  String get errorProviderUnavailableDesc =>
      'প্রদানকারী সাময়িকভাবে অনুপলব্ধ। শীঘ্রই আবার চেষ্টা করুন।';

  @override
  String get errorQuotaExceeded => 'কোটা অতিক্রম করেছে';

  @override
  String get errorQuotaExceededDesc =>
      'কোটা অতিক্রম করেছে। আপনার প্রদানকারী পরিকল্পনা বা বিলিং পরীক্ষা করুন।';

  @override
  String get errorRateLimitExceeded => 'রেট সীমা অতিক্রম করেছে';

  @override
  String get errorRateLimitExceededDesc =>
      'রেট সীমা অতিক্রম করেছে। কিছুক্ষণ অপেক্ষা করুন এবং আবার চেষ্টা করুন।';

  @override
  String get errorServerError => 'সার্ভার ত্রুটি';

  @override
  String get errorServerErrorDesc =>
      'সার্ভার ত্রুটি। অনুগ্রহ করে আবার চেষ্টা করুন।';

  @override
  String get errorServiceUnavailable => 'পরিষেবা অনুপলব্ধ';

  @override
  String get errorServiceUnavailableDesc =>
      'পরিষেবা সাময়িকভাবে অনুপলব্ধ। সার্ভারটি চালু হতে পারে — অনুগ্রহ করে শীঘ্রই আবার চেষ্টা করুন।';

  @override
  String get fileActionAttachmentDataDecoded =>
      'সংযুক্তি ডেটা ডিকোড করা যায়নি৷';

  @override
  String get fileActionAttachmentPathEmpty => 'সংযুক্তি পথ খালি।';

  @override
  String get fileActionAttachmentPayloadEmpty => 'সংযুক্তি পেলোড খালি৷';

  @override
  String get fileActionAttachmentProvideValid =>
      'সংযুক্তি একটি বৈধ অবস্থান প্রদান করে না.';

  @override
  String get fileActionAttachmentSavedDevice =>
      'এই ডিভাইসে সংযুক্তি সংরক্ষণ করা যায়নি৷';

  @override
  String fileActionAttachmentSavedOutputFile(String path) {
    return 'সংযুক্তি $path এ সংরক্ষিত এবং খোলা হয়েছে।';
  }

  @override
  String fileActionAttachmentSavedOutputFile2(String path) {
    return 'সংযুক্তি $path এ সংরক্ষিত হয়েছে।';
  }

  @override
  String fileActionAttachmentSavedSavedPath(String savedPath) {
    return 'সংযুক্তি $savedPath এ সংরক্ষিত হয়েছে।';
  }

  @override
  String get fileActionLocalAttachmentFound =>
      'এই ডিভাইসে স্থানীয় সংযুক্তি পাওয়া যায়নি।';

  @override
  String get fileActionSaveCanceled => 'সংরক্ষণ বাতিল করা হয়েছে।';

  @override
  String get fileActionUnableOpenLocal => 'স্থানীয় সংযুক্তি খুলতে অক্ষম৷';

  @override
  String get filesAddChat => 'চ্যাটে যোগ করুন';

  @override
  String get filesAutosave => 'স্বয়ংক্রিয় সংরক্ষণ';

  @override
  String get filesAutosaveOn => 'স্বয়ংক্রিয় সংরক্ষণ চালু';

  @override
  String get filesAutosaveOff => 'স্বয়ংক্রিয় সংরক্ষণ বন্ধ';

  @override
  String get filesRedo => 'পুনরায় করুন';

  @override
  String get filesUndo => 'পূর্বাবস্থা';

  @override
  String get filesBinaryFilePreview => 'বাইনারি ফাইল প্রিভিউ উপলব্ধ নয়।';

  @override
  String get filesClear => 'পরিষ্কার';

  @override
  String get filesContents => 'বিষয়বস্তু';

  @override
  String get filesDuplicate => 'ডুপ্লিকেট';

  @override
  String get filesDuplicated => 'ফাইল ডুপ্লিকেট হয়েছে';

  @override
  String get filesFileEmpty => 'ফাইলটি খালি।';

  @override
  String get filesAlreadyExists =>
      'একই নামে একটি ফাইল বা ফোল্ডার ইতিমধ্যে বিদ্যমান।';

  @override
  String get filesCopyPath => 'পাথ কপি করুন';

  @override
  String get filesCreateFileTitle => 'ফাইল তৈরি করুন';

  @override
  String get filesCreateFolderTitle => 'ফোল্ডার তৈরি করুন';

  @override
  String get filesDelete => 'মুছুন';

  @override
  String filesDeleteConfirm(String name) {
    return '$name মুছবেন? এটি আর ফিরিয়ে আনা যাবে না। ফোল্ডার এবং এর ভেতরের বিষয়বস্তু মুছে যাবে।';
  }

  @override
  String filesDeleteTitle(String name) {
    return '$name মুছুন';
  }

  @override
  String get filesFilesFound => 'কোন ফাইল পাওয়া যায়নি';

  @override
  String get filesFileCreated => 'ফাইল তৈরি হয়েছে।';

  @override
  String get filesFolderCreated => 'ফোল্ডার তৈরি হয়েছে।';

  @override
  String get filesHideSidebar => 'ফাইল সাইডবার লুকান';

  @override
  String get filesInvalidName => 'পাথ বিভাজক ছাড়া একটি বৈধ নাম লিখুন।';

  @override
  String get filesNameHint => 'নাম';

  @override
  String get filesNew => 'নতুন';

  @override
  String get filesNewFile => 'নতুন ফাইল';

  @override
  String get filesNewFolder => 'নতুন ফোল্ডার';

  @override
  String get filesNames => 'নাম';

  @override
  String filesOpenFilesFileState(int length) {
    return 'খোলা ফাইল ($length)';
  }

  @override
  String get filesQuickOpen => 'দ্রুত খুলুন';

  @override
  String get filesQuickOpenFile => 'দ্রুত খুলুন ফাইল';

  @override
  String get filesOperationFailed => 'ফাইল অপারেশন ব্যর্থ হয়েছে।';

  @override
  String get filesOperationUnavailable =>
      'এই সার্ভারের জন্য ফাইল অপারেশন উপলব্ধ নয়।';

  @override
  String get filesOutsideRoot => 'পাথটি প্রজেক্ট রুটের বাইরে।';

  @override
  String get filesPathCopied => 'পাথ কপি হয়েছে।';

  @override
  String get filesPathMissing => 'পাথটি বিদ্যমান নেই।';

  @override
  String get filesPermissionDenied => 'অনুমতি অস্বীকার করা হয়েছে।';

  @override
  String get filesRefresh => 'ফাইল রিফ্রেশ করুন';

  @override
  String get filesRename => 'নাম পরিবর্তন করুন';

  @override
  String filesRenameTitle(String name) {
    return '$name এর নাম পরিবর্তন করুন';
  }

  @override
  String get filesRenamed => 'নাম পরিবর্তন হয়েছে।';

  @override
  String get filesRootDeleteBlocked => 'প্রজেক্ট রুট মুছে ফেলা যাবে না।';

  @override
  String get filesSearchHint => 'নাম বা পথ দ্বারা ফাইল অনুসন্ধান করুন';

  @override
  String get filesDeleted => 'মুছে ফেলা হয়েছে।';

  @override
  String get filesTitle => 'ফাইল';

  @override
  String get forwardAction => 'ফরোয়ার্ড';

  @override
  String get forwardAllFailed => 'কোনো সেশনে ফরোয়ার্ড করা যায়নি';

  @override
  String get forwardCancel => 'বাতিল';

  @override
  String get forwardDialogSubtitle => 'এক বা একাধিক কথোপকথন নির্বাচন করুন';

  @override
  String get forwardDialogTitle => 'ফরোয়ার্ড করুন…';

  @override
  String get forwardLoading => 'সেশন লোড হচ্ছে…';

  @override
  String get forwardNoOpenProjects => 'সেশনসহ কোনো খোলা প্রজেক্ট নেই';

  @override
  String get forwardNoProviderModel =>
      'ফরোয়ার্ড করার আগে একটি প্রোভাইডার এবং মডেল নির্বাচন করুন';

  @override
  String get forwardNoSessions => 'কোনো সাম্প্রতিক সেশন নেই';

  @override
  String forwardPartial(int success, int total) {
    return '$total এর মধ্যে $successটিতে ফরোয়ার্ড করা হয়েছে';
  }

  @override
  String forwardProvenanceLabel(String origin) {
    return '$origin থেকে ফরোয়ার্ড করা হয়েছে';
  }

  @override
  String get forwardRetry => 'আবার চেষ্টা করুন';

  @override
  String get forwardSearchHint => 'অনুসন্ধান';

  @override
  String forwardSelectedCount(int count) {
    return '$countটি নির্বাচিত';
  }

  @override
  String get forwardSend => 'ফরোয়ার্ড';

  @override
  String get forwardServerOffline => 'সার্ভার অফলাইন';

  @override
  String get forwardShortcutHint => 'Ctrl+Shift+F';

  @override
  String forwardSuccess(int count) {
    return '$countটি সেশনে ফরোয়ার্ড করা হয়েছে';
  }

  @override
  String get forwardUndo => 'পূর্বাবস্থায় ফিরুন';

  @override
  String get forwardUndoFailed => 'ফরোয়ার্ড পূর্বাবস্থায় ফেরানো যায়নি';

  @override
  String get logsAppLogs => 'অ্যাপ লগ';

  @override
  String get logsClear => 'সাফ লগ';

  @override
  String get logsCloseSearch => 'অনুসন্ধান বন্ধ করুন';

  @override
  String get logsCopyFiltered => 'ফিল্টার করা লগ কপি করুন';

  @override
  String get logsEnableLogging => 'অ্যাপ লগ চালু করুন';

  @override
  String get logsEnableLoggingAction => 'লগ চালু করুন';

  @override
  String get logsEnableLoggingDescription =>
      'মেমরিতে ডায়াগনস্টিক লগ সংগ্রহ করে। সমস্যা সমাধান না করলে বন্ধ রাখুন।';

  @override
  String get logsEntryContext => 'প্রসঙ্গ';

  @override
  String get logsEntryTags => 'ট্যাগ';

  @override
  String get logsFilterAll => 'সব';

  @override
  String get logsFilterByTag => 'ট্যাগ';

  @override
  String get logsLevel => 'স্তর';

  @override
  String get logsLoggingDisabledDescription =>
      'CodeWalk বিস্তারিত অ্যাপ লগ সংগ্রহ করছে না। ডায়াগনস্টিক প্রয়োজন হলে তবেই লগ চালু করুন।';

  @override
  String get logsLoggingDisabledTitle => 'লগ বন্ধ আছে';

  @override
  String get logsMeasurePerformance => 'পারফরম্যান্স মাপুন';

  @override
  String get logsMeasurePerformanceDescription =>
      'অ্যাপের ব্যয়বহুল অপারেশনের সময় ধরে। ধীরগতি নির্ণয় ছাড়া বন্ধ রাখুন।';

  @override
  String get logsNoLogsYet => 'এখনও কোনো লগ ক্যাপচার করা হয়নি।';

  @override
  String get logsNoMatchingLogs =>
      'বর্তমান ফিল্টারগুলির সাথে কোনো লগ মিলছে না।';

  @override
  String get logsNoPerformanceData =>
      'বর্তমান ফিল্টারের সাথে কোনো পারফরম্যান্স লগ মেলে না।';

  @override
  String get logsNoTaskData => 'বর্তমান ফিল্টারের সাথে কোনো কাজ মেলে না।';

  @override
  String logsPerformanceDuration(int elapsedMs) {
    return '$elapsedMs ms';
  }

  @override
  String get logsPerformanceFilter => 'পারফরম্যান্স';

  @override
  String logsPerformanceTileTitle(
    int elapsedMs,
    String operation,
    String status,
  ) {
    return 'পারফরম্যান্স $operation | $elapsedMs ms | $status';
  }

  @override
  String get logsSearch => 'লগ অনুসন্ধান করুন';

  @override
  String logsShowingOrderedLength(int length, int length2) {
    return '$length2 টি এন্ট্রির মধ্যে $length টি দেখাচ্ছে';
  }

  @override
  String get logsSlowestPerformance => 'সবচেয়ে ধীর পারফরম্যান্স লগ';

  @override
  String get logsSlowestTasks => 'সবচেয়ে ধীর কাজ';

  @override
  String get logsTagCustomHint => 'ট্যাগের নাম (যেমন: task:select_session)';

  @override
  String get logsTagCustomAction => 'কাস্টম...';

  @override
  String logsTaskDuration(int elapsedMs, String operation) {
    return '$operation — $elapsedMs ms';
  }

  @override
  String get logsTaskStatusCanceled => 'বাতিল';

  @override
  String get logsTaskStatusError => 'ত্রুটি';

  @override
  String get logsTaskStatusOk => 'ঠিক আছে';

  @override
  String get logsTimeRange => 'সময় পরিসীমা';

  @override
  String get mathExpressionLabel => 'গণিত';

  @override
  String get mermaidCopySourceTooltip => 'কপি উৎস';

  @override
  String get mermaidDiagramLabel => 'মারমেইড ডায়াগ্রাম';

  @override
  String get modelAuto => 'অটো';

  @override
  String get modelChooseAgent => 'এজেন্ট নির্বাচন করুন';

  @override
  String get modelFavorites => 'প্রিয়';

  @override
  String get modelFree => 'বিনামূল্যে';

  @override
  String get modelLabelBaseEnglish => 'বেস (ইংরেজি)';

  @override
  String get modelLabelParakeet => 'Parakeet V3 (২৫টি ইউরোপীয় ভাষা)';

  @override
  String get modelLabelSenseVoice => 'SenseVoice (zh/en/ja/ko/yue)';

  @override
  String get modelLabelTinyEnglish => 'Tiny (ইংরেজি)';

  @override
  String get modelLoadingModels => 'মডেল লোড হচ্ছে';

  @override
  String get modelModelsFound => 'কোন মডেল পাওয়া যায়নি';

  @override
  String get modelRetryModels => 'মডেল পুনরায় চেষ্টা করুন';

  @override
  String get modelSearchHint => 'অনুসন্ধান মডেল বা প্রদানকারী';

  @override
  String get msgBatterySettingsFailed =>
      'অ্যান্ড্রয়েড ব্যাটারি অপ্টিমাইজেশান সেটিংস খুলতে পারেনি৷';

  @override
  String get msgBatterySettingsOpened =>
      'অ্যান্ড্রয়েড ব্যাটারি সেটিংস খোলা হয়েছে। CodeWalk-এর জন্য সীমাহীন ব্যাটারির অনুমতি দিন।';

  @override
  String get msgClearUsernameNeedsConfigEdit =>
      'OpenCode কথোপকথন ব্যবহারকারীর নাম সাফ করার জন্য এখনও অ্যাপের বাইরে কনফিগার সম্পাদনা প্রয়োজন।';

  @override
  String get msgCommandCopied => 'কমান্ড অনুলিপি করা হয়েছে';

  @override
  String get msgCopiedToClipboard => 'ক্লিপবোর্ডে কপি করা হয়েছে';

  @override
  String get msgEnterUsernameToSave =>
      'একটি কাস্টম OpenCode কথোপকথনের নাম সংরক্ষণ করতে একটি ব্যবহারকারীর নাম লিখুন৷';

  @override
  String get msgFailedToSendMessage =>
      'বার্তা পাঠাতে ব্যর্থ হয়েছে. খসড়া পুনরায় চেষ্টা করার জন্য রাখা হয়েছে।';

  @override
  String get msgFailedToStartVoiceInput =>
      'ভয়েস ইনপুট শুরু করতে ব্যর্থ হয়েছে৷';

  @override
  String msgFilePathNotFound(String path) {
    return 'ফাইল পাওয়া যায়নি: $path';
  }

  @override
  String get msgFilteredLogsCopied =>
      'ফিল্টার করা লগ ক্লিপবোর্ডে কপি করা হয়েছে';

  @override
  String get msgInfoAgent => 'এজেন্ট';

  @override
  String get msgInfoCompaction => 'কম্প্যাকশন';

  @override
  String msgInfoCost(String cost) {
    return 'খরচ: \$$cost';
  }

  @override
  String get msgInfoMessageInfo => 'বার্তা তথ্য';

  @override
  String msgInfoModel(String modelId) {
    return 'মডেল: $modelId';
  }

  @override
  String get msgInfoNoMetadata => 'কোন মেটাডেটা উপলব্ধ নেই';

  @override
  String msgInfoPartDescriptionModel(String description, String model) {
    return '$description$model';
  }

  @override
  String get msgInfoPatch => 'প্যাচ';

  @override
  String msgInfoProvider(String providerId) {
    return 'প্রদানকারী: $providerId';
  }

  @override
  String get msgInfoRetry => 'আবার চেষ্টা করুন';

  @override
  String get msgInfoSnapshot => 'স্ন্যাপশট';

  @override
  String msgInfoSubtaskPartAgent(String agent) {
    return 'সাবটাস্ক ($agent)';
  }

  @override
  String msgInfoTokens(int total) {
    return 'টোকেন: $total';
  }

  @override
  String get msgInfoUndoThisTurn => 'এই পালা পূর্বাবস্থায় ফেরান';

  @override
  String get msgInfoView => 'দেখুন';

  @override
  String get msgNoSystemSoundsFound =>
      'এই ডিভাইসে কোনো সিস্টেম সাউন্ড পাওয়া যায়নি।';

  @override
  String get msgNoValidFilesSelected => 'কোন বৈধ ফাইল নির্বাচন করা হয়নি';

  @override
  String get msgSomeSelectedFilesNotAttached =>
      'কিছু নির্বাচিত ফাইল সংযুক্ত করা যায়নি।';

  @override
  String get msgReadAloud => 'জোরে পড়ুন';

  @override
  String get msgReadAloudNotAvailable =>
      'এই ডিভাইসে টেক্সট-টু-স্পিচ উপলব্ধ নেই।';

  @override
  String get msgSetupDebugCopied =>
      'OpenCode সেটআপ ডিবাগ ক্লিপবোর্ডে কপি করা হয়েছে';

  @override
  String get msgShareAsImage => 'ছবি হিসেবে শেয়ার করুন';

  @override
  String get msgShareAsImageFailed => 'ছবি হিসেবে বার্তা শেয়ার করা যায়নি।';

  @override
  String get msgShareAsImageSubject => 'কোডওয়াক বার্তা';

  @override
  String get msgShareAsImageTooTall =>
      'বার্তাটি একটি চিত্র হিসাবে ভাগ করার জন্য খুব দীর্ঘ৷';

  @override
  String get msgStopReadAloud => 'পড়া বন্ধ করুন';

  @override
  String get msgSystemSoundPickerUnavailable =>
      'এই প্ল্যাটফর্মে সিস্টেম সাউন্ড পিকার উপলব্ধ নেই৷';

  @override
  String get msgUpdatedButRefreshFailed =>
      'সার্ভার সেটিং আপডেট করা হয়েছে, কিন্তু চ্যাট প্রদানকারীদের রিফ্রেশ করতে পারেনি।';

  @override
  String get msgVoiceInputUnavailable => 'এই ডিভাইসে ভয়েস ইনপুট অনুপলব্ধ৷';

  @override
  String get notifAndroidBatteryOptimization =>
      'অ্যান্ড্রয়েড ব্যাটারি অপ্টিমাইজেশান';

  @override
  String get notifConversationUpdates => 'কথোপকথন আপডেট';

  @override
  String get notifNotificationsArriveReopening =>
      'যদি শুধুমাত্র অ্যাপটি খোলার সময় বিজ্ঞপ্তি আসে, তাহলে এই ডিভাইসে অপ্টিমাইজেশন ছাড়াই CodeWalk চালানোর অনুমতি দিন।';

  @override
  String get notifResponseRunningKeep =>
      'যখন একটি প্রতিক্রিয়া চলছে, আপনি অ্যাপটি ছেড়ে যাওয়ার পরে সংক্ষেপে রিয়েলটাইম সক্রিয় রাখুন।';

  @override
  String notifSelectedSoundLabel(String soundLabel) {
    return 'নির্বাচিত: $soundLabel';
  }

  @override
  String get notificationAgentFinished =>
      'এজেন্ট বর্তমান প্রতিক্রিয়া শেষ করেছে।';

  @override
  String get notificationConversationUpdates => 'কথোপকথন আপডেট';

  @override
  String get notificationOpenToClear =>
      'সম্পর্কিত বিজ্ঞপ্তিগুলি মুছতে এই কথোপকথনটি খুলুন।';

  @override
  String get notificationSession => 'সেশন';

  @override
  String get notificationSoundLoadFailed =>
      'অ্যান্ড্রয়েড সিস্টেম সাউন্ড লোড করতে ব্যর্থ হয়েছে';

  @override
  String get onboardingAIGeneratedTitles => 'এআই শিরোনাম তৈরি করেছে';

  @override
  String get onboardingAddServerLater =>
      'আপনি পরে সেটিংস > সার্ভারে একটি সার্ভার যোগ করতে পারেন।';

  @override
  String get onboardingAddedButHealthCheckFailed =>
      'সার্ভার যোগ করা হয়েছে কিন্তু হেলথ চেক ব্যর্থ হয়েছে। এটি এখনও চালু হতে পারে।';

  @override
  String get onboardingAlmostInstallOpenCode =>
      'আপনি প্রায় আছে. প্রথমে OpenCode ইনস্টল করুন, তারপর CodeWalk কে সার্ভার URL এর সাথে সংযুক্ত করুন।';

  @override
  String onboardingAppProviderLocalSetupLogsLength(int length, int length2) {
    return '$lengthটি সেটআপ লগ লাইন এবং $length2টি সেটআপ ইভেন্ট আলাদা সেটআপ ডিবাগ স্ক্রিনে উপলব্ধ।';
  }

  @override
  String get onboardingAuthenticate => 'প্রমাণীকরণ';

  @override
  String get onboardingAvailable => 'উপলব্ধ';

  @override
  String get onboardingAvailableOnlyDesktop =>
      'শুধুমাত্র ডেস্কটপে (Linux/macOS/Windows) উপলব্ধ।';

  @override
  String get onboardingBasicAuthTip =>
      'আপনার OpenCode সার্ভার পাসওয়ার্ড সুরক্ষিত থাকলেই কেবল বেসিক অথ সক্ষম করুন।';

  @override
  String get onboardingChooseAnotherPath => 'অন্য পথ বেছে নিন';

  @override
  String get onboardingChooseHowToSetup =>
      'কিভাবে আপনার সার্ভার সেট আপ করবেন তা চয়ন করুন';

  @override
  String get onboardingClear => 'পরিষ্কার';

  @override
  String get onboardingCloudflareAuthFailed =>
      'Cloudflare Access প্রমাণীকরণ ব্যর্থ হয়েছে।';

  @override
  String get onboardingCodeWalkAppOpenCode =>
      'কোডওয়াক অ্যাপ। OpenCode হল একটি ইঞ্জিন যার সাথে এটি সংযোগ করে।';

  @override
  String get onboardingConnectRunningServer =>
      'একটি চলমান সার্ভারের সাথে সংযোগ করুন';

  @override
  String get onboardingConnectionIssue => 'সংযোগ সমস্যা';

  @override
  String get onboardingConnectionSaved =>
      'সার্ভার সংযোগ সফলভাবে সংরক্ষিত হয়েছে।';

  @override
  String get onboardingConnectionTips => 'সংযোগ টিপস';

  @override
  String get onboardingConnectionUpdated =>
      'সার্ভার সংযোগ সফলভাবে আপডেট করা হয়েছে।';

  @override
  String get onboardingContinue => 'চালিয়ে যান';

  @override
  String get onboardingContinueServerURL => 'সার্ভার URL এ চালিয়ে যান';

  @override
  String get onboardingCopyLoginURL => 'লগইন URL কপি করুন';

  @override
  String get onboardingCouldNotVerify => 'সার্ভার সংযোগ যাচাই করা যায়নি।';

  @override
  String get onboardingDefaultURLEmulator =>
      'ডিফল্ট URL, এমুলেটর লুপব্যাক, প্রমাণীকরণ এবং ডিবাগ সহায়তা।';

  @override
  String onboardingDesktopOnlyDiagnose(String appName) {
    return 'শুধুমাত্র ডেস্কটপ: $appName আপনার জন্য OpenCode নির্ণয়, ইনস্টল এবং চালাতে পারে।';
  }

  @override
  String get onboardingDetailedSetupEvents =>
      'সমস্যা সমাধানের জন্য বিস্তারিত সেটআপ ইভেন্ট ক্যাপচার করা হয়েছে।';

  @override
  String get onboardingDonShowAgain => 'আবার দেখাবেন না';

  @override
  String get onboardingDone => 'সম্পন্ন';

  @override
  String get onboardingEditServer => 'সার্ভার সম্পাদনা করুন';

  @override
  String get onboardingEditServerConnection => 'সার্ভার সংযোগ সম্পাদনা করুন';

  @override
  String get onboardingEmulatorRemap =>
      'অ্যান্ড্রয়েড এমুলেটরে, localhost এবং 127.0.0.1 স্বয়ংক্রিয়ভাবে 10.0.2.2-এ পুনরায় ম্যাপ করা হয়।';

  @override
  String get onboardingEnterServerUrl => 'একটি সার্ভার URL লিখুন';

  @override
  String get onboardingExisting => 'বিদ্যমান ব্যবহার করুন';

  @override
  String get onboardingExplainInstallOpenCode =>
      'কিভাবে OpenCode ইনস্টল করবেন, সার্ভার শুরু করবেন এবং তারপর CodeWalk থেকে সংযোগ করবেন তা ব্যাখ্যা করুন।';

  @override
  String get onboardingFailed => 'ব্যর্থ';

  @override
  String get onboardingGoodOptionDesktop => 'ডেস্কটপে ভাল প্রথম বিকল্প';

  @override
  String get onboardingHealthCheckFailedMayBeStarting =>
      'সার্ভার হেলথ চেক ব্যর্থ হয়েছে। এটি এখনও চালু হতে পারে।';

  @override
  String get onboardingInstallBinary => 'বাইনারি ইনস্টল করুন';

  @override
  String get onboardingInstallBun => 'Bun এর মাধ্যমে ইনস্টল করুন';

  @override
  String get onboardingInstallBunOpenCode => 'Bun + OpenCode ইনস্টল করুন';

  @override
  String get onboardingInstallNpm => 'npm এর মাধ্যমে ইনস্টল করুন';

  @override
  String get onboardingInstallRunOpenCode =>
      'ডেস্কটপে CodeWalk থেকে সরাসরি OpenCode ইনস্টল করুন এবং চালান।';

  @override
  String get onboardingInvalidUrl => 'অকার্যকর URL';

  @override
  String get onboardingLabel => 'লেবেল (ঐচ্ছিক)';

  @override
  String get onboardingLabelHint => 'আমার সার্ভার';

  @override
  String onboardingLatestOutputAppProvider(String localServerLastOutput) {
    return 'সর্বশেষ আউটপুট: $localServerLastOutput';
  }

  @override
  String get onboardingLetCodeWalkSet =>
      'কোডওয়াককে এটি স্থানীয়ভাবে সেট আপ করতে দিন';

  @override
  String get onboardingLocalServerSetup => 'স্থানীয় সার্ভার সেটআপ';

  @override
  String get onboardingManagedLocalServer => 'পরিচালিত স্থানীয় সার্ভার';

  @override
  String get onboardingManagedLocalServer2 =>
      'পরিচালিত স্থানীয় সার্ভার মোড শুধুমাত্র ডেস্কটপ বিল্ডে উপলব্ধ (Linux/macOS/Windows)।';

  @override
  String onboardingNeedsOpenCodeServer(String appName) {
    return '$appName-এর আপনার কোড সহ সহায়তা করার আগে একটি OpenCode সার্ভার প্রয়োজন।';
  }

  @override
  String get onboardingNotAvailable => 'উপলব্ধ নয়';

  @override
  String get onboardingNotWritable => 'লেখার যোগ্য নয়';

  @override
  String get onboardingOpenCode => 'OpenCode কি?';

  @override
  String get onboardingOpenCodeRunningDevice =>
      'আমার ইতিমধ্যেই এই ডিভাইসে বা আমার নেটওয়ার্কের কোথাও OpenCode চলছে৷';

  @override
  String get onboardingOpenCodeRunsLocally =>
      'OpenCode স্থানীয়ভাবে বা সার্ভারে চলে এবং CodeWalk-এর ভিতরে AI কোডিং বৈশিষ্ট্যগুলিকে ক্ষমতা দেয়৷ যদি OpenCode ইতিমধ্যেই চলছে, তাহলে এটির সাথে সংযোগ করুন। যদি না হয়, নীচের নির্দেশিত সেটআপ পাথগুলির মধ্যে একটি বেছে নিন।';

  @override
  String get onboardingOpenTailscaleLogin => 'টেলস্কেল লগইন URL খুলতে পারেনি৷';

  @override
  String get onboardingPassword => 'পাসওয়ার্ড';

  @override
  String get onboardingPasswordRequired => 'পাসওয়ার্ড লিখুন';

  @override
  String get onboardingPickSetupPath =>
      'আপনার বর্তমান OpenCode সেটআপের সাথে মেলে এমন সেটআপ পাথ চয়ন করুন।';

  @override
  String get onboardingPreconditionDirectoryNotWritable =>
      'ইনস্টলেশন ডিরেক্টরিটি লেখার যোগ্য (writable) নয়। ব্যবহারকারীর অনুমতি পরীক্ষা করুন।';

  @override
  String get onboardingPreconditionInstallViaBunRecommendation =>
      'OpenCode রক্ষণাবেক্ষণকারীদের দ্বারা Bun এর মাধ্যমে ইনস্টলেশন সুপারিশ করা হয়।';

  @override
  String get onboardingPreconditionNetworkFailed =>
      'নেটওয়ার্ক অ্যাক্সেস ব্যর্থ হয়েছে। OpenCode ইনস্টল করার আগে সংযোগ परीक्षा করুন।';

  @override
  String get onboardingPreconditionNoRuntimeDetected =>
      'কোনো রানটাইম সনাক্ত করা যায়নি। সরাসরি OpenCode বাইনারি ইনস্টল করুন অথবা প্রথমে Bun বুটস্ট্র্যাপ করুন।';

  @override
  String get onboardingPreconditionNodeNpmAvailable =>
      'Node + npm উপলব্ধ রয়েছে। npm এর মাধ্যমে OpenCode ইনস্টল করুন অথবা প্রস্তাবিত পদ্ধতির জন্য Bun ইনস্টল করুন।';

  @override
  String get onboardingPreconditionOpenCodeAlreadyAvailable =>
      'OpenCode ইতিমধ্যেই উপলব্ধ রয়েছে। আপনি সনাক্ত করা কমান্ডটি অবিলম্বে ব্যবহার করতে পারেন।';

  @override
  String get onboardingPreconditionWindowsPathLagHint =>
      ' Windows-এ, ইনস্টলেশনের পরে পরীক্ষাগুলি রিফ্রেশ করুন কারণ ইতিমধ্যে খোলা অ্যাপগুলিতে PATH আপডেট হতে কিছুটা সময় লাগতে পারে।';

  @override
  String get onboardingPreconditionWindowsWslRecommendation =>
      'Windows সংস্করণ সনাক্ত করা হয়েছে। OpenCode নথি অনুযায়ী WSL ব্যবহারের সুপারিশ করা হয়, তবে বিকল্প হিসেবে npm install ব্যবহার করা যেতে পারে।';

  @override
  String get onboardingReachable => 'পৌঁছানোযোগ্য';

  @override
  String get onboardingReady => 'প্রস্তুত';

  @override
  String get onboardingRecommendedOrderTry =>
      'প্রস্তাবিত অর্ডার: আপনি যদি CodeWalk আপনার জন্য সবকিছু বুটস্ট্র্যাপ করতে চান তবে Bun + OpenCode ইনস্টল করার চেষ্টা করুন। ওপেনকোড ইতিমধ্যে ইনস্টল করা থাকলে বিদ্যমান ব্যবহার করুন।';

  @override
  String get onboardingRefreshChecks => 'রিফ্রেশ চেক';

  @override
  String get onboardingRunDiagnosticsToVerify =>
      'স্থানীয় OpenCode প্রয়োজনীয়তা যাচাই করতে ডায়াগনস্টিকস চালান।';

  @override
  String get onboardingSaveAndTest => 'সংরক্ষণ করুন এবং পরীক্ষা করুন';

  @override
  String get onboardingServerConnectedReady =>
      'আপনার সার্ভার সংযুক্ত এবং ব্যবহারের জন্য প্রস্তুত।';

  @override
  String get onboardingServerConnection => 'সার্ভার সংযোগ';

  @override
  String get onboardingServerSettingsSaved =>
      'আপনার সার্ভার সেটিংস সংরক্ষিত হয়েছে এবং হেলথ চেক রিফ্রেশ করা হয়েছে।';

  @override
  String get onboardingServerSetup => 'সার্ভার সেটআপ';

  @override
  String get onboardingServerUpdated => 'সার্ভার আপডেট করা হয়েছে';

  @override
  String get onboardingServerUrl => 'সার্ভার URL';

  @override
  String get onboardingSetup => 'সেটআপ';

  @override
  String get onboardingSetupWizard => 'সেটআপ উইজার্ড';

  @override
  String get onboardingShowSetupSteps => 'আমাকে সেটআপ পদক্ষেপ দেখান';

  @override
  String get onboardingShowSetupSteps2 => 'সেটআপের ধাপগুলি দেখান';

  @override
  String get onboardingSkip => 'আপাতত এড়িয়ে যান';

  @override
  String get onboardingSkipSetup => 'সেটআপ এড়িয়ে যাবেন?';

  @override
  String get onboardingStart => 'শুরু করুন';

  @override
  String onboardingStartUsing(String appName) {
    return '$appName ব্যবহার শুরু করুন';
  }

  @override
  String get onboardingStarting => 'শুরু হচ্ছে';

  @override
  String get onboardingStop => 'থামো';

  @override
  String get onboardingStopped => 'বন্ধ';

  @override
  String get onboardingStopping => 'বন্ধ হচ্ছে';

  @override
  String onboardingSuggestedUrl(String url) {
    return 'প্রস্তাবিত স্থানীয় OpenCode সার্ভার URL: $url';
  }

  @override
  String get onboardingTailscaleAdminApproval =>
      'Tailscale অ্যাডমিন অনুমোদন প্রয়োজন';

  @override
  String get onboardingTailscaleAuthAfterSave =>
      'সংরক্ষণের পরে Tailscale প্রমাণীকরণ করা হবে';

  @override
  String onboardingTailscaleAuthAfterSaveTest(String appName) {
    return 'আপনি এই সার্ভারটি সংরক্ষণ এবং পরীক্ষা করার পরে, এই ডিভাইসটি এখনও প্রমাণীকৃত না হলে $appName Tailscale লগইন খুলবে।';
  }

  @override
  String get onboardingTailscaleConnected => 'Tailscale সংযুক্ত';

  @override
  String get onboardingTailscaleConnecting => 'Tailscale সংযোগ করছে';

  @override
  String get onboardingTailscaleConnectionFailed =>
      'Tailscale সংযোগ ব্যর্থ হয়েছে';

  @override
  String get onboardingTailscaleLoginRequired => 'Tailscale লগইন প্রয়োজন';

  @override
  String get onboardingTailscaleOpenLoginUrl =>
      'এই ডিভাইসটিকে আপনার tailnet-এ যোগ করতে লগইন URL খুলুন। ব্রাউজার না খুললে নিচের URL-টি কপি করুন।';

  @override
  String get onboardingTailscaleUnsupported => 'Tailscale অসমর্থিত';

  @override
  String get onboardingTestConnection => 'সংযোগ পরীক্ষা করুন';

  @override
  String get onboardingTesting => 'পরীক্ষা করা হচ্ছে...';

  @override
  String get onboardingUnreachable => 'অপ্রাপ্য';

  @override
  String get onboardingUseBasicAuth => 'মৌলিক প্রমাণীকরণ ব্যবহার করুন';

  @override
  String get onboardingUsername => 'ব্যবহারকারীর নাম';

  @override
  String get onboardingUsernameRequired => 'ব্যবহারকারীর নাম লিখুন';

  @override
  String get onboardingUsesServerTitle =>
      'কথোপকথনের নাম দিতে আপনার সার্ভারের শিরোনাম এজেন্ট ব্যবহার করে';

  @override
  String get onboardingUsingDetectedCommand =>
      'সনাক্ত করা OpenCode কমান্ড ব্যবহার করা হচ্ছে।';

  @override
  String get onboardingViewSetupDebug => 'সেটআপ ডিবাগ দেখুন';

  @override
  String onboardingWelcomeTo(String appName) {
    return '$appName-এ স্বাগতম';
  }

  @override
  String get onboardingWindowsTipInstalling =>
      'উইন্ডোজ টিপ: ইনস্টল করার পরে, রিফ্রেশ চেক ক্লিক করুন। সনাক্তকরণ এখনও ব্যর্থ হলে, PATH পরিবর্তনগুলি পুনরায় লোড করতে CodeWalk পুনরায় খুলুন৷';

  @override
  String get onboardingWritable => 'লেখার যোগ্য';

  @override
  String get onboardingYoureAllSet => 'আপনি সম্পূর্ণ প্রস্তুত!';

  @override
  String get permissionAllowOnce => 'একবার অনুমতি দিন';

  @override
  String get permissionAlways => 'সর্বদা';

  @override
  String get permissionBack => 'ব্যাক';

  @override
  String get permissionConfirmReject => 'প্রত্যাখ্যান নিশ্চিত করুন';

  @override
  String get permissionReject => 'প্রত্যাখ্যান করুন';

  @override
  String get permissionReopen => 'আবার খুলুন';

  @override
  String get questionAnswerSelected => 'কোনো উত্তর নির্বাচন করা হয়নি।';

  @override
  String get questionCommaSeparatedValues => 'কমা দ্বারা পৃথক করা মান';

  @override
  String get questionQuestionGroupMarked =>
      'প্রশ্ন গ্রুপ প্রত্যাখ্যাত হিসাবে চিহ্নিত করা হয়েছে. আপনি চ্যাটিং চালিয়ে যেতে পারেন এবং নিশ্চিত করার আগে যেকোনো সময় এই গ্রুপটি আবার খুলতে পারেন।';

  @override
  String get questionQuestionRequest => 'প্রশ্ন অনুরোধ';

  @override
  String get questionQuestionsProvidedSubmit =>
      'কোন প্রশ্ন প্রদান করা হয় না. আপনি একটি খালি প্রতিক্রিয়া জমা দিতে পারেন.';

  @override
  String get questionReviewAnswersSubmitting =>
      'জমা দেওয়ার আগে আপনার উত্তর পর্যালোচনা করুন.';

  @override
  String get quotaAuthCookie => 'প্রমাণ কুকি';

  @override
  String get quotaConnect => 'সংযোগ করুন';

  @override
  String get quotaForget => 'ভুলে যাও';

  @override
  String get quotaOpenCodeGoConnectDescription =>
      'ব্যবহারের ড্যাশবোর্ড সংযোগ করুন যাতে চলমান, সাপ্তাহিক ও মাসিক সীমা দেখা যায়।';

  @override
  String get quotaOpenCodeGoDetected => 'OpenCode Go শনাক্ত হয়েছে';

  @override
  String get quotaOpenCodeGoNeedsReconnect => 'OpenCode Go পুনরায় সংযোগ দরকার';

  @override
  String get quotaOpenCodeGoReconnectDescription =>
      'ব্যবহারের বার ফিরিয়ে আনতে ড্যাশবোর্ডের পরিচয়পত্র রিফ্রেশ করুন।';

  @override
  String get quotaOpenCodeGoUsage => 'OpenCode Go ব্যবহার';

  @override
  String get quotaOpenDashboard => 'OpenCode ড্যাশবোর্ড খুলুন';

  @override
  String get quotaPaceExplanation =>
      'বর্তমান হারের ভিত্তিতে বর্তমান সীমা উইন্ডোর শেষে মোট ব্যবহার কত হবে তা গতি অনুমান করে।';

  @override
  String quotaPacePercent(String percent) {
    return 'গতি $percent%';
  }

  @override
  String get quotaRateLimits => 'কোটা';

  @override
  String get quotaReconnect => 'পুনরায় সংযোগ করুন';

  @override
  String get quotaRefreshing => 'আপডেট হচ্ছে...';

  @override
  String quotaResetsIn(String time) {
    return '$time পরে রিসেট হবে';
  }

  @override
  String get quotaSaving => 'সংরক্ষণ করা হচ্ছে...';

  @override
  String get quotaWorkspaceId => 'ওয়ার্কস্পেস আইডি';

  @override
  String get serverClearOAuth => 'OAuth সাফ করুন';

  @override
  String get serverConnectionAttention => 'সার্ভার সংযোগে মনোযোগ প্রয়োজন।';

  @override
  String get serverHealthHealthy => 'স্বাস্থ্যকর';

  @override
  String get serverHealthUnhealthy => 'অস্বাস্থ্যকর';

  @override
  String get serverHealthUnknown => 'অজানা';

  @override
  String get serverOAuthAuthFailed => 'OAuth প্রমাণীকরণ ব্যর্থ হয়েছে৷';

  @override
  String get serverOAuthChip => 'OAuth';

  @override
  String get serverOAuthNotSupported =>
      'Cloudflare অ্যাক্সেস OAuth এই প্ল্যাটফর্মে সমর্থিত নয়';

  @override
  String get serverReauthenticate => 'পুনরায় প্রমাণীকরণ করুন';

  @override
  String get serverTailscaleChip => 'টেলস্কেল';

  @override
  String get serversActive => 'সক্রিয়';

  @override
  String get serversActiveServer => 'সক্রিয় সার্ভার';

  @override
  String get serversAddLeastOpenCode =>
      'অ্যাপ ব্যবহার শুরু করতে অন্তত একটি OpenCode সার্ভার যোগ করুন।';

  @override
  String get serversAddServer => 'সার্ভার যোগ করুন';

  @override
  String get serversCancel => 'বাতিল করুন';

  @override
  String get serversCannotActivateUnhealthy =>
      'একটি অস্বাস্থ্যকর সার্ভার সক্রিয় করা যাবে না';

  @override
  String get serversCheckHealth => 'স্বাস্থ্য পরীক্ষা করুন';

  @override
  String get serversClearDefault => 'ডিফল্ট সাফ করুন';

  @override
  String serversCommandAppProviderLocalServerCommandPath(
    String localServerCommandPath,
  ) {
    return 'কমান্ড: $localServerCommandPath';
  }

  @override
  String get serversCopy => 'কপি';

  @override
  String get serversDefault => 'ডিফল্ট';

  @override
  String get serversDelete => 'মুছে দিন';

  @override
  String get serversDeleteServer => 'সার্ভার মুছুন';

  @override
  String get serversDesktopModeExplanation =>
      'ডেস্কটপ মোড CodeWalk থেকে সরাসরি `opencode serve` চালু এবং পরিচালনা করতে পারে।';

  @override
  String get serversEdit => 'সম্পাদনা করুন';

  @override
  String get serversLocalOpenCodeServer => 'স্থানীয় ওপেনকোড সার্ভার';

  @override
  String get serversManagedModeAvailable =>
      'এই পরিচালিত মোড শুধুমাত্র ডেস্কটপ বিল্ডে উপলব্ধ (Linux/macOS/Windows)।';

  @override
  String get serversNoServersFound => 'কোনো সার্ভার পাওয়া যায়নি';

  @override
  String get serversRefreshHealth => 'স্বাস্থ্য রিফ্রেশ';

  @override
  String serversRemoveProfileDisplayName(String displayName) {
    return '\"$displayName\" সরাবেন?';
  }

  @override
  String get serversSearchActiveHint => 'সক্রিয় সার্ভার অনুসন্ধান করুন';

  @override
  String get serversServersConfigured => 'কোন সার্ভার কনফিগার করা নেই';

  @override
  String get serversSetActive => 'সক্রিয় সেট করুন';

  @override
  String get serversSetDefault => 'ডিফল্ট সেট করুন';

  @override
  String get serversSetupDebug => 'ডিবাগ সেটআপ করুন';

  @override
  String get serversSetupWizard => 'সেটআপ উইজার্ড';

  @override
  String get serversTailscaleAdminApprovalRequired =>
      'Tailscale প্রশাসকের অনুমোদন প্রয়োজন';

  @override
  String get serversTailscaleAuthRequired => 'Tailscale প্রমাণীকরণ প্রয়োজন';

  @override
  String get serversTailscaleConnectExplanation =>
      'এই সক্রিয় প্রোফাইল ব্যবহার করলে Tailscale সংযুক্ত হবে।';

  @override
  String get serversTailscaleConnected => 'Tailscale সংযুক্ত';

  @override
  String get serversTailscaleConnecting => 'Tailscale সংযোগ হচ্ছে';

  @override
  String get serversTailscaleConnectionFailed =>
      'Tailscale সংযোগ ব্যর্থ হয়েছে';

  @override
  String get serversTailscaleDisconnected => 'Tailscale সংযোগ বিচ্ছিন্ন';

  @override
  String get serversTailscaleLoginExplanation =>
      'আপনার tailnet-এ এই ডিভাইসটি যোগ করতে Tailscale লগইন URL খুলুন।';

  @override
  String get serversTailscaleTrafficExplanation =>
      'এই সক্রিয় প্রোফাইলের জন্য OpenCode ট্রাফিক Tailscale-এর মাধ্যমে রুট করা হয়।';

  @override
  String get serversTailscaleUnsupported => 'Tailscale সমর্থিত নয়';

  @override
  String get serversUnhealthyActivateError =>
      'এই সার্ভারটি অস্বাস্থ্যকর। সক্রিয় করার আগে স্বাস্থ্য পরীক্ষা করুন বা সেটিংস সম্পাদনা করুন।';

  @override
  String get sessionActionArchived => 'সংরক্ষণাগারভুক্ত';

  @override
  String get sessionActionDeleted => 'মুছে ফেলা';

  @override
  String get sessionActionForked => 'কাঁটাযুক্ত';

  @override
  String get sessionActionPinned => 'পিন করা';

  @override
  String get sessionActionUnarchived => 'অসংরক্ষিত';

  @override
  String get sessionActionUnpinned => 'আনপিন করা';

  @override
  String get sessionArchive => 'আর্কাইভ করুন';

  @override
  String get sessionCancelRename => 'নাম পরিবর্তন বাতিল করুন';

  @override
  String sessionChildrenCount(int count) {
    return 'উপ-কথোপকথন: $count';
  }

  @override
  String get sessionCompactContext => 'প্রসঙ্গ কম্প্যাক্ট করুন';

  @override
  String get sessionCopyLink => 'শেয়ার লিংক কপি করুন';

  @override
  String get sessionDelete => 'মুছে দিন';

  @override
  String sessionDeleteConfirm(String title) {
    return 'আপনি কি নিশ্চিত যে \"$title\" কথোপকথনটি মুছে ফেলতে চান? এই কাজটি পূর্বাবস্থায় ফেরানো যাবে না।';
  }

  @override
  String get sessionDeleteTitle => 'কথোপকথন মুছুন';

  @override
  String get sessionDiffChangedFile => 'পরিবর্তিত ফাইল';

  @override
  String get sessionDiffContentNotCaptured =>
      'ফাইলের বিষয়বস্তু সার্ভার দ্বারা ক্যাপচার করা হয়নি';

  @override
  String sessionDiffFilesChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count টি ফাইল পরিবর্তিত হয়েছে',
      one: '১টি ফাইল পরিবর্তিত হয়েছে',
    );
    return '$_temp0';
  }

  @override
  String sessionDiffFilesCount(int count) {
    return 'ডিফ ফাইল: $count';
  }

  @override
  String sessionDiffLinesAddedRemoved(int added, int removed) {
    return '+$added লাইন যোগ করা হয়েছে -$removed লাইন সরানো হয়েছে';
  }

  @override
  String sessionDiffLinesCollapsed(int count) {
    return '$count লাইনগুলি ভেঙে গেছে — প্রসারিত করতে আলতো চাপুন৷';
  }

  @override
  String get sessionDiffLoading => 'পরিবর্তিত ফাইল লোড হচ্ছে…';

  @override
  String get sessionDiffReview => 'পরিবর্তনগুলি পর্যালোচনা করুন';

  @override
  String get sessionDiffSplit => 'বিভক্ত';

  @override
  String get sessionDiffSummary => 'সারাংশ';

  @override
  String get sessionDiffUnified => 'ঐক্যবদ্ধ';

  @override
  String get sessionExportAssistant => 'সহকারী';

  @override
  String get sessionExportCanceled => 'সেশন এক্সপোর্ট বাতিল করা হয়েছে';

  @override
  String get sessionExportDebugJson => 'ডিবাগ JSON এক্সপোর্ট';

  @override
  String get sessionExportDebugJsonErrorClipboard =>
      'ফাইল সংরক্ষণ করা যায়নি; ডিবাগ JSON ক্লিপবোর্ডে কপি করা হয়েছে';

  @override
  String get sessionExportDebugJsonSaved =>
      'ডিবাগ JSON এক্সপোর্ট সংরক্ষিত হয়েছে';

  @override
  String get sessionExportDebugJsonTitle =>
      'সেশন ডিবাগ JSON হিসাবে এক্সপোর্ট করুন';

  @override
  String get sessionExportError => 'ত্রুটি:';

  @override
  String get sessionExportInput => 'ইনপুট:';

  @override
  String get sessionExportMarkdown => 'Markdown এক্সপোর্ট';

  @override
  String get sessionExportMarkdownErrorClipboard =>
      'ফাইল সংরক্ষণ করা যায়নি; Markdown ক্লিপবোর্ডে কপি করা হয়েছে';

  @override
  String get sessionExportMarkdownSaved => 'Markdown এক্সপোর্ট সংরক্ষিত হয়েছে';

  @override
  String get sessionExportMarkdownTitle =>
      'সেশন Markdown হিসাবে এক্সপোর্ট করুন';

  @override
  String get sessionExportOutput => 'আউটপুট:';

  @override
  String get sessionExportUntitled => 'শিরোনামহীন সেশন';

  @override
  String get sessionExportUser => 'ব্যবহারকারী';

  @override
  String get sessionFailedRename =>
      'কথোপকথনের নাম পরিবর্তন করতে ব্যর্থ হয়েছে৷';

  @override
  String get sessionFailedUpdateArchive =>
      'সংরক্ষণাগার অবস্থা আপডেট করতে ব্যর্থ হয়েছে';

  @override
  String get sessionFailedUpdateSharing =>
      'ভাগ করার অবস্থা আপডেট করতে ব্যর্থ হয়েছে৷';

  @override
  String get sessionFork => 'কাঁটা';

  @override
  String get sessionForkFailed => 'কথোপকথন ফর্ক করতে ব্যর্থ';

  @override
  String get sessionForked => 'কথোপকথন ফর্ক করা হয়েছে';

  @override
  String sessionHasError(String title) {
    return '\"$title\"-এ একটি ত্রুটি আছে।';
  }

  @override
  String sessionHasNewReply(String title) {
    return '\"$title\"-এ একটি নতুন উত্তর আছে।';
  }

  @override
  String get sessionKeyboardShortcuts => 'কীবোর্ড শর্টকাট';

  @override
  String sessionNeedsInput(String title) {
    return '\"$title\" আপনার ইনপুট প্রয়োজন।';
  }

  @override
  String get sessionNoCachedConversations => 'এখনও কোনো ক্যাশ করা কথোপকথন নেই';

  @override
  String get sessionNoConversationsInProject =>
      'এই প্রজেক্টে কোনো কথোপকথন নেই।';

  @override
  String get sessionNotAvailable =>
      'এই প্রকল্পের জন্য কথোপকথন এখনও উপলব্ধ নয়৷';

  @override
  String get sessionOpenProjectToLoad => 'কথোপকথন লোড করতে প্রজেক্ট খুলুন।';

  @override
  String get sessionPin => 'পিন করুন';

  @override
  String get sessionRename => 'নাম পরিবর্তন করুন';

  @override
  String get sessionRenameHint => 'নতুন কথোপকথনের নাম লিখুন';

  @override
  String get sessionRenameTitle => 'কথোপকথনের নাম পরিবর্তন করুন';

  @override
  String get sessionSaveTitle => 'শিরোনাম সংরক্ষণ করুন';

  @override
  String get sessionShare => 'সেশন শেয়ার করুন';

  @override
  String get sessionShareAction => 'শেয়ার করুন';

  @override
  String get sessionShareLinkCopied => 'শেয়ার লিঙ্ক কপি করা হয়েছে';

  @override
  String get sessionShareLinkUnavailable =>
      'এই সেশনের জন্য শেয়ার লিংক উপলব্ধ নয়';

  @override
  String get sessionShared => 'কথোপকথন শেয়ার করা হয়েছে';

  @override
  String get sessionSyncing => 'কথোপকথন সিঙ্ক হচ্ছে...';

  @override
  String get sessionTitleHint => 'কথোপকথনের শিরোনাম';

  @override
  String get sessionUnarchive => 'আর্কাইভ থেকে সরান';

  @override
  String get sessionUnpin => 'আনপিন করুন';

  @override
  String get sessionUnshare => 'সেশন শেয়ারিং বাতিল করুন';

  @override
  String get sessionUnshareAction => 'শেয়ার বন্ধ করুন';

  @override
  String get sessionUnshared => 'কথোপকথনের শেয়ারিং বাতিল করা হয়েছে';

  @override
  String get sessionViewTasks => 'টাস্ক দেখুন';

  @override
  String get settingsAboutCheckForUpdates => 'আপডেটের জন্য চেক করুন';

  @override
  String get settingsAboutCheckOnOpen => 'খোলার আপডেটের জন্য চেক করুন';

  @override
  String get settingsAboutCheckOnOpenDescription =>
      'অ্যাপটি শুরু হলে স্বয়ংক্রিয়ভাবে পরীক্ষা করুন';

  @override
  String get settingsAboutChecking => 'পরীক্ষা করা হচ্ছে...';

  @override
  String get settingsAboutDescription =>
      'সংস্করণ, আপডেট, সহায়তা এবং অ্যাপের তথ্য';

  @override
  String get settingsAboutDismiss => 'খারিজ';

  @override
  String settingsAboutDownloading(String percent) {
    return 'ডাউনলোড হচ্ছে... $percent%';
  }

  @override
  String get settingsAboutEraseAllData =>
      'সমস্ত ডেটা মুছুন এবং পুনরায় চালু করুন';

  @override
  String get settingsAboutInstallUpdate => 'আপডেট ইনস্টল করুন';

  @override
  String get settingsAboutInstalling => 'ইনস্টল করা হচ্ছে...';

  @override
  String settingsAboutLatestVersion(String version) {
    return 'v$version সর্বশেষ সংস্করণ';
  }

  @override
  String get settingsAboutLoading => 'লোড হচ্ছে...';

  @override
  String get settingsAboutReplayChatTour => 'চ্যাট ট্যুর রিপ্লে করুন';

  @override
  String get settingsAboutReplayChatTourDescription =>
      'সেটিংস বন্ধ করুন এবং নির্দেশিত চ্যাট ওয়াকথ্রু দেখান';

  @override
  String get settingsAboutResetApp => 'অ্যাপ রিসেট করুন';

  @override
  String get settingsAboutResetAppQuestion => 'অ্যাপ রিসেট করবেন?';

  @override
  String get settingsAboutResetAppWarning =>
      'এটি সমস্ত সার্ভার, সেটিংস এবং ক্যাশে করা ডেটা মুছে ফেলবে৷ এই ক্রিয়াটি পূর্বাবস্থায় ফেরানো যাবে না৷';

  @override
  String get settingsAboutRetryInstall => 'পুনরায় ইনস্টল করার চেষ্টা করুন';

  @override
  String get settingsAboutTapToCheck =>
      'নতুন সংস্করণগুলি পরীক্ষা করতে আলতো চাপুন৷';

  @override
  String get settingsAboutTitle => 'সম্পর্কে';

  @override
  String get settingsAboutUpToDate => 'আপনি আপ টু ডেট';

  @override
  String settingsAboutUpdateAvailable(String version) {
    return 'আপডেট উপলব্ধ: v$version';
  }

  @override
  String get settingsAboutUpdateInstalled =>
      'আপডেট ইনস্টল করা হয়েছে। আবেদন করতে অ্যাপটি পুনরায় চালু করুন।';

  @override
  String settingsAboutUpdateVersionSummary(
    String installedVersion,
    String latestVersion,
  ) {
    return 'বর্তমান: $installedVersion; উপলব্ধ: v$latestVersion';
  }

  @override
  String get settingsAboutVersion => 'সংস্করণ';

  @override
  String settingsAboutVersionBuild(String buildNumber, String version) {
    return '$version (বিল্ড $buildNumber)';
  }

  @override
  String get settingsAppearanceAmoledDark => 'AMOLED অন্ধকার মোড';

  @override
  String get settingsAppearanceAmoledDarkActive =>
      'অন্ধকার মোড সক্রিয় থাকাকালীন খাঁটি কালো পৃষ্ঠ ব্যবহার করুন।';

  @override
  String get settingsAppearanceAmoledDarkInactive =>
      'AMOLED সারফেস চালু করতে ডার্ক মোডে স্যুইচ করুন।';

  @override
  String get settingsAppearanceBrandColor => 'ব্র্যান্ড রঙ';

  @override
  String get settingsAppearanceBrandColorDynamicBlocked =>
      'একটি ব্র্যান্ডের রঙ বাছাই করতে ওয়ালপেপারের রঙগুলি অক্ষম করুন৷';

  @override
  String get settingsAppearanceBrandColorNormal =>
      'অ্যাপ প্যালেটের জন্য একটি বীজের রঙ বেছে নিন।';

  @override
  String get settingsAppearanceBrandColorPresetBlocked =>
      'একটি ব্র্যান্ডের রঙ বাছাই করতে CodeWalk Classic-এ স্যুইচ করুন।';

  @override
  String get settingsAppearanceChatFontScale => 'কথোপকথনের টেক্সটের আকার';

  @override
  String get settingsAppearanceChatFontScaleDescription =>
      'সিস্টেম টেক্সটের আকারের উপর চ্যাট বার্তা এবং কম্পোজার টেক্সটের আকার বাড়ান বা কমান।';

  @override
  String get settingsAppearanceCodeWalkClassic => 'কোডওয়াক ক্লাসিক';

  @override
  String get settingsAppearanceComposerTips => 'সুরকার টিপস';

  @override
  String get settingsAppearanceComposerTipsDescription =>
      'সহকারী যখন যুক্তি দিচ্ছে তখন ঘোরানো টিপস দেখান বা লুকান৷';

  @override
  String get settingsAppearanceContrast => 'বৈপরীত্য';

  @override
  String get settingsAppearanceContrastDynamicBlocked =>
      'বৈসাদৃশ্য সামঞ্জস্য করতে ওয়ালপেপার রং অক্ষম করুন।';

  @override
  String get settingsAppearanceContrastHigh => 'উচ্চ';

  @override
  String get settingsAppearanceContrastNormal =>
      'রঙের স্কিমের বৈসাদৃশ্য স্তর সামঞ্জস্য করুন।';

  @override
  String get settingsAppearanceContrastPresetBlocked =>
      'বৈসাদৃশ্য সামঞ্জস্য করতে CodeWalk ক্লাসিকে স্যুইচ করুন।';

  @override
  String get settingsAppearanceContrastReduced => 'হ্রাস করা হয়েছে';

  @override
  String get settingsAppearanceDark => 'অন্ধকার';

  @override
  String get settingsAppearanceDensity => 'ঘনত্ব';

  @override
  String get settingsAppearanceDensityDense => 'ঘন';

  @override
  String get settingsAppearanceDensityDescription =>
      'অ্যাপ জুড়ে ব্যবধান এবং উপাদানের ঘনত্ব প্রয়োগ করুন।';

  @override
  String get settingsAppearanceDensityExtraDense => 'অতিরিক্ত ঘন';

  @override
  String get settingsAppearanceDensityExtraSpacious => 'অতিরিক্ত প্রশস্ত';

  @override
  String get settingsAppearanceDensityNormal => 'স্বাভাবিক';

  @override
  String get settingsAppearanceDensitySpacious => 'প্রশস্ত';

  @override
  String get settingsAppearanceDescription =>
      'থিম, রঙ, টেক্সট সাইজ এবং চ্যাট প্রদর্শন চয়ন করুন';

  @override
  String get settingsAppearanceFontSize => 'টেক্সটের আকার';

  @override
  String get settingsAppearanceFontSizeDescription =>
      'সিস্টেম টেক্সট, কথোপকথনের টেক্সট এবং টার্মিনাল টেক্সটের আকার সামঞ্জস্য করুন।';

  @override
  String get settingsAppearanceLight => 'আলো';

  @override
  String get settingsAppearanceMathRendering => 'গণিত রেন্ডারিং';

  @override
  String get settingsAppearanceMathRenderingDescription =>
      'চ্যাট বার্তায় LaTeX গণিত রাশিগুলিকে টাইপসেট সমীকরণ হিসেবে রেন্ডার করুন।';

  @override
  String get settingsAppearanceNoPresets =>
      'কোনো প্রিসেট প্যালেট পাওয়া যায়নি';

  @override
  String get settingsAppearanceOpenCodePresets => 'ওপেনকোড প্রিসেট';

  @override
  String get settingsAppearancePresetHelper =>
      'অফিসিয়াল ওপেনকোড ওয়েব বিল্ট-ইন থিম তালিকাকে মিরর করে।';

  @override
  String get settingsAppearancePresetNote =>
      'থিমের রঙগুলি এখন অফিসিয়াল ওপেনকোড ওয়েব রেজিস্ট্রি এবং ড্রাইভ মার্কডাউন/কোড সারফেস অনুসরণ করে।';

  @override
  String get settingsAppearancePresetPalette => 'প্রিসেট প্যালেট';

  @override
  String get settingsAppearanceSearchPreset => 'প্রিসেট প্যালেট অনুসন্ধান করুন';

  @override
  String get settingsAppearanceSectionDescription =>
      'আপনার কর্মপ্রবাহের জন্য ভিজ্যুয়াল ঘনত্ব এবং বার্তা সারফেস টিউন করুন।';

  @override
  String get settingsAppearanceSectionTitle => 'চেহারা';

  @override
  String get settingsAppearanceSystem => 'সিস্টেম';

  @override
  String get settingsAppearanceSystemFontScale => 'সিস্টেম টেক্সটের আকার';

  @override
  String get settingsAppearanceSystemFontScaleDescription =>
      'অ্যাপ শেলের সব টেক্সটের আকার বাড়ান বা কমান, মেনু, ডায়ালগ এবং সাইডবারসহ।';

  @override
  String get settingsAppearanceTaskList => 'টাস্ক তালিকা';

  @override
  String get settingsAppearanceTaskListDescription =>
      'সেশন টাস্ক লিস্ট উইজেট দেখান বা লুকান।';

  @override
  String get settingsAppearanceTerminalFontSize => 'টার্মিনাল টেক্সটের আকার';

  @override
  String get settingsAppearanceTerminalFontSizeDescription =>
      'এমবেডেড টার্মিনালের ফন্টের আকার পরিবর্তন করুন। চলমান সেশনে তাৎক্ষণিক প্রযোজ্য।';

  @override
  String get settingsAppearanceTheme => 'থিম';

  @override
  String get settingsAppearanceThemeDescription =>
      'হালকা, অন্ধকার বা সিস্টেম মোড চয়ন করুন, তারপর CodeWalk ক্লাসিক প্যালেট রাখুন বা একটি OpenCode প্রিসেট এ স্যুইচ করুন।';

  @override
  String get settingsAppearanceVisualStyle => 'ভিজ্যুয়াল স্টাইল';

  @override
  String get settingsAppearanceVisualStyleDescription =>
      'ক্লাসিক রূপ অথবা আরও নরম পরিশীলিত সারফেস বেছে নিন।';

  @override
  String get settingsAppearanceVisualStyleClassic => 'ক্লাসিক';

  @override
  String get settingsAppearanceVisualStyleRefined => 'পরিশীলিত';

  @override
  String get settingsAppearanceThinkingBubbles => 'বুদবুদ চিন্তা';

  @override
  String get settingsAppearanceThinkingBubblesDescription =>
      'সহকারী বার্তাগুলিতে যুক্তি ব্লকগুলি দেখান বা লুকান৷';

  @override
  String get settingsAppearanceTitle => 'চেহারা';

  @override
  String get settingsAppearanceToolCallBubbles => 'টুল কল বুদবুদ';

  @override
  String get settingsAppearanceToolCallBubblesDescription =>
      'সহকারী বার্তাগুলিতে টুল এক্সিকিউশন কার্ড দেখান বা লুকান।';

  @override
  String get settingsAppearanceWallpaperColors => 'ওয়ালপেপার রং ব্যবহার করুন';

  @override
  String get settingsAppearanceWallpaperNormal =>
      'আপনার ডিভাইসের ওয়ালপেপার থেকে রঙের স্কিম বের করুন।';

  @override
  String get settingsAppearanceWallpaperPresetBlocked =>
      'ওয়ালপেপার রং ব্যবহার করতে CodeWalk ক্লাসিকে স্যুইচ করুন।';

  @override
  String get settingsAppearanceWindowChrome => 'উইন্ডো ট্যাব';

  @override
  String get settingsAppearanceWindowChromeDescription =>
      'ডেস্কটপে সেশন ট্যাব ও টাইটেল বার কীভাবে যুক্ত হবে তা বেছে নিন।';

  @override
  String get settingsAppearanceWindowChromeIntegrated => 'সমন্বিত ট্যাব';

  @override
  String get settingsAppearanceWindowChromeIntegratedDescription =>
      'ট্যাবগুলো উইন্ডোর উপরে থাকে এবং সিস্টেম টাইটেল বার লুকানো হয়।';

  @override
  String get settingsAppearanceWindowChromeSystem => 'সিস্টেম সজ্জা';

  @override
  String get settingsAppearanceWindowChromeSystemDescription =>
      'নেটিভ টাইটেল বার রাখে এবং অ্যাপ বারের নিচে ট্যাব দেখায়।';

  @override
  String get settingsBack => 'ব্যাক';

  @override
  String get settingsBehaviorAutoupdateCaveat =>
      'CodeWalk রিলিজ চেকের জন্য সম্পর্কে ব্যবহার করুন। এই সেটিংটি শুধুমাত্র অফিসিয়াল OpenCode `autoupdate` কনফিগারেশনকে মিরর করে।';

  @override
  String get settingsBehaviorAutoupdateHelp =>
      'আপস্ট্রিম OpenCode রানটাইম আপডেট নিয়ন্ত্রণ করে, CodeWalk অ্যাপ আপডেট চেক নয়।';

  @override
  String get settingsBehaviorCellularDataSaver => 'সেলুলার ডেটা সেভার';

  @override
  String get settingsBehaviorChatRenderMode => 'চ্যাট রেন্ডার মোড';

  @override
  String get settingsBehaviorChatRenderModeBlock => 'ব্লক';

  @override
  String get settingsBehaviorChatRenderModeBlockDescription =>
      'বর্তমান টার্ন একক ব্লক হিসেবে দেখানোর আগ পর্যন্ত লাইভ সহায়ক টেক্সট, যুক্তি এবং টুল কার্ড লুকিয়ে রাখুন।';

  @override
  String get settingsBehaviorChatRenderModeDescription =>
      'সহায়কের উত্তর স্ট্রিম করার সময় দেখাবেন নাকি বর্তমান টার্ন শেষ হওয়ার পরে দেখাবেন তা চয়ন করুন।';

  @override
  String get settingsBehaviorChatRenderModeLive => 'লাইভ';

  @override
  String get settingsBehaviorChatRenderModeLiveDescription =>
      'OpenCode ইভেন্ট স্ট্রিম করার সময় সহায়কের টেক্সট, যুক্তি ও টুলের কার্যকলাপ দেখান।';

  @override
  String get settingsBehaviorComposerSpellCheck => 'কম্পোজার বানান পরীক্ষা';

  @override
  String get settingsBehaviorComposerSpellCheckDescription =>
      'চ্যাট কম্পোজারে প্ল্যাটফর্মের নেটিভ বানান পরীক্ষা, পরামর্শ এবং স্বয়ংক্রিয় সংশোধন ব্যবহার করুন।';

  @override
  String get settingsBehaviorConfigDeferred =>
      'CodeWalk বর্তমান প্রতিক্রিয়া শেষ হওয়ার পরে এই OpenCode সেটিং প্রয়োগ করবে।';

  @override
  String settingsBehaviorConfigUpdateFailed(String field) {
    return 'OpenCode $field আপডেট করা যায়নি।';
  }

  @override
  String get settingsBehaviorConversationUsername =>
      'কথোপকথনের ব্যবহারকারীর নাম';

  @override
  String get settingsBehaviorConversationUsernameHelp =>
      'সিস্টেম ব্যবহারকারী নামের পরিবর্তে কথোপকথনে দেখানো কাস্টম প্রদর্শন নাম।';

  @override
  String get settingsBehaviorDataSaverActive => 'মোবাইল ডেটাতে এখন সক্রিয়।';

  @override
  String get settingsBehaviorDataSaverCellularOnly =>
      'সংযোগটি সেলুলার/মোবাইল হলেই প্রযোজ্য।';

  @override
  String get settingsBehaviorDataSaverDescription =>
      'ব্যাকগ্রাউন্ড ডাউনলোড বন্ধ করে এবং স্বয়ংক্রিয় ফোরগ্রাউন্ড রিফ্রেশ থ্রটলিং করে স্বয়ংক্রিয় মোবাইল-ডেটা ব্যবহার কম করে।';

  @override
  String get settingsBehaviorDataSaverWaiting =>
      'পরবর্তী মোবাইল-ডেটা সিঙ্ক উইন্ডোর জন্য অপেক্ষা করা হচ্ছে।';

  @override
  String get settingsBehaviorDefaultAgent => 'ডিফল্ট এজেন্ট';

  @override
  String get settingsBehaviorDefaultAgentHelp =>
      'কোন এজেন্ট স্পষ্টভাবে নির্বাচিত না হলে প্রাথমিক এজেন্ট ব্যবহার করা হয়।';

  @override
  String get settingsBehaviorDefaultModel => 'ডিফল্ট মডেল';

  @override
  String get settingsBehaviorDefaultModelHelp =>
      'কনফিগারের মাধ্যমে OpenCode ক্লায়েন্ট জুড়ে শেয়ার করা হয়েছে।';

  @override
  String get settingsBehaviorDescription =>
      'ভাষা, চ্যাট আচরণ, ডেটা ব্যবহার এবং OpenCode ডিফল্ট নিয়ন্ত্রণ করুন';

  @override
  String get settingsBehaviorEnableDataSaver =>
      'সেলুলার ডেটা সেভার সক্ষম করুন৷';

  @override
  String get settingsBehaviorMultiDeviceSync =>
      'পরীক্ষামূলক মাল্টি-ডিভাইস সিঙ্ক সক্ষম করুন';

  @override
  String get settingsBehaviorMultiDeviceSyncDescription =>
      'সক্রিয় সার্ভার কনফিগারেশনের সাথে সুরকার নির্বাচন (এজেন্ট/মডেল/ভেরিয়েন্ট) সিঙ্ক করুন।';

  @override
  String get settingsBehaviorMultiDeviceSyncWarning =>
      'একই সময়ে একাধিক সেশনে কাজ করার সময় চলমান সেশন বাতিল করতে পারে।';

  @override
  String get settingsBehaviorNoAgents => 'কোন এজেন্ট পাওয়া যায়নি';

  @override
  String get settingsBehaviorNoModels => 'কোন মডেল পাওয়া যায়নি';

  @override
  String get settingsBehaviorOpenCodeAutoupdate =>
      'OpenCode স্বয়ংক্রিয় আপডেট';

  @override
  String get settingsBehaviorOpenCodeDefaults => 'OpenCode-ব্যাকড ডিফল্ট';

  @override
  String get settingsBehaviorOpenCodeDefaultsDescription =>
      'এই মানগুলি সক্রিয় সার্ভারে `/config` তে লিখবে এবং অফিসিয়াল OpenCode শেয়ার করা কনফিগারের সাথে মেলে।';

  @override
  String get settingsBehaviorOpenCodeSnapshots => 'OpenCode স্ন্যাপশট';

  @override
  String get settingsBehaviorOpenCodeSnapshotsDescription =>
      'আপস্ট্রিম গিট-ব্যাকড স্ন্যাপশটগুলিকে পূর্বাবস্থায় ফিরিয়ে আনা/পুনরায় করা এবং পুনরুদ্ধারের ইতিহাসের জন্য সক্রিয় রাখুন।';

  @override
  String get settingsBehaviorPermissionDeferred =>
      'অ্যাডভান্সড পারমিশন রুল এডিটিং আপাতত সেটিংসের বাইরে থাকে এবং পরবর্তী প্যারিটি কাজের জন্য পিছিয়ে দেওয়া হয়।';

  @override
  String get settingsBehaviorPermissionProvenance => 'অনুমতি হ্যান্ডলিং মূল';

  @override
  String get settingsBehaviorPermissionProvenanceDescription =>
      'অফিসিয়াল OpenCode অনুমতি নীতি \'opencode.json\'-এ কনফিগার করা হয়েছে প্রতি টুলের অনুমতি/চাওয়া/অস্বীকার করার নিয়মের সাথে। CodeWalk অফিসিয়াল অনুমতি-অনুরোধের কার্ডগুলি রাখে এবং একটি অনুমোদিত ADR-023 ব্যতিক্রম যোগ করে: সুরকার স্বয়ংক্রিয়ভাবে অনুমোদিত টগল উত্তরগুলি \'সর্বদা\' এবং \'মনে রাখবেন: সত্য\' সহ টেকসই সেশন-স্কোপড অনুদান তৈরি করতে শর্তহীনভাবে এবং একই থ্রেড-স্কোপড ধারাবাহিকতা পাথ অ্যান্ড্রয়েড ওয়ার্ক-এ সক্রিয় রাখে।';

  @override
  String get settingsBehaviorRefreshDefaults => 'ডিফল্ট রিফ্রেশ করুন';

  @override
  String get settingsBehaviorSaveUsername => 'ব্যবহারকারীর নাম সংরক্ষণ করুন';

  @override
  String get settingsBehaviorSearchAutoupdate =>
      'স্বয়ংক্রিয়-আপডেট মোড অনুসন্ধান করুন';

  @override
  String get settingsBehaviorSearchDefaultAgent =>
      'ডিফল্ট এজেন্ট অনুসন্ধান করুন';

  @override
  String get settingsBehaviorSearchDefaultModel => 'ডিফল্ট মডেল অনুসন্ধান করুন';

  @override
  String get settingsBehaviorSearchShareMode => 'শেয়ারিং মোড খুঁজুন';

  @override
  String get settingsBehaviorSearchSmallModel => 'ছোট মডেল অনুসন্ধান করুন';

  @override
  String get settingsBehaviorShareMode => 'OpenCode শেয়ারিং ডিফল্ট';

  @override
  String get settingsBehaviorShareModeCaveat =>
      'এখন একটি সেশন প্রকাশ করতে চ্যাট-লেভেল শেয়ার অ্যাকশন ব্যবহার করুন। এই সেটিং শুধুমাত্র OpenCode এর ডিফল্ট শেয়ারিং নীতি পরিবর্তন করে।';

  @override
  String get settingsBehaviorShareModeHelp =>
      'একটি স্বতন্ত্র চ্যাটের জন্য শেয়ার বোতাম নয়, অফিসিয়াল গ্লোবাল `শেয়ার` কনফিগারেশন নিয়ন্ত্রণ করে।';

  @override
  String get settingsBehaviorSmallModel => 'ছোট মডেল';

  @override
  String get settingsBehaviorSmallModelAutoFallback => 'স্বয়ংক্রিয় ফলব্যাক';

  @override
  String get settingsBehaviorSmallModelFallbackActive =>
      'OpenCode স্বয়ংক্রিয় ফলব্যাক সক্রিয় কারণ `small_model` সেট করা নেই।';

  @override
  String get settingsBehaviorSmallModelHelp =>
      'টাইটেল জেনারেশনের মতো লাইটওয়েট কাজের জন্য ব্যবহার করা হয়।';

  @override
  String get settingsBehaviorSmallModelResetCaveat =>
      '`small_model` আবার স্বয়ংক্রিয় ফলব্যাকে রিসেট করার জন্য এখনও অ্যাপের বাইরে কনফিগার সম্পাদনা প্রয়োজন কারণ `/config` প্যাচ আপডেট কীগুলি সরাতে পারে না।';

  @override
  String get settingsBehaviorSnapshotCaveat =>
      'এটি ওপেনকোড স্ন্যাপশট সঞ্চয়স্থান এবং পূর্বাবস্থায় ফেরানো/পুনরায় করা সমর্থন নিয়ন্ত্রণ করে, কোডওয়াক স্থানীয় ক্যাশে স্ন্যাপশট নয়।';

  @override
  String get settingsBehaviorTitle => 'আচরণ';

  @override
  String get settingsBehaviorUsernameFallback =>
      'OpenCode সিস্টেম ব্যবহারকারীর নাম ব্যবহার করে কারণ `ব্যবহারকারীর নাম` সেট করা নেই।';

  @override
  String get settingsBehaviorUsernamePatchCaveat =>
      'সিস্টেম ডিফল্টে `ব্যবহারকারীর নাম` পুনরায় সেট করার জন্য এখনও অ্যাপের বাইরে কনফিগার সম্পাদনা প্রয়োজন কারণ `/config` প্যাচ আপডেটগুলি কীগুলি সরাতে পারে না।';

  @override
  String get settingsConfigRefreshFailed =>
      'সার্ভার সেটিং আপডেট করা হয়েছে, কিন্তু চ্যাট প্রদানকারীদের রিফ্রেশ করতে পারেনি।';

  @override
  String get settingsConfigUpdateDeferred =>
      'CodeWalk বর্তমান প্রতিক্রিয়া শেষ হওয়ার পরে এই OpenCode সেটিং প্রয়োগ করবে।';

  @override
  String get settingsConversationUsername => 'কথোপকথন ব্যবহারকারীর নাম';

  @override
  String get settingsDefaultAgent => 'ডিফল্ট এজেন্ট';

  @override
  String get settingsDefaultModel => 'ডিফল্ট মডেল';

  @override
  String get settingsLanguageDescription =>
      'CodeWalk দ্বারা ব্যবহৃত ভাষা চয়ন করুন। সিস্টেম ডিফল্ট আপনার ডিভাইসের ভাষা অনুসরণ করে।';

  @override
  String get settingsLanguageEmptyText => 'কোনো ভাষা পাওয়া যায়নি';

  @override
  String get settingsLanguageFieldHelper =>
      'অবিলম্বে প্রযোজ্য এবং পুনরায় আরম্ভ জুড়ে অব্যাহত থাকে।';

  @override
  String get settingsLanguageFieldLabel => 'অ্যাপের ভাষা';

  @override
  String get settingsLanguageSearchHint => 'ভাষা অনুসন্ধান করুন';

  @override
  String get settingsLanguageSystemDefault => 'সিস্টেম ডিফল্ট';

  @override
  String get settingsLanguageTitle => 'ভাষা';

  @override
  String get settingsLogsDescription =>
      'অ্যাপ ডায়াগনস্টিকস এবং সমস্যা সমাধানের বিবরণ পর্যালোচনা করুন';

  @override
  String get settingsLogsTitle => 'Registros';

  @override
  String get settingsNoAgentsFound => 'কোনো এজেন্ট পাওয়া যায়নি';

  @override
  String get settingsNotificationsAgentSubtitle => 'একটি প্রতিক্রিয়া শেষ হলে';

  @override
  String get settingsNotificationsAgentUpdates => 'এজেন্ট আপডেট';

  @override
  String get settingsNotificationsAnotherConversation => 'আরেকটি কথোপকথন';

  @override
  String get settingsNotificationsAppInBackground => 'ব্যাকগ্রাউন্ডে অ্যাপ';

  @override
  String get settingsNotificationsBackgroundAlerts =>
      'অ্যান্ড্রয়েড ব্যাকগ্রাউন্ড সতর্কতা';

  @override
  String get settingsNotificationsBackgroundBehavior => 'পটভূমি আচরণ';

  @override
  String get settingsNotificationsBackgroundBehaviorDescription =>
      'অ্যাপটি অগ্রভাগ ছেড়ে যাওয়ার পরে কোডওয়াক কীভাবে আচরণ করবে তা চয়ন করুন।';

  @override
  String get settingsNotificationsBackgroundDescription =>
      'অ্যাপ্লিকেশানটি স্ক্রিনে না থাকাকালীন প্রতিক্রিয়া সম্পূর্ণকরণ, অনুমতির অনুরোধ, প্রশ্ন এবং ত্রুটির জন্য লো-ডেটা ব্যাকগ্রাউন্ড মনিটরিং ব্যবহার করুন।';

  @override
  String get settingsNotificationsBackgroundToggle =>
      'অ্যান্ড্রয়েডে পটভূমি সতর্কতা';

  @override
  String get settingsNotificationsBackgroundToggleDescription =>
      'সমস্ত অ্যান্ড্রয়েড ব্যাকগ্রাউন্ড চেক বন্ধ করুন এবং ক্রমাগত মনিটর বিজ্ঞপ্তি লুকান।';

  @override
  String get settingsNotificationsBatteryDescription =>
      'যদি শুধুমাত্র অ্যাপটি খোলার সময় বিজ্ঞপ্তি আসে, তাহলে এই ডিভাইসে অপ্টিমাইজেশন ছাড়াই CodeWalk চালানোর অনুমতি দিন।';

  @override
  String get settingsNotificationsBatteryDisabled =>
      'CodeWalk-এর জন্য ব্যাটারি অপ্টিমাইজেশান অক্ষম করা হয়েছে৷';

  @override
  String get settingsNotificationsBatteryEnabled =>
      'ব্যাটারি অপ্টিমাইজেশান সক্ষম করা হয়েছে৷ কিছু ডিভাইস পটভূমি সতর্কতা বিলম্বিত করতে পারে।';

  @override
  String get settingsNotificationsBatteryOptimization =>
      'অ্যান্ড্রয়েড ব্যাটারি অপ্টিমাইজেশান';

  @override
  String get settingsNotificationsBatteryUnknown =>
      'ব্যাটারি অপ্টিমাইজেশান স্ট্যাটাস এখনও পড়তে পারেনি৷';

  @override
  String get settingsNotificationsChooseAudioFile => 'অডিও ফাইল নির্বাচন করুন';

  @override
  String get settingsNotificationsChooseSystemSound => 'সিস্টেম শব্দ চয়ন করুন';

  @override
  String get settingsNotificationsCloseToTray => 'ট্রের কাছে';

  @override
  String get settingsNotificationsCloseToTrayDescription =>
      'উইন্ডো লুকান এবং সিস্টেম ট্রেতে চালাতে থাকুন।';

  @override
  String get settingsNotificationsDescription =>
      'কোন ইভেন্ট আপনাকে সতর্ক করবে এবং কীভাবে, তা চয়ন করুন';

  @override
  String get settingsNotificationsDisableOptimization =>
      'অপ্টিমাইজেশান অক্ষম করুন';

  @override
  String get settingsNotificationsErrors => 'ত্রুটি';

  @override
  String get settingsNotificationsErrorsSubtitle =>
      'যখন একটি সেশন একটি ব্যর্থতার রিপোর্ট করে';

  @override
  String get settingsNotificationsJustClose => 'শুধু বন্ধ';

  @override
  String get settingsNotificationsJustCloseDescription =>
      'অ্যাপ্লিকেশন সম্পূর্ণরূপে প্রস্থান করুন.';

  @override
  String get settingsNotificationsKeepLive =>
      'সতর্কতাগুলি 3 মিনিটের জন্য লাইভ রাখুন';

  @override
  String get settingsNotificationsKeepLiveDescription =>
      'যখন একটি প্রতিক্রিয়া ইতিমধ্যেই চলছে, তখন অ্যাপটি ছেড়ে যাওয়ার পরে সংক্ষেপে রিয়েলটাইম সক্রিয় রাখুন।';

  @override
  String get settingsNotificationsLocal => 'লোকাল';

  @override
  String get settingsNotificationsMinimizeWhenClose => 'বন্ধ হলে ছোট করুন';

  @override
  String get settingsNotificationsMinimizeWhenCloseDescription =>
      'টাস্কবার/ডকে ছোট করুন এবং চালিয়ে যান।';

  @override
  String get settingsNotificationsNoCondition =>
      'যদি কোনো শর্ত নির্বাচন না করা হয়, তবে যেকোনো প্রসঙ্গে সতর্কতা অনুমোদিত।';

  @override
  String get settingsNotificationsNotify => 'অবহিত করুন';

  @override
  String get settingsNotificationsNotifyOnlyWhen => 'শুধুমাত্র যখন জানাবেন';

  @override
  String get settingsNotificationsOpenBatterySettings =>
      'ব্যাটারি সেটিংস খুলুন';

  @override
  String get settingsNotificationsPermissions => 'অনুমতি এবং প্রশ্ন';

  @override
  String get settingsNotificationsPermissionsSubtitle =>
      'যখন টুল আপনার ইনপুট অনুরোধ';

  @override
  String get settingsNotificationsPreview => 'পূর্বরূপ';

  @override
  String get settingsNotificationsRefreshStatus => 'স্থিতি রিফ্রেশ করুন';

  @override
  String get settingsNotificationsSearchSoundType => 'শব্দের ধরন খুঁজুন';

  @override
  String get settingsNotificationsSectionDescription =>
      'কখন সতর্কতা প্রদর্শিত হয় এবং কখন তারা শব্দ চালাতে পারে তা নিয়ন্ত্রণ করুন।';

  @override
  String get settingsNotificationsSectionTitle => 'বিজ্ঞপ্তি';

  @override
  String settingsNotificationsSelectedSound(String label) {
    return 'নির্বাচিত: $label';
  }

  @override
  String get settingsNotificationsServer => 'সার্ভার';

  @override
  String get settingsNotificationsSound => 'শব্দ';

  @override
  String get settingsNotificationsSoundBuiltInAlert => 'বিল্ট-ইন অ্যালার্ট';

  @override
  String get settingsNotificationsSoundBuiltInClick => 'বিল্ট-ইন ক্লিক';

  @override
  String get settingsNotificationsSoundOff => 'বন্ধ';

  @override
  String get settingsNotificationsSoundOnlyWhen => 'শব্দ শুধুমাত্র যখন';

  @override
  String get settingsNotificationsSoundPickAudioFile =>
      'অ디오 ফাইল নির্বাচন করুন';

  @override
  String get settingsNotificationsSoundPickFromSystem =>
      'সিস্টেম থেকে নির্বাচন করুন';

  @override
  String get settingsNotificationsSoundSystemDefault => 'সিস্টেমের ডিফল্ট';

  @override
  String get settingsNotificationsSoundType => 'শব্দের ধরন';

  @override
  String get settingsNotificationsSyncInfo =>
      'কিছু বিভাগ চালু/বন্ধ টগল সক্রিয় সার্ভারে /config থেকে সিঙ্ক করা হয়।';

  @override
  String get settingsNotificationsSyncInfoLocal =>
      'বর্তমান সার্ভার / কনফিগারেশনে বিজ্ঞপ্তি টগল প্রকাশ করে না; স্থানীয় মান সক্রিয়।';

  @override
  String get settingsNotificationsSystemSoundPickerTitle =>
      'সিস্টেম শব্দ চয়ন করুন';

  @override
  String get settingsNotificationsTitle => 'বিজ্ঞপ্তি';

  @override
  String get settingsNotificationsWhenClosing => 'জানালা বন্ধ করার সময়';

  @override
  String get settingsOpenCodeAutoUpdate => 'OpenCode স্বয়ংক্রিয় আপডেট';

  @override
  String get settingsOpenCodeSharingDefault => 'OpenCode শেয়ারিং ডিফল্ট';

  @override
  String get settingsReadAloudEnabled => 'জোরে পড়ুন';

  @override
  String get settingsReadAloudEnabledDescription =>
      'সহকারী বার্তাগুলিতে একটি জোরে পড়ার বোতাম দেখান।';

  @override
  String get settingsReadAloudPitch => 'পিচ';

  @override
  String get settingsReadAloudPitchDescription => 'ভয়েস পিচ সামঞ্জস্য করুন।';

  @override
  String get settingsReadAloudSectionDescription =>
      'সহকারীর প্রতিক্রিয়াগুলি জোরে পড়ুন। গতি, পিচ এবং ভয়েস কনফিগার করুন।';

  @override
  String get settingsReadAloudSectionTitle => 'টেক্সট টু বক্তৃতা';

  @override
  String get settingsReadAloudSpeed => 'গতি';

  @override
  String get settingsReadAloudSpeedDescription =>
      'কথা বলার হার সামঞ্জস্য করুন।';

  @override
  String get settingsReadAloudVoice => 'ভয়েস';

  @override
  String get settingsReadAloudVoiceHint =>
      'উচ্চস্বরে পড়ার জন্য একটি ভয়েস নির্বাচন করুন।';

  @override
  String get settingsSearchAutoUpdateMode =>
      'স্বয়ংক্রিয় আপডেট মোড অনুসন্ধান করুন';

  @override
  String get settingsSearchDefaultAgent => 'ডিফল্ট এজেন্ট অনুসন্ধান করুন';

  @override
  String get settingsSearchDefaultModel => 'ডিফল্ট মডেল অনুসন্ধান করুন';

  @override
  String get settingsSearchSharingMode => 'শেয়ারিং মোড অনুসন্ধান করুন';

  @override
  String get settingsSearchSmallModel => 'ছোট মডেল অনুসন্ধান করুন';

  @override
  String get settingsServersActive => 'সক্রিয়';

  @override
  String get settingsServersChooseActive => 'সক্রিয় সার্ভার নির্বাচন করুন';

  @override
  String get settingsServersDefault => 'ডিফল্ট';

  @override
  String get settingsServersDescription =>
      'OpenCode-এ সংযোগ করুন এবং আপনার সার্ভার পরিচালনা করুন';

  @override
  String get settingsServersTitle => 'সার্ভার';

  @override
  String get settingsSessionAttentionSize => 'বাবলের আকার';

  @override
  String get settingsSessionAttentionSizeExtraLarge => 'অতি বড়';

  @override
  String get settingsSessionAttentionSizeExtraSmall => 'অতি ছোট';

  @override
  String get settingsSessionAttentionSizeLarge => 'বড়';

  @override
  String get settingsSessionAttentionSizeSmall => 'ছোট';

  @override
  String get settingsSessionAttentionSizeStandard => 'আদর্শ';

  @override
  String get settingsSetupWizard => 'সেটআপ উইজার্ড';

  @override
  String get settingsShortcutsDescription =>
      'কীবোর্ড শর্টকাট খুঁজুন এবং কাস্টমাইজ করুন';

  @override
  String get settingsShortcutsEdit => 'শর্টকাট সম্পাদনা করুন';

  @override
  String get settingsShortcutsKeyboard => 'কীবোর্ড শর্টকাট';

  @override
  String get settingsShortcutsReset => 'শর্টকাট রিসেট করুন';

  @override
  String get settingsShortcutsSearch => 'শর্টকাট অনুসন্ধান করুন';

  @override
  String get settingsShortcutsTitle => 'শর্টকাট';

  @override
  String get settingsSmallModel => 'ছোট মডেল';

  @override
  String get settingsSmallModelResetExplanation =>
      '`/config` প্যাচ আপডেটগুলি কীগুলি সরাতে পারে না, তাই `small_model` স্বয়ংক্রিয় ফলব্যাকে রিসেট করতে অ্যাপের বাইরে কনফিگرেশন সম্পাদনা করতে হবে।';

  @override
  String get settingsSmallModelUnsetExplanation =>
      'OpenCode স্বয়ংক্রিয় ফলব্যাক সক্রিয় কারণ `small_model` সেট করা নেই।';

  @override
  String get settingsSoundPickerNotAvailable =>
      'সিস্টেম সাউন্ড পিকার এই প্ল্যাটফর্মে উপলব্ধ নয়।';

  @override
  String get settingsSpeechDescription =>
      'ভয়েস ইনপুট, অফলাইন মডেল এবং উচ্চস্বরে পড়া সেট আপ করুন';

  @override
  String get settingsSpeechRefreshStatus => 'স্থিতি রিফ্রেশ করুন';

  @override
  String settingsSpeechSilenceTimeout(String value) {
    return 'নীরবতার সময়সীমা: ${value}s';
  }

  @override
  String get settingsSpeechTitle => 'টেক্সট থেকে বক্তৃতা';

  @override
  String get settingsTitle => 'সেটিংস';

  @override
  String get settingsGroupAlertTypes => 'সতর্কতা প্রকার';

  @override
  String get settingsGroupBackgroundBehavior => 'ব্যাকগ্রাউন্ড আচরণ';

  @override
  String get settingsGroupChatDisplay => 'চ্যাট প্রদর্শন';

  @override
  String get settingsGroupCurrentConnection => 'বর্তমান সংযোগ';

  @override
  String get settingsGroupDataAndSync => 'ডেটা এবং সিঙ্ক';

  @override
  String get settingsGroupDataReset => 'ডেটা এবং রিসেট';

  @override
  String get settingsGroupDelivery => 'ডেলিভারি';

  @override
  String get settingsGroupHelp => 'সহায়তা';

  @override
  String get settingsGroupLanguageAndChat => 'ভাষা এবং চ্যাট';

  @override
  String get settingsGroupLayoutAndText => 'লেআউট এবং টেক্সট';

  @override
  String get settingsGroupOfflineModels => 'অফলাইন মডেল';

  @override
  String get settingsGroupOpenCodeDefaults => 'OpenCode ডিফল্ট';

  @override
  String get settingsGroupReadAloud => 'উচ্চস্বরে পড়া';

  @override
  String get settingsGroupSavedServers => 'সংরক্ষিত সার্ভার';

  @override
  String get settingsGroupThemeAndColor => 'থিম এবং রঙ';

  @override
  String get settingsGroupThisDevice => 'এই ডিভাইস';

  @override
  String get settingsGroupVersionUpdates => 'সংস্করণ এবং আপডেট';

  @override
  String get settingsGroupVoiceInput => 'ভয়েস ইনপুট';

  @override
  String get settingsNavigationGroupExperience => 'অভিজ্ঞতা';

  @override
  String get settingsNavigationGroupInput => 'ইনপুট';

  @override
  String get settingsNavigationGroupSetup => 'সেটআপ';

  @override
  String get settingsNavigationGroupSupport => 'সহায়তা এবং ডায়াগনস্টিকস';

  @override
  String get settingsNavigationNoResults => 'কোনো সেটিংস পাওয়া যায়নি';

  @override
  String get settingsNavigationSearchHint => 'সেটিংস অনুসন্ধান করুন';

  @override
  String get settingsUsernameClearHint =>
      'OpenCode কথোপকথন ব্যবহারকারীর নাম সাফ করার জন্য এখনও অ্যাপের বাইরে কনফিগার সম্পাদনা প্রয়োজন।';

  @override
  String get settingsUsernameEnterHint =>
      'একটি কাস্টম OpenCode কথোপকথনের নাম সংরক্ষণ করতে একটি ব্যবহারকারীর নাম লিখুন৷';

  @override
  String get settingsUsernameResetExplanation =>
      '`/config` প্যাচ আপডেটগুলি কীগুলি সরাতে পারে না, তাই `username` ডিফল্টে রিসেট করতে অ্যাপের বাইরে কনফিগারেশন সম্পাদনা করতে হবে।';

  @override
  String get settingsUsernameUnsetExplanation =>
      'OpenCode সিস্টেম ব্যবহারকারীর নাম ব্যবহার করে কারণ `username` সেট করা নেই।';

  @override
  String get setupDebugBun => 'বান';

  @override
  String get setupDebugBun2 => 'বান';

  @override
  String get setupDebugCapturedSetupDetails => 'এখনো সেটআপের কোনো বিবরণ নেই';

  @override
  String get setupDebugCapturedSetupLogs => 'ক্যাপচার সেটআপ লগ';

  @override
  String get setupDebugClear => 'সেটআপ ডিবাগ সাফ করুন';

  @override
  String get setupDebugClearSetupDebug => 'সেটআপ ডিবাগ সাফ করুন';

  @override
  String get setupDebugCodeWalkCaptureEnough =>
      'যদি CodeWalk যথেষ্ট প্রসঙ্গ ক্যাপচার না করে, তাহলে সরাসরি অফিসিয়াল OpenCode লগ এবং হেলথ এন্ডপয়েন্ট চেক করুন:';

  @override
  String get setupDebugCommandPath => 'কমান্ড পাথ';

  @override
  String get setupDebugCommandPath2 => 'কমান্ড পাথ';

  @override
  String get setupDebugCopy => 'সেটআপ ডিবাগ কপি করুন';

  @override
  String get setupDebugCopySetupDebug => 'সেটআপ ডিবাগ কপি করুন';

  @override
  String get setupDebugCurrentStatus => 'বর্তমান অবস্থা';

  @override
  String get setupDebugDiagnosticsLoading => 'ডায়াগনস্টিক এখনও লোড হচ্ছে।';

  @override
  String get setupDebugEnvironment => 'এনভায়রনমেন্ট ডায়াগনস্টিকস';

  @override
  String get setupDebugEnvironmentDiagnostics => 'এনভায়রনমেন্ট ডায়াগনস্টিকস';

  @override
  String get setupDebugFocusedOpenCodeSetup =>
      'OpenCode সেটআপে ফোকাস করা হয়েছে';

  @override
  String get setupDebugInstallDir => 'ডিরেক্টরি ইনস্টল করুন';

  @override
  String get setupDebugInstallDirectory => 'ডিরেক্টরি ইনস্টল করুন';

  @override
  String get setupDebugLatestLocalServer => 'সর্বশেষ স্থানীয় সার্ভার আউটপুট';

  @override
  String get setupDebugLogs => 'ক্যাপচার সেটআপ লগ';

  @override
  String get setupDebugManual => 'ম্যানুয়াল সমস্যা সমাধান';

  @override
  String get setupDebugManualTroubleshooting => 'ম্যানুয়াল সমস্যা সমাধান';

  @override
  String get setupDebugNetwork => 'নেটওয়ার্ক';

  @override
  String get setupDebugNetwork2 => 'নেটওয়ার্ক';

  @override
  String get setupDebugNoDetails => 'এখনো সেটআপের কোনো বিবরণ নেই';

  @override
  String get setupDebugNode => 'Node.js';

  @override
  String get setupDebugNodeJs => 'Node.js';

  @override
  String get setupDebugNpm => 'npm';

  @override
  String get setupDebugNpm2 => 'npm';

  @override
  String get setupDebugOpenCode => 'ওপেনকোড';

  @override
  String get setupDebugOpenCode2 => 'ওপেনকোড';

  @override
  String get setupDebugOpenCodeSetupDebug => 'OpenCode সেটআপ ডিবাগ';

  @override
  String get setupDebugPlatform => 'প্ল্যাটফর্ম';

  @override
  String get setupDebugPlatform2 => 'প্ল্যাটফর্ম';

  @override
  String get setupDebugRunDiagnosticsTry =>
      'ডায়াগনস্টিক চালান, একটি ইনস্টলেশন পদ্ধতি চেষ্টা করুন, বা OpenCode-নির্দিষ্ট সমস্যা সমাধানের বিবরণ এখানে ক্যাপচার করতে একটি সেটআপ প্রবাহ চেষ্টা করুন।';

  @override
  String get setupDebugScreenCoversOpenCode =>
      'এই স্ক্রীনটি শুধুমাত্র OpenCode ইনস্টলেশন, ডায়াগনস্টিকস এবং স্থানীয় সেটআপ সমস্যা সমাধান কভার করে। সাধারণ কোডওয়াক রানটাইম সমস্যার জন্য অ্যাপ লগ ব্যবহার করুন।';

  @override
  String get setupDebugServerOutput => 'সর্বশেষ স্থানীয় সার্ভার আউটপুট';

  @override
  String get setupDebugStatus => 'বর্তমান অবস্থা';

  @override
  String setupDebugTimeEntrySource(String source, String time) {
    return '$time - $source';
  }

  @override
  String get setupDebugTimeline => 'টাইমলাইন';

  @override
  String get setupDebugTimeline2 => 'টাইমলাইন';

  @override
  String get setupDebugTitle => 'OpenCode সেটআপে ফোকাস করা হয়েছে';

  @override
  String get setupDebugWSL => 'WSL';

  @override
  String get setupDebugWsl => 'WSL';

  @override
  String get shortcutCloseApp => 'ট্যাব/অ্যাপ্লিকেশন বন্ধ করুন';

  @override
  String get shortcutCloseAppDesc =>
      'বর্তমান সেশন ট্যাব থাকলে সেটি বন্ধ করুন; অন্যথায় প্ল্যাটফর্মের নিয়মে অ্যাপ বন্ধ করুন';

  @override
  String get shortcutFocusCloseDrawer => 'ফোকাস/ড্রয়ার বন্ধ করুন';

  @override
  String get shortcutFocusCloseDrawerDesc =>
      'ডিফল্টভাবে ইনপুটে ফোকাস করুন, অথবা খোলা থাকলে ড্রয়ার বন্ধ করুন';

  @override
  String get shortcutFocusInput => 'ইনপুটে ফোকাস করুন';

  @override
  String get shortcutFocusInputDesc => 'টেক্সট ইনপুটে ফোকাস সরান';

  @override
  String get shortcutGroupApplication => 'অ্যাপ্লিকেশন';

  @override
  String get shortcutGroupGeneral => 'সাধারণ';

  @override
  String get shortcutGroupModelAndAgent => 'মডেল এবং এজেন্ট';

  @override
  String get shortcutGroupNavigation => 'নেভিগেশন';

  @override
  String get shortcutGroupPrompt => 'প্রম্পট';

  @override
  String get shortcutGroupSession => 'সেশন';

  @override
  String get shortcutNewConversation => 'নতুন কথোপকথন';

  @override
  String get shortcutNewConversationDesc => 'একটি নতুন চ্যাট সেশন তৈরি করুন';

  @override
  String get shortcutNextAgent => 'পরবর্তী এজেন্ট';

  @override
  String get shortcutNextAgentDesc => 'পরবর্তী উপলব্ধ এজেন্টে যান';

  @override
  String get shortcutNextRecentModel => 'পরবর্তী সাম্প্রতিক মডেল';

  @override
  String get shortcutNextRecentModelDesc =>
      'সম্প্রতি ব্যবহৃত মডেলগুলির মধ্যে পরিবর্তন করুন';

  @override
  String get shortcutNextVariant => 'পরবর্তী ভেরিয়েন্ট';

  @override
  String get shortcutNextVariantDesc =>
      'উপলব্ধ মডেল ভেরিয়েন্টগুলির মধ্যে পরিবর্তন করুন';

  @override
  String get shortcutOpenSettings => 'সেটিংস খুলুন';

  @override
  String get shortcutOpenSettingsDesc => 'সেটিংস পৃষ্ঠা খুলুন';

  @override
  String get shortcutPreviousAgent => 'পূর্ববর্তী এজেন্ট';

  @override
  String get shortcutPreviousAgentDesc => 'পূর্ববর্তী উপলব্ধ এজেন্টে যান';

  @override
  String get shortcutQuickOpenFiles => 'ফাইলগুলি দ্রুত খুলুন';

  @override
  String get shortcutQuickOpenFilesDesc => 'ফাইল দ্রুত অনুসন্ধান খুলুন';

  @override
  String get shortcutQuitApp => 'অ্যাপ্লিকেশন থেকে প্রস্থান করুন';

  @override
  String get shortcutQuitAppDesc => 'অ্যাপ থেকে জোরপূর্বক প্রস্থান করুন';

  @override
  String get shortcutRefreshData => 'ডেটা রিফ্রেশ করুন';

  @override
  String get shortcutRefreshDataDesc => 'বর্তমান চ্যাট ডেটা রিফ্রেশ করুন';

  @override
  String get shortcutStopResponse => 'প্রতিক্রিয়া বন্ধ করুন';

  @override
  String get shortcutStopResponseDesc =>
      'সক্রিয় প্রতিক্রিয়া বন্ধ করুন (প্রতিক্রিয়া দেওয়ার সময়)';

  @override
  String get shortcutToggleVoiceInput => 'ভয়েস ইনপুট টগল করুন';

  @override
  String get shortcutToggleVoiceInputDesc =>
      'এডিটরে ভয়েস ডিক্টেশন শুরু বা বন্ধ করুন';

  @override
  String get shortcutsApply => 'আবেদন করুন';

  @override
  String shortcutsConflictConflict(String conflict) {
    return '$conflict এর সাথে দ্বন্দ্ব';
  }

  @override
  String get shortcutsKeyboardShortcuts => 'কীবোর্ড শর্টকাট';

  @override
  String get shortcutsReset => 'সব রিসেট করুন';

  @override
  String get shortcutsSearchEditBindings =>
      'সংরক্ষণ করার আগে অনুসন্ধান করুন, বাইন্ডিং সম্পাদনা করুন এবং দ্বন্দ্ব সমাধান করুন।';

  @override
  String shortcutsSetShortcutWidget(String label) {
    return 'শর্টকাট সেট করুন: $label';
  }

  @override
  String get shortcutsTheseBindingsStored =>
      'এই বাইন্ডিংগুলি বর্তমান অ্যাপ রানটাইমের জন্য CodeWalk-এ সংরক্ষিত থাকে এবং OpenCode `tui.json` কীবাইন্ড এডিট করে না।';

  @override
  String get speechAutoStopSilence => 'অটো-স্টপ সাইলেন্স টাইমআউট';

  @override
  String get speechChooseRecognitionEngine =>
      'স্বীকৃতি ইঞ্জিন, নীরবতা টাইমআউট এবং মডেল বিকল্পগুলি চয়ন করুন৷';

  @override
  String speechDesktopOnly(String service) {
    return '$service শুধুমাত্র ডেস্কটপে উপলব্ধ।';
  }

  @override
  String get speechDownload => 'ডাউনলোড করুন';

  @override
  String get speechEngine => 'ইঞ্জিন';

  @override
  String get speechInstalledLanguages => 'ইনস্টল করা ভাষা';

  @override
  String get speechListeningStopsAutomatically =>
      'এই কয়েক সেকেন্ডের নীরবতার পরে শোনা স্বয়ংক্রিয়ভাবে বন্ধ হয়ে যায়।';

  @override
  String get speechMicPermissionDisabled => 'মাইক্রোফোন অনুমতি নিষ্ক্রিয়।';

  @override
  String speechModelFilesIncomplete(String service) {
    return '$service মডেল ফাইলগুলি অপূর্ণ।';
  }

  @override
  String get speechMoonshine => 'মুনশাইন';

  @override
  String get speechMoonshineModelsDesktop => 'মুনশাইন মডেল (ডেস্কটপ)';

  @override
  String get speechMoonshineStaysDownloadable =>
      'Moonshine ডাউনলোডযোগ্য এবং অ্যাপ বান্ডেলের বাইরে থাকে। এই ডেস্কটপ ডিভাইসের জন্য একটি মডেল বাছুন এবং যদি আপনি স্থান ফিরে চান তাহলে পরে এটি সরান।';

  @override
  String get speechNative => 'নেটিভ';

  @override
  String get speechNativeSTTDisabled =>
      'এই অ্যাপে Linux-এ নেটিভ STT অক্ষম করা আছে। প্যারাকিট নতুন ইনস্টলের জন্য ডিফল্ট ইঞ্জিন।';

  @override
  String get speechNativeSTTWorks =>
      'Windows-এ CodeWalk তার WASAPI মাইক্রোফোন ব্যাকএন্ডের মাধ্যমে স্থানীয় অন-ডিভাইস স্পিচ রিকগনিশন ব্যবহার করে। স্থিতিশীলতার জন্য Windows-এর নেটিভ স্পিচ রিকগনিশন নিষ্ক্রিয় করা আছে।';

  @override
  String get speechNativeStartsFaster =>
      'নেটিভ দ্রুত শুরু হয়. শেরপা ভারী সেটআপ এবং গভীর মডেল নিয়ন্ত্রণ সহ সম্পূর্ণরূপে অন-ডিভাইস চালান।';

  @override
  String get speechOpenMicrophoneSettings => 'মাইক্রোফোন সেটিংস খুলুন';

  @override
  String get speechOpenSpeechPrivacy => 'স্পিচ গোপনীয়তা খুলুন';

  @override
  String get speechOpenSpeechSettings => 'স্পিচ সেটিংস খুলুন';

  @override
  String get speechParakeet => 'প্যারাকিট';

  @override
  String get speechParakeetModelsDesktop => 'প্যারাকিট মডেল (ডেস্কটপ)';

  @override
  String get speechParakeetStaysDownloadable =>
      'প্যারাকিট ডাউনলোডযোগ্য এবং অ্যাপ বান্ডিলের বাইরে থাকে। এটি বর্তমানে 25টি ইউরোপীয় ভাষার জন্য অপ্টিমাইজ করা একটি বহুভাষিক মডেল প্রকাশ করে।';

  @override
  String get speechPickLanguagePacks =>
      'ভাষা প্যাকগুলি বেছে নিন এবং ডিভাইসে শনাক্তকরণের জন্য মডেলগুলি ডাউনলোড/সরান৷';

  @override
  String get speechRemove => 'সরান';

  @override
  String speechRuntimeFailed(String service) {
    return '$service রানটাইম শুরু করতে ব্যর্থ হয়েছে।';
  }

  @override
  String get speechSelectSherpaAbove =>
      'ভাষা প্যাক পরিচালনা করতে এবং মডেল ডাউনলোড করতে উপরে শেরপা নির্বাচন করুন।';

  @override
  String get speechSenseVoice => 'সেন্সভয়েস';

  @override
  String get speechSenseVoiceModelsDesktop => 'SenseVoice মডেল (ডেস্কটপ)';

  @override
  String get speechSenseVoiceStaysDownloadable =>
      'SenseVoice ডাউনলোডযোগ্য এবং অ্যাপ বান্ডেলের বাইরে থাকে। এটি চাইনিজ, ক্যান্টনিজ, জাপানিজ, কোরিয়ান এবং ইংরেজির জন্য এখানে সবচেয়ে শক্তিশালী ডেস্কটপ বিকল্প।';

  @override
  String get speechSherpa => 'শেরপা';

  @override
  String get speechSherpaExperimentalFail =>
      'শেরপা পরীক্ষামূলক এবং কিছু ডিভাইসে ব্যর্থ হতে পারে। আপনি যদি সবচেয়ে স্থিতিশীল আচরণ চান তাহলে নেটিভ পছন্দ করুন।';

  @override
  String get speechSherpaModelsLinux => 'শেরপা মডেল (লিনাক্স)';

  @override
  String get speechSpeechText => 'টেক্সট থেকে বক্তৃতা';

  @override
  String speechUnavailableOnPlatform(String service) {
    return 'এই প্ল্যাটফর্মে $service স্পিচ উপলব্ধ নয়।';
  }

  @override
  String get speechWindowsSetupHint =>
      'Windows ভয়েস ইনপুট অন-ডিভাইস মডেলসহ CodeWalk WASAPI ক্যাপচার ব্যবহার করে। ডেস্কটপ অ্যাপগুলোর জন্য মাইক্রোফোন অ্যাক্সেস চালু রাখুন; নিচের বাটনগুলো সমস্যা সমাধানের জন্য Windows সেটিংস খোলে।';

  @override
  String get statusConnected => 'সংযুক্ত';

  @override
  String get statusDelayed => 'বিলম্বিত';

  @override
  String get statusFailed => 'ব্যর্থ';

  @override
  String get statusOffline => 'অফলাইন';

  @override
  String get statusOnline => 'অনলাইন';

  @override
  String get statusReconnecting => 'পুনরায় সংযোগ হচ্ছে';

  @override
  String get statusStarting => 'শুরু হচ্ছে';

  @override
  String get statusStopped => 'বন্ধ';

  @override
  String get statusStopping => 'বন্ধ হচ্ছে';

  @override
  String get statusSyncDelayed => 'সিঙ্ক বিলম্বিত';

  @override
  String get tailscaleNoPeers => 'কোনো সমবয়সীদের পাওয়া যায়নি';

  @override
  String get tailscaleNotSupportedOnPlatform =>
      'এই প্ল্যাটফর্মে Tailscale সমর্থিত নয়।';

  @override
  String get tailscaleNotSupportedOnWindows =>
      'Windows-এ Tailscale সমর্থিত নয়।';

  @override
  String get tailscalePeerOffline => 'অফলাইন';

  @override
  String get tailscaleSelectPeer => 'একটি টেলস্কেল সহকর্মী নির্বাচন করুন';

  @override
  String get tailscaleWaitingAdminApproval =>
      'এই Tailscale নোডটি অ্যাডমিন অনুমোদনের অপেক্ষায় রয়েছে।';

  @override
  String get terminalClose => 'টার্মিনাল বন্ধ করুন';

  @override
  String terminalConnectingTo(String serverName) {
    return '$serverName টার্মিনালে সংযুক্ত হচ্ছে...';
  }

  @override
  String terminalConnectionFailed(String error) {
    return 'টার্মিনাল সংযোগ ব্যর্থ হয়েছে: $error';
  }

  @override
  String get terminalDisconnected => 'টার্মিনাল সংযোগ বিচ্ছিন্ন।';

  @override
  String terminalEmbeddedUnavailable(String serverName) {
    return 'এমবেডেড টার্মিনাল এখনও এই রানটাইমে উপলব্ধ নয়। এককালীন কমান্ডের জন্য কম্পোজার শেল মোড ব্যবহার চালিয়ে যান বা $serverName-এর জন্য সমর্থित CodeWalk অ্যাপ রানটাইম থেকে টার্মিনাল খুলুন।';
  }

  @override
  String get terminalExtraKeyAlt => 'Alt কী';

  @override
  String get terminalExtraKeyArrowDown => 'নিচের তীর';

  @override
  String get terminalExtraKeyArrowLeft => 'বাঁ তীর';

  @override
  String get terminalExtraKeyArrowRight => 'ডান তীর';

  @override
  String get terminalExtraKeyArrowUp => 'উপরের তীর';

  @override
  String get terminalExtraKeyControl => 'Control কী';

  @override
  String get terminalExtraKeyEscape => 'Escape কী';

  @override
  String get terminalExtraKeyTab => 'Tab কী';

  @override
  String get terminalExtraKeys => 'টার্মিনালের অতিরিক্ত কী';

  @override
  String get terminalHide => 'টার্মিনাল লুকান';

  @override
  String get terminalMaximize => 'সর্বাধিক করুন';

  @override
  String get terminalMinimize => 'টার্মিনাল ছোট করুন';

  @override
  String get terminalNotAvailableYet =>
      'এমবেডেড টার্মিনাল এই রানটাইমে এখনও উপলব্ধ নয়।';

  @override
  String get terminalOpen => 'টার্মিনাল খুলুন';

  @override
  String get terminalOpenInfo => 'টার্মিনাল তথ্য খুলুন';

  @override
  String get terminalOpenProjectFirst =>
      'সার্ভার টার্মিনাল শুরু করার আগে একটি প্রজেক্ট ফোল্ডার খুলুন।';

  @override
  String get terminalOpenToConnect =>
      'সার্ভার প্রজেক্ট টার্মিনালে সংযোগ করতে টার্মিনাল খুলুন।';

  @override
  String get terminalReconnect => 'টার্মিনাল পুনরায় সংযোগ করুন';

  @override
  String get terminalRestoreSize => 'আকার পুনরুদ্ধার করুন';

  @override
  String get terminalSelectServer =>
      'টার্মিনাল খোলার আগে একটি সক্রিয় সার্ভার নির্বাচন করুন।';

  @override
  String get terminalSessionClosed => 'টার্মিনাল সেশন বন্ধ।';

  @override
  String get terminalTerminal => 'টার্মিনাল';

  @override
  String get terminalTitle => 'টার্মিনাল';

  @override
  String get terminalTryAgain => 'আবার চেষ্টা করুন';

  @override
  String get toolAwaitingInput => 'ইনপুট অপেক্ষা করছে';

  @override
  String get toolEditing => 'সম্পাদনা';

  @override
  String get toolEditingFiles => 'ফাইল সম্পাদনা';

  @override
  String get toolFinding => 'ফাইন্ডিং';

  @override
  String get toolFindingFiles => 'ফাইল খোঁজা';

  @override
  String get toolPresentationAwaitingInput => 'ইনপুট অপেক্ষা করছে';

  @override
  String get toolPresentationEditing => 'সম্পাদনা';

  @override
  String get toolPresentationEditingFiles => 'ফাইল সম্পাদনা';

  @override
  String get toolPresentationFinding => 'ফাইন্ডিং';

  @override
  String get toolPresentationFindingFiles => 'ফাইল খোঁজা';

  @override
  String get toolPresentationReading => 'পড়া';

  @override
  String get toolPresentationReadingFile => 'ফাইল পড়া';

  @override
  String get toolPresentationRunning => 'চলমান';

  @override
  String get toolPresentationRunningCommand => 'চলমান কমান্ড';

  @override
  String toolPresentationRunningTool(String toolName) {
    return '$toolName চলছে';
  }

  @override
  String get toolPresentationSearching => 'অনুসন্ধান করা হচ্ছে';

  @override
  String get toolPresentationSearchingCode => 'অনুসন্ধান কোড';

  @override
  String get toolPresentationSearchingWeb => 'ওয়েবে অনুসন্ধান করা হচ্ছে';

  @override
  String get toolPresentationTool => 'টুল';

  @override
  String get toolPresentationUpdatingTaskList => 'টাস্ক লিস্ট আপডেট করা হচ্ছে';

  @override
  String get toolPresentationUpdatingTasks => 'কাজ আপডেট করা হচ্ছে';

  @override
  String get toolPresentationWaitingInput => 'আপনার ইনপুট জন্য অপেক্ষা';

  @override
  String get toolPresentationWriting => 'লেখা';

  @override
  String get toolPresentationWritingFile => 'ফাইল লেখা';

  @override
  String get toolReading => 'পড়া';

  @override
  String get toolReadingFile => 'ফাইল পড়া';

  @override
  String get toolRunning => 'চলমান';

  @override
  String get toolRunningCommand => 'চলমান কমান্ড';

  @override
  String get toolRunningTask => 'চলমান টাস্ক';

  @override
  String get toolSearching => 'অনুসন্ধান করা হচ্ছে';

  @override
  String get toolSearchingCode => 'অনুসন্ধান কোড';

  @override
  String get toolSearchingWeb => 'ওয়েবে অনুসন্ধান করা হচ্ছে';

  @override
  String get toolUpdatingTaskList => 'টাস্ক লিস্ট আপডেট করা হচ্ছে';

  @override
  String get toolUpdatingTasks => 'কাজ আপডেট করা হচ্ছে';

  @override
  String get toolWaitingForInput => 'আপনার ইনপুট জন্য অপেক্ষা';

  @override
  String get toolWriting => 'লেখা';

  @override
  String get toolWritingFile => 'ফাইল লেখা';

  @override
  String get tourBack => 'ব্যাক';

  @override
  String get tourSkip => 'এড়িয়ে যান';

  @override
  String get trayQuit => 'প্রস্থান করুন';

  @override
  String get trayShow => 'দেখান';

  @override
  String get useOAuthCloudflareAccess =>
      'OAuth ব্যবহার করুন (ক্লাউডফ্লেয়ার অ্যাক্সেস)';

  @override
  String get useOAuthCloudflareAccessSubtitle =>
      'Cloudflare অ্যাক্সেস পরিচালিত OAuth-এর জন্য একটি ব্রাউজার খোলে।';

  @override
  String get useOAuthCloudflareAccessUnsupported =>
      'এই প্ল্যাটফর্মে Cloudflare অ্যাক্সেস OAuth উপলব্ধ নেই৷ পরিবর্তে মৌলিক প্রমাণীকরণ ব্যবহার করুন।';

  @override
  String get useTailscale => 'টেলস্কেল ব্যবহার করুন';

  @override
  String get useTailscaleSubtitle =>
      'একটি সিস্টেম VPN ছাড়া টেলস্কেল নেটওয়ার্কের মাধ্যমে ট্র্যাফিককে রুট করে।';

  @override
  String get useTailscaleUnsupported => 'এই প্ল্যাটফর্মে টেলস্কেল সমর্থিত নয়।';

  @override
  String get utilityTitle => 'ইউটিলিটি';

  @override
  String get workspaceBrowseDirs => 'ডিরেক্টরি ব্রাউজ করুন';

  @override
  String get workspaceChooseFolderOpen =>
      'প্রকল্পের প্রসঙ্গ হিসাবে খুলতে যেকোনো ফোল্ডার বেছে নিন।';

  @override
  String workspaceCloseProject(String project) {
    return '$project বন্ধ করুন';
  }

  @override
  String get workspaceClosedProjects => 'বন্ধ প্রজেক্ট সমূহ';

  @override
  String workspaceCurrentDirectory(String path) {
    return 'বর্তমান ডিরেক্টরি: $path';
  }

  @override
  String get workspaceFilterDirs => 'ফিল্টার ডিরেক্টরি';

  @override
  String get workspaceOpenFolder => 'ফোল্ডার খুলুন';

  @override
  String get workspaceOpenProjectFolder => 'প্রকল্প ফোল্ডার খুলুন';

  @override
  String get workspaceOpenProjects => 'খোলা প্রজেক্ট সমূহ';

  @override
  String get workspaceProjectDirectory => 'প্রকল্প ডিরেক্টরি';

  @override
  String get workspaceProjectHint => '/repo/my-project';

  @override
  String workspaceRemoveFromHistory(String name) {
    return 'ইতিহাস থেকে $name সরান';
  }

  @override
  String get settingsSessionAttentionTitle => 'সেশন মনোযোগ';

  @override
  String get settingsSessionAttentionDescription =>
      'ঐচ্ছিক বাবল বা প্যানেলে রুট সেশনের অবস্থা দেখায়।';

  @override
  String get settingsSessionAttentionOff => 'বন্ধ';

  @override
  String get settingsSessionAttentionBubble => 'বাবল';

  @override
  String get settingsSessionAttentionPanel => 'প্যানেল';

  @override
  String get settingsSessionAttentionPrivacy =>
      'Android-এ চালু করলে একটি স্থায়ী ফোরগ্রাউন্ড পরিষেবা শুরু হয়। উত্তরের লেখা এনক্রিপ্ট করে রাখা হয়; পড়ুন চাপার পরেই ক্লাউড TTS লেখা পাঠায়।';

  @override
  String get settingsSessionAttentionUnavailable =>
      'এই প্ল্যাটফর্মে সেশন মনোযোগ উপলভ্য নয়।';

  @override
  String get settingsSessionAttentionOpenSettings => 'ডিসপ্লে সেটিংস খুলুন';

  @override
  String get settingsSessionAttentionStop => 'সেশন মনোযোগ বন্ধ করুন';

  @override
  String get settingsSessionAttentionThirdPartyTtsWarning =>
      'পড়ুন চাপলে উত্তরের লেখা কনফিগার করা তৃতীয়-পক্ষ TTS প্রদানকারীর কাছে পাঠানো হতে পারে।';

  @override
  String get workspaceSuggestions => 'পরামর্শ';

  @override
  String get sessionTabsGestureHintTitle => 'সেশন ট্যাবে নতুন নিয়ন্ত্রণ আছে';

  @override
  String get sessionTabsGestureHintBody =>
      'একটি ট্যাব বন্ধ করতে ডাবল-ক্লিক করুন বা ডাবল-ট্যাপ করুন। সেশন অ্যাকশন খুলতে ডান-ক্লিক করুন বা চেপে ধরে রাখুন। প্রদর্শন টগল থেকে ট্যাব নিষ্ক্রিয় করা যায়।';

  @override
  String get sessionTabsGestureHintAcknowledge => 'বুঝেছি';

  @override
  String get sessionTabsGestureHintDisableTabs => 'ট্যাব নিষ্ক্রিয় করুন';

  @override
  String get sessionTabRenameAction => 'সেশনের নাম পরিবর্তন করুন';

  @override
  String sessionTabClosedMessage(String title) {
    return 'ট্যাব \"$title\" বন্ধ হয়েছে';
  }

  @override
  String get sessionTabUndo => 'পূর্বাবস্থায় ফেরান';

  @override
  String get sessionTabRestoreFailed => 'ট্যাব পুনরুদ্ধার করা যায়নি।';

  @override
  String get sessionTabChangeIconAction => 'আইকন পরিবর্তন করুন';

  @override
  String get sessionTabIconPickerTitle => 'ট্যাব আইকন চয়ন করুন';

  @override
  String get sessionTabIconUseProjectIcon => 'প্রজেক্ট আইকন ব্যবহার করুন';

  @override
  String get sessionTabIconApplied => 'ট্যাব আইকন আপডেট হয়েছে।';

  @override
  String get sessionTabIconSaveFailed => 'ট্যাব আইকন সংরক্ষণ করা যায়নি।';

  @override
  String get sessionTabIconPresetCode => 'কোড';

  @override
  String get sessionTabIconPresetTerminal => 'টার্মিনাল';

  @override
  String get sessionTabIconPresetBug => 'বাগ';

  @override
  String get sessionTabIconPresetTasks => 'কাজ';

  @override
  String get sessionTabIconPresetLaunch => 'চালু করুন';

  @override
  String get sessionTabIconPresetIdea => 'আইডিয়া';

  @override
  String get sessionTabIconPresetResearch => 'গবেষণা';

  @override
  String get sessionTabIconPresetDesign => 'ডিজাইন';

  @override
  String get sessionTabIconPresetData => 'ডেটা';

  @override
  String get sessionTabIconPresetCloud => 'ক্লাউড';

  @override
  String get sessionTabIconPresetSecurity => 'নিরাপত্তা';

  @override
  String get sessionTabIconPresetTools => 'টুলস';

  @override
  String get workspaceNoActiveContext => 'কোনো সক্রিয় কনটেক্সট নেই';

  @override
  String get settingsAppearanceContrastLow => 'নিম্ন';

  @override
  String get settingsAppearanceContrastStandard => 'মানক';

  @override
  String get settingsAppearanceContrastMedium => 'মাঝারি';

  @override
  String get settingsAppearanceContrastMediumHigh => 'মাঝারি-উচ্চ';

  @override
  String get settingsNotificationsSystemSoundsWebUnavailable =>
      'ওয়েবে উপলব্ধ নয়।';

  @override
  String get settingsNotificationsSystemSoundsAndroid =>
      'সিস্টেম থেকে Android নোটিফিকেশন শব্দ।';

  @override
  String get settingsNotificationsSystemSoundsFreedesktop =>
      '/usr/share/sounds/freedesktop/stereo থেকে Freedesktop শব্দ।';

  @override
  String get settingsNotificationsSystemSoundsPlatform =>
      'অপারেটিং সিস্টেম যেখানে সিস্টেম শব্দ প্রদান করে সেখানে সমর্থিত।';

  @override
  String get serversQuickGuideTitle => 'দ্রুত সেটআপ';

  @override
  String get serversQuickGuideIntro =>
      'CodeWalk হলো অ্যাপটি। OpenCode হলো ইঞ্জিন — এই সংযোগ কাজ করার আগে এটি চালু থাকতে হবে।';

  @override
  String get serversQuickGuideStepInstallCli => '১. OpenCode CLI ইনস্টল করুন।';

  @override
  String get serversQuickGuideRunPowerShell => '২. PowerShell-এ চালান:';

  @override
  String get serversQuickGuideRunTerminal => '২. আপনার টার্মিনালে চালান:';

  @override
  String get serversQuickGuideProtectPassword =>
      'পাসওয়ার্ড দিয়ে অ্যাক্সেস সুরক্ষিত করুন';

  @override
  String get serversQuickGuideServerPassword => 'সার্ভার পাসওয়ার্ড';

  @override
  String get serversQuickGuideInstallOptions =>
      'অন্যান্য অফিসিয়াল ইনস্টল বিকল্প: ইনস্টল স্ক্রিপ্ট, npm, bun, pnpm, Homebrew, অথবা GitHub Releases থেকে একটি বাইনারি।';

  @override
  String get serversQuickGuideVerifyHint =>
      'সার্ভার চালু করার পর, URLটি CodeWalk-এ পেস্ট করার আগে /global/health বা /doc সাড়া দেয় কিনা নিশ্চিত করুন।';

  @override
  String get shortcutsPressKeyCombination => 'এখন কী কম্বিনেশন টিপুন';

  @override
  String get settingsProvenanceOpenCodeBacked => 'OpenCode-সমর্থিত';

  @override
  String get settingsProvenanceCodeWalkLocal => 'CodeWalk-স্থানীয়';

  @override
  String get settingsProvenanceCodeWalkException => 'CodeWalk ব্যতিক্রম';

  @override
  String get shortcutsErrorInvalid => 'অবৈধ শর্টকাট';

  @override
  String get shortcutsErrorUnsupportedKey => 'অসমর্থিত শর্টকাট কী';

  @override
  String shortcutsErrorConflict(String conflict) {
    return '\"$conflict\"-এর সাথে সংঘর্ষ';
  }

  @override
  String get settingsSessionAttentionStopSaveFailed =>
      'সেশন অ্যাটেনশন বন্ধ করা হয়েছে কিন্তু সেটিংটি সংরক্ষণ করা যায়নি।';

  @override
  String get settingsSessionAttentionEnableFailed =>
      'সেশন অ্যাটেনশন চালু করা যায়নি।';

  @override
  String get settingsSessionAttentionSaveFailedStopped =>
      'সেশন অ্যাটেনশন সংরক্ষণ করা যায়নি এবং এটি বন্ধ করা হয়েছে।';

  @override
  String get settingsSessionAttentionStillRunning =>
      'সেশন অ্যাটেনশন এখনও চলছে। এটি আবার বন্ধ করার চেষ্টা করুন।';

  @override
  String get settingsSessionAttentionStopFailed =>
      'সেশন অ্যাটেনশন বন্ধ করা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get settingsSessionAttentionCapabilityUnavailable =>
      'সেশন অ্যাটেনশন হোস্ট ক্ষমতা উপলব্ধ নেই।';

  @override
  String get settingsServerFallbackProviderName =>
      'সার্ভারে কনফিগার করা হয়েছে';

  @override
  String get composerStopResponse => 'উত্তর বন্ধ করুন';

  @override
  String get composerSendMessageWhileResponding =>
      'উত্তর চলাকালীন বার্তা পাঠান';

  @override
  String get composerSendMessage => 'বার্তা পাঠান';

  @override
  String get chatTourComposerDescription => 'এখানে আপনার অনুরোধ টাইপ করুন।';

  @override
  String get chatTourSendDescription => 'এখানে আপনার বার্তা পাঠান।';

  @override
  String get composerAttachmentFallbackName => 'সংযুক্তি';

  @override
  String get composerContextFallbackName => 'কনটেক্সট';

  @override
  String get searchableDropdownSearchHint => 'অনুসন্ধান';

  @override
  String get searchableDropdownEmptyText => 'কোনো মিল পাওয়া যায়নি';

  @override
  String get speechApiKeyStorageUnavailable =>
      'নিরাপদ TTS API কী স্টোরেজ উপলব্ধ নেই।';

  @override
  String get speechApiKeyRemoved => 'API কী মুছে ফেলা হয়েছে।';

  @override
  String get speechApiKeySaved =>
      'API কী এই ডিভাইসে নিরাপদে সংরক্ষণ করা হয়েছে।';

  @override
  String get speechReadAloudTestText =>
      'এটি একটি CodeWalk টেক্সট-টু-স্পিচ পরীক্ষা।';

  @override
  String get speechNativeDisabledWindows =>
      'স্থিতিশীলতার জন্য Windows-এ অক্ষম। CodeWalk WASAPI ক্যাপচারের মাধ্যমে Parakeet বা অন্য কোনো অন-ডিভাইস ইঞ্জিন ব্যবহার করুন।';

  @override
  String get speechNativeUnavailableLinux =>
      'Linux-এ উপলব্ধ নয়। স্পিচ ইনপুটের জন্য Parakeet ব্যবহার করুন।';

  @override
  String get speechNotAvailableOnPlatform => 'এই প্ল্যাটফর্মে উপলব্ধ নয়।';

  @override
  String get speechSherpaUnavailableAndroid =>
      'ছোট APK আকারের জন্য অপ্টিমাইজ করা Android বিল্ডে উপলব্ধ নয়।';

  @override
  String get speechMoonshineDesktopOnlyHint =>
      'শুধুমাত্র ডেস্কটপে উপলব্ধ। Android শুধুমাত্র নেটিভ থাকবে।';

  @override
  String get speechParakeetDesktopOnlyHint =>
      'শুধুমাত্র ডেস্কটপে উপলব্ধ। অফলাইন বহুভাষিক শনাক্তকরণ ব্যবহার করে।';

  @override
  String get speechSenseVoiceDesktopOnlyHint =>
      'শুধুমাত্র ডেস্কটপে উপলব্ধ। চাইনিজ, ক্যান্টোনিজ, জাপানিজ, কোরিয়ান এবং ইংরেজির জন্য সবচেয়ে শক্তিশালী।';

  @override
  String get speechNativeSubtitle => 'সহজ এবং দ্রুত স্টার্টআপ।';

  @override
  String get speechSherpaSubtitle =>
      'ভারী, পরীক্ষামূলক এবং বাগ-প্রবণ। ডাউনলোড করা মডেলের সাথে প্রায়শই বেশি নির্ভুল।';

  @override
  String get speechMoonshineSubtitle =>
      'sherpa_onnx অফলাইন শনাক্তকরণ এবং ডাউনলোডযোগ্য মডেল ব্যবহার করে শুধুমাত্র ডেস্কটপের পরীক্ষামূলক পথ।';

  @override
  String get speechParakeetSubtitle =>
      'একটি বহুভাষিক ডাউনলোডযোগ্য মডেলসহ শুধুমাত্র ডেস্কটপের অফলাইন NeMo ট্রান্সডিউসার পথ।';

  @override
  String get speechSenseVoiceSubtitle =>
      'চাইনিজ, ক্যান্টোনিজ, জাপানিজ, কোরিয়ান এবং ইংরেজির জন্য টিউন করা শুধুমাত্র ডেস্কটপের অফলাইন পথ।';

  @override
  String get speechMoonshineModel => 'Moonshine মডেল';

  @override
  String get speechSherpaLanguage => 'Sherpa ভাষা';

  @override
  String get speechSearchSherpaLanguage => 'Sherpa ভাষা অনুসন্ধান করুন';

  @override
  String get speechNoLanguagePacksFound => 'কোনো ভাষা প্যাক পাওয়া যায়নি';

  @override
  String get speechTextToSpeechProvider => 'টেক্সট-টু-স্পিচ প্রদানকারী';

  @override
  String get speechProviderSystemNative => 'সিস্টেম / নেটিভ';

  @override
  String get speechProviderEdgeExperimental =>
      'Microsoft Edge Speech (পরীক্ষামূলক)';

  @override
  String get speechProviderOpenAiCompatible => 'OpenAI-সামঞ্জস্যপূর্ণ';

  @override
  String get speechProviderElevenLabs => 'ElevenLabs';

  @override
  String get speechProviderNvidiaNim => 'NVIDIA NIM';

  @override
  String get speechNimSpeedNotSupported =>
      'Speed is not supported by NVIDIA NIM TTS and is hidden for this provider.';

  @override
  String get speechRemoteVoice => 'Voice';

  @override
  String get speechRemoteVoiceUnavailable =>
      'The selected voice is no longer available in the provider catalog.';

  @override
  String get speechRemoteVoiceListUnavailable =>
      'Using the default voice. The voice list could not be loaded right now.';

  @override
  String get speechRemoteVoicesLoaded => 'Loaded from the provider voices.';

  @override
  String get speechRemoteModel => 'Model';

  @override
  String get speechRemoteModelListUnavailable =>
      'The model list could not be loaded right now. You can type a custom model below.';

  @override
  String get speechRemoteModelsLoaded => 'Loaded from the provider models.';

  @override
  String get speechCustomModel => 'Custom model…';

  @override
  String get speechEdgeExperimentalTitle => 'Microsoft Edge Speech পরীক্ষামূলক';

  @override
  String get speechEdgeExperimentalDescription =>
      'এই ডিভাইস থেকে সরাসরি অননুমোদিত Edge Read Aloud পরিষেবা ব্যবহার করে। আপনি read aloud ব্যবহার করলে বার্তার টেক্সট Microsoft-এ পাঠানো হয় এবং Microsoft প্রাইভেট প্রোটোকল পরিবর্তন করলে পরিষেবাটি ভেঙে যেতে পারে।';

  @override
  String get speechEdgeVoice => 'Edge ভয়েস';

  @override
  String get speechEdgeVoiceUnavailable =>
      'নির্বাচিত ভোয়সটি আর উপলব্ধ নেই। ডিফল্ট Edge ভোয়স ব্যবহার করা হচ্ছে।';

  @override
  String get speechEdgeVoiceListUnavailable =>
      'ডিফল্ট Edge ভয়েস ব্যবহার করা হচ্ছে। এই মুহূর্তে ভয়েস তালিকা লোড করা যায়নি।';

  @override
  String get speechEdgeVoicesLoaded =>
      'Microsoft Edge Speech ভয়েস থেকে লোড করা হয়েছে।';

  @override
  String get speechCloudTtsPrivacy => 'ক্লাউড TTS গোপনীয়তা';

  @override
  String get speechCloudTtsPrivacyDescription =>
      'ক্লাউড TTS নির্বাচিত সহকারী বার্তার টেক্সট কনফিগার করা প্রদানকারীর কাছে পাঠায়। API কী এই ডিভাইসের নিরাপদ স্টোরেজে সংরক্ষিত থাকে।';

  @override
  String get speechBaseUrl => 'বেস URL';

  @override
  String get speechApiKey => 'API কী';

  @override
  String get speechApiKeySavedHelper =>
      'একটি কী সংরক্ষিত আছে। এটি প্রতিস্থাপন করতে একটি নতুন মান লিখুন, অথবা মুছে ফেলতে একটি খালি মান সংরক্ষণ করুন।';

  @override
  String get speechNoApiKeySaved => 'কোনো API কী সংরক্ষিত নেই।';

  @override
  String get speechSaveApiKey => 'API কী সংরক্ষণ করুন';

  @override
  String get speechModel => 'মডেল';

  @override
  String get speechPitchNotSupported =>
      'OpenAI-সামঞ্জস্যপূর্ণ TTS পিচ সমর্থন করে না, তাই এই প্রদানকারীর জন্য এটি লুকানো আছে।';

  @override
  String get speechPitchHiddenForProvider =>
      'Pitch is not supported by this TTS provider and is hidden.';

  @override
  String get speechTestVoice => 'ভয়েস পরীক্ষা করুন';

  @override
  String get dialogMoonshineVoiceSetupDescription =>
      'Moonshine sherpa_onnx-এর মাধ্যমে অন-ডিভাইসে চলে। একবার একটি মডেল বেছে নিন এবং এটি শুধুমাত্র এই ডেস্কটপ ডিভাইসের জন্য ডাউনলোড করুন।';

  @override
  String get dialogParakeetVoiceSetupDescription =>
      'Parakeet sherpa_onnx অফলাইন শনাক্তকরণের মাধ্যমে অন-ডিভাইসে চলে। বহুভাষিক STT সক্ষম করতে এই ডেস্কটপ ডিভাইসের জন্য এটি একবার ডাউনলোড করুন।';

  @override
  String get dialogSenseVoiceSetupDescription =>
      'SenseVoice sherpa_onnx অফলাইন শনাক্তকরণের মাধ্যমে অন-ডিভাইসে চলে। এটি চাইনিজ, ক্যান্টোনিজ, জাপানিজ, কোরিয়ান এবং ইংরেজির জন্য সবচেয়ে শক্তিশালী।';

  @override
  String get dialogSherpaVoiceSetupDescription =>
      'Sherpa ভয়েস ইনপুটের জন্য একটি অন-ডিভাইস স্পিচ মডেল প্রয়োজন। আপনার ভাষা নির্বাচন করুন এবং এটি একবার ডাউনলোড করুন (~147 MB)।';

  @override
  String speechSilenceSeconds(String value) {
    return '$value সেকেন্ড';
  }

  @override
  String speechModelInstalled(String modelId) {
    return 'মডেল ইনস্টল করা হয়েছে ($modelId)';
  }

  @override
  String speechModelMissing(String modelId) {
    return 'মডেল নেই ($modelId)';
  }

  @override
  String speechModelSizeMb(String sizeMb) {
    return '~$sizeMb MB';
  }

  @override
  String speechSystemDefaultLanguage(String language) {
    return 'সিস্টেম ডিফল্ট ($language)';
  }

  @override
  String speechModelListLoadFailed(String error, String service) {
    return '$service মডেল তালিকা লোড করা ব্যর্থ হয়েছে: $error';
  }

  @override
  String speechDownloadFailed(String error) {
    return 'ডাউনলোড ব্যর্থ হয়েছে: $error';
  }

  @override
  String speechFailedToRemoveModel(String error) {
    return 'মডেল সরানো ব্যর্থ হয়েছে: $error';
  }

  @override
  String speechBaseUrlExample(String url) {
    return 'উদাহরণ: $url';
  }

  @override
  String speechModelDefaultHelper(String model) {
    return 'ডিফল্ট: $model';
  }

  @override
  String get notificationPermissionOrQuestionNeedsInput =>
      'একটি টুল অনুমতি বা প্রশ্নে আপনার ইনপুট প্রয়োজন।';

  @override
  String get notificationPermissionNeedsInput =>
      'একটি টুল অনুমতিতে আপনার ইনপুট প্রয়োজন।';

  @override
  String get notificationQuestionNeedsInput =>
      'একটি টুল প্রশ্নে আপনার ইনপুট প্রয়োজন।';

  @override
  String get notificationSessionError => 'একটি সেশন একটি ত্রুটি রিপোর্ট করেছে।';

  @override
  String get notificationChannelErrors => 'CodeWalk ত্রুটি';

  @override
  String get notificationChannelErrorsDescription => 'CodeWalk ত্রুটি সতর্কতা';

  @override
  String get notificationChannelPermissions => 'CodeWalk অনুমতি';

  @override
  String get notificationChannelPermissionsDescription =>
      'CodeWalk অ্যাকশন প্রয়োজনীয় সতর্কতা';

  @override
  String get notificationChannelAgent => 'CodeWalk এজেন্ট';

  @override
  String get notificationChannelAgentDescription =>
      'CodeWalk এজেন্ট সম্পন্ন হওয়ার সতর্কতা';

  @override
  String get notificationActionOpen => 'খুলুন';

  @override
  String get foregroundMonitorNotificationBody =>
      'নির্ভরযোগ্য ব্যাকগ্রাউন্ড সতর্কতা সক্রিয়';

  @override
  String get foregroundMonitorNotificationTitle =>
      'ব্যাকগ্রাউন্ড মনিটরিং সক্রিয়';

  @override
  String get foregroundMonitorNotificationOneSession =>
      'একটি সেশন মনিটর করা হচ্ছে';

  @override
  String foregroundMonitorNotificationSessionCount(int count) {
    return '$countটি সেশন মনিটর করা হচ্ছে';
  }

  @override
  String sessionAttentionSemanticLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি সেশনে মনোযোগ প্রয়োজন',
      one: '১টি সেশনে মনোযোগ প্রয়োজন',
    );
    return '$_temp0';
  }

  @override
  String get sessionAttentionOverlayPermissionRequired =>
      'অন্যান্য অ্যাপের উপরে প্রদর্শনের অনুমতি প্রয়োজন।';

  @override
  String get sessionAttentionIosInAppOnly =>
      'সেশন অ্যাটেনশন শুধুমাত্র CodeWalk-এর ভিতরে উপলব্ধ।';

  @override
  String get sessionAttentionOverlayPermissionGrantPrompt =>
      'অন্যান্য অ্যাপের উপরে প্রদর্শনের অনুমতি দিন, তারপর আবার চেষ্টা করুন।';

  @override
  String get sessionAttentionAndroidStartFailed =>
      'Android সেশন অ্যাটেনশন পরিষেবা শুরু করা যায়নি।';

  @override
  String chatMessageTruncatedChars(int count, String reason) {
    return '[$count অক্ষর ছাঁটা হয়েছে] $reason';
  }

  @override
  String get chatMessageJustNow => 'এইমাত্র';

  @override
  String chatMessageMinutesAgo(int count) {
    return '$count মি. আগে';
  }

  @override
  String chatMessageHoursAgo(int count) {
    return '$count ঘণ্টা আগে';
  }

  @override
  String chatMessageDaysAgo(int count) {
    return '$count দিন আগে';
  }

  @override
  String chatMessageDateTime(int day, int hour, int minute, int month) {
    return '$month/$day $hour:$minute';
  }

  @override
  String get chatMessageYourMessage => 'আপনার বার্তা';

  @override
  String get chatMessageAssistantMessage => 'সহকারীর বার্তা';

  @override
  String chatMessageStepStarted(int step) {
    return 'ধাপ #$step শুরু হয়েছে';
  }

  @override
  String chatMessageStepStartedWithSnapshot(String snapshot, int step) {
    return 'ধাপ #$step শুরু হয়েছে: $snapshot';
  }

  @override
  String chatMessageStepFinished(
    String cost,
    String reason,
    int step,
    int tokens,
  ) {
    return 'ধাপ #$step শেষ হয়েছে: $reason • টোকেন $tokens • \$$cost';
  }

  @override
  String chatMessagePatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি প্যাচ',
      one: '১টি প্যাচ',
    );
    return '$_temp0';
  }

  @override
  String get chatMessageToolRun => 'টুল রান';

  @override
  String get chatMessageToolExecution => 'টুল এক্সিকিউশন';

  @override
  String chatMessageToolChainMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$countটি আরও',
      one: '+১টি আরও',
    );
    return '$_temp0';
  }

  @override
  String chatMessageToolChainExtraTypes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$countটি ধরন',
      one: '+১টি ধরন',
    );
    return '$_temp0';
  }

  @override
  String chatMessageToolAttentionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটিতে মনোযোগ প্রয়োজন',
      one: '১টিতে মনোযোগ প্রয়োজন',
    );
    return '$_temp0';
  }

  @override
  String chatMessageToolDoneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি সম্পন্ন',
      one: '১টি সম্পন্ন',
    );
    return '$_temp0';
  }

  @override
  String get chatMessageToolCallsTitle => 'টুল কল';

  @override
  String get chatMessageDiffPreviewTruncated =>
      'অ্যাপ স্থিতিশীলতার জন্য ডিফ প্রিভিউ ছাঁটা হয়েছে।';

  @override
  String get chatMessageLargeMessageTruncated =>
      'অ্যাপ স্থিতিশীলতার জন্য বড় বার্তার প্রিভিউ ছাঁটা হয়েছে।';

  @override
  String get chatMessageInvalidLinkFormat => 'অবৈধ লিংক ফরম্যাট';

  @override
  String get chatMessageUnableToOpenLink => 'লিংক খোলা যাচ্ছে না';

  @override
  String sessionTodoInProgressCompact(int current, int total) {
    return '$current/$total চলছে';
  }

  @override
  String sessionTodoTaskProgress(String content, int index, int total) {
    return 'কাজ $index/$total $content';
  }

  @override
  String sessionTodoDoneCompact(int count, int total) {
    return '$count/$total সম্পন্ন';
  }

  @override
  String sessionTodoCompletedCount(int count, int total) {
    return 'কাজ $count/$total সম্পন্ন হয়েছে';
  }

  @override
  String sessionTodoTasksCount(int count) {
    return 'কাজ ($count)';
  }

  @override
  String questionStepOfReview(int current, int total) {
    return 'ধাপ $current/$total - পর্যালোচনা';
  }

  @override
  String questionStepOfQuestion(int current, int total) {
    return 'ধাপ $current/$total - প্রশ্ন';
  }

  @override
  String get questionCustomAnswer => 'কাস্টম উত্তর';

  @override
  String get questionSubmitAnswers => 'উত্তর জমা দিন';

  @override
  String get questionReviewAnswers => 'উত্তর পর্যালোচনা করুন';

  @override
  String permissionRequestTitle(String permission) {
    return 'অনুমতির অনুরোধ: $permission';
  }

  @override
  String get sessionTitleCannotBeEmpty => 'শিরোনাম খালি হতে পারে না';

  @override
  String get filesFailedToLoad => 'ফাইল লোড করতে ব্যর্থ';

  @override
  String get filesFailedToSearch => 'ফাইল অনুসন্ধান করতে ব্যর্থ';

  @override
  String get filesNoOpenFilesHint =>
      'এখনও কোনো খোলা ফাইল নেই। অনুসন্ধান করতে টাইপ করুন।';

  @override
  String get filesNoContentMatches => 'কোনো বিষয়বস্তু মিল পাওয়া যায়নি';

  @override
  String filesOpenFilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count টি খোলা ফাইল',
      one: '১টি খোলা ফাইল',
    );
    return '$_temp0';
  }

  @override
  String filesLinesSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count টি লাইন নির্বাচিত',
      one: '১টি লাইন নির্বাচিত',
    );
    return '$_temp0';
  }

  @override
  String get filesDraftTooLargeToSave =>
      'খসড়াটি সম্পাদক থেকে সংরক্ষণ করার মতো খুব বড়।';

  @override
  String get filesSaveChangesBeforeClose =>
      'এই ফাইলটি বন্ধ করার আগে পরিবর্তনগুলি সংরক্ষণ করুন।';

  @override
  String get filesSaveChangesBeforePathChange =>
      'এই পাথ পরিবর্তন করার আগে পরিবর্তনগুলি সংরক্ষণ করুন।';

  @override
  String get filesWaitForSaveBeforePathChange =>
      'এই পাথ পরিবর্তন করার আগে ফাইল সংরক্ষণ শেষ হওয়ার জন্য অপেক্ষা করুন।';

  @override
  String get filesWaitForFileOperation =>
      'ফাইল অপারেশন শেষ হওয়ার জন্য অপেক্ষা করুন।';

  @override
  String get filesLargeFileReadOnly =>
      'সম্পাদনা সচল রাখতে বড় ফাইলগুলো শুধুমাত্র পড়ার জন্য খোলে।';

  @override
  String get filesCheckingWriteSupport =>
      'ফাইলে লেখার সমর্থন পরীক্ষা করা হচ্ছে...';

  @override
  String get filesActiveProjectRequired =>
      'ফাইল অপারেশনের জন্য একটি সক্রিয় প্রজেক্ট ডিরেক্টরি প্রয়োজন।';

  @override
  String get filesReloadSkippedUnsavedChanges =>
      'অসংরক্ষিত পরিবর্তন আছে; রিলোড এড়িয়ে যাওয়া হয়েছে।';

  @override
  String get filesFailedToLoadContent => 'ফাইলের বিষয়বস্তু লোড করতে ব্যর্থ';

  @override
  String get filesFileSaved => 'ফাইল সংরক্ষিত হয়েছে।';

  @override
  String get filesParentNotDirectory => 'প্যারেন্ট একটি ডিরেক্টরি নয়।';

  @override
  String get filesMalformedResponse =>
      'ফাইল অপারেশন একটি অবৈধ প্রতিক্রিয়া ফিরিয়েছে।';

  @override
  String get filesShellCommandDidNotComplete =>
      'ফাইল অপারেশনের শেল কমান্ড সম্পূর্ণ হয়নি।';

  @override
  String get filesShellCommandNoResult =>
      'ফাইল অপারেশনের শেল কমান্ড কোনো ফলাফল ফেরত দেয়নি।';

  @override
  String get filesShellCommandTruncated =>
      'ফাইল অপারেশনের শেল কমান্ড সার্ভার দ্বারা ছাঁটাই করা হয়েছে।';

  @override
  String get filesShellCommandSyntaxError =>
      'ফাইল অপারেশনের শেল কমান্ড সিনট্যাক্স ত্রুটির কারণে ব্যর্থ হয়েছে।';

  @override
  String get filesShellUtilityNotFound =>
      'একটি প্রয়োজনীয় শেল ইউটিলিটি পাওয়া যায়নি।';

  @override
  String get filesShellCommandFailed =>
      'ফাইল অপারেশনের শেল কমান্ড ফলাফল ফেরত দেওয়ার আগেই ব্যর্থ হয়েছে।';

  @override
  String get attachmentSaveTitle => 'সংযুক্তি সংরক্ষণ করুন';

  @override
  String get attachmentBrowserSandboxLocalFile =>
      'ব্রাউজার স্যান্ডবক্স সরাসরি স্থানীয় file:// সংযুক্তি খুলতে বাধা দেয়।';

  @override
  String get attachmentLocalPathBrowserBlocked =>
      'এই সংযুক্তিটি এমন একটি স্থানীয় পাথের দিকে নির্দেশ করে যা ব্রাউজার থেকে খোলা যায় না।';

  @override
  String terminalConnectedTo(String directory, String serverName) {
    return '$directory-এ $serverName-এর সাথে সংযুক্ত';
  }

  @override
  String get terminalTransportUnavailable => 'টার্মিনাল ট্রান্সপোর্ট অনুপলব্ধ।';

  @override
  String get chatSlashCommandNew => 'নতুন চ্যাট সেশন তৈরি করুন';

  @override
  String get chatSlashCommandModels => 'মডেল নির্বাচক খুলুন';

  @override
  String get chatSlashCommandSessions => 'কথোপকথনের তালিকা খুলুন';

  @override
  String get chatSlashCommandAgent => 'এজেন্ট নির্বাচক খুলুন';

  @override
  String get chatSlashCommandOpen => 'ফাইল খোলার দ্রুত অ্যাকশন';

  @override
  String get chatSlashCommandHelp => 'কমান্ড সাহায্য দেখান';

  @override
  String get chatSlashCommandCompact =>
      'বর্তমান সেশনের প্রসঙ্গ কম্প্যাক্ট করুন';

  @override
  String get chatSlashCommandThinking => 'চিন্তার বুদবুদ টগল করুন';

  @override
  String get chatSlashCommandUndo =>
      'শেষ দৃশ্যমান ব্যবহারকারীর পালা পূর্বাবস্থায় ফেরান';

  @override
  String get chatSlashCommandRedo =>
      'শেষ পূর্বাবস্থায় ফেরানো পালা পুনরায় করুন';

  @override
  String chatSessionSubConversationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count টি উপ-কথোপকথন',
      one: '১টি উপ-কথোপকথন',
    );
    return '$_temp0';
  }

  @override
  String chatMessageWeeksAgo(int count) {
    return '$count সপ্তাহ আগে';
  }

  @override
  String chatMessageShortDate(int day, int month) {
    return '$month/$day';
  }

  @override
  String get chatProviderErrorLoadSessionStatus =>
      'সেশনের স্থিতি লোড করতে ব্যর্থ';

  @override
  String get chatProviderErrorLoadSessionDetails =>
      'কিছু সেশন বিবরণ লোড করা যায়নি';

  @override
  String chatProviderErrorLoadSessionList(String error) {
    return 'সেশনের তালিকা লোড করতে ব্যর্থ: $error';
  }

  @override
  String get chatProviderErrorCreateSession => 'সেশন তৈরি করতে ব্যর্থ';

  @override
  String get chatProviderErrorSelectProviderModelBeforeSend =>
      'পাঠানোর আগে একটি সংযুক্ত প্রদানকারী বা বিনামূল্যের OpenCode মডেল নির্বাচন করুন';

  @override
  String get chatProviderErrorStartMessageSend =>
      'বার্তা পাঠানো শুরু করতে ব্যর্থ';

  @override
  String get chatProviderErrorStopUnavailable =>
      'বর্তমান সেশনের জন্য থামানো অনুপলব্ধ';

  @override
  String get chatProviderErrorWaitForResponseFinish =>
      'কম্প্যাক্ট করার আগে বর্তমান প্রতিক্রিয়া শেষ হওয়ার জন্য অপেক্ষা করুন';

  @override
  String get chatProviderErrorCompactUnavailable =>
      'বর্তমান সেশনের জন্য কমপ্যাক্ট প্রসঙ্গ অনুপলব্ধ';

  @override
  String get chatProviderErrorSelectModelBeforeCompact =>
      'প্রসঙ্গ কম্প্যাক্ট করার আগে একটি মডেল নির্বাচন করুন';

  @override
  String get chatProviderErrorCompactSessionContext =>
      'সেশনের প্রসঙ্গ কম্প্যাক্ট করতে ব্যর্থ';

  @override
  String get chatProviderErrorNetwork =>
      'নেটওয়ার্ক সংযোগ ব্যর্থ হয়েছে। অনুগ্রহ করে নেটওয়ার্ক সেটিংস পরীক্ষা করুন';

  @override
  String get chatProviderErrorServer =>
      'সার্ভার ত্রুটি। অনুগ্রহ করে পরে আবার চেষ্টা করুন';

  @override
  String get chatProviderErrorNotFound => 'রিসোর্স পাওয়া যায়নি';

  @override
  String get chatProviderErrorInvalidInput => 'অবৈধ ইনপুট প্যারামিটার';

  @override
  String get chatProviderErrorUnknown =>
      'অজানা ত্রুটি। অনুগ্রহ করে পরে আবার চেষ্টা করুন';

  @override
  String get chatProviderErrorSessionFallback => 'সেশন ত্রুটি';

  @override
  String get projectProviderErrorNoProjectContext =>
      'সার্ভার থেকে কোনো প্রজেক্ট প্রসঙ্গ উপলব্ধ নেই';

  @override
  String projectProviderErrorInitializeFailed(String error) {
    return 'প্রজেক্ট প্রসঙ্গ শুরু করতে ব্যর্থ: $error';
  }

  @override
  String get projectProviderErrorSwitchProjectNotFound =>
      'প্রজেক্ট পরিবর্তন করতে ব্যর্থ: প্রজেক্ট পাওয়া যায়নি';

  @override
  String get projectProviderErrorSwitchDirectoryEmpty =>
      'প্রজেক্ট পরিবর্তন করতে ব্যর্থ: ডিরেক্টরি খালি';

  @override
  String get projectProviderErrorAtLeastOneContext =>
      'অন্তত একটি প্রসঙ্গ খোলা থাকতে হবে';

  @override
  String get projectProviderErrorReopenProjectNotFound =>
      'প্রজেক্ট পুনরায় খুলতে ব্যর্থ: প্রজেক্ট পাওয়া যায়নি';

  @override
  String get projectProviderErrorOnlyClosedArchivable =>
      'শুধুমাত্র বন্ধ প্রজেক্ট সংরক্ষণাগারভুক্ত করা যাবে';

  @override
  String get projectProviderErrorArchiveProjectNotFound =>
      'প্রজেক্ট সংরক্ষণাগারভুক্ত করতে ব্যর্থ: প্রজেক্ট পাওয়া যায়নি';

  @override
  String get projectProviderErrorArchiveProjectPathInvalid =>
      'প্রজেক্ট সংরক্ষণাগারভুক্ত করতে ব্যর্থ: প্রজেক্ট পাথ অবৈধ';

  @override
  String projectProviderErrorLoadWorkspaces(String error) {
    return 'ওয়ার্কস্পেস লোড করতে ব্যর্থ: $error';
  }

  @override
  String get projectProviderErrorWorkspaceNameEmpty =>
      'ওয়ার্কস্পেসের নাম খালি হতে পারে না';

  @override
  String projectProviderErrorCreateWorkspace(String error) {
    return 'ওয়ার্কস্পেস তৈরি করতে ব্যর্থ: $error';
  }

  @override
  String projectProviderErrorResetWorkspace(String error) {
    return 'ওয়ার্কস্পেস রিসেট করতে ব্যর্থ: $error';
  }

  @override
  String projectProviderErrorDeleteWorkspace(String error) {
    return 'ওয়ার্কস্পেস মুছতে ব্যর্থ: $error';
  }

  @override
  String get projectProviderErrorDirectoryEmpty => 'ডিরেক্টরি খালি হতে পারে না';

  @override
  String projectProviderErrorListDirectories(String error) {
    return 'ডিরেক্টরি তালিকাভুক্ত করতে ব্যর্থ: $error';
  }

  @override
  String projectProviderErrorValidateDirectory(String error) {
    return 'ডিরেক্টরি যাচাই করতে ব্যর্থ: $error';
  }

  @override
  String get projectProviderErrorPathEmpty => 'পাথ খালি হতে পারে না';

  @override
  String projectProviderErrorListFiles(String error) {
    return 'ফাইল তালিকাভুক্ত করতে ব্যর্থ: $error';
  }

  @override
  String projectProviderErrorSearchFiles(String error) {
    return 'ফাইল অনুসন্ধান করতে ব্যর্থ: $error';
  }

  @override
  String projectProviderErrorContentSearchUnavailable(String error) {
    return 'বিষয়বস্তু অনুসন্ধান উপলব্ধ নয়: $error';
  }

  @override
  String projectProviderErrorSearchSymbols(String error) {
    return 'প্রতীক অনুসন্ধান করতে ব্যর্থ: $error';
  }

  @override
  String projectProviderErrorReadFile(String error) {
    return 'ফাইল পড়তে ব্যর্থ: $error';
  }

  @override
  String projectProviderErrorLoadProjectList(String error) {
    return 'প্রজেক্টের তালিকা লোড করতে ব্যর্থ: $error';
  }

  @override
  String get workspaceProjectRemovedFromHistory =>
      'প্রজেক্ট ইতিহাস থেকে সরানো হয়েছে';

  @override
  String workspaceProjectContextOpened(String directory) {
    return 'প্রজেক্ট প্রসঙ্গ খোলা হয়েছে: $directory';
  }

  @override
  String workspaceFailedToOpenProjectContext(String directory) {
    return 'প্রজেক্ট প্রসঙ্গ খুলতে ব্যর্থ: $directory';
  }

  @override
  String get chatAbortNotice => 'আপনি কী ভিন্নভাবে করতে চান?';

  @override
  String sessionTitleToday(String date, String time) {
    return 'আজ $time ($date)';
  }

  @override
  String sessionTitleYesterday(String date, String time) {
    return 'গতকাল $time ($date)';
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
  String get sessionWeekdayMon => 'সোম';

  @override
  String get sessionWeekdayTue => 'মঙ্গল';

  @override
  String get sessionWeekdayWed => 'বুধ';

  @override
  String get sessionWeekdayThu => 'বৃহস্পতি';

  @override
  String get sessionWeekdayFri => 'শুক্র';

  @override
  String get sessionWeekdaySat => 'শনি';

  @override
  String get sessionWeekdaySun => 'রবি';

  @override
  String get forwardTimeNow => 'এখন';

  @override
  String forwardTimeMinutes(int count) {
    return '$count মিনিট';
  }

  @override
  String forwardTimeHours(int count) {
    return '$count ঘণ্টা';
  }

  @override
  String forwardTimeDays(int count) {
    return '$count দিন';
  }

  @override
  String forwardTimeWeeks(int count) {
    return '$count সপ্তাহ';
  }

  @override
  String get settingsBehaviorConfigFieldDefaultModel => 'ডিফল্ট মডেল';

  @override
  String get settingsBehaviorConfigFieldDefaultAgent => 'ডিফল্ট এজেন্ট';

  @override
  String get settingsBehaviorConfigFieldSmallModel => 'ছোট মডেল';

  @override
  String get settingsBehaviorConfigFieldAutoUpdateMode => 'অটো-আপডেট মোড';

  @override
  String get settingsBehaviorConfigFieldSnapshotSetting => 'স্ন্যাপশট সেটিং';

  @override
  String get settingsBehaviorConfigFieldConversationUsername =>
      'কথোপকথন ব্যবহারকারীর নাম';

  @override
  String get settingsBehaviorConfigFieldSharingDefault => 'শেয়ারিং ডিফল্ট';

  @override
  String get speechMicNoInputDevice =>
      'কোনো মাইক্রোফোন ইনপুট ডিভাইস উপলব্ধ নেই।';

  @override
  String get speechMicDeviceBusy =>
      'ডিফল্ট মাইক্রোফোনটি বর্তমানে অন্য একটি অ্যাপ ব্যবহার করছে।';

  @override
  String get speechMicUnsupportedFormat =>
      'ডিফল্ট মাইক্রোফোন ফরম্যাট সমর্থিত নয়।';

  @override
  String get speechMicSpeechPrivacy =>
      'Windows স্পিচ পরিষেবাগুলি নিষ্ক্রিয় থাকতে পারে (স্পিচ গোপনীয়তা, অনলাইন স্পিচ রিকগনিশন, বা ভাষা প্যাক)।';

  @override
  String get speechMicBackendUnavailable =>
      'এই বিল্ডে Windows মাইক্রোফোন ব্যাকএন্ড উপলব্ধ নয়।';

  @override
  String speechEngineFallbackNotice(String fallback, String reason) {
    return 'নির্বাচিত STT ইঞ্জিন অনুপলব্ধ ($reason)। পরিবর্তে $fallback ব্যবহার করা হচ্ছে।';
  }

  @override
  String get oauthFlowSecureStorageUnavailable =>
      'OAuth-এর জন্য নিরাপদ পরিচয়পত্র স্টোরেজ অনুপলব্ধ।';

  @override
  String get oauthFlowUnexpectedError =>
      'OAuth ফ্লো অপ্রত্যাশিতভাবে ব্যর্থ হয়েছে। অনুগ্রহ করে আবার চেষ্টা করুন।';

  @override
  String get oauthFlowNoEndpointsDiscovered =>
      'কোনো OAuth এন্ডপয়েন্ট আবিষ্কৃত হয়নি। Cloudflare Dashboard → Access → Applications → [এই অ্যাপ]-এ Managed OAuth সক্ষম করুন।';

  @override
  String get oauthFlowTokenResponseMissingAccessToken =>
      'OAuth টোকেন প্রতিক্রিয়ায় একটি অ্যাক্সেস টোকেন অন্তর্ভুক্ত ছিল না।';

  @override
  String get oauthFlowProfileChanged =>
      'OAuth শেষ হওয়ার আগেই সার্ভার প্রোফাইল পরিবর্তিত হয়েছে।';

  @override
  String get oauthFlowMetadataMissingEndpoints =>
      'OAuth মেটাডেটায় অনুমোদন/টোকেন এন্ডপয়েন্ট অনুপস্থিত।';

  @override
  String get oauthFlowCallbackNotCompleted => 'অনুমোদন কলব্যাক সম্পূর্ণ হয়নি';

  @override
  String get oauthFlowProviderDeclined =>
      'অনুমোদন সার্ভার OAuth অনুরোধটি প্রত্যাখ্যান করেছে। অনুগ্রহ করে আবার চেষ্টা করুন।';

  @override
  String get oauthFlowCallbackValidationFailed =>
      'OAuth কলব্যাক যাচাই ব্যর্থ হয়েছে। অনুগ্রহ করে আবার চেষ্টা করুন।';

  @override
  String get oauthFlowCallbackServerStartFailed =>
      'স্থানীয় OAuth কলব্যাক সার্ভার শুরু করতে ব্যর্থ হয়েছে।';

  @override
  String get oauthFlowSignInCanceled => 'OAuth সাইন-ইন বাতিল করা হয়েছে।';

  @override
  String get oauthFlowBrowserOpenFailed =>
      'OAuth সাইন-ইনের জন্য সিস্টেম ব্রাউজার খোলা যায়নি।';

  @override
  String get oauthFlowCallbackTimeout =>
      '৫ মিনিটের মধ্যে অ্যাপে কোনো অনুমোদন কলব্যাক পৌঁছায়নি। সম্মতির পর ব্রাউজারটি স্থানীয় কলব্যাক ঠিকানায় পুনঃনির্দেশিত হওয়ার কথা ছিল। যদি ব্রাউজারটি পরিবর্তে একটি সংযোগ ত্রুটি দেখায়, তাহলে এই ডিভাইস বা নেটওয়ার্ক লুপব্যাক রিডাইরেক্ট ব্লক করে।';

  @override
  String oauthFlowTokenExchangeTransientFailure(int maxAttempts) {
    return 'অস্থায়ী নেটওয়ার্ক সমস্যার কারণে $maxAttempts বার চেষ্টার পরেও টোকেন বিনিময় ব্যর্থ হয়েছে। অনুগ্রহ করে আবার চেষ্টা করুন।';
  }

  @override
  String oauthFlowTokenExchangeHttpFailure(int statusCode) {
    return 'টোকেন বিনিময় ব্যর্থ হয়েছে (HTTP $statusCode)। অনুগ্রহ করে আবার চেষ্টা করুন।';
  }

  @override
  String get oauthFlowTokenExchangeUnexpectedFailure =>
      'টোকেন বিনিময় অপ্রত্যাশিতভাবে ব্যর্থ হয়েছে। অনুগ্রহ করে আবার চেষ্টা করুন।';

  @override
  String get oauthFlowTokenExchangeIncomplete =>
      'অনুমোদন কোড পাঠানোর পরেও টোকেন বিনিময় সম্পূর্ণ হয়নি। অনুগ্রহ করে আবার OAuth সাইন-ইন শুরু করুন।';

  @override
  String get speechReadAloudFailed => 'টেক্সট-টু-স্পিচ ব্যর্থ হয়েছে।';

  @override
  String get speechReadAloudNoText => 'জোরে পড়ার জন্য কোনো টেক্সট নেই।';

  @override
  String get speechEdgeTextTooLong =>
      'Microsoft Edge Speech একবারে সর্বোচ্চ 4096 বাইট পড়তে পারে।';

  @override
  String get speechEdgeMalformedAudio =>
      'Microsoft Edge Speech ত্রুটিপূর্ণ অডিও ডেটা ফিরিয়েছে।';

  @override
  String get speechEdgeUnsupportedAudio =>
      'Microsoft Edge Speech অসমর্থিত অডিও ডেটা ফিরিয়েছে।';

  @override
  String get speechEdgeUnsupportedFrame =>
      'Microsoft Edge Speech একটি অসমর্থিত websocket ফ্রেম ফিরিয়েছে।';

  @override
  String get speechEdgeSynthesisInterrupted =>
      'সংশ্লেষণ সম্পূর্ণ হওয়ার আগেই Microsoft Edge Speech শেষ হয়ে গেছে।';

  @override
  String get speechEdgeEmptyAudio =>
      'Microsoft Edge Speech একটি খালি অডিও প্রতিক্রিয়া ফিরিয়েছে।';

  @override
  String get speechEdgeTimedOut =>
      'Microsoft Edge Speech-এর সময়সীমা শেষ হয়েছে।';

  @override
  String get speechEdgeUnreachable => 'Microsoft Edge Speech-এ পৌঁছানো যায়নি।';

  @override
  String get speechApiKeyMissing =>
      'এই TTS প্রদানকারী ব্যবহার করতে Settings > Speech-এ একটি API কী যোগ করুন।';

  @override
  String get speechProviderEmptyAudio =>
      'TTS প্রদানকারী একটি খালি অডিও প্রতিক্রিয়া ফিরিয়েছে।';

  @override
  String get speechProviderRequestRejected =>
      'TTS প্রদানকারী স্পিচ অনুরোধটি প্রত্যাখ্যান করেছে।';

  @override
  String get speechApiKeyRejected =>
      'TTS API কী প্রদানকারী দ্বারা প্রত্যাখ্যাত হয়েছে।';

  @override
  String get speechProviderQuotaRateLimit =>
      'TTS প্রদানকারী একটি কোটা বা রেট সীমা জানিয়েছে।';

  @override
  String get speechReadAloudNoVoice => 'Select a voice for this TTS provider.';

  @override
  String get speechProviderTextTooLong =>
      'The text is too long for this TTS model.';

  @override
  String get speechProviderInvalidAudio =>
      'The TTS provider returned unrecognized audio.';

  @override
  String get speechNimBaseUrlRequired =>
      'Enter the NVIDIA NIM deployment base URL in Settings > Speech.';

  @override
  String get speechProviderTemporarilyUnavailable =>
      'TTS প্রদানকারী সাময়িকভাবে অনুপলব্ধ।';

  @override
  String get speechProviderUnreachable => 'TTS প্রদানকারীতে পৌঁছানো যায়নি।';

  @override
  String appProviderErrorFailedToStartProcess(String tool) {
    return '$tool প্রক্রিয়া শুরু করতে ব্যর্থ হয়েছে।';
  }

  @override
  String appProviderErrorToolNotAvailable(String runtime, String tool) {
    return '$tool উপলব্ধ নেই। প্রথমে $runtime ইনস্টল করুন।';
  }

  @override
  String appProviderErrorToolInstallFailed(int exitCode, String tool) {
    return '$tool ইনস্টল ব্যর্থ হয়েছে এক্সিট কোড $exitCode সহ।';
  }

  @override
  String appProviderErrorBunBootstrapFailed(int exitCode) {
    return 'Bun বুটস্ট্র্যাপ ব্যর্থ হয়েছে এক্সিট কোড $exitCode সহ।';
  }

  @override
  String get appProviderErrorInstalledButNotFoundInPath =>
      'OpenCode ইনস্টলেশন শেষ হয়েছে কিন্তু কমান্ডটি PATH-এ পাওয়া যায়নি।';

  @override
  String get appProviderErrorInstalledButPathNotResolved =>
      'OpenCode ইনস্টলেশন শেষ হয়েছে কিন্তু কমান্ডের পথ নির্ধারণ করা যায়নি।';

  @override
  String appProviderErrorConfiguredCommandNotFound(String tool) {
    return 'কনফিগার করা কমান্ড পাওয়া যায়নি এবং $tool PATH-এ নেই।';
  }

  @override
  String get appProviderErrorConfiguredCommandPathMissing =>
      'কনফিগার করা কমান্ডের পথ বিদ্যমান নেই।';

  @override
  String get appProviderErrorConfiguredCommandVersionCheckFailed =>
      'কনফিগার করা কমান্ড বিদ্যমান কিন্তু সংস্করণ যাচাই ব্যর্থ হয়েছে।';

  @override
  String get appProviderErrorConfiguredCommandExecutionFailed =>
      'কনফিগার করা কমান্ডটি কার্যকর করা যায়নি।';

  @override
  String get appProviderWslCheckWindowsOnly =>
      'WSL চেক শুধুমাত্র Windows-এ প্রযোজ্য।';

  @override
  String get appProviderDesktopBuildRequired =>
      'পরিচালিত স্থানীয় সার্ভার কনফিগার করতে একটি ডেস্কটপ বিল্ড ব্যবহার করুন।';

  @override
  String get appProviderKnownInstallationDirectoryDetected =>
      'একটি পরিচিত ইনস্টলেশন ডিরেক্টরি থেকে সনাক্ত করা হয়েছে।';

  @override
  String appProviderKnownInstallationPathRefreshHint(String appName) {
    return 'একটি পরিচিত ইনস্টলেশন ডিরেক্টরি থেকে সনাক্ত করা হয়েছে। PATH রিফ্রেশের প্রয়োজন হতে পারে; সাম্প্রতিক ইনস্টল এখনও সনাক্ত না হলে $appName পুনরায় খুলুন।';
  }

  @override
  String get appProviderErrorReleaseMetadataFetchFailed =>
      'GitHub থেকে সর্বশেষ রিলিজ মেটাডেটা আনতে ব্যর্থ হয়েছে।';

  @override
  String get appProviderErrorReleaseAssetListMissing =>
      'সর্বশেষ রিলিজ মেটাডেটায় অ্যাসেট তালিকা অন্তর্ভুক্ত ছিল না।';

  @override
  String get appProviderErrorNoCompatibleAsset =>
      'কোনো সামঞ্জস্যপূর্ণ OpenCode বাইনারি অ্যাসেট পাওয়া যায়নি।';

  @override
  String get appProviderErrorDownloadAssetFailed =>
      'নির্বাচিত OpenCode অ্যাসেট ডাউনলোড করতে ব্যর্থ হয়েছে।';

  @override
  String get appProviderErrorChecksumVerificationFailed =>
      'ডাউনলোড করা অ্যাসেটের চেকসাম যাচাই ব্যর্থ হয়েছে।';

  @override
  String get appProviderErrorExtractArchiveFailed =>
      'OpenCode বাইনারি আর্কাইভ নিষ্কাশন করতে ব্যর্থ হয়েছে।';

  @override
  String appProviderErrorExecutableNotFound(String tool) {
    return 'নিষ্কাশিত ফাইলগুলিতে $tool এক্সিকিউটেবল পাওয়া যায়নি।';
  }

  @override
  String get chatNoResponseFromServer =>
      'সার্ভার থেকে কোনো সাড়া নেই। অনুগ্রহ করে আবার চেষ্টা করুন।';

  @override
  String get chatNoResponseFromModel =>
      'মডেল থেকে কোনো সাড়া নেই। অনুগ্রহ করে আবার চেষ্টা করুন।';

  @override
  String get speechJobCancelled => 'স্পিচ কাজটি বাতিল করা হয়েছে।';

  @override
  String get speechEdgeCancelled => 'Microsoft Edge Speech বাতিল করা হয়েছে।';

  @override
  String get sessionAttentionKindActive => 'সক্রিয়';

  @override
  String get sessionAttentionKindReceiving => 'গ্রহণ করা হচ্ছে';

  @override
  String get sessionAttentionKindDelayed => 'বিলম্বিত';

  @override
  String get sessionAttentionKindCompleted => 'সম্পন্ন';

  @override
  String get sessionAttentionKindPendingInteraction =>
      'মিথস্ক্রিয়ার অপেক্ষায়';

  @override
  String get sessionAttentionKindError => 'ত্রুটি';

  @override
  String get sessionAttentionPauseCellularDataSaver =>
      'সেলুলার ডেটা সেভার সক্রিয়';

  @override
  String get sessionAttentionPauseOauthReopenRequired =>
      'OAuth সাইন-ইন প্রয়োজন';

  @override
  String get sessionAttentionPauseTailscaleReopenRequired =>
      'Tailscale সংযোগ প্রয়োজন';

  @override
  String get sessionAttentionPauseOffline => 'অফলাইন';

  @override
  String get sessionAttentionPausePermissionRevoked =>
      'অনুমতি প্রত্যাহার করা হয়েছে';

  @override
  String get sessionAttentionPauseServiceStopped => 'পরিষেবা বন্ধ';

  @override
  String get sessionAttentionPauseHostUnavailable => 'হোস্ট অনুপলব্ধ';

  @override
  String get errorRequestCancelled => 'অনুরোধ বাতিল হয়েছে';

  @override
  String errorUnknownNetworkError(String error) {
    return 'অজানা নেটওয়ার্ক ত্রুটি: $error';
  }

  @override
  String get errorCertificateError => 'সার্টিফিকেট ত্রুটি';

  @override
  String get errorSessionBusy => 'সেশন অন্য একটি অনুরোধ প্রক্রিয়াকরণে ব্যস্ত।';

  @override
  String get errorRunShellCommandFailed => 'শেল কমান্ড চালানো ব্যর্থ হয়েছে';

  @override
  String get errorRunSlashCommandFailed =>
      'স্ল্যাশ কমান্ড চালানো ব্যর্থ হয়েছে';

  @override
  String get settingsBehaviorOpenCodeDefaultsLoadError =>
      'সক্রিয় সার্ভার থেকে OpenCode-সমর্থিত ডিফল্ট লোড করা যায়নি।';

  @override
  String get sessionTabIconRemoveFailed =>
      'স্থানীয় সেশনের ট্যাব আইকন ডেটা সরাতে ব্যর্থ হয়েছে';

  @override
  String get forwardUntitled => 'শিরোনামহীন';

  @override
  String setupDebugLinuxLogsPath(String path) {
    return 'Linux লগ: $path';
  }

  @override
  String setupDebugRunOpenCodeCommand(String command) {
    return 'OpenCode চালান: $command';
  }

  @override
  String setupDebugServerHealthEndpoint(String endpoint) {
    return 'সার্ভার হেলথ: $endpoint';
  }

  @override
  String setupDebugServerDocsEndpoint(String endpoint) {
    return 'সার্ভার ডকস: $endpoint';
  }

  @override
  String get logsEntryError => 'ত্রুটি';

  @override
  String get logsEntryStack => 'স্ট্যাক';

  @override
  String get setupDebugSourceDiagnostics => 'ডায়াগনস্টিকস';

  @override
  String get setupDebugSourceUseExisting => 'বিদ্যমান ব্যবহার করুন';

  @override
  String get setupDebugSourceLocalServer => 'স্থানীয় সার্ভার';

  @override
  String get setupDebugSourceOnboarding => 'অনবোর্ডিং';

  @override
  String get setupDebugSourceManualConnection => 'ম্যানুয়াল সংযোগ';

  @override
  String setupDebugMessageDiagnosticsResult(
    String availability,
    String platform,
    String recommendation,
  ) {
    return '$platform-এ $availability। $recommendation';
  }

  @override
  String get setupDebugMessageDetectAttempt =>
      'বর্তমান পরিবেশ থেকে একটি বিদ্যমান OpenCode কমান্ড সনাক্ত করার চেষ্টা করা হচ্ছে।';

  @override
  String get setupDebugMessageInstallStarted =>
      'CodeWalk থেকে OpenCode ইনস্টলেশন শুরু হয়েছে।';

  @override
  String setupDebugMessageStartLocalServer(String url) {
    return '$url-এ পরিচালিত OpenCode সার্ভার চালু করা হচ্ছে।';
  }

  @override
  String setupDebugMessageHealthyRunning(String url) {
    return 'পরিচালিত OpenCode সার্ভার সুস্থ আছে এবং $url-এ চলছে।';
  }

  @override
  String get setupDebugMessageStoppingLocalServer =>
      'পরিচালিত OpenCode সার্ভার বন্ধ করা হচ্ছে।';

  @override
  String get setupDebugMessageStoppedCleanly =>
      'পরিচালিত OpenCode সার্ভার সঠিকভাবে বন্ধ হয়েছে।';

  @override
  String get setupDebugMessageExitedAfterRequestedStop =>
      'অনুরোধকৃত বন্ধের পরে পরিচালিত OpenCode সার্ভার বন্ধ হয়ে গেছে।';

  @override
  String get setupDebugMessageOnboardingConnectExisting =>
      'ব্যবহারকারী একটি বিদ্যমান OpenCode সার্ভারে সংযোগ করতে বেছে নিয়েছেন।';

  @override
  String get setupDebugMessageOnboardingGuidedPath =>
      'ব্যবহারকারী নির্দেশিত OpenCode সেটআপ পথ খুলেছেন।';

  @override
  String get setupDebugMessageOnboardingManagedLocal =>
      'ব্যবহারকারী পরিচালিত স্থানীয় OpenCode সেটআপ খুলেছেন।';

  @override
  String get setupDebugMessageOnboardingOpenedServerSettings =>
      'ব্যর্থ হেলথ চেকের পরে ব্যবহারকারী সার্ভার সেটিংস খুলেছেন।';

  @override
  String get setupDebugMessageOnboardingAddAnotherServer =>
      'ব্যর্থ হেলথ চেকের পরে ব্যবহারকারী আরেকটি সার্ভার যোগ করতে বেছে নিয়েছেন।';

  @override
  String setupDebugMessageTestingServerUrl(String url) {
    return 'অনবোর্ডিং থেকে OpenCode সার্ভারের URL $url পরীক্ষা করা হচ্ছে।';
  }

  @override
  String get chatProviderErrorSessionNotFound => 'সেশন পাওয়া যায়নি';

  @override
  String get chatProviderErrorInvalidMessageFormat => 'অবৈধ মেসেজ ফরম্যাট';

  @override
  String get chatProviderErrorNetworkShort => 'নেটওয়ার্ক সংযোগ ব্যর্থ হয়েছে';

  @override
  String get chatProviderErrorUnknownShort => 'অজানা ত্রুটি';

  @override
  String get terminalCreateFailed => 'টার্মিনাল সেশন তৈরি করতে ব্যর্থ';

  @override
  String get terminalEndpointUnavailable => 'টার্মিনাল এন্ডপয়েন্ট উপলব্ধ নয়';

  @override
  String get terminalInvalidDirectory => 'অবৈধ টার্মিনাল ডিরেক্টরি';

  @override
  String get terminalWebsocketUnavailable =>
      'টার্মিনাল websocket এখানে উপলব্ধ নয়।';

  @override
  String chatMessageToolChainCallsCompact(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি কল',
      one: '১টি কল',
    );
    return '$_temp0';
  }

  @override
  String get errorConnectionTimeout => 'সংযোগের সময়সীমা শেষ হয়েছে';

  @override
  String get errorClientError => 'ক্লায়েন্ট ত্রুটি';

  @override
  String get chatProviderErrorSendMessage => 'বার্তা পাঠানো ব্যর্থ হয়েছে';

  @override
  String get speechApiEngine => 'API';

  @override
  String get speechApiEngineSubtitle =>
      'OpenAI, Groq অথবা একটি কাস্টম OpenAI-সামঞ্জস্যপূর্ণ এন্ডপয়েন্ট।';

  @override
  String get speechApiProvider => 'স্পিচ-টু-টেক্সট প্রদানকারী';

  @override
  String get speechCloudSttPrivacy => 'ক্লাউড স্পিচ-টু-টেক্সট গোপনীয়তা';

  @override
  String get speechCloudSttPrivacyDescription =>
      'রেকর্ড করা মাইক্রোফোন অডিও কনফিগার করা প্রদানকারীর কাছে পাঠানো হয়। API কী এই ডিভাইসের নিরাপদ স্টোরেজে থাকে।';

  @override
  String get speechApiKeyOptional => 'কাস্টম এন্ডপয়েন্টের জন্য ঐচ্ছিক।';

  @override
  String speechApiBatchHint(String provider) {
    return '$provider ব্যাচ ট্রান্সক্রিপশন ব্যবহার করে। থামাতে ও ট্রান্সক্রিপ্ট করতে আবার মাইক্রোফোনে আলতো চাপুন।';
  }

  @override
  String get speechApiWebUnavailable =>
      'API স্পিচ-টু-টেক্সট ওয়েব বিল্ডে উপলব্ধ নয়।';

  @override
  String get speechApiConfigInvalid =>
      'স্পিচ API এন্ডপয়েন্ট এবং মডেল পরীক্ষা করুন। রিমোট এন্ডপয়েন্টে অবশ্যই HTTPS ব্যবহার করতে হবে।';

  @override
  String get speechApiRequestInvalid =>
      'স্পিচ এন্ডপয়েন্ট বা মডেল প্রত্যাখ্যান করা হয়েছে।';

  @override
  String get speechApiRateLimited =>
      'স্পিচ প্রদানকারী একটি কোটা বা রেট লিমিট জানিয়েছে।';

  @override
  String get speechApiUnavailable => 'স্পিচ প্রদানকারী সাময়িকভাবে অনুপলব্ধ।';

  @override
  String get speechApiNetwork => 'স্পিচ প্রদানকারীর সাথে যোগাযোগ করা যায়নি।';

  @override
  String get speechApiInvalidResponse =>
      'স্পিচ প্রদানকারী একটি অবৈধ প্রতিক্রিয়া ফিরিয়েছে।';

  @override
  String get speechApiEmptyAudio => 'কোনো মাইক্রোফোন অডিও ধারণ করা হয়নি।';

  @override
  String get speechApiEmptyTranscript =>
      'স্পিচ প্রদানকারী কোনো ট্রান্সক্রিপশন ফিরিয়ে দেয়নি।';

  @override
  String get speechApiCustomProvider => 'কাস্টম OpenAI-সামঞ্জস্যপূর্ণ';

  @override
  String get speechApiMaxDuration =>
      'API রেকর্ডিং ২ মিনিট পরে স্বয়ংক্রিয়ভাবে বন্ধ হয়।';

  @override
  String get speechApiLanguageHint =>
      'সক্রিয় অ্যাপ ভাষা ট্রান্সক্রিপশন ইঙ্গিত হিসেবে পাঠানো হয়।';

  @override
  String get speechSttApiKeyStorageUnavailable =>
      'নিরাপদ স্পিচ API কী স্টোরেজ উপলব্ধ নয়।';

  @override
  String get speechSttApiKeyMissing =>
      'সেটিংস > স্পিচে একটি স্পিচ API কী যোগ করুন।';

  @override
  String get speechSttApiKeyRejected => 'স্পিচ API কী প্রত্যাখ্যান করা হয়েছে।';

  @override
  String get carMessagingReply => 'উত্তর';

  @override
  String get carMessagingMarkRead => 'পঠিত হিসেবে চিহ্নিত করুন';

  @override
  String get carMessagingDeliveryFailedTitle => 'উত্তর পাঠানো যায়নি';

  @override
  String get carMessagingDeliveryFailedBody =>
      'আপনার ভয়েস উত্তরটি পৌঁছে দেওয়া যায়নি। আবার চেষ্টা করতে CodeWalk খুলুন।';
}
