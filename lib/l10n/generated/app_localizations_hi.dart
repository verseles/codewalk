// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get aboutGitHub => 'GitHub';

  @override
  String get appProviderCannotActivateUnhealthy =>
      'एक अस्वस्थ सर्वर को सक्रिय नहीं किया जा सकता';

  @override
  String get appProviderDesktopOnly =>
      'प्रबंधित स्थानीय सर्वर केवल डेस्कटॉप पर उपलब्ध है।';

  @override
  String get appProviderDetectingCommand =>
      'OpenCode कमांड का पता लगाया जा रहा है...';

  @override
  String get appProviderErrorCannotActivateUnhealthy =>
      'एक अस्वस्थ सर्वर को सक्रिय नहीं किया जा सकता';

  @override
  String get appProviderErrorCloudflareOAuthNotSupported =>
      'Cloudflare Access OAuth इस प्लेटफॉर्म पर समर्थित नहीं है';

  @override
  String get appProviderErrorInstallationFailed => 'OpenCode स्थापना विफल रही।';

  @override
  String get appProviderErrorInvalidServerUrl => 'अमान्य सर्वर URL';

  @override
  String get appProviderErrorLocalServerHealthCheckFailed =>
      'स्थानीय सर्वर शुरू हुआ लेकिन स्वास्थ्य जांच पास नहीं हुई।';

  @override
  String get appProviderErrorManagedDesktopOnly =>
      'प्रबंधित स्थानीय सर्वर केवल डेस्कटॉप पर उपलब्ध है।';

  @override
  String get appProviderErrorServerAlreadyExists =>
      'इस URL वाला सर्वर पहले से मौजूद है';

  @override
  String get appProviderErrorServerProfileNotFound =>
      'सर्वर प्रोफाइल नहीं मिला';

  @override
  String get appProviderErrorServerUrlRequired => 'सर्वर URL आवश्यक है';

  @override
  String get appProviderErrorTailscaleNotSupported =>
      'Tailscale इस प्लेटफॉर्म पर समर्थित नहीं है';

  @override
  String appProviderExitedWithCode(int code) {
    return 'स्थानीय सर्वर कोड $code के साथ बाहर निकल गया।';
  }

  @override
  String get appProviderFailedToStart =>
      'स्थानीय OpenCode सर्वर शुरू करने में विफल।';

  @override
  String get appProviderInstallBinary => 'बाइनरी स्थापित करें';

  @override
  String get appProviderInstallBunOpenCode => 'Bun + OpenCode स्थापित करें';

  @override
  String get appProviderInstallSucceeded => 'स्थापना सफल रही।';

  @override
  String appProviderInstallSucceededWithPath(String path) {
    return 'स्थापना सफल रही। OpenCode कमांड $path पर उपलब्ध है।';
  }

  @override
  String get appProviderInstallViaBun => 'Bun के माध्यम से स्थापित करें';

  @override
  String get appProviderInstallViaNpm => 'npm के माध्यम से स्थापित करें';

  @override
  String get appProviderInstallationFailed => 'OpenCode स्थापना विफल रही।';

  @override
  String get appProviderInstalledSuccessfully =>
      'OpenCode आवश्यकताएँ सफलतापूर्वक स्थापित की गईं।';

  @override
  String get appProviderInstallingRequirements =>
      'OpenCode आवश्यकताएँ स्थापित की जा रही हैं...';

  @override
  String get appProviderInvalidServerUrl => 'अमान्य सर्वर URL';

  @override
  String get appProviderLabelLocalOpenCodeManaged =>
      'स्थानीय OpenCode (प्रबंधित)';

  @override
  String get appProviderLabelPrimaryServer => 'प्राथमिक सर्वर';

  @override
  String get appProviderLocalManaged => 'स्थानीय OpenCode (प्रबंधित)';

  @override
  String get appProviderLocalServerStopped => 'स्थानीय सर्वर रुका हुआ है।';

  @override
  String get appProviderNotDetectedInstall =>
      'OpenCode कमांड का पता नहीं चला। विज़ार्ड से स्थापना चलाएँ।';

  @override
  String appProviderNotDetectedRefresh(String appName) {
    return 'OpenCode कमांड का पता नहीं चला। यदि आपने इसे अभी स्थापित किया है, तो जांच रिफ्रेश करें या PATH को फिर से लोड करने के लिए $appName को फिर से खोलें।';
  }

  @override
  String get appProviderOAuthNotSupported =>
      'Cloudflare Access OAuth इस प्लेटफॉर्म पर समर्थित नहीं है';

  @override
  String get appProviderOpenCodeDetected => 'OpenCode का पता चला';

  @override
  String get appProviderOpenCodeNotDetected => 'OpenCode का पता नहीं चला';

  @override
  String get appProviderPrimaryServer => 'प्राथमिक सर्वर';

  @override
  String get appProviderProfileNotFound => 'सर्वर प्रोफाइल नहीं मिला';

  @override
  String get appProviderRunDiagnostics =>
      'स्थानीय OpenCode आवश्यकताओं को सत्यापित करने के लिए निदान चलाएँ।';

  @override
  String appProviderRunningAt(String url) {
    return '$url पर चल रहा है';
  }

  @override
  String get appProviderSetupDetectingOpenCode =>
      'OpenCode कमांड का पता लगाया जा रहा है...';

  @override
  String get appProviderSetupInstallationSucceeded => 'स्थापना सफल रही।';

  @override
  String appProviderSetupInstallationSucceededWithPath(String path) {
    return 'स्थापना सफल रही। OpenCode कमांड $path पर उपलब्ध है।';
  }

  @override
  String get appProviderSetupInstallingRequirements =>
      'OpenCode आवश्यकताएँ स्थापित की जा रही हैं...';

  @override
  String get appProviderSetupOpenCodeDetected => 'OpenCode का पता चला';

  @override
  String get appProviderSetupOpenCodeNotDetected => 'OpenCode का पता नहीं चला';

  @override
  String get appProviderSetupOpenCodeNotDetectedInstall =>
      'OpenCode कमांड का पता नहीं चला। विज़ार्ड से स्थापना चलाएँ।';

  @override
  String get appProviderSetupOpenCodeNotDetectedRefresh =>
      'OpenCode कमांड का पता नहीं चला। यदि आपने इसे अभी स्थापित किया है, तो जांच रिफ्रेश करें या PATH को फिर से लोड करने के लिए CodeWalk को फिर से खोलें।';

  @override
  String get appProviderSetupRequirementsInstalled =>
      'OpenCode आवश्यकताएँ सफलतापूर्वक स्थापित की गईं।';

  @override
  String appProviderSetupUsingOpenCodeAt(String path) {
    return '$path पर OpenCode कमांड का उपयोग करना';
  }

  @override
  String get appProviderStartingLocalServer =>
      'स्थानीय सर्वर शुरू हो रहा है...';

  @override
  String appProviderStatusLocalServerExitedWithCode(int code) {
    return 'स्थानीय सर्वर कोड $code के साथ बाहर निकल गया।';
  }

  @override
  String get appProviderStatusLocalServerStopped =>
      'स्थानीय सर्वर रुका हुआ है।';

  @override
  String appProviderStatusRunningAt(String url) {
    return '$url पर चल रहा है';
  }

  @override
  String get appProviderStatusStartingLocalServer =>
      'स्थानीय सर्वर शुरू हो रहा है...';

  @override
  String get appProviderStatusStoppingLocalServer =>
      'स्थानीय सर्वर रुक रहा है...';

  @override
  String get appProviderStoppingLocalServer => 'स्थानीय सर्वर रुक रहा है...';

  @override
  String get appProviderTailscaleNotSupported =>
      'Tailscale इस प्लेटफॉर्म पर समर्थित नहीं है';

  @override
  String appProviderUsingCommandAt(String path) {
    return '$path पर OpenCode कमांड का उपयोग करना';
  }

  @override
  String get appShellDownloadingUpdate => 'अपडेट डाउनलोड हो रहा है';

  @override
  String get appShellInstall => 'इंस्टॉल करें';

  @override
  String get appShellInstallFailed => 'इंस्टॉलेशन विफल';

  @override
  String get appShellInstallingUpdate => 'अपडेट इंस्टॉल हो रहा है...';

  @override
  String get appShellRestart => 'पुनः आरंभ करें';

  @override
  String appShellUpdateAvailableResult(String latestVersion) {
    return 'अपडेट उपलब्ध: v$latestVersion';
  }

  @override
  String get appShellUpdateInstalledRestartApp =>
      'अपडेट इंस्टॉल हो गया है। लागू करने के लिए ऐप को पुनरारंभ करें।';

  @override
  String get appShellUpdateInstalledRestartRequired =>
      'अपडेट इंस्टॉल हो गया है। नया संस्करण लागू करने के लिए पुनरारंभ आवश्यक है।';

  @override
  String get attachmentCouldNotDecode =>
      'अनुलग्नक डेटा को डिकोड नहीं किया जा सका।';

  @override
  String get attachmentCouldNotDownload => 'अनुलग्नक डाउनलोड नहीं किया जा सका।';

  @override
  String get attachmentCouldNotSave =>
      'इस डिवाइस पर अनुलग्नक सहेजा नहीं जा सका।';

  @override
  String get attachmentDownloadStarted => 'अनुलग्नक डाउनलोड शुरू हुआ।';

  @override
  String get attachmentLocalNotFound =>
      'इस डिवाइस पर स्थानीय अनुलग्नक नहीं मिला।';

  @override
  String get attachmentNoValidLocation =>
      'अनुलग्नक एक मान्य स्थान प्रदान नहीं करता है।';

  @override
  String get attachmentNotAvailableOnPlatform =>
      'इस प्लेटफॉर्म पर अनुलग्नक क्रियाएं उपलब्ध नहीं हैं।';

  @override
  String get attachmentPathEmpty => 'अनुलग्नक पथ खाली है।';

  @override
  String get attachmentPayloadEmpty => 'अनुलग्नक पेलोड खाली है।';

  @override
  String get attachmentSaveCanceled => 'सहेजना रद्द कर दिया गया।';

  @override
  String attachmentSavedAndOpened(String path) {
    return 'अनुलग्नक $path में सहेजा गया और खोला गया।';
  }

  @override
  String attachmentSavedPath(String path) {
    return 'अनुलग्नक $path में सहेजा गया।';
  }

  @override
  String attachmentSavedTo(String path) {
    return 'अनुलग्नक $path में सहेजा गया।';
  }

  @override
  String get attachmentUnableToOpenLink => 'अनुलग्नक लिंक खोलने में असमर्थ।';

  @override
  String get attachmentUnableToOpenLocal =>
      'स्थानीय अनुलग्नक खोलने में असमर्थ।';

  @override
  String get behaviorAdvancedPermissionRule => 'उन्नत अनुमति नियम';

  @override
  String get behaviorAutomatic => 'स्वचालित';

  @override
  String get behaviorAutomaticFallback => 'स्वचालित फॉलबैक';

  @override
  String get behaviorCellularDataSaver => 'मोबाइल डेटा सेवर';

  @override
  String get behaviorCellularDataSaverActive => 'मोबाइल डेटा सेवर सक्रिय है।';

  @override
  String get behaviorChatLevelShare => 'चैट-स्तर साझाकरण';

  @override
  String get behaviorCodeWalkReleaseChecks => 'CodeWalk रिलीज़ जाँच';

  @override
  String get behaviorControlsOfficialGlobal =>
      'OpenCode आधिकारिक वैश्विक सेटिंग्स नियंत्रित करता है';

  @override
  String get behaviorControlsUpstreamOpenCode =>
      'अपस्ट्रीम OpenCode सेटिंग्स नियंत्रित करता है';

  @override
  String get behaviorCustomDisplayName => 'कस्टम प्रदर्शन नाम';

  @override
  String behaviorCutsAutomaticMobile(int inSeconds) {
    return 'बैकग्राउंड डाउनलोड रोककर और अग्रभूमि स्वचालित रीफ्रेश को हर $inSeconds सेकंड में एक बर्स्ट तक सीमित करके स्वचालित मोबाइल डेटा उपयोग कम करता है।';
  }

  @override
  String get behaviorDataSaverActive => 'मोबाइल डेटा पर अभी सक्रिय है।';

  @override
  String get behaviorDataSaverAggressive => 'आक्रामक';

  @override
  String get behaviorDataSaverAggressiveDescription =>
      'कम-बैंडविड्थ मोड: केवल दृश्य कार्यक्षेत्र स्ट्रीम सक्रिय रहती है, वैश्विक अपडेट रोक दिए जाते हैं, और स्वचालित रीफ़्रेश के बीच अंतराल बढ़ा दिया जाता है।';

  @override
  String get behaviorDataSaverCellularOnly =>
      'केवल तब लागू होता है जब कनेक्शन सेलुलर/मोबाइल हो।';

  @override
  String get behaviorDataSaverOff => 'बंद';

  @override
  String get behaviorDataSaverOffHint =>
      'पूर्ण रीयलटाइम और स्वचालित रीफ़्रेश सक्षम हैं।';

  @override
  String get behaviorDataSaverStandard => 'मानक';

  @override
  String get behaviorDataSaverWaiting =>
      'अगले मोबाइल-डेटा सिंक विंडो की प्रतीक्षा की जा रही है।';

  @override
  String get behaviorDisabled => 'अक्षम';

  @override
  String get behaviorLightweightTasksLike => 'हल्के कार्य जैसे';

  @override
  String get behaviorManual => 'मैनुअल';

  @override
  String get behaviorNotify => 'सूचित करें';

  @override
  String get behaviorOfficialOpenCodePermission =>
      'आधिकारिक OpenCode अनुमति नीति को `opencode.json` में प्रति टूल allow/ask/deny नियमों के साथ कॉन्फ़िगर किया गया है। CodeWalk आधिकारिक अनुमति-अनुरोध कार्ड रखता है और एक स्वीकृत ADR-023 अपवाद जोड़ता है: कंपोज़र ऑटो-अनुमोदन टॉगल बिना शर्त `Always` और `remember: true` के साथ उत्तर देता है ताकि टिकाऊ सत्र-स्कोप्ड अनुदान बनाया जा सके, और एंड्रॉइड बैकग्राउंड वर्कर में समान थ्रेड-स्कोप्ड निरंतरता पथ को सक्रिय रखता है।';

  @override
  String get behaviorOpenCodeBackedDefaults => 'OpenCode-समर्थित डिफ़ॉल्ट';

  @override
  String get behaviorPermissionHandlingProvenance =>
      'अनुमति संचालन उत्पत्ति (provenance)';

  @override
  String get behaviorPermissionsVariantReasoning =>
      'अनुमतियां और वेरिएंट/रीज़निंग समानता तब तक अलग रहती हैं जब तक कि उनका UI उन्नत कॉन्फ़िगरेशन को सुरक्षित रूप से संरक्षित नहीं कर लेता।';

  @override
  String get behaviorPrimaryAgentAgent =>
      'प्राथमिक एजेंट जिसका उपयोग तब किया जाता है जब कोई एजेंट स्पष्ट रूप से नहीं चुना जाता है।';

  @override
  String get behaviorRefreshDefaults => 'डिफ़ॉल्ट रीफ़्रेश करें';

  @override
  String get behaviorSharedAcrossOpenCode =>
      'कॉन्फ़िगरेशन के माध्यम से OpenCode क्लाइंट्स में साझा किया गया।';

  @override
  String get behaviorTheseValuesWrite =>
      'ये मान सक्रिय सर्वर पर `/config` में लिखे जाते हैं और आधिकारिक OpenCode साझा कॉन्फ़िगरेशन से मेल खाते हैं।';

  @override
  String get cannedAddTitle => 'त्वरित उत्तर जोड़ें';

  @override
  String get cannedAppendAtCursor => 'कर्सर पर जोड़ें';

  @override
  String get cannedAppendAtCursorSubtitle =>
      'बंद = वर्तमान कंपोज़र टेक्स्ट बदलें';

  @override
  String get cannedAttachFiles => 'फ़ाइलें संलग्न करें';

  @override
  String get cannedEditTitle => 'त्वरित उत्तर संपादित करें';

  @override
  String get cannedNewQuickReply => 'नई त्वरित प्रतिक्रिया';

  @override
  String get cannedNoSuggestions => 'कोई सुझाव नहीं';

  @override
  String get cannedOffMeansReplace =>
      'ऑफ़ का अर्थ है वर्तमान कंपोज़र पाठ को बदलना';

  @override
  String get cannedQuickReply => 'नया त्वरित उत्तर';

  @override
  String get cannedReplace => 'बदलें';

  @override
  String get cannedScopeGlobalSubtitle =>
      'केवल प्रोजेक्ट आइटम के लिए अक्षम करें';

  @override
  String get cannedScopeGlobalUnavailableSubtitle =>
      'वर्तमान संदर्भ में केवल-प्रोजेक्ट उपलब्ध नहीं';

  @override
  String get cannedSendAutomaticallySubtitle =>
      'यह त्वरित उत्तर डालने के तुरंत बाद भेजें';

  @override
  String get cannedSendImmediatelyInserting =>
      'इस त्वरित उत्तर को डालने के तुरंत बाद भेजें';

  @override
  String get cannedTextLabel => 'टेक्स्ट';

  @override
  String get chatActionNext => 'अगला';

  @override
  String get chatActiveServerUnhealthy =>
      'सक्रिय सर्वर अस्वस्थ है। पुनर्प्राप्ति होने तक भेजने का प्रयास केवल एक बार होगा और तुरंत विफल हो जाएगा।';

  @override
  String get chatActiveServerUnhealthyLabel => 'सक्रिय सर्वर अस्वस्थ है';

  @override
  String get chatAddServerToStart => 'चैटिंग शुरू करने के लिए एक सर्वर जोड़ें।';

  @override
  String get chatAppBarMoreActions => 'अधिक क्रियाएं';

  @override
  String get chatAppBarPinAction => 'ऐप बार पर पिन करें';

  @override
  String get chatAppBarPinDescription => 'यह क्रिया मेनू के बाहर दिखाई देगी।';

  @override
  String get chatAppBarUnpinAction => 'ऐप बार से अनपिन करें';

  @override
  String get chatAppBarUnpinDescription => 'यह क्रिया वापस मेनू में चली जाएगी।';

  @override
  String chatBadgeConversationError(String title) {
    return '\"$title\" में एक त्रुटि है।';
  }

  @override
  String chatBadgeConversationNeedsInput(String title) {
    return '\"$title\" को आपके इनपुट की आवश्यकता है।';
  }

  @override
  String chatBadgeConversationNewReply(String title) {
    return '\"$title\" में एक नई प्रतिक्रिया है।';
  }

  @override
  String get chatBadgeDataSaverActive => 'सेलुलर डेटा सेवर सक्रिय है।';

  @override
  String get chatBadgeServerNeedsAttention =>
      'सर्वर कनेक्शन पर ध्यान देने की आवश्यकता है।';

  @override
  String get chatBadgeSyncing => 'बातचीत सिंक हो रही है...';

  @override
  String get chatBlockResponsePendingDescription =>
      'जब यह टर्न समाप्त होगा, तो उत्तर एक ही ब्लॉक के रूप में दिखाई देगा।';

  @override
  String get chatBlockResponsePendingTitle => 'प्रतिक्रिया बनाई जा रही है';

  @override
  String get chatCachedConversationsYet => 'अभी तक कोई कैश्ड बातचीत नहीं है';

  @override
  String get chatChangedFilesAvailable =>
      'इस सत्र के लिए कोई बदली गई फ़ाइल उपलब्ध नहीं है।';

  @override
  String chatChildrenChatProviderCurrentSessionChildren(int length) {
    return 'बच्चे: $length';
  }

  @override
  String get chatChooseAgent => 'एजेंट चुनें';

  @override
  String get chatChooseDirectory => 'निर्देशिका चुनें';

  @override
  String get chatChooseEffort => 'प्रयास चुनें';

  @override
  String get chatChooseFolderOpen =>
      'परियोजना संदर्भ के रूप में खोलने के लिए एक फ़ोल्डर चुनें।';

  @override
  String get chatChooseModel => 'मॉडल चुनें';

  @override
  String get chatClose => 'बंद करें';

  @override
  String chatCloseProject(String project) {
    return '$project बंद करें';
  }

  @override
  String get chatCollapseGroup => 'समूह छोटा करें';

  @override
  String get chatCommandDescriptionProject => 'प्रोजेक्ट कमांड';

  @override
  String get chatCommandSourceGeneric => 'कमांड';

  @override
  String get chatCommandSourceProject => 'प्रोजेक्ट';

  @override
  String get chatCompactContext => 'संक्षिप्त संदर्भ (Compact Context)';

  @override
  String get chatComposerHintShell =>
      'शेल कमांड (बाहर निकलने के लिए Esc दबाएं)';

  @override
  String get chatComposerPlaceholder => 'अपनी ज़रूरतें लिखें...';

  @override
  String get chatConversation => 'बातचीत';

  @override
  String get chatConversations => 'बातचीत';

  @override
  String get chatConversationsPane => 'बातचीत';

  @override
  String chatCostLabel(double cost) {
    return 'लागत: \$$cost';
  }

  @override
  String get chatCouldNotRefreshSession =>
      'यह वार्तालाप रीफ़्रेश नहीं किया जा सका';

  @override
  String get chatCurrent => 'वर्तमान का उपयोग करें';

  @override
  String chatDescriptionChildren(int count) {
    return 'बच्चे: $count';
  }

  @override
  String get chatDescriptionCloseApp =>
      'प्लेटफ़ॉर्म बंद करने के व्यवहार का उपयोग करके ऐप बंद करें';

  @override
  String get chatDescriptionCycleModels => 'हाल के मॉडल बदलें';

  @override
  String get chatDescriptionCycleVariant => 'मॉडल संस्करण बदलें';

  @override
  String get chatDescriptionDiffFilesZero => 'डिफ फाइलें: 0';

  @override
  String get chatDescriptionFocusInput => 'संदेश इनपुट पर ध्यान केंद्रित करें';

  @override
  String get chatDescriptionFocusOrCloseDrawer =>
      'इनपुट पर ध्यान केंद्रित करें (या खुला होने पर दराज बंद करें)';

  @override
  String get chatDescriptionForceExit => 'ऐप को जबरन बंद करें';

  @override
  String get chatDescriptionNewConversation => 'नई बातचीत';

  @override
  String get chatDescriptionNextAgent => 'अगला एजेंट';

  @override
  String get chatDescriptionOpenProjects =>
      'अपने प्रोजेक्ट और बातचीत खोलने के लिए इस बटन का उपयोग करें।';

  @override
  String get chatDescriptionOpenSettings => 'सेटिंग्स खोलें';

  @override
  String get chatDescriptionPreviousAgent => 'पिछला एजेंट';

  @override
  String get chatDescriptionProjectCommand => 'प्रोजेक्ट कमांड';

  @override
  String get chatDescriptionQuickOpen => 'फाइलें जल्दी खोलें';

  @override
  String get chatDescriptionRefreshData => 'चैट डेटा रिफ्रेश करें';

  @override
  String get chatDescriptionStopResponse =>
      'सक्रिय प्रतिक्रिया रोकें (प्रतिक्रिया देते समय)';

  @override
  String get chatDescriptionSwitchProject =>
      'प्रोजेक्ट फोल्डर और संदर्भ बदलने के लिए इस बटन का उपयोग करें।';

  @override
  String get chatDescriptionVoiceInput => 'आवाज इनपुट शुरू या बंद करें';

  @override
  String get chatDiffFiles => 'डिफ़ फ़ाइलें: 0';

  @override
  String get chatDisplay => 'प्रदर्शन';

  @override
  String get chatDisplayToggles => 'टॉगल प्रदर्शित करें';

  @override
  String get chatDoubleESCStop => 'रुकने के लिए दो बार ESC';

  @override
  String get chatEffortLockedSubConversation =>
      'उप-वार्तालाप में प्रयास लॉक है';

  @override
  String get chatExpandGroup => 'समूह विस्तार करें';

  @override
  String get chatExportCanceled => 'सत्र निर्यात रद्द कर दिया गया';

  @override
  String get chatFailedToLoadDirectories => 'निर्देशिकाएँ लोड करने में विफल';

  @override
  String get chatFailedToLoadFile => 'फ़ाइल लोड करने में विफल';

  @override
  String get chatFailedToRefreshProviders =>
      'प्रदाता और मॉडल रीफ़्रेश करने में विफल';

  @override
  String get chatFailedToRefreshSubConversations =>
      'उप-वार्तालाप रीफ़्रेश नहीं हुए। कृपया पुनः प्रयास करें।';

  @override
  String get chatFailedToStopResponse =>
      'वर्तमान प्रतिक्रिया को रोकने में विफल';

  @override
  String get chatFileExplorerContents => 'सामग्री';

  @override
  String get chatFileExplorerNames => 'नाम';

  @override
  String get chatFilterActive => 'सक्रिय';

  @override
  String get chatFilterAll => 'सभी';

  @override
  String get chatFilterArchived => 'अभिलेखागार (Archived)';

  @override
  String get chatFilterDirectories => 'निर्देशिकाएं फ़िल्टर करें';

  @override
  String get chatFilterSessions => 'सत्र फ़िल्टर करें';

  @override
  String get chatForkFailed => 'बातचीत को फोर्क करने में विफल';

  @override
  String get chatForked => 'बातचीत फोर्क की गई';

  @override
  String get chatGoToFirst => 'पहले संदेश पर जाएं';

  @override
  String get chatGoToLatest => 'नवीनतम संदेश पर जाएं';

  @override
  String chatGroupMessageCountMessages(
    String compactionLabel,
    String messageCount,
  ) {
    return '$compactionLabel संपीडन से पहले $messageCount संदेश छिपाए गए';
  }

  @override
  String get chatHelloAssistant => 'नमस्कार! मैं आपका एआई सहायक हूँ';

  @override
  String get chatHelp => 'मैं आपकी क्या मदद कर सकता हूँ?';

  @override
  String get chatHelpMessage =>
      'उल्लेख के लिए @, शेल के लिए !, कमांड के लिए / का उपयोग करें';

  @override
  String get chatHideConversationsSidebar => 'बातचीत साइडबार छुपाएं';

  @override
  String get chatHideUtilitySidebar => 'उपयोगिता (Utility) साइडबार छुपाएं';

  @override
  String get chatHistoryCollapsed => 'पिछला इतिहास संकुचित है';

  @override
  String get chatHistoryHideEarlier => 'पिछले संदेश छिपाएं';

  @override
  String chatHistoryMessagesHidden(int count, String label) {
    return '$count संदेश $label संकुचन से पहले छिपाए गए';
  }

  @override
  String get chatHistoryShowEarlier => 'पिछले संदेश दिखाएं';

  @override
  String get chatKeepWorking => 'काम जारी रखें';

  @override
  String get chatLargeContentSkipped =>
      'स्थिरता के लिए बड़ी या खराब सामग्री को छोड़ दिया गया।';

  @override
  String get chatLatestToolActivity =>
      'चैट व्यूपोर्ट को स्थिर रखने के लिए नवीनतम टूल गतिविधि इस बद्ध (bounded) पैनल के अंदर रहती है।';

  @override
  String get chatLoadMore => 'और लोड करें';

  @override
  String get chatLoadingProjectContext =>
      'परियोजना संदर्भ लोड किया जा रहा है...';

  @override
  String get chatMainConversationUnavailable =>
      'मुख्य वार्तालाप अभी उपलब्ध नहीं है।';

  @override
  String get chatParentConversationUnavailable =>
      'पैरेंट बातचीत अभी उपलब्ध नहीं है।';

  @override
  String get chatMentionAgentSubtitle => 'एजेंट';

  @override
  String get chatMentionFileSubtitle => 'फ़ाइल';

  @override
  String get chatMentionSymbolSubtitle => 'प्रतीक';

  @override
  String get chatMessageAttachedFile => 'संलग्न फ़ाइल';

  @override
  String get chatMessageDetails => 'विवरण';

  @override
  String get chatMessageHide => 'छिपाएं';

  @override
  String get chatMessageLess => 'कम';

  @override
  String get chatMessageMessagePartUnavailable => 'संदेश का भाग अनुपलब्ध है';

  @override
  String get chatMessageMetadataAvailable => 'कोई मेटाडेटा उपलब्ध नहीं है';

  @override
  String chatMessageModelMessageModelId(String modelId) {
    return 'मॉडल: $modelId';
  }

  @override
  String get chatMessageMore => 'और';

  @override
  String get chatMessageOpenFile => 'फ़ाइल खोलें';

  @override
  String chatMessageProviderMessageProviderId(String providerId) {
    return 'प्रदाता: $providerId';
  }

  @override
  String get chatMessageRewindEdit => 'यहाँ से रिवाइंड और संपादित करें';

  @override
  String get chatMessageRunningTask => 'कार्य चलाया जा रहा है';

  @override
  String get chatMessageSaveFile => 'फ़ाइल सहेजें';

  @override
  String get chatMessageShow => 'दिखाएं';

  @override
  String get chatMessageShowQuestion => 'प्रश्न देखें';

  @override
  String get chatMessageShowLess => 'कम दिखाएं';

  @override
  String get chatMessageShowLessCompact => 'कम';

  @override
  String get chatMessageShowMore => 'और दिखाएं';

  @override
  String get chatMessageShowMoreCompact => 'और';

  @override
  String get chatMessageThinking => 'सोच रहा है';

  @override
  String get chatMessageThinkingProcess =>
      'सोचने की प्रक्रिया (Thinking Process)';

  @override
  String get chatMessageToolCall => '1 टूल कॉल';

  @override
  String chatMessageToolCalls(int count) {
    return '$count टूल कॉल';
  }

  @override
  String get chatMessageToolCommand => 'कमांड';

  @override
  String get chatMessageToolCommandTruncated =>
      'कमांड पूर्वावलोकन स्थिरता के लिए छोटा किया गया।';

  @override
  String get chatMessageToolDiffOmitted =>
      'Diff पूर्वावलोकन हटाया गया: पेलोड मोबाइल पर दिखाने के लिए बहुत बड़ा है।';

  @override
  String get chatMessageToolInput => 'इनपुट';

  @override
  String get chatMessageToolInputTruncated =>
      'इनपुट पूर्वावलोकन स्थिरता के लिए छोटा किया गया।';

  @override
  String get chatMessageToolOutputTruncated =>
      'बड़े आउटपुट का पूर्वावलोकन स्थिरता के लिए छोटा किया गया।';

  @override
  String chatMessageToolQueuedCount(int count) {
    return '$count कतार में हैं';
  }

  @override
  String chatMessageToolRunningCount(int count) {
    return '$count चल रहे हैं';
  }

  @override
  String get chatMessageToolStatusInProgress => 'प्रगति पर है';

  @override
  String get chatMessageToolStatusNeedsAttention => 'ध्यान देने की आवश्यकता है';

  @override
  String get chatMessageToolStatusQueued => 'कतारबद्ध (Queued)';

  @override
  String get chatMessageYou => 'आप';

  @override
  String get chatModelLockedSubConversation => 'उप-वार्तालाप में मॉडल लॉक है';

  @override
  String get chatNewChat => 'नई चैट';

  @override
  String get chatNewChatTourDescription => 'यहाँ एक नई बातचीत शुरू करें।';

  @override
  String get chatNewChatTourTitle => 'नई चैट';

  @override
  String get chatNoConversationsInProject =>
      'इस प्रोजेक्ट में कोई बातचीत नहीं है।';

  @override
  String get chatNoServerYet => 'अभी तक कोई सर्वर कॉन्फ़िगर नहीं किया गया है';

  @override
  String get chatNoSessionSelected =>
      'चैट शुरू करने के लिए वार्तालाप चुनें या बनाएं';

  @override
  String get chatNoSubConversationFound =>
      'इस कार्य के लिए कोई उप-वार्तालाप नहीं मिला।';

  @override
  String get chatOpenFiles => 'खुली फ़ाइलें';

  @override
  String get chatOpenProject => 'प्रोजेक्ट खोलें';

  @override
  String get chatOpenProjectFolder => 'परियोजना फ़ोल्डर खोलें...';

  @override
  String get chatOpenProjectToLoad => 'बातचीत लोड करने के लिए प्रोजेक्ट खोलें।';

  @override
  String get chatOpenSidebar => 'साइडबार खोलें';

  @override
  String get chatPageStatusAutomaticCompactionExplanation =>
      'जैसे-जैसे संदर्भ उपयोग बढ़ता है, स्वचालित संकुचन होता है।';

  @override
  String get chatPageStatusCompactNow => 'अभी संकुचित करें';

  @override
  String get chatPageStatusCompacting => 'संकुचित किया जा रहा है...';

  @override
  String get chatPageStatusCompactingContextNow =>
      'संदर्भ को अभी संकुचित किया जा रहा है...';

  @override
  String get chatPageStatusContextCompacted => 'संदर्भ संकुचित किया गया';

  @override
  String get chatPageStatusContextUsage => 'संदर्भ उपयोग';

  @override
  String get chatPageStatusCost => 'लागत';

  @override
  String get chatPageStatusFailedToCompactContext =>
      'संदर्भ को संकुचित करने में विफल';

  @override
  String get chatPageStatusLimit => 'सीमा';

  @override
  String get chatPageStatusManageServers => 'सर्वर प्रबंधित करें';

  @override
  String get chatPageStatusSaver => 'सेवर';

  @override
  String get chatPageStatusServer => 'सर्वर';

  @override
  String get chatPageStatusSwitchServer => 'सर्वर बदलें';

  @override
  String get chatPageStatusTokens => 'टोकन';

  @override
  String get chatPageStatusUsage => 'उपयोग';

  @override
  String chatPageStatusUsagePercent(int usagePercent) {
    return '$usagePercent';
  }

  @override
  String get chatPermissionAutoApproveOff => 'अनुमति स्वतः-अनुमोदन बंद है';

  @override
  String get chatPermissionAutoApproveOn => 'अनुमति स्वतः-अनुमोदन चालू है';

  @override
  String get chatProjectContext => 'परियोजना संदर्भ (Project Context)';

  @override
  String get chatProjectContext2 => 'प्रोजेक्ट संदर्भ';

  @override
  String get chatRealtimeGlobalEvent => 'वैश्विक घटना';

  @override
  String chatRealtimeGlobalEventReason(String reason) {
    return 'वैश्विक घटना ($reason)';
  }

  @override
  String get chatRealtimeGlobalEventStale => 'वैश्विक घटना (पुरानी पीढ़ी)';

  @override
  String chatRealtimeMessageStreamReason(String reason) {
    return 'संदेश प्रवाह ($reason)';
  }

  @override
  String get chatRealtimeRealtimeEvent => 'रीयलटाइम घटना';

  @override
  String chatRealtimeRealtimeEventReason(String reason) {
    return 'रीयलटाइम घटना ($reason)';
  }

  @override
  String get chatRealtimeRealtimeEventStale => 'रीयलटाइम घटना (पुरानी पीढ़ी)';

  @override
  String get chatRealtimeReconnectingServerTry =>
      'सर्वर से पुनः कनेक्ट हो रहा है। कुछ क्षण में पुनः प्रयास करें।';

  @override
  String get chatReasoning => 'तर्क कर रहा है...';

  @override
  String get chatRecentSessions => 'हाल के सत्र';

  @override
  String get chatRecentSessionsToggle => 'हाल के सत्र';

  @override
  String get chatRedoLastTurn => 'पिछला पूर्ववत किया गया कदम फिर से करें';

  @override
  String get chatRedoNothing => 'इस सत्र में फिर से करने के लिए कुछ नहीं है';

  @override
  String get chatRefresh => 'रीफ़्रेश करें';

  @override
  String get chatRefreshConversation =>
      'इस बातचीत को रीफ़्रेश नहीं किया जा सका';

  @override
  String get chatRefreshProjects => 'परियोजनाएं रीफ़्रेश करें';

  @override
  String get chatRefreshSessionDetails => 'सत्र विवरण रीफ़्रेश करें';

  @override
  String chatRemoveDisplayNameHistory(String displayName) {
    return 'इतिहास से $displayName हटाएँ';
  }

  @override
  String get chatRetry => 'पुनः प्रयास करें';

  @override
  String get chatRetry2 => 'पुनः प्रयास करें';

  @override
  String get chatRetryRefresh => 'रीफ़्रेश करने का पुनः प्रयास करें';

  @override
  String get chatRetryingModelRequest =>
      'मॉडल अनुरोध का पुनः प्रयास किया जा रहा है...';

  @override
  String get chatReturnToMainConversation => 'मुख्य बातचीत पर लौटें';

  @override
  String get chatReturnToParentConversation => 'पैरेंट बातचीत पर लौटें';

  @override
  String get chatReviewChanges => 'परिवर्तनों की समीक्षा करें';

  @override
  String get chatSearchConversations => 'बातचीत खोजें';

  @override
  String get chatSearchNextResult => 'अगला परिणाम';

  @override
  String get chatSearchNoResults => 'कोई परिणाम नहीं';

  @override
  String get chatSearchPreviousResult => 'पिछला परिणाम';

  @override
  String chatSearchResultCount(int current, int total) {
    return 'संदेश $current का $total';
  }

  @override
  String get chatSearchTimeline => 'समयरेखा खोजें';

  @override
  String get chatSelectDirectory => 'निर्देशिका चुनें';

  @override
  String get chatSelectOrCreate =>
      'चैटिंग शुरू करने के लिए एक बातचीत चुनें या बनाएं';

  @override
  String get chatSelectProjectBelow => 'नीचे एक परियोजना चुनें।';

  @override
  String get chatServerSelectedModel => 'सर्वर-चयनित मॉडल';

  @override
  String get chatSessionActions => 'सत्र क्रियाएं';

  @override
  String chatSessionChatSessionSession(String title) {
    return 'चैट सत्र: $title';
  }

  @override
  String chatSessionConversationNextAction(String nextAction) {
    return 'वार्तालाप $nextAction';
  }

  @override
  String get chatSessionConversations => 'कोई बातचीत नहीं';

  @override
  String get chatSessionCreateConversationStart =>
      'चैटिंग शुरू करने के लिए एक नई बातचीत बनाएं';

  @override
  String get chatSessionTabsToggle => 'सत्र टैब';

  @override
  String chatSessionsLength(int length) {
    return '$length';
  }

  @override
  String get chatSetUpServer => 'सर्वर सेट अप करें';

  @override
  String get chatSettings => 'सेटिंग्स';

  @override
  String get chatShortcutsCloseApp =>
      'प्लेटफ़ॉर्म व्यवहार का उपयोग करके ऐप बंद करें';

  @override
  String get chatShortcutsCycleModels => 'हाल के मॉडल बदलें';

  @override
  String get chatShortcutsCycleVariant => 'मॉडल संस्करण बदलें';

  @override
  String get chatShortcutsFocusInput => 'संदेश इनपुट पर ध्यान दें';

  @override
  String get chatShortcutsFocusInputCloseDrawer =>
      'इनपुट पर ध्यान दें (या खुला होने पर ड्रॉर बंद करें)';

  @override
  String get chatShortcutsForceExit => 'ऐप से ज़बरदस्ती बाहर निकलें';

  @override
  String get chatShortcutsNewConversation => 'नई बातचीत';

  @override
  String get chatShortcutsNextAgent => 'अगला एजेंट';

  @override
  String get chatShortcutsOpenSettings => 'सेटिंग्स खोलें';

  @override
  String get chatShortcutsPreviousAgent => 'पिछला एजेंट';

  @override
  String get chatShortcutsQuickOpen => 'फ़ाइलें जल्दी खोलें';

  @override
  String get chatShortcutsRefreshChat => 'चैट डेटा रीफ्रेश करें';

  @override
  String get chatShortcutsStartStopVoice => 'आवाज इनपुट शुरू या बंद करें';

  @override
  String get chatShortcutsStopResponse =>
      'सक्रिय प्रतिक्रिया रोकें (प्रतिक्रिया देते समय)';

  @override
  String get chatSidebarAccess => 'साइडबार एक्सेस';

  @override
  String get chatSortMostRecent => 'सबसे हालिया';

  @override
  String get chatSortOldest => 'सबसे पुराना';

  @override
  String get chatSortRecent => 'हालिया';

  @override
  String get chatSortSessions => 'सत्र क्रमबद्ध करें';

  @override
  String get chatSortTitle => 'शीर्षक';

  @override
  String get chatStartVoiceInput => 'आवाज़ इनपुट शुरू करें';

  @override
  String get chatStartingVoiceInput => 'आवाज़ इनपुट शुरू हो रहा है';

  @override
  String get chatStatusBusy => 'स्थिति: व्यस्त';

  @override
  String get chatStatusPatching => 'पैच किया जा रहा है';

  @override
  String chatStatusPatchingMultipleFiles(int count) {
    return '$count फ़ाइलें पैच की जा रही हैं';
  }

  @override
  String get chatStatusPatchingOneFile => '1 फ़ाइल पैच की जा रही है';

  @override
  String get chatStatusRetry => 'स्थिति: पुन: प्रयास';

  @override
  String chatStatusRetryCount(int count) {
    return 'स्थिति: पुन: प्रयास #$count';
  }

  @override
  String get chatStatusSubsession => 'उप-सत्र';

  @override
  String get chatStatusThinking => 'सोच रहा है...';

  @override
  String get chatStopVoiceInput => 'आवाज़ इनपुट बंद करें';

  @override
  String chatSyncLabel(String label) {
    return 'सिंक: $label';
  }

  @override
  String get chatTasks => 'कार्य';

  @override
  String get chatTasksAvailableSession =>
      'इस सत्र के लिए कोई कार्य उपलब्ध नहीं हैं।';

  @override
  String get chatTipAcceptanceCriteria =>
      'सुझाव: बड़े बदलावों के लिए स्वीकृति मानदंड जोड़ें';

  @override
  String get chatTipAskForPlan => 'सुझाव: बड़े कार्यों में पहले योजना मांगें';

  @override
  String get chatTipBeSpecific =>
      'सुझाव: विशिष्ट बनें — छोटे प्रॉम्प्ट का उत्तर तेज़ी से मिलता है';

  @override
  String get chatTipBreakTasks =>
      'सुझाव: बड़े कार्यों को छोटे प्रॉम्प्ट में विभाजित करें';

  @override
  String get chatTipCompareOptions =>
      'सुझाव: ट्रेडऑफ अस्पष्ट हों तो विकल्प मांगें';

  @override
  String get chatTipContextKnob =>
      'सुझाव: उपयोग विवरण देखने के लिए संदर्भ नॉब पर टैप करें';

  @override
  String get chatTipDefineVerification =>
      'सुझाव: बताएं कौन से टेस्ट या जांच पास होनी चाहिए';

  @override
  String get chatTipLongPressSend =>
      'सुझाव: नई लाइन डालने के लिए सेंड को देर तक दबाएं';

  @override
  String get chatTipMentionFiles =>
      'सुझाव: अपने प्रॉम्प्ट में फ़ाइलों का उल्लेख करने के लिए @ का उपयोग करें';

  @override
  String get chatTipNameRelevantFiles =>
      'सुझाव: संबंधित फ़ाइलें, स्क्रीन या कमांड बताएं';

  @override
  String get chatTipProvideContext =>
      'सुझाव: संदर्भ प्रदान करें — त्रुटि संदेश और लॉग पेस्ट करें';

  @override
  String get chatTipRenameConversation =>
      'सुझाव: बातचीत का नाम बदलने के लिए शीर्षक पर टैप करें';

  @override
  String get chatTipRequestDocs => 'सुझाव: व्यवहार बदलने पर डॉक्स अपडेट मांगें';

  @override
  String get chatTipShareAttempts =>
      'सुझाव: आपने क्या आजमाया और सटीक त्रुटि बताएं';

  @override
  String get chatTipShellCommands =>
      'सुझाव: शेल कमांड चलाने के लिए शुरुआत में ! का उपयोग करें';

  @override
  String get chatTipSlashCommands =>
      'सुझाव: स्लैश कमांड तक पहुँचने के लिए / का उपयोग करें';

  @override
  String get chatTipStartWithGoal => 'सुझाव: अंतिम लक्ष्य से शुरू करें';

  @override
  String get chatTipStateConstraints =>
      'सुझाव: वे सीमाएं बताएं जिन्हें एजेंट को बचाए रखना है';

  @override
  String get chatTipStepByStep =>
      'सुझाव: जटिल समस्याओं को डीबग करते समय चरण-दर-चरण पूछें';

  @override
  String get chatTipUseFocusedAgents =>
      'सुझाव: योजना, समीक्षा या बिल्ड के लिए केंद्रित एजेंट चुनें';

  @override
  String get chatToggleSidebars => 'साइडबार टॉगल करें';

  @override
  String chatTokensLabel(int total) {
    return 'टोकन: $total';
  }

  @override
  String get chatTourProjectsConversations =>
      'अपने प्रोजेक्ट और बातचीत खोलने के लिए इस बटन का उपयोग करें।';

  @override
  String get chatTourSidebarProjectTools =>
      'बातचीत साइडबार और प्रोजेक्ट टूल दिखाने के लिए इस मेनू का उपयोग करें।';

  @override
  String get chatTourSwitchFolders =>
      'प्रोजेक्ट फोल्डर और संदर्भ बदलने के लिए इस बटन का उपयोग करें।';

  @override
  String get chatUndoLastTurn => 'पिछला कदम पूर्ववत (undo) करें';

  @override
  String get chatUndoNothing => 'इस सत्र में पूर्ववत करने के लिए कुछ नहीं है';

  @override
  String get chatUseCurrent => 'वर्तमान का उपयोग करें';

  @override
  String get chatWaitingForNetworkConnection =>
      'नेटवर्क कनेक्शन की प्रतीक्षा...';

  @override
  String get chatWelcomeMessage => 'नमस्ते! मैं आपका AI सहायक हूँ।';

  @override
  String get chatWelcomeSubmessage => 'आज मैं आपकी कैसे मदद कर सकता हूँ?';

  @override
  String get chatWorkBoundedPanelExplanation =>
      'चैट व्यूपोर्ट को स्थिर रखने के लिए नवीनतम टूल गतिविधि इस बद्ध (bounded) पैनल के अंदर रहती है।';

  @override
  String get chatWorkExpand => 'विस्तार करें';

  @override
  String get chatWorkHide => 'छिपाएं';

  @override
  String get chatWorkMessageOne => '1 कार्य संदेश';

  @override
  String chatWorkMessagesMultiple(int count) {
    return '$count कार्य संदेश';
  }

  @override
  String get chatWorkShow => 'दिखाएं';

  @override
  String get commonCancel => 'रद्द करें';

  @override
  String get commonCopiedToClipboard => 'क्लिपबोर्ड पर कॉपी किया गया';

  @override
  String get commonDelete => 'हटाएं';

  @override
  String get commonFile => 'फ़ाइल';

  @override
  String get commonReset => 'रीसेट करें';

  @override
  String get commonSave => 'सहेजें';

  @override
  String get compactionAutomatic => 'स्वचालित';

  @override
  String get compactionManual => 'मैन्युअल';

  @override
  String get composerAddAttachment => 'अनुलग्नक (attachment) जोड़ें';

  @override
  String get composerAttachFiles => 'फ़ाइलें संलग्न करें';

  @override
  String get composerCannedAppendAtCursor => 'कर्सर पर जोड़ें';

  @override
  String get composerCannedLabel => 'लेबल (वैकल्पिक)';

  @override
  String get composerCannedNoReplies => 'अभी तक कोई त्वरित उत्तर नहीं है।';

  @override
  String get composerCannedReplace => 'बदलें';

  @override
  String get composerCannedSave => 'सहेजें';

  @override
  String get composerCannedScopeGlobal => 'वैश्विक (Global)';

  @override
  String get composerCannedScopeProject => 'केवल परियोजना';

  @override
  String get composerCannedSendAutomatically => 'स्वचालित रूप से भेजें';

  @override
  String get composerCannedText => 'पाठ';

  @override
  String get composerChatInput => 'चैट इनपुट';

  @override
  String get composerDeleteAction => 'हटाएं';

  @override
  String get composerDropHint => 'संलग्न करने के लिए इमेज या PDF छोड़ें';

  @override
  String get composerPastedImageName => 'चिपकाई गई इमेज';

  @override
  String get composerEdit => 'संपादित करें';

  @override
  String get composerExtras => 'अतिरिक्त सुविधाएं';

  @override
  String get composerExtrasHide => 'अतिरिक्त छिपाएँ';

  @override
  String get composerNewQuickReply => 'नया त्वरित उत्तर';

  @override
  String get composerSelectImages => 'छवियां चुनें';

  @override
  String get composerSelectPdf => 'PDF चुनें';

  @override
  String get composerSend => 'भेजें';

  @override
  String get composerShellMode => 'शेल (Shell) मोड';

  @override
  String get desktopWindowClose => 'बंद करें';

  @override
  String get desktopWindowMaximize => 'बड़ा करें';

  @override
  String get desktopWindowMinimize => 'छोटा करें';

  @override
  String get desktopWindowRestore => 'पुनर्स्थापित करें';

  @override
  String get dialogDownload => 'डाउनलोड';

  @override
  String get dialogLanguage => 'भाषा';

  @override
  String get dialogMoonshineModelSize => 'मॉडल का आकार';

  @override
  String get dialogMoonshineVoiceSetup => 'Moonshine वॉयस सेटअप';

  @override
  String get dialogParakeetModel => 'Parakeet मॉडल';

  @override
  String get dialogParakeetVoiceSetup => 'Parakeet वॉयस सेटअप';

  @override
  String get dialogSenseVoiceModel => 'SenseVoice मॉडल';

  @override
  String get dialogSenseVoiceSetup => 'SenseVoice सेटअप';

  @override
  String get dialogVoiceInputSetup => 'वॉयस इनपुट सेटअप';

  @override
  String get errorAnErrorOccurred => 'एक त्रुटि हुई';

  @override
  String get errorAuthRequired => 'प्रमाणीकरण आवश्यक है';

  @override
  String get errorAuthRequiredDesc =>
      'प्रमाणीकरण विफल रहा। प्रदाता को फिर से कनेक्ट करें और पुनः प्रयास करें।';

  @override
  String get errorConnectionFailed => 'कनेक्शन विफल रहा';

  @override
  String get errorConnectionFailedDesc =>
      'सर्वर तक पहुँचने में असमर्थ। कनेक्शन और सर्वर स्थिति की जाँच करें।';

  @override
  String get errorFormatAuthenticationFailedReconnect =>
      'प्रमाणीकरण विफल रहा। प्रदाता को दोबारा कनेक्ट करें और पुनः प्रयास करें।';

  @override
  String get errorFormatProviderTemporarilyUnavailable =>
      'प्रदाता अस्थायी रूप से अनुपलब्ध है। कुछ समय बाद पुनः प्रयास करें।';

  @override
  String get errorFormatQuotaExceededCheck =>
      'कोटा समाप्त हो गया। अपने प्रदाता प्लान या बिलिंग की जांच करें।';

  @override
  String get errorFormatRateLimitExceeded =>
      'दर सीमा (Rate limit) पार हो गई। कुछ क्षण प्रतीक्षा करें और पुनः प्रयास करें।';

  @override
  String get errorFormatServerErrorPlease =>
      'सर्वर त्रुटि। कृपया पुनः प्रयास करें।';

  @override
  String get errorFormatServiceTemporarilyUnavailable =>
      'सेवा अस्थायी रूप से अनुपलब्ध है। सर्वर शुरू हो रहा हो सकता है — कृपया कुछ समय बाद पुनः प्रयास करें।';

  @override
  String get errorFormatUnableReachServer =>
      'सर्वर तक पहुँचने में असमर्थ। कनेक्शन और सर्वर स्थिति की जांच करें।';

  @override
  String get errorProviderUnavailable => 'प्रदाता अनुपलब्ध है';

  @override
  String get errorProviderUnavailableDesc =>
      'प्रदाता अस्थायी रूप से अनुपलब्ध है। थोड़ी देर में पुनः प्रयास करें।';

  @override
  String get errorQuotaExceeded => 'कोटा समाप्त हो गया';

  @override
  String get errorQuotaExceededDesc =>
      'कोटा समाप्त हो गया। अपने प्रदाता प्लान या बिलिंग की जाँच करें।';

  @override
  String get errorRateLimitExceeded => 'दर सीमा समाप्त हो गई';

  @override
  String get errorRateLimitExceededDesc =>
      'दर सीमा समाप्त हो गई। एक क्षण प्रतीक्षा करें और पुनः प्रयास करें।';

  @override
  String get errorServerError => 'सर्वर त्रुटि';

  @override
  String get errorServerErrorDesc => 'सर्वर त्रुटि। कृपया पुनः प्रयास करें।';

  @override
  String get errorServiceUnavailable => 'सेवा अनुपलब्ध है';

  @override
  String get errorServiceUnavailableDesc =>
      'सेवा अस्थायी रूप से अनुपलब्ध है। सर्वर शुरू हो रहा हो सकता है — कृपया थोड़ी देर में पुनः प्रयास करें।';

  @override
  String get fileActionAttachmentDataDecoded =>
      'अनुलग्नक (attachment) डेटा को डीकोड नहीं किया जा सका।';

  @override
  String get fileActionAttachmentPathEmpty => 'अनुलग्नक पथ खाली है।';

  @override
  String get fileActionAttachmentPayloadEmpty => 'अनुलग्नक पेलोड खाली है।';

  @override
  String get fileActionAttachmentProvideValid =>
      'अनुलग्नक एक मान्य स्थान प्रदान नहीं करता है।';

  @override
  String get fileActionAttachmentSavedDevice =>
      'इस डिवाइस पर अनुलग्नक सहेजा नहीं जा सका।';

  @override
  String fileActionAttachmentSavedOutputFile(String path) {
    return 'अटैचमेंट $path में सहेजा गया और खोला गया।';
  }

  @override
  String fileActionAttachmentSavedOutputFile2(String path) {
    return 'अटैचमेंट $path में सहेजा गया।';
  }

  @override
  String fileActionAttachmentSavedSavedPath(String savedPath) {
    return 'अटैचमेंट $savedPath में सहेजा गया।';
  }

  @override
  String get fileActionLocalAttachmentFound =>
      'इस डिवाइस पर स्थानीय अनुलग्नक नहीं मिला।';

  @override
  String get fileActionSaveCanceled => 'सहेजना रद्द किया गया।';

  @override
  String get fileActionUnableOpenLocal => 'स्थानीय अनुलग्नक खोलने में असमर्थ।';

  @override
  String get filesAddChat => 'चैट में जोड़ें';

  @override
  String get filesAutosave => 'ऑटोसेव';

  @override
  String get filesAutosaveOn => 'ऑटोसेव चालू';

  @override
  String get filesAutosaveOff => 'ऑटोसेव बंद';

  @override
  String get filesRedo => 'फिर से करें';

  @override
  String get filesUndo => 'पूर्ववत करें';

  @override
  String get filesBinaryFilePreview =>
      'बाइनरी फ़ाइल पूर्वावलोकन उपलब्ध नहीं है।';

  @override
  String get filesClear => 'साफ़ करें';

  @override
  String get filesContents => 'सामग्री';

  @override
  String get filesDuplicate => 'डुप्लिकेट';

  @override
  String get filesDuplicated => 'फ़ाइल डुप्लिकेट की गई';

  @override
  String get filesFileEmpty => 'फ़ाइल खाली है।';

  @override
  String get filesAlreadyExists =>
      'इस नाम वाली फ़ाइल या फ़ोल्डर पहले से मौजूद है।';

  @override
  String get filesCopyPath => 'पथ कॉपी करें';

  @override
  String get filesCreateFileTitle => 'फ़ाइल बनाएं';

  @override
  String get filesCreateFolderTitle => 'फ़ोल्डर बनाएं';

  @override
  String get filesDelete => 'हटाएं';

  @override
  String filesDeleteConfirm(String name) {
    return '$name हटाएं? इसे पूर्ववत नहीं किया जा सकता। फ़ोल्डर और उनकी सामग्री हटा दी जाएगी।';
  }

  @override
  String filesDeleteTitle(String name) {
    return '$name हटाएं';
  }

  @override
  String get filesFilesFound => 'कोई फ़ाइल नहीं मिली';

  @override
  String get filesFileCreated => 'फ़ाइल बन गई।';

  @override
  String get filesFolderCreated => 'फ़ोल्डर बन गया।';

  @override
  String get filesHideSidebar => 'फ़ाइलें साइडबार छुपाएं';

  @override
  String get filesInvalidName => 'बिना पथ विभाजक के मान्य नाम दर्ज करें।';

  @override
  String get filesNameHint => 'नाम';

  @override
  String get filesNew => 'नया';

  @override
  String get filesNewFile => 'नई फ़ाइल';

  @override
  String get filesNewFolder => 'नया फ़ोल्डर';

  @override
  String get filesNames => 'नाम';

  @override
  String get filesQuickOpen => 'त्वरित रूप से खोलें (Quick Open)';

  @override
  String get filesQuickOpenFile => 'त्वरित रूप से फ़ाइल खोलें';

  @override
  String get filesOperationFailed => 'फ़ाइल ऑपरेशन विफल रहा।';

  @override
  String get filesOperationUnavailable =>
      'इस सर्वर के लिए फ़ाइल ऑपरेशन उपलब्ध नहीं हैं।';

  @override
  String get filesOutsideRoot => 'पथ प्रोजेक्ट रूट के बाहर है।';

  @override
  String get filesPathCopied => 'पथ कॉपी किया गया।';

  @override
  String get filesPathMissing => 'पथ मौजूद नहीं है।';

  @override
  String get filesPermissionDenied => 'अनुमति अस्वीकृत।';

  @override
  String get filesRefresh => 'फ़ाइलें रीफ़्रेश करें';

  @override
  String get filesRename => 'नाम बदलें';

  @override
  String filesRenameTitle(String name) {
    return '$name का नाम बदलें';
  }

  @override
  String get filesRenamed => 'नाम बदल दिया गया।';

  @override
  String get filesRootDeleteBlocked => 'प्रोजेक्ट रूट को हटाया नहीं जा सकता।';

  @override
  String get filesSearchHint => 'नाम या पथ द्वारा फ़ाइलें खोजें';

  @override
  String get filesDeleted => 'हटा दिया गया।';

  @override
  String get filesTitle => 'फ़ाइलें';

  @override
  String get forwardAction => 'आगे भेजें';

  @override
  String get forwardAllFailed => 'किसी भी सत्र में आगे नहीं भेजा जा सका';

  @override
  String get forwardCancel => 'रद्द करें';

  @override
  String get forwardDialogSubtitle => 'एक या अधिक बातचीत चुनें';

  @override
  String get forwardDialogTitle => 'आगे भेजें…';

  @override
  String get forwardLoading => 'सत्र लोड हो रहे हैं…';

  @override
  String get forwardNoOpenProjects => 'सत्र वाली कोई खुली परियोजना नहीं';

  @override
  String get forwardNoProviderModel =>
      'आगे भेजने से पहले प्रदाता और मॉडल चुनें';

  @override
  String get forwardNoSessions => 'कोई हालिया सत्र नहीं';

  @override
  String forwardPartial(int success, int total) {
    return '$total में से $success सत्रों में आगे भेजा गया';
  }

  @override
  String forwardProvenanceLabel(String origin) {
    return 'आगे भेजा गया: $origin से';
  }

  @override
  String get forwardRetry => 'पुनः प्रयास करें';

  @override
  String get forwardSearchHint => 'खोजें';

  @override
  String forwardSelectedCount(int count) {
    return '$count चयनित';
  }

  @override
  String get forwardSend => 'आगे भेजें';

  @override
  String get forwardServerOffline => 'सर्वर ऑफ़लाइन है';

  @override
  String get forwardShortcutHint => 'Ctrl+Shift+F';

  @override
  String forwardSuccess(int count) {
    return '$count सत्रों में आगे भेजा गया';
  }

  @override
  String get forwardUndo => 'पूर्ववत करें';

  @override
  String get forwardUndoFailed => 'आगे भेजना पूर्ववत नहीं किया जा सका';

  @override
  String get logsAppLogs => 'ऐप लॉग';

  @override
  String get logsClear => 'लॉग साफ़ करें';

  @override
  String get logsCloseSearch => 'खोज बंद करें';

  @override
  String get logsCopyFiltered => 'फ़िल्टर किए गए लॉग कॉपी करें';

  @override
  String get logsEnableLogging => 'ऐप लॉगिंग चालू करें';

  @override
  String get logsEnableLoggingAction => 'लॉगिंग चालू करें';

  @override
  String get logsEnableLoggingDescription =>
      'मेमोरी में निदान लॉग इकट्ठा करता है। समस्या हल करते समय ही इसे चालू रखें।';

  @override
  String get logsEntryContext => 'संदर्भ';

  @override
  String get logsEntryTags => 'टैग';

  @override
  String get logsFilterAll => 'सभी';

  @override
  String get logsFilterByTag => 'टैग';

  @override
  String get logsLevel => 'स्तर (Level)';

  @override
  String get logsLoggingDisabledDescription =>
      'CodeWalk विस्तृत ऐप लॉग इकट्ठा नहीं कर रहा है। निदान की ज़रूरत होने पर ही लॉगिंग चालू करें।';

  @override
  String get logsLoggingDisabledTitle => 'लॉगिंग बंद है';

  @override
  String get logsMeasurePerformance => 'प्रदर्शन मापें';

  @override
  String get logsMeasurePerformanceDescription =>
      'ऐप के महंगे ऑपरेशन का समय कैप्चर करता है। धीमापन जांचते समय ही चालू रखें।';

  @override
  String get logsNoLogsYet => 'अभी तक कोई लॉग कैप्चर नहीं किया गया है।';

  @override
  String get logsNoMatchingLogs =>
      'कोई भी लॉग वर्तमान फ़िल्टर से मेल नहीं खाता है।';

  @override
  String get logsNoPerformanceData =>
      'मौजूदा फ़िल्टर से कोई प्रदर्शन लॉग मेल नहीं खाता।';

  @override
  String get logsNoTaskData => 'मौजूदा फ़िल्टर से कोई कार्य मेल नहीं खाता।';

  @override
  String logsPerformanceDuration(int elapsedMs) {
    return '$elapsedMs ms';
  }

  @override
  String get logsPerformanceFilter => 'प्रदर्शन';

  @override
  String logsPerformanceTileTitle(
    int elapsedMs,
    String operation,
    String status,
  ) {
    return 'प्रदर्शन $operation | $elapsedMs ms | $status';
  }

  @override
  String get logsSearch => 'लॉग खोजें';

  @override
  String logsShowingOrderedLength(int length, int length2) {
    return '$length2 में से $length प्रविष्टियाँ दिखाई गईं';
  }

  @override
  String get logsSlowestPerformance => 'सबसे धीमे प्रदर्शन लॉग';

  @override
  String get logsSlowestTasks => 'सबसे धीमे कार्य';

  @override
  String get logsTagCustomHint => 'टैग नाम (उदा.: task:select_session)';

  @override
  String get logsTagCustomAction => 'कस्टम...';

  @override
  String logsTaskDuration(int elapsedMs, String operation) {
    return '$operation — $elapsedMs ms';
  }

  @override
  String get logsTaskStatusCanceled => 'रद्द';

  @override
  String get logsTaskStatusError => 'त्रुटि';

  @override
  String get logsTaskStatusOk => 'ठीक';

  @override
  String get logsTimeRange => 'समय सीमा (Time range)';

  @override
  String get mathExpressionLabel => 'गणित';

  @override
  String get mermaidCopySourceTooltip => 'स्रोत कॉपी करें';

  @override
  String get mermaidDiagramLabel => 'मरमेड आरेख (Mermaid Diagram)';

  @override
  String get modelAuto => 'ऑटो';

  @override
  String get modelChooseAgent => 'एजेंट चुनें';

  @override
  String get modelFavorites => 'पसंदीदा';

  @override
  String get modelFree => 'मुफ़्त';

  @override
  String get modelLabelBaseEnglish => 'बेस (अंग्रेजी)';

  @override
  String get modelLabelParakeet => 'Parakeet V3 (25 यूरोपीय भाषाएं)';

  @override
  String get modelLabelSenseVoice => 'SenseVoice (zh/en/ja/ko/yue)';

  @override
  String get modelLabelTinyEnglish => 'Tiny (अंग्रेजी)';

  @override
  String get modelLoadingModels => 'मॉडल लोड हो रहे हैं';

  @override
  String get modelModelsFound => 'कोई मॉडल नहीं मिला';

  @override
  String get modelRetryModels => 'मॉडलों का पुनः प्रयास करें';

  @override
  String get modelSearchHint => 'मॉडल या प्रदाता खोजें';

  @override
  String get msgBatterySettingsFailed =>
      'एंड्रॉइड बैटरी अनुकूलन सेटिंग्स नहीं खोली जा सकीं।';

  @override
  String get msgBatterySettingsOpened =>
      'एंड्रॉइड बैटरी सेटिंग्स खोली गईं। CodeWalk के लिए अप्रतिबंधित बैटरी की अनुमति दें।';

  @override
  String get msgClearUsernameNeedsConfigEdit =>
      'OpenCode बातचीत उपयोगकर्ता नाम को साफ़ करने के लिए अभी भी ऐप के बाहर कॉन्फ़िगरेशन को संपादित करने की आवश्यकता होती है।';

  @override
  String get msgCommandCopied => 'कमांड कॉपी किया गया';

  @override
  String get msgCopiedToClipboard => 'क्लिपबोर्ड पर कॉपी किया गया';

  @override
  String get msgEnterUsernameToSave =>
      'कस्टम OpenCode बातचीत नाम सहेजने के लिए उपयोगकर्ता नाम दर्ज करें।';

  @override
  String get msgFailedToSendMessage =>
      'संदेश भेजने में विफल। पुनः प्रयास के लिए मसौदा (draft) रखा गया है।';

  @override
  String get msgFailedToStartVoiceInput => 'वॉयस इनपुट शुरू करने में विफल';

  @override
  String msgFilePathNotFound(String path) {
    return 'फ़ाइल नहीं मिली: $path';
  }

  @override
  String get msgFilteredLogsCopied =>
      'फ़िल्टर किए गए लॉग क्लिपबोर्ड पर कॉपी किए गए';

  @override
  String get msgInfoAgent => 'एजेंट';

  @override
  String get msgInfoCompaction => 'संकुचन (Compaction)';

  @override
  String msgInfoCost(String cost) {
    return 'लागत: \$$cost';
  }

  @override
  String get msgInfoMessageInfo => 'संदेश की जानकारी';

  @override
  String msgInfoModel(String modelId) {
    return 'मॉडल: $modelId';
  }

  @override
  String get msgInfoNoMetadata => 'कोई मेटाडेटा उपलब्ध नहीं है';

  @override
  String msgInfoPartDescriptionModel(String description, String model) {
    return '$description$model';
  }

  @override
  String get msgInfoPatch => 'पैच';

  @override
  String msgInfoProvider(String providerId) {
    return 'प्रदाता: $providerId';
  }

  @override
  String get msgInfoRetry => 'पुनः प्रयास करें';

  @override
  String get msgInfoSnapshot => 'स्नैपशॉट';

  @override
  String msgInfoSubtaskPartAgent(String agent) {
    return 'उपकार्य ($agent)';
  }

  @override
  String msgInfoTokens(int total) {
    return 'टोकन: $total';
  }

  @override
  String get msgInfoUndoThisTurn => 'इस कदम को पूर्ववत करें';

  @override
  String get msgInfoView => 'देखें';

  @override
  String get msgNoSystemSoundsFound =>
      'इस डिवाइस पर कोई सिस्टम ध्वनि नहीं मिली।';

  @override
  String get msgNoValidFilesSelected => 'कोई वैध फ़ाइल नहीं चुनी गई';

  @override
  String get msgSomeSelectedFilesNotAttached =>
      'कुछ चयनित फ़ाइलें संलग्न नहीं की जा सकीं।';

  @override
  String get msgReadAloud => 'ज़ोर से पढ़ें';

  @override
  String get msgReadAloudNotAvailable =>
      'इस डिवाइस पर टेक्स्ट-टू-स्पीच उपलब्ध नहीं है।';

  @override
  String get msgSetupDebugCopied =>
      'OpenCode सेटअप डिबग क्लिपबोर्ड पर कॉपी किया गया';

  @override
  String get msgShareAsImage => 'छवि के रूप में साझा करें';

  @override
  String get msgShareAsImageFailed =>
      'संदेश को छवि के रूप में साझा नहीं किया जा सका।';

  @override
  String get msgShareAsImageSubject => 'CodeWalk संदेश';

  @override
  String get msgShareAsImageTooTall =>
      'छवि के रूप में साझा करने के लिए संदेश बहुत लंबा है।';

  @override
  String get msgStopReadAloud => 'पढ़ना बंद करें';

  @override
  String get msgPauseReadAloud => 'पढ़ना रोकें';

  @override
  String get msgResumeReadAloud => 'पढ़ना जारी रखें';

  @override
  String get msgSystemSoundPickerUnavailable =>
      'इस प्लेटफॉर्म पर सिस्टम ध्वनि पिकर उपलब्ध नहीं है।';

  @override
  String get msgUpdatedButRefreshFailed =>
      'सर्वर सेटिंग अपडेट की गई, लेकिन चैट प्रदाताओं को रीफ़्रेश नहीं किया जा सका।';

  @override
  String get msgVoiceInputUnavailable => 'इस डिवाइस पर वॉयस इनपुट अनुपलब्ध है';

  @override
  String get notifAndroidBatteryOptimization => 'एंड्रॉइड बैटरी अनुकूलन';

  @override
  String get notifConversationUpdates => 'वार्तालाप अपडेट';

  @override
  String get notifNotificationsArriveReopening =>
      'यदि सूचनाएं केवल ऐप दोबारा खोलने पर आती हैं, तो CodeWalk को इस डिवाइस पर अनुकूलन के बिना चलने की अनुमति दें।';

  @override
  String get notifResponseRunningKeep =>
      'जब कोई प्रतिक्रिया चल रही हो, तो ऐप छोड़ने के बाद थोड़ी देर के लिए रीयलटाइम सक्रिय रखें।';

  @override
  String notifSelectedSoundLabel(String soundLabel) {
    return 'चयनित: $soundLabel';
  }

  @override
  String get notificationAgentFinished =>
      'एजेंट ने वर्तमान प्रतिक्रिया समाप्त कर दी है।';

  @override
  String get notificationConversationUpdates => 'बातचीत अपडेट';

  @override
  String get notificationOpenToClear =>
      'संबंधित सूचनाओं को हटाने के लिए इस बातचीत को खोलें।';

  @override
  String get notificationSession => 'सत्र';

  @override
  String get notificationSoundLoadFailed =>
      'Android सिस्टम ध्वनियाँ लोड करने में विफल';

  @override
  String get onboardingAIGeneratedTitles => 'एआई द्वारा जनरेट किए गए शीर्षक';

  @override
  String get onboardingAddServerLater =>
      'आप बाद में सेटिंग्स > सर्वर में सर्वर जोड़ सकते हैं।';

  @override
  String get onboardingAddedButHealthCheckFailed =>
      'सर्वर जोड़ा गया लेकिन स्वास्थ्य जांच विफल रही। यह अभी भी शुरू हो रहा हो सकता है।';

  @override
  String get onboardingAlmostInstallOpenCode =>
      'आप लगभग पहुँच चुके हैं। पहले OpenCode इंस्टॉल करें, फिर CodeWalk को सर्वर URL से कनेक्ट करें।';

  @override
  String onboardingAppProviderLocalSetupLogsLength(int length, int length2) {
    return '$length सेटअप लॉग पंक्तियाँ और $length2 सेटअप घटनाएँ अलग सेटअप डीबग स्क्रीन में उपलब्ध हैं।';
  }

  @override
  String get onboardingAuthenticate => 'प्रमाणित करें';

  @override
  String get onboardingAvailable => 'उपलब्ध';

  @override
  String get onboardingAvailableOnlyDesktop =>
      'केवल डेस्कटॉप (Linux/macOS/Windows) पर उपलब्ध है।';

  @override
  String get onboardingBasicAuthTip =>
      'बेसिक ऑथ को केवल तभी सक्षम करें जब आपका OpenCode सर्वर पासवर्ड से सुरक्षित हो।';

  @override
  String get onboardingChooseAnotherPath => 'कोई अन्य पथ चुनें';

  @override
  String get onboardingChooseHowToSetup =>
      'चुनें कि अपना सर्वर कैसे सेटअप करें';

  @override
  String get onboardingClear => 'साफ़ करें';

  @override
  String get onboardingCloudflareAuthFailed =>
      'Cloudflare Access प्रमाणीकरण विफल रहा।';

  @override
  String get onboardingCodeWalkAppOpenCode =>
      'CodeWalk ऐप है। OpenCode वह इंजन है जिससे यह कनेक्ट होता है।';

  @override
  String get onboardingConnectRunningServer => 'चल रहे सर्वर से कनेक्ट करें';

  @override
  String get onboardingConnectionIssue => 'कनेक्शन की समस्या';

  @override
  String get onboardingConnectionSaved =>
      'सर्वर कनेक्शन सफलतापूर्वक सहेजा गया।';

  @override
  String get onboardingConnectionTips => 'कनेक्शन के सुझाव';

  @override
  String get onboardingConnectionUpdated =>
      'सर्वर कनेक्शन सफलतापूर्वक अपडेट किया गया।';

  @override
  String get onboardingContinue => 'जारी रखें';

  @override
  String get onboardingContinueServerURL => 'सर्वर URL पर जारी रखें';

  @override
  String get onboardingCopyLoginURL => 'लॉगिन URL कॉपी करें';

  @override
  String get onboardingCouldNotVerify =>
      'सर्वर कनेक्शन को सत्यापित नहीं किया जा सका।';

  @override
  String get onboardingDefaultURLEmulator =>
      'डिफ़ॉल्ट URL, एमुलेटर लूपबैक, प्रमाणीकरण और डिबग सहायता।';

  @override
  String onboardingDesktopOnlyDiagnose(String appName) {
    return 'केवल डेस्कटॉप: $appName आपके लिए OpenCode का निदान, स्थापना और संचालन कर सकता है।';
  }

  @override
  String get onboardingDetailedSetupEvents =>
      'समस्या निवारण के लिए विस्तृत सेटअप घटनाएं कैप्चर की गईं।';

  @override
  String get onboardingDonShowAgain => 'दोबारा न दिखाएं';

  @override
  String get onboardingDone => 'हो गया';

  @override
  String get onboardingEditServer => 'सर्वर संपादित करें';

  @override
  String get onboardingEditServerConnection => 'सर्वर कनेक्शन संपादित करें';

  @override
  String get onboardingEmulatorRemap =>
      'Android एमुलेटर पर, localhost और 127.0.0.1 स्वचालित रूप से 10.0.2.2 पर रीमैप हो जाते हैं।';

  @override
  String get onboardingEnterServerUrl => 'सर्वर URL दर्ज करें';

  @override
  String get onboardingExisting => 'मौजूदा का उपयोग करें';

  @override
  String get onboardingExplainInstallOpenCode =>
      'बताएं कि OpenCode कैसे इंस्टॉल करें, सर्वर कैसे शुरू करें, और फिर CodeWalk से कैसे कनेक्ट करें।';

  @override
  String get onboardingFailed => 'विफल';

  @override
  String get onboardingGoodOptionDesktop => 'डेस्कटॉप पर अच्छा पहला विकल्प';

  @override
  String get onboardingHealthCheckFailedMayBeStarting =>
      'सर्वर स्वास्थ्य जांच विफल रही। यह अभी भी शुरू हो रहा हो सकता है।';

  @override
  String get onboardingInstallBinary => 'बाइनरी इंस्टॉल करें';

  @override
  String get onboardingInstallBun => 'Bun के माध्यम से इंस्टॉल करें';

  @override
  String get onboardingInstallBunOpenCode => 'Bun + OpenCode इंस्टॉल करें';

  @override
  String get onboardingInstallNpm => 'npm के माध्यम से इंस्टॉल करें';

  @override
  String get onboardingInstallRunOpenCode =>
      'डेस्कटॉप पर सीधे CodeWalk से OpenCode इंस्टॉल करें और चलाएं।';

  @override
  String get onboardingInvalidUrl => 'अमान्य URL';

  @override
  String get onboardingLabel => 'लेबल (वैकल्पिक)';

  @override
  String get onboardingLabelHint => 'मेरा सर्वर';

  @override
  String onboardingLatestOutputAppProvider(String localServerLastOutput) {
    return 'नवीनतम आउटपुट: $localServerLastOutput';
  }

  @override
  String get onboardingLetCodeWalkSet =>
      'CodeWalk को इसे स्थानीय रूप से सेट करने दें';

  @override
  String get onboardingLocalServerSetup => 'स्थानीय सर्वर सेटअप';

  @override
  String get onboardingManagedLocalServer => 'प्रबंधित स्थानीय सर्वर';

  @override
  String get onboardingManagedLocalServer2 =>
      'प्रबंधित स्थानीय सर्वर मोड केवल डेस्कटॉप बिल्ड (Linux/macOS/Windows) पर उपलब्ध है।';

  @override
  String onboardingNeedsOpenCodeServer(String appName) {
    return '$appName को आपके कोड में मदद करने से पहले एक OpenCode सर्वर की आवश्यकता है।';
  }

  @override
  String get onboardingNotAvailable => 'उपलब्ध नहीं';

  @override
  String get onboardingNotWritable => 'लिखने योग्य नहीं';

  @override
  String get onboardingOpenCode => 'OpenCode क्या है?';

  @override
  String get onboardingOpenCodeRunningDevice =>
      'मेरे पास इस डिवाइस पर या मेरे नेटवर्क पर कहीं OpenCode पहले से ही चल रहा है।';

  @override
  String get onboardingOpenCodeRunsLocally =>
      'OpenCode स्थानीय रूप से या सर्वर पर चलता है और CodeWalk के अंदर AI कोडिंग सुविधाओं को संचालित करता है। यदि OpenCode पहले से चल रहा है, तो उससे कनेक्ट करें। यदि नहीं, तो नीचे दिए गए निर्देशित सेटअप पथों में से एक चुनें।';

  @override
  String get onboardingOpenTailscaleLogin =>
      'Tailscale लॉगिन URL नहीं खोला जा सका।';

  @override
  String get onboardingPassword => 'पासवर्ड';

  @override
  String get onboardingPasswordRequired => 'पासवर्ड दर्ज करें';

  @override
  String get onboardingPickSetupPath =>
      'वह सेटअप पथ चुनें जो आपके वर्तमान OpenCode सेटअप से मेल खाता हो।';

  @override
  String get onboardingPreconditionDirectoryNotWritable =>
      'इंस्टॉल निर्देशिका लिखने योग्य नहीं है। उपयोगकर्ता अनुमतियों की जांच करें।';

  @override
  String get onboardingPreconditionInstallViaBunRecommendation =>
      'OpenCode अनुरक्षकों द्वारा Bun के माध्यम से इंस्टॉल करने की अनुशंसा की जाती है।';

  @override
  String get onboardingPreconditionNetworkFailed =>
      'नेटवर्क एक्सेस विफल रहा। OpenCode इंस्टॉल करने से पहले कनेक्टिविटी की जांच करें।';

  @override
  String get onboardingPreconditionNoRuntimeDetected =>
      'किसी रनटाइम का पता नहीं चला। OpenCode बाइनरी को सीधे इंस्टॉल करें या पहले Bun को बूटस्ट्रैप करें।';

  @override
  String get onboardingPreconditionNodeNpmAvailable =>
      'Node + npm उपलब्ध हैं। npm के माध्यम से OpenCode इंस्टॉल करें या अनुशंसित फ़्लो के लिए Bun इंस्टॉल करें।';

  @override
  String get onboardingPreconditionOpenCodeAlreadyAvailable =>
      'OpenCode पहले से ही उपलब्ध है। आप तुरंत पहचाने गए कमांड का उपयोग कर सकते हैं।';

  @override
  String get onboardingPreconditionWindowsPathLagHint =>
      ' Windows पर, इंस्टॉल करने के बाद जांच को रीफ्रेश करें क्योंकि पहले से खुले ऐप्स में PATH अपडेट में देरी हो सकती है।';

  @override
  String get onboardingPreconditionWindowsWslRecommendation =>
      'Windows बिल्ड का पता चला है। OpenCode दस्तावेज़ों द्वारा WSL की अनुशंसा की जाती है, लेकिन बैकअप के रूप में npm install का उपयोग किया जा सकता है।';

  @override
  String get onboardingReachable => 'पहुंच योग्य';

  @override
  String get onboardingReady => 'तैयार';

  @override
  String get onboardingRecommendedOrderTry =>
      'अनुशंसित क्रम: यदि आप चाहते हैं कि CodeWalk सब कुछ बूटस्ट्रैप करे, तो Bun + OpenCode इंस्टॉल करें का प्रयास करें। यदि OpenCode पहले से इंस्टॉल है, तो मौजूदा का उपयोग करें चुनें।';

  @override
  String get onboardingRefreshChecks => 'चेक रीफ़्रेश करें';

  @override
  String get onboardingRunDiagnosticsToVerify =>
      'स्थानीय OpenCode आवश्यकताओं को सत्यापित करने के लिए निदान चलाएँ।';

  @override
  String get onboardingSaveAndTest => 'सहेजें और परीक्षण करें';

  @override
  String get onboardingServerConnectedReady =>
      'आपका सर्वर कनेक्ट है और उपयोग के लिए तैयार है।';

  @override
  String get onboardingServerConnection => 'सर्वर कनेक्शन';

  @override
  String get onboardingServerSettingsSaved =>
      'आपकी सर्वर सेटिंग्स सहेजी गईं और स्वास्थ्य जांच रिफ्रेश की गई।';

  @override
  String get onboardingServerSetup => 'सर्वर सेटअप';

  @override
  String get onboardingServerUpdated => 'सर्वर अपडेट किया गया';

  @override
  String get onboardingServerUrl => 'सर्वर URL';

  @override
  String get onboardingSetup => 'सेटअप';

  @override
  String get onboardingSetupWizard => 'सेटअप विज़ार्ड';

  @override
  String get onboardingShowSetupSteps => 'मुझे सेटअप चरण दिखाएं';

  @override
  String get onboardingShowSetupSteps2 => 'सेटअप चरण दिखाएं';

  @override
  String get onboardingSkip => 'अभी के लिए छोड़ें';

  @override
  String get onboardingSkipSetup => 'सेटअप छोड़ें?';

  @override
  String get onboardingStart => 'शुरू करें';

  @override
  String onboardingStartUsing(String appName) {
    return '$appName का उपयोग शुरू करें';
  }

  @override
  String get onboardingStarting => 'शुरू हो रहा है';

  @override
  String get onboardingStop => 'रोकें';

  @override
  String get onboardingStopped => 'रुका हुआ';

  @override
  String get onboardingStopping => 'रुक रहा है';

  @override
  String onboardingSuggestedUrl(String url) {
    return 'सुझाया गया स्थानीय OpenCode सर्वर URL: $url';
  }

  @override
  String get onboardingTailscaleAdminApproval =>
      'Tailscale व्यवस्थापक अनुमोदन आवश्यक';

  @override
  String get onboardingTailscaleAuthAfterSave =>
      'सहेजने के बाद Tailscale प्रमाणित होगा';

  @override
  String onboardingTailscaleAuthAfterSaveTest(String appName) {
    return 'इस सर्वर को सहेजने और परीक्षण करने के बाद, $appName Tailscale लॉगिन खोलेगा यदि यह डिवाइस अभी तक प्रमाणित नहीं है।';
  }

  @override
  String get onboardingTailscaleConnected => 'Tailscale कनेक्टेड';

  @override
  String get onboardingTailscaleConnecting => 'Tailscale कनेक्ट हो रहा है';

  @override
  String get onboardingTailscaleConnectionFailed =>
      'Tailscale कनेक्शन विफल रहा';

  @override
  String get onboardingTailscaleLoginRequired => 'Tailscale लॉगिन आवश्यक';

  @override
  String get onboardingTailscaleOpenLoginUrl =>
      'इस डिवाइस को अपने tailnet में जोड़ने के लिए लॉगिन URL खोलें। यदि ब्राउज़र नहीं खुला, तो नीचे दिए गए URL को कॉपी करें।';

  @override
  String get onboardingTailscaleUnsupported => 'Tailscale समर्थित नहीं है';

  @override
  String get onboardingTestConnection => 'कनेक्शन का परीक्षण करें';

  @override
  String get onboardingTesting => 'परीक्षण जारी है...';

  @override
  String get onboardingUnreachable => 'पहुंच से बाहर';

  @override
  String get onboardingUseBasicAuth => 'Basic Auth का उपयोग करें';

  @override
  String get onboardingUsername => 'उपयोगकर्ता नाम';

  @override
  String get onboardingUsernameRequired => 'उपयोगकर्ता नाम दर्ज करें';

  @override
  String get onboardingUsesServerTitle =>
      'बातचीत का नाम रखने के लिए आपके सर्वर के शीर्षक एजेंट का उपयोग करता है';

  @override
  String get onboardingUsingDetectedCommand =>
      'पता लगाए गए OpenCode कमांड का उपयोग कर रहा है।';

  @override
  String get onboardingViewSetupDebug => 'सेटअप डिबग देखें';

  @override
  String onboardingWelcomeTo(String appName) {
    return '$appName में आपका स्वागत है';
  }

  @override
  String get onboardingWindowsTipInstalling =>
      'विंडोज टिप: इंस्टॉल करने के बाद, चेक रीफ़्रेश करें पर क्लिक करें। यदि पहचान अभी भी विफल रहती है, तो PATH परिवर्तनों को पुनः लोड करने के लिए CodeWalk को फिर से खोलें।';

  @override
  String get onboardingWritable => 'लिखने योग्य';

  @override
  String get onboardingYoureAllSet => 'आप पूरी तरह तैयार हैं!';

  @override
  String get permissionAllowOnce => 'एक बार अनुमति दें';

  @override
  String get permissionAlways => 'हमेशा';

  @override
  String get permissionBack => 'पीछे';

  @override
  String get permissionConfirmReject => 'अस्वीकृति की पुष्टि करें';

  @override
  String get permissionReject => 'अस्वीकार करें';

  @override
  String get permissionReopen => 'फिर से खोलें';

  @override
  String get questionAnswerSelected => 'कोई उत्तर नहीं चुना गया।';

  @override
  String get questionCommaSeparatedValues =>
      'अल्पविराम से अलग किए गए मान (Comma-separated values)';

  @override
  String get questionQuestionGroupMarked =>
      'प्रश्न समूह को अस्वीकार के रूप में चिह्नित किया गया। आप चैट करना जारी रख सकते हैं और पुष्टि करने से पहले किसी भी समय इस समूह को फिर से खोल सकते हैं।';

  @override
  String get questionQuestionRequest => 'प्रश्न का अनुरोध';

  @override
  String get questionQuestionsProvidedSubmit =>
      'कोई प्रश्न प्रदान नहीं किया गया। आप एक खाली प्रतिक्रिया सबमिट कर सकते हैं।';

  @override
  String get questionReviewAnswersSubmitting =>
      'सबमिट करने से पहले अपने उत्तरों की समीक्षा करें।';

  @override
  String get quotaAuthCookie => 'प्रमाणीकरण (Auth) कुकी';

  @override
  String get quotaConnect => 'कनेक्ट करें';

  @override
  String get quotaForget => 'भूल जाएं';

  @override
  String get quotaOpenCodeGoConnectDescription =>
      'रोलिंग, साप्ताहिक और मासिक सीमाएँ दिखाने के लिए उपयोग डैशबोर्ड कनेक्ट करें।';

  @override
  String get quotaOpenCodeGoDetected => 'OpenCode Go मिला';

  @override
  String get quotaOpenCodeGoNeedsReconnect =>
      'OpenCode Go को फिर से कनेक्ट करना होगा';

  @override
  String get quotaOpenCodeGoReconnectDescription =>
      'उपयोग बार वापस लाने के लिए डैशबोर्ड क्रेडेंशियल रीफ़्रेश करें।';

  @override
  String get quotaOpenCodeGoUsage => 'OpenCode Go उपयोग';

  @override
  String get quotaOpenDashboard => 'OpenCode डैशबोर्ड खोलें';

  @override
  String get quotaPaceExplanation =>
      'गति मौजूदा दर के आधार पर वर्तमान सीमा विंडो के अंत तक कुल उपयोग का अनुमान लगाती है।';

  @override
  String quotaPacePercent(String percent) {
    return 'गति $percent%';
  }

  @override
  String get quotaRateLimits => 'उपयोग सीमाएँ';

  @override
  String get quotaReconnect => 'फिर से कनेक्ट करें';

  @override
  String get quotaRefreshing => 'ताज़ा हो रहा है...';

  @override
  String quotaResetsIn(String time) {
    return '$time में रीसेट होगा';
  }

  @override
  String get quotaSaving => 'सहेजा जा रहा है...';

  @override
  String get quotaWorkspaceId => 'कार्यक्षेत्र (Workspace) ID';

  @override
  String get serverClearOAuth => 'OAuth साफ़ करें';

  @override
  String get serverConnectionAttention =>
      'सर्वर कनेक्शन पर ध्यान देने की आवश्यकता है।';

  @override
  String get serverHealthHealthy => 'स्वस्थ';

  @override
  String get serverHealthUnhealthy => 'अस्वस्थ';

  @override
  String get serverHealthUnknown => 'अज्ञात';

  @override
  String get serverOAuthAuthFailed => 'OAuth प्रमाणीकरण विफल रहा';

  @override
  String get serverOAuthChip => 'OAuth';

  @override
  String get serverOAuthNotSupported =>
      'इस प्लेटफ़ॉर्म पर Cloudflare Access OAuth समर्थित नहीं है';

  @override
  String get serverReauthenticate => 'पुनः प्रमाणित करें';

  @override
  String get serverTailscaleChip => 'Tailscale';

  @override
  String get serversActive => 'सक्रिय';

  @override
  String get serversActiveServer => 'सक्रिय सर्वर';

  @override
  String get serversAddLeastOpenCode =>
      'ऐप का उपयोग शुरू करने के लिए कम से कम एक OpenCode सर्वर जोड़ें।';

  @override
  String get serversAddServer => 'सर्वर जोड़ें';

  @override
  String get serversCancel => 'रद्द करें';

  @override
  String get serversCannotActivateUnhealthy =>
      'अस्वस्थ सर्वर को सक्रिय नहीं किया जा सकता';

  @override
  String get serversCheckHealth => 'स्वास्थ्य की जांच करें (Check Health)';

  @override
  String get serversClearDefault => 'डिफ़ॉल्ट साफ़ करें';

  @override
  String serversCommandAppProviderLocalServerCommandPath(
    String localServerCommandPath,
  ) {
    return 'कमांड: $localServerCommandPath';
  }

  @override
  String get serversCopy => 'कॉपी करें';

  @override
  String get serversDefault => 'डिफ़ॉल्ट';

  @override
  String get serversDelete => 'हटाएं';

  @override
  String get serversDeleteServer => 'सर्वर हटाएं';

  @override
  String get serversDesktopModeExplanation =>
      'डेस्कटॉप मोड CodeWalk से सीधे `opencode serve` लॉन्च और प्रबंधित कर सकता है।';

  @override
  String get serversEdit => 'संपादित करें';

  @override
  String get serversLocalOpenCodeServer => 'स्थानीय OpenCode सर्वर';

  @override
  String get serversManagedModeAvailable =>
      'यह प्रबंधित मोड केवल डेस्कटॉप बिल्ड (Linux/macOS/Windows) पर उपलब्ध है।';

  @override
  String get serversNoServersFound => 'कोई सर्वर नहीं मिला';

  @override
  String get serversRefreshHealth => 'स्वास्थ्य रीफ़्रेश करें';

  @override
  String serversRemoveProfileDisplayName(String displayName) {
    return '\"$displayName\" हटाएँ?';
  }

  @override
  String get serversSearchActiveHint => 'सक्रिय सर्वर खोजें';

  @override
  String get serversServersConfigured => 'कोई सर्वर कॉन्फ़िगर नहीं किया गया';

  @override
  String get serversSetActive => 'सक्रिय सेट करें';

  @override
  String get serversSetDefault => 'डिफ़ॉल्ट सेट करें';

  @override
  String get serversSetupDebug => 'सेटअप डिबग';

  @override
  String get serversSetupWizard => 'सेटअप विज़ार्ड';

  @override
  String get serversTailscaleAdminApprovalRequired =>
      'Tailscale व्यवस्थापक अनुमोदन आवश्यक';

  @override
  String get serversTailscaleAuthRequired => 'Tailscale प्रमाणीकरण आवश्यक';

  @override
  String get serversTailscaleConnectExplanation =>
      'इस सक्रिय प्रोफ़ाइल का उपयोग करने पर Tailscale कनेक्ट होगा।';

  @override
  String get serversTailscaleConnected => 'Tailscale कनेक्टेड';

  @override
  String get serversTailscaleConnecting => 'Tailscale कनेक्ट हो रहा है';

  @override
  String get serversTailscaleConnectionFailed => 'Tailscale कनेक्शन विफल';

  @override
  String get serversTailscaleDisconnected => 'Tailscale डिस्कनेक्टेड';

  @override
  String get serversTailscaleLoginExplanation =>
      'इस डिवाइस को अपने tailnet में जोड़ने के लिए Tailscale लॉगिन URL खोलें।';

  @override
  String get serversTailscaleLogout => 'लॉग आउट';

  @override
  String get serversTailscaleLogoutConfirmMessage =>
      'यह डिवाइस tailnet छोड़ देगा। आप कभी भी दोबारा लॉग इन कर सकते हैं।';

  @override
  String get serversTailscaleLogoutConfirmTitle => 'Tailscale से लॉग आउट करें?';

  @override
  String get serversTailscaleReconnect => 'पुनः कनेक्ट करें';

  @override
  String get serversTailscaleTrafficExplanation =>
      'इस सक्रिय प्रोफ़ाइल के लिए OpenCode ट्रैफ़िक Tailscale के माध्यम से रूट किया जाता है।';

  @override
  String get serversTailscaleUnsupported => 'Tailscale समर्थित नहीं है';

  @override
  String get serversUnhealthyActivateError =>
      'यह सर्वर स्वस्थ नहीं है। सक्रिय करने से पहले स्वास्थ्य जांचें या सेटिंग्स संपादित करें।';

  @override
  String get sessionActionArchived => 'संग्रहीत (archived)';

  @override
  String get sessionActionDeleted => 'हटा दिया गया';

  @override
  String get sessionActionForked => 'फ़ोर्क किया गया';

  @override
  String get sessionActionPinned => 'पिन किया गया';

  @override
  String get sessionActionUnarchived => 'असंग्रहीत (unarchived)';

  @override
  String get sessionActionUnpinned => 'अनपिन किया गया';

  @override
  String get sessionArchive => 'संग्रहीत करें';

  @override
  String get sessionCancelRename => 'नाम बदलना रद्द करें';

  @override
  String sessionChildrenCount(int count) {
    return 'उप-वार्तालाप: $count';
  }

  @override
  String get sessionCompactContext => 'संदर्भ संक्षिप्त करें';

  @override
  String get sessionCopyLink => 'लिंक कॉपी करें';

  @override
  String get sessionDelete => 'हटाएं';

  @override
  String sessionDeleteConfirm(String title) {
    return 'क्या आप वाकई \"$title\" वार्तालाप को हटाना चाहते हैं? यह कार्रवाई पूर्ववत नहीं की जा सकती।';
  }

  @override
  String get sessionDeleteTitle => 'बातचीत हटाएं';

  @override
  String get sessionDiffChangedFile => 'बदली गई फ़ाइल';

  @override
  String get sessionDiffContentNotCaptured =>
      'फ़ाइल सामग्री सर्वर द्वारा कैप्चर नहीं की गई';

  @override
  String sessionDiffFilesChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count फ़ाइलें बदली गईं',
      one: '1 फ़ाइल बदली गई',
    );
    return '$_temp0';
  }

  @override
  String sessionDiffFilesCount(int count) {
    return 'Diff फ़ाइलें: $count';
  }

  @override
  String sessionDiffLinesAddedRemoved(int added, int removed) {
    return '+$added पंक्तियाँ जोड़ी गईं -$removed पंक्तियाँ हटाई गईं';
  }

  @override
  String sessionDiffLinesCollapsed(int count) {
    return '$count पंक्तियाँ संकुचित की गईं — विस्तार करने के लिए टैप करें';
  }

  @override
  String get sessionDiffLoading => 'बदली गई फ़ाइलें लोड हो रही हैं…';

  @override
  String get sessionDiffReview => 'परिवर्तनों की समीक्षा करें';

  @override
  String get sessionDiffSplit => 'विभाजित (Split)';

  @override
  String get sessionDiffSummary => 'सारांश';

  @override
  String get sessionDiffUnified => 'एकीकृत (Unified)';

  @override
  String get sessionExportAssistant => 'सहायक';

  @override
  String get sessionExportCanceled => 'सत्र निर्यात रद्द किया गया';

  @override
  String get sessionExportDebugJson => 'डीबग JSON निर्यात करें';

  @override
  String get sessionExportDebugJsonErrorClipboard =>
      'फ़ाइल सहेजी नहीं जा सकी; डीबग JSON क्लिपबोर्ड पर कॉपी किया गया';

  @override
  String get sessionExportDebugJsonSaved => 'डीबग JSON निर्यात सहेजा गया';

  @override
  String get sessionExportDebugJsonTitle =>
      'डीबग JSON के रूप में सत्र निर्यात करें';

  @override
  String get sessionExportError => 'त्रुटि:';

  @override
  String get sessionExportInput => 'इनपुट:';

  @override
  String get sessionExportMarkdown => 'Markdown निर्यात करें';

  @override
  String get sessionExportMarkdownErrorClipboard =>
      'फ़ाइल सहेजी नहीं जा सकी; Markdown क्लिपबोर्ड पर कॉपी किया गया';

  @override
  String get sessionExportMarkdownSaved => 'Markdown निर्यात सहेजा गया';

  @override
  String get sessionExportMarkdownTitle =>
      'Markdown के रूप में सत्र निर्यात करें';

  @override
  String get sessionExportOutput => 'आउटपुट:';

  @override
  String get sessionExportUntitled => 'बिना शीर्षक वाला सत्र';

  @override
  String get sessionExportUser => 'उपयोगकर्ता';

  @override
  String get sessionFailedRename => 'बातचीत का नाम बदलने में विफल';

  @override
  String get sessionFailedUpdateArchive =>
      'संग्रह (archive) स्थिति अपडेट करने में विफल';

  @override
  String get sessionFailedUpdateSharing => 'साझाकरण स्थिति अपडेट करने में विफल';

  @override
  String get sessionFork => 'फ़ोर्क (Fork) करें';

  @override
  String get sessionForkFailed => 'वार्तालाप फोर्क करने में विफल';

  @override
  String get sessionForked => 'वार्तालाप फोर्क किया गया';

  @override
  String sessionHasError(String title) {
    return '\"$title\" में त्रुटि है।';
  }

  @override
  String sessionHasNewReply(String title) {
    return '\"$title\" में नया उत्तर है।';
  }

  @override
  String get sessionKeyboardShortcuts => 'कीबोर्ड शॉर्टकट';

  @override
  String sessionNeedsInput(String title) {
    return '\"$title\" को आपके इनपुट की आवश्यकता है।';
  }

  @override
  String get sessionNoCachedConversations => 'अभी तक कोई कैश्ड वार्तालाप नहीं';

  @override
  String get sessionNoConversationsInProject =>
      'इस प्रोजेक्ट में कोई वार्तालाप नहीं।';

  @override
  String get sessionNotAvailable =>
      'इस परियोजना के लिए बातचीत अभी उपलब्ध नहीं है';

  @override
  String get sessionOpenProjectToLoad =>
      'वार्तालाप लोड करने के लिए प्रोजेक्ट खोलें।';

  @override
  String get sessionPin => 'पिन करें';

  @override
  String get sessionRename => 'नाम बदलें';

  @override
  String get sessionRenameHint => 'नया बातचीत नाम दर्ज करें';

  @override
  String get sessionRenameTitle => 'बातचीत का नाम बदलें';

  @override
  String get sessionSaveTitle => 'शीर्षक सहेजें';

  @override
  String get sessionShare => 'सत्र साझा करें';

  @override
  String get sessionShareAction => 'साझा करें';

  @override
  String get sessionShareLinkCopied => 'साझाकरण लिंक कॉपी किया गया';

  @override
  String get sessionShareLinkUnavailable =>
      'इस सत्र के लिए लिंक उपलब्ध नहीं है';

  @override
  String get sessionShared => 'वार्तालाप साझा किया गया';

  @override
  String get sessionSyncing => 'वार्तालाप सिंक हो रहे हैं...';

  @override
  String get sessionTitleHint => 'बातचीत का शीर्षक';

  @override
  String get sessionUnarchive => 'असंग्रहीत करें';

  @override
  String get sessionUnpin => 'अनपिन करें';

  @override
  String get sessionUnshare => 'सत्र साझा करना बंद करें';

  @override
  String get sessionUnshareAction => 'साझा करना बंद करें';

  @override
  String get sessionUnshared => 'वार्तालाप साझा करना बंद किया गया';

  @override
  String get sessionViewTasks => 'कार्य देखें';

  @override
  String get settingsAboutCheckForUpdates => 'अपडेट की जांच करें';

  @override
  String get settingsAboutCheckOnOpen => 'खोलने पर अपडेट की जांच करें';

  @override
  String get settingsAboutCheckOnOpenDescription =>
      'ऐप शुरू होने पर स्वचालित रूप से जांचें';

  @override
  String get settingsAboutChecking => 'जांच की जा रही है...';

  @override
  String get settingsAboutDescription => 'संस्करण, अपडेट, सहायता और ऐप डेटा';

  @override
  String get settingsAboutDismiss => 'खारिज करें';

  @override
  String settingsAboutDownloading(String percent) {
    return 'डाउनलोड हो रहा है... $percent%';
  }

  @override
  String get settingsAboutEraseAllData => 'सारा डेटा मिटाएं और रीस्टार्ट करें';

  @override
  String get settingsAboutInstallUpdate => 'अपडेट इंस्टॉल करें';

  @override
  String get settingsAboutInstalling => 'इंस्टॉल हो रहा है...';

  @override
  String settingsAboutLatestVersion(String version) {
    return 'v$version नवीनतम संस्करण है';
  }

  @override
  String get settingsAboutLoading => 'लोड हो रहा है...';

  @override
  String get settingsAboutReplayChatTour => 'चैट टूर दोबारा चलाएं';

  @override
  String get settingsAboutReplayChatTourDescription =>
      'सेटिंग्स बंद करें और निर्देशित चैट वॉकथ्रू दिखाएं';

  @override
  String get settingsAboutResetApp => 'ऐप रीसेट करें';

  @override
  String get settingsAboutResetAppQuestion => 'ऐप रीसेट करें?';

  @override
  String get settingsAboutResetAppWarning =>
      'इससे सभी सर्वर, सेटिंग्स और कैश्ड डेटा मिट जाएंगे। इस कार्रवाई को पूर्ववत नहीं किया जा सकता।';

  @override
  String get settingsAboutRetryInstall => 'इंस्टॉल करने का पुनः प्रयास करें';

  @override
  String get settingsAboutTapToCheck =>
      'नए संस्करणों की जांच करने के लिए टैप करें';

  @override
  String get settingsAboutTitle => 'के बारे में';

  @override
  String get settingsAboutUpToDate => 'आप अद्यतित (up to date) हैं';

  @override
  String settingsAboutUpdateAvailable(String version) {
    return 'अपडेट उपलब्ध है: v$version';
  }

  @override
  String get settingsAboutUpdateInstalled =>
      'अपडेट इंस्टॉल हो गया। लागू करने के लिए ऐप को पुनरारंभ करें।';

  @override
  String settingsAboutUpdateVersionSummary(
    String installedVersion,
    String latestVersion,
  ) {
    return 'वर्तमान: $installedVersion; उपलब्ध: v$latestVersion';
  }

  @override
  String get settingsAboutVersion => 'संस्करण';

  @override
  String settingsAboutVersionBuild(String buildNumber, String version) {
    return '$version (बिल्ड $buildNumber)';
  }

  @override
  String get settingsAppearanceAmoledDark => 'AMOLED डार्क मोड';

  @override
  String get settingsAppearanceAmoledDarkActive =>
      'डार्क मोड सक्रिय होने पर शुद्ध काली सतहों का उपयोग करें।';

  @override
  String get settingsAppearanceAmoledDarkInactive =>
      'AMOLED सतहों को सक्षम करने के लिए डार्क मोड पर स्विच करें।';

  @override
  String get settingsAppearanceBrandColor => 'ब्रांड रंग';

  @override
  String get settingsAppearanceBrandColorDynamicBlocked =>
      'ब्रांड रंग चुनने के लिए वॉलपेपर रंगों को अक्षम करें।';

  @override
  String get settingsAppearanceBrandColorNormal =>
      'ऐप पैलेट के लिए एक बीज (seed) रंग चुनें।';

  @override
  String get settingsAppearanceBrandColorPresetBlocked =>
      'ब्रांड रंग चुनने के लिए CodeWalk क्लासिक पर स्विच करें।';

  @override
  String get settingsAppearanceChatFontScale => 'बातचीत टेक्स्ट आकार';

  @override
  String get settingsAppearanceChatFontScaleDescription =>
      'सिस्टम टेक्स्ट आकार के ऊपर चैट संदेश और कंपोज़र टेक्स्ट को स्केल करें।';

  @override
  String get settingsAppearanceCodeWalkClassic => 'CodeWalk क्लासिक';

  @override
  String get settingsAppearanceComposerTips => 'कंपोज़र युक्तियाँ';

  @override
  String get settingsAppearanceComposerTipsDescription =>
      'जब सहायक विचार कर रहा हो तो घूमती हुई युक्तियाँ दिखाएं या छिपाएं।';

  @override
  String get settingsAppearanceContrast => 'कांट्रास्ट';

  @override
  String get settingsAppearanceContrastDynamicBlocked =>
      'कांट्रास्ट समायोजित करने के लिए वॉलपेपर रंगों को अक्षम करें।';

  @override
  String get settingsAppearanceContrastHigh => 'उच्च';

  @override
  String get settingsAppearanceContrastNormal =>
      'रंग योजना के कांट्रास्ट स्तर को समायोजित करें।';

  @override
  String get settingsAppearanceContrastPresetBlocked =>
      'कांट्रास्ट समायोजित करने के लिए CodeWalk क्लासिक पर स्विच करें।';

  @override
  String get settingsAppearanceContrastReduced => 'कम किया गया';

  @override
  String get settingsAppearanceDark => 'डार्क';

  @override
  String get settingsAppearanceDensity => 'घनत्व';

  @override
  String get settingsAppearanceDensityDense => 'घना';

  @override
  String get settingsAppearanceDensityDescription =>
      'ऐप में रिक्ति और घटक घनत्व लागू करें।';

  @override
  String get settingsAppearanceDensityExtraDense => 'अत्यधिक घना';

  @override
  String get settingsAppearanceDensityExtraSpacious => 'अत्यधिक विस्तृत';

  @override
  String get settingsAppearanceDensityNormal => 'सामान्य';

  @override
  String get settingsAppearanceDensitySpacious => 'विस्तृत';

  @override
  String get settingsAppearanceDescription =>
      'थीम, रंग, टेक्स्ट आकार और चैट प्रदर्शन चुनें';

  @override
  String get settingsAppearanceFontSize => 'टेक्स्ट आकार';

  @override
  String get settingsAppearanceFontSizeDescription =>
      'सिस्टम टेक्स्ट, बातचीत टेक्स्ट और टर्मिनल टेक्स्ट का आकार समायोजित करें।';

  @override
  String get settingsAppearanceLight => 'लाइट';

  @override
  String get settingsAppearanceMathRendering => 'गणित रेंडरिंग';

  @override
  String get settingsAppearanceMathRenderingDescription =>
      'चैट संदेशों में LaTeX गणितीय अभिव्यक्तियों को टाइपसेट समीकरणों के रूप में प्रस्तुत करें।';

  @override
  String get settingsAppearanceNoPresets => 'कोई प्रीसेट पैलेट नहीं मिला';

  @override
  String get settingsAppearanceOpenCodePresets => 'OpenCode प्रीसेट';

  @override
  String get settingsAppearancePresetHelper =>
      'आधिकारिक OpenCode वेब अंतर्निहित थीम सूची को दर्शाता है।';

  @override
  String get settingsAppearancePresetNote =>
      'थीम रंग अब आधिकारिक OpenCode वेब रजिस्ट्री का अनुसरण करते हैं और मार्कडाउन/कोड सतहों को भी संचालित करते हैं।';

  @override
  String get settingsAppearancePresetPalette => 'प्रीसेट पैलेट';

  @override
  String get settingsAppearanceSearchPreset => 'प्रीसेट पैलेट खोजें';

  @override
  String get settingsAppearanceSectionDescription =>
      'अपने वर्कफ़्लो के लिए दृश्य घनत्व और संदेश सतहों को ट्यून करें।';

  @override
  String get settingsAppearanceSectionTitle => 'रूप-रंग';

  @override
  String get settingsAppearanceSystem => 'सिस्टम';

  @override
  String get settingsAppearanceSystemFontScale => 'सिस्टम टेक्स्ट आकार';

  @override
  String get settingsAppearanceSystemFontScaleDescription =>
      'मेनू, डायलॉग और साइडबार सहित ऐप शेल के सभी टेक्स्ट को स्केल करें।';

  @override
  String get settingsAppearanceTaskList => 'कार्य सूची';

  @override
  String get settingsAppearanceTaskListDescription =>
      'सत्र कार्य सूची विजेट दिखाएं या छिपाएं।';

  @override
  String get settingsAppearanceTerminalFontSize => 'टर्मिनल टेक्स्ट आकार';

  @override
  String get settingsAppearanceTerminalFontSizeDescription =>
      'एम्बेडेड टर्मिनल फ़ॉन्ट का आकार बदलें। चल रहे सत्रों पर तुरंत लागू होता है।';

  @override
  String get settingsAppearanceTheme => 'थीम';

  @override
  String get settingsAppearanceThemeDescription =>
      'लाइट, डार्क या सिस्टम मोड चुनें, फिर CodeWalk क्लासिक पैलेट रखें या OpenCode प्रीसेट पर स्विच करें।';

  @override
  String get settingsAppearanceVisualStyle => 'दृश्य शैली';

  @override
  String get settingsAppearanceVisualStyleDescription =>
      'क्लासिक रूप या नरम परिष्कृत सतहें चुनें।';

  @override
  String get settingsAppearanceVisualStyleClassic => 'क्लासिक';

  @override
  String get settingsAppearanceVisualStyleRefined => 'परिष्कृत';

  @override
  String get settingsAppearanceThinkingBubbles =>
      'विचार करने वाले बुलबुले (Thinking bubbles)';

  @override
  String get settingsAppearanceThinkingBubblesDescription =>
      'सहायक संदेशों में तर्क ब्लॉकों को दिखाएं या छिपाएं।';

  @override
  String get settingsAppearanceTitle => 'रूप-रंग';

  @override
  String get settingsAppearanceToolCallBubbles => 'टूल कॉल बुलबुले';

  @override
  String get settingsAppearanceToolCallBubblesDescription =>
      'सहायक संदेशों में टूल निष्पादन (tool execution) कार्ड दिखाएं या छिपाएं।';

  @override
  String get settingsAppearanceWallpaperColors => 'वॉलपेपर रंगों का उपयोग करें';

  @override
  String get settingsAppearanceWallpaperNormal =>
      'अपने डिवाइस वॉलपेपर से रंग योजना निकालें।';

  @override
  String get settingsAppearanceWallpaperPresetBlocked =>
      'वॉलपेपर रंगों का उपयोग करने के लिए CodeWalk क्लासिक पर स्विच करें।';

  @override
  String get settingsAppearanceWindowChrome => 'विंडो टैब';

  @override
  String get settingsAppearanceWindowChromeDescription =>
      'चुनें कि डेस्कटॉप पर सत्र टैब और टाइटल बार कैसे जोड़े जाएँ।';

  @override
  String get settingsAppearanceWindowChromeIntegrated => 'एकीकृत टैब';

  @override
  String get settingsAppearanceWindowChromeIntegratedDescription =>
      'टैब विंडो के शीर्ष पर रहते हैं और सिस्टम टाइटल बार छिप जाता है।';

  @override
  String get settingsAppearanceWindowChromeSystem => 'सिस्टम सजावट';

  @override
  String get settingsAppearanceWindowChromeSystemDescription =>
      'मूल टाइटल बार बनाए रखता है और टैब को ऐप बार के नीचे दिखाता है।';

  @override
  String get settingsBack => 'पीछे';

  @override
  String get settingsBehaviorAutoupdateCaveat =>
      'CodeWalk रिलीज़ जांच के लिए के बारे में (About) का उपयोग करें। यह सेटिंग केवल आधिकारिक OpenCode `autoupdate` कॉन्फ़िगरेशन को दर्शाता है।';

  @override
  String get settingsBehaviorAutoupdateHelp =>
      'अपस्ट्रीम OpenCode रनटाइम अपडेट को नियंत्रित करता है, न कि CodeWalk ऐप अपडेट की जांच को।';

  @override
  String get settingsBehaviorCellularDataSaver => 'सेलुलर डेटा सेवर';

  @override
  String get settingsBehaviorChatRenderMode => 'चैट रेंडर मोड';

  @override
  String get settingsBehaviorChatRenderModeBlock => 'ब्लॉक';

  @override
  String get settingsBehaviorChatRenderModeBlockDescription =>
      'जब तक वर्तमान टर्न को एक ब्लॉक के रूप में नहीं दिखाया जा सकता, तब तक लाइव असिस्टेंट टेक्स्ट, तर्क और टूल कार्ड छिपाएं।';

  @override
  String get settingsBehaviorChatRenderModeDescription =>
      'चुनें कि असिस्टेंट प्रतिक्रियाएं स्ट्रीम होते ही दिखें या वर्तमान टर्न पूरा होने के बाद प्रकट हों।';

  @override
  String get settingsBehaviorChatRenderModeLive => 'लाइव';

  @override
  String get settingsBehaviorChatRenderModeLiveDescription =>
      'OpenCode इवेंट स्ट्रीम करते समय असिस्टेंट टेक्स्ट, तर्क और टूल गतिविधि दिखाएं।';

  @override
  String get settingsBehaviorComposerSpellCheck => 'कंपोज़र वर्तनी जांच';

  @override
  String get settingsBehaviorComposerSpellCheckDescription =>
      'चैट कंपोज़र में नेटिव प्लेटफ़ॉर्म वर्तनी जांच, सुझाव और ऑटोकरेक्ट का उपयोग करें।';

  @override
  String get settingsBehaviorConfigDeferred =>
      'वर्तमान प्रतिक्रिया समाप्त होने के बाद CodeWalk इस OpenCode सेटिंग को लागू करेगा।';

  @override
  String settingsBehaviorConfigUpdateFailed(String field) {
    return 'OpenCode $field को अपडेट नहीं किया जा सका।';
  }

  @override
  String get settingsBehaviorConversationUsername =>
      'वार्तालाप उपयोगकर्ता नाम (username)';

  @override
  String get settingsBehaviorConversationUsernameHelp =>
      'सिस्टम उपयोगकर्ता नाम के बजाय वार्तालाप में दिखाया जाने वाला कस्टम नाम।';

  @override
  String get settingsBehaviorDataSaverActive => 'मोबाइल डेटा पर अभी सक्रिय है।';

  @override
  String get settingsBehaviorDataSaverCellularOnly =>
      'केवल तब लागू होता है जब कनेक्शन सेलुलर/मोबाइल हो।';

  @override
  String get settingsBehaviorDataSaverDescription =>
      'पृष्ठभूमि डाउनलोड को रोककर और स्वचालित अग्रभूमि (foreground) रीफ़्रेश को कम करके स्वचालित मोबाइल डेटा उपयोग को कम करता है।';

  @override
  String get settingsBehaviorDataSaverWaiting =>
      'अगले मोबाइल-डेटा सिंक विंडो की प्रतीक्षा की जा रही है।';

  @override
  String get settingsBehaviorDefaultAgent => 'डिफ़ॉल्ट एजेंट';

  @override
  String get settingsBehaviorDefaultAgentHelp =>
      'प्राथमिक एजेंट जिसका उपयोग तब किया जाता है जब कोई एजेंट स्पष्ट रूप से नहीं चुना जाता है।';

  @override
  String get settingsBehaviorDefaultModel => 'डिफ़ॉल्ट मॉडल';

  @override
  String get settingsBehaviorDefaultModelHelp =>
      'कॉन्फ़िगरेशन के माध्यम से OpenCode क्लाइंट्स में साझा किया गया।';

  @override
  String get settingsBehaviorDescription =>
      'भाषा, चैट व्यवहार, डेटा उपयोग और OpenCode डिफ़ॉल्ट नियंत्रित करें';

  @override
  String get settingsBehaviorEnableDataSaver => 'सेलुलर डेटा सेवर सक्षम करें';

  @override
  String get settingsBehaviorMultiDeviceSync =>
      'प्रायोगिक मल्टी-डिवाइस सिंक सक्षम करें';

  @override
  String get settingsBehaviorMultiDeviceSyncDescription =>
      'सक्रिय सर्वर कॉन्फ़िगरेशन के साथ कंपोज़र चयन (एजेंट/मॉडल/वेरिएंट) को सिंक करें।';

  @override
  String get settingsBehaviorMultiDeviceSyncWarning =>
      'एक ही समय में एक से अधिक सत्रों (sessions) में काम करते समय चल रहे सत्रों को निरस्त कर सकता है।';

  @override
  String get settingsBehaviorNoAgents => 'कोई एजेंट नहीं मिला';

  @override
  String get settingsBehaviorNoModels => 'कोई मॉडल नहीं मिला';

  @override
  String get settingsBehaviorOpenCodeAutoupdate => 'OpenCode ऑटो-अपडेट';

  @override
  String get settingsBehaviorOpenCodeDefaults => 'OpenCode-समर्थित डिफ़ॉल्ट';

  @override
  String get settingsBehaviorOpenCodeDefaultsDescription =>
      'ये मान सक्रिय सर्वर पर `/config` में लिखे जाते हैं और आधिकारिक OpenCode साझा कॉन्फ़िगरेशन से मेल खाते हैं।';

  @override
  String get settingsBehaviorOpenCodeSnapshots => 'OpenCode स्नैपशॉट';

  @override
  String get settingsBehaviorOpenCodeSnapshotsDescription =>
      'पूर्ववत/फिर से करें (undo/redo) और पुनर्प्राप्ति इतिहास के लिए अपस्ट्रीम गिट-समर्थित स्नैपशॉट सक्षम रखें।';

  @override
  String get settingsBehaviorPermissionDeferred =>
      'उन्नत अनुमति नियम संपादन अभी के लिए सेटिंग्स से बाहर है और बाद के समानता (parity) कार्य के लिए स्थगित कर दिया गया है।';

  @override
  String get settingsBehaviorPermissionProvenance =>
      'अनुमति संचालन उत्पत्ति (provenance)';

  @override
  String get settingsBehaviorPermissionProvenanceDescription =>
      'आधिकारिक OpenCode अनुमति नीति को `opencode.json` में प्रति टूल allow/ask/deny नियमों के साथ कॉन्फ़िगर किया गया है। CodeWalk आधिकारिक अनुमति-अनुरोध कार्ड रखता है और एक स्वीकृत ADR-023 अपवाद जोड़ता है: कंपोज़र ऑटो-अनुमोदन टॉगल बिना शर्त `Always` और `remember: true` के साथ उत्तर देता है ताकि टिकाऊ सत्र-स्कोप्ड अनुदान बनाया जा सके, और एंड्रॉइड बैकग्राउंड वर्कर में समान थ्रेड-स्कोप्ड निरंतरता पथ को सक्रिय रखता है।';

  @override
  String get settingsBehaviorRefreshDefaults => 'डिफ़ॉल्ट रीफ़्रेश करें';

  @override
  String get settingsBehaviorSaveUsername => 'उपयोगकर्ता नाम सहेजें';

  @override
  String get settingsBehaviorSearchAutoupdate => 'ऑटो-अपडेट मोड खोजें';

  @override
  String get settingsBehaviorSearchDefaultAgent => 'डिफ़ॉल्ट एजेंट खोजें';

  @override
  String get settingsBehaviorSearchDefaultModel => 'डिफ़ॉल्ट मॉडल खोजें';

  @override
  String get settingsBehaviorSearchShareMode => 'साझाकरण मोड खोजें';

  @override
  String get settingsBehaviorSearchSmallModel => 'छोटा मॉडल खोजें';

  @override
  String get settingsBehaviorShareMode => 'OpenCode साझाकरण डिफ़ॉल्ट';

  @override
  String get settingsBehaviorShareModeCaveat =>
      'अभी एक सत्र प्रकाशित करने के लिए चैट-स्तरीय साझाकरण क्रिया का उपयोग करें। यह सेटिंग केवल OpenCode की डिफ़ॉल्ट साझाकरण नीति को बदलती है।';

  @override
  String get settingsBehaviorShareModeHelp =>
      'आधिकारिक वैश्विक `share` कॉन्फ़िगरेशन को नियंत्रित करता है, न कि किसी व्यक्तिगत चैट के लिए साझाकरण बटन को।';

  @override
  String get settingsBehaviorSmallModel => 'छोटा मॉडल';

  @override
  String get settingsBehaviorSmallModelAutoFallback => 'स्वचालित फ़ॉलबैक';

  @override
  String get settingsBehaviorSmallModelFallbackActive =>
      'OpenCode स्वचालित फ़ॉलबैक सक्रिय है क्योंकि `small_model` सेट नहीं है।';

  @override
  String get settingsBehaviorSmallModelHelp =>
      'शीर्षक पीढ़ी (title generation) जैसे हल्के कार्यों के लिए उपयोग किया जाता है।';

  @override
  String get settingsBehaviorSmallModelResetCaveat =>
      '`small_model` को स्वचालित फ़ॉलबैक पर रीसेट करने के लिए अभी भी ऐप के बाहर कॉन्फ़िगरेशन को संपादित करने की आवश्यकता होती है क्योंकि `/config` पैच अपडेट कुंजियों को हटा नहीं सकते हैं।';

  @override
  String get settingsBehaviorSnapshotCaveat =>
      'यह OpenCode स्नैपशॉट स्टोरेज और अनडू/रीडू सपोर्ट को नियंत्रित करता है, न कि CodeWalk स्थानीय कैश स्नैपशॉट को।';

  @override
  String get settingsBehaviorTitle => 'व्यवहार';

  @override
  String get settingsBehaviorUsernameFallback =>
      'OpenCode सिस्टम उपयोगकर्ता नाम का उपयोग करता है क्योंकि `username` सेट नहीं है।';

  @override
  String get settingsBehaviorUsernamePatchCaveat =>
      '`username` को वापस सिस्टम डिफ़ॉल्ट पर रीसेट करने के लिए अभी भी ऐप के बाहर कॉन्फ़िगरेशन को संपादित करने की आवश्यकता होती है क्योंकि `/config` पैच अपडेट कुंजियों (keys) को हटा नहीं सकते हैं।';

  @override
  String get settingsConfigRefreshFailed =>
      'सर्वर सेटिंग अपडेट की गई, लेकिन चैट प्रदाताओं को रीफ़्रेश नहीं किया जा सका।';

  @override
  String get settingsConfigUpdateDeferred =>
      'वर्तमान प्रतिक्रिया समाप्त होने के बाद CodeWalk इस OpenCode सेटिंग को लागू करेगा।';

  @override
  String get settingsConversationUsername => 'बातचीत उपयोगकर्ता नाम';

  @override
  String get settingsDefaultAgent => 'डिफ़ॉल्ट एजेंट';

  @override
  String get settingsDefaultModel => 'डिफ़ॉルト मॉडल';

  @override
  String get settingsLanguageDescription =>
      'CodeWalk द्वारा उपयोग की जाने वाली भाषा चुनें। सिस्टम डिफ़ॉल्ट आपके डिवाइस की भाषा का अनुसरण करता है।';

  @override
  String get settingsLanguageEmptyText => 'कोई भाषा नहीं मिली';

  @override
  String get settingsLanguageFieldHelper =>
      'तुरंत लागू होता है और पुनरारंभ (restart) करने पर भी बना रहता है।';

  @override
  String get settingsLanguageFieldLabel => 'ऐप की भाषा';

  @override
  String get settingsLanguageSearchHint => 'भाषाएँ खोजें';

  @override
  String get settingsLanguageSystemDefault => 'सिस्टम डिफ़ॉल्ट';

  @override
  String get settingsLanguageTitle => 'भाषा';

  @override
  String get settingsLogsDescription =>
      'ऐप डायग्नोस्टिक्स और समस्या निवारण विवरण देखें';

  @override
  String get settingsLogsTitle => 'Registros';

  @override
  String get settingsNoAgentsFound => 'कोई एजेंट नहीं मिला';

  @override
  String get settingsNotificationsAgentSubtitle =>
      'जब कोई प्रतिक्रिया समाप्त होती है';

  @override
  String get settingsNotificationsAgentUpdates => 'एजेंट अपडेट';

  @override
  String get settingsNotificationsAnotherConversation => 'कोई अन्य बातचीत';

  @override
  String get settingsNotificationsAppInBackground => 'ऐप पृष्ठभूमि में हो';

  @override
  String get settingsNotificationsBackgroundAlerts =>
      'एंड्रॉइड पृष्ठभूमि अलर्ट';

  @override
  String get settingsNotificationsBackgroundBehavior => 'पृष्ठभूमि व्यवहार';

  @override
  String get settingsNotificationsBackgroundBehaviorDescription =>
      'चुनें कि फ़ोरग्राउंड छोड़ने के बाद CodeWalk कैसा व्यवहार करे।';

  @override
  String get settingsNotificationsBackgroundDescription =>
      'जब ऐप स्क्रीन पर न हो तो प्रतिक्रिया पूर्ण होने, अनुमति अनुरोधों, प्रश्नों और त्रुटियों के लिए कम-डेटा पृष्ठभूमि निगरानी का उपयोग करें।';

  @override
  String get settingsNotificationsBackgroundToggle =>
      'एंड्रॉइड पर पृष्ठभूमि अलर्ट';

  @override
  String get settingsNotificationsBackgroundToggleDescription =>
      'सभी एंड्रॉइड पृष्ठभूमि जांच बंद करें और निरंतर मॉनिटर अधिसूचना छुपाएं।';

  @override
  String get settingsNotificationsBatteryDescription =>
      'यदि सूचनाएं केवल ऐप दोबारा खोलने पर आती हैं, तो CodeWalk को इस डिवाइस पर अनुकूलन के बिना चलने की अनुमति दें।';

  @override
  String get settingsNotificationsBatteryDisabled =>
      'CodeWalk के लिए बैटरी अनुकूलन अक्षम है।';

  @override
  String get settingsNotificationsBatteryEnabled =>
      'बैटरी अनुकूलन सक्षम है। कुछ डिवाइस पृष्ठभूमि अलर्ट में देरी कर सकते हैं।';

  @override
  String get settingsNotificationsBatteryOptimization =>
      'एंड्रॉइड बैटरी अनुकूलन';

  @override
  String get settingsNotificationsBatteryUnknown =>
      'बैटरी अनुकूलन स्थिति अभी नहीं पढ़ी जा सकी।';

  @override
  String get settingsNotificationsChooseAudioFile => 'ऑडियो फ़ाइल चुनें';

  @override
  String get settingsNotificationsChooseSystemSound => 'सिस्टम ध्वनि चुनें';

  @override
  String get settingsNotificationsCloseToTray =>
      'ट्रे में बंद करें (Close to tray)';

  @override
  String get settingsNotificationsCloseToTrayDescription =>
      'विंडो छुपाएं और सिस्टम ट्रे में चलते रहें।';

  @override
  String get settingsNotificationsDescription =>
      'चुनें कि कौन सी घटनाएँ आपको सचेत करें और कैसे';

  @override
  String get settingsNotificationsDisableOptimization => 'अनुकूलन अक्षम करें';

  @override
  String get settingsNotificationsErrors => 'त्रुटियां';

  @override
  String get settingsNotificationsErrorsSubtitle =>
      'जब कोई सत्र विफलता की रिपोर्ट करता है';

  @override
  String get settingsNotificationsJustClose => 'बस बंद करें';

  @override
  String get settingsNotificationsJustCloseDescription =>
      'एप्लिकेशन से पूरी तरह बाहर निकलें।';

  @override
  String get settingsNotificationsKeepLive => 'अलर्ट 3 मिनट तक लाइव रखें';

  @override
  String get settingsNotificationsKeepLiveDescription =>
      'जब कोई प्रतिक्रिया पहले से ही चल रही हो, तो ऐप छोड़ने के बाद थोड़ी देर के लिए रीयलटाइम सक्रिय रखें।';

  @override
  String get settingsNotificationsLocal => 'स्थानीय';

  @override
  String get settingsNotificationsMinimizeWhenClose =>
      'बंद करने पर न्यूनतम (minimize) करें';

  @override
  String get settingsNotificationsMinimizeWhenCloseDescription =>
      'टास्कबार/डॉक पर न्यूनतम करें और चलते रहें।';

  @override
  String get settingsNotificationsNoCondition =>
      'यदि कोई शर्त नहीं चुनी गई है, तो किसी भी संदर्भ में अलर्ट की अनुमति है।';

  @override
  String get settingsNotificationsNotify => 'अधिसूचित करें';

  @override
  String get settingsNotificationsNotifyOnlyWhen => 'केवल तब सूचित करें जब';

  @override
  String get settingsNotificationsOpenBatterySettings => 'बैटरी सेटिंग्स खोलें';

  @override
  String get settingsNotificationsPermissions => 'अनुमतियां और प्रश्न';

  @override
  String get settingsNotificationsPermissionsSubtitle =>
      'जब टूल आपके इनपुट का अनुरोध करते हैं';

  @override
  String get settingsNotificationsPreview => 'पूर्वावलोकन';

  @override
  String get settingsNotificationsRefreshStatus => 'स्थिति रीफ़्रेश करें';

  @override
  String get settingsNotificationsSearchSoundType => 'ध्वनि प्रकार खोजें';

  @override
  String get settingsNotificationsSectionDescription =>
      'नियंत्रित करें कि अलर्ट कब दिखाई दें और वे कब ध्वनि बजा सकें।';

  @override
  String get settingsNotificationsSectionTitle => 'सूचनाएं';

  @override
  String settingsNotificationsSelectedSound(String label) {
    return 'चयनित: $label';
  }

  @override
  String get settingsNotificationsServer => 'सर्वर';

  @override
  String get settingsNotificationsSound => 'ध्वनि';

  @override
  String get settingsNotificationsSoundBuiltInAlert => 'इन-बिल्ट अलर्ट';

  @override
  String get settingsNotificationsSoundBuiltInClick => 'इन-बिल्ट क्लिक';

  @override
  String get settingsNotificationsSoundOff => 'बंद';

  @override
  String get settingsNotificationsSoundOnlyWhen => 'केवल तब ध्वनि बजाएं जब';

  @override
  String get settingsNotificationsSoundPickAudioFile => 'ऑडियो फ़ाइल चुनें';

  @override
  String get settingsNotificationsSoundPickFromSystem => 'सिस्टम से चुनें';

  @override
  String get settingsNotificationsSoundSystemDefault => 'सिस्टम डिफ़ॉल्ट';

  @override
  String get settingsNotificationsSoundType => 'ध्वनि प्रकार';

  @override
  String get settingsNotificationsSyncInfo =>
      'कुछ श्रेणी ऑन/ऑफ़ टॉगल सक्रिय सर्वर पर /config से सिंक किए जाते हैं।';

  @override
  String get settingsNotificationsSyncInfoLocal =>
      'वर्तमान सर्वर /config में अधिसूचना टॉगल प्रदर्शित नहीं करता है; स्थानीय मान सक्रिय हैं।';

  @override
  String get settingsNotificationsSystemSoundPickerTitle =>
      'सिस्टम ध्वनि चुनें';

  @override
  String get settingsNotificationsTitle => 'सूचनाएं';

  @override
  String get settingsNotificationsWhenClosing => 'विंडो बंद करते समय';

  @override
  String get settingsOpenCodeAutoUpdate => 'OpenCode ऑटो-अपडेट';

  @override
  String get settingsOpenCodeSharingDefault => 'OpenCode शेयरिंग डिफ़ॉल्ट';

  @override
  String get settingsReadAloudEnabled => 'ज़ोर से पढ़ें';

  @override
  String get settingsReadAloudEnabledDescription =>
      'सहायक संदेशों पर एक ज़ोर से पढ़ने का बटन दिखाएं।';

  @override
  String get settingsReadAloudPitch => 'पिच';

  @override
  String get settingsReadAloudPitchDescription =>
      'आवाज की पिच को समायोजित करें।';

  @override
  String get settingsReadAloudSectionDescription =>
      'सहायक की प्रतिक्रियाओं को ज़ोर से पढ़ें। गति, पिच और आवाज़ को कॉन्फ़िगर करें।';

  @override
  String get settingsReadAloudSectionTitle => 'भाषण से पाठ';

  @override
  String get settingsReadAloudSpeed => 'गति';

  @override
  String get settingsReadAloudSpeedDescription =>
      'बोलने की गति को समायोजित करें।';

  @override
  String get settingsReadAloudVoice => 'आवाज';

  @override
  String get settingsReadAloudVoiceHint =>
      'ज़ोर से पढ़ने के लिए एक आवाज़ चुनें।';

  @override
  String get settingsSearchAutoUpdateMode => 'ऑटो-अपडेट मोड खोजें';

  @override
  String get settingsSearchDefaultAgent => 'डिफ़ॉल्ट एजेंट खोजें';

  @override
  String get settingsSearchDefaultModel => 'डिफ़ॉल्ट मॉडल खोजें';

  @override
  String get settingsSearchSharingMode => 'शेयरिंग मोड खोजें';

  @override
  String get settingsSearchSmallModel => 'छोटा मॉडल खोजें';

  @override
  String get settingsServersActive => 'सक्रिय';

  @override
  String get settingsServersChooseActive => 'सक्रिय सर्वर चुनें';

  @override
  String get settingsServersDefault => 'डिफ़ॉल्ट';

  @override
  String get settingsServersDescription =>
      'OpenCode से कनेक्ट करें और अपने सर्वर प्रबंधित करें';

  @override
  String get settingsServersTitle => 'सर्वर';

  @override
  String get settingsSessionAttentionSize => 'बबल का आकार';

  @override
  String get settingsSessionAttentionSizeExtraLarge => 'बहुत बड़ा';

  @override
  String get settingsSessionAttentionSizeExtraSmall => 'बहुत छोटा';

  @override
  String get settingsSessionAttentionSizeLarge => 'बड़ा';

  @override
  String get settingsSessionAttentionSizeSmall => 'छोटा';

  @override
  String get settingsSessionAttentionSizeStandard => 'मानक';

  @override
  String get settingsSetupWizard => 'सेटअप विज़ार्ड';

  @override
  String get settingsShortcutsDescription =>
      'कीबोर्ड शॉर्टकट खोजें और अनुकूलित करें';

  @override
  String get settingsShortcutsEdit => 'शॉर्टकट संपादित करें';

  @override
  String get settingsShortcutsKeyboard => 'कीबोर्ड शॉर्टकट';

  @override
  String get settingsShortcutsReset => 'शॉर्टकट रीसेट करें';

  @override
  String get settingsShortcutsSearch => 'शॉर्टकट खोजें';

  @override
  String get settingsShortcutsTitle => 'शॉर्टकट';

  @override
  String get settingsSmallModel => 'छोटा मॉडल';

  @override
  String get settingsSmallModelResetExplanation =>
      '`/config` पैच अपडेट कुंजियों को नहीं हटा सकते हैं, इसलिए `small_model` को स्वचालित फ़ालबैक पर रीसेट करने के लिए अभी भी ऐप के बाहर कॉन्फ़िगरेशन संपादित करने की आवश्यकता है।';

  @override
  String get settingsSmallModelUnsetExplanation =>
      'OpenCode स्वचालित फ़ालबैक सक्रिय है क्योंकि `small_model` सेट नहीं है।';

  @override
  String get settingsSoundPickerNotAvailable =>
      'सिस्टम ध्वनि चयनकर्ता इस प्लेटफॉर्म पर उपलब्ध नहीं है।';

  @override
  String get settingsSpeechDescription =>
      'वॉइस इनपुट, ऑफ़लाइन मॉडल और पढ़कर सुनाना सेट करें';

  @override
  String get settingsSpeechRefreshStatus => 'स्थिति रीफ़्रेश करें';

  @override
  String settingsSpeechSilenceTimeout(String value) {
    return 'मौन टाइमआउट: ${value}s';
  }

  @override
  String get settingsSpeechTitle => 'भाषण से पाठ';

  @override
  String get settingsTitle => 'सेटिंग्स';

  @override
  String get settingsGroupAlertTypes => 'अलर्ट प्रकार';

  @override
  String get settingsGroupBackgroundBehavior => 'पृष्ठभूमि व्यवहार';

  @override
  String get settingsGroupChatDisplay => 'चैट प्रदर्शन';

  @override
  String get settingsGroupCurrentConnection => 'वर्तमान कनेक्शन';

  @override
  String get settingsGroupDataAndSync => 'डेटा और सिंक';

  @override
  String get settingsGroupDataReset => 'डेटा और रीसेट';

  @override
  String get settingsGroupDelivery => 'डिलीवरी';

  @override
  String get settingsGroupHelp => 'सहायता';

  @override
  String get settingsGroupLanguageAndChat => 'भाषा और चैट';

  @override
  String get settingsGroupLayoutAndText => 'लेआउट और टेक्स्ट';

  @override
  String get settingsGroupOfflineModels => 'ऑफ़लाइन मॉडल';

  @override
  String get settingsGroupOpenCodeDefaults => 'OpenCode डिफ़ॉल्ट';

  @override
  String get settingsGroupReadAloud => 'पढ़कर सुनाना';

  @override
  String get settingsGroupSavedServers => 'सहेजे गए सर्वर';

  @override
  String get settingsGroupThemeAndColor => 'थीम और रंग';

  @override
  String get settingsGroupThisDevice => 'यह डिवाइस';

  @override
  String get settingsGroupVersionUpdates => 'संस्करण और अपडेट';

  @override
  String get settingsGroupVoiceInput => 'वॉइस इनपुट';

  @override
  String get settingsNavigationGroupExperience => 'अनुभव';

  @override
  String get settingsNavigationGroupInput => 'इनपुट';

  @override
  String get settingsNavigationGroupSetup => 'सेटअप';

  @override
  String get settingsNavigationGroupSupport => 'सहायता और डायग्नोस्टिक्स';

  @override
  String get settingsNavigationNoResults => 'कोई सेटिंग नहीं मिली';

  @override
  String get settingsNavigationSearchHint => 'सेटिंग खोजें';

  @override
  String get settingsUsernameClearHint =>
      'OpenCode बातचीत उपयोगकर्ता नाम को साफ़ करने के लिए अभी भी ऐप के बाहर कॉन्फ़िगरेशन को संपादित करने की आवश्यकता होती है।';

  @override
  String get settingsUsernameEnterHint =>
      'कस्टम OpenCode बातचीत नाम सहेजने के लिए उपयोगकर्ता नाम दर्ज करें।';

  @override
  String get settingsUsernameResetExplanation =>
      '`/config` पैच अपडेट कुंजियों को नहीं हटा सकते हैं, इसलिए `username` को सिस्टम डिफ़ॉल्ट पर रीसेट करने के लिए अभी भी ऐप के बाहर कॉन्फ़िगरेशन संपादित करने की आवश्यकता है।';

  @override
  String get settingsUsernameUnsetExplanation =>
      'OpenCode सिस्टम उपयोगकर्ता नाम का उपयोग करता है क्योंकि `username` सेट नहीं है।';

  @override
  String get setupDebugBun => 'Bun';

  @override
  String get setupDebugBun2 => 'Bun';

  @override
  String get setupDebugCapturedSetupDetails =>
      'अभी तक कोई कैप्चर किया गया सेटअप विवरण नहीं है';

  @override
  String get setupDebugCapturedSetupLogs => 'कैप्चर किए गए सेटअप लॉग';

  @override
  String get setupDebugClear => 'सेटअप डिबग साफ़ करें';

  @override
  String get setupDebugClearSetupDebug => 'सेटअप डिबग साफ़ करें';

  @override
  String get setupDebugCodeWalkCaptureEnough =>
      'यदि CodeWalk ने पर्याप्त संदर्भ कैप्चर नहीं किया है, तो सीधे आधिकारिक OpenCode लॉग और स्वास्थ्य एंडपॉइंट देखें:';

  @override
  String get setupDebugCommandPath => 'कमांड पथ';

  @override
  String get setupDebugCommandPath2 => 'कमांड पथ';

  @override
  String get setupDebugCopy => 'सेटअप डिबग कॉपी करें';

  @override
  String get setupDebugCopySetupDebug => 'सेटअप डिबग कॉपी करें';

  @override
  String get setupDebugCurrentStatus => 'वर्तमान स्थिति';

  @override
  String get setupDebugDiagnosticsLoading => 'निदान अभी लोड हो रहे हैं।';

  @override
  String get setupDebugEnvironment => 'पर्यावरण निदान';

  @override
  String get setupDebugEnvironmentDiagnostics => 'पर्यावरण निदान';

  @override
  String get setupDebugFocusedOpenCodeSetup =>
      'OpenCode  सेटअप पर ध्यान केंद्रित';

  @override
  String get setupDebugInstallDir => 'इंस्टॉल निर्देशिका';

  @override
  String get setupDebugInstallDirectory => 'इंस्टॉल निर्देशिका';

  @override
  String get setupDebugLatestLocalServer => 'नवीनतम स्थानीय सर्वर आउटपुट';

  @override
  String get setupDebugLogs => 'कैप्चर किए गए सेटअप लॉग';

  @override
  String get setupDebugManual => 'मैनुअल समस्या निवारण';

  @override
  String get setupDebugManualTroubleshooting => 'मैनुअल समस्या निवारण';

  @override
  String get setupDebugNetwork => 'नेटवर्क';

  @override
  String get setupDebugNetwork2 => 'नेटवर्क';

  @override
  String get setupDebugNoDetails =>
      'अभी तक कोई कैप्चर किया गया सेटअप विवरण नहीं है';

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
  String get setupDebugOpenCodeSetupDebug => 'OpenCode सेटअप डिबग';

  @override
  String get setupDebugPlatform => 'प्लेटफॉर्म';

  @override
  String get setupDebugPlatform2 => 'प्लेटफॉर्म';

  @override
  String get setupDebugRunDiagnosticsTry =>
      'यहाँ OpenCode-विशिष्ट समस्या निवारण विवरण कैप्चर करने के लिए निदान चलाएं, एक इंस्टॉलेशन विधि आज़माएं, या सेटअप प्रवाह का प्रयास करें।';

  @override
  String get setupDebugScreenCoversOpenCode =>
      'यह स्क्रीन केवल OpenCode इंस्टॉलेशन, निदान और स्थानीय सेटअप समस्या निवारण को कवर करती है। सामान्य CodeWalk रनटाइम समस्याओं के लिए ऐप लॉग का उपयोग करें।';

  @override
  String get setupDebugServerOutput => 'नवीनतम स्थानीय सर्वर आउटपुट';

  @override
  String get setupDebugStatus => 'वर्तमान स्थिति';

  @override
  String setupDebugTimeEntrySource(String source, String time) {
    return '$time - $source';
  }

  @override
  String get setupDebugTimeline => 'समयरेखा (Timeline)';

  @override
  String get setupDebugTimeline2 => 'समयरेखा (Timeline)';

  @override
  String get setupDebugTitle => 'OpenCode सेटअप पर ध्यान केंद्रित';

  @override
  String get setupDebugWSL => 'WSL';

  @override
  String get setupDebugWsl => 'WSL';

  @override
  String get shortcutCloseApp => 'टैब/ऐप्लिकेशन बंद करें';

  @override
  String get shortcutCloseAppDesc =>
      'वर्तमान सत्र टैब उपलब्ध हो तो उसे बंद करें; अन्यथा प्लेटफ़ॉर्म व्यवहार के अनुसार ऐप बंद करें';

  @override
  String get shortcutFocusCloseDrawer => 'दराज पर ध्यान केंद्रित करें/बंद करें';

  @override
  String get shortcutFocusCloseDrawerDesc =>
      'डिफ़ॉल्ट रूप से इनपुट पर ध्यान केंद्रित करें, या खुला होने पर दराज बंद करें';

  @override
  String get shortcutFocusInput => 'इनपुट पर ध्यान केंद्रित करें';

  @override
  String get shortcutFocusInputDesc => 'ध्यान टेक्स्ट इनपुट पर ले जाएं';

  @override
  String get shortcutGroupApplication => 'एप्लिकेशन';

  @override
  String get shortcutGroupGeneral => 'सामान्य';

  @override
  String get shortcutGroupModelAndAgent => 'मॉडल और एजेंट';

  @override
  String get shortcutGroupNavigation => 'नेविगेशन';

  @override
  String get shortcutGroupPrompt => 'प्रॉम्प्ट';

  @override
  String get shortcutGroupSession => 'सत्र';

  @override
  String get shortcutNewConversation => 'नई बातचीत';

  @override
  String get shortcutNewConversationDesc => 'एक नया चैट सत्र बनाएं';

  @override
  String get shortcutNextAgent => 'अगला एजेंट';

  @override
  String get shortcutNextAgentDesc => 'अगले उपलब्ध एजेंट पर जाएं';

  @override
  String get shortcutNextRecentModel => 'अगला हालिया मॉडल';

  @override
  String get shortcutNextRecentModelDesc =>
      'हाल ही में उपयोग किए गए मॉडल के बीच चक्र करें';

  @override
  String get shortcutNextVariant => 'अगला संस्करण';

  @override
  String get shortcutNextVariantDesc =>
      'उपलब्ध मॉडल संस्करणों के बीच चक्र करें';

  @override
  String get shortcutOpenSettings => 'सेटिंग्स खोलें';

  @override
  String get shortcutOpenSettingsDesc => 'सेटिंग्स पेज खोलें';

  @override
  String get shortcutPreviousAgent => 'पिछला एजेंट';

  @override
  String get shortcutPreviousAgentDesc => 'पिछले उपलब्ध एजेंट पर जाएं';

  @override
  String get shortcutQuickOpenFiles => 'फाइलें जल्दी खोलें';

  @override
  String get shortcutQuickOpenFilesDesc => 'फाइल त्वरित खोज खोलें';

  @override
  String get shortcutQuitApp => 'एप्लिकेशन से बाहर निकलें';

  @override
  String get shortcutQuitAppDesc => 'ऐप को जबरन बंद करें';

  @override
  String get shortcutRefreshData => 'डेटा रिफ्रेश करें';

  @override
  String get shortcutRefreshDataDesc => 'वर्तमान चैट डेटा रिफ्रेश करें';

  @override
  String get shortcutStopResponse => 'प्रतिक्रिया रोकें';

  @override
  String get shortcutStopResponseDesc =>
      'सक्रिय प्रतिक्रिया रोकें (प्रतिक्रिया देते समय)';

  @override
  String get shortcutToggleVoiceInput => 'आवाज इनपुट टॉगल करें';

  @override
  String get shortcutToggleVoiceInputDesc =>
      'संपादक में आवाज श्रुतलेख शुरू या बंद करें';

  @override
  String get shortcutsApply => 'लागू करें';

  @override
  String shortcutsConflictConflict(String conflict) {
    return '$conflict के साथ विरोध';
  }

  @override
  String get shortcutsKeyboardShortcuts => 'कीबोर्ड शॉर्टकट';

  @override
  String get shortcutsReset => 'सभी रीसेट करें';

  @override
  String get shortcutsSearchEditBindings =>
      'सहेजने से पहले बाइंडिंग खोजें, संपादित करें और संघर्षों (conflicts) को हल करें।';

  @override
  String shortcutsSetShortcutWidget(String label) {
    return 'शॉर्टकट सेट करें: $label';
  }

  @override
  String get shortcutsTheseBindingsStored =>
      'ये बाइंडिंग वर्तमान ऐप रनटाइम के लिए CodeWalk में संग्रहीत हैं और OpenCode `tui.json` की-बाइंड को संपादित नहीं करती हैं।';

  @override
  String get speechAutoStopSilence =>
      'स्वचालित रूप से रोकने के लिए मौन टाइमआउट';

  @override
  String get speechChooseRecognitionEngine =>
      'पहचान इंजन (recognition engine), मौन टाइमआउट और मॉडल विकल्प चुनें।';

  @override
  String speechDesktopOnly(String service) {
    return '$service केवल डेस्कटॉप पर उपलब्ध है।';
  }

  @override
  String get speechDownload => 'डाउनलोड';

  @override
  String get speechEngine => 'इंजन';

  @override
  String get speechInstalledLanguages => 'इंस्टॉल की गई भाषाएं';

  @override
  String get speechListeningStopsAutomatically =>
      'इतने सेकंड के मौन के बाद सुनना अपने आप बंद हो जाता है।';

  @override
  String get speechMicPermissionDisabled => 'माइक्रोफ़ोन अनुमति अक्षम है।';

  @override
  String speechModelFilesIncomplete(String service) {
    return '$service मॉडल फ़ाइलें अपूर्ण हैं।';
  }

  @override
  String get speechMoonshine => 'Moonshine';

  @override
  String get speechMoonshineModelsDesktop => 'Moonshine मॉडल (डेस्कटॉप)';

  @override
  String get speechMoonshineStaysDownloadable =>
      'Moonshine डाउनलोड करने योग्य रहता है और ऐप बंडल से बाहर रहता. इस डेस्कटॉप डिवाइस के लिए एक मॉडल चुनें और यदि आप स्थान वापस चाहते हैं तो इसे बाद में हटा दें।';

  @override
  String get speechNative => 'मूल (Native)';

  @override
  String get speechNativeSTTDisabled =>
      'इस ऐप में लिनक्स पर नेटिव STT अक्षम है। नए इंस्टॉलेशन के लिए Parakeet डिफ़ॉल्ट इंजन है।';

  @override
  String get speechNativeSTTWorks =>
      'Windows पर, CodeWalk अपने WASAPI माइक्रोफ़ोन बैकएंड के माध्यम से स्थानीय ऑन-डिवाइस भाषण पहचान का उपयोग करता है। स्थिरता के लिए नेटिव Windows भाषण पहचान अक्षम है।';

  @override
  String get speechNativeStartsFaster =>
      'नेटिव तेज़ी से शुरू होता है। Sherpa भारी सेटअप और गहरे मॉडल नियंत्रण के साथ पूरी तरह से डिवाइस पर चलता है।';

  @override
  String get speechOpenMicrophoneSettings => 'माइक्रोफ़ोन सेटिंग्स खोलें';

  @override
  String get speechOpenSpeechPrivacy => 'भाषण गोपनीयता सेटिंग्स खोलें';

  @override
  String get speechOpenSpeechSettings => 'भाषण सेटिंग्स खोलें';

  @override
  String get speechParakeet => 'Parakeet';

  @override
  String get speechParakeetModelsDesktop => 'Parakeet मॉडल (डेस्कटॉप)';

  @override
  String get speechParakeetStaysDownloadable =>
      'Parakeet डाउनलोड करने योग्य रहता है और ऐप बंडल से बाहर रहता है। यह वर्तमान में 25 यूरोपीय भाषाओं के लिए अनुकूलित एक बहुभाषी मॉडल प्रदर्शित करता।';

  @override
  String get speechPickLanguagePacks =>
      'डिवाइस पर पहचान के लिए भाषा पैक चुनें और मॉडल डाउनलोड/हटाएं।';

  @override
  String get speechRemove => 'हटाएं';

  @override
  String speechRuntimeFailed(String service) {
    return '$service रनटाइम शुरू होने में विफल रहा।';
  }

  @override
  String get speechSelectSherpaAbove =>
      'भाषा पैक प्रबंधित करने और मॉडल डाउनलोड करने के लिए ऊपर Sherpa का चयन करें।';

  @override
  String get speechSenseVoice => 'SenseVoice';

  @override
  String get speechSenseVoiceModelsDesktop => 'SenseVoice मॉडल (डेस्कटॉप)';

  @override
  String get speechSenseVoiceStaysDownloadable =>
      'SenseVoice डाउनलोड करने योग्य रहता है और ऐप बंडल से बाहर रहता है। यह चीनी, कैंटोनीज़, जापानी, कोरियाई और अंग्रेजी के लिए यहाँ सबसे मजबूत डेस्कटॉप विकल्प है।';

  @override
  String get speechSherpa => 'Sherpa';

  @override
  String get speechSherpaExperimentalFail =>
      'Sherpa प्रायोगिक है और कुछ उपकरणों पर विफल हो सकता है। यदि आप सबसे स्थिर व्यवहार चाहते हैं तो मूल (Native) को प्राथमिकता दें।';

  @override
  String get speechSherpaModelsLinux => 'Sherpa मॉडल (Linux)';

  @override
  String get speechSpeechText => 'भाषण से पाठ';

  @override
  String speechUnavailableOnPlatform(String service) {
    return 'इस प्लेटफॉर्म पर $service स्पीच उपलब्ध नहीं है।';
  }

  @override
  String get speechWindowsSetupHint =>
      'Windows आवाज़ इनपुट ऑन-डिवाइस मॉडल के साथ CodeWalk WASAPI कैप्चर का उपयोग करता है। डेस्कटॉप ऐप्स के लिए माइक्रोफ़ोन एक्सेस सक्षम रखें; नीचे दिए गए बटन समस्या निवारण के लिए Windows सेटिंग्स खोलते हैं।';

  @override
  String get statusConnected => 'कनेक्टेड';

  @override
  String get statusDelayed => 'विलंबित';

  @override
  String get statusFailed => 'विफल';

  @override
  String get statusOffline => 'ऑफ़लाइन';

  @override
  String get statusOnline => 'ऑनलाइन';

  @override
  String get statusReconnecting => 'पुनः कनेक्ट हो रहा है';

  @override
  String get statusStarting => 'शुरू हो रहा है';

  @override
  String get statusStopped => 'रुका हुआ';

  @override
  String get statusStopping => 'रुक रहा है';

  @override
  String get statusSyncDelayed => 'सिंक विलंबित';

  @override
  String get tailscaleNoPeers => 'कोई पीयर नहीं मिला';

  @override
  String get tailscaleNotSupportedOnPlatform =>
      'इस प्लेटफॉर्म पर Tailscale समर्थित नहीं है।';

  @override
  String get tailscaleNotSupportedOnWindows =>
      'Windows पर Tailscale समर्थित नहीं है।';

  @override
  String get tailscalePeerOffline => 'ऑफ़लाइन';

  @override
  String get tailscaleSelectPeer => 'एक Tailscale पीयर चुनें';

  @override
  String get tailscaleWaitingAdminApproval =>
      'यह Tailscale नोड एडमिन की मंजूरी का इंतज़ार कर रहा है।';

  @override
  String get terminalClose => 'टर्मिनल बंद करें';

  @override
  String terminalConnectingTo(String serverName) {
    return '$serverName टर्मिनल से जुड़ रहा है...';
  }

  @override
  String terminalConnectionFailed(String error) {
    return 'टर्मिनल कनेक्शन विफल रहा: $error';
  }

  @override
  String get terminalDisconnected => 'टर्मिनल डिस्कनेक्ट हो गया।';

  @override
  String terminalEmbeddedUnavailable(String serverName) {
    return 'एम्बेडेड टर्मिनल अभी इस रनटाइम पर उपलब्ध नहीं है। एक-बार के कमांड के लिए कंपोज़र शेल मोड का उपयोग जारी रखें या $serverName के लिए समर्थित CodeWalk ऐप रनटाइम से टर्मिनल खोलें।';
  }

  @override
  String get terminalExtraKeyAlt => 'Alt कुंजी';

  @override
  String get terminalExtraKeyArrowDown => 'नीचे तीर';

  @override
  String get terminalExtraKeyArrowLeft => 'बायां तीर';

  @override
  String get terminalExtraKeyArrowRight => 'दायां तीर';

  @override
  String get terminalExtraKeyArrowUp => 'ऊपर तीर';

  @override
  String get terminalExtraKeyControl => 'Control कुंजी';

  @override
  String get terminalExtraKeyEscape => 'Escape कुंजी';

  @override
  String get terminalExtraKeyTab => 'Tab कुंजी';

  @override
  String get terminalExtraKeys => 'टर्मिनल की अतिरिक्त कुंजियां';

  @override
  String get terminalHide => 'टर्मिनल छिपाएं';

  @override
  String get terminalMaximize => 'अधिकतम करें';

  @override
  String get terminalMinimize => 'टर्मिनल न्यूनतम करें';

  @override
  String get terminalNotAvailableYet =>
      'इस रनटाइम पर एम्बेडेड टर्मिनल अभी उपलब्ध नहीं है।';

  @override
  String get terminalOpen => 'टर्मिनल खोलें';

  @override
  String get terminalOpenInfo => 'टर्मिनल जानकारी खोलें';

  @override
  String get terminalOpenProjectFirst =>
      'सर्वर टर्मिनल शुरू करने से पहले एक प्रोजेक्ट फ़ोल्डर खोलें।';

  @override
  String get terminalOpenToConnect =>
      'सर्वर प्रोजेक्ट टर्मिनल से जुड़ने के लिए टर्मिनल खोलें।';

  @override
  String get terminalReconnect => 'टर्मिनल को दोबारा कनेक्ट करें';

  @override
  String get terminalRestoreSize => 'आकार पुनर्स्थापित करें';

  @override
  String get terminalSelectServer =>
      'टर्मिनल खोलने से पहले एक सक्रिय सर्वर चुनें।';

  @override
  String get terminalSessionClosed => 'टर्मिनल सत्र बंद हो गया।';

  @override
  String get terminalTerminal => 'टर्मिनल';

  @override
  String get terminalTitle => 'टर्मिनल';

  @override
  String get terminalTryAgain => 'फिर प्रयास करें';

  @override
  String get toolAwaitingInput => 'इनपुट की प्रतीक्षा है';

  @override
  String get toolEditing => 'संपादित किया जा रहा है';

  @override
  String get toolEditingFiles => 'फ़ाइलें संपादित की जा रही हैं';

  @override
  String get toolFinding => 'खोजा जा रहा है';

  @override
  String get toolFindingFiles => 'फ़ाइलें खोजी जा रही हैं';

  @override
  String get toolPresentationAwaitingInput => 'इनपुट की प्रतीक्षा है';

  @override
  String get toolPresentationEditing => 'संपादित किया जा रहा है';

  @override
  String get toolPresentationEditingFiles => 'फ़ाइलें संपादित की जा रही हैं';

  @override
  String get toolPresentationFinding => 'खोजा जा रहा है';

  @override
  String get toolPresentationFindingFiles => 'फ़ाइलें खोजी जा रही हैं';

  @override
  String get toolPresentationReading => 'पढ़ा जा रहा है';

  @override
  String get toolPresentationReadingFile => 'फ़ाइल पढ़ी जा रही है';

  @override
  String get toolPresentationRunning => 'चल रहा है';

  @override
  String get toolPresentationRunningCommand => 'कमांड चलाया जा रहा है';

  @override
  String toolPresentationRunningTool(String toolName) {
    return '$toolName चल रहा है';
  }

  @override
  String get toolPresentationSearching => 'खोज की जा रही है';

  @override
  String get toolPresentationSearchingCode => 'कोड खोजा जा रहा है';

  @override
  String get toolPresentationSearchingWeb => 'वेब पर खोज की जा रही है';

  @override
  String get toolPresentationTool => 'उपकरण';

  @override
  String get toolPresentationUpdatingTaskList =>
      'कार्य सूची अपडेट की जा रही है';

  @override
  String get toolPresentationUpdatingTasks => 'कार्यों को अपडेट किया जा रहा है';

  @override
  String get toolPresentationWaitingInput =>
      'आपके इनपुट की प्रतीक्षा की जा रही है';

  @override
  String get toolPresentationWriting => 'लिखा जा रहा है';

  @override
  String get toolPresentationWritingFile => 'फ़ाइल लिखी जा रही है';

  @override
  String get toolReading => 'पढ़ा जा रहा है';

  @override
  String get toolReadingFile => 'फ़ाइल पढ़ी जा रही है';

  @override
  String get toolRunning => 'चल रहा है';

  @override
  String get toolRunningCommand => 'कमांड चलाया जा रहा है';

  @override
  String get toolRunningTask => 'कार्य चलाया जा रहा है';

  @override
  String get toolSearching => 'खोज की जा रही है';

  @override
  String get toolSearchingCode => 'कोड खोजा जा रहा है';

  @override
  String get toolSearchingWeb => 'वेब पर खोज की जा रही है';

  @override
  String get toolUpdatingTaskList => 'कार्य सूची अपडेट की जा रही है';

  @override
  String get toolUpdatingTasks => 'कार्यों को अपडेट किया जा रहा है';

  @override
  String get toolWaitingForInput => 'आपके इनपुट की प्रतीक्षा की जा रही है';

  @override
  String get toolWriting => 'लिखा जा रहा है';

  @override
  String get toolWritingFile => 'फ़ाइल लिखी जा रही है';

  @override
  String get tourBack => 'पीछे';

  @override
  String get tourSkip => 'छोड़ें';

  @override
  String get trayQuit => 'बाहर निकलें';

  @override
  String get trayShow => 'दिखाएं';

  @override
  String get useOAuthCloudflareAccess =>
      'OAuth का उपयोग करें (Cloudflare Access)';

  @override
  String get useOAuthCloudflareAccessSubtitle =>
      'Cloudflare Access प्रबंधित OAuth के लिए ब्राउज़र खोलता है।';

  @override
  String get useOAuthCloudflareAccessUnsupported =>
      'इस प्लेटफ़ॉर्म पर Cloudflare Access OAuth उपलब्ध नहीं है। इसके बजाय बेसिक ऑथ (Basic Auth) का उपयोग करें।';

  @override
  String get useTailscale => 'Tailscale का उपयोग करें';

  @override
  String get useTailscaleSubtitle =>
      'सिस्टम VPN के बिना Tailscale नेटवर्क के माध्यम से ट्रैफ़िक को निर्देशित करता है।';

  @override
  String get useTailscaleUnsupported =>
      'इस प्लेटफ़ॉर्म पर Tailscale समर्थित नहीं है।';

  @override
  String get utilityTitle => 'उपयोगिता';

  @override
  String get workspaceBrowseDirs => 'निर्देशिकाएं ब्राउज़ करें';

  @override
  String get workspaceChooseFolderOpen =>
      'परियोजना संदर्भ के रूप में खोलने के लिए कोई भी फ़ोल्डर चुनें।';

  @override
  String workspaceCloseProject(String project) {
    return '$project बंद करें';
  }

  @override
  String get workspaceClosedProjects => 'बंद परियोजनाएँ';

  @override
  String workspaceCurrentDirectory(String path) {
    return 'वर्तमान निर्देशिका: $path';
  }

  @override
  String get workspaceFilterDirs => 'निर्देशिकाएं फ़िल्टर करें';

  @override
  String get workspaceOpenFolder => 'फ़ोल्डर खोलें';

  @override
  String get workspaceOpenProjectFolder => 'परियोजना फ़ोल्डर खोलें';

  @override
  String get workspaceOpenProjects => 'खुली परियोजनाएँ';

  @override
  String get workspaceProjectDirectory =>
      'परियोजना निर्देशिका (Project directory)';

  @override
  String get workspaceProjectHint => '/repo/my-project';

  @override
  String workspaceRemoveFromHistory(String name) {
    return 'इतिहास से $name निकालें';
  }

  @override
  String get settingsSessionAttentionTitle => 'सत्र ध्यान';

  @override
  String get settingsSessionAttentionDescription =>
      'रूट सत्र की स्थिति को वैकल्पिक बबल या पैनल में दिखाता है।';

  @override
  String get settingsSessionAttentionOff => 'बंद';

  @override
  String get settingsSessionAttentionBubble => 'बबल';

  @override
  String get settingsSessionAttentionPanel => 'पैनल';

  @override
  String get settingsSessionAttentionPrivacy =>
      'Android पर इसे चालू करने से स्थायी फ़ोरग्राउंड सेवा शुरू होती है। उत्तर का पाठ एन्क्रिप्ट होकर सहेजा जाता है; क्लाउड TTS पाठ केवल पढ़ें दबाने के बाद भेजता है।';

  @override
  String get settingsSessionAttentionUnavailable =>
      'इस प्लेटफ़ॉर्म पर सत्र ध्यान उपलब्ध नहीं है।';

  @override
  String get settingsSessionAttentionOpenSettings => 'डिस्प्ले सेटिंग खोलें';

  @override
  String get settingsSessionAttentionStop => 'सत्र ध्यान रोकें';

  @override
  String get settingsSessionAttentionThirdPartyTtsWarning =>
      'पढ़ें दबाने पर उत्तर का पाठ कॉन्फ़िगर किए गए तृतीय-पक्ष TTS प्रदाता को भेजा जा सकता है।';

  @override
  String get workspaceSuggestions => 'सुझाव';

  @override
  String get sessionTabsGestureHintTitle => 'सत्र टैब में नए नियंत्रण हैं';

  @override
  String get sessionTabsGestureHintBody =>
      'किसी टैब को बंद करने के लिए उस पर डबल-क्लिक या डबल-टैप करें। सत्र क्रियाएं खोलने के लिए राइट-क्लिक करें या टच और होल्ड करें। आप डिस्प्ले टॉगल (Display Toggles) में टैब अक्षम कर सकते हैं।';

  @override
  String get sessionTabsGestureHintAcknowledge => 'ठीक है';

  @override
  String get sessionTabsGestureHintDisableTabs => 'टैब अक्षम करें';

  @override
  String get sessionTabRenameAction => 'सत्र का नाम बदलें';

  @override
  String sessionTabClosedMessage(String title) {
    return 'टैब \"$title\" बंद हुआ';
  }

  @override
  String get sessionTabUndo => 'पूर्ववत करें';

  @override
  String get sessionTabRestoreFailed => 'टैब पुनर्स्थापित नहीं किया जा सका।';

  @override
  String get sessionTabChangeIconAction => 'आइकन बदलें';

  @override
  String get sessionTabIconPickerTitle => 'टैब आइकन चुनें';

  @override
  String get sessionTabIconUseProjectIcon => 'प्रोजेक्ट आइकन का उपयोग करें';

  @override
  String get sessionTabIconApplied => 'टैब आइकन अपडेट हो गया।';

  @override
  String get sessionTabIconSaveFailed => 'टैब आइकन सहेजा नहीं जा सका।';

  @override
  String get sessionTabIconPresetCode => 'कोड';

  @override
  String get sessionTabIconPresetTerminal => 'टर्मिनल';

  @override
  String get sessionTabIconPresetBug => 'बग';

  @override
  String get sessionTabIconPresetTasks => 'कार्य';

  @override
  String get sessionTabIconPresetLaunch => 'लॉन्च';

  @override
  String get sessionTabIconPresetIdea => 'विचार';

  @override
  String get sessionTabIconPresetResearch => 'शोध';

  @override
  String get sessionTabIconPresetDesign => 'डिज़ाइन';

  @override
  String get sessionTabIconPresetData => 'डेटा';

  @override
  String get sessionTabIconPresetCloud => 'क्लाउड';

  @override
  String get sessionTabIconPresetSecurity => 'सुरक्षा';

  @override
  String get sessionTabIconPresetTools => 'टूल्स';

  @override
  String get workspaceNoActiveContext => 'कोई सक्रिय संदर्भ नहीं';

  @override
  String get settingsAppearanceContrastLow => 'कम';

  @override
  String get settingsAppearanceContrastStandard => 'मानक';

  @override
  String get settingsAppearanceContrastMedium => 'मध्यम';

  @override
  String get settingsAppearanceContrastMediumHigh => 'मध्यम उच्च';

  @override
  String get settingsNotificationsSystemSoundsWebUnavailable =>
      'वेब पर उपलब्ध नहीं।';

  @override
  String get settingsNotificationsSystemSoundsAndroid =>
      'सिस्टम से Android सूचना ध्वनियाँ।';

  @override
  String get settingsNotificationsSystemSoundsFreedesktop =>
      'Freedesktop ध्वनियाँ /usr/share/sounds/freedesktop/stereo से।';

  @override
  String get settingsNotificationsSystemSoundsPlatform =>
      'जहाँ ऑपरेटिंग सिस्टम सिस्टम ध्वनियाँ उपलब्ध कराता है, वहाँ समर्थित।';

  @override
  String get serversQuickGuideTitle => 'त्वरित सेटअप';

  @override
  String get serversQuickGuideIntro =>
      'CodeWalk ऐप है। OpenCode इंजन है, जिसे इस कनेक्शन के काम करने से पहले चालू होना आवश्यक है।';

  @override
  String get serversQuickGuideStepInstallCli => '1. OpenCode CLI स्थापित करें।';

  @override
  String get serversQuickGuideRunPowerShell => '2. PowerShell में चलाएँ:';

  @override
  String get serversQuickGuideRunTerminal => '2. अपने टर्मिनल में चलाएँ:';

  @override
  String get serversQuickGuideProtectPassword =>
      'पासवर्ड से एक्सेस सुरक्षित करें';

  @override
  String get serversQuickGuideServerPassword => 'सर्वर पासवर्ड';

  @override
  String get serversQuickGuideInstallOptions =>
      'अन्य आधिकारिक स्थापना विकल्प: इंस्टॉल स्क्रिप्ट, npm, bun, pnpm, Homebrew, या GitHub Releases से बाइनरी।';

  @override
  String get serversQuickGuideVerifyHint =>
      'सर्वर शुरू करने के बाद, CodeWalk में URL पेस्ट करने से पहले /global/health या /doc के प्रतिक्रिया देने की पुष्टि करें।';

  @override
  String get shortcutsPressKeyCombination => 'अब की-कॉम्बिनेशन दबाएँ';

  @override
  String get settingsProvenanceOpenCodeBacked => 'OpenCode-समर्थित';

  @override
  String get settingsProvenanceCodeWalkLocal => 'CodeWalk-स्थानीय';

  @override
  String get settingsProvenanceCodeWalkException => 'CodeWalk अपवाद';

  @override
  String get shortcutsErrorInvalid => 'अमान्य शॉर्टकट';

  @override
  String get shortcutsErrorUnsupportedKey => 'असमर्थित शॉर्टकट कुंजी';

  @override
  String shortcutsErrorConflict(String conflict) {
    return '\"$conflict\" से टकराता है';
  }

  @override
  String get settingsSessionAttentionStopSaveFailed =>
      'सत्र ध्यान रोका गया लेकिन सेटिंग सहेजी नहीं जा सकी।';

  @override
  String get settingsSessionAttentionEnableFailed =>
      'सत्र ध्यान सक्षम नहीं किया जा सका।';

  @override
  String get settingsSessionAttentionSaveFailedStopped =>
      'सत्र ध्यान सहेजा नहीं जा सका और इसे रोक दिया गया।';

  @override
  String get settingsSessionAttentionStillRunning =>
      'सत्र ध्यान अभी भी चल रहा है। इसे फिर से रोकने का प्रयास करें।';

  @override
  String get settingsSessionAttentionStopFailed =>
      'सत्र ध्यान रोका नहीं जा सका। फिर से प्रयास करें।';

  @override
  String get settingsSessionAttentionCapabilityUnavailable =>
      'सत्र ध्यान की होस्ट क्षमता उपलब्ध नहीं है।';

  @override
  String get settingsServerFallbackProviderName =>
      'सर्वर पर कॉन्फ़िगर किया गया';

  @override
  String get composerStopResponse => 'प्रतिक्रिया रोकें';

  @override
  String get composerSendMessageWhileResponding =>
      'प्रतिक्रिया चलने के दौरान संदेश भेजें';

  @override
  String get composerSendMessage => 'संदेश भेजें';

  @override
  String get chatTourComposerDescription => 'अपना अनुरोध यहाँ लिखें।';

  @override
  String get chatTourSendDescription => 'अपना संदेश यहाँ भेजें।';

  @override
  String get composerAttachmentFallbackName => 'अनुलग्नक';

  @override
  String get composerContextFallbackName => 'संदर्भ';

  @override
  String get searchableDropdownSearchHint => 'खोजें';

  @override
  String get searchableDropdownEmptyText => 'कोई मेल नहीं मिला';

  @override
  String get speechApiKeyStorageUnavailable =>
      'सुरक्षित TTS API कुंजी संग्रहण उपलब्ध नहीं है।';

  @override
  String get speechApiKeyRemoved => 'API कुंजी हटाई गई।';

  @override
  String get speechApiKeySaved =>
      'API कुंजी इस डिवाइस पर सुरक्षित रूप से सहेजी गई।';

  @override
  String get speechReadAloudTestText =>
      'यह एक CodeWalk टेक्स्ट-टू-स्पीच परीक्षण है।';

  @override
  String get speechNativeDisabledWindows =>
      'स्थिरता के लिए Windows पर अक्षम। CodeWalk WASAPI कैप्चर के माध्यम से Parakeet या कोई अन्य ऑन-डिवाइस इंजन उपयोग करें।';

  @override
  String get speechNativeUnavailableLinux =>
      'Linux पर अनुपलब्ध। भाषण इनपुट के लिए Parakeet का उपयोग करें।';

  @override
  String get speechNotAvailableOnPlatform => 'इस प्लेटफॉर्म पर उपलब्ध नहीं।';

  @override
  String get speechSherpaUnavailableAndroid =>
      'छोटे APK आकार के लिए अनुकूलित Android बिल्ड पर अनुपलब्ध।';

  @override
  String get speechMoonshineDesktopOnlyHint =>
      'केवल डेस्कटॉप पर उपलब्ध। Android केवल नेटिव रहता है।';

  @override
  String get speechParakeetDesktopOnlyHint =>
      'केवल डेस्कटॉप पर उपलब्ध। ऑफ़लाइन बहुभाषी पहचान का उपयोग करता है।';

  @override
  String get speechSenseVoiceDesktopOnlyHint =>
      'केवल डेस्कटॉप पर उपलब्ध। चीनी, कैंटोनीज़, जापानी, कोरियाई और अंग्रेज़ी के लिए सबसे मजबूत।';

  @override
  String get speechNativeSubtitle => 'सरल और तेज़ स्टार्टअप।';

  @override
  String get speechSherpaSubtitle =>
      'भारी, प्रायोगिक और बग-प्रवण। डाउनलोड किए गए मॉडल के साथ अक्सर अधिक सटीक।';

  @override
  String get speechMoonshineSubtitle =>
      'sherpa_onnx ऑफ़लाइन पहचान और डाउनलोड करने योग्य मॉडल का उपयोग करने वाला केवल-डेस्कटॉप प्रायोगिक पथ।';

  @override
  String get speechParakeetSubtitle =>
      'एक बहुभाषी डाउनलोड करने योग्य मॉडल के साथ केवल-डेस्कटॉप ऑफ़लाइन NeMo ट्रांसड्यूसर पथ।';

  @override
  String get speechSenseVoiceSubtitle =>
      'चीनी, कैंटोनीज़, जापानी, कोरियाई और अंग्रेज़ी के लिए अनुकूलित केवल-डेस्कटॉप ऑफ़लाइन पथ।';

  @override
  String get speechMoonshineModel => 'Moonshine मॉडल';

  @override
  String get speechSherpaLanguage => 'Sherpa भाषा';

  @override
  String get speechSearchSherpaLanguage => 'Sherpa भाषा खोजें';

  @override
  String get speechNoLanguagePacksFound => 'कोई भाषा पैक नहीं मिला';

  @override
  String get speechTextToSpeechProvider => 'टेक्स्ट-टू-स्पीच प्रदाता';

  @override
  String get speechProviderSystemNative => 'सिस्टम / नेटिव';

  @override
  String get speechProviderEdgeExperimental =>
      'Microsoft Edge Speech (प्रायोगिक)';

  @override
  String get speechProviderOpenAiCompatible => 'OpenAI-संगत';

  @override
  String get speechProviderElevenLabs => 'ElevenLabs';

  @override
  String get speechProviderNvidiaNim => 'NVIDIA NIM';

  @override
  String get speechNimSpeedNotSupported =>
      'गति NVIDIA NIM TTS द्वारा समर्थित नहीं है और इस प्रदाता के लिए छिपी हुई है।';

  @override
  String get speechRemoteVoice => 'आवाज़';

  @override
  String get speechRemoteVoiceUnavailable =>
      'चयनित आवाज़ प्रदाता की सूची में अब उपलब्ध नहीं है।';

  @override
  String get speechRemoteVoiceListUnavailable =>
      'डिफ़ॉल्ट आवाज़ का उपयोग हो रहा है। आवाज़ों की सूची अभी लोड नहीं की जा सकी।';

  @override
  String get speechRemoteVoicesLoaded => 'प्रदाता की आवाज़ों से लोड किया गया।';

  @override
  String get speechRemoteModel => 'मॉडल';

  @override
  String get speechRemoteModelListUnavailable =>
      'मॉडल सूची अभी लोड नहीं की जा सकी। आप नीचे कस्टम मॉडल टाइप कर सकते हैं।';

  @override
  String get speechRemoteModelsLoaded => 'प्रदाता के मॉडल से लोड किया गया।';

  @override
  String get speechRemoteModelUnavailable =>
      'चयनित मॉडल प्रदाता की सूची में अब उपलब्ध नहीं है।';

  @override
  String get speechCustomModel => 'कस्टम मॉडल…';

  @override
  String get speechEdgeExperimentalTitle =>
      'Microsoft Edge Speech प्रायोगिक है';

  @override
  String get speechEdgeExperimentalDescription =>
      'इस डिवाइस से सीधे अनाधिकारिक Edge Read Aloud सेवा का उपयोग करता है। जब आप रीड अलाउड का उपयोग करते हैं तो संदेश टेक्स्ट Microsoft को भेजा जाता है, और यदि Microsoft निजी प्रोटोकॉल बदलता है तो सेवा टूट सकती है।';

  @override
  String get speechEdgeVoice => 'Edge आवाज़';

  @override
  String get speechEdgeVoiceUnavailable =>
      'चयनित आवाज़ अब उपलब्ध नहीं है। डिफ़ॉल्ट Edge आवाज़ का उपयोग किया जा रहा है।';

  @override
  String get speechEdgeVoiceListUnavailable =>
      'डिफ़ॉल्ट Edge आवाज़ का उपयोग किया जा रहा है। आवाज़ सूची अभी लोड नहीं की जा सकी।';

  @override
  String get speechEdgeVoicesLoaded =>
      'Microsoft Edge Speech आवाज़ों से लोड किया गया।';

  @override
  String get speechCloudTtsPrivacy => 'क्लाउड TTS गोपनीयता';

  @override
  String get speechCloudTtsPrivacyDescription =>
      'क्लाउड TTS चयनित असिस्टेंट संदेश टेक्स्ट कॉन्फ़िगर किए गए प्रदाता को भेजता है। API कुंजियाँ इस डिवाइस पर सुरक्षित संग्रहण में रखी जाती हैं।';

  @override
  String get speechBaseUrl => 'बेस URL';

  @override
  String get speechApiKey => 'API कुंजी';

  @override
  String get speechApiKeySavedHelper =>
      'एक कुंजी सहेजी गई है। बदलने के लिए नया मान दर्ज करें, या हटाने के लिए खाली मान सहेजें।';

  @override
  String get speechNoApiKeySaved => 'कोई API कुंजी सहेजी नहीं गई।';

  @override
  String get speechSaveApiKey => 'API कुंजी सहेजें';

  @override
  String get speechModel => 'मॉडल';

  @override
  String get speechPitchNotSupported =>
      'पिच OpenAI-संगत TTS द्वारा समर्थित नहीं है और इस प्रदाता के लिए छिपाई गई है।';

  @override
  String get speechPitchHiddenForProvider =>
      'पिच इस TTS प्रदाता द्वारा समर्थित नहीं है और छिपी हुई है।';

  @override
  String get speechTestVoice => 'आवाज़ का परीक्षण करें';

  @override
  String get speechReadAloudTestPhraseLabel => 'आवाज़ परीक्षण वाक्य';

  @override
  String get speechReadAloudTestPhraseHint =>
      'खाली छोड़ने पर डिफ़ॉल्ट परीक्षण वाक्य उपयोग होगा।';

  @override
  String get dialogMoonshineVoiceSetupDescription =>
      'Moonshine sherpa_onnx के माध्यम से डिवाइस पर चलता है। एक बार मॉडल चुनें और इसे केवल इस डेस्कटॉप डिवाइस के लिए डाउनलोड करें।';

  @override
  String get dialogParakeetVoiceSetupDescription =>
      'Parakeet sherpa_onnx ऑफ़लाइन पहचान के माध्यम से डिवाइस पर चलता है। बहुभाषी STT सक्षम करने के लिए इसे इस डेस्कटॉप डिवाइस के लिए एक बार डाउनलोड करें।';

  @override
  String get dialogSenseVoiceSetupDescription =>
      'SenseVoice sherpa_onnx ऑफ़लाइन पहचान के माध्यम से डिवाइस पर चलता है। यह चीनी, कैंटोनीज़, जापानी, कोरियाई और अंग्रेज़ी के लिए सबसे मजबूत है।';

  @override
  String get dialogSherpaVoiceSetupDescription =>
      'Sherpa आवाज़ इनपुट के लिए ऑन-डिवाइस भाषण मॉडल आवश्यक है। अपनी भाषा चुनें और इसे एक बार डाउनलोड करें (~147 MB)।';

  @override
  String speechSilenceSeconds(String value) {
    return '$value सेकंड';
  }

  @override
  String speechModelInstalled(String modelId) {
    return 'मॉडल स्थापित ($modelId)';
  }

  @override
  String speechModelMissing(String modelId) {
    return 'मॉडल अनुपलब्ध ($modelId)';
  }

  @override
  String speechModelSizeMb(String sizeMb) {
    return '~$sizeMb MB';
  }

  @override
  String speechSystemDefaultLanguage(String language) {
    return 'सिस्टम डिफ़ॉल्ट ($language)';
  }

  @override
  String speechModelListLoadFailed(String error, String service) {
    return '$service मॉडल सूची लोड करने में विफल: $error';
  }

  @override
  String speechDownloadFailed(String error) {
    return 'डाउनलोड विफल: $error';
  }

  @override
  String speechFailedToRemoveModel(String error) {
    return 'मॉडल हटाने में विफल: $error';
  }

  @override
  String speechBaseUrlExample(String url) {
    return 'उदाहरण: $url';
  }

  @override
  String speechModelDefaultHelper(String model) {
    return 'डिफ़ॉल्ट: $model';
  }

  @override
  String get notificationPermissionOrQuestionNeedsInput =>
      'किसी टूल अनुमति या प्रश्न के लिए आपके इनपुट की आवश्यकता है।';

  @override
  String get notificationPermissionNeedsInput =>
      'किसी टूल अनुमति के लिए आपके इनपुट की आवश्यकता है।';

  @override
  String get notificationQuestionNeedsInput =>
      'किसी टूल प्रश्न के लिए आपके इनपुट की आवश्यकता है।';

  @override
  String get notificationSessionError => 'एक सत्र ने त्रुटि की सूचना दी।';

  @override
  String get notificationChannelErrors => 'CodeWalk त्रुटियाँ';

  @override
  String get notificationChannelErrorsDescription => 'CodeWalk त्रुटि अलर्ट';

  @override
  String get notificationChannelPermissions => 'CodeWalk अनुमतियाँ';

  @override
  String get notificationChannelPermissionsDescription =>
      'CodeWalk कार्रवाई आवश्यक अलर्ट';

  @override
  String get notificationChannelAgent => 'CodeWalk एजेंट';

  @override
  String get notificationChannelAgentDescription =>
      'CodeWalk एजेंट पूर्णता अलर्ट';

  @override
  String get notificationActionOpen => 'खोलें';

  @override
  String get foregroundMonitorNotificationBody =>
      'विश्वसनीय बैकग्राउंड अलर्ट सक्रिय हैं';

  @override
  String get foregroundMonitorNotificationTitle => 'बैकग्राउंड निगरानी सक्रिय';

  @override
  String get foregroundMonitorNotificationOneSession => 'एक सत्र की निगरानी';

  @override
  String foregroundMonitorNotificationSessionCount(int count) {
    return '$count सत्रों की निगरानी';
  }

  @override
  String sessionAttentionSemanticLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सत्रों को ध्यान देने की आवश्यकता है',
      one: '1 सत्र को ध्यान देने की आवश्यकता है',
    );
    return '$_temp0';
  }

  @override
  String get sessionAttentionOverlayPermissionRequired =>
      'अन्य ऐप्स के ऊपर प्रदर्शित करने की अनुमति आवश्यक है।';

  @override
  String get sessionAttentionIosInAppOnly =>
      'सत्र ध्यान केवल CodeWalk के भीतर उपलब्ध है।';

  @override
  String get sessionAttentionOverlayPermissionGrantPrompt =>
      'अन्य ऐप्स के ऊपर प्रदर्शित करने की अनुमति दें, फिर पुनः प्रयास करें।';

  @override
  String get sessionAttentionAndroidStartFailed =>
      'Android सत्र ध्यान सेवा शुरू नहीं हो सकी।';

  @override
  String chatMessageTruncatedChars(int count, String reason) {
    return '[$count वर्ण छोटे किए गए] $reason';
  }

  @override
  String get chatMessageJustNow => 'अभी-अभी';

  @override
  String chatMessageMinutesAgo(int count) {
    return '$count मिनट पहले';
  }

  @override
  String chatMessageHoursAgo(int count) {
    return '$count घंटे पहले';
  }

  @override
  String chatMessageDaysAgo(int count) {
    return '$count दिन पहले';
  }

  @override
  String chatMessageDateTime(int day, int hour, int minute, int month) {
    return '$month/$day $hour:$minute';
  }

  @override
  String get chatMessageYourMessage => 'आपका संदेश';

  @override
  String get chatMessageAssistantMessage => 'असिस्टेंट संदेश';

  @override
  String chatMessageStepStarted(int step) {
    return 'चरण शुरू #$step';
  }

  @override
  String chatMessageStepStartedWithSnapshot(String snapshot, int step) {
    return 'चरण शुरू #$step: $snapshot';
  }

  @override
  String chatMessageStepFinished(
    String cost,
    String reason,
    int step,
    int tokens,
  ) {
    return 'चरण समाप्त #$step: $reason • टोकन $tokens • \$$cost';
  }

  @override
  String chatMessagePatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count पैच',
      one: '1 पैच',
    );
    return '$_temp0';
  }

  @override
  String get chatMessageToolRun => 'टूल रन';

  @override
  String get chatMessageToolExecution => 'टूल निष्पादन';

  @override
  String chatMessageToolChainMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count और',
      one: '+1 और',
    );
    return '$_temp0';
  }

  @override
  String chatMessageToolChainExtraTypes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count प्रकार',
      one: '+1 प्रकार',
    );
    return '$_temp0';
  }

  @override
  String chatMessageToolAttentionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count को ध्यान देने की आवश्यकता है',
      one: '1 को ध्यान देने की आवश्यकता है',
    );
    return '$_temp0';
  }

  @override
  String chatMessageToolDoneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count पूर्ण',
      one: '1 पूर्ण',
    );
    return '$_temp0';
  }

  @override
  String get chatMessageToolCallsTitle => 'टूल कॉल';

  @override
  String get chatMessageDiffPreviewTruncated =>
      'ऐप स्थिरता के लिए Diff पूर्वावलोकन छोटा किया गया।';

  @override
  String get chatMessageLargeMessageTruncated =>
      'ऐप स्थिरता के लिए बड़े संदेश का पूर्वावलोकन छोटा किया गया।';

  @override
  String get chatMessageInvalidLinkFormat => 'अमान्य लिंक प्रारूप';

  @override
  String get chatMessageUnableToOpenLink => 'लिंक खोलने में असमर्थ';

  @override
  String sessionTodoInProgressCompact(int current, int total) {
    return '$current/$total प्रगति पर';
  }

  @override
  String sessionTodoTaskProgress(String content, int index, int total) {
    return 'कार्य $index/$total $content';
  }

  @override
  String sessionTodoDoneCompact(int count, int total) {
    return '$count/$total पूर्ण';
  }

  @override
  String sessionTodoCompletedCount(int count, int total) {
    return 'कार्य $count/$total पूर्ण हुए';
  }

  @override
  String sessionTodoTasksCount(int count) {
    return 'कार्य ($count)';
  }

  @override
  String questionStepOfReview(int current, int total) {
    return 'चरण $current/$total - समीक्षा';
  }

  @override
  String questionStepOfQuestion(int current, int total) {
    return 'चरण $current/$total - प्रश्न';
  }

  @override
  String get questionCustomAnswer => 'कस्टम उत्तर';

  @override
  String get questionSubmitAnswers => 'उत्तर जमा करें';

  @override
  String get questionReviewAnswers => 'उत्तरों की समीक्षा करें';

  @override
  String permissionRequestTitle(String permission) {
    return 'अनुमति अनुरोध: $permission';
  }

  @override
  String get sessionTitleCannotBeEmpty => 'शीर्षक खाली नहीं हो सकता';

  @override
  String get filesFailedToLoad => 'फ़ाइलें लोड करने में विफल';

  @override
  String get filesFailedToSearch => 'फ़ाइलें खोजने में विफल';

  @override
  String get filesNoOpenFilesHint =>
      'अभी तक कोई फ़ाइल खुली नहीं है। खोजने के लिए टाइप करें।';

  @override
  String get filesNoContentMatches => 'कोई सामग्री मेल नहीं मिली';

  @override
  String filesLinesSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count पंक्तियाँ चयनित',
      one: '1 पंक्ति चयनित',
    );
    return '$_temp0';
  }

  @override
  String get filesDraftTooLargeToSave =>
      'ड्राफ़्ट एडिटर से सेव करने के लिए बहुत बड़ा है।';

  @override
  String get filesSaveChangesBeforeClose =>
      'इस फ़ाइल को बंद करने से पहले परिवर्तन सेव करें।';

  @override
  String get filesSaveChangesBeforePathChange =>
      'यह पथ बदलने से पहले परिवर्तन सेव करें।';

  @override
  String get filesWaitForSaveBeforePathChange =>
      'यह पथ बदलने से पहले फ़ाइल सेव होने तक प्रतीक्षा करें।';

  @override
  String get filesWaitForFileOperation =>
      'फ़ाइल ऑपरेशन पूरा होने तक प्रतीक्षा करें।';

  @override
  String get filesLargeFileReadOnly =>
      'बड़ी फ़ाइलें एडिटिंग को सुचारू रखने के लिए केवल-पढ़ने के मोड में खुलती हैं।';

  @override
  String get filesCheckingWriteSupport =>
      'फ़ाइल लिखने की सुविधा की जाँच की जा रही है...';

  @override
  String get filesActiveProjectRequired =>
      'फ़ाइल ऑपरेशन के लिए एक सक्रिय प्रोजेक्ट निर्देशिका आवश्यक है।';

  @override
  String get filesReloadSkippedUnsavedChanges =>
      'अनसेव किए गए परिवर्तन हैं; रीलोड छोड़ दिया गया।';

  @override
  String get filesFailedToLoadContent => 'फ़ाइल सामग्री लोड करने में विफल';

  @override
  String get filesFileSaved => 'फ़ाइल सेव हो गई।';

  @override
  String get filesParentNotDirectory => 'पैरेंट एक निर्देशिका नहीं है।';

  @override
  String get filesMalformedResponse =>
      'फ़ाइल ऑपरेशन ने अमान्य प्रतिक्रिया लौटाई।';

  @override
  String get filesShellCommandDidNotComplete =>
      'फ़ाइल ऑपरेशन शेल कमांड पूरा नहीं हुआ।';

  @override
  String get filesShellCommandNoResult =>
      'फ़ाइल ऑपरेशन शेल कमांड ने कोई परिणाम नहीं लौटाया।';

  @override
  String get filesShellCommandTruncated =>
      'फ़ाइल ऑपरेशन शेल कमांड को सर्वर ने काट दिया।';

  @override
  String get filesShellCommandSyntaxError =>
      'फ़ाइल ऑपरेशन शेल कमांड सिंटैक्स त्रुटि के साथ विफल रहा।';

  @override
  String get filesShellUtilityNotFound => 'एक आवश्यक शेल उपयोगिता नहीं मिली।';

  @override
  String get filesShellCommandFailed =>
      'फ़ाइल ऑपरेशन शेल कमांड परिणाम लौटाने से पहले विफल रहा।';

  @override
  String get attachmentSaveTitle => 'अटैचमेंट सेव करें';

  @override
  String get attachmentBrowserSandboxLocalFile =>
      'ब्राउज़र सैंडबॉक्स स्थानीय file:// अटैचमेंट को सीधे खोलने से रोकता है।';

  @override
  String get attachmentLocalPathBrowserBlocked =>
      'यह अटैचमेंट एक स्थानीय पथ की ओर इंगित करता है जिसे ब्राउज़र से नहीं खोला जा सकता।';

  @override
  String terminalConnectedTo(String directory, String serverName) {
    return 'निर्देशिका $directory में $serverName से कनेक्ट हुआ';
  }

  @override
  String get terminalTransportUnavailable => 'टर्मिनल ट्रांसपोर्ट अनुपलब्ध है।';

  @override
  String get chatSlashCommandNew => 'नया चैट सत्र बनाएँ';

  @override
  String get chatSlashCommandModels => 'मॉडल चयनकर्ता खोलें';

  @override
  String get chatSlashCommandSessions => 'बातचीत सूची खोलें';

  @override
  String get chatSlashCommandAgent => 'एजेंट चयनकर्ता खोलें';

  @override
  String get chatSlashCommandOpen => 'फ़ाइल खोलने का त्वरित कार्य';

  @override
  String get chatSlashCommandHelp => 'कमांड सहायता दिखाएँ';

  @override
  String get chatSlashCommandCompact => 'वर्तमान सत्र संदर्भ संक्षिप्त करें';

  @override
  String get chatSlashCommandThinking => 'थिंकिंग बबल्स टॉगल करें';

  @override
  String get chatSlashCommandUndo => 'अंतिम दृश्यमान उपयोगकर्ता टर्न अनडू करें';

  @override
  String get chatSlashCommandRedo => 'अंतिम अनडू किया गया टर्न रीडू करें';

  @override
  String chatSessionSubConversationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count उप-बातचीतें',
      one: '1 उप-बातचीत',
    );
    return '$_temp0';
  }

  @override
  String chatMessageWeeksAgo(int count) {
    return '$count सप्ताह पहले';
  }

  @override
  String chatMessageShortDate(int day, int month) {
    return '$month/$day';
  }

  @override
  String get chatProviderErrorLoadSessionStatus =>
      'सत्र स्थिति लोड करने में विफल';

  @override
  String get chatProviderErrorLoadSessionDetails =>
      'कुछ सत्र विवरण लोड नहीं हो सके';

  @override
  String chatProviderErrorLoadSessionList(String error) {
    return 'सत्र सूची लोड करने में विफल: $error';
  }

  @override
  String get chatProviderErrorCreateSession => 'सत्र बनाने में विफल';

  @override
  String get chatProviderErrorSelectProviderModelBeforeSend =>
      'भेजने से पहले एक कनेक्टेड प्रोवाइडर या निःशुल्क OpenCode मॉडल चुनें';

  @override
  String get chatProviderErrorStartMessageSend =>
      'संदेश भेजना शुरू करने में विफल';

  @override
  String get chatProviderErrorStopUnavailable =>
      'वर्तमान सत्र के लिए रोकना उपलब्ध नहीं है';

  @override
  String get chatProviderErrorWaitForResponseFinish =>
      'संदर्भ संक्षिप्त करने से पहले वर्तमान प्रतिक्रिया समाप्त होने तक प्रतीक्षा करें';

  @override
  String get chatProviderErrorCompactUnavailable =>
      'वर्तमान सत्र के लिए संक्षिप्त संदर्भ अनुपलब्ध है';

  @override
  String get chatProviderErrorSelectModelBeforeCompact =>
      'संदर्भ संक्षिप्त करने से पहले एक मॉडल चुनें';

  @override
  String get chatProviderErrorCompactSessionContext =>
      'सत्र संदर्भ संक्षिप्त करने में विफल';

  @override
  String get chatProviderErrorNetwork =>
      'नेटवर्क कनेक्शन विफल। कृपया नेटवर्क सेटिंग्स जाँचें';

  @override
  String get chatProviderErrorServer =>
      'सर्वर त्रुटि। कृपया बाद में पुनः प्रयास करें';

  @override
  String get chatProviderErrorNotFound => 'संसाधन नहीं मिला';

  @override
  String get chatProviderErrorInvalidInput => 'अमान्य इनपुट पैरामीटर';

  @override
  String get chatProviderErrorUnknown =>
      'अज्ञात त्रुटि। कृपया बाद में पुनः प्रयास करें';

  @override
  String get chatProviderErrorSessionFallback => 'सत्र त्रुटि';

  @override
  String get projectProviderErrorNoProjectContext =>
      'सर्वर से कोई प्रोजेक्ट संदर्भ उपलब्ध नहीं है';

  @override
  String projectProviderErrorInitializeFailed(String error) {
    return 'प्रोजेक्ट संदर्भ आरंभ करने में विफल: $error';
  }

  @override
  String get projectProviderErrorSwitchProjectNotFound =>
      'प्रोजेक्ट बदलने में विफल: प्रोजेक्ट नहीं मिला';

  @override
  String get projectProviderErrorSwitchDirectoryEmpty =>
      'प्रोजेक्ट बदलने में विफल: निर्देशिका खाली है';

  @override
  String get projectProviderErrorAtLeastOneContext =>
      'कम से कम एक संदर्भ खुला रहना चाहिए';

  @override
  String get projectProviderErrorReopenProjectNotFound =>
      'प्रोजेक्ट फिर से खोलने में विफल: प्रोजेक्ट नहीं मिला';

  @override
  String get projectProviderErrorOnlyClosedArchivable =>
      'केवल बंद प्रोजेक्ट संग्रहीत किए जा सकते हैं';

  @override
  String get projectProviderErrorArchiveProjectNotFound =>
      'प्रोजेक्ट संग्रहीत करने में विफल: प्रोजेक्ट नहीं मिला';

  @override
  String get projectProviderErrorArchiveProjectPathInvalid =>
      'प्रोजेक्ट संग्रहीत करने में विफल: प्रोजेक्ट पथ अमान्य है';

  @override
  String projectProviderErrorLoadWorkspaces(String error) {
    return 'कार्यक्षेत्र लोड करने में विफल: $error';
  }

  @override
  String get projectProviderErrorWorkspaceNameEmpty =>
      'कार्यक्षेत्र नाम खाली नहीं हो सकता';

  @override
  String projectProviderErrorCreateWorkspace(String error) {
    return 'कार्यक्षेत्र बनाने में विफल: $error';
  }

  @override
  String projectProviderErrorResetWorkspace(String error) {
    return 'कार्यक्षेत्र रीसेट करने में विफल: $error';
  }

  @override
  String projectProviderErrorDeleteWorkspace(String error) {
    return 'कार्यक्षेत्र हटाने में विफल: $error';
  }

  @override
  String get projectProviderErrorDirectoryEmpty =>
      'निर्देशिका खाली नहीं हो सकती';

  @override
  String projectProviderErrorListDirectories(String error) {
    return 'निर्देशिकाएँ सूचीबद्ध करने में विफल: $error';
  }

  @override
  String projectProviderErrorValidateDirectory(String error) {
    return 'निर्देशिका सत्यापित करने में विफल: $error';
  }

  @override
  String get projectProviderErrorPathEmpty => 'पथ खाली नहीं हो सकता';

  @override
  String projectProviderErrorListFiles(String error) {
    return 'फ़ाइलें सूचीबद्ध करने में विफल: $error';
  }

  @override
  String projectProviderErrorSearchFiles(String error) {
    return 'फ़ाइलें खोजने में विफल: $error';
  }

  @override
  String projectProviderErrorContentSearchUnavailable(String error) {
    return 'सामग्री खोज उपलब्ध नहीं: $error';
  }

  @override
  String projectProviderErrorSearchSymbols(String error) {
    return 'प्रतीक खोजने में विफल: $error';
  }

  @override
  String projectProviderErrorReadFile(String error) {
    return 'फ़ाइल पढ़ने में विफल: $error';
  }

  @override
  String projectProviderErrorLoadProjectList(String error) {
    return 'प्रोजेक्ट सूची लोड करने में विफल: $error';
  }

  @override
  String get workspaceProjectRemovedFromHistory =>
      'प्रोजेक्ट इतिहास से हटा दिया गया';

  @override
  String workspaceProjectContextOpened(String directory) {
    return 'प्रोजेक्ट संदर्भ खोला गया: $directory';
  }

  @override
  String workspaceFailedToOpenProjectContext(String directory) {
    return 'प्रोजेक्ट संदर्भ खोलने में विफल: $directory';
  }

  @override
  String get chatAbortNotice => 'आप क्या अलग करना चाहते हैं?';

  @override
  String sessionTitleToday(String date, String time) {
    return 'आज $time ($date)';
  }

  @override
  String sessionTitleYesterday(String date, String time) {
    return 'कल $time ($date)';
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
  String get sessionWeekdayMon => 'सोम';

  @override
  String get sessionWeekdayTue => 'मंगल';

  @override
  String get sessionWeekdayWed => 'बुध';

  @override
  String get sessionWeekdayThu => 'गुरु';

  @override
  String get sessionWeekdayFri => 'शुक्र';

  @override
  String get sessionWeekdaySat => 'शनि';

  @override
  String get sessionWeekdaySun => 'रवि';

  @override
  String get forwardTimeNow => 'अभी';

  @override
  String forwardTimeMinutes(int count) {
    return '$count मिनट';
  }

  @override
  String forwardTimeHours(int count) {
    return '$count घंटे';
  }

  @override
  String forwardTimeDays(int count) {
    return '$count दिन';
  }

  @override
  String forwardTimeWeeks(int count) {
    return '$count सप्ताह';
  }

  @override
  String get settingsBehaviorConfigFieldDefaultModel => 'डिफ़ॉल्ट मॉडल';

  @override
  String get settingsBehaviorConfigFieldDefaultAgent => 'डिफ़ॉल्ट एजेंट';

  @override
  String get settingsBehaviorConfigFieldSmallModel => 'छोटा मॉडल';

  @override
  String get settingsBehaviorConfigFieldAutoUpdateMode => 'ऑटो-अपडेट मोड';

  @override
  String get settingsBehaviorConfigFieldSnapshotSetting => 'स्नैपशॉट सेटिंग';

  @override
  String get settingsBehaviorConfigFieldConversationUsername =>
      'बातचीत उपयोगकर्ता नाम';

  @override
  String get settingsBehaviorConfigFieldSharingDefault => 'साझाकरण डिफ़ॉल्ट';

  @override
  String get speechMicNoInputDevice =>
      'कोई माइक्रोफ़ोन इनपुट डिवाइस उपलब्ध नहीं है।';

  @override
  String get speechLinuxAudioServerUnavailable =>
      'A microphone tool was found, but the Linux audio server could not be reached. Make sure PipeWire or PulseAudio is running.';

  @override
  String get speechLinuxMicBackendMissing =>
      'No microphone recording tool was found on this system. Install PulseAudio tools (parecord), PipeWire tools (pw-record) or ALSA utilities (arecord), then try again.';

  @override
  String get speechMicDeviceBusy =>
      'डिफ़ॉल्ट माइक्रोफ़ोन वर्तमान में किसी अन्य ऐप द्वारा उपयोग में है।';

  @override
  String get speechMicUnsupportedFormat =>
      'डिफ़ॉल्ट माइक्रोफ़ोन प्रारूप समर्थित नहीं है।';

  @override
  String get speechMicSpeechPrivacy =>
      'Windows स्पीच सेवाएँ अक्षम हो सकती हैं (स्पीच प्राइवेसी, ऑनलाइन स्पीच रिकग्निशन, या भाषा पैक)।';

  @override
  String get speechMicBackendUnavailable =>
      'Windows माइक्रोफ़ोन बैकएंड इस बिल्ड में उपलब्ध नहीं है।';

  @override
  String speechEngineFallbackNotice(String fallback, String reason) {
    return 'चयनित STT इंजन अनुपलब्ध है ($reason)। इसके बजाय $fallback का उपयोग किया जा रहा है।';
  }

  @override
  String get oauthFlowSecureStorageUnavailable =>
      'OAuth के लिए सुरक्षित क्रेडेंशियल स्टोरेज अनुपलब्ध है।';

  @override
  String get oauthFlowUnexpectedError =>
      'OAuth प्रवाह अप्रत्याशित रूप से विफल रहा। कृपया पुनः प्रयास करें।';

  @override
  String get oauthFlowNoEndpointsDiscovered =>
      'कोई OAuth एंडपॉइंट खोजा नहीं गया। Cloudflare Dashboard में Managed OAuth सक्षम करें → Access → Applications → [यह ऐप]।';

  @override
  String get oauthFlowTokenResponseMissingAccessToken =>
      'OAuth टोकन प्रतिक्रिया में एक्सेस टोकन शामिल नहीं था।';

  @override
  String get oauthFlowProfileChanged =>
      'OAuth समाप्त होने से पहले सर्वर प्रोफाइल बदल गया।';

  @override
  String get oauthFlowMetadataMissingEndpoints =>
      'OAuth मेटाडेटा में ऑथराइज़ेशन/टोकन एंडपॉइंट अनुपलब्ध हैं।';

  @override
  String get oauthFlowCallbackNotCompleted => 'ऑथराइज़ेशन कॉलबैक पूरा नहीं हुआ';

  @override
  String get oauthFlowProviderDeclined =>
      'ऑथराइज़ेशन सर्वर ने OAuth अनुरोध अस्वीकार कर दिया। कृपया पुनः प्रयास करें।';

  @override
  String get oauthFlowCallbackValidationFailed =>
      'OAuth कॉलबैक सत्यापन विफल। कृपया पुनः प्रयास करें।';

  @override
  String get oauthFlowCallbackServerStartFailed =>
      'स्थानीय OAuth कॉलबैक सर्वर शुरू करने में विफल।';

  @override
  String get oauthFlowSignInCanceled => 'OAuth साइन-इन रद्द कर दिया गया।';

  @override
  String get oauthFlowBrowserOpenFailed =>
      'OAuth साइन-इन के लिए सिस्टम ब्राउज़र नहीं खोला जा सका।';

  @override
  String get oauthFlowCallbackTimeout =>
      '5 मिनट के भीतर ऐप तक कोई ऑथराइज़ेशन कॉलबैक नहीं पहुँचा। सहमति के बाद ब्राउज़र को स्थानीय कॉलबैक पते पर रीडायरेक्ट होना था। यदि ब्राउज़र ने इसके बजाय कनेक्शन त्रुटि दिखाई, तो यह डिवाइस या नेटवर्क लूपबैक रीडायरेक्ट को ब्लॉक करता है।';

  @override
  String oauthFlowTokenExchangeTransientFailure(int maxAttempts) {
    return '$maxAttempts प्रयासों के बाद अस्थायी नेटवर्क समस्या के कारण टोकन एक्सचेंज विफल रहा। कृपया पुनः प्रयास करें।';
  }

  @override
  String oauthFlowTokenExchangeHttpFailure(int statusCode) {
    return 'टोकन एक्सचेंज विफल (HTTP $statusCode)। कृपया पुनः प्रयास करें।';
  }

  @override
  String get oauthFlowTokenExchangeUnexpectedFailure =>
      'टोकन एक्सचेंज अप्रत्याशित रूप से विफल रहा। कृपया पुनः प्रयास करें।';

  @override
  String get oauthFlowTokenExchangeIncomplete =>
      'ऑथराइज़ेशन कोड भेजे जाने के बाद टोकन एक्सचेंज पूरा नहीं हुआ। कृपया OAuth साइन-इन फिर से शुरू करें।';

  @override
  String get speechReadAloudFailed => 'टेक्स्ट-टू-स्पीच विफल रहा।';

  @override
  String get speechReadAloudNoText =>
      'पढ़कर सुनाने के लिए कोई टेक्स्ट नहीं है।';

  @override
  String get speechEdgeTextTooLong =>
      'Microsoft Edge Speech एक बार में 4096 बाइट्स तक पढ़ सकता है।';

  @override
  String get speechEdgeMalformedAudio =>
      'Microsoft Edge Speech ने दोषपूर्ण ऑडियो डेटा लौटाया।';

  @override
  String get speechEdgeUnsupportedAudio =>
      'Microsoft Edge Speech ने अनसमर्थित ऑडियो डेटा लौटाया।';

  @override
  String get speechEdgeUnsupportedFrame =>
      'Microsoft Edge Speech ने एक अनसमर्थित वेबसॉकेट फ्रेम लौटाया।';

  @override
  String get speechEdgeSynthesisInterrupted =>
      'Microsoft Edge Speech संश्लेषण पूरा होने से पहले समाप्त हो गया।';

  @override
  String get speechEdgeEmptyAudio =>
      'Microsoft Edge Speech ने खाली ऑडियो प्रतिक्रिया लौटाई।';

  @override
  String get speechEdgeTimedOut =>
      'Microsoft Edge Speech का समय समाप्त हो गया।';

  @override
  String get speechEdgeUnreachable =>
      'Microsoft Edge Speech तक नहीं पहुँचा जा सका।';

  @override
  String get speechApiKeyMissing =>
      'इस TTS प्रदाता का उपयोग करने के लिए सेटिंग्स > भाषण से पाठ में API कुंजी जोड़ें।';

  @override
  String get speechProviderEmptyAudio =>
      'TTS प्रदाता ने खाली ऑडियो प्रतिक्रिया लौटाई।';

  @override
  String get speechProviderRequestRejected =>
      'TTS प्रदाता ने स्पीच अनुरोध अस्वीकार कर दिया।';

  @override
  String get speechApiKeyRejected =>
      'TTS API कुंजी प्रदाता द्वारा अस्वीकार कर दी गई।';

  @override
  String get speechProviderQuotaRateLimit =>
      'TTS प्रदाता ने कोटा या दर सीमा की सूचना दी।';

  @override
  String get speechReadAloudNoVoice => 'इस TTS प्रदाता के लिए एक आवाज़ चुनें।';

  @override
  String get speechProviderTextTooLong =>
      'यह टेक्स्ट इस TTS मॉडल के लिए बहुत लंबा है।';

  @override
  String get speechProviderInvalidAudio =>
      'TTS प्रदाता ने अपरिचित ऑडियो लौटाया।';

  @override
  String get speechNimBaseUrlRequired =>
      'NVIDIA NIM डिप्लॉयमेंट का बेस URL सेटिंग्स > भाषण से पाठ में दर्ज करें।';

  @override
  String get speechProviderTemporarilyUnavailable =>
      'TTS प्रदाता अस्थायी रूप से अनुपलब्ध है।';

  @override
  String get speechProviderUnreachable => 'TTS प्रदाता तक नहीं पहुँचा जा सका।';

  @override
  String appProviderErrorFailedToStartProcess(String tool) {
    return '$tool प्रक्रिया शुरू करने में विफल।';
  }

  @override
  String appProviderErrorToolNotAvailable(String runtime, String tool) {
    return '$tool उपलब्ध नहीं है। पहले $runtime स्थापित करें।';
  }

  @override
  String appProviderErrorToolInstallFailed(int exitCode, String tool) {
    return '$tool स्थापना निकास कोड $exitCode के साथ विफल रही।';
  }

  @override
  String appProviderErrorBunBootstrapFailed(int exitCode) {
    return 'Bun बूटस्ट्रैप निकास कोड $exitCode के साथ विफल रहा।';
  }

  @override
  String get appProviderErrorInstalledButNotFoundInPath =>
      'OpenCode स्थापना पूरी हुई लेकिन कमांड PATH में नहीं मिला।';

  @override
  String get appProviderErrorInstalledButPathNotResolved =>
      'OpenCode स्थापना पूरी हुई लेकिन कमांड पथ हल नहीं किया जा सका।';

  @override
  String appProviderErrorConfiguredCommandNotFound(String tool) {
    return 'कॉन्फ़िगर किया गया कमांड नहीं मिला और $tool PATH में नहीं है।';
  }

  @override
  String get appProviderErrorConfiguredCommandPathMissing =>
      'कॉन्फ़िगर किए गए कमांड का पथ मौजूद नहीं है।';

  @override
  String get appProviderErrorConfiguredCommandVersionCheckFailed =>
      'कॉन्फ़िगर किया गया कमांड मौजूद है लेकिन संस्करण जांच विफल रही।';

  @override
  String get appProviderErrorConfiguredCommandExecutionFailed =>
      'कॉन्फ़िगर किया गया कमांड निष्पादित नहीं किया जा सका।';

  @override
  String get appProviderWslCheckWindowsOnly =>
      'WSL जांच केवल Windows पर लागू होती है।';

  @override
  String get appProviderDesktopBuildRequired =>
      'प्रबंधित स्थानीय सर्वर कॉन्फ़िगर करने के लिए डेस्कटॉप बिल्ड का उपयोग करें।';

  @override
  String get appProviderKnownInstallationDirectoryDetected =>
      'किसी ज्ञात स्थापना निर्देशिका से पता लगाया गया।';

  @override
  String appProviderKnownInstallationPathRefreshHint(String appName) {
    return 'किसी ज्ञात स्थापना निर्देशिका से पता लगाया गया। PATH को रीफ़्रेश करने की आवश्यकता हो सकती है; यदि हाल की स्थापना अभी तक पता नहीं चली है, तो $appName को फिर से खोलें।';
  }

  @override
  String get appProviderErrorReleaseMetadataFetchFailed =>
      'GitHub से नवीनतम रिलीज़ मेटाडेटा प्राप्त करने में विफल।';

  @override
  String get appProviderErrorReleaseAssetListMissing =>
      'नवीनतम रिलीज़ मेटाडेटा में संपत्ति सूची शामिल नहीं थी।';

  @override
  String get appProviderErrorNoCompatibleAsset =>
      'कोई संगत OpenCode बाइनरी संपत्ति नहीं मिली।';

  @override
  String get appProviderErrorDownloadAssetFailed =>
      'चयनित OpenCode संपत्ति डाउनलोड करने में विफल।';

  @override
  String get appProviderErrorChecksumVerificationFailed =>
      'डाउनलोड की गई संपत्ति के लिए चेकसम सत्यापन विफल रहा।';

  @override
  String get appProviderErrorExtractArchiveFailed =>
      'OpenCode बाइनरी संग्रह निकालने में विफल।';

  @override
  String appProviderErrorExecutableNotFound(String tool) {
    return 'निकाले गए फ़ाइलों में $tool निष्पादन योग्य नहीं मिला।';
  }

  @override
  String get chatNoResponseFromServer =>
      'सर्वर से कोई प्रतिक्रिया नहीं मिली। कृपया पुनः प्रयास करें।';

  @override
  String get chatNoResponseFromModel =>
      'मॉडल से कोई प्रतिक्रिया नहीं मिली। कृपया पुनः प्रयास करें।';

  @override
  String get speechJobCancelled => 'स्पीच कार्य रद्द कर दिया गया।';

  @override
  String get speechEdgeCancelled => 'Microsoft Edge Speech रद्द कर दिया गया।';

  @override
  String get sessionAttentionKindActive => 'सक्रिय';

  @override
  String get sessionAttentionKindReceiving => 'प्राप्त हो रहा है';

  @override
  String get sessionAttentionKindDelayed => 'विलंबित';

  @override
  String get sessionAttentionKindCompleted => 'पूर्ण';

  @override
  String get sessionAttentionKindPendingInteraction =>
      'इंटरैक्शन की प्रतीक्षा है';

  @override
  String get sessionAttentionKindError => 'त्रुटि';

  @override
  String get sessionAttentionPauseCellularDataSaver =>
      'सेलुलर डेटा सेवर सक्रिय है।';

  @override
  String get sessionAttentionPauseOauthReopenRequired => 'OAuth साइन-इन आवश्यक';

  @override
  String get sessionAttentionPauseTailscaleReopenRequired =>
      'Tailscale कनेक्शन आवश्यक';

  @override
  String get sessionAttentionPauseOffline => 'ऑफ़लाइन';

  @override
  String get sessionAttentionPausePermissionRevoked => 'अनुमति रद्द कर दी गई';

  @override
  String get sessionAttentionPauseServiceStopped => 'सेवा रुक गई';

  @override
  String get sessionAttentionPauseHostUnavailable => 'होस्ट अनुपलब्ध';

  @override
  String get errorRequestCancelled => 'अनुरोध रद्द कर दिया गया';

  @override
  String errorUnknownNetworkError(String error) {
    return 'अज्ञात नेटवर्क त्रुटि: $error';
  }

  @override
  String get errorCertificateError => 'प्रमाणपत्र त्रुटि';

  @override
  String get errorSessionBusy =>
      'सत्र किसी अन्य अनुरोध को संसाधित करने में व्यस्त है।';

  @override
  String get errorRunShellCommandFailed => 'शेल कमांड चलाने में विफल';

  @override
  String get errorRunSlashCommandFailed => 'स्लैश कमांड चलाने में विफल';

  @override
  String get settingsBehaviorOpenCodeDefaultsLoadError =>
      'सक्रिय सर्वर से OpenCode-आधारित डिफ़ॉल्ट लोड नहीं किए जा सके।';

  @override
  String get sessionTabIconRemoveFailed =>
      'स्थानीय सत्र टैब आइकन डेटा हटाने में विफल';

  @override
  String get forwardUntitled => 'बिना शीर्षक';

  @override
  String setupDebugLinuxLogsPath(String path) {
    return 'Linux लॉग: $path';
  }

  @override
  String setupDebugRunOpenCodeCommand(String command) {
    return 'OpenCode चलाने के लिए: $command';
  }

  @override
  String setupDebugServerHealthEndpoint(String endpoint) {
    return 'सर्वर स्वास्थ्य जांच: $endpoint';
  }

  @override
  String setupDebugServerDocsEndpoint(String endpoint) {
    return 'सर्वर दस्तावेज़: $endpoint';
  }

  @override
  String get logsEntryError => 'त्रुटि';

  @override
  String get logsEntryStack => 'स्टैक';

  @override
  String get setupDebugSourceDiagnostics => 'निदान';

  @override
  String get setupDebugSourceUseExisting => 'मौजूदा का उपयोग करें';

  @override
  String get setupDebugSourceLocalServer => 'स्थानीय सर्वर';

  @override
  String get setupDebugSourceOnboarding => 'ऑनबोर्डिंग';

  @override
  String get setupDebugSourceManualConnection => 'मैन्युअल कनेक्शन';

  @override
  String setupDebugMessageDiagnosticsResult(
    String availability,
    String platform,
    String recommendation,
  ) {
    return '$platform पर $availability। $recommendation';
  }

  @override
  String get setupDebugMessageDetectAttempt =>
      'वर्तमान वातावरण से मौजूदा OpenCode कमांड का पता लगाने का प्रयास किया जा रहा है।';

  @override
  String get setupDebugMessageInstallStarted =>
      'CodeWalk से OpenCode इंस्टॉलेशन शुरू किया गया।';

  @override
  String setupDebugMessageStartLocalServer(String url) {
    return '$url पर प्रबंधित OpenCode सर्वर शुरू हो रहा है।';
  }

  @override
  String setupDebugMessageHealthyRunning(String url) {
    return 'प्रबंधित OpenCode सर्वर स्वस्थ है और $url पर चल रहा है।';
  }

  @override
  String get setupDebugMessageStoppingLocalServer =>
      'प्रबंधित OpenCode सर्वर रोका जा रहा है।';

  @override
  String get setupDebugMessageStoppedCleanly =>
      'प्रबंधित OpenCode सर्वर साफ़ रूप से रुक गया।';

  @override
  String get setupDebugMessageExitedAfterRequestedStop =>
      'अनुरोधित रोक के बाद प्रबंधित OpenCode सर्वर बंद हो गया।';

  @override
  String get setupDebugMessageOnboardingConnectExisting =>
      'उपयोगकर्ता ने मौजूदा OpenCode सर्वर से कनेक्ट करना चुना।';

  @override
  String get setupDebugMessageOnboardingGuidedPath =>
      'उपयोगकर्ता ने निर्देशित OpenCode सेटअप पथ खोला।';

  @override
  String get setupDebugMessageOnboardingManagedLocal =>
      'उपयोगकर्ता ने प्रबंधित स्थानीय OpenCode सेटअप खोला।';

  @override
  String get setupDebugMessageOnboardingOpenedServerSettings =>
      'स्वास्थ्य जांच विफल होने के बाद उपयोगकर्ता ने सर्वर सेटिंग्स खोली।';

  @override
  String get setupDebugMessageOnboardingAddAnotherServer =>
      'स्वास्थ्य जांच विफल होने के बाद उपयोगकर्ता ने दूसरा सर्वर जोड़ना चुना।';

  @override
  String setupDebugMessageTestingServerUrl(String url) {
    return 'ऑनबोर्डिंग से OpenCode सर्वर URL $url का परीक्षण किया जा रहा है।';
  }

  @override
  String get chatProviderErrorSessionNotFound => 'सत्र नहीं मिला';

  @override
  String get chatProviderErrorInvalidMessageFormat => 'अमान्य संदेश प्रारूप';

  @override
  String get chatProviderErrorNetworkShort => 'नेटवर्क कनेक्शन विफल';

  @override
  String get chatProviderErrorUnknownShort => 'अज्ञात त्रुटि';

  @override
  String get terminalCreateFailed => 'टर्मिनल सत्र बनाना विफल';

  @override
  String get terminalEndpointUnavailable => 'टर्मिनल एंडपॉइंट उपलब्ध नहीं है';

  @override
  String get terminalInvalidDirectory => 'अमान्य टर्मिनल निर्देशिका';

  @override
  String get terminalWebsocketUnavailable =>
      'टर्मिनल वेबसॉकेट यहाँ उपलब्ध नहीं है।';

  @override
  String chatMessageToolChainCallsCompact(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count कॉल',
      one: '1 कॉल',
    );
    return '$_temp0';
  }

  @override
  String get errorConnectionTimeout => 'कनेक्शन टाइमआउट';

  @override
  String get errorClientError => 'क्लाइंट त्रुटि';

  @override
  String get chatProviderErrorSendMessage => 'संदेश भेजने में विफल';

  @override
  String get speechApiEngine => 'API';

  @override
  String get speechApiEngineSubtitle =>
      'OpenAI, Groq या एक कस्टम OpenAI-संगत एंडपॉइंट।';

  @override
  String get speechApiProvider => 'स्पीच-टू-टेक्स्ट प्रदाता';

  @override
  String get speechCloudSttPrivacy => 'क्लाउड स्पीच-टू-टेक्स्ट गोपनीयता';

  @override
  String get speechCloudSttPrivacyDescription =>
      'रिकॉर्ड किया गया माइक्रोफ़ोन ऑडियो कॉन्फ़िगर किए गए प्रदाता को भेजा जाता है। API कुंजियाँ इस डिवाइस की सुरक्षित स्टोरेज में रहती हैं।';

  @override
  String get speechApiKeyOptional => 'कस्टम एंडपॉइंट के लिए वैकल्पिक।';

  @override
  String speechApiBatchHint(String provider) {
    return '$provider बैच ट्रांसक्रिप्शन का उपयोग करता है। रोकने और ट्रांसक्रिप्ट करने के लिए माइक्रोफ़ोन को फिर से टैप करें।';
  }

  @override
  String get speechApiWebUnavailable =>
      'API स्पीच-टू-टेक्स्ट वेब बिल्ड पर उपलब्ध नहीं है।';

  @override
  String get speechApiConfigInvalid =>
      'स्पीच API एंडपॉइंट और मॉडल जाँचें। रिमोट एंडपॉइंट को HTTPS का उपयोग करना चाहिए।';

  @override
  String get speechApiRequestInvalid =>
      'स्पीच एंडपॉइंट या मॉडल अस्वीकृत कर दिया गया।';

  @override
  String get speechApiRateLimited =>
      'स्पीच प्रदाता ने कोटा या दर सीमा की सूचना दी।';

  @override
  String get speechApiUnavailable =>
      'स्पीच प्रदाता अस्थायी रूप से अनुपलब्ध है।';

  @override
  String get speechApiNetwork => 'स्पीच प्रदाता तक नहीं पहुंचा जा सका।';

  @override
  String get speechApiInvalidResponse =>
      'स्पीच प्रदाता ने अमान्य प्रतिक्रिया लौटाई।';

  @override
  String get speechApiEmptyAudio => 'कोई माइक्रोफ़ोन ऑडियो कैप्चर नहीं हुआ।';

  @override
  String get speechApiEmptyTranscript =>
      'स्पीच प्रदाता ने कोई ट्रांसक्रिप्शन नहीं लौटाया।';

  @override
  String get speechApiCustomProvider => 'कस्टम OpenAI-संगत';

  @override
  String get speechApiMaxDuration =>
      'API रिकॉर्डिंग 2 मिनट के बाद स्वचालित रूप से रुक जाती है।';

  @override
  String get speechApiLanguageHint =>
      'सक्रिय ऐप भाषा ट्रांसक्रिप्शन संकेत के रूप में भेजी जाती है।';

  @override
  String get speechSttApiKeyStorageUnavailable =>
      'सुरक्षित स्पीच API कुंजी स्टोरेज उपलब्ध नहीं है।';

  @override
  String get speechSttApiKeyMissing =>
      'सेटिंग्स > स्पीच में स्पीच API कुंजी जोड़ें।';

  @override
  String get speechSttApiKeyRejected => 'स्पीच API कुंजी अस्वीकृत कर दी गई।';

  @override
  String get carMessagingReply => 'जवाब दें';

  @override
  String get carMessagingMarkRead => 'पढ़ा हुआ चिह्नित करें';

  @override
  String get carMessagingDeliveryFailedTitle => 'जवाब भेजा नहीं जा सका';

  @override
  String get carMessagingDeliveryFailedBody =>
      'आपका वॉइस जवाब डिलीवर नहीं किया जा सका। फिर से कोशिश करने के लिए CodeWalk खोलें।';
}
