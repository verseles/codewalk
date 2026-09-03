import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_bn.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_ur.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('bn'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
    Locale('it'),
    Locale('ja'),
    Locale('ko'),
    Locale('pt'),
    Locale('ru'),
    Locale('ur'),
    Locale('zh'),
  ];

  /// CodeWalk UI string — aboutGitHub
  ///
  /// In en, this message translates to:
  /// **'GitHub'**
  String get aboutGitHub;

  /// CodeWalk UI string — appProviderCannotActivateUnhealthy
  ///
  /// In en, this message translates to:
  /// **'Cannot activate an unhealthy server'**
  String get appProviderCannotActivateUnhealthy;

  /// CodeWalk UI string — appProviderDesktopOnly
  ///
  /// In en, this message translates to:
  /// **'Managed local server is available only on desktop.'**
  String get appProviderDesktopOnly;

  /// CodeWalk UI string — appProviderDetectingCommand
  ///
  /// In en, this message translates to:
  /// **'Detecting OpenCode command...'**
  String get appProviderDetectingCommand;

  /// CodeWalk UI string — appProviderErrorCannotActivateUnhealthy
  ///
  /// In en, this message translates to:
  /// **'Cannot activate an unhealthy server'**
  String get appProviderErrorCannotActivateUnhealthy;

  /// CodeWalk UI string — appProviderErrorCloudflareOAuthNotSupported
  ///
  /// In en, this message translates to:
  /// **'Cloudflare Access OAuth is not supported on this platform'**
  String get appProviderErrorCloudflareOAuthNotSupported;

  /// CodeWalk UI string — appProviderErrorInstallationFailed
  ///
  /// In en, this message translates to:
  /// **'OpenCode installation failed.'**
  String get appProviderErrorInstallationFailed;

  /// CodeWalk UI string — appProviderErrorInvalidServerUrl
  ///
  /// In en, this message translates to:
  /// **'Invalid server URL'**
  String get appProviderErrorInvalidServerUrl;

  /// CodeWalk UI string — appProviderErrorLocalServerHealthCheckFailed
  ///
  /// In en, this message translates to:
  /// **'Local server started but health check did not pass.'**
  String get appProviderErrorLocalServerHealthCheckFailed;

  /// CodeWalk UI string — appProviderErrorManagedDesktopOnly
  ///
  /// In en, this message translates to:
  /// **'Managed local server is available only on desktop.'**
  String get appProviderErrorManagedDesktopOnly;

  /// CodeWalk UI string — appProviderErrorServerAlreadyExists
  ///
  /// In en, this message translates to:
  /// **'A server with this URL already exists'**
  String get appProviderErrorServerAlreadyExists;

  /// CodeWalk UI string — appProviderErrorServerProfileNotFound
  ///
  /// In en, this message translates to:
  /// **'Server profile not found'**
  String get appProviderErrorServerProfileNotFound;

  /// CodeWalk UI string — appProviderErrorServerUrlRequired
  ///
  /// In en, this message translates to:
  /// **'Server URL is required'**
  String get appProviderErrorServerUrlRequired;

  /// CodeWalk UI string — appProviderErrorTailscaleNotSupported
  ///
  /// In en, this message translates to:
  /// **'Tailscale is not supported on this platform'**
  String get appProviderErrorTailscaleNotSupported;

  /// CodeWalk UI string — appProviderExitedWithCode
  ///
  /// In en, this message translates to:
  /// **'Local server exited with code {code}.'**
  String appProviderExitedWithCode(int code);

  /// CodeWalk UI string — appProviderFailedToStart
  ///
  /// In en, this message translates to:
  /// **'Failed to start local OpenCode server.'**
  String get appProviderFailedToStart;

  /// CodeWalk UI string — appProviderInstallBinary
  ///
  /// In en, this message translates to:
  /// **'Install Binary'**
  String get appProviderInstallBinary;

  /// CodeWalk UI string — appProviderInstallBunOpenCode
  ///
  /// In en, this message translates to:
  /// **'Install Bun + OpenCode'**
  String get appProviderInstallBunOpenCode;

  /// CodeWalk UI string — appProviderInstallSucceeded
  ///
  /// In en, this message translates to:
  /// **'Installation succeeded.'**
  String get appProviderInstallSucceeded;

  /// CodeWalk UI string — appProviderInstallSucceededWithPath
  ///
  /// In en, this message translates to:
  /// **'Installation succeeded. OpenCode command available at {path}.'**
  String appProviderInstallSucceededWithPath(String path);

  /// CodeWalk UI string — appProviderInstallViaBun
  ///
  /// In en, this message translates to:
  /// **'Install via Bun'**
  String get appProviderInstallViaBun;

  /// CodeWalk UI string — appProviderInstallViaNpm
  ///
  /// In en, this message translates to:
  /// **'Install via npm'**
  String get appProviderInstallViaNpm;

  /// CodeWalk UI string — appProviderInstallationFailed
  ///
  /// In en, this message translates to:
  /// **'OpenCode installation failed.'**
  String get appProviderInstallationFailed;

  /// CodeWalk UI string — appProviderInstalledSuccessfully
  ///
  /// In en, this message translates to:
  /// **'OpenCode requirements installed successfully.'**
  String get appProviderInstalledSuccessfully;

  /// CodeWalk UI string — appProviderInstallingRequirements
  ///
  /// In en, this message translates to:
  /// **'Installing OpenCode requirements...'**
  String get appProviderInstallingRequirements;

  /// CodeWalk UI string — appProviderInvalidServerUrl
  ///
  /// In en, this message translates to:
  /// **'Invalid server URL'**
  String get appProviderInvalidServerUrl;

  /// CodeWalk UI string — appProviderLabelLocalOpenCodeManaged
  ///
  /// In en, this message translates to:
  /// **'Local OpenCode (Managed)'**
  String get appProviderLabelLocalOpenCodeManaged;

  /// CodeWalk UI string — appProviderLabelPrimaryServer
  ///
  /// In en, this message translates to:
  /// **'Primary server'**
  String get appProviderLabelPrimaryServer;

  /// CodeWalk UI string — appProviderLocalManaged
  ///
  /// In en, this message translates to:
  /// **'Local OpenCode (Managed)'**
  String get appProviderLocalManaged;

  /// CodeWalk UI string — appProviderLocalServerStopped
  ///
  /// In en, this message translates to:
  /// **'Local server is stopped.'**
  String get appProviderLocalServerStopped;

  /// CodeWalk UI string — appProviderNotDetectedInstall
  ///
  /// In en, this message translates to:
  /// **'OpenCode command was not detected. Run installation from the wizard.'**
  String get appProviderNotDetectedInstall;

  /// CodeWalk UI string — appProviderNotDetectedRefresh
  ///
  /// In en, this message translates to:
  /// **'OpenCode command was not detected. If you installed it moments ago, refresh checks or reopen {appName} to reload PATH.'**
  String appProviderNotDetectedRefresh(String appName);

  /// CodeWalk UI string — appProviderOAuthNotSupported
  ///
  /// In en, this message translates to:
  /// **'Cloudflare Access OAuth is not supported on this platform'**
  String get appProviderOAuthNotSupported;

  /// CodeWalk UI string — appProviderOpenCodeDetected
  ///
  /// In en, this message translates to:
  /// **'OpenCode detected'**
  String get appProviderOpenCodeDetected;

  /// CodeWalk UI string — appProviderOpenCodeNotDetected
  ///
  /// In en, this message translates to:
  /// **'OpenCode not detected'**
  String get appProviderOpenCodeNotDetected;

  /// CodeWalk UI string — appProviderPrimaryServer
  ///
  /// In en, this message translates to:
  /// **'Primary server'**
  String get appProviderPrimaryServer;

  /// CodeWalk UI string — appProviderProfileNotFound
  ///
  /// In en, this message translates to:
  /// **'Server profile not found'**
  String get appProviderProfileNotFound;

  /// CodeWalk UI string — appProviderRunDiagnostics
  ///
  /// In en, this message translates to:
  /// **'Run diagnostics to verify local OpenCode requirements.'**
  String get appProviderRunDiagnostics;

  /// CodeWalk UI string — appProviderRunningAt
  ///
  /// In en, this message translates to:
  /// **'Running at {url}'**
  String appProviderRunningAt(String url);

  /// CodeWalk UI string — appProviderSetupDetectingOpenCode
  ///
  /// In en, this message translates to:
  /// **'Detecting OpenCode command...'**
  String get appProviderSetupDetectingOpenCode;

  /// CodeWalk UI string — appProviderSetupInstallationSucceeded
  ///
  /// In en, this message translates to:
  /// **'Installation succeeded.'**
  String get appProviderSetupInstallationSucceeded;

  /// CodeWalk UI string — appProviderSetupInstallationSucceededWithPath
  ///
  /// In en, this message translates to:
  /// **'Installation succeeded. OpenCode command available at {path}.'**
  String appProviderSetupInstallationSucceededWithPath(String path);

  /// CodeWalk UI string — appProviderSetupInstallingRequirements
  ///
  /// In en, this message translates to:
  /// **'Installing OpenCode requirements...'**
  String get appProviderSetupInstallingRequirements;

  /// CodeWalk UI string — appProviderSetupOpenCodeDetected
  ///
  /// In en, this message translates to:
  /// **'OpenCode detected'**
  String get appProviderSetupOpenCodeDetected;

  /// CodeWalk UI string — appProviderSetupOpenCodeNotDetected
  ///
  /// In en, this message translates to:
  /// **'OpenCode not detected'**
  String get appProviderSetupOpenCodeNotDetected;

  /// CodeWalk UI string — appProviderSetupOpenCodeNotDetectedInstall
  ///
  /// In en, this message translates to:
  /// **'OpenCode command was not detected. Run installation from the wizard.'**
  String get appProviderSetupOpenCodeNotDetectedInstall;

  /// CodeWalk UI string — appProviderSetupOpenCodeNotDetectedRefresh
  ///
  /// In en, this message translates to:
  /// **'OpenCode command was not detected. If you installed it moments ago, refresh checks or reopen CodeWalk to reload PATH.'**
  String get appProviderSetupOpenCodeNotDetectedRefresh;

  /// CodeWalk UI string — appProviderSetupRequirementsInstalled
  ///
  /// In en, this message translates to:
  /// **'OpenCode requirements installed successfully.'**
  String get appProviderSetupRequirementsInstalled;

  /// CodeWalk UI string — appProviderSetupUsingOpenCodeAt
  ///
  /// In en, this message translates to:
  /// **'Using OpenCode command at {path}'**
  String appProviderSetupUsingOpenCodeAt(String path);

  /// CodeWalk UI string — appProviderStartingLocalServer
  ///
  /// In en, this message translates to:
  /// **'Starting local server...'**
  String get appProviderStartingLocalServer;

  /// CodeWalk UI string — appProviderStatusLocalServerExitedWithCode
  ///
  /// In en, this message translates to:
  /// **'Local server exited with code {code}.'**
  String appProviderStatusLocalServerExitedWithCode(int code);

  /// CodeWalk UI string — appProviderStatusLocalServerStopped
  ///
  /// In en, this message translates to:
  /// **'Local server is stopped.'**
  String get appProviderStatusLocalServerStopped;

  /// CodeWalk UI string — appProviderStatusRunningAt
  ///
  /// In en, this message translates to:
  /// **'Running at {url}'**
  String appProviderStatusRunningAt(String url);

  /// CodeWalk UI string — appProviderStatusStartingLocalServer
  ///
  /// In en, this message translates to:
  /// **'Starting local server...'**
  String get appProviderStatusStartingLocalServer;

  /// CodeWalk UI string — appProviderStatusStoppingLocalServer
  ///
  /// In en, this message translates to:
  /// **'Stopping local server...'**
  String get appProviderStatusStoppingLocalServer;

  /// CodeWalk UI string — appProviderStoppingLocalServer
  ///
  /// In en, this message translates to:
  /// **'Stopping local server...'**
  String get appProviderStoppingLocalServer;

  /// CodeWalk UI string — appProviderTailscaleNotSupported
  ///
  /// In en, this message translates to:
  /// **'Tailscale is not supported on this platform'**
  String get appProviderTailscaleNotSupported;

  /// CodeWalk UI string — appProviderUsingCommandAt
  ///
  /// In en, this message translates to:
  /// **'Using OpenCode command at {path}'**
  String appProviderUsingCommandAt(String path);

  /// CodeWalk UI string — appShellDownloadingUpdate
  ///
  /// In en, this message translates to:
  /// **'Downloading update…'**
  String get appShellDownloadingUpdate;

  /// CodeWalk UI string — appShellInstall
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get appShellInstall;

  /// CodeWalk UI string — appShellInstallFailed
  ///
  /// In en, this message translates to:
  /// **'Install failed'**
  String get appShellInstallFailed;

  /// CodeWalk UI string — appShellInstallingUpdate
  ///
  /// In en, this message translates to:
  /// **'Installing update...'**
  String get appShellInstallingUpdate;

  /// CodeWalk UI string — appShellRestart
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get appShellRestart;

  /// CodeWalk UI string — appShellUpdateAvailableResult
  ///
  /// In en, this message translates to:
  /// **'Update available: v{latestVersion}'**
  String appShellUpdateAvailableResult(String latestVersion);

  /// CodeWalk UI string — appShellUpdateInstalledRestartApp
  ///
  /// In en, this message translates to:
  /// **'Update installed. Restart the app to apply.'**
  String get appShellUpdateInstalledRestartApp;

  /// CodeWalk UI string — appShellUpdateInstalledRestartRequired
  ///
  /// In en, this message translates to:
  /// **'Update installed. Restart is required to apply the new version.'**
  String get appShellUpdateInstalledRestartRequired;

  /// CodeWalk UI string — attachmentCouldNotDecode
  ///
  /// In en, this message translates to:
  /// **'Attachment data could not be decoded.'**
  String get attachmentCouldNotDecode;

  /// CodeWalk UI string — attachmentCouldNotDownload
  ///
  /// In en, this message translates to:
  /// **'Attachment could not be downloaded.'**
  String get attachmentCouldNotDownload;

  /// CodeWalk UI string — attachmentCouldNotSave
  ///
  /// In en, this message translates to:
  /// **'Attachment could not be saved on this device.'**
  String get attachmentCouldNotSave;

  /// CodeWalk UI string — attachmentDownloadStarted
  ///
  /// In en, this message translates to:
  /// **'Attachment download started.'**
  String get attachmentDownloadStarted;

  /// CodeWalk UI string — attachmentLocalNotFound
  ///
  /// In en, this message translates to:
  /// **'Local attachment was not found on this device.'**
  String get attachmentLocalNotFound;

  /// CodeWalk UI string — attachmentNoValidLocation
  ///
  /// In en, this message translates to:
  /// **'Attachment does not provide a valid location.'**
  String get attachmentNoValidLocation;

  /// CodeWalk UI string — attachmentNotAvailableOnPlatform
  ///
  /// In en, this message translates to:
  /// **'Attachment actions are not available on this platform.'**
  String get attachmentNotAvailableOnPlatform;

  /// CodeWalk UI string — attachmentPathEmpty
  ///
  /// In en, this message translates to:
  /// **'Attachment path is empty.'**
  String get attachmentPathEmpty;

  /// CodeWalk UI string — attachmentPayloadEmpty
  ///
  /// In en, this message translates to:
  /// **'Attachment payload is empty.'**
  String get attachmentPayloadEmpty;

  /// CodeWalk UI string — attachmentSaveCanceled
  ///
  /// In en, this message translates to:
  /// **'Save canceled.'**
  String get attachmentSaveCanceled;

  /// CodeWalk UI string — attachmentSavedAndOpened
  ///
  /// In en, this message translates to:
  /// **'Attachment saved to {path} and opened.'**
  String attachmentSavedAndOpened(String path);

  /// CodeWalk UI string — attachmentSavedPath
  ///
  /// In en, this message translates to:
  /// **'Attachment saved to {path}.'**
  String attachmentSavedPath(String path);

  /// CodeWalk UI string — attachmentSavedTo
  ///
  /// In en, this message translates to:
  /// **'Attachment saved to {path}.'**
  String attachmentSavedTo(String path);

  /// CodeWalk UI string — attachmentUnableToOpenLink
  ///
  /// In en, this message translates to:
  /// **'Unable to open the attachment link.'**
  String get attachmentUnableToOpenLink;

  /// CodeWalk UI string — attachmentUnableToOpenLocal
  ///
  /// In en, this message translates to:
  /// **'Unable to open the local attachment.'**
  String get attachmentUnableToOpenLocal;

  /// CodeWalk UI string — behaviorAdvancedPermissionRule
  ///
  /// In en, this message translates to:
  /// **'Advanced permission rule editing stays out of Settings for now and is deferred to later parity work.'**
  String get behaviorAdvancedPermissionRule;

  /// CodeWalk UI string — behaviorAutomatic
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get behaviorAutomatic;

  /// CodeWalk UI string — behaviorAutomaticFallback
  ///
  /// In en, this message translates to:
  /// **'Automatic fallback'**
  String get behaviorAutomaticFallback;

  /// CodeWalk UI string — behaviorCellularDataSaver
  ///
  /// In en, this message translates to:
  /// **'Cellular data saver'**
  String get behaviorCellularDataSaver;

  /// CodeWalk UI string — behaviorCellularDataSaverActive
  ///
  /// In en, this message translates to:
  /// **'Cellular data saver is active.'**
  String get behaviorCellularDataSaverActive;

  /// CodeWalk UI string — behaviorChatLevelShare
  ///
  /// In en, this message translates to:
  /// **'Use the chat-level share action to publish one session now. This setting only changes OpenCode’s default sharing policy.'**
  String get behaviorChatLevelShare;

  /// CodeWalk UI string — behaviorCodeWalkReleaseChecks
  ///
  /// In en, this message translates to:
  /// **'Use About for CodeWalk release checks. This setting only mirrors the official OpenCode `autoupdate` config.'**
  String get behaviorCodeWalkReleaseChecks;

  /// CodeWalk UI string — behaviorControlsOfficialGlobal
  ///
  /// In en, this message translates to:
  /// **'Controls the official global `share` config, not the share button for an individual chat.'**
  String get behaviorControlsOfficialGlobal;

  /// CodeWalk UI string — behaviorControlsUpstreamOpenCode
  ///
  /// In en, this message translates to:
  /// **'Controls upstream OpenCode runtime updates, not CodeWalk app update checks.'**
  String get behaviorControlsUpstreamOpenCode;

  /// CodeWalk UI string — behaviorCustomDisplayName
  ///
  /// In en, this message translates to:
  /// **'Custom display name shown in conversations instead of the system username.'**
  String get behaviorCustomDisplayName;

  /// CodeWalk UI string — behaviorCutsAutomaticMobile
  ///
  /// In en, this message translates to:
  /// **'Cuts automatic mobile-data usage by stopping background downloads and throttling automatic foreground refreshes to one burst every {inSeconds} seconds.'**
  String behaviorCutsAutomaticMobile(int inSeconds);

  /// CodeWalk UI string — behaviorDataSaverActive
  ///
  /// In en, this message translates to:
  /// **'Active now on mobile data.'**
  String get behaviorDataSaverActive;

  /// CodeWalk UI string — behaviorDataSaverAggressive
  ///
  /// In en, this message translates to:
  /// **'Aggressive'**
  String get behaviorDataSaverAggressive;

  /// CodeWalk UI string — behaviorDataSaverAggressiveDescription
  ///
  /// In en, this message translates to:
  /// **'Low-bandwidth mode: only the visible workspace stream stays live, global updates are paused, and automatic refreshes are stretched.'**
  String get behaviorDataSaverAggressiveDescription;

  /// CodeWalk UI string — behaviorDataSaverCellularOnly
  ///
  /// In en, this message translates to:
  /// **'Only applies when the connection is cellular/mobile.'**
  String get behaviorDataSaverCellularOnly;

  /// CodeWalk UI string — behaviorDataSaverOff
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get behaviorDataSaverOff;

  /// CodeWalk UI string — behaviorDataSaverOffHint
  ///
  /// In en, this message translates to:
  /// **'Full realtime and automatic refreshes are enabled.'**
  String get behaviorDataSaverOffHint;

  /// CodeWalk UI string — behaviorDataSaverStandard
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get behaviorDataSaverStandard;

  /// CodeWalk UI string — behaviorDataSaverWaiting
  ///
  /// In en, this message translates to:
  /// **'Waiting for the next mobile-data sync window.'**
  String get behaviorDataSaverWaiting;

  /// CodeWalk UI string — behaviorDisabled
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get behaviorDisabled;

  /// CodeWalk UI string — behaviorLightweightTasksLike
  ///
  /// In en, this message translates to:
  /// **'Used for lightweight tasks like title generation.'**
  String get behaviorLightweightTasksLike;

  /// CodeWalk UI string — behaviorManual
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get behaviorManual;

  /// CodeWalk UI string — behaviorNotify
  ///
  /// In en, this message translates to:
  /// **'Notify only'**
  String get behaviorNotify;

  /// CodeWalk UI string — behaviorOfficialOpenCodePermission
  ///
  /// In en, this message translates to:
  /// **'Official OpenCode permission policy is configured in `opencode.json` with allow/ask/deny rules per tool. CodeWalk keeps the official permission-request cards and adds one approved ADR-023 exception: the composer auto-approve toggle replies with `Always` and `remember: true` unconditionally to create durable session-scoped grants, and keeps the same thread-scoped continuity path active in the Android background worker.'**
  String get behaviorOfficialOpenCodePermission;

  /// CodeWalk UI string — behaviorOpenCodeBackedDefaults
  ///
  /// In en, this message translates to:
  /// **'OpenCode-backed defaults'**
  String get behaviorOpenCodeBackedDefaults;

  /// CodeWalk UI string — behaviorPermissionHandlingProvenance
  ///
  /// In en, this message translates to:
  /// **'Permission handling provenance'**
  String get behaviorPermissionHandlingProvenance;

  /// CodeWalk UI string — behaviorPermissionsVariantReasoning
  ///
  /// In en, this message translates to:
  /// **'Permissions and variant/reasoning parity stay separate until their UI can preserve advanced config safely.'**
  String get behaviorPermissionsVariantReasoning;

  /// CodeWalk UI string — behaviorPrimaryAgentAgent
  ///
  /// In en, this message translates to:
  /// **'Primary agent used when no agent is explicitly chosen.'**
  String get behaviorPrimaryAgentAgent;

  /// CodeWalk UI string — behaviorRefreshDefaults
  ///
  /// In en, this message translates to:
  /// **'Refresh defaults'**
  String get behaviorRefreshDefaults;

  /// CodeWalk UI string — behaviorSharedAcrossOpenCode
  ///
  /// In en, this message translates to:
  /// **'Shared across OpenCode clients through config.'**
  String get behaviorSharedAcrossOpenCode;

  /// CodeWalk UI string — behaviorTheseValuesWrite
  ///
  /// In en, this message translates to:
  /// **'These values write to `/config` on the active server and match official OpenCode shared config.'**
  String get behaviorTheseValuesWrite;

  /// CodeWalk UI string — cannedAddTitle
  ///
  /// In en, this message translates to:
  /// **'Add canned answer'**
  String get cannedAddTitle;

  /// CodeWalk UI string — cannedAppendAtCursor
  ///
  /// In en, this message translates to:
  /// **'Append at cursor'**
  String get cannedAppendAtCursor;

  /// CodeWalk UI string — cannedAppendAtCursorSubtitle
  ///
  /// In en, this message translates to:
  /// **'Off means replace current composer text'**
  String get cannedAppendAtCursorSubtitle;

  /// CodeWalk UI string — cannedAttachFiles
  ///
  /// In en, this message translates to:
  /// **'Attach files'**
  String get cannedAttachFiles;

  /// CodeWalk UI string — cannedEditTitle
  ///
  /// In en, this message translates to:
  /// **'Edit canned answer'**
  String get cannedEditTitle;

  /// CodeWalk UI string — cannedNewQuickReply
  ///
  /// In en, this message translates to:
  /// **'New quick reply'**
  String get cannedNewQuickReply;

  /// CodeWalk UI string — cannedNoSuggestions
  ///
  /// In en, this message translates to:
  /// **'No suggestions'**
  String get cannedNoSuggestions;

  /// CodeWalk UI string — cannedOffMeansReplace
  ///
  /// In en, this message translates to:
  /// **'Off means replace current composer text'**
  String get cannedOffMeansReplace;

  /// CodeWalk UI string — cannedQuickReply
  ///
  /// In en, this message translates to:
  /// **'New quick reply'**
  String get cannedQuickReply;

  /// CodeWalk UI string — cannedReplace
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get cannedReplace;

  /// CodeWalk UI string — cannedScopeGlobalSubtitle
  ///
  /// In en, this message translates to:
  /// **'Disable for project-only item'**
  String get cannedScopeGlobalSubtitle;

  /// CodeWalk UI string — cannedScopeGlobalUnavailableSubtitle
  ///
  /// In en, this message translates to:
  /// **'Project-only unavailable in current context'**
  String get cannedScopeGlobalUnavailableSubtitle;

  /// CodeWalk UI string — cannedSendAutomaticallySubtitle
  ///
  /// In en, this message translates to:
  /// **'Send immediately after inserting this quick reply'**
  String get cannedSendAutomaticallySubtitle;

  /// CodeWalk UI string — cannedSendImmediatelyInserting
  ///
  /// In en, this message translates to:
  /// **'Send immediately after inserting this quick reply'**
  String get cannedSendImmediatelyInserting;

  /// CodeWalk UI string — cannedTextLabel
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get cannedTextLabel;

  /// CodeWalk UI string — chatActionNext
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get chatActionNext;

  /// CodeWalk UI string — chatActiveServerUnhealthy
  ///
  /// In en, this message translates to:
  /// **'Active server is unhealthy. Sends will try once and fail fast until recovery.'**
  String get chatActiveServerUnhealthy;

  /// CodeWalk UI string — chatActiveServerUnhealthyLabel
  ///
  /// In en, this message translates to:
  /// **'Active server is unhealthy'**
  String get chatActiveServerUnhealthyLabel;

  /// CodeWalk UI string — chatAddServerToStart
  ///
  /// In en, this message translates to:
  /// **'Add a server to start chatting.'**
  String get chatAddServerToStart;

  /// CodeWalk UI string — chatAppBarMoreActions
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get chatAppBarMoreActions;

  /// CodeWalk UI string — chatAppBarPinAction
  ///
  /// In en, this message translates to:
  /// **'Pin to app bar'**
  String get chatAppBarPinAction;

  /// CodeWalk UI string — chatAppBarPinDescription
  ///
  /// In en, this message translates to:
  /// **'This action will stay visible outside the menu.'**
  String get chatAppBarPinDescription;

  /// CodeWalk UI string — chatAppBarUnpinAction
  ///
  /// In en, this message translates to:
  /// **'Unpin from app bar'**
  String get chatAppBarUnpinAction;

  /// CodeWalk UI string — chatAppBarUnpinDescription
  ///
  /// In en, this message translates to:
  /// **'This action will move back into the menu.'**
  String get chatAppBarUnpinDescription;

  /// CodeWalk UI string — chatBadgeConversationError
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" has an error.'**
  String chatBadgeConversationError(String title);

  /// CodeWalk UI string — chatBadgeConversationNeedsInput
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" needs your input.'**
  String chatBadgeConversationNeedsInput(String title);

  /// CodeWalk UI string — chatBadgeConversationNewReply
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" has a new reply.'**
  String chatBadgeConversationNewReply(String title);

  /// CodeWalk UI string — chatBadgeDataSaverActive
  ///
  /// In en, this message translates to:
  /// **'Cellular data saver is active.'**
  String get chatBadgeDataSaverActive;

  /// CodeWalk UI string — chatBadgeServerNeedsAttention
  ///
  /// In en, this message translates to:
  /// **'Server connection needs attention.'**
  String get chatBadgeServerNeedsAttention;

  /// CodeWalk UI string — chatBadgeSyncing
  ///
  /// In en, this message translates to:
  /// **'Syncing conversations...'**
  String get chatBadgeSyncing;

  /// CodeWalk UI string — chatBlockResponsePendingDescription
  ///
  /// In en, this message translates to:
  /// **'The answer will appear as a single block when this turn finishes.'**
  String get chatBlockResponsePendingDescription;

  /// CodeWalk UI string — chatBlockResponsePendingTitle
  ///
  /// In en, this message translates to:
  /// **'Generating response'**
  String get chatBlockResponsePendingTitle;

  /// CodeWalk UI string — chatCachedConversationsYet
  ///
  /// In en, this message translates to:
  /// **'No cached conversations yet'**
  String get chatCachedConversationsYet;

  /// CodeWalk UI string — chatChangedFilesAvailable
  ///
  /// In en, this message translates to:
  /// **'No changed files are available for this session.'**
  String get chatChangedFilesAvailable;

  /// CodeWalk UI string — chatChildrenChatProviderCurrentSessionChildren
  ///
  /// In en, this message translates to:
  /// **'Children: {length}'**
  String chatChildrenChatProviderCurrentSessionChildren(int length);

  /// CodeWalk UI string — chatChooseAgent
  ///
  /// In en, this message translates to:
  /// **'Select agent'**
  String get chatChooseAgent;

  /// CodeWalk UI string — chatChooseDirectory
  ///
  /// In en, this message translates to:
  /// **'Choose Directory'**
  String get chatChooseDirectory;

  /// CodeWalk UI string — chatChooseEffort
  ///
  /// In en, this message translates to:
  /// **'Choose effort'**
  String get chatChooseEffort;

  /// CodeWalk UI string — chatChooseFolderOpen
  ///
  /// In en, this message translates to:
  /// **'Choose a folder to open as project context.'**
  String get chatChooseFolderOpen;

  /// CodeWalk UI string — chatChooseModel
  ///
  /// In en, this message translates to:
  /// **'Choose model'**
  String get chatChooseModel;

  /// CodeWalk UI string — chatClose
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get chatClose;

  /// CodeWalk UI string — chatCloseProject
  ///
  /// In en, this message translates to:
  /// **'Close {project}'**
  String chatCloseProject(String project);

  /// CodeWalk UI string — chatCollapseGroup
  ///
  /// In en, this message translates to:
  /// **'Collapse group'**
  String get chatCollapseGroup;

  /// CodeWalk UI string — chatCommandDescriptionProject
  ///
  /// In en, this message translates to:
  /// **'Project command'**
  String get chatCommandDescriptionProject;

  /// CodeWalk UI string — chatCommandSourceGeneric
  ///
  /// In en, this message translates to:
  /// **'command'**
  String get chatCommandSourceGeneric;

  /// CodeWalk UI string — chatCommandSourceProject
  ///
  /// In en, this message translates to:
  /// **'project'**
  String get chatCommandSourceProject;

  /// CodeWalk UI string — chatCompactContext
  ///
  /// In en, this message translates to:
  /// **'Compact Context'**
  String get chatCompactContext;

  /// CodeWalk UI string — chatComposerHintShell
  ///
  /// In en, this message translates to:
  /// **'Shell command (Esc to exit)'**
  String get chatComposerHintShell;

  /// CodeWalk UI string — chatComposerPlaceholder
  ///
  /// In en, this message translates to:
  /// **'Type your needs...'**
  String get chatComposerPlaceholder;

  /// CodeWalk UI string — chatConversation
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get chatConversation;

  /// CodeWalk UI string — chatConversations
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get chatConversations;

  /// CodeWalk UI string — chatConversationsPane
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get chatConversationsPane;

  /// CodeWalk UI string — chatCostLabel
  ///
  /// In en, this message translates to:
  /// **'Cost: \${cost}'**
  String chatCostLabel(double cost);

  /// CodeWalk UI string — chatCouldNotRefreshSession
  ///
  /// In en, this message translates to:
  /// **'Could not refresh this conversation'**
  String get chatCouldNotRefreshSession;

  /// CodeWalk UI string — chatCurrent
  ///
  /// In en, this message translates to:
  /// **'Use current'**
  String get chatCurrent;

  /// CodeWalk UI string — chatDescriptionChildren
  ///
  /// In en, this message translates to:
  /// **'Children: {count}'**
  String chatDescriptionChildren(int count);

  /// CodeWalk UI string — chatDescriptionCloseApp
  ///
  /// In en, this message translates to:
  /// **'Close app using platform close behavior'**
  String get chatDescriptionCloseApp;

  /// CodeWalk UI string — chatDescriptionCycleModels
  ///
  /// In en, this message translates to:
  /// **'Cycle recent models'**
  String get chatDescriptionCycleModels;

  /// CodeWalk UI string — chatDescriptionCycleVariant
  ///
  /// In en, this message translates to:
  /// **'Cycle model variant'**
  String get chatDescriptionCycleVariant;

  /// CodeWalk UI string — chatDescriptionDiffFilesZero
  ///
  /// In en, this message translates to:
  /// **'Diff files: 0'**
  String get chatDescriptionDiffFilesZero;

  /// CodeWalk UI string — chatDescriptionFocusInput
  ///
  /// In en, this message translates to:
  /// **'Focus message input'**
  String get chatDescriptionFocusInput;

  /// CodeWalk UI string — chatDescriptionFocusOrCloseDrawer
  ///
  /// In en, this message translates to:
  /// **'Focus input (or close drawer when open)'**
  String get chatDescriptionFocusOrCloseDrawer;

  /// CodeWalk UI string — chatDescriptionForceExit
  ///
  /// In en, this message translates to:
  /// **'Force-exit the app'**
  String get chatDescriptionForceExit;

  /// CodeWalk UI string — chatDescriptionNewConversation
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get chatDescriptionNewConversation;

  /// CodeWalk UI string — chatDescriptionNextAgent
  ///
  /// In en, this message translates to:
  /// **'Next agent'**
  String get chatDescriptionNextAgent;

  /// CodeWalk UI string — chatDescriptionOpenProjects
  ///
  /// In en, this message translates to:
  /// **'Use this button to open your projects and conversations.'**
  String get chatDescriptionOpenProjects;

  /// CodeWalk UI string — chatDescriptionOpenSettings
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get chatDescriptionOpenSettings;

  /// CodeWalk UI string — chatDescriptionPreviousAgent
  ///
  /// In en, this message translates to:
  /// **'Previous agent'**
  String get chatDescriptionPreviousAgent;

  /// CodeWalk UI string — chatDescriptionProjectCommand
  ///
  /// In en, this message translates to:
  /// **'Project command'**
  String get chatDescriptionProjectCommand;

  /// CodeWalk UI string — chatDescriptionQuickOpen
  ///
  /// In en, this message translates to:
  /// **'Quick open files'**
  String get chatDescriptionQuickOpen;

  /// CodeWalk UI string — chatDescriptionRefreshData
  ///
  /// In en, this message translates to:
  /// **'Refresh chat data'**
  String get chatDescriptionRefreshData;

  /// CodeWalk UI string — chatDescriptionStopResponse
  ///
  /// In en, this message translates to:
  /// **'Stop active response (while responding)'**
  String get chatDescriptionStopResponse;

  /// CodeWalk UI string — chatDescriptionSwitchProject
  ///
  /// In en, this message translates to:
  /// **'Use this button to switch project folders and context.'**
  String get chatDescriptionSwitchProject;

  /// CodeWalk UI string — chatDescriptionVoiceInput
  ///
  /// In en, this message translates to:
  /// **'Start or stop voice input'**
  String get chatDescriptionVoiceInput;

  /// CodeWalk UI string — chatDiffFiles
  ///
  /// In en, this message translates to:
  /// **'Diff files: 0'**
  String get chatDiffFiles;

  /// CodeWalk UI string — chatDisplay
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get chatDisplay;

  /// CodeWalk UI string — chatDisplayToggles
  ///
  /// In en, this message translates to:
  /// **'Display toggles'**
  String get chatDisplayToggles;

  /// CodeWalk UI string — chatDoubleESCStop
  ///
  /// In en, this message translates to:
  /// **'Double ESC to stop'**
  String get chatDoubleESCStop;

  /// CodeWalk UI string — chatEffortLockedSubConversation
  ///
  /// In en, this message translates to:
  /// **'Effort locked in sub-conversation'**
  String get chatEffortLockedSubConversation;

  /// CodeWalk UI string — chatExpandGroup
  ///
  /// In en, this message translates to:
  /// **'Expand group'**
  String get chatExpandGroup;

  /// CodeWalk UI string — chatExportCanceled
  ///
  /// In en, this message translates to:
  /// **'Session export canceled'**
  String get chatExportCanceled;

  /// CodeWalk UI string — chatFailedToLoadDirectories
  ///
  /// In en, this message translates to:
  /// **'Failed to load directories'**
  String get chatFailedToLoadDirectories;

  /// CodeWalk UI string — chatFailedToLoadFile
  ///
  /// In en, this message translates to:
  /// **'Failed to load file'**
  String get chatFailedToLoadFile;

  /// CodeWalk UI string — chatFailedToRefreshProviders
  ///
  /// In en, this message translates to:
  /// **'Failed to refresh providers and models'**
  String get chatFailedToRefreshProviders;

  /// CodeWalk UI string — chatFailedToRefreshSubConversations
  ///
  /// In en, this message translates to:
  /// **'Failed to refresh sub-conversations. Please try again.'**
  String get chatFailedToRefreshSubConversations;

  /// CodeWalk UI string — chatFailedToStopResponse
  ///
  /// In en, this message translates to:
  /// **'Failed to stop current response'**
  String get chatFailedToStopResponse;

  /// CodeWalk UI string — chatFileExplorerContents
  ///
  /// In en, this message translates to:
  /// **'Contents'**
  String get chatFileExplorerContents;

  /// CodeWalk UI string — chatFileExplorerNames
  ///
  /// In en, this message translates to:
  /// **'Names'**
  String get chatFileExplorerNames;

  /// CodeWalk UI string — chatFilterActive
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get chatFilterActive;

  /// CodeWalk UI string — chatFilterAll
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get chatFilterAll;

  /// CodeWalk UI string — chatFilterArchived
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get chatFilterArchived;

  /// CodeWalk UI string — chatFilterDirectories
  ///
  /// In en, this message translates to:
  /// **'Filter directories'**
  String get chatFilterDirectories;

  /// CodeWalk UI string — chatFilterSessions
  ///
  /// In en, this message translates to:
  /// **'Filter sessions'**
  String get chatFilterSessions;

  /// CodeWalk UI string — chatForkFailed
  ///
  /// In en, this message translates to:
  /// **'Failed to fork conversation'**
  String get chatForkFailed;

  /// CodeWalk UI string — chatForked
  ///
  /// In en, this message translates to:
  /// **'Conversation forked'**
  String get chatForked;

  /// CodeWalk UI string — chatGoToFirst
  ///
  /// In en, this message translates to:
  /// **'Go to first message'**
  String get chatGoToFirst;

  /// CodeWalk UI string — chatGoToLatest
  ///
  /// In en, this message translates to:
  /// **'Go to latest message'**
  String get chatGoToLatest;

  /// CodeWalk UI string — chatGroupMessageCountMessages
  ///
  /// In en, this message translates to:
  /// **'{messageCount} messages hidden before {compactionLabel} compaction'**
  String chatGroupMessageCountMessages(
    String compactionLabel,
    String messageCount,
  );

  /// CodeWalk UI string — chatHelloAssistant
  ///
  /// In en, this message translates to:
  /// **'Hello! I am your AI assistant'**
  String get chatHelloAssistant;

  /// CodeWalk UI string — chatHelp
  ///
  /// In en, this message translates to:
  /// **'How can I help you?'**
  String get chatHelp;

  /// CodeWalk UI string — chatHelpMessage
  ///
  /// In en, this message translates to:
  /// **'Use @ for mentions, ! for shell, / for commands'**
  String get chatHelpMessage;

  /// CodeWalk UI string — chatHideConversationsSidebar
  ///
  /// In en, this message translates to:
  /// **'Hide Conversations sidebar'**
  String get chatHideConversationsSidebar;

  /// CodeWalk UI string — chatHideUtilitySidebar
  ///
  /// In en, this message translates to:
  /// **'Hide Utility sidebar'**
  String get chatHideUtilitySidebar;

  /// CodeWalk UI string — chatHistoryCollapsed
  ///
  /// In en, this message translates to:
  /// **'Previous history is collapsed'**
  String get chatHistoryCollapsed;

  /// CodeWalk UI string — chatHistoryHideEarlier
  ///
  /// In en, this message translates to:
  /// **'Hide earlier messages'**
  String get chatHistoryHideEarlier;

  /// CodeWalk UI string — chatHistoryMessagesHidden
  ///
  /// In en, this message translates to:
  /// **'{count} messages hidden before {label} compaction'**
  String chatHistoryMessagesHidden(int count, String label);

  /// CodeWalk UI string — chatHistoryShowEarlier
  ///
  /// In en, this message translates to:
  /// **'Show earlier messages'**
  String get chatHistoryShowEarlier;

  /// CodeWalk UI string — chatKeepWorking
  ///
  /// In en, this message translates to:
  /// **'Keep working'**
  String get chatKeepWorking;

  /// CodeWalk UI string — chatLargeContentSkipped
  ///
  /// In en, this message translates to:
  /// **'Large or malformed content was skipped for stability.'**
  String get chatLargeContentSkipped;

  /// CodeWalk UI string — chatLatestToolActivity
  ///
  /// In en, this message translates to:
  /// **'Latest tool activity stays inside this bounded panel to keep the chat viewport stable.'**
  String get chatLatestToolActivity;

  /// CodeWalk UI string — chatLoadMore
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get chatLoadMore;

  /// CodeWalk UI string — chatLoadingProjectContext
  ///
  /// In en, this message translates to:
  /// **'Loading project context...'**
  String get chatLoadingProjectContext;

  /// CodeWalk UI string — chatMainConversationUnavailable
  ///
  /// In en, this message translates to:
  /// **'Main conversation is not available yet.'**
  String get chatMainConversationUnavailable;

  /// CodeWalk UI string — chatParentConversationUnavailable
  ///
  /// In en, this message translates to:
  /// **'Parent conversation is not available yet.'**
  String get chatParentConversationUnavailable;

  /// CodeWalk UI string — chatMentionAgentSubtitle
  ///
  /// In en, this message translates to:
  /// **'agent'**
  String get chatMentionAgentSubtitle;

  /// CodeWalk UI string — chatMentionFileSubtitle
  ///
  /// In en, this message translates to:
  /// **'file'**
  String get chatMentionFileSubtitle;

  /// CodeWalk UI string — chatMentionSymbolSubtitle
  ///
  /// In en, this message translates to:
  /// **'symbol'**
  String get chatMentionSymbolSubtitle;

  /// CodeWalk UI string — chatMessageAttachedFile
  ///
  /// In en, this message translates to:
  /// **'Attached file'**
  String get chatMessageAttachedFile;

  /// CodeWalk UI string — chatMessageDetails
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get chatMessageDetails;

  /// CodeWalk UI string — chatMessageHide
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get chatMessageHide;

  /// CodeWalk UI string — chatMessageLess
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get chatMessageLess;

  /// CodeWalk UI string — chatMessageMessagePartUnavailable
  ///
  /// In en, this message translates to:
  /// **'Message part unavailable'**
  String get chatMessageMessagePartUnavailable;

  /// CodeWalk UI string — chatMessageMetadataAvailable
  ///
  /// In en, this message translates to:
  /// **'No metadata available'**
  String get chatMessageMetadataAvailable;

  /// CodeWalk UI string — chatMessageModelMessageModelId
  ///
  /// In en, this message translates to:
  /// **'Model: {modelId}'**
  String chatMessageModelMessageModelId(String modelId);

  /// CodeWalk UI string — chatMessageMore
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get chatMessageMore;

  /// CodeWalk UI string — chatMessageOpenFile
  ///
  /// In en, this message translates to:
  /// **'Open file'**
  String get chatMessageOpenFile;

  /// CodeWalk UI string — chatMessageProviderMessageProviderId
  ///
  /// In en, this message translates to:
  /// **'Provider: {providerId}'**
  String chatMessageProviderMessageProviderId(String providerId);

  /// CodeWalk UI string — chatMessageRewindEdit
  ///
  /// In en, this message translates to:
  /// **'Rewind and edit from here'**
  String get chatMessageRewindEdit;

  /// CodeWalk UI string — chatMessageRunningTask
  ///
  /// In en, this message translates to:
  /// **'Running task'**
  String get chatMessageRunningTask;

  /// CodeWalk UI string — chatMessageSaveFile
  ///
  /// In en, this message translates to:
  /// **'Save file'**
  String get chatMessageSaveFile;

  /// CodeWalk UI string — chatMessageShow
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get chatMessageShow;

  /// CodeWalk UI string — chatMessageShowQuestion
  ///
  /// In en, this message translates to:
  /// **'View question'**
  String get chatMessageShowQuestion;

  /// CodeWalk UI string — chatMessageShowLess
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get chatMessageShowLess;

  /// CodeWalk UI string — chatMessageShowLessCompact
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get chatMessageShowLessCompact;

  /// CodeWalk UI string — chatMessageShowMore
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get chatMessageShowMore;

  /// CodeWalk UI string — chatMessageShowMoreCompact
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get chatMessageShowMoreCompact;

  /// CodeWalk UI string — chatMessageThinking
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get chatMessageThinking;

  /// CodeWalk UI string — chatMessageThinkingProcess
  ///
  /// In en, this message translates to:
  /// **'Thinking Process'**
  String get chatMessageThinkingProcess;

  /// CodeWalk UI string — chatMessageToolCall
  ///
  /// In en, this message translates to:
  /// **'1 tool call'**
  String get chatMessageToolCall;

  /// CodeWalk UI string — chatMessageToolCalls
  ///
  /// In en, this message translates to:
  /// **'{count} tool calls'**
  String chatMessageToolCalls(int count);

  /// CodeWalk UI string — chatMessageToolCommand
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get chatMessageToolCommand;

  /// CodeWalk UI string — chatMessageToolCommandTruncated
  ///
  /// In en, this message translates to:
  /// **'Command preview truncated for stability.'**
  String get chatMessageToolCommandTruncated;

  /// CodeWalk UI string — chatMessageToolDiffOmitted
  ///
  /// In en, this message translates to:
  /// **'Diff preview omitted: edit payload is too large to render safely on mobile.'**
  String get chatMessageToolDiffOmitted;

  /// CodeWalk UI string — chatMessageToolInput
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get chatMessageToolInput;

  /// CodeWalk UI string — chatMessageToolInputTruncated
  ///
  /// In en, this message translates to:
  /// **'Input preview truncated for stability.'**
  String get chatMessageToolInputTruncated;

  /// CodeWalk UI string — chatMessageToolOutputTruncated
  ///
  /// In en, this message translates to:
  /// **'Large tool output preview truncated for app stability.'**
  String get chatMessageToolOutputTruncated;

  /// CodeWalk UI string — chatMessageToolQueuedCount
  ///
  /// In en, this message translates to:
  /// **'{count} queued'**
  String chatMessageToolQueuedCount(int count);

  /// CodeWalk UI string — chatMessageToolRunningCount
  ///
  /// In en, this message translates to:
  /// **'{count} running'**
  String chatMessageToolRunningCount(int count);

  /// CodeWalk UI string — chatMessageToolStatusInProgress
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get chatMessageToolStatusInProgress;

  /// CodeWalk UI string — chatMessageToolStatusNeedsAttention
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get chatMessageToolStatusNeedsAttention;

  /// CodeWalk UI string — chatMessageToolStatusQueued
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get chatMessageToolStatusQueued;

  /// CodeWalk UI string — chatMessageYou
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get chatMessageYou;

  /// CodeWalk UI string — chatModelLockedSubConversation
  ///
  /// In en, this message translates to:
  /// **'Model locked in sub-conversation'**
  String get chatModelLockedSubConversation;

  /// CodeWalk UI string — chatNewChat
  ///
  /// In en, this message translates to:
  /// **'New Chat'**
  String get chatNewChat;

  /// CodeWalk UI string — chatNewChatTourDescription
  ///
  /// In en, this message translates to:
  /// **'Start a new conversation here.'**
  String get chatNewChatTourDescription;

  /// CodeWalk UI string — chatNewChatTourTitle
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get chatNewChatTourTitle;

  /// CodeWalk UI string — chatNoConversationsInProject
  ///
  /// In en, this message translates to:
  /// **'No conversations in this project.'**
  String get chatNoConversationsInProject;

  /// CodeWalk UI string — chatNoServerYet
  ///
  /// In en, this message translates to:
  /// **'No server configured yet'**
  String get chatNoServerYet;

  /// CodeWalk UI string — chatNoSessionSelected
  ///
  /// In en, this message translates to:
  /// **'Select or create a conversation to start chatting'**
  String get chatNoSessionSelected;

  /// CodeWalk UI string — chatNoSubConversationFound
  ///
  /// In en, this message translates to:
  /// **'No sub-conversation found for this task.'**
  String get chatNoSubConversationFound;

  /// CodeWalk UI string — chatOpenFiles
  ///
  /// In en, this message translates to:
  /// **'Open Files'**
  String get chatOpenFiles;

  /// CodeWalk UI string — chatOpenProject
  ///
  /// In en, this message translates to:
  /// **'Open project'**
  String get chatOpenProject;

  /// CodeWalk UI string — chatOpenProjectFolder
  ///
  /// In en, this message translates to:
  /// **'Open project folder...'**
  String get chatOpenProjectFolder;

  /// CodeWalk UI string — chatOpenProjectToLoad
  ///
  /// In en, this message translates to:
  /// **'Open project to load conversations.'**
  String get chatOpenProjectToLoad;

  /// CodeWalk UI string — chatOpenSidebar
  ///
  /// In en, this message translates to:
  /// **'Open sidebar'**
  String get chatOpenSidebar;

  /// CodeWalk UI string — chatPageStatusAutomaticCompactionExplanation
  ///
  /// In en, this message translates to:
  /// **'Automatic compaction happens as context usage grows.'**
  String get chatPageStatusAutomaticCompactionExplanation;

  /// CodeWalk UI string — chatPageStatusCompactNow
  ///
  /// In en, this message translates to:
  /// **'Compact now'**
  String get chatPageStatusCompactNow;

  /// CodeWalk UI string — chatPageStatusCompacting
  ///
  /// In en, this message translates to:
  /// **'Compacting...'**
  String get chatPageStatusCompacting;

  /// CodeWalk UI string — chatPageStatusCompactingContextNow
  ///
  /// In en, this message translates to:
  /// **'Compacting context now...'**
  String get chatPageStatusCompactingContextNow;

  /// CodeWalk UI string — chatPageStatusContextCompacted
  ///
  /// In en, this message translates to:
  /// **'Context compacted'**
  String get chatPageStatusContextCompacted;

  /// CodeWalk UI string — chatPageStatusContextUsage
  ///
  /// In en, this message translates to:
  /// **'Context usage'**
  String get chatPageStatusContextUsage;

  /// CodeWalk UI string — chatPageStatusCost
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get chatPageStatusCost;

  /// CodeWalk UI string — chatPageStatusFailedToCompactContext
  ///
  /// In en, this message translates to:
  /// **'Failed to compact context'**
  String get chatPageStatusFailedToCompactContext;

  /// CodeWalk UI string — chatPageStatusLimit
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get chatPageStatusLimit;

  /// CodeWalk UI string — chatPageStatusManageServers
  ///
  /// In en, this message translates to:
  /// **'Manage Servers'**
  String get chatPageStatusManageServers;

  /// CodeWalk UI string — chatPageStatusSaver
  ///
  /// In en, this message translates to:
  /// **'Saver'**
  String get chatPageStatusSaver;

  /// CodeWalk UI string — chatPageStatusServer
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get chatPageStatusServer;

  /// CodeWalk UI string — chatPageStatusSwitchServer
  ///
  /// In en, this message translates to:
  /// **'Switch Server'**
  String get chatPageStatusSwitchServer;

  /// CodeWalk UI string — chatPageStatusTokens
  ///
  /// In en, this message translates to:
  /// **'Tokens'**
  String get chatPageStatusTokens;

  /// CodeWalk UI string — chatPageStatusUsage
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get chatPageStatusUsage;

  /// CodeWalk UI string — chatPageStatusUsagePercent
  ///
  /// In en, this message translates to:
  /// **'{usagePercent}'**
  String chatPageStatusUsagePercent(int usagePercent);

  /// CodeWalk UI string — chatPermissionAutoApproveOff
  ///
  /// In en, this message translates to:
  /// **'Permission auto-approve is off'**
  String get chatPermissionAutoApproveOff;

  /// CodeWalk UI string — chatPermissionAutoApproveOn
  ///
  /// In en, this message translates to:
  /// **'Permission auto-approve is on'**
  String get chatPermissionAutoApproveOn;

  /// CodeWalk UI string — chatProjectContext
  ///
  /// In en, this message translates to:
  /// **'Project Context'**
  String get chatProjectContext;

  /// CodeWalk UI string — chatProjectContext2
  ///
  /// In en, this message translates to:
  /// **'Project context'**
  String get chatProjectContext2;

  /// CodeWalk UI string — chatRealtimeGlobalEvent
  ///
  /// In en, this message translates to:
  /// **'global event'**
  String get chatRealtimeGlobalEvent;

  /// CodeWalk UI string — chatRealtimeGlobalEventReason
  ///
  /// In en, this message translates to:
  /// **'global event ({reason})'**
  String chatRealtimeGlobalEventReason(String reason);

  /// CodeWalk UI string — chatRealtimeGlobalEventStale
  ///
  /// In en, this message translates to:
  /// **'global event (stale generation)'**
  String get chatRealtimeGlobalEventStale;

  /// CodeWalk UI string — chatRealtimeMessageStreamReason
  ///
  /// In en, this message translates to:
  /// **'message stream ({reason})'**
  String chatRealtimeMessageStreamReason(String reason);

  /// CodeWalk UI string — chatRealtimeRealtimeEvent
  ///
  /// In en, this message translates to:
  /// **'realtime event'**
  String get chatRealtimeRealtimeEvent;

  /// CodeWalk UI string — chatRealtimeRealtimeEventReason
  ///
  /// In en, this message translates to:
  /// **'realtime event ({reason})'**
  String chatRealtimeRealtimeEventReason(String reason);

  /// CodeWalk UI string — chatRealtimeRealtimeEventStale
  ///
  /// In en, this message translates to:
  /// **'realtime event (stale generation)'**
  String get chatRealtimeRealtimeEventStale;

  /// CodeWalk UI string — chatRealtimeReconnectingServerTry
  ///
  /// In en, this message translates to:
  /// **'Reconnecting to the server. Try again in a moment.'**
  String get chatRealtimeReconnectingServerTry;

  /// CodeWalk UI string — chatReasoning
  ///
  /// In en, this message translates to:
  /// **'Reasoning...'**
  String get chatReasoning;

  /// CodeWalk UI string — chatRecentSessions
  ///
  /// In en, this message translates to:
  /// **'Recent sessions'**
  String get chatRecentSessions;

  /// CodeWalk UI string — chatRecentSessionsToggle
  ///
  /// In en, this message translates to:
  /// **'Recent sessions'**
  String get chatRecentSessionsToggle;

  /// CodeWalk UI string — chatRedoLastTurn
  ///
  /// In en, this message translates to:
  /// **'Redo last undone turn'**
  String get chatRedoLastTurn;

  /// CodeWalk UI string — chatRedoNothing
  ///
  /// In en, this message translates to:
  /// **'Nothing to redo in this session'**
  String get chatRedoNothing;

  /// CodeWalk UI string — chatRefresh
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get chatRefresh;

  /// CodeWalk UI string — chatRefreshConversation
  ///
  /// In en, this message translates to:
  /// **'Could not refresh this conversation'**
  String get chatRefreshConversation;

  /// CodeWalk UI string — chatRefreshProjects
  ///
  /// In en, this message translates to:
  /// **'Refresh projects'**
  String get chatRefreshProjects;

  /// CodeWalk UI string — chatRefreshSessionDetails
  ///
  /// In en, this message translates to:
  /// **'Refresh session details'**
  String get chatRefreshSessionDetails;

  /// CodeWalk UI string — chatRemoveDisplayNameHistory
  ///
  /// In en, this message translates to:
  /// **'Remove {displayName} from history'**
  String chatRemoveDisplayNameHistory(String displayName);

  /// CodeWalk UI string — chatRetry
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get chatRetry;

  /// CodeWalk UI string — chatRetry2
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get chatRetry2;

  /// CodeWalk UI string — chatRetryRefresh
  ///
  /// In en, this message translates to:
  /// **'Retry refresh'**
  String get chatRetryRefresh;

  /// CodeWalk UI string — chatRetryingModelRequest
  ///
  /// In en, this message translates to:
  /// **'Retrying model request...'**
  String get chatRetryingModelRequest;

  /// CodeWalk UI string — chatReturnToMainConversation
  ///
  /// In en, this message translates to:
  /// **'Return to main conversation'**
  String get chatReturnToMainConversation;

  /// CodeWalk UI string — chatReturnToParentConversation
  ///
  /// In en, this message translates to:
  /// **'Return to parent conversation'**
  String get chatReturnToParentConversation;

  /// CodeWalk UI string — chatReviewChanges
  ///
  /// In en, this message translates to:
  /// **'Review changes'**
  String get chatReviewChanges;

  /// CodeWalk UI string — chatSearchConversations
  ///
  /// In en, this message translates to:
  /// **'Search conversations'**
  String get chatSearchConversations;

  /// CodeWalk UI string — chatSearchNextResult
  ///
  /// In en, this message translates to:
  /// **'Next result'**
  String get chatSearchNextResult;

  /// CodeWalk UI string — chatSearchNoResults
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get chatSearchNoResults;

  /// CodeWalk UI string — chatSearchPreviousResult
  ///
  /// In en, this message translates to:
  /// **'Previous result'**
  String get chatSearchPreviousResult;

  /// CodeWalk UI string — chatSearchResultCount
  ///
  /// In en, this message translates to:
  /// **'Message {current} of {total}'**
  String chatSearchResultCount(int current, int total);

  /// CodeWalk UI string — chatSearchTimeline
  ///
  /// In en, this message translates to:
  /// **'Search timeline'**
  String get chatSearchTimeline;

  /// CodeWalk UI string — chatSelectDirectory
  ///
  /// In en, this message translates to:
  /// **'Select directory'**
  String get chatSelectDirectory;

  /// CodeWalk UI string — chatSelectOrCreate
  ///
  /// In en, this message translates to:
  /// **'Select or create a conversation to start chatting'**
  String get chatSelectOrCreate;

  /// CodeWalk UI string — chatSelectProjectBelow
  ///
  /// In en, this message translates to:
  /// **'Select a project below.'**
  String get chatSelectProjectBelow;

  /// CodeWalk UI string — chatServerSelectedModel
  ///
  /// In en, this message translates to:
  /// **'Server-selected model'**
  String get chatServerSelectedModel;

  /// CodeWalk UI string — chatSessionActions
  ///
  /// In en, this message translates to:
  /// **'Session actions'**
  String get chatSessionActions;

  /// CodeWalk UI string — chatSessionChatSessionSession
  ///
  /// In en, this message translates to:
  /// **'Chat session: {title}'**
  String chatSessionChatSessionSession(String title);

  /// CodeWalk UI string — chatSessionConversationNextAction
  ///
  /// In en, this message translates to:
  /// **'Conversation {nextAction}'**
  String chatSessionConversationNextAction(String nextAction);

  /// CodeWalk UI string — chatSessionConversations
  ///
  /// In en, this message translates to:
  /// **'No conversations'**
  String get chatSessionConversations;

  /// CodeWalk UI string — chatSessionCreateConversationStart
  ///
  /// In en, this message translates to:
  /// **'Create a new conversation to start chatting'**
  String get chatSessionCreateConversationStart;

  /// CodeWalk UI string — chatSessionTabsToggle
  ///
  /// In en, this message translates to:
  /// **'Session tabs'**
  String get chatSessionTabsToggle;

  /// CodeWalk UI string — chatSessionsLength
  ///
  /// In en, this message translates to:
  /// **'{length}'**
  String chatSessionsLength(int length);

  /// CodeWalk UI string — chatSetUpServer
  ///
  /// In en, this message translates to:
  /// **'Set up server'**
  String get chatSetUpServer;

  /// CodeWalk UI string — chatSettings
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get chatSettings;

  /// CodeWalk UI string — chatShortcutsCloseApp
  ///
  /// In en, this message translates to:
  /// **'Close app using platform close behavior'**
  String get chatShortcutsCloseApp;

  /// CodeWalk UI string — chatShortcutsCycleModels
  ///
  /// In en, this message translates to:
  /// **'Cycle recent models'**
  String get chatShortcutsCycleModels;

  /// CodeWalk UI string — chatShortcutsCycleVariant
  ///
  /// In en, this message translates to:
  /// **'Cycle model variant'**
  String get chatShortcutsCycleVariant;

  /// CodeWalk UI string — chatShortcutsFocusInput
  ///
  /// In en, this message translates to:
  /// **'Focus message input'**
  String get chatShortcutsFocusInput;

  /// CodeWalk UI string — chatShortcutsFocusInputCloseDrawer
  ///
  /// In en, this message translates to:
  /// **'Focus input (or close drawer when open)'**
  String get chatShortcutsFocusInputCloseDrawer;

  /// CodeWalk UI string — chatShortcutsForceExit
  ///
  /// In en, this message translates to:
  /// **'Force-exit the app'**
  String get chatShortcutsForceExit;

  /// CodeWalk UI string — chatShortcutsNewConversation
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get chatShortcutsNewConversation;

  /// CodeWalk UI string — chatShortcutsNextAgent
  ///
  /// In en, this message translates to:
  /// **'Next agent'**
  String get chatShortcutsNextAgent;

  /// CodeWalk UI string — chatShortcutsOpenSettings
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get chatShortcutsOpenSettings;

  /// CodeWalk UI string — chatShortcutsPreviousAgent
  ///
  /// In en, this message translates to:
  /// **'Previous agent'**
  String get chatShortcutsPreviousAgent;

  /// CodeWalk UI string — chatShortcutsQuickOpen
  ///
  /// In en, this message translates to:
  /// **'Quick open files'**
  String get chatShortcutsQuickOpen;

  /// CodeWalk UI string — chatShortcutsRefreshChat
  ///
  /// In en, this message translates to:
  /// **'Refresh chat data'**
  String get chatShortcutsRefreshChat;

  /// CodeWalk UI string — chatShortcutsStartStopVoice
  ///
  /// In en, this message translates to:
  /// **'Start or stop voice input'**
  String get chatShortcutsStartStopVoice;

  /// CodeWalk UI string — chatShortcutsStopResponse
  ///
  /// In en, this message translates to:
  /// **'Stop active response (while responding)'**
  String get chatShortcutsStopResponse;

  /// CodeWalk UI string — chatSidebarAccess
  ///
  /// In en, this message translates to:
  /// **'Sidebar access'**
  String get chatSidebarAccess;

  /// CodeWalk UI string — chatSortMostRecent
  ///
  /// In en, this message translates to:
  /// **'Most Recent'**
  String get chatSortMostRecent;

  /// CodeWalk UI string — chatSortOldest
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get chatSortOldest;

  /// CodeWalk UI string — chatSortRecent
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get chatSortRecent;

  /// CodeWalk UI string — chatSortSessions
  ///
  /// In en, this message translates to:
  /// **'Sort sessions'**
  String get chatSortSessions;

  /// CodeWalk UI string — chatSortTitle
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get chatSortTitle;

  /// CodeWalk UI string — chatStartVoiceInput
  ///
  /// In en, this message translates to:
  /// **'Start voice input'**
  String get chatStartVoiceInput;

  /// CodeWalk UI string — chatStartingVoiceInput
  ///
  /// In en, this message translates to:
  /// **'Starting voice input'**
  String get chatStartingVoiceInput;

  /// CodeWalk UI string — chatStatusBusy
  ///
  /// In en, this message translates to:
  /// **'Status: Busy'**
  String get chatStatusBusy;

  /// CodeWalk UI string — chatStatusPatching
  ///
  /// In en, this message translates to:
  /// **'Patching'**
  String get chatStatusPatching;

  /// CodeWalk UI string — chatStatusPatchingMultipleFiles
  ///
  /// In en, this message translates to:
  /// **'Patching {count} files'**
  String chatStatusPatchingMultipleFiles(int count);

  /// CodeWalk UI string — chatStatusPatchingOneFile
  ///
  /// In en, this message translates to:
  /// **'Patching 1 file'**
  String get chatStatusPatchingOneFile;

  /// CodeWalk UI string — chatStatusRetry
  ///
  /// In en, this message translates to:
  /// **'Status: Retry'**
  String get chatStatusRetry;

  /// CodeWalk UI string — chatStatusRetryCount
  ///
  /// In en, this message translates to:
  /// **'Status: Retry #{count}'**
  String chatStatusRetryCount(int count);

  /// CodeWalk UI string — chatStatusSubsession
  ///
  /// In en, this message translates to:
  /// **'Subsession'**
  String get chatStatusSubsession;

  /// CodeWalk UI string — chatStatusThinking
  ///
  /// In en, this message translates to:
  /// **'Thinking...'**
  String get chatStatusThinking;

  /// CodeWalk UI string — chatStopVoiceInput
  ///
  /// In en, this message translates to:
  /// **'Stop voice input'**
  String get chatStopVoiceInput;

  /// CodeWalk UI string — chatSyncLabel
  ///
  /// In en, this message translates to:
  /// **'Sync: {label}'**
  String chatSyncLabel(String label);

  /// CodeWalk UI string — chatTasks
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get chatTasks;

  /// CodeWalk UI string — chatTasksAvailableSession
  ///
  /// In en, this message translates to:
  /// **'No tasks are available for this session.'**
  String get chatTasksAvailableSession;

  /// CodeWalk UI string — chatTipAcceptanceCriteria
  ///
  /// In en, this message translates to:
  /// **'Tip: Add acceptance criteria for larger changes'**
  String get chatTipAcceptanceCriteria;

  /// CodeWalk UI string — chatTipAskForPlan
  ///
  /// In en, this message translates to:
  /// **'Tip: Ask for a plan first on large tasks'**
  String get chatTipAskForPlan;

  /// CodeWalk UI string — chatTipBeSpecific
  ///
  /// In en, this message translates to:
  /// **'Tip: Be specific — shorter prompts get faster answers'**
  String get chatTipBeSpecific;

  /// CodeWalk UI string — chatTipBreakTasks
  ///
  /// In en, this message translates to:
  /// **'Tip: Break large tasks into smaller prompts'**
  String get chatTipBreakTasks;

  /// CodeWalk UI string — chatTipCompareOptions
  ///
  /// In en, this message translates to:
  /// **'Tip: Ask for alternatives when tradeoffs are unclear'**
  String get chatTipCompareOptions;

  /// CodeWalk UI string — chatTipContextKnob
  ///
  /// In en, this message translates to:
  /// **'Tip: Tap the context knob to see usage details'**
  String get chatTipContextKnob;

  /// CodeWalk UI string — chatTipDefineVerification
  ///
  /// In en, this message translates to:
  /// **'Tip: Say which tests or checks should pass'**
  String get chatTipDefineVerification;

  /// CodeWalk UI string — chatTipLongPressSend
  ///
  /// In en, this message translates to:
  /// **'Tip: Long-press Send to insert a newline'**
  String get chatTipLongPressSend;

  /// CodeWalk UI string — chatTipMentionFiles
  ///
  /// In en, this message translates to:
  /// **'Tip: Use @ to mention files in your prompt'**
  String get chatTipMentionFiles;

  /// CodeWalk UI string — chatTipNameRelevantFiles
  ///
  /// In en, this message translates to:
  /// **'Tip: Name relevant files, screens, or commands'**
  String get chatTipNameRelevantFiles;

  /// CodeWalk UI string — chatTipProvideContext
  ///
  /// In en, this message translates to:
  /// **'Tip: Provide context — paste error messages and logs'**
  String get chatTipProvideContext;

  /// CodeWalk UI string — chatTipRenameConversation
  ///
  /// In en, this message translates to:
  /// **'Tip: Tap the title to rename a conversation'**
  String get chatTipRenameConversation;

  /// CodeWalk UI string — chatTipRequestDocs
  ///
  /// In en, this message translates to:
  /// **'Tip: Ask for docs updates when behavior changes'**
  String get chatTipRequestDocs;

  /// CodeWalk UI string — chatTipShareAttempts
  ///
  /// In en, this message translates to:
  /// **'Tip: Share what you tried and the exact error'**
  String get chatTipShareAttempts;

  /// CodeWalk UI string — chatTipShellCommands
  ///
  /// In en, this message translates to:
  /// **'Tip: Use ! at the start to run shell commands'**
  String get chatTipShellCommands;

  /// CodeWalk UI string — chatTipSlashCommands
  ///
  /// In en, this message translates to:
  /// **'Tip: Use / to access slash commands'**
  String get chatTipSlashCommands;

  /// CodeWalk UI string — chatTipStartWithGoal
  ///
  /// In en, this message translates to:
  /// **'Tip: Start with the end goal'**
  String get chatTipStartWithGoal;

  /// CodeWalk UI string — chatTipStateConstraints
  ///
  /// In en, this message translates to:
  /// **'Tip: State constraints the agent must preserve'**
  String get chatTipStateConstraints;

  /// CodeWalk UI string — chatTipStepByStep
  ///
  /// In en, this message translates to:
  /// **'Tip: Ask for step-by-step when debugging complex issues'**
  String get chatTipStepByStep;

  /// CodeWalk UI string — chatTipUseFocusedAgents
  ///
  /// In en, this message translates to:
  /// **'Tip: Pick a focused agent for plan, review, or build'**
  String get chatTipUseFocusedAgents;

  /// CodeWalk UI string — chatToggleSidebars
  ///
  /// In en, this message translates to:
  /// **'Toggle sidebars'**
  String get chatToggleSidebars;

  /// CodeWalk UI string — chatTokensLabel
  ///
  /// In en, this message translates to:
  /// **'Tokens: {total}'**
  String chatTokensLabel(int total);

  /// CodeWalk UI string — chatTourProjectsConversations
  ///
  /// In en, this message translates to:
  /// **'Use this button to open your projects and conversations.'**
  String get chatTourProjectsConversations;

  /// CodeWalk UI string — chatTourSidebarProjectTools
  ///
  /// In en, this message translates to:
  /// **'Use this menu to show the conversations sidebar and project tools.'**
  String get chatTourSidebarProjectTools;

  /// CodeWalk UI string — chatTourSwitchFolders
  ///
  /// In en, this message translates to:
  /// **'Use this button to switch project folders and context.'**
  String get chatTourSwitchFolders;

  /// CodeWalk UI string — chatUndoLastTurn
  ///
  /// In en, this message translates to:
  /// **'Undo last turn'**
  String get chatUndoLastTurn;

  /// CodeWalk UI string — chatUndoNothing
  ///
  /// In en, this message translates to:
  /// **'Nothing to undo in this session'**
  String get chatUndoNothing;

  /// CodeWalk UI string — chatUseCurrent
  ///
  /// In en, this message translates to:
  /// **'Use current'**
  String get chatUseCurrent;

  /// CodeWalk UI string — chatWaitingForNetworkConnection
  ///
  /// In en, this message translates to:
  /// **'Waiting for network connection...'**
  String get chatWaitingForNetworkConnection;

  /// CodeWalk UI string — chatWelcomeMessage
  ///
  /// In en, this message translates to:
  /// **'Hello! I am your AI assistant.'**
  String get chatWelcomeMessage;

  /// CodeWalk UI string — chatWelcomeSubmessage
  ///
  /// In en, this message translates to:
  /// **'How can I help you today?'**
  String get chatWelcomeSubmessage;

  /// CodeWalk UI string — chatWorkBoundedPanelExplanation
  ///
  /// In en, this message translates to:
  /// **'Latest tool activity stays inside this bounded panel to keep the chat viewport stable.'**
  String get chatWorkBoundedPanelExplanation;

  /// CodeWalk UI string — chatWorkExpand
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get chatWorkExpand;

  /// CodeWalk UI string — chatWorkHide
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get chatWorkHide;

  /// CodeWalk UI string — chatWorkMessageOne
  ///
  /// In en, this message translates to:
  /// **'1 work message'**
  String get chatWorkMessageOne;

  /// CodeWalk UI string — chatWorkMessagesMultiple
  ///
  /// In en, this message translates to:
  /// **'{count} work messages'**
  String chatWorkMessagesMultiple(int count);

  /// CodeWalk UI string — chatWorkShow
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get chatWorkShow;

  /// CodeWalk UI string — commonCancel
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// CodeWalk UI string — commonCopiedToClipboard
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get commonCopiedToClipboard;

  /// CodeWalk UI string — commonDelete
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// CodeWalk UI string — commonFile
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get commonFile;

  /// CodeWalk UI string — commonReset
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get commonReset;

  /// CodeWalk UI string — commonSave
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// CodeWalk UI string — compactionAutomatic
  ///
  /// In en, this message translates to:
  /// **'automatic'**
  String get compactionAutomatic;

  /// CodeWalk UI string — compactionManual
  ///
  /// In en, this message translates to:
  /// **'manual'**
  String get compactionManual;

  /// CodeWalk UI string — composerAddAttachment
  ///
  /// In en, this message translates to:
  /// **'Add attachment'**
  String get composerAddAttachment;

  /// CodeWalk UI string — composerAttachFiles
  ///
  /// In en, this message translates to:
  /// **'Attach files'**
  String get composerAttachFiles;

  /// CodeWalk UI string — composerCannedAppendAtCursor
  ///
  /// In en, this message translates to:
  /// **'Append at cursor'**
  String get composerCannedAppendAtCursor;

  /// CodeWalk UI string — composerCannedLabel
  ///
  /// In en, this message translates to:
  /// **'Label (optional)'**
  String get composerCannedLabel;

  /// CodeWalk UI string — composerCannedNoReplies
  ///
  /// In en, this message translates to:
  /// **'No quick replies yet.'**
  String get composerCannedNoReplies;

  /// CodeWalk UI string — composerCannedReplace
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get composerCannedReplace;

  /// CodeWalk UI string — composerCannedSave
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get composerCannedSave;

  /// CodeWalk UI string — composerCannedScopeGlobal
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get composerCannedScopeGlobal;

  /// CodeWalk UI string — composerCannedScopeProject
  ///
  /// In en, this message translates to:
  /// **'Project-only'**
  String get composerCannedScopeProject;

  /// CodeWalk UI string — composerCannedSendAutomatically
  ///
  /// In en, this message translates to:
  /// **'Send automatically'**
  String get composerCannedSendAutomatically;

  /// CodeWalk UI string — composerCannedText
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get composerCannedText;

  /// CodeWalk UI string — composerChatInput
  ///
  /// In en, this message translates to:
  /// **'Chat input'**
  String get composerChatInput;

  /// CodeWalk UI string — composerDeleteAction
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get composerDeleteAction;

  /// CodeWalk UI string — composerDropHint
  ///
  /// In en, this message translates to:
  /// **'Drop images or PDFs to attach'**
  String get composerDropHint;

  /// CodeWalk UI string — composerPastedImageName
  ///
  /// In en, this message translates to:
  /// **'Pasted image'**
  String get composerPastedImageName;

  /// CodeWalk UI string — composerEdit
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get composerEdit;

  /// CodeWalk UI string — composerExtras
  ///
  /// In en, this message translates to:
  /// **'Extras'**
  String get composerExtras;

  /// CodeWalk UI string — composerExtrasHide
  ///
  /// In en, this message translates to:
  /// **'Hide extras'**
  String get composerExtrasHide;

  /// CodeWalk UI string — composerNewQuickReply
  ///
  /// In en, this message translates to:
  /// **'New quick reply'**
  String get composerNewQuickReply;

  /// CodeWalk UI string — composerSelectImages
  ///
  /// In en, this message translates to:
  /// **'Select Images'**
  String get composerSelectImages;

  /// CodeWalk UI string — composerSelectPdf
  ///
  /// In en, this message translates to:
  /// **'Select PDF'**
  String get composerSelectPdf;

  /// CodeWalk UI string — composerSend
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get composerSend;

  /// CodeWalk UI string — composerShellMode
  ///
  /// In en, this message translates to:
  /// **'Shell mode'**
  String get composerShellMode;

  /// CodeWalk UI string — desktopWindowClose
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get desktopWindowClose;

  /// CodeWalk UI string — desktopWindowMaximize
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get desktopWindowMaximize;

  /// CodeWalk UI string — desktopWindowMinimize
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get desktopWindowMinimize;

  /// CodeWalk UI string — desktopWindowRestore
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get desktopWindowRestore;

  /// CodeWalk UI string — dialogDownload
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get dialogDownload;

  /// CodeWalk UI string — dialogLanguage
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get dialogLanguage;

  /// CodeWalk UI string — dialogMoonshineModelSize
  ///
  /// In en, this message translates to:
  /// **'Model size'**
  String get dialogMoonshineModelSize;

  /// CodeWalk UI string — dialogMoonshineVoiceSetup
  ///
  /// In en, this message translates to:
  /// **'Moonshine Voice Setup'**
  String get dialogMoonshineVoiceSetup;

  /// CodeWalk UI string — dialogParakeetModel
  ///
  /// In en, this message translates to:
  /// **'Parakeet model'**
  String get dialogParakeetModel;

  /// CodeWalk UI string — dialogParakeetVoiceSetup
  ///
  /// In en, this message translates to:
  /// **'Parakeet Voice Setup'**
  String get dialogParakeetVoiceSetup;

  /// CodeWalk UI string — dialogSenseVoiceModel
  ///
  /// In en, this message translates to:
  /// **'SenseVoice model'**
  String get dialogSenseVoiceModel;

  /// CodeWalk UI string — dialogSenseVoiceSetup
  ///
  /// In en, this message translates to:
  /// **'SenseVoice Setup'**
  String get dialogSenseVoiceSetup;

  /// CodeWalk UI string — dialogVoiceInputSetup
  ///
  /// In en, this message translates to:
  /// **'Voice Input Setup'**
  String get dialogVoiceInputSetup;

  /// CodeWalk UI string — errorAnErrorOccurred
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get errorAnErrorOccurred;

  /// CodeWalk UI string — errorAuthRequired
  ///
  /// In en, this message translates to:
  /// **'Authentication required'**
  String get errorAuthRequired;

  /// CodeWalk UI string — errorAuthRequiredDesc
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Reconnect the provider and try again.'**
  String get errorAuthRequiredDesc;

  /// CodeWalk UI string — errorConnectionFailed
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get errorConnectionFailed;

  /// CodeWalk UI string — errorConnectionFailedDesc
  ///
  /// In en, this message translates to:
  /// **'Unable to reach the server. Check connection and server status.'**
  String get errorConnectionFailedDesc;

  /// CodeWalk UI string — errorFormatAuthenticationFailedReconnect
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Reconnect the provider and try again.'**
  String get errorFormatAuthenticationFailedReconnect;

  /// CodeWalk UI string — errorFormatProviderTemporarilyUnavailable
  ///
  /// In en, this message translates to:
  /// **'Provider temporarily unavailable. Try again shortly.'**
  String get errorFormatProviderTemporarilyUnavailable;

  /// CodeWalk UI string — errorFormatQuotaExceededCheck
  ///
  /// In en, this message translates to:
  /// **'Quota exceeded. Check your provider plan or billing.'**
  String get errorFormatQuotaExceededCheck;

  /// CodeWalk UI string — errorFormatRateLimitExceeded
  ///
  /// In en, this message translates to:
  /// **'Rate limit exceeded. Wait a moment and try again.'**
  String get errorFormatRateLimitExceeded;

  /// CodeWalk UI string — errorFormatServerErrorPlease
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again.'**
  String get errorFormatServerErrorPlease;

  /// CodeWalk UI string — errorFormatServiceTemporarilyUnavailable
  ///
  /// In en, this message translates to:
  /// **'Service temporarily unavailable. The server may be starting up — please try again shortly.'**
  String get errorFormatServiceTemporarilyUnavailable;

  /// CodeWalk UI string — errorFormatUnableReachServer
  ///
  /// In en, this message translates to:
  /// **'Unable to reach the server. Check connection and server status.'**
  String get errorFormatUnableReachServer;

  /// CodeWalk UI string — errorProviderUnavailable
  ///
  /// In en, this message translates to:
  /// **'Provider unavailable'**
  String get errorProviderUnavailable;

  /// CodeWalk UI string — errorProviderUnavailableDesc
  ///
  /// In en, this message translates to:
  /// **'Provider temporarily unavailable. Try again shortly.'**
  String get errorProviderUnavailableDesc;

  /// CodeWalk UI string — errorQuotaExceeded
  ///
  /// In en, this message translates to:
  /// **'Quota exceeded'**
  String get errorQuotaExceeded;

  /// CodeWalk UI string — errorQuotaExceededDesc
  ///
  /// In en, this message translates to:
  /// **'Quota exceeded. Check your provider plan or billing.'**
  String get errorQuotaExceededDesc;

  /// CodeWalk UI string — errorRateLimitExceeded
  ///
  /// In en, this message translates to:
  /// **'Rate limit exceeded'**
  String get errorRateLimitExceeded;

  /// CodeWalk UI string — errorRateLimitExceededDesc
  ///
  /// In en, this message translates to:
  /// **'Rate limit exceeded. Wait a moment and try again.'**
  String get errorRateLimitExceededDesc;

  /// CodeWalk UI string — errorServerError
  ///
  /// In en, this message translates to:
  /// **'Server error'**
  String get errorServerError;

  /// CodeWalk UI string — errorServerErrorDesc
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again.'**
  String get errorServerErrorDesc;

  /// CodeWalk UI string — errorServiceUnavailable
  ///
  /// In en, this message translates to:
  /// **'Service unavailable'**
  String get errorServiceUnavailable;

  /// CodeWalk UI string — errorServiceUnavailableDesc
  ///
  /// In en, this message translates to:
  /// **'Service temporarily unavailable. The server may be starting up — please try again shortly.'**
  String get errorServiceUnavailableDesc;

  /// CodeWalk UI string — fileActionAttachmentDataDecoded
  ///
  /// In en, this message translates to:
  /// **'Attachment data could not be decoded.'**
  String get fileActionAttachmentDataDecoded;

  /// CodeWalk UI string — fileActionAttachmentPathEmpty
  ///
  /// In en, this message translates to:
  /// **'Attachment path is empty.'**
  String get fileActionAttachmentPathEmpty;

  /// CodeWalk UI string — fileActionAttachmentPayloadEmpty
  ///
  /// In en, this message translates to:
  /// **'Attachment payload is empty.'**
  String get fileActionAttachmentPayloadEmpty;

  /// CodeWalk UI string — fileActionAttachmentProvideValid
  ///
  /// In en, this message translates to:
  /// **'Attachment does not provide a valid location.'**
  String get fileActionAttachmentProvideValid;

  /// CodeWalk UI string — fileActionAttachmentSavedDevice
  ///
  /// In en, this message translates to:
  /// **'Attachment could not be saved on this device.'**
  String get fileActionAttachmentSavedDevice;

  /// CodeWalk UI string — fileActionAttachmentSavedOutputFile
  ///
  /// In en, this message translates to:
  /// **'Attachment saved to {path} and opened.'**
  String fileActionAttachmentSavedOutputFile(String path);

  /// CodeWalk UI string — fileActionAttachmentSavedOutputFile2
  ///
  /// In en, this message translates to:
  /// **'Attachment saved to {path}.'**
  String fileActionAttachmentSavedOutputFile2(String path);

  /// CodeWalk UI string — fileActionAttachmentSavedSavedPath
  ///
  /// In en, this message translates to:
  /// **'Attachment saved to {savedPath}.'**
  String fileActionAttachmentSavedSavedPath(String savedPath);

  /// CodeWalk UI string — fileActionLocalAttachmentFound
  ///
  /// In en, this message translates to:
  /// **'Local attachment was not found on this device.'**
  String get fileActionLocalAttachmentFound;

  /// CodeWalk UI string — fileActionSaveCanceled
  ///
  /// In en, this message translates to:
  /// **'Save canceled.'**
  String get fileActionSaveCanceled;

  /// CodeWalk UI string — fileActionUnableOpenLocal
  ///
  /// In en, this message translates to:
  /// **'Unable to open the local attachment.'**
  String get fileActionUnableOpenLocal;

  /// CodeWalk UI string — filesAddChat
  ///
  /// In en, this message translates to:
  /// **'Add to chat'**
  String get filesAddChat;

  /// CodeWalk UI string — filesAutosave
  ///
  /// In en, this message translates to:
  /// **'Autosave'**
  String get filesAutosave;

  /// CodeWalk UI string — filesAutosaveOn
  ///
  /// In en, this message translates to:
  /// **'Autosave on'**
  String get filesAutosaveOn;

  /// CodeWalk UI string — filesAutosaveOff
  ///
  /// In en, this message translates to:
  /// **'Autosave off'**
  String get filesAutosaveOff;

  /// CodeWalk UI string — filesRedo
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get filesRedo;

  /// CodeWalk UI string — filesUndo
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get filesUndo;

  /// CodeWalk UI string — filesBinaryFilePreview
  ///
  /// In en, this message translates to:
  /// **'Binary file preview is not available.'**
  String get filesBinaryFilePreview;

  /// CodeWalk UI string — filesClear
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get filesClear;

  /// CodeWalk UI string — filesContents
  ///
  /// In en, this message translates to:
  /// **'Contents'**
  String get filesContents;

  /// CodeWalk UI string — filesDuplicate
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get filesDuplicate;

  /// CodeWalk UI string — filesDuplicated
  ///
  /// In en, this message translates to:
  /// **'File duplicated'**
  String get filesDuplicated;

  /// CodeWalk UI string — filesFileEmpty
  ///
  /// In en, this message translates to:
  /// **'File is empty.'**
  String get filesFileEmpty;

  /// CodeWalk UI string — filesAlreadyExists
  ///
  /// In en, this message translates to:
  /// **'A file or folder with that name already exists.'**
  String get filesAlreadyExists;

  /// CodeWalk UI string — filesCopyPath
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get filesCopyPath;

  /// CodeWalk UI string — filesCreateFileTitle
  ///
  /// In en, this message translates to:
  /// **'Create file'**
  String get filesCreateFileTitle;

  /// CodeWalk UI string — filesCreateFolderTitle
  ///
  /// In en, this message translates to:
  /// **'Create folder'**
  String get filesCreateFolderTitle;

  /// CodeWalk UI string — filesDelete
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get filesDelete;

  /// CodeWalk UI string — filesDeleteConfirm
  ///
  /// In en, this message translates to:
  /// **'Delete {name}? This cannot be undone. Folders and their contents will be deleted.'**
  String filesDeleteConfirm(String name);

  /// CodeWalk UI string — filesDeleteTitle
  ///
  /// In en, this message translates to:
  /// **'Delete {name}'**
  String filesDeleteTitle(String name);

  /// CodeWalk UI string — filesFilesFound
  ///
  /// In en, this message translates to:
  /// **'No files found'**
  String get filesFilesFound;

  /// CodeWalk UI string — filesFileCreated
  ///
  /// In en, this message translates to:
  /// **'File created.'**
  String get filesFileCreated;

  /// CodeWalk UI string — filesFolderCreated
  ///
  /// In en, this message translates to:
  /// **'Folder created.'**
  String get filesFolderCreated;

  /// CodeWalk UI string — filesHideSidebar
  ///
  /// In en, this message translates to:
  /// **'Hide Files sidebar'**
  String get filesHideSidebar;

  /// CodeWalk UI string — filesInvalidName
  ///
  /// In en, this message translates to:
  /// **'Enter a valid name without path separators.'**
  String get filesInvalidName;

  /// CodeWalk UI string — filesNameHint
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get filesNameHint;

  /// CodeWalk UI string — filesNew
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get filesNew;

  /// CodeWalk UI string — filesNewFile
  ///
  /// In en, this message translates to:
  /// **'New file'**
  String get filesNewFile;

  /// CodeWalk UI string — filesNewFolder
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get filesNewFolder;

  /// CodeWalk UI string — filesNames
  ///
  /// In en, this message translates to:
  /// **'Names'**
  String get filesNames;

  /// CodeWalk UI string — filesOpenFilesFileState
  ///
  /// In en, this message translates to:
  /// **'Open files ({length})'**
  String filesOpenFilesFileState(int length);

  /// CodeWalk UI string — filesQuickOpen
  ///
  /// In en, this message translates to:
  /// **'Quick Open'**
  String get filesQuickOpen;

  /// CodeWalk UI string — filesQuickOpenFile
  ///
  /// In en, this message translates to:
  /// **'Quick Open File'**
  String get filesQuickOpenFile;

  /// CodeWalk UI string — filesOperationFailed
  ///
  /// In en, this message translates to:
  /// **'File operation failed.'**
  String get filesOperationFailed;

  /// CodeWalk UI string — filesOperationUnavailable
  ///
  /// In en, this message translates to:
  /// **'File operations are not available for this server.'**
  String get filesOperationUnavailable;

  /// CodeWalk UI string — filesOutsideRoot
  ///
  /// In en, this message translates to:
  /// **'The path is outside the project root.'**
  String get filesOutsideRoot;

  /// CodeWalk UI string — filesPathCopied
  ///
  /// In en, this message translates to:
  /// **'Path copied.'**
  String get filesPathCopied;

  /// CodeWalk UI string — filesPathMissing
  ///
  /// In en, this message translates to:
  /// **'Path does not exist.'**
  String get filesPathMissing;

  /// CodeWalk UI string — filesPermissionDenied
  ///
  /// In en, this message translates to:
  /// **'Permission denied.'**
  String get filesPermissionDenied;

  /// CodeWalk UI string — filesRefresh
  ///
  /// In en, this message translates to:
  /// **'Refresh files'**
  String get filesRefresh;

  /// CodeWalk UI string — filesRename
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get filesRename;

  /// CodeWalk UI string — filesRenameTitle
  ///
  /// In en, this message translates to:
  /// **'Rename {name}'**
  String filesRenameTitle(String name);

  /// CodeWalk UI string — filesRenamed
  ///
  /// In en, this message translates to:
  /// **'Renamed.'**
  String get filesRenamed;

  /// CodeWalk UI string — filesRootDeleteBlocked
  ///
  /// In en, this message translates to:
  /// **'The project root cannot be deleted.'**
  String get filesRootDeleteBlocked;

  /// CodeWalk UI string — filesSearchHint
  ///
  /// In en, this message translates to:
  /// **'Search files by name or path'**
  String get filesSearchHint;

  /// CodeWalk UI string — filesDeleted
  ///
  /// In en, this message translates to:
  /// **'Deleted.'**
  String get filesDeleted;

  /// CodeWalk UI string — filesTitle
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get filesTitle;

  /// CodeWalk UI string — forwardAction
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get forwardAction;

  /// CodeWalk UI string — forwardAllFailed
  ///
  /// In en, this message translates to:
  /// **'Could not forward to any session'**
  String get forwardAllFailed;

  /// CodeWalk UI string — forwardCancel
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get forwardCancel;

  /// CodeWalk UI string — forwardDialogSubtitle
  ///
  /// In en, this message translates to:
  /// **'Select one or more conversations'**
  String get forwardDialogSubtitle;

  /// CodeWalk UI string — forwardDialogTitle
  ///
  /// In en, this message translates to:
  /// **'Forward to…'**
  String get forwardDialogTitle;

  /// CodeWalk UI string — forwardLoading
  ///
  /// In en, this message translates to:
  /// **'Loading sessions…'**
  String get forwardLoading;

  /// CodeWalk UI string — forwardNoOpenProjects
  ///
  /// In en, this message translates to:
  /// **'No open projects with sessions'**
  String get forwardNoOpenProjects;

  /// CodeWalk UI string — forwardNoProviderModel
  ///
  /// In en, this message translates to:
  /// **'Select a provider and model before forwarding'**
  String get forwardNoProviderModel;

  /// CodeWalk UI string — forwardNoSessions
  ///
  /// In en, this message translates to:
  /// **'No recent sessions'**
  String get forwardNoSessions;

  /// CodeWalk UI string — forwardPartial
  ///
  /// In en, this message translates to:
  /// **'Forwarded to {success} of {total}'**
  String forwardPartial(int success, int total);

  /// CodeWalk UI string — forwardProvenanceLabel
  ///
  /// In en, this message translates to:
  /// **'Forwarded from: {origin}'**
  String forwardProvenanceLabel(String origin);

  /// CodeWalk UI string — forwardRetry
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get forwardRetry;

  /// CodeWalk UI string — forwardSearchHint
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get forwardSearchHint;

  /// CodeWalk UI string — forwardSelectedCount
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String forwardSelectedCount(int count);

  /// CodeWalk UI string — forwardSend
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get forwardSend;

  /// CodeWalk UI string — forwardServerOffline
  ///
  /// In en, this message translates to:
  /// **'Server offline'**
  String get forwardServerOffline;

  /// CodeWalk UI string — forwardShortcutHint
  ///
  /// In en, this message translates to:
  /// **'Ctrl+Shift+F'**
  String get forwardShortcutHint;

  /// CodeWalk UI string — forwardSuccess
  ///
  /// In en, this message translates to:
  /// **'Forwarded to {count} sessions'**
  String forwardSuccess(int count);

  /// CodeWalk UI string — forwardUndo
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get forwardUndo;

  /// CodeWalk UI string — forwardUndoFailed
  ///
  /// In en, this message translates to:
  /// **'Could not undo the forward'**
  String get forwardUndoFailed;

  /// CodeWalk UI string — logsAppLogs
  ///
  /// In en, this message translates to:
  /// **'App Logs'**
  String get logsAppLogs;

  /// CodeWalk UI string — logsClear
  ///
  /// In en, this message translates to:
  /// **'Clear logs'**
  String get logsClear;

  /// CodeWalk UI string — logsCloseSearch
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get logsCloseSearch;

  /// CodeWalk UI string — logsCopyFiltered
  ///
  /// In en, this message translates to:
  /// **'Copy filtered logs'**
  String get logsCopyFiltered;

  /// CodeWalk UI string — logsEnableLogging
  ///
  /// In en, this message translates to:
  /// **'Enable app logging'**
  String get logsEnableLogging;

  /// CodeWalk UI string — logsEnableLoggingAction
  ///
  /// In en, this message translates to:
  /// **'Enable logging'**
  String get logsEnableLoggingAction;

  /// CodeWalk UI string — logsEnableLoggingDescription
  ///
  /// In en, this message translates to:
  /// **'Collect in-memory diagnostic logs. Keep this off unless you are troubleshooting.'**
  String get logsEnableLoggingDescription;

  /// CodeWalk UI string — logsEntryContext
  ///
  /// In en, this message translates to:
  /// **'Context'**
  String get logsEntryContext;

  /// CodeWalk UI string — logsEntryTags
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get logsEntryTags;

  /// CodeWalk UI string — logsFilterAll
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get logsFilterAll;

  /// CodeWalk UI string — logsFilterByTag
  ///
  /// In en, this message translates to:
  /// **'Tag'**
  String get logsFilterByTag;

  /// CodeWalk UI string — logsLevel
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get logsLevel;

  /// CodeWalk UI string — logsLoggingDisabledDescription
  ///
  /// In en, this message translates to:
  /// **'CodeWalk is not collecting detailed app logs. Enable logging only when you need diagnostics.'**
  String get logsLoggingDisabledDescription;

  /// CodeWalk UI string — logsLoggingDisabledTitle
  ///
  /// In en, this message translates to:
  /// **'Logging is disabled'**
  String get logsLoggingDisabledTitle;

  /// CodeWalk UI string — logsMeasurePerformance
  ///
  /// In en, this message translates to:
  /// **'Measure performance'**
  String get logsMeasurePerformance;

  /// CodeWalk UI string — logsMeasurePerformanceDescription
  ///
  /// In en, this message translates to:
  /// **'Capture timing logs for expensive app operations. Leave off unless you are diagnosing lag.'**
  String get logsMeasurePerformanceDescription;

  /// CodeWalk UI string — logsNoLogsYet
  ///
  /// In en, this message translates to:
  /// **'No logs captured yet.'**
  String get logsNoLogsYet;

  /// CodeWalk UI string — logsNoMatchingLogs
  ///
  /// In en, this message translates to:
  /// **'No logs match the current filters.'**
  String get logsNoMatchingLogs;

  /// CodeWalk UI string — logsNoPerformanceData
  ///
  /// In en, this message translates to:
  /// **'No performance logs match the current filters.'**
  String get logsNoPerformanceData;

  /// CodeWalk UI string — logsNoTaskData
  ///
  /// In en, this message translates to:
  /// **'No tasks match the current filters.'**
  String get logsNoTaskData;

  /// CodeWalk UI string — logsPerformanceDuration
  ///
  /// In en, this message translates to:
  /// **'{elapsedMs} ms'**
  String logsPerformanceDuration(int elapsedMs);

  /// CodeWalk UI string — logsPerformanceFilter
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get logsPerformanceFilter;

  /// CodeWalk UI string — logsPerformanceTileTitle
  ///
  /// In en, this message translates to:
  /// **'PERFORMANCE {operation} | {elapsedMs} ms | {status}'**
  String logsPerformanceTileTitle(
    int elapsedMs,
    String operation,
    String status,
  );

  /// CodeWalk UI string — logsSearch
  ///
  /// In en, this message translates to:
  /// **'Search logs'**
  String get logsSearch;

  /// CodeWalk UI string — logsShowingOrderedLength
  ///
  /// In en, this message translates to:
  /// **'Showing {length} of {length2} entries'**
  String logsShowingOrderedLength(int length, int length2);

  /// CodeWalk UI string — logsSlowestPerformance
  ///
  /// In en, this message translates to:
  /// **'Slowest performance logs'**
  String get logsSlowestPerformance;

  /// CodeWalk UI string — logsSlowestTasks
  ///
  /// In en, this message translates to:
  /// **'Slowest tasks'**
  String get logsSlowestTasks;

  /// CodeWalk UI string — logsTagCustomHint
  ///
  /// In en, this message translates to:
  /// **'Tag name (for example: task:select_session)'**
  String get logsTagCustomHint;

  /// CodeWalk UI string — logsTagCustomAction
  ///
  /// In en, this message translates to:
  /// **'Custom...'**
  String get logsTagCustomAction;

  /// CodeWalk UI string — logsTaskDuration
  ///
  /// In en, this message translates to:
  /// **'{operation} — {elapsedMs} ms'**
  String logsTaskDuration(int elapsedMs, String operation);

  /// CodeWalk UI string — logsTaskStatusCanceled
  ///
  /// In en, this message translates to:
  /// **'canceled'**
  String get logsTaskStatusCanceled;

  /// CodeWalk UI string — logsTaskStatusError
  ///
  /// In en, this message translates to:
  /// **'error'**
  String get logsTaskStatusError;

  /// CodeWalk UI string — logsTaskStatusOk
  ///
  /// In en, this message translates to:
  /// **'ok'**
  String get logsTaskStatusOk;

  /// CodeWalk UI string — logsTimeRange
  ///
  /// In en, this message translates to:
  /// **'Time range'**
  String get logsTimeRange;

  /// CodeWalk UI string — mathExpressionLabel
  ///
  /// In en, this message translates to:
  /// **'Math'**
  String get mathExpressionLabel;

  /// CodeWalk UI string — mermaidCopySourceTooltip
  ///
  /// In en, this message translates to:
  /// **'Copy source'**
  String get mermaidCopySourceTooltip;

  /// CodeWalk UI string — mermaidDiagramLabel
  ///
  /// In en, this message translates to:
  /// **'Mermaid Diagram'**
  String get mermaidDiagramLabel;

  /// CodeWalk UI string — modelAuto
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get modelAuto;

  /// CodeWalk UI string — modelChooseAgent
  ///
  /// In en, this message translates to:
  /// **'Choose agent'**
  String get modelChooseAgent;

  /// CodeWalk UI string — modelFavorites
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get modelFavorites;

  /// CodeWalk UI string — modelFree
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get modelFree;

  /// CodeWalk UI string — modelLabelBaseEnglish
  ///
  /// In en, this message translates to:
  /// **'Base (English)'**
  String get modelLabelBaseEnglish;

  /// CodeWalk UI string — modelLabelParakeet
  ///
  /// In en, this message translates to:
  /// **'Parakeet V3 (25 European languages)'**
  String get modelLabelParakeet;

  /// CodeWalk UI string — modelLabelSenseVoice
  ///
  /// In en, this message translates to:
  /// **'SenseVoice (zh/en/ja/ko/yue)'**
  String get modelLabelSenseVoice;

  /// CodeWalk UI string — modelLabelTinyEnglish
  ///
  /// In en, this message translates to:
  /// **'Tiny (English)'**
  String get modelLabelTinyEnglish;

  /// CodeWalk UI string — modelLoadingModels
  ///
  /// In en, this message translates to:
  /// **'Loading models'**
  String get modelLoadingModels;

  /// CodeWalk UI string — modelModelsFound
  ///
  /// In en, this message translates to:
  /// **'No models found'**
  String get modelModelsFound;

  /// CodeWalk UI string — modelRetryModels
  ///
  /// In en, this message translates to:
  /// **'Retry models'**
  String get modelRetryModels;

  /// CodeWalk UI string — modelSearchHint
  ///
  /// In en, this message translates to:
  /// **'Search model or provider'**
  String get modelSearchHint;

  /// CodeWalk UI string — msgBatterySettingsFailed
  ///
  /// In en, this message translates to:
  /// **'Could not open Android battery optimization settings.'**
  String get msgBatterySettingsFailed;

  /// CodeWalk UI string — msgBatterySettingsOpened
  ///
  /// In en, this message translates to:
  /// **'Android battery settings opened. Allow unrestricted battery for CodeWalk.'**
  String get msgBatterySettingsOpened;

  /// CodeWalk UI string — msgClearUsernameNeedsConfigEdit
  ///
  /// In en, this message translates to:
  /// **'Clearing the OpenCode conversation username still requires editing config outside the app.'**
  String get msgClearUsernameNeedsConfigEdit;

  /// CodeWalk UI string — msgCommandCopied
  ///
  /// In en, this message translates to:
  /// **'Command copied'**
  String get msgCommandCopied;

  /// CodeWalk UI string — msgCopiedToClipboard
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get msgCopiedToClipboard;

  /// CodeWalk UI string — msgEnterUsernameToSave
  ///
  /// In en, this message translates to:
  /// **'Enter a username to save a custom OpenCode conversation name.'**
  String get msgEnterUsernameToSave;

  /// CodeWalk UI string — msgFailedToSendMessage
  ///
  /// In en, this message translates to:
  /// **'Failed to send message. Draft kept for retry.'**
  String get msgFailedToSendMessage;

  /// CodeWalk UI string — msgFailedToStartVoiceInput
  ///
  /// In en, this message translates to:
  /// **'Failed to start voice input'**
  String get msgFailedToStartVoiceInput;

  /// CodeWalk UI string — msgFilePathNotFound
  ///
  /// In en, this message translates to:
  /// **'File not found: {path}'**
  String msgFilePathNotFound(String path);

  /// CodeWalk UI string — msgFilteredLogsCopied
  ///
  /// In en, this message translates to:
  /// **'Filtered logs copied to clipboard'**
  String get msgFilteredLogsCopied;

  /// CodeWalk UI string — msgInfoAgent
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get msgInfoAgent;

  /// CodeWalk UI string — msgInfoCompaction
  ///
  /// In en, this message translates to:
  /// **'Compaction'**
  String get msgInfoCompaction;

  /// CodeWalk UI string — msgInfoCost
  ///
  /// In en, this message translates to:
  /// **'Cost: \${cost}'**
  String msgInfoCost(String cost);

  /// CodeWalk UI string — msgInfoMessageInfo
  ///
  /// In en, this message translates to:
  /// **'Message Info'**
  String get msgInfoMessageInfo;

  /// CodeWalk UI string — msgInfoModel
  ///
  /// In en, this message translates to:
  /// **'Model: {modelId}'**
  String msgInfoModel(String modelId);

  /// CodeWalk UI string — msgInfoNoMetadata
  ///
  /// In en, this message translates to:
  /// **'No metadata available'**
  String get msgInfoNoMetadata;

  /// CodeWalk UI string — msgInfoPartDescriptionModel
  ///
  /// In en, this message translates to:
  /// **'{description}{model}'**
  String msgInfoPartDescriptionModel(String description, String model);

  /// CodeWalk UI string — msgInfoPatch
  ///
  /// In en, this message translates to:
  /// **'Patch'**
  String get msgInfoPatch;

  /// CodeWalk UI string — msgInfoProvider
  ///
  /// In en, this message translates to:
  /// **'Provider: {providerId}'**
  String msgInfoProvider(String providerId);

  /// CodeWalk UI string — msgInfoRetry
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get msgInfoRetry;

  /// CodeWalk UI string — msgInfoSnapshot
  ///
  /// In en, this message translates to:
  /// **'Snapshot'**
  String get msgInfoSnapshot;

  /// CodeWalk UI string — msgInfoSubtaskPartAgent
  ///
  /// In en, this message translates to:
  /// **'Subtask ({agent})'**
  String msgInfoSubtaskPartAgent(String agent);

  /// CodeWalk UI string — msgInfoTokens
  ///
  /// In en, this message translates to:
  /// **'Tokens: {total}'**
  String msgInfoTokens(int total);

  /// CodeWalk UI string — msgInfoUndoThisTurn
  ///
  /// In en, this message translates to:
  /// **'Undo this turn'**
  String get msgInfoUndoThisTurn;

  /// CodeWalk UI string — msgInfoView
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get msgInfoView;

  /// CodeWalk UI string — msgNoSystemSoundsFound
  ///
  /// In en, this message translates to:
  /// **'No system sound was found on this device.'**
  String get msgNoSystemSoundsFound;

  /// CodeWalk UI string — msgNoValidFilesSelected
  ///
  /// In en, this message translates to:
  /// **'No valid files were selected'**
  String get msgNoValidFilesSelected;

  /// CodeWalk UI string — msgSomeSelectedFilesNotAttached
  ///
  /// In en, this message translates to:
  /// **'Some selected files could not be attached.'**
  String get msgSomeSelectedFilesNotAttached;

  /// CodeWalk UI string — msgReadAloud
  ///
  /// In en, this message translates to:
  /// **'Read aloud'**
  String get msgReadAloud;

  /// CodeWalk UI string — msgReadAloudNotAvailable
  ///
  /// In en, this message translates to:
  /// **'Text-to-speech is not available on this device.'**
  String get msgReadAloudNotAvailable;

  /// CodeWalk UI string — msgSetupDebugCopied
  ///
  /// In en, this message translates to:
  /// **'OpenCode setup debug copied to clipboard'**
  String get msgSetupDebugCopied;

  /// CodeWalk UI string — msgShareAsImage
  ///
  /// In en, this message translates to:
  /// **'Share as image'**
  String get msgShareAsImage;

  /// CodeWalk UI string — msgShareAsImageFailed
  ///
  /// In en, this message translates to:
  /// **'Could not share message as image.'**
  String get msgShareAsImageFailed;

  /// CodeWalk UI string — msgShareAsImageSubject
  ///
  /// In en, this message translates to:
  /// **'CodeWalk message'**
  String get msgShareAsImageSubject;

  /// CodeWalk UI string — msgShareAsImageTooTall
  ///
  /// In en, this message translates to:
  /// **'Message is too long to share as an image.'**
  String get msgShareAsImageTooTall;

  /// CodeWalk UI string — msgStopReadAloud
  ///
  /// In en, this message translates to:
  /// **'Stop reading'**
  String get msgStopReadAloud;

  /// CodeWalk UI string — msgPauseReadAloud
  ///
  /// In en, this message translates to:
  /// **'Pause reading'**
  String get msgPauseReadAloud;

  /// CodeWalk UI string — msgResumeReadAloud
  ///
  /// In en, this message translates to:
  /// **'Resume reading'**
  String get msgResumeReadAloud;

  /// CodeWalk UI string — msgSystemSoundPickerUnavailable
  ///
  /// In en, this message translates to:
  /// **'System sound picker is not available on this platform.'**
  String get msgSystemSoundPickerUnavailable;

  /// CodeWalk UI string — msgUpdatedButRefreshFailed
  ///
  /// In en, this message translates to:
  /// **'Updated the server setting, but could not refresh chat providers.'**
  String get msgUpdatedButRefreshFailed;

  /// CodeWalk UI string — msgVoiceInputUnavailable
  ///
  /// In en, this message translates to:
  /// **'Voice input is unavailable on this device'**
  String get msgVoiceInputUnavailable;

  /// CodeWalk UI string — notifAndroidBatteryOptimization
  ///
  /// In en, this message translates to:
  /// **'Android battery optimization'**
  String get notifAndroidBatteryOptimization;

  /// CodeWalk UI string — notifConversationUpdates
  ///
  /// In en, this message translates to:
  /// **'Conversation updates'**
  String get notifConversationUpdates;

  /// CodeWalk UI string — notifNotificationsArriveReopening
  ///
  /// In en, this message translates to:
  /// **'If notifications only arrive when reopening the app, allow CodeWalk to run without optimization on this device.'**
  String get notifNotificationsArriveReopening;

  /// CodeWalk UI string — notifResponseRunningKeep
  ///
  /// In en, this message translates to:
  /// **'When a response is running, keep realtime active briefly after you leave the app.'**
  String get notifResponseRunningKeep;

  /// CodeWalk UI string — notifSelectedSoundLabel
  ///
  /// In en, this message translates to:
  /// **'Selected: {soundLabel}'**
  String notifSelectedSoundLabel(String soundLabel);

  /// CodeWalk UI string — notificationAgentFinished
  ///
  /// In en, this message translates to:
  /// **'Agent finished the current response.'**
  String get notificationAgentFinished;

  /// CodeWalk UI string — notificationConversationUpdates
  ///
  /// In en, this message translates to:
  /// **'Conversation updates'**
  String get notificationConversationUpdates;

  /// CodeWalk UI string — notificationOpenToClear
  ///
  /// In en, this message translates to:
  /// **'Open this conversation to clear related notifications.'**
  String get notificationOpenToClear;

  /// CodeWalk UI string — notificationSession
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get notificationSession;

  /// CodeWalk UI string — notificationSoundLoadFailed
  ///
  /// In en, this message translates to:
  /// **'Failed to load Android system sounds'**
  String get notificationSoundLoadFailed;

  /// CodeWalk UI string — onboardingAIGeneratedTitles
  ///
  /// In en, this message translates to:
  /// **'AI generated titles'**
  String get onboardingAIGeneratedTitles;

  /// CodeWalk UI string — onboardingAddServerLater
  ///
  /// In en, this message translates to:
  /// **'You can add a server later in Settings > Servers.'**
  String get onboardingAddServerLater;

  /// CodeWalk UI string — onboardingAddedButHealthCheckFailed
  ///
  /// In en, this message translates to:
  /// **'Server added but health check failed. It may still be starting up.'**
  String get onboardingAddedButHealthCheckFailed;

  /// CodeWalk UI string — onboardingAlmostInstallOpenCode
  ///
  /// In en, this message translates to:
  /// **'You are almost there. Install OpenCode first, then connect CodeWalk to the server URL.'**
  String get onboardingAlmostInstallOpenCode;

  /// CodeWalk UI string — onboardingAppProviderLocalSetupLogsLength
  ///
  /// In en, this message translates to:
  /// **'{length} setup log lines and {length2} setup events are available in the separate setup debug screen.'**
  String onboardingAppProviderLocalSetupLogsLength(int length, int length2);

  /// CodeWalk UI string — onboardingAuthenticate
  ///
  /// In en, this message translates to:
  /// **'Authenticate'**
  String get onboardingAuthenticate;

  /// CodeWalk UI string — onboardingAvailable
  ///
  /// In en, this message translates to:
  /// **'available'**
  String get onboardingAvailable;

  /// CodeWalk UI string — onboardingAvailableOnlyDesktop
  ///
  /// In en, this message translates to:
  /// **'Available only on desktop (Linux/macOS/Windows).'**
  String get onboardingAvailableOnlyDesktop;

  /// CodeWalk UI string — onboardingBasicAuthTip
  ///
  /// In en, this message translates to:
  /// **'Enable Basic Auth only if your OpenCode server is password-protected.'**
  String get onboardingBasicAuthTip;

  /// CodeWalk UI string — onboardingChooseAnotherPath
  ///
  /// In en, this message translates to:
  /// **'Choose another path'**
  String get onboardingChooseAnotherPath;

  /// CodeWalk UI string — onboardingChooseHowToSetup
  ///
  /// In en, this message translates to:
  /// **'Choose how to set up your server'**
  String get onboardingChooseHowToSetup;

  /// CodeWalk UI string — onboardingClear
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get onboardingClear;

  /// CodeWalk UI string — onboardingCloudflareAuthFailed
  ///
  /// In en, this message translates to:
  /// **'Cloudflare Access authentication failed.'**
  String get onboardingCloudflareAuthFailed;

  /// CodeWalk UI string — onboardingCodeWalkAppOpenCode
  ///
  /// In en, this message translates to:
  /// **'CodeWalk is the app. OpenCode is the engine it connects to.'**
  String get onboardingCodeWalkAppOpenCode;

  /// CodeWalk UI string — onboardingConnectRunningServer
  ///
  /// In en, this message translates to:
  /// **'Connect to a running server'**
  String get onboardingConnectRunningServer;

  /// CodeWalk UI string — onboardingConnectionIssue
  ///
  /// In en, this message translates to:
  /// **'Connection issue'**
  String get onboardingConnectionIssue;

  /// CodeWalk UI string — onboardingConnectionSaved
  ///
  /// In en, this message translates to:
  /// **'Server connection saved successfully.'**
  String get onboardingConnectionSaved;

  /// CodeWalk UI string — onboardingConnectionTips
  ///
  /// In en, this message translates to:
  /// **'Connection tips'**
  String get onboardingConnectionTips;

  /// CodeWalk UI string — onboardingConnectionUpdated
  ///
  /// In en, this message translates to:
  /// **'Server connection updated successfully.'**
  String get onboardingConnectionUpdated;

  /// CodeWalk UI string — onboardingContinue
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingContinue;

  /// CodeWalk UI string — onboardingContinueServerURL
  ///
  /// In en, this message translates to:
  /// **'Continue to server URL'**
  String get onboardingContinueServerURL;

  /// CodeWalk UI string — onboardingCopyLoginURL
  ///
  /// In en, this message translates to:
  /// **'Copy login URL'**
  String get onboardingCopyLoginURL;

  /// CodeWalk UI string — onboardingCouldNotVerify
  ///
  /// In en, this message translates to:
  /// **'Could not verify the server connection.'**
  String get onboardingCouldNotVerify;

  /// CodeWalk UI string — onboardingDefaultURLEmulator
  ///
  /// In en, this message translates to:
  /// **'Default URL, emulator loopback, auth, and debug help.'**
  String get onboardingDefaultURLEmulator;

  /// CodeWalk UI string — onboardingDesktopOnlyDiagnose
  ///
  /// In en, this message translates to:
  /// **'Desktop only: {appName} can diagnose, install, and run OpenCode for you.'**
  String onboardingDesktopOnlyDiagnose(String appName);

  /// CodeWalk UI string — onboardingDetailedSetupEvents
  ///
  /// In en, this message translates to:
  /// **'Detailed setup events were captured for troubleshooting.'**
  String get onboardingDetailedSetupEvents;

  /// CodeWalk UI string — onboardingDonShowAgain
  ///
  /// In en, this message translates to:
  /// **'Don\'\'t show again'**
  String get onboardingDonShowAgain;

  /// CodeWalk UI string — onboardingDone
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get onboardingDone;

  /// CodeWalk UI string — onboardingEditServer
  ///
  /// In en, this message translates to:
  /// **'Edit server'**
  String get onboardingEditServer;

  /// CodeWalk UI string — onboardingEditServerConnection
  ///
  /// In en, this message translates to:
  /// **'Edit server connection'**
  String get onboardingEditServerConnection;

  /// CodeWalk UI string — onboardingEmulatorRemap
  ///
  /// In en, this message translates to:
  /// **'On Android emulator, localhost and 127.0.0.1 are remapped to 10.0.2.2 automatically.'**
  String get onboardingEmulatorRemap;

  /// CodeWalk UI string — onboardingEnterServerUrl
  ///
  /// In en, this message translates to:
  /// **'Enter a server URL'**
  String get onboardingEnterServerUrl;

  /// CodeWalk UI string — onboardingExisting
  ///
  /// In en, this message translates to:
  /// **'Use Existing'**
  String get onboardingExisting;

  /// CodeWalk UI string — onboardingExplainInstallOpenCode
  ///
  /// In en, this message translates to:
  /// **'Explain how to install OpenCode, start the server, and then connect from CodeWalk.'**
  String get onboardingExplainInstallOpenCode;

  /// CodeWalk UI string — onboardingFailed
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get onboardingFailed;

  /// CodeWalk UI string — onboardingGoodOptionDesktop
  ///
  /// In en, this message translates to:
  /// **'Good first option on desktop'**
  String get onboardingGoodOptionDesktop;

  /// CodeWalk UI string — onboardingHealthCheckFailedMayBeStarting
  ///
  /// In en, this message translates to:
  /// **'Server health check failed. It may still be starting up.'**
  String get onboardingHealthCheckFailedMayBeStarting;

  /// CodeWalk UI string — onboardingInstallBinary
  ///
  /// In en, this message translates to:
  /// **'Install Binary'**
  String get onboardingInstallBinary;

  /// CodeWalk UI string — onboardingInstallBun
  ///
  /// In en, this message translates to:
  /// **'Install via Bun'**
  String get onboardingInstallBun;

  /// CodeWalk UI string — onboardingInstallBunOpenCode
  ///
  /// In en, this message translates to:
  /// **'Install Bun + OpenCode'**
  String get onboardingInstallBunOpenCode;

  /// CodeWalk UI string — onboardingInstallNpm
  ///
  /// In en, this message translates to:
  /// **'Install via npm'**
  String get onboardingInstallNpm;

  /// CodeWalk UI string — onboardingInstallRunOpenCode
  ///
  /// In en, this message translates to:
  /// **'Install and run OpenCode directly from CodeWalk on desktop.'**
  String get onboardingInstallRunOpenCode;

  /// CodeWalk UI string — onboardingInvalidUrl
  ///
  /// In en, this message translates to:
  /// **'Invalid URL'**
  String get onboardingInvalidUrl;

  /// CodeWalk UI string — onboardingLabel
  ///
  /// In en, this message translates to:
  /// **'Label (optional)'**
  String get onboardingLabel;

  /// CodeWalk UI string — onboardingLabelHint
  ///
  /// In en, this message translates to:
  /// **'My server'**
  String get onboardingLabelHint;

  /// CodeWalk UI string — onboardingLatestOutputAppProvider
  ///
  /// In en, this message translates to:
  /// **'Latest output: {localServerLastOutput}'**
  String onboardingLatestOutputAppProvider(String localServerLastOutput);

  /// CodeWalk UI string — onboardingLetCodeWalkSet
  ///
  /// In en, this message translates to:
  /// **'Let CodeWalk set it up locally'**
  String get onboardingLetCodeWalkSet;

  /// CodeWalk UI string — onboardingLocalServerSetup
  ///
  /// In en, this message translates to:
  /// **'Local server setup'**
  String get onboardingLocalServerSetup;

  /// CodeWalk UI string — onboardingManagedLocalServer
  ///
  /// In en, this message translates to:
  /// **'Managed local server'**
  String get onboardingManagedLocalServer;

  /// CodeWalk UI string — onboardingManagedLocalServer2
  ///
  /// In en, this message translates to:
  /// **'Managed local server mode is available only on desktop builds (Linux/macOS/Windows).'**
  String get onboardingManagedLocalServer2;

  /// CodeWalk UI string — onboardingNeedsOpenCodeServer
  ///
  /// In en, this message translates to:
  /// **'{appName} needs an OpenCode server before it can help with your code.'**
  String onboardingNeedsOpenCodeServer(String appName);

  /// CodeWalk UI string — onboardingNotAvailable
  ///
  /// In en, this message translates to:
  /// **'not available'**
  String get onboardingNotAvailable;

  /// CodeWalk UI string — onboardingNotWritable
  ///
  /// In en, this message translates to:
  /// **'not writable'**
  String get onboardingNotWritable;

  /// CodeWalk UI string — onboardingOpenCode
  ///
  /// In en, this message translates to:
  /// **'What is OpenCode?'**
  String get onboardingOpenCode;

  /// CodeWalk UI string — onboardingOpenCodeRunningDevice
  ///
  /// In en, this message translates to:
  /// **'I already have OpenCode running on this device or somewhere on my network.'**
  String get onboardingOpenCodeRunningDevice;

  /// CodeWalk UI string — onboardingOpenCodeRunsLocally
  ///
  /// In en, this message translates to:
  /// **'OpenCode runs locally or on a server and powers the AI coding features inside CodeWalk. If OpenCode is already running, connect to it. If not, pick one of the guided setup paths below.'**
  String get onboardingOpenCodeRunsLocally;

  /// CodeWalk UI string — onboardingOpenTailscaleLogin
  ///
  /// In en, this message translates to:
  /// **'Could not open Tailscale login URL.'**
  String get onboardingOpenTailscaleLogin;

  /// CodeWalk UI string — onboardingPassword
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get onboardingPassword;

  /// CodeWalk UI string — onboardingPasswordRequired
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get onboardingPasswordRequired;

  /// CodeWalk UI string — onboardingPickSetupPath
  ///
  /// In en, this message translates to:
  /// **'Pick the setup path that matches your current OpenCode setup.'**
  String get onboardingPickSetupPath;

  /// CodeWalk UI string — onboardingPreconditionDirectoryNotWritable
  ///
  /// In en, this message translates to:
  /// **'Install directory is not writable. Check user permissions.'**
  String get onboardingPreconditionDirectoryNotWritable;

  /// CodeWalk UI string — onboardingPreconditionInstallViaBunRecommendation
  ///
  /// In en, this message translates to:
  /// **'Install via Bun is recommended by OpenCode maintainers.'**
  String get onboardingPreconditionInstallViaBunRecommendation;

  /// CodeWalk UI string — onboardingPreconditionNetworkFailed
  ///
  /// In en, this message translates to:
  /// **'Network access failed. Check connectivity before installing OpenCode.'**
  String get onboardingPreconditionNetworkFailed;

  /// CodeWalk UI string — onboardingPreconditionNoRuntimeDetected
  ///
  /// In en, this message translates to:
  /// **'No runtime detected. Install OpenCode binary directly or bootstrap Bun first.'**
  String get onboardingPreconditionNoRuntimeDetected;

  /// CodeWalk UI string — onboardingPreconditionNodeNpmAvailable
  ///
  /// In en, this message translates to:
  /// **'Node + npm are available. Install OpenCode via npm or install Bun for the recommended flow.'**
  String get onboardingPreconditionNodeNpmAvailable;

  /// CodeWalk UI string — onboardingPreconditionOpenCodeAlreadyAvailable
  ///
  /// In en, this message translates to:
  /// **'OpenCode is already available. You can use the detected command immediately.'**
  String get onboardingPreconditionOpenCodeAlreadyAvailable;

  /// CodeWalk UI string — onboardingPreconditionWindowsPathLagHint
  ///
  /// In en, this message translates to:
  /// **' On Windows, refresh checks after install because PATH updates may lag in already-open apps.'**
  String get onboardingPreconditionWindowsPathLagHint;

  /// CodeWalk UI string — onboardingPreconditionWindowsWslRecommendation
  ///
  /// In en, this message translates to:
  /// **'Windows build detected. WSL is recommended by OpenCode docs, but npm install can be used as fallback.'**
  String get onboardingPreconditionWindowsWslRecommendation;

  /// CodeWalk UI string — onboardingReachable
  ///
  /// In en, this message translates to:
  /// **'reachable'**
  String get onboardingReachable;

  /// CodeWalk UI string — onboardingReady
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get onboardingReady;

  /// CodeWalk UI string — onboardingRecommendedOrderTry
  ///
  /// In en, this message translates to:
  /// **'Recommended order: try Install Bun + OpenCode if you want CodeWalk to bootstrap everything for you. Use Existing if OpenCode is already installed.'**
  String get onboardingRecommendedOrderTry;

  /// CodeWalk UI string — onboardingRefreshChecks
  ///
  /// In en, this message translates to:
  /// **'Refresh Checks'**
  String get onboardingRefreshChecks;

  /// CodeWalk UI string — onboardingRunDiagnosticsToVerify
  ///
  /// In en, this message translates to:
  /// **'Run diagnostics to verify local OpenCode requirements.'**
  String get onboardingRunDiagnosticsToVerify;

  /// CodeWalk UI string — onboardingSaveAndTest
  ///
  /// In en, this message translates to:
  /// **'Save and test'**
  String get onboardingSaveAndTest;

  /// CodeWalk UI string — onboardingServerConnectedReady
  ///
  /// In en, this message translates to:
  /// **'Your server is connected and ready to use.'**
  String get onboardingServerConnectedReady;

  /// CodeWalk UI string — onboardingServerConnection
  ///
  /// In en, this message translates to:
  /// **'Server connection'**
  String get onboardingServerConnection;

  /// CodeWalk UI string — onboardingServerSettingsSaved
  ///
  /// In en, this message translates to:
  /// **'Your server settings were saved and health checks were refreshed.'**
  String get onboardingServerSettingsSaved;

  /// CodeWalk UI string — onboardingServerSetup
  ///
  /// In en, this message translates to:
  /// **'Server setup'**
  String get onboardingServerSetup;

  /// CodeWalk UI string — onboardingServerUpdated
  ///
  /// In en, this message translates to:
  /// **'Server updated'**
  String get onboardingServerUpdated;

  /// CodeWalk UI string — onboardingServerUrl
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get onboardingServerUrl;

  /// CodeWalk UI string — onboardingSetup
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get onboardingSetup;

  /// CodeWalk UI string — onboardingSetupWizard
  ///
  /// In en, this message translates to:
  /// **'Setup wizard'**
  String get onboardingSetupWizard;

  /// CodeWalk UI string — onboardingShowSetupSteps
  ///
  /// In en, this message translates to:
  /// **'Show me the setup steps'**
  String get onboardingShowSetupSteps;

  /// CodeWalk UI string — onboardingShowSetupSteps2
  ///
  /// In en, this message translates to:
  /// **'Show setup steps'**
  String get onboardingShowSetupSteps2;

  /// CodeWalk UI string — onboardingSkip
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get onboardingSkip;

  /// CodeWalk UI string — onboardingSkipSetup
  ///
  /// In en, this message translates to:
  /// **'Skip setup?'**
  String get onboardingSkipSetup;

  /// CodeWalk UI string — onboardingStart
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get onboardingStart;

  /// CodeWalk UI string — onboardingStartUsing
  ///
  /// In en, this message translates to:
  /// **'Start using {appName}'**
  String onboardingStartUsing(String appName);

  /// CodeWalk UI string — onboardingStarting
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get onboardingStarting;

  /// CodeWalk UI string — onboardingStop
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get onboardingStop;

  /// CodeWalk UI string — onboardingStopped
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get onboardingStopped;

  /// CodeWalk UI string — onboardingStopping
  ///
  /// In en, this message translates to:
  /// **'Stopping'**
  String get onboardingStopping;

  /// CodeWalk UI string — onboardingSuggestedUrl
  ///
  /// In en, this message translates to:
  /// **'Suggested local OpenCode server URL: {url}'**
  String onboardingSuggestedUrl(String url);

  /// CodeWalk UI string — onboardingTailscaleAdminApproval
  ///
  /// In en, this message translates to:
  /// **'Tailscale admin approval required'**
  String get onboardingTailscaleAdminApproval;

  /// CodeWalk UI string — onboardingTailscaleAuthAfterSave
  ///
  /// In en, this message translates to:
  /// **'Tailscale will authenticate after saving'**
  String get onboardingTailscaleAuthAfterSave;

  /// CodeWalk UI string — onboardingTailscaleAuthAfterSaveTest
  ///
  /// In en, this message translates to:
  /// **'After you save and test this server, {appName} will open Tailscale login if this device is not authenticated yet.'**
  String onboardingTailscaleAuthAfterSaveTest(String appName);

  /// CodeWalk UI string — onboardingTailscaleConnected
  ///
  /// In en, this message translates to:
  /// **'Tailscale connected'**
  String get onboardingTailscaleConnected;

  /// CodeWalk UI string — onboardingTailscaleConnecting
  ///
  /// In en, this message translates to:
  /// **'Tailscale connecting'**
  String get onboardingTailscaleConnecting;

  /// CodeWalk UI string — onboardingTailscaleConnectionFailed
  ///
  /// In en, this message translates to:
  /// **'Tailscale connection failed'**
  String get onboardingTailscaleConnectionFailed;

  /// CodeWalk UI string — onboardingTailscaleLoginRequired
  ///
  /// In en, this message translates to:
  /// **'Tailscale login required'**
  String get onboardingTailscaleLoginRequired;

  /// CodeWalk UI string — onboardingTailscaleOpenLoginUrl
  ///
  /// In en, this message translates to:
  /// **'Open the login URL to add this device to your tailnet. If the browser did not open, copy the URL below.'**
  String get onboardingTailscaleOpenLoginUrl;

  /// CodeWalk UI string — onboardingTailscaleUnsupported
  ///
  /// In en, this message translates to:
  /// **'Tailscale unsupported'**
  String get onboardingTailscaleUnsupported;

  /// CodeWalk UI string — onboardingTestConnection
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get onboardingTestConnection;

  /// CodeWalk UI string — onboardingTesting
  ///
  /// In en, this message translates to:
  /// **'Testing...'**
  String get onboardingTesting;

  /// CodeWalk UI string — onboardingUnreachable
  ///
  /// In en, this message translates to:
  /// **'unreachable'**
  String get onboardingUnreachable;

  /// CodeWalk UI string — onboardingUseBasicAuth
  ///
  /// In en, this message translates to:
  /// **'Use Basic Auth'**
  String get onboardingUseBasicAuth;

  /// CodeWalk UI string — onboardingUsername
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get onboardingUsername;

  /// CodeWalk UI string — onboardingUsernameRequired
  ///
  /// In en, this message translates to:
  /// **'Enter username'**
  String get onboardingUsernameRequired;

  /// CodeWalk UI string — onboardingUsesServerTitle
  ///
  /// In en, this message translates to:
  /// **'Uses your server\'\'s title agent to name conversations'**
  String get onboardingUsesServerTitle;

  /// CodeWalk UI string — onboardingUsingDetectedCommand
  ///
  /// In en, this message translates to:
  /// **'Using detected OpenCode command.'**
  String get onboardingUsingDetectedCommand;

  /// CodeWalk UI string — onboardingViewSetupDebug
  ///
  /// In en, this message translates to:
  /// **'View setup debug'**
  String get onboardingViewSetupDebug;

  /// CodeWalk UI string — onboardingWelcomeTo
  ///
  /// In en, this message translates to:
  /// **'Welcome to {appName}'**
  String onboardingWelcomeTo(String appName);

  /// CodeWalk UI string — onboardingWindowsTipInstalling
  ///
  /// In en, this message translates to:
  /// **'Windows tip: after installing, click Refresh Checks. If detection still fails, reopen CodeWalk to reload PATH changes.'**
  String get onboardingWindowsTipInstalling;

  /// CodeWalk UI string — onboardingWritable
  ///
  /// In en, this message translates to:
  /// **'writable'**
  String get onboardingWritable;

  /// CodeWalk UI string — onboardingYoureAllSet
  ///
  /// In en, this message translates to:
  /// **'You\'\'re all set!'**
  String get onboardingYoureAllSet;

  /// CodeWalk UI string — permissionAllowOnce
  ///
  /// In en, this message translates to:
  /// **'Allow Once'**
  String get permissionAllowOnce;

  /// CodeWalk UI string — permissionAlways
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get permissionAlways;

  /// CodeWalk UI string — permissionBack
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get permissionBack;

  /// CodeWalk UI string — permissionConfirmReject
  ///
  /// In en, this message translates to:
  /// **'Confirm Reject'**
  String get permissionConfirmReject;

  /// CodeWalk UI string — permissionReject
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get permissionReject;

  /// CodeWalk UI string — permissionReopen
  ///
  /// In en, this message translates to:
  /// **'Reopen'**
  String get permissionReopen;

  /// CodeWalk UI string — questionAnswerSelected
  ///
  /// In en, this message translates to:
  /// **'No answer selected.'**
  String get questionAnswerSelected;

  /// CodeWalk UI string — questionCommaSeparatedValues
  ///
  /// In en, this message translates to:
  /// **'Comma-separated values'**
  String get questionCommaSeparatedValues;

  /// CodeWalk UI string — questionQuestionGroupMarked
  ///
  /// In en, this message translates to:
  /// **'Question group marked as rejected. You can keep chatting and reopen this group anytime before confirming.'**
  String get questionQuestionGroupMarked;

  /// CodeWalk UI string — questionQuestionRequest
  ///
  /// In en, this message translates to:
  /// **'Question request'**
  String get questionQuestionRequest;

  /// CodeWalk UI string — questionQuestionsProvidedSubmit
  ///
  /// In en, this message translates to:
  /// **'No questions provided. You can submit an empty response.'**
  String get questionQuestionsProvidedSubmit;

  /// CodeWalk UI string — questionReviewAnswersSubmitting
  ///
  /// In en, this message translates to:
  /// **'Review your answers before submitting.'**
  String get questionReviewAnswersSubmitting;

  /// CodeWalk UI string — quotaAuthCookie
  ///
  /// In en, this message translates to:
  /// **'Auth cookie'**
  String get quotaAuthCookie;

  /// CodeWalk UI string — quotaConnect
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get quotaConnect;

  /// CodeWalk UI string — quotaForget
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get quotaForget;

  /// CodeWalk UI string — quotaOpenCodeGoConnectDescription
  ///
  /// In en, this message translates to:
  /// **'Connect the usage dashboard to show rolling, weekly, and monthly limits.'**
  String get quotaOpenCodeGoConnectDescription;

  /// CodeWalk UI string — quotaOpenCodeGoDetected
  ///
  /// In en, this message translates to:
  /// **'OpenCode Go detected'**
  String get quotaOpenCodeGoDetected;

  /// CodeWalk UI string — quotaOpenCodeGoNeedsReconnect
  ///
  /// In en, this message translates to:
  /// **'OpenCode Go needs reconnect'**
  String get quotaOpenCodeGoNeedsReconnect;

  /// CodeWalk UI string — quotaOpenCodeGoReconnectDescription
  ///
  /// In en, this message translates to:
  /// **'Refresh the dashboard credentials to restore usage bars.'**
  String get quotaOpenCodeGoReconnectDescription;

  /// CodeWalk UI string — quotaOpenCodeGoUsage
  ///
  /// In en, this message translates to:
  /// **'OpenCode Go usage'**
  String get quotaOpenCodeGoUsage;

  /// CodeWalk UI string — quotaOpenDashboard
  ///
  /// In en, this message translates to:
  /// **'Open OpenCode dashboard'**
  String get quotaOpenDashboard;

  /// CodeWalk UI string — quotaPaceExplanation
  ///
  /// In en, this message translates to:
  /// **'Pace predicts total usage by the end of the current limit window based on the current rate.'**
  String get quotaPaceExplanation;

  /// CodeWalk UI string — quotaPacePercent
  ///
  /// In en, this message translates to:
  /// **'Pace {percent}%'**
  String quotaPacePercent(String percent);

  /// CodeWalk UI string — quotaRateLimits
  ///
  /// In en, this message translates to:
  /// **'Rate limits'**
  String get quotaRateLimits;

  /// CodeWalk UI string — quotaReconnect
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get quotaReconnect;

  /// CodeWalk UI string — quotaRefreshing
  ///
  /// In en, this message translates to:
  /// **'Refreshing...'**
  String get quotaRefreshing;

  /// CodeWalk UI string — quotaResetsIn
  ///
  /// In en, this message translates to:
  /// **'Resets in {time}'**
  String quotaResetsIn(String time);

  /// CodeWalk UI string — quotaSaving
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get quotaSaving;

  /// CodeWalk UI string — quotaWorkspaceId
  ///
  /// In en, this message translates to:
  /// **'Workspace ID'**
  String get quotaWorkspaceId;

  /// CodeWalk UI string — serverClearOAuth
  ///
  /// In en, this message translates to:
  /// **'Clear OAuth'**
  String get serverClearOAuth;

  /// CodeWalk UI string — serverConnectionAttention
  ///
  /// In en, this message translates to:
  /// **'Server connection needs attention.'**
  String get serverConnectionAttention;

  /// CodeWalk UI string — serverHealthHealthy
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get serverHealthHealthy;

  /// CodeWalk UI string — serverHealthUnhealthy
  ///
  /// In en, this message translates to:
  /// **'Unhealthy'**
  String get serverHealthUnhealthy;

  /// CodeWalk UI string — serverHealthUnknown
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get serverHealthUnknown;

  /// CodeWalk UI string — serverOAuthAuthFailed
  ///
  /// In en, this message translates to:
  /// **'OAuth authentication failed'**
  String get serverOAuthAuthFailed;

  /// CodeWalk UI string — serverOAuthChip
  ///
  /// In en, this message translates to:
  /// **'OAuth'**
  String get serverOAuthChip;

  /// CodeWalk UI string — serverOAuthNotSupported
  ///
  /// In en, this message translates to:
  /// **'Cloudflare Access OAuth is not supported on this platform'**
  String get serverOAuthNotSupported;

  /// CodeWalk UI string — serverReauthenticate
  ///
  /// In en, this message translates to:
  /// **'Re-authenticate'**
  String get serverReauthenticate;

  /// CodeWalk UI string — serverTailscaleChip
  ///
  /// In en, this message translates to:
  /// **'Tailscale'**
  String get serverTailscaleChip;

  /// CodeWalk UI string — serversActive
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get serversActive;

  /// CodeWalk UI string — serversActiveServer
  ///
  /// In en, this message translates to:
  /// **'Active Server'**
  String get serversActiveServer;

  /// CodeWalk UI string — serversAddLeastOpenCode
  ///
  /// In en, this message translates to:
  /// **'Add at least one OpenCode server to start using the app.'**
  String get serversAddLeastOpenCode;

  /// CodeWalk UI string — serversAddServer
  ///
  /// In en, this message translates to:
  /// **'Add Server'**
  String get serversAddServer;

  /// CodeWalk UI string — serversCancel
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get serversCancel;

  /// CodeWalk UI string — serversCannotActivateUnhealthy
  ///
  /// In en, this message translates to:
  /// **'Cannot activate an unhealthy server'**
  String get serversCannotActivateUnhealthy;

  /// CodeWalk UI string — serversCheckHealth
  ///
  /// In en, this message translates to:
  /// **'Check Health'**
  String get serversCheckHealth;

  /// CodeWalk UI string — serversClearDefault
  ///
  /// In en, this message translates to:
  /// **'Clear Default'**
  String get serversClearDefault;

  /// CodeWalk UI string — serversCommandAppProviderLocalServerCommandPath
  ///
  /// In en, this message translates to:
  /// **'Command: {localServerCommandPath}'**
  String serversCommandAppProviderLocalServerCommandPath(
    String localServerCommandPath,
  );

  /// CodeWalk UI string — serversCopy
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get serversCopy;

  /// CodeWalk UI string — serversDefault
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get serversDefault;

  /// CodeWalk UI string — serversDelete
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get serversDelete;

  /// CodeWalk UI string — serversDeleteServer
  ///
  /// In en, this message translates to:
  /// **'Delete server'**
  String get serversDeleteServer;

  /// CodeWalk UI string — serversDesktopModeExplanation
  ///
  /// In en, this message translates to:
  /// **'Desktop mode can launch and manage `opencode serve` directly from CodeWalk.'**
  String get serversDesktopModeExplanation;

  /// CodeWalk UI string — serversEdit
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get serversEdit;

  /// CodeWalk UI string — serversLocalOpenCodeServer
  ///
  /// In en, this message translates to:
  /// **'Local OpenCode Server'**
  String get serversLocalOpenCodeServer;

  /// CodeWalk UI string — serversManagedModeAvailable
  ///
  /// In en, this message translates to:
  /// **'This managed mode is available only on desktop builds (Linux/macOS/Windows).'**
  String get serversManagedModeAvailable;

  /// CodeWalk UI string — serversNoServersFound
  ///
  /// In en, this message translates to:
  /// **'No servers found'**
  String get serversNoServersFound;

  /// CodeWalk UI string — serversRefreshHealth
  ///
  /// In en, this message translates to:
  /// **'Refresh Health'**
  String get serversRefreshHealth;

  /// CodeWalk UI string — serversRemoveProfileDisplayName
  ///
  /// In en, this message translates to:
  /// **'Remove \"{displayName}\"?'**
  String serversRemoveProfileDisplayName(String displayName);

  /// CodeWalk UI string — serversSearchActiveHint
  ///
  /// In en, this message translates to:
  /// **'Search active server'**
  String get serversSearchActiveHint;

  /// CodeWalk UI string — serversServersConfigured
  ///
  /// In en, this message translates to:
  /// **'No servers configured'**
  String get serversServersConfigured;

  /// CodeWalk UI string — serversSetActive
  ///
  /// In en, this message translates to:
  /// **'Set Active'**
  String get serversSetActive;

  /// CodeWalk UI string — serversSetDefault
  ///
  /// In en, this message translates to:
  /// **'Set Default'**
  String get serversSetDefault;

  /// CodeWalk UI string — serversSetupDebug
  ///
  /// In en, this message translates to:
  /// **'Setup Debug'**
  String get serversSetupDebug;

  /// CodeWalk UI string — serversSetupWizard
  ///
  /// In en, this message translates to:
  /// **'Setup Wizard'**
  String get serversSetupWizard;

  /// CodeWalk UI string — serversTailscaleAdminApprovalRequired
  ///
  /// In en, this message translates to:
  /// **'Tailscale admin approval required'**
  String get serversTailscaleAdminApprovalRequired;

  /// CodeWalk UI string — serversTailscaleAuthRequired
  ///
  /// In en, this message translates to:
  /// **'Tailscale authentication required'**
  String get serversTailscaleAuthRequired;

  /// CodeWalk UI string — serversTailscaleConnectExplanation
  ///
  /// In en, this message translates to:
  /// **'Tailscale will connect when this active profile is used.'**
  String get serversTailscaleConnectExplanation;

  /// CodeWalk UI string — serversTailscaleConnected
  ///
  /// In en, this message translates to:
  /// **'Tailscale connected'**
  String get serversTailscaleConnected;

  /// CodeWalk UI string — serversTailscaleConnecting
  ///
  /// In en, this message translates to:
  /// **'Tailscale connecting'**
  String get serversTailscaleConnecting;

  /// CodeWalk UI string — serversTailscaleConnectionFailed
  ///
  /// In en, this message translates to:
  /// **'Tailscale connection failed'**
  String get serversTailscaleConnectionFailed;

  /// CodeWalk UI string — serversTailscaleDisconnected
  ///
  /// In en, this message translates to:
  /// **'Tailscale disconnected'**
  String get serversTailscaleDisconnected;

  /// CodeWalk UI string — serversTailscaleLoginExplanation
  ///
  /// In en, this message translates to:
  /// **'Open the Tailscale login URL to add this device to your tailnet.'**
  String get serversTailscaleLoginExplanation;

  /// CodeWalk UI string — serversTailscaleLogout
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get serversTailscaleLogout;

  /// CodeWalk UI string — serversTailscaleLogoutConfirmMessage
  ///
  /// In en, this message translates to:
  /// **'This device will leave the tailnet. You can log in again at any time.'**
  String get serversTailscaleLogoutConfirmMessage;

  /// CodeWalk UI string — serversTailscaleLogoutConfirmTitle
  ///
  /// In en, this message translates to:
  /// **'Log out of Tailscale?'**
  String get serversTailscaleLogoutConfirmTitle;

  /// CodeWalk UI string — serversTailscaleReconnect
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get serversTailscaleReconnect;

  /// CodeWalk UI string — serversTailscaleTrafficExplanation
  ///
  /// In en, this message translates to:
  /// **'OpenCode traffic for this active profile is routed through Tailscale.'**
  String get serversTailscaleTrafficExplanation;

  /// CodeWalk UI string — serversTailscaleUnsupported
  ///
  /// In en, this message translates to:
  /// **'Tailscale unsupported'**
  String get serversTailscaleUnsupported;

  /// CodeWalk UI string — serversUnhealthyActivateError
  ///
  /// In en, this message translates to:
  /// **'This server is unhealthy. Use check health or edit settings before activating.'**
  String get serversUnhealthyActivateError;

  /// CodeWalk UI string — sessionActionArchived
  ///
  /// In en, this message translates to:
  /// **'archived'**
  String get sessionActionArchived;

  /// CodeWalk UI string — sessionActionDeleted
  ///
  /// In en, this message translates to:
  /// **'deleted'**
  String get sessionActionDeleted;

  /// CodeWalk UI string — sessionActionForked
  ///
  /// In en, this message translates to:
  /// **'forked'**
  String get sessionActionForked;

  /// CodeWalk UI string — sessionActionPinned
  ///
  /// In en, this message translates to:
  /// **'pinned'**
  String get sessionActionPinned;

  /// CodeWalk UI string — sessionActionUnarchived
  ///
  /// In en, this message translates to:
  /// **'unarchived'**
  String get sessionActionUnarchived;

  /// CodeWalk UI string — sessionActionUnpinned
  ///
  /// In en, this message translates to:
  /// **'unpinned'**
  String get sessionActionUnpinned;

  /// CodeWalk UI string — sessionArchive
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get sessionArchive;

  /// CodeWalk UI string — sessionCancelRename
  ///
  /// In en, this message translates to:
  /// **'Cancel rename'**
  String get sessionCancelRename;

  /// CodeWalk UI string — sessionChildrenCount
  ///
  /// In en, this message translates to:
  /// **'Children: {count}'**
  String sessionChildrenCount(int count);

  /// CodeWalk UI string — sessionCompactContext
  ///
  /// In en, this message translates to:
  /// **'Compact context'**
  String get sessionCompactContext;

  /// CodeWalk UI string — sessionCopyLink
  ///
  /// In en, this message translates to:
  /// **'Copy Link'**
  String get sessionCopyLink;

  /// CodeWalk UI string — sessionDelete
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get sessionDelete;

  /// CodeWalk UI string — sessionDeleteConfirm
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the conversation \"{title}\"? This action cannot be undone.'**
  String sessionDeleteConfirm(String title);

  /// CodeWalk UI string — sessionDeleteTitle
  ///
  /// In en, this message translates to:
  /// **'Delete Conversation'**
  String get sessionDeleteTitle;

  /// CodeWalk UI string — sessionDiffChangedFile
  ///
  /// In en, this message translates to:
  /// **'Changed file'**
  String get sessionDiffChangedFile;

  /// CodeWalk UI string — sessionDiffContentNotCaptured
  ///
  /// In en, this message translates to:
  /// **'File content not captured by the server'**
  String get sessionDiffContentNotCaptured;

  /// CodeWalk UI string — sessionDiffFilesChanged
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file changed} other{{count} files changed}}'**
  String sessionDiffFilesChanged(int count);

  /// CodeWalk UI string — sessionDiffFilesCount
  ///
  /// In en, this message translates to:
  /// **'Diff files: {count}'**
  String sessionDiffFilesCount(int count);

  /// CodeWalk UI string — sessionDiffLinesAddedRemoved
  ///
  /// In en, this message translates to:
  /// **'+{added} lines added -{removed} lines removed'**
  String sessionDiffLinesAddedRemoved(int added, int removed);

  /// CodeWalk UI string — sessionDiffLinesCollapsed
  ///
  /// In en, this message translates to:
  /// **'{count} lines collapsed — tap to expand'**
  String sessionDiffLinesCollapsed(int count);

  /// CodeWalk UI string — sessionDiffLoading
  ///
  /// In en, this message translates to:
  /// **'Loading changed files…'**
  String get sessionDiffLoading;

  /// CodeWalk UI string — sessionDiffReview
  ///
  /// In en, this message translates to:
  /// **'Review changes'**
  String get sessionDiffReview;

  /// CodeWalk UI string — sessionDiffSplit
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get sessionDiffSplit;

  /// CodeWalk UI string — sessionDiffSummary
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get sessionDiffSummary;

  /// CodeWalk UI string — sessionDiffUnified
  ///
  /// In en, this message translates to:
  /// **'Unified'**
  String get sessionDiffUnified;

  /// CodeWalk UI string — sessionExportAssistant
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get sessionExportAssistant;

  /// CodeWalk UI string — sessionExportCanceled
  ///
  /// In en, this message translates to:
  /// **'Session export canceled'**
  String get sessionExportCanceled;

  /// CodeWalk UI string — sessionExportDebugJson
  ///
  /// In en, this message translates to:
  /// **'Export debug JSON'**
  String get sessionExportDebugJson;

  /// CodeWalk UI string — sessionExportDebugJsonErrorClipboard
  ///
  /// In en, this message translates to:
  /// **'Could not save file; debug JSON copied to clipboard'**
  String get sessionExportDebugJsonErrorClipboard;

  /// CodeWalk UI string — sessionExportDebugJsonSaved
  ///
  /// In en, this message translates to:
  /// **'Debug JSON export saved'**
  String get sessionExportDebugJsonSaved;

  /// CodeWalk UI string — sessionExportDebugJsonTitle
  ///
  /// In en, this message translates to:
  /// **'Export session as debug JSON'**
  String get sessionExportDebugJsonTitle;

  /// CodeWalk UI string — sessionExportError
  ///
  /// In en, this message translates to:
  /// **'Error:'**
  String get sessionExportError;

  /// CodeWalk UI string — sessionExportInput
  ///
  /// In en, this message translates to:
  /// **'Input:'**
  String get sessionExportInput;

  /// CodeWalk UI string — sessionExportMarkdown
  ///
  /// In en, this message translates to:
  /// **'Export Markdown'**
  String get sessionExportMarkdown;

  /// CodeWalk UI string — sessionExportMarkdownErrorClipboard
  ///
  /// In en, this message translates to:
  /// **'Could not save file; Markdown copied to clipboard'**
  String get sessionExportMarkdownErrorClipboard;

  /// CodeWalk UI string — sessionExportMarkdownSaved
  ///
  /// In en, this message translates to:
  /// **'Markdown export saved'**
  String get sessionExportMarkdownSaved;

  /// CodeWalk UI string — sessionExportMarkdownTitle
  ///
  /// In en, this message translates to:
  /// **'Export session as Markdown'**
  String get sessionExportMarkdownTitle;

  /// CodeWalk UI string — sessionExportOutput
  ///
  /// In en, this message translates to:
  /// **'Output:'**
  String get sessionExportOutput;

  /// CodeWalk UI string — sessionExportUntitled
  ///
  /// In en, this message translates to:
  /// **'Untitled session'**
  String get sessionExportUntitled;

  /// CodeWalk UI string — sessionExportUser
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get sessionExportUser;

  /// CodeWalk UI string — sessionFailedRename
  ///
  /// In en, this message translates to:
  /// **'Failed to rename conversation'**
  String get sessionFailedRename;

  /// CodeWalk UI string — sessionFailedUpdateArchive
  ///
  /// In en, this message translates to:
  /// **'Failed to update archive state'**
  String get sessionFailedUpdateArchive;

  /// CodeWalk UI string — sessionFailedUpdateSharing
  ///
  /// In en, this message translates to:
  /// **'Failed to update sharing state'**
  String get sessionFailedUpdateSharing;

  /// CodeWalk UI string — sessionFork
  ///
  /// In en, this message translates to:
  /// **'Fork'**
  String get sessionFork;

  /// CodeWalk UI string — sessionForkFailed
  ///
  /// In en, this message translates to:
  /// **'Failed to fork conversation'**
  String get sessionForkFailed;

  /// CodeWalk UI string — sessionForked
  ///
  /// In en, this message translates to:
  /// **'Conversation forked'**
  String get sessionForked;

  /// CodeWalk UI string — sessionHasError
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" has an error.'**
  String sessionHasError(String title);

  /// CodeWalk UI string — sessionHasNewReply
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" has a new reply.'**
  String sessionHasNewReply(String title);

  /// CodeWalk UI string — sessionKeyboardShortcuts
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get sessionKeyboardShortcuts;

  /// CodeWalk UI string — sessionNeedsInput
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" needs your input.'**
  String sessionNeedsInput(String title);

  /// CodeWalk UI string — sessionNoCachedConversations
  ///
  /// In en, this message translates to:
  /// **'No cached conversations yet'**
  String get sessionNoCachedConversations;

  /// CodeWalk UI string — sessionNoConversationsInProject
  ///
  /// In en, this message translates to:
  /// **'No conversations in this project.'**
  String get sessionNoConversationsInProject;

  /// CodeWalk UI string — sessionNotAvailable
  ///
  /// In en, this message translates to:
  /// **'Conversation is not available for this project yet'**
  String get sessionNotAvailable;

  /// CodeWalk UI string — sessionOpenProjectToLoad
  ///
  /// In en, this message translates to:
  /// **'Open project to load conversations.'**
  String get sessionOpenProjectToLoad;

  /// CodeWalk UI string — sessionPin
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get sessionPin;

  /// CodeWalk UI string — sessionRename
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get sessionRename;

  /// CodeWalk UI string — sessionRenameHint
  ///
  /// In en, this message translates to:
  /// **'Enter new conversation name'**
  String get sessionRenameHint;

  /// CodeWalk UI string — sessionRenameTitle
  ///
  /// In en, this message translates to:
  /// **'Rename Conversation'**
  String get sessionRenameTitle;

  /// CodeWalk UI string — sessionSaveTitle
  ///
  /// In en, this message translates to:
  /// **'Save title'**
  String get sessionSaveTitle;

  /// CodeWalk UI string — sessionShare
  ///
  /// In en, this message translates to:
  /// **'Share session'**
  String get sessionShare;

  /// CodeWalk UI string — sessionShareAction
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get sessionShareAction;

  /// CodeWalk UI string — sessionShareLinkCopied
  ///
  /// In en, this message translates to:
  /// **'Share link copied'**
  String get sessionShareLinkCopied;

  /// CodeWalk UI string — sessionShareLinkUnavailable
  ///
  /// In en, this message translates to:
  /// **'Share link unavailable for this session'**
  String get sessionShareLinkUnavailable;

  /// CodeWalk UI string — sessionShared
  ///
  /// In en, this message translates to:
  /// **'Conversation shared'**
  String get sessionShared;

  /// CodeWalk UI string — sessionSyncing
  ///
  /// In en, this message translates to:
  /// **'Syncing conversations...'**
  String get sessionSyncing;

  /// CodeWalk UI string — sessionTitleHint
  ///
  /// In en, this message translates to:
  /// **'Conversation title'**
  String get sessionTitleHint;

  /// CodeWalk UI string — sessionUnarchive
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get sessionUnarchive;

  /// CodeWalk UI string — sessionUnpin
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get sessionUnpin;

  /// CodeWalk UI string — sessionUnshare
  ///
  /// In en, this message translates to:
  /// **'Unshare session'**
  String get sessionUnshare;

  /// CodeWalk UI string — sessionUnshareAction
  ///
  /// In en, this message translates to:
  /// **'Unshare'**
  String get sessionUnshareAction;

  /// CodeWalk UI string — sessionUnshared
  ///
  /// In en, this message translates to:
  /// **'Conversation unshared'**
  String get sessionUnshared;

  /// CodeWalk UI string — sessionViewTasks
  ///
  /// In en, this message translates to:
  /// **'View tasks'**
  String get sessionViewTasks;

  /// CodeWalk UI string — settingsAboutCheckForUpdates
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get settingsAboutCheckForUpdates;

  /// CodeWalk UI string — settingsAboutCheckOnOpen
  ///
  /// In en, this message translates to:
  /// **'Check for updates on open'**
  String get settingsAboutCheckOnOpen;

  /// CodeWalk UI string — settingsAboutCheckOnOpenDescription
  ///
  /// In en, this message translates to:
  /// **'Automatically check when the app starts'**
  String get settingsAboutCheckOnOpenDescription;

  /// CodeWalk UI string — settingsAboutChecking
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get settingsAboutChecking;

  /// CodeWalk UI string — settingsAboutDescription
  ///
  /// In en, this message translates to:
  /// **'Version, updates, help, and app data'**
  String get settingsAboutDescription;

  /// CodeWalk UI string — settingsAboutDismiss
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get settingsAboutDismiss;

  /// CodeWalk UI string — settingsAboutDownloading
  ///
  /// In en, this message translates to:
  /// **'Downloading... {percent}%'**
  String settingsAboutDownloading(String percent);

  /// CodeWalk UI string — settingsAboutEraseAllData
  ///
  /// In en, this message translates to:
  /// **'Erase all data and restart'**
  String get settingsAboutEraseAllData;

  /// CodeWalk UI string — settingsAboutInstallUpdate
  ///
  /// In en, this message translates to:
  /// **'Install update'**
  String get settingsAboutInstallUpdate;

  /// CodeWalk UI string — settingsAboutInstalling
  ///
  /// In en, this message translates to:
  /// **'Installing...'**
  String get settingsAboutInstalling;

  /// CodeWalk UI string — settingsAboutLatestVersion
  ///
  /// In en, this message translates to:
  /// **'v{version} is the latest version'**
  String settingsAboutLatestVersion(String version);

  /// CodeWalk UI string — settingsAboutLoading
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get settingsAboutLoading;

  /// CodeWalk UI string — settingsAboutReplayChatTour
  ///
  /// In en, this message translates to:
  /// **'Replay chat tour'**
  String get settingsAboutReplayChatTour;

  /// CodeWalk UI string — settingsAboutReplayChatTourDescription
  ///
  /// In en, this message translates to:
  /// **'Close settings and show the guided chat walkthrough'**
  String get settingsAboutReplayChatTourDescription;

  /// CodeWalk UI string — settingsAboutResetApp
  ///
  /// In en, this message translates to:
  /// **'Reset app'**
  String get settingsAboutResetApp;

  /// CodeWalk UI string — settingsAboutResetAppQuestion
  ///
  /// In en, this message translates to:
  /// **'Reset app?'**
  String get settingsAboutResetAppQuestion;

  /// CodeWalk UI string — settingsAboutResetAppWarning
  ///
  /// In en, this message translates to:
  /// **'This will erase all servers, settings, and cached data. This action cannot be undone.'**
  String get settingsAboutResetAppWarning;

  /// CodeWalk UI string — settingsAboutRetryInstall
  ///
  /// In en, this message translates to:
  /// **'Retry install'**
  String get settingsAboutRetryInstall;

  /// CodeWalk UI string — settingsAboutTapToCheck
  ///
  /// In en, this message translates to:
  /// **'Tap to check for new versions'**
  String get settingsAboutTapToCheck;

  /// CodeWalk UI string — settingsAboutTitle
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutTitle;

  /// CodeWalk UI string — settingsAboutUpToDate
  ///
  /// In en, this message translates to:
  /// **'You\'\'re up to date'**
  String get settingsAboutUpToDate;

  /// CodeWalk UI string — settingsAboutUpdateAvailable
  ///
  /// In en, this message translates to:
  /// **'Update available: v{version}'**
  String settingsAboutUpdateAvailable(String version);

  /// CodeWalk UI string — settingsAboutUpdateInstalled
  ///
  /// In en, this message translates to:
  /// **'Update installed. Restart the app to apply.'**
  String get settingsAboutUpdateInstalled;

  /// CodeWalk UI string — settingsAboutUpdateVersionSummary
  ///
  /// In en, this message translates to:
  /// **'Current: {installedVersion}; available: v{latestVersion}'**
  String settingsAboutUpdateVersionSummary(
    String installedVersion,
    String latestVersion,
  );

  /// CodeWalk UI string — settingsAboutVersion
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsAboutVersion;

  /// CodeWalk UI string — settingsAboutVersionBuild
  ///
  /// In en, this message translates to:
  /// **'{version} (build {buildNumber})'**
  String settingsAboutVersionBuild(String buildNumber, String version);

  /// CodeWalk UI string — settingsAppearanceAmoledDark
  ///
  /// In en, this message translates to:
  /// **'AMOLED dark mode'**
  String get settingsAppearanceAmoledDark;

  /// CodeWalk UI string — settingsAppearanceAmoledDarkActive
  ///
  /// In en, this message translates to:
  /// **'Use pure black surfaces while dark mode is active.'**
  String get settingsAppearanceAmoledDarkActive;

  /// CodeWalk UI string — settingsAppearanceAmoledDarkInactive
  ///
  /// In en, this message translates to:
  /// **'Switch to dark mode to enable AMOLED surfaces.'**
  String get settingsAppearanceAmoledDarkInactive;

  /// CodeWalk UI string — settingsAppearanceBrandColor
  ///
  /// In en, this message translates to:
  /// **'Brand color'**
  String get settingsAppearanceBrandColor;

  /// CodeWalk UI string — settingsAppearanceBrandColorDynamicBlocked
  ///
  /// In en, this message translates to:
  /// **'Disable wallpaper colors to pick a brand color.'**
  String get settingsAppearanceBrandColorDynamicBlocked;

  /// CodeWalk UI string — settingsAppearanceBrandColorNormal
  ///
  /// In en, this message translates to:
  /// **'Pick a seed color for the app palette.'**
  String get settingsAppearanceBrandColorNormal;

  /// CodeWalk UI string — settingsAppearanceBrandColorPresetBlocked
  ///
  /// In en, this message translates to:
  /// **'Switch to CodeWalk Classic to pick a brand color.'**
  String get settingsAppearanceBrandColorPresetBlocked;

  /// CodeWalk UI string — settingsAppearanceChatFontScale
  ///
  /// In en, this message translates to:
  /// **'Conversation text size'**
  String get settingsAppearanceChatFontScale;

  /// CodeWalk UI string — settingsAppearanceChatFontScaleDescription
  ///
  /// In en, this message translates to:
  /// **'Scale the chat message and composer text on top of the system text size.'**
  String get settingsAppearanceChatFontScaleDescription;

  /// CodeWalk UI string — settingsAppearanceCodeWalkClassic
  ///
  /// In en, this message translates to:
  /// **'CodeWalk Classic'**
  String get settingsAppearanceCodeWalkClassic;

  /// CodeWalk UI string — settingsAppearanceComposerTips
  ///
  /// In en, this message translates to:
  /// **'Composer tips'**
  String get settingsAppearanceComposerTips;

  /// CodeWalk UI string — settingsAppearanceComposerTipsDescription
  ///
  /// In en, this message translates to:
  /// **'Show or hide rotating tips while the assistant is reasoning.'**
  String get settingsAppearanceComposerTipsDescription;

  /// CodeWalk UI string — settingsAppearanceContrast
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get settingsAppearanceContrast;

  /// CodeWalk UI string — settingsAppearanceContrastDynamicBlocked
  ///
  /// In en, this message translates to:
  /// **'Disable wallpaper colors to adjust contrast.'**
  String get settingsAppearanceContrastDynamicBlocked;

  /// CodeWalk UI string — settingsAppearanceContrastHigh
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get settingsAppearanceContrastHigh;

  /// CodeWalk UI string — settingsAppearanceContrastNormal
  ///
  /// In en, this message translates to:
  /// **'Adjust the contrast level of the color scheme.'**
  String get settingsAppearanceContrastNormal;

  /// CodeWalk UI string — settingsAppearanceContrastPresetBlocked
  ///
  /// In en, this message translates to:
  /// **'Switch to CodeWalk Classic to adjust contrast.'**
  String get settingsAppearanceContrastPresetBlocked;

  /// CodeWalk UI string — settingsAppearanceContrastReduced
  ///
  /// In en, this message translates to:
  /// **'Reduced'**
  String get settingsAppearanceContrastReduced;

  /// CodeWalk UI string — settingsAppearanceDark
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsAppearanceDark;

  /// CodeWalk UI string — settingsAppearanceDensity
  ///
  /// In en, this message translates to:
  /// **'Density'**
  String get settingsAppearanceDensity;

  /// CodeWalk UI string — settingsAppearanceDensityDense
  ///
  /// In en, this message translates to:
  /// **'Dense'**
  String get settingsAppearanceDensityDense;

  /// CodeWalk UI string — settingsAppearanceDensityDescription
  ///
  /// In en, this message translates to:
  /// **'Apply spacing and component density across the app.'**
  String get settingsAppearanceDensityDescription;

  /// CodeWalk UI string — settingsAppearanceDensityExtraDense
  ///
  /// In en, this message translates to:
  /// **'Extra Dense'**
  String get settingsAppearanceDensityExtraDense;

  /// CodeWalk UI string — settingsAppearanceDensityExtraSpacious
  ///
  /// In en, this message translates to:
  /// **'Extra Spacious'**
  String get settingsAppearanceDensityExtraSpacious;

  /// CodeWalk UI string — settingsAppearanceDensityNormal
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get settingsAppearanceDensityNormal;

  /// CodeWalk UI string — settingsAppearanceDensitySpacious
  ///
  /// In en, this message translates to:
  /// **'Spacious'**
  String get settingsAppearanceDensitySpacious;

  /// CodeWalk UI string — settingsAppearanceDescription
  ///
  /// In en, this message translates to:
  /// **'Choose themes, colors, text size, and chat display'**
  String get settingsAppearanceDescription;

  /// CodeWalk UI string — settingsAppearanceFontSize
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get settingsAppearanceFontSize;

  /// CodeWalk UI string — settingsAppearanceFontSizeDescription
  ///
  /// In en, this message translates to:
  /// **'Adjust the size of system text, conversation text, and terminal text.'**
  String get settingsAppearanceFontSizeDescription;

  /// CodeWalk UI string — settingsAppearanceLight
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsAppearanceLight;

  /// CodeWalk UI string — settingsAppearanceMathRendering
  ///
  /// In en, this message translates to:
  /// **'Math rendering'**
  String get settingsAppearanceMathRendering;

  /// CodeWalk UI string — settingsAppearanceMathRenderingDescription
  ///
  /// In en, this message translates to:
  /// **'Render LaTeX math expressions (\$…\$ and \$\$…\$\$) as typeset equations in chat messages.'**
  String get settingsAppearanceMathRenderingDescription;

  /// CodeWalk UI string — settingsAppearanceNoPresets
  ///
  /// In en, this message translates to:
  /// **'No preset palettes found'**
  String get settingsAppearanceNoPresets;

  /// CodeWalk UI string — settingsAppearanceOpenCodePresets
  ///
  /// In en, this message translates to:
  /// **'OpenCode Presets'**
  String get settingsAppearanceOpenCodePresets;

  /// CodeWalk UI string — settingsAppearancePresetHelper
  ///
  /// In en, this message translates to:
  /// **'Mirrors the official OpenCode Web built-in theme list.'**
  String get settingsAppearancePresetHelper;

  /// CodeWalk UI string — settingsAppearancePresetNote
  ///
  /// In en, this message translates to:
  /// **'Theme colors now follow the official OpenCode Web registry and drive markdown/code surfaces too.'**
  String get settingsAppearancePresetNote;

  /// CodeWalk UI string — settingsAppearancePresetPalette
  ///
  /// In en, this message translates to:
  /// **'Preset palette'**
  String get settingsAppearancePresetPalette;

  /// CodeWalk UI string — settingsAppearanceSearchPreset
  ///
  /// In en, this message translates to:
  /// **'Search preset palette'**
  String get settingsAppearanceSearchPreset;

  /// CodeWalk UI string — settingsAppearanceSectionDescription
  ///
  /// In en, this message translates to:
  /// **'Tune visual density and message surfaces for your workflow.'**
  String get settingsAppearanceSectionDescription;

  /// CodeWalk UI string — settingsAppearanceSectionTitle
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearanceSectionTitle;

  /// CodeWalk UI string — settingsAppearanceSystem
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsAppearanceSystem;

  /// CodeWalk UI string — settingsAppearanceSystemFontScale
  ///
  /// In en, this message translates to:
  /// **'System text size'**
  String get settingsAppearanceSystemFontScale;

  /// CodeWalk UI string — settingsAppearanceSystemFontScaleDescription
  ///
  /// In en, this message translates to:
  /// **'Scale all text in the app shell, including menus, dialogs, and sidebars.'**
  String get settingsAppearanceSystemFontScaleDescription;

  /// CodeWalk UI string — settingsAppearanceTaskList
  ///
  /// In en, this message translates to:
  /// **'Task list'**
  String get settingsAppearanceTaskList;

  /// CodeWalk UI string — settingsAppearanceTaskListDescription
  ///
  /// In en, this message translates to:
  /// **'Show or hide the session task list widget.'**
  String get settingsAppearanceTaskListDescription;

  /// CodeWalk UI string — settingsAppearanceTerminalFontSize
  ///
  /// In en, this message translates to:
  /// **'Terminal text size'**
  String get settingsAppearanceTerminalFontSize;

  /// CodeWalk UI string — settingsAppearanceTerminalFontSizeDescription
  ///
  /// In en, this message translates to:
  /// **'Resize the embedded terminal font. Applies immediately to running sessions.'**
  String get settingsAppearanceTerminalFontSizeDescription;

  /// CodeWalk UI string — settingsAppearanceTheme
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsAppearanceTheme;

  /// CodeWalk UI string — settingsAppearanceThemeDescription
  ///
  /// In en, this message translates to:
  /// **'Choose light, dark, or system mode, then keep the CodeWalk classic palette or switch to an OpenCode preset.'**
  String get settingsAppearanceThemeDescription;

  /// CodeWalk UI string — settingsAppearanceVisualStyle
  ///
  /// In en, this message translates to:
  /// **'Visual style'**
  String get settingsAppearanceVisualStyle;

  /// CodeWalk UI string — settingsAppearanceVisualStyleDescription
  ///
  /// In en, this message translates to:
  /// **'Choose Classic or softer Refined surfaces.'**
  String get settingsAppearanceVisualStyleDescription;

  /// CodeWalk UI string — settingsAppearanceVisualStyleClassic
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get settingsAppearanceVisualStyleClassic;

  /// CodeWalk UI string — settingsAppearanceVisualStyleRefined
  ///
  /// In en, this message translates to:
  /// **'Refined'**
  String get settingsAppearanceVisualStyleRefined;

  /// CodeWalk UI string — settingsAppearanceThinkingBubbles
  ///
  /// In en, this message translates to:
  /// **'Thinking bubbles'**
  String get settingsAppearanceThinkingBubbles;

  /// CodeWalk UI string — settingsAppearanceThinkingBubblesDescription
  ///
  /// In en, this message translates to:
  /// **'Show or hide reasoning blocks in assistant messages.'**
  String get settingsAppearanceThinkingBubblesDescription;

  /// CodeWalk UI string — settingsAppearanceTitle
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearanceTitle;

  /// CodeWalk UI string — settingsAppearanceToolCallBubbles
  ///
  /// In en, this message translates to:
  /// **'Tool call bubbles'**
  String get settingsAppearanceToolCallBubbles;

  /// CodeWalk UI string — settingsAppearanceToolCallBubblesDescription
  ///
  /// In en, this message translates to:
  /// **'Show or hide tool execution cards in assistant messages.'**
  String get settingsAppearanceToolCallBubblesDescription;

  /// CodeWalk UI string — settingsAppearanceWallpaperColors
  ///
  /// In en, this message translates to:
  /// **'Use wallpaper colors'**
  String get settingsAppearanceWallpaperColors;

  /// CodeWalk UI string — settingsAppearanceWallpaperNormal
  ///
  /// In en, this message translates to:
  /// **'Extract color scheme from your device wallpaper.'**
  String get settingsAppearanceWallpaperNormal;

  /// CodeWalk UI string — settingsAppearanceWallpaperPresetBlocked
  ///
  /// In en, this message translates to:
  /// **'Switch to CodeWalk Classic to use wallpaper colors.'**
  String get settingsAppearanceWallpaperPresetBlocked;

  /// CodeWalk UI string — settingsAppearanceWindowChrome
  ///
  /// In en, this message translates to:
  /// **'Window tabs'**
  String get settingsAppearanceWindowChrome;

  /// CodeWalk UI string — settingsAppearanceWindowChromeDescription
  ///
  /// In en, this message translates to:
  /// **'Choose how session tabs and the window title bar are combined on desktop.'**
  String get settingsAppearanceWindowChromeDescription;

  /// CodeWalk UI string — settingsAppearanceWindowChromeIntegrated
  ///
  /// In en, this message translates to:
  /// **'Integrated tabs'**
  String get settingsAppearanceWindowChromeIntegrated;

  /// CodeWalk UI string — settingsAppearanceWindowChromeIntegratedDescription
  ///
  /// In en, this message translates to:
  /// **'Tabs sit at the top of the window and the system title bar is hidden.'**
  String get settingsAppearanceWindowChromeIntegratedDescription;

  /// CodeWalk UI string — settingsAppearanceWindowChromeSystem
  ///
  /// In en, this message translates to:
  /// **'System decoration'**
  String get settingsAppearanceWindowChromeSystem;

  /// CodeWalk UI string — settingsAppearanceWindowChromeSystemDescription
  ///
  /// In en, this message translates to:
  /// **'Keep the native title bar and show tabs below the app bar.'**
  String get settingsAppearanceWindowChromeSystemDescription;

  /// CodeWalk UI string — settingsBack
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get settingsBack;

  /// CodeWalk UI string — settingsBehaviorAutoupdateCaveat
  ///
  /// In en, this message translates to:
  /// **'Use About for CodeWalk release checks. This setting only mirrors the official OpenCode `autoupdate` config.'**
  String get settingsBehaviorAutoupdateCaveat;

  /// CodeWalk UI string — settingsBehaviorAutoupdateHelp
  ///
  /// In en, this message translates to:
  /// **'Controls upstream OpenCode runtime updates, not CodeWalk app update checks.'**
  String get settingsBehaviorAutoupdateHelp;

  /// CodeWalk UI string — settingsBehaviorCellularDataSaver
  ///
  /// In en, this message translates to:
  /// **'Cellular data saver'**
  String get settingsBehaviorCellularDataSaver;

  /// CodeWalk UI string — settingsBehaviorChatRenderMode
  ///
  /// In en, this message translates to:
  /// **'Chat render mode'**
  String get settingsBehaviorChatRenderMode;

  /// CodeWalk UI string — settingsBehaviorChatRenderModeBlock
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get settingsBehaviorChatRenderModeBlock;

  /// CodeWalk UI string — settingsBehaviorChatRenderModeBlockDescription
  ///
  /// In en, this message translates to:
  /// **'Hide live assistant text, reasoning, and tool cards until the current turn can be shown as one block.'**
  String get settingsBehaviorChatRenderModeBlockDescription;

  /// CodeWalk UI string — settingsBehaviorChatRenderModeDescription
  ///
  /// In en, this message translates to:
  /// **'Choose whether assistant responses appear as they stream or reveal after the current turn settles.'**
  String get settingsBehaviorChatRenderModeDescription;

  /// CodeWalk UI string — settingsBehaviorChatRenderModeLive
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get settingsBehaviorChatRenderModeLive;

  /// CodeWalk UI string — settingsBehaviorChatRenderModeLiveDescription
  ///
  /// In en, this message translates to:
  /// **'Show assistant text, reasoning, and tool activity as OpenCode streams events.'**
  String get settingsBehaviorChatRenderModeLiveDescription;

  /// CodeWalk UI string — settingsBehaviorComposerSpellCheck
  ///
  /// In en, this message translates to:
  /// **'Composer spell check'**
  String get settingsBehaviorComposerSpellCheck;

  /// CodeWalk UI string — settingsBehaviorComposerSpellCheckDescription
  ///
  /// In en, this message translates to:
  /// **'Use native platform spell check, suggestions, and autocorrect in the chat composer.'**
  String get settingsBehaviorComposerSpellCheckDescription;

  /// CodeWalk UI string — settingsBehaviorConfigDeferred
  ///
  /// In en, this message translates to:
  /// **'CodeWalk will apply this OpenCode setting after the current response finishes.'**
  String get settingsBehaviorConfigDeferred;

  /// CodeWalk UI string — settingsBehaviorConfigUpdateFailed
  ///
  /// In en, this message translates to:
  /// **'Could not update the OpenCode {field}.'**
  String settingsBehaviorConfigUpdateFailed(String field);

  /// CodeWalk UI string — settingsBehaviorConversationUsername
  ///
  /// In en, this message translates to:
  /// **'Conversation username'**
  String get settingsBehaviorConversationUsername;

  /// CodeWalk UI string — settingsBehaviorConversationUsernameHelp
  ///
  /// In en, this message translates to:
  /// **'Custom display name shown in conversations instead of the system username.'**
  String get settingsBehaviorConversationUsernameHelp;

  /// CodeWalk UI string — settingsBehaviorDataSaverActive
  ///
  /// In en, this message translates to:
  /// **'Active now on mobile data.'**
  String get settingsBehaviorDataSaverActive;

  /// CodeWalk UI string — settingsBehaviorDataSaverCellularOnly
  ///
  /// In en, this message translates to:
  /// **'Only applies when the connection is cellular/mobile.'**
  String get settingsBehaviorDataSaverCellularOnly;

  /// CodeWalk UI string — settingsBehaviorDataSaverDescription
  ///
  /// In en, this message translates to:
  /// **'Cuts automatic mobile-data usage by stopping background downloads and throttling automatic foreground refreshes.'**
  String get settingsBehaviorDataSaverDescription;

  /// CodeWalk UI string — settingsBehaviorDataSaverWaiting
  ///
  /// In en, this message translates to:
  /// **'Waiting for the next mobile-data sync window.'**
  String get settingsBehaviorDataSaverWaiting;

  /// CodeWalk UI string — settingsBehaviorDefaultAgent
  ///
  /// In en, this message translates to:
  /// **'Default agent'**
  String get settingsBehaviorDefaultAgent;

  /// CodeWalk UI string — settingsBehaviorDefaultAgentHelp
  ///
  /// In en, this message translates to:
  /// **'Primary agent used when no agent is explicitly chosen.'**
  String get settingsBehaviorDefaultAgentHelp;

  /// CodeWalk UI string — settingsBehaviorDefaultModel
  ///
  /// In en, this message translates to:
  /// **'Default model'**
  String get settingsBehaviorDefaultModel;

  /// CodeWalk UI string — settingsBehaviorDefaultModelHelp
  ///
  /// In en, this message translates to:
  /// **'Shared across OpenCode clients through config.'**
  String get settingsBehaviorDefaultModelHelp;

  /// CodeWalk UI string — settingsBehaviorDescription
  ///
  /// In en, this message translates to:
  /// **'Control language, chat behavior, data use, and OpenCode defaults'**
  String get settingsBehaviorDescription;

  /// CodeWalk UI string — settingsBehaviorEnableDataSaver
  ///
  /// In en, this message translates to:
  /// **'Enable cellular data saver'**
  String get settingsBehaviorEnableDataSaver;

  /// CodeWalk UI string — settingsBehaviorMultiDeviceSync
  ///
  /// In en, this message translates to:
  /// **'Enable experimental multi-device sync'**
  String get settingsBehaviorMultiDeviceSync;

  /// CodeWalk UI string — settingsBehaviorMultiDeviceSyncDescription
  ///
  /// In en, this message translates to:
  /// **'Sync composer selection (agent/model/variant) with the active server config.'**
  String get settingsBehaviorMultiDeviceSyncDescription;

  /// CodeWalk UI string — settingsBehaviorMultiDeviceSyncWarning
  ///
  /// In en, this message translates to:
  /// **'Can abort ongoing sessions when working in more than one session at the same time.'**
  String get settingsBehaviorMultiDeviceSyncWarning;

  /// CodeWalk UI string — settingsBehaviorNoAgents
  ///
  /// In en, this message translates to:
  /// **'No agents found'**
  String get settingsBehaviorNoAgents;

  /// CodeWalk UI string — settingsBehaviorNoModels
  ///
  /// In en, this message translates to:
  /// **'No models found'**
  String get settingsBehaviorNoModels;

  /// CodeWalk UI string — settingsBehaviorOpenCodeAutoupdate
  ///
  /// In en, this message translates to:
  /// **'OpenCode auto-update'**
  String get settingsBehaviorOpenCodeAutoupdate;

  /// CodeWalk UI string — settingsBehaviorOpenCodeDefaults
  ///
  /// In en, this message translates to:
  /// **'OpenCode-backed defaults'**
  String get settingsBehaviorOpenCodeDefaults;

  /// CodeWalk UI string — settingsBehaviorOpenCodeDefaultsDescription
  ///
  /// In en, this message translates to:
  /// **'These values write to `/config` on the active server and match official OpenCode shared config.'**
  String get settingsBehaviorOpenCodeDefaultsDescription;

  /// CodeWalk UI string — settingsBehaviorOpenCodeSnapshots
  ///
  /// In en, this message translates to:
  /// **'OpenCode snapshots'**
  String get settingsBehaviorOpenCodeSnapshots;

  /// CodeWalk UI string — settingsBehaviorOpenCodeSnapshotsDescription
  ///
  /// In en, this message translates to:
  /// **'Keep upstream git-backed snapshots enabled for undo/redo and recovery history.'**
  String get settingsBehaviorOpenCodeSnapshotsDescription;

  /// CodeWalk UI string — settingsBehaviorPermissionDeferred
  ///
  /// In en, this message translates to:
  /// **'Advanced permission rule editing stays out of Settings for now and is deferred to later parity work.'**
  String get settingsBehaviorPermissionDeferred;

  /// CodeWalk UI string — settingsBehaviorPermissionProvenance
  ///
  /// In en, this message translates to:
  /// **'Permission handling provenance'**
  String get settingsBehaviorPermissionProvenance;

  /// CodeWalk UI string — settingsBehaviorPermissionProvenanceDescription
  ///
  /// In en, this message translates to:
  /// **'Official OpenCode permission policy is configured in `opencode.json` with allow/ask/deny rules per tool. CodeWalk keeps the official permission-request cards and adds one approved ADR-023 exception: the composer auto-approve toggle replies with `Always` and `remember: true` unconditionally to create durable session-scoped grants, and keeps the same thread-scoped continuity path active in the Android background worker.'**
  String get settingsBehaviorPermissionProvenanceDescription;

  /// CodeWalk UI string — settingsBehaviorRefreshDefaults
  ///
  /// In en, this message translates to:
  /// **'Refresh defaults'**
  String get settingsBehaviorRefreshDefaults;

  /// CodeWalk UI string — settingsBehaviorSaveUsername
  ///
  /// In en, this message translates to:
  /// **'Save username'**
  String get settingsBehaviorSaveUsername;

  /// CodeWalk UI string — settingsBehaviorSearchAutoupdate
  ///
  /// In en, this message translates to:
  /// **'Search auto-update mode'**
  String get settingsBehaviorSearchAutoupdate;

  /// CodeWalk UI string — settingsBehaviorSearchDefaultAgent
  ///
  /// In en, this message translates to:
  /// **'Search default agent'**
  String get settingsBehaviorSearchDefaultAgent;

  /// CodeWalk UI string — settingsBehaviorSearchDefaultModel
  ///
  /// In en, this message translates to:
  /// **'Search default model'**
  String get settingsBehaviorSearchDefaultModel;

  /// CodeWalk UI string — settingsBehaviorSearchShareMode
  ///
  /// In en, this message translates to:
  /// **'Search sharing mode'**
  String get settingsBehaviorSearchShareMode;

  /// CodeWalk UI string — settingsBehaviorSearchSmallModel
  ///
  /// In en, this message translates to:
  /// **'Search small model'**
  String get settingsBehaviorSearchSmallModel;

  /// CodeWalk UI string — settingsBehaviorShareMode
  ///
  /// In en, this message translates to:
  /// **'OpenCode sharing default'**
  String get settingsBehaviorShareMode;

  /// CodeWalk UI string — settingsBehaviorShareModeCaveat
  ///
  /// In en, this message translates to:
  /// **'Use the chat-level share action to publish one session now. This setting only changes OpenCode\'\'s default sharing policy.'**
  String get settingsBehaviorShareModeCaveat;

  /// CodeWalk UI string — settingsBehaviorShareModeHelp
  ///
  /// In en, this message translates to:
  /// **'Controls the official global `share` config, not the share button for an individual chat.'**
  String get settingsBehaviorShareModeHelp;

  /// CodeWalk UI string — settingsBehaviorSmallModel
  ///
  /// In en, this message translates to:
  /// **'Small model'**
  String get settingsBehaviorSmallModel;

  /// CodeWalk UI string — settingsBehaviorSmallModelAutoFallback
  ///
  /// In en, this message translates to:
  /// **'Automatic fallback'**
  String get settingsBehaviorSmallModelAutoFallback;

  /// CodeWalk UI string — settingsBehaviorSmallModelFallbackActive
  ///
  /// In en, this message translates to:
  /// **'OpenCode automatic fallback is active because `small_model` is unset.'**
  String get settingsBehaviorSmallModelFallbackActive;

  /// CodeWalk UI string — settingsBehaviorSmallModelHelp
  ///
  /// In en, this message translates to:
  /// **'Used for lightweight tasks like title generation.'**
  String get settingsBehaviorSmallModelHelp;

  /// CodeWalk UI string — settingsBehaviorSmallModelResetCaveat
  ///
  /// In en, this message translates to:
  /// **'Resetting `small_model` back to automatic fallback still requires editing config outside the app because `/config` patch updates cannot remove keys.'**
  String get settingsBehaviorSmallModelResetCaveat;

  /// CodeWalk UI string — settingsBehaviorSnapshotCaveat
  ///
  /// In en, this message translates to:
  /// **'This controls OpenCode snapshot storage and undo/redo support, not CodeWalk local cache snapshots.'**
  String get settingsBehaviorSnapshotCaveat;

  /// CodeWalk UI string — settingsBehaviorTitle
  ///
  /// In en, this message translates to:
  /// **'Behavior'**
  String get settingsBehaviorTitle;

  /// CodeWalk UI string — settingsBehaviorUsernameFallback
  ///
  /// In en, this message translates to:
  /// **'OpenCode uses the system username because `username` is unset.'**
  String get settingsBehaviorUsernameFallback;

  /// CodeWalk UI string — settingsBehaviorUsernamePatchCaveat
  ///
  /// In en, this message translates to:
  /// **'Resetting `username` back to the system default still requires editing config outside the app because `/config` patch updates cannot remove keys.'**
  String get settingsBehaviorUsernamePatchCaveat;

  /// CodeWalk UI string — settingsConfigRefreshFailed
  ///
  /// In en, this message translates to:
  /// **'Updated the server setting, but could not refresh chat providers.'**
  String get settingsConfigRefreshFailed;

  /// CodeWalk UI string — settingsConfigUpdateDeferred
  ///
  /// In en, this message translates to:
  /// **'CodeWalk will apply this OpenCode setting after the current response finishes.'**
  String get settingsConfigUpdateDeferred;

  /// CodeWalk UI string — settingsConversationUsername
  ///
  /// In en, this message translates to:
  /// **'Conversation username'**
  String get settingsConversationUsername;

  /// CodeWalk UI string — settingsDefaultAgent
  ///
  /// In en, this message translates to:
  /// **'Default agent'**
  String get settingsDefaultAgent;

  /// CodeWalk UI string — settingsDefaultModel
  ///
  /// In en, this message translates to:
  /// **'Default model'**
  String get settingsDefaultModel;

  /// CodeWalk UI string — settingsLanguageDescription
  ///
  /// In en, this message translates to:
  /// **'Choose the language used by CodeWalk. System default follows your device language.'**
  String get settingsLanguageDescription;

  /// CodeWalk UI string — settingsLanguageEmptyText
  ///
  /// In en, this message translates to:
  /// **'No languages found'**
  String get settingsLanguageEmptyText;

  /// CodeWalk UI string — settingsLanguageFieldHelper
  ///
  /// In en, this message translates to:
  /// **'Applies immediately and persists across restarts.'**
  String get settingsLanguageFieldHelper;

  /// CodeWalk UI string — settingsLanguageFieldLabel
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get settingsLanguageFieldLabel;

  /// CodeWalk UI string — settingsLanguageSearchHint
  ///
  /// In en, this message translates to:
  /// **'Search languages'**
  String get settingsLanguageSearchHint;

  /// CodeWalk UI string — settingsLanguageSystemDefault
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystemDefault;

  /// CodeWalk UI string — settingsLanguageTitle
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageTitle;

  /// CodeWalk UI string — settingsLogsDescription
  ///
  /// In en, this message translates to:
  /// **'Review app diagnostics and troubleshooting details'**
  String get settingsLogsDescription;

  /// CodeWalk UI string — settingsLogsTitle
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get settingsLogsTitle;

  /// CodeWalk UI string — settingsNoAgentsFound
  ///
  /// In en, this message translates to:
  /// **'No agents found'**
  String get settingsNoAgentsFound;

  /// CodeWalk UI string — settingsNotificationsAgentSubtitle
  ///
  /// In en, this message translates to:
  /// **'When a response finishes'**
  String get settingsNotificationsAgentSubtitle;

  /// CodeWalk UI string — settingsNotificationsAgentUpdates
  ///
  /// In en, this message translates to:
  /// **'Agent updates'**
  String get settingsNotificationsAgentUpdates;

  /// CodeWalk UI string — settingsNotificationsAnotherConversation
  ///
  /// In en, this message translates to:
  /// **'Another conversation'**
  String get settingsNotificationsAnotherConversation;

  /// CodeWalk UI string — settingsNotificationsAppInBackground
  ///
  /// In en, this message translates to:
  /// **'App in background'**
  String get settingsNotificationsAppInBackground;

  /// CodeWalk UI string — settingsNotificationsBackgroundAlerts
  ///
  /// In en, this message translates to:
  /// **'Android background alerts'**
  String get settingsNotificationsBackgroundAlerts;

  /// CodeWalk UI string — settingsNotificationsBackgroundBehavior
  ///
  /// In en, this message translates to:
  /// **'Background behavior'**
  String get settingsNotificationsBackgroundBehavior;

  /// CodeWalk UI string — settingsNotificationsBackgroundBehaviorDescription
  ///
  /// In en, this message translates to:
  /// **'Choose how CodeWalk behaves after the app leaves the foreground.'**
  String get settingsNotificationsBackgroundBehaviorDescription;

  /// CodeWalk UI string — settingsNotificationsBackgroundDescription
  ///
  /// In en, this message translates to:
  /// **'Use low-data background monitoring for response completions, permission requests, questions, and errors while the app is not on screen.'**
  String get settingsNotificationsBackgroundDescription;

  /// CodeWalk UI string — settingsNotificationsBackgroundToggle
  ///
  /// In en, this message translates to:
  /// **'Background alerts on Android'**
  String get settingsNotificationsBackgroundToggle;

  /// CodeWalk UI string — settingsNotificationsBackgroundToggleDescription
  ///
  /// In en, this message translates to:
  /// **'Turn off all Android background checks and hide the persistent monitor notification.'**
  String get settingsNotificationsBackgroundToggleDescription;

  /// CodeWalk UI string — settingsNotificationsBatteryDescription
  ///
  /// In en, this message translates to:
  /// **'If notifications only arrive when reopening the app, allow CodeWalk to run without optimization on this device.'**
  String get settingsNotificationsBatteryDescription;

  /// CodeWalk UI string — settingsNotificationsBatteryDisabled
  ///
  /// In en, this message translates to:
  /// **'Battery optimization is disabled for CodeWalk.'**
  String get settingsNotificationsBatteryDisabled;

  /// CodeWalk UI string — settingsNotificationsBatteryEnabled
  ///
  /// In en, this message translates to:
  /// **'Battery optimization is enabled. Some devices may delay background alerts.'**
  String get settingsNotificationsBatteryEnabled;

  /// CodeWalk UI string — settingsNotificationsBatteryOptimization
  ///
  /// In en, this message translates to:
  /// **'Android battery optimization'**
  String get settingsNotificationsBatteryOptimization;

  /// CodeWalk UI string — settingsNotificationsBatteryUnknown
  ///
  /// In en, this message translates to:
  /// **'Could not read battery optimization status yet.'**
  String get settingsNotificationsBatteryUnknown;

  /// CodeWalk UI string — settingsNotificationsChooseAudioFile
  ///
  /// In en, this message translates to:
  /// **'Choose audio file'**
  String get settingsNotificationsChooseAudioFile;

  /// CodeWalk UI string — settingsNotificationsChooseSystemSound
  ///
  /// In en, this message translates to:
  /// **'Choose system sound'**
  String get settingsNotificationsChooseSystemSound;

  /// CodeWalk UI string — settingsNotificationsCloseToTray
  ///
  /// In en, this message translates to:
  /// **'Close to tray'**
  String get settingsNotificationsCloseToTray;

  /// CodeWalk UI string — settingsNotificationsCloseToTrayDescription
  ///
  /// In en, this message translates to:
  /// **'Hide window and keep running in system tray.'**
  String get settingsNotificationsCloseToTrayDescription;

  /// CodeWalk UI string — settingsNotificationsDescription
  ///
  /// In en, this message translates to:
  /// **'Choose which events alert you and how'**
  String get settingsNotificationsDescription;

  /// CodeWalk UI string — settingsNotificationsDisableOptimization
  ///
  /// In en, this message translates to:
  /// **'Disable optimization'**
  String get settingsNotificationsDisableOptimization;

  /// CodeWalk UI string — settingsNotificationsErrors
  ///
  /// In en, this message translates to:
  /// **'Errors'**
  String get settingsNotificationsErrors;

  /// CodeWalk UI string — settingsNotificationsErrorsSubtitle
  ///
  /// In en, this message translates to:
  /// **'When a session reports a failure'**
  String get settingsNotificationsErrorsSubtitle;

  /// CodeWalk UI string — settingsNotificationsJustClose
  ///
  /// In en, this message translates to:
  /// **'Just close'**
  String get settingsNotificationsJustClose;

  /// CodeWalk UI string — settingsNotificationsJustCloseDescription
  ///
  /// In en, this message translates to:
  /// **'Exit the application completely.'**
  String get settingsNotificationsJustCloseDescription;

  /// CodeWalk UI string — settingsNotificationsKeepLive
  ///
  /// In en, this message translates to:
  /// **'Keep alerts live for 3 min'**
  String get settingsNotificationsKeepLive;

  /// CodeWalk UI string — settingsNotificationsKeepLiveDescription
  ///
  /// In en, this message translates to:
  /// **'When a response is already running, keep realtime active briefly after leaving the app.'**
  String get settingsNotificationsKeepLiveDescription;

  /// CodeWalk UI string — settingsNotificationsLocal
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get settingsNotificationsLocal;

  /// CodeWalk UI string — settingsNotificationsMinimizeWhenClose
  ///
  /// In en, this message translates to:
  /// **'Minimize when close'**
  String get settingsNotificationsMinimizeWhenClose;

  /// CodeWalk UI string — settingsNotificationsMinimizeWhenCloseDescription
  ///
  /// In en, this message translates to:
  /// **'Minimize to taskbar/dock and keep running.'**
  String get settingsNotificationsMinimizeWhenCloseDescription;

  /// CodeWalk UI string — settingsNotificationsNoCondition
  ///
  /// In en, this message translates to:
  /// **'If no condition is selected, alerts are allowed in any context.'**
  String get settingsNotificationsNoCondition;

  /// CodeWalk UI string — settingsNotificationsNotify
  ///
  /// In en, this message translates to:
  /// **'Notify'**
  String get settingsNotificationsNotify;

  /// CodeWalk UI string — settingsNotificationsNotifyOnlyWhen
  ///
  /// In en, this message translates to:
  /// **'Notify only when'**
  String get settingsNotificationsNotifyOnlyWhen;

  /// CodeWalk UI string — settingsNotificationsOpenBatterySettings
  ///
  /// In en, this message translates to:
  /// **'Open battery settings'**
  String get settingsNotificationsOpenBatterySettings;

  /// CodeWalk UI string — settingsNotificationsPermissions
  ///
  /// In en, this message translates to:
  /// **'Permissions and questions'**
  String get settingsNotificationsPermissions;

  /// CodeWalk UI string — settingsNotificationsPermissionsSubtitle
  ///
  /// In en, this message translates to:
  /// **'When tools request your input'**
  String get settingsNotificationsPermissionsSubtitle;

  /// CodeWalk UI string — settingsNotificationsPreview
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get settingsNotificationsPreview;

  /// CodeWalk UI string — settingsNotificationsRefreshStatus
  ///
  /// In en, this message translates to:
  /// **'Refresh status'**
  String get settingsNotificationsRefreshStatus;

  /// CodeWalk UI string — settingsNotificationsSearchSoundType
  ///
  /// In en, this message translates to:
  /// **'Search sound type'**
  String get settingsNotificationsSearchSoundType;

  /// CodeWalk UI string — settingsNotificationsSectionDescription
  ///
  /// In en, this message translates to:
  /// **'Control when alerts appear and when they can play sound.'**
  String get settingsNotificationsSectionDescription;

  /// CodeWalk UI string — settingsNotificationsSectionTitle
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotificationsSectionTitle;

  /// CodeWalk UI string — settingsNotificationsSelectedSound
  ///
  /// In en, this message translates to:
  /// **'Selected: {label}'**
  String settingsNotificationsSelectedSound(String label);

  /// CodeWalk UI string — settingsNotificationsServer
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get settingsNotificationsServer;

  /// CodeWalk UI string — settingsNotificationsSound
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get settingsNotificationsSound;

  /// CodeWalk UI string — settingsNotificationsSoundBuiltInAlert
  ///
  /// In en, this message translates to:
  /// **'Built-in alert'**
  String get settingsNotificationsSoundBuiltInAlert;

  /// CodeWalk UI string — settingsNotificationsSoundBuiltInClick
  ///
  /// In en, this message translates to:
  /// **'Built-in click'**
  String get settingsNotificationsSoundBuiltInClick;

  /// CodeWalk UI string — settingsNotificationsSoundOff
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsNotificationsSoundOff;

  /// CodeWalk UI string — settingsNotificationsSoundOnlyWhen
  ///
  /// In en, this message translates to:
  /// **'Sound only when'**
  String get settingsNotificationsSoundOnlyWhen;

  /// CodeWalk UI string — settingsNotificationsSoundPickAudioFile
  ///
  /// In en, this message translates to:
  /// **'Pick audio file'**
  String get settingsNotificationsSoundPickAudioFile;

  /// CodeWalk UI string — settingsNotificationsSoundPickFromSystem
  ///
  /// In en, this message translates to:
  /// **'Pick from system'**
  String get settingsNotificationsSoundPickFromSystem;

  /// CodeWalk UI string — settingsNotificationsSoundSystemDefault
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsNotificationsSoundSystemDefault;

  /// CodeWalk UI string — settingsNotificationsSoundType
  ///
  /// In en, this message translates to:
  /// **'Sound type'**
  String get settingsNotificationsSoundType;

  /// CodeWalk UI string — settingsNotificationsSyncInfo
  ///
  /// In en, this message translates to:
  /// **'Some category on/off toggles are synced from /config on the active server.'**
  String get settingsNotificationsSyncInfo;

  /// CodeWalk UI string — settingsNotificationsSyncInfoLocal
  ///
  /// In en, this message translates to:
  /// **'Current server does not expose notification toggles in /config; local values are active.'**
  String get settingsNotificationsSyncInfoLocal;

  /// CodeWalk UI string — settingsNotificationsSystemSoundPickerTitle
  ///
  /// In en, this message translates to:
  /// **'Choose system sound'**
  String get settingsNotificationsSystemSoundPickerTitle;

  /// CodeWalk UI string — settingsNotificationsTitle
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotificationsTitle;

  /// CodeWalk UI string — settingsNotificationsWhenClosing
  ///
  /// In en, this message translates to:
  /// **'When closing the window'**
  String get settingsNotificationsWhenClosing;

  /// CodeWalk UI string — settingsOpenCodeAutoUpdate
  ///
  /// In en, this message translates to:
  /// **'OpenCode auto-update'**
  String get settingsOpenCodeAutoUpdate;

  /// CodeWalk UI string — settingsOpenCodeSharingDefault
  ///
  /// In en, this message translates to:
  /// **'OpenCode sharing default'**
  String get settingsOpenCodeSharingDefault;

  /// CodeWalk UI string — settingsReadAloudEnabled
  ///
  /// In en, this message translates to:
  /// **'Read aloud'**
  String get settingsReadAloudEnabled;

  /// CodeWalk UI string — settingsReadAloudEnabledDescription
  ///
  /// In en, this message translates to:
  /// **'Show a read-aloud button on assistant messages.'**
  String get settingsReadAloudEnabledDescription;

  /// CodeWalk UI string — settingsReadAloudPitch
  ///
  /// In en, this message translates to:
  /// **'Pitch'**
  String get settingsReadAloudPitch;

  /// CodeWalk UI string — settingsReadAloudPitchDescription
  ///
  /// In en, this message translates to:
  /// **'Adjust the voice pitch.'**
  String get settingsReadAloudPitchDescription;

  /// CodeWalk UI string — settingsReadAloudSectionDescription
  ///
  /// In en, this message translates to:
  /// **'Read assistant responses aloud. Configure speed, pitch, and voice.'**
  String get settingsReadAloudSectionDescription;

  /// CodeWalk UI string — settingsReadAloudSectionTitle
  ///
  /// In en, this message translates to:
  /// **'Text to speech'**
  String get settingsReadAloudSectionTitle;

  /// CodeWalk UI string — settingsReadAloudSpeed
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get settingsReadAloudSpeed;

  /// CodeWalk UI string — settingsReadAloudSpeedDescription
  ///
  /// In en, this message translates to:
  /// **'Adjust the speaking rate.'**
  String get settingsReadAloudSpeedDescription;

  /// CodeWalk UI string — settingsReadAloudVoice
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get settingsReadAloudVoice;

  /// CodeWalk UI string — settingsReadAloudVoiceHint
  ///
  /// In en, this message translates to:
  /// **'Select a voice for read-aloud.'**
  String get settingsReadAloudVoiceHint;

  /// CodeWalk UI string — settingsSearchAutoUpdateMode
  ///
  /// In en, this message translates to:
  /// **'Search auto-update mode'**
  String get settingsSearchAutoUpdateMode;

  /// CodeWalk UI string — settingsSearchDefaultAgent
  ///
  /// In en, this message translates to:
  /// **'Search default agent'**
  String get settingsSearchDefaultAgent;

  /// CodeWalk UI string — settingsSearchDefaultModel
  ///
  /// In en, this message translates to:
  /// **'Search default model'**
  String get settingsSearchDefaultModel;

  /// CodeWalk UI string — settingsSearchSharingMode
  ///
  /// In en, this message translates to:
  /// **'Search sharing mode'**
  String get settingsSearchSharingMode;

  /// CodeWalk UI string — settingsSearchSmallModel
  ///
  /// In en, this message translates to:
  /// **'Search small model'**
  String get settingsSearchSmallModel;

  /// CodeWalk UI string — settingsServersActive
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get settingsServersActive;

  /// CodeWalk UI string — settingsServersChooseActive
  ///
  /// In en, this message translates to:
  /// **'Choose active server'**
  String get settingsServersChooseActive;

  /// CodeWalk UI string — settingsServersDefault
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get settingsServersDefault;

  /// CodeWalk UI string — settingsServersDescription
  ///
  /// In en, this message translates to:
  /// **'Connect to OpenCode and manage your servers'**
  String get settingsServersDescription;

  /// CodeWalk UI string — settingsServersTitle
  ///
  /// In en, this message translates to:
  /// **'Servers'**
  String get settingsServersTitle;

  /// CodeWalk UI string — settingsSessionAttentionSize
  ///
  /// In en, this message translates to:
  /// **'Bubble size'**
  String get settingsSessionAttentionSize;

  /// CodeWalk UI string — settingsSessionAttentionSizeExtraLarge
  ///
  /// In en, this message translates to:
  /// **'Extra large'**
  String get settingsSessionAttentionSizeExtraLarge;

  /// CodeWalk UI string — settingsSessionAttentionSizeExtraSmall
  ///
  /// In en, this message translates to:
  /// **'Extra small'**
  String get settingsSessionAttentionSizeExtraSmall;

  /// CodeWalk UI string — settingsSessionAttentionSizeLarge
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get settingsSessionAttentionSizeLarge;

  /// CodeWalk UI string — settingsSessionAttentionSizeSmall
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get settingsSessionAttentionSizeSmall;

  /// CodeWalk UI string — settingsSessionAttentionSizeStandard
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get settingsSessionAttentionSizeStandard;

  /// CodeWalk UI string — settingsSetupWizard
  ///
  /// In en, this message translates to:
  /// **'Setup Wizard'**
  String get settingsSetupWizard;

  /// CodeWalk UI string — settingsShortcutsDescription
  ///
  /// In en, this message translates to:
  /// **'Find and customize keyboard shortcuts'**
  String get settingsShortcutsDescription;

  /// CodeWalk UI string — settingsShortcutsEdit
  ///
  /// In en, this message translates to:
  /// **'Edit shortcut'**
  String get settingsShortcutsEdit;

  /// CodeWalk UI string — settingsShortcutsKeyboard
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get settingsShortcutsKeyboard;

  /// CodeWalk UI string — settingsShortcutsReset
  ///
  /// In en, this message translates to:
  /// **'Reset shortcut'**
  String get settingsShortcutsReset;

  /// CodeWalk UI string — settingsShortcutsSearch
  ///
  /// In en, this message translates to:
  /// **'Search shortcuts'**
  String get settingsShortcutsSearch;

  /// CodeWalk UI string — settingsShortcutsTitle
  ///
  /// In en, this message translates to:
  /// **'Shortcuts'**
  String get settingsShortcutsTitle;

  /// CodeWalk UI string — settingsSmallModel
  ///
  /// In en, this message translates to:
  /// **'Small model'**
  String get settingsSmallModel;

  /// CodeWalk UI string — settingsSmallModelResetExplanation
  ///
  /// In en, this message translates to:
  /// **'Resetting `small_model` back to automatic fallback still requires editing config outside the app because `/config` patch updates cannot remove keys.'**
  String get settingsSmallModelResetExplanation;

  /// CodeWalk UI string — settingsSmallModelUnsetExplanation
  ///
  /// In en, this message translates to:
  /// **'OpenCode automatic fallback is active because `small_model` is unset.'**
  String get settingsSmallModelUnsetExplanation;

  /// CodeWalk UI string — settingsSoundPickerNotAvailable
  ///
  /// In en, this message translates to:
  /// **'System sound picker is not available on this platform.'**
  String get settingsSoundPickerNotAvailable;

  /// CodeWalk UI string — settingsSpeechDescription
  ///
  /// In en, this message translates to:
  /// **'Set up voice input, offline models, and read aloud'**
  String get settingsSpeechDescription;

  /// CodeWalk UI string — settingsSpeechRefreshStatus
  ///
  /// In en, this message translates to:
  /// **'Refresh status'**
  String get settingsSpeechRefreshStatus;

  /// CodeWalk UI string — settingsSpeechSilenceTimeout
  ///
  /// In en, this message translates to:
  /// **'Silence timeout: {value}s'**
  String settingsSpeechSilenceTimeout(String value);

  /// CodeWalk UI string — settingsSpeechTitle
  ///
  /// In en, this message translates to:
  /// **'Speech to text'**
  String get settingsSpeechTitle;

  /// CodeWalk UI string — settingsTitle
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// CodeWalk UI string — settingsGroupAlertTypes
  ///
  /// In en, this message translates to:
  /// **'Alert types'**
  String get settingsGroupAlertTypes;

  /// CodeWalk UI string — settingsGroupBackgroundBehavior
  ///
  /// In en, this message translates to:
  /// **'Background behavior'**
  String get settingsGroupBackgroundBehavior;

  /// CodeWalk UI string — settingsGroupChatDisplay
  ///
  /// In en, this message translates to:
  /// **'Chat display'**
  String get settingsGroupChatDisplay;

  /// CodeWalk UI string — settingsGroupCurrentConnection
  ///
  /// In en, this message translates to:
  /// **'Current connection'**
  String get settingsGroupCurrentConnection;

  /// CodeWalk UI string — settingsGroupDataAndSync
  ///
  /// In en, this message translates to:
  /// **'Data and sync'**
  String get settingsGroupDataAndSync;

  /// CodeWalk UI string — settingsGroupDataReset
  ///
  /// In en, this message translates to:
  /// **'Data and reset'**
  String get settingsGroupDataReset;

  /// CodeWalk UI string — settingsGroupDelivery
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get settingsGroupDelivery;

  /// CodeWalk UI string — settingsGroupHelp
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get settingsGroupHelp;

  /// CodeWalk UI string — settingsGroupLanguageAndChat
  ///
  /// In en, this message translates to:
  /// **'Language and chat'**
  String get settingsGroupLanguageAndChat;

  /// CodeWalk UI string — settingsGroupLayoutAndText
  ///
  /// In en, this message translates to:
  /// **'Layout and text'**
  String get settingsGroupLayoutAndText;

  /// CodeWalk UI string — settingsGroupOfflineModels
  ///
  /// In en, this message translates to:
  /// **'Offline models'**
  String get settingsGroupOfflineModels;

  /// CodeWalk UI string — settingsGroupOpenCodeDefaults
  ///
  /// In en, this message translates to:
  /// **'OpenCode defaults'**
  String get settingsGroupOpenCodeDefaults;

  /// CodeWalk UI string — settingsGroupReadAloud
  ///
  /// In en, this message translates to:
  /// **'Read aloud'**
  String get settingsGroupReadAloud;

  /// CodeWalk UI string — settingsGroupSavedServers
  ///
  /// In en, this message translates to:
  /// **'Saved servers'**
  String get settingsGroupSavedServers;

  /// CodeWalk UI string — settingsGroupThemeAndColor
  ///
  /// In en, this message translates to:
  /// **'Theme and color'**
  String get settingsGroupThemeAndColor;

  /// CodeWalk UI string — settingsGroupThisDevice
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get settingsGroupThisDevice;

  /// CodeWalk UI string — settingsGroupVersionUpdates
  ///
  /// In en, this message translates to:
  /// **'Version and updates'**
  String get settingsGroupVersionUpdates;

  /// CodeWalk UI string — settingsGroupVoiceInput
  ///
  /// In en, this message translates to:
  /// **'Voice input'**
  String get settingsGroupVoiceInput;

  /// CodeWalk UI string — settingsNavigationGroupExperience
  ///
  /// In en, this message translates to:
  /// **'Experience'**
  String get settingsNavigationGroupExperience;

  /// CodeWalk UI string — settingsNavigationGroupInput
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get settingsNavigationGroupInput;

  /// CodeWalk UI string — settingsNavigationGroupSetup
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get settingsNavigationGroupSetup;

  /// CodeWalk UI string — settingsNavigationGroupSupport
  ///
  /// In en, this message translates to:
  /// **'Help and diagnostics'**
  String get settingsNavigationGroupSupport;

  /// CodeWalk UI string — settingsNavigationNoResults
  ///
  /// In en, this message translates to:
  /// **'No settings found'**
  String get settingsNavigationNoResults;

  /// CodeWalk UI string — settingsNavigationSearchHint
  ///
  /// In en, this message translates to:
  /// **'Search settings'**
  String get settingsNavigationSearchHint;

  /// CodeWalk UI string — settingsUsernameClearHint
  ///
  /// In en, this message translates to:
  /// **'Clearing the OpenCode conversation username still requires editing config outside the app.'**
  String get settingsUsernameClearHint;

  /// CodeWalk UI string — settingsUsernameEnterHint
  ///
  /// In en, this message translates to:
  /// **'Enter a username to save a custom OpenCode conversation name.'**
  String get settingsUsernameEnterHint;

  /// CodeWalk UI string — settingsUsernameResetExplanation
  ///
  /// In en, this message translates to:
  /// **'Resetting `username` back to the system default still requires editing config outside the app because `/config` patch updates cannot remove keys.'**
  String get settingsUsernameResetExplanation;

  /// CodeWalk UI string — settingsUsernameUnsetExplanation
  ///
  /// In en, this message translates to:
  /// **'OpenCode uses the system username because `username` is unset.'**
  String get settingsUsernameUnsetExplanation;

  /// CodeWalk UI string — setupDebugBun
  ///
  /// In en, this message translates to:
  /// **'Bun'**
  String get setupDebugBun;

  /// CodeWalk UI string — setupDebugBun2
  ///
  /// In en, this message translates to:
  /// **'Bun'**
  String get setupDebugBun2;

  /// CodeWalk UI string — setupDebugCapturedSetupDetails
  ///
  /// In en, this message translates to:
  /// **'No captured setup details yet'**
  String get setupDebugCapturedSetupDetails;

  /// CodeWalk UI string — setupDebugCapturedSetupLogs
  ///
  /// In en, this message translates to:
  /// **'Captured setup logs'**
  String get setupDebugCapturedSetupLogs;

  /// CodeWalk UI string — setupDebugClear
  ///
  /// In en, this message translates to:
  /// **'Clear setup debug'**
  String get setupDebugClear;

  /// CodeWalk UI string — setupDebugClearSetupDebug
  ///
  /// In en, this message translates to:
  /// **'Clear setup debug'**
  String get setupDebugClearSetupDebug;

  /// CodeWalk UI string — setupDebugCodeWalkCaptureEnough
  ///
  /// In en, this message translates to:
  /// **'If CodeWalk did not capture enough context, check the official OpenCode logs and health endpoints directly:'**
  String get setupDebugCodeWalkCaptureEnough;

  /// CodeWalk UI string — setupDebugCommandPath
  ///
  /// In en, this message translates to:
  /// **'Command path'**
  String get setupDebugCommandPath;

  /// CodeWalk UI string — setupDebugCommandPath2
  ///
  /// In en, this message translates to:
  /// **'Command path'**
  String get setupDebugCommandPath2;

  /// CodeWalk UI string — setupDebugCopy
  ///
  /// In en, this message translates to:
  /// **'Copy setup debug'**
  String get setupDebugCopy;

  /// CodeWalk UI string — setupDebugCopySetupDebug
  ///
  /// In en, this message translates to:
  /// **'Copy setup debug'**
  String get setupDebugCopySetupDebug;

  /// CodeWalk UI string — setupDebugCurrentStatus
  ///
  /// In en, this message translates to:
  /// **'Current status'**
  String get setupDebugCurrentStatus;

  /// CodeWalk UI string — setupDebugDiagnosticsLoading
  ///
  /// In en, this message translates to:
  /// **'Diagnostics are still loading.'**
  String get setupDebugDiagnosticsLoading;

  /// CodeWalk UI string — setupDebugEnvironment
  ///
  /// In en, this message translates to:
  /// **'Environment diagnostics'**
  String get setupDebugEnvironment;

  /// CodeWalk UI string — setupDebugEnvironmentDiagnostics
  ///
  /// In en, this message translates to:
  /// **'Environment diagnostics'**
  String get setupDebugEnvironmentDiagnostics;

  /// CodeWalk UI string — setupDebugFocusedOpenCodeSetup
  ///
  /// In en, this message translates to:
  /// **'Focused on OpenCode setup'**
  String get setupDebugFocusedOpenCodeSetup;

  /// CodeWalk UI string — setupDebugInstallDir
  ///
  /// In en, this message translates to:
  /// **'Install directory'**
  String get setupDebugInstallDir;

  /// CodeWalk UI string — setupDebugInstallDirectory
  ///
  /// In en, this message translates to:
  /// **'Install directory'**
  String get setupDebugInstallDirectory;

  /// CodeWalk UI string — setupDebugLatestLocalServer
  ///
  /// In en, this message translates to:
  /// **'Latest local server output'**
  String get setupDebugLatestLocalServer;

  /// CodeWalk UI string — setupDebugLogs
  ///
  /// In en, this message translates to:
  /// **'Captured setup logs'**
  String get setupDebugLogs;

  /// CodeWalk UI string — setupDebugManual
  ///
  /// In en, this message translates to:
  /// **'Manual troubleshooting'**
  String get setupDebugManual;

  /// CodeWalk UI string — setupDebugManualTroubleshooting
  ///
  /// In en, this message translates to:
  /// **'Manual troubleshooting'**
  String get setupDebugManualTroubleshooting;

  /// CodeWalk UI string — setupDebugNetwork
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get setupDebugNetwork;

  /// CodeWalk UI string — setupDebugNetwork2
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get setupDebugNetwork2;

  /// CodeWalk UI string — setupDebugNoDetails
  ///
  /// In en, this message translates to:
  /// **'No captured setup details yet'**
  String get setupDebugNoDetails;

  /// CodeWalk UI string — setupDebugNode
  ///
  /// In en, this message translates to:
  /// **'Node.js'**
  String get setupDebugNode;

  /// CodeWalk UI string — setupDebugNodeJs
  ///
  /// In en, this message translates to:
  /// **'Node.js'**
  String get setupDebugNodeJs;

  /// CodeWalk UI string — setupDebugNpm
  ///
  /// In en, this message translates to:
  /// **'npm'**
  String get setupDebugNpm;

  /// CodeWalk UI string — setupDebugNpm2
  ///
  /// In en, this message translates to:
  /// **'npm'**
  String get setupDebugNpm2;

  /// CodeWalk UI string — setupDebugOpenCode
  ///
  /// In en, this message translates to:
  /// **'OpenCode'**
  String get setupDebugOpenCode;

  /// CodeWalk UI string — setupDebugOpenCode2
  ///
  /// In en, this message translates to:
  /// **'OpenCode'**
  String get setupDebugOpenCode2;

  /// CodeWalk UI string — setupDebugOpenCodeSetupDebug
  ///
  /// In en, this message translates to:
  /// **'OpenCode Setup Debug'**
  String get setupDebugOpenCodeSetupDebug;

  /// CodeWalk UI string — setupDebugPlatform
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get setupDebugPlatform;

  /// CodeWalk UI string — setupDebugPlatform2
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get setupDebugPlatform2;

  /// CodeWalk UI string — setupDebugRunDiagnosticsTry
  ///
  /// In en, this message translates to:
  /// **'Run diagnostics, try an installation method, or attempt a setup flow to capture OpenCode-specific troubleshooting details here.'**
  String get setupDebugRunDiagnosticsTry;

  /// CodeWalk UI string — setupDebugScreenCoversOpenCode
  ///
  /// In en, this message translates to:
  /// **'This screen only covers OpenCode installation, diagnostics, and local setup troubleshooting. Use App Logs for general CodeWalk runtime issues.'**
  String get setupDebugScreenCoversOpenCode;

  /// CodeWalk UI string — setupDebugServerOutput
  ///
  /// In en, this message translates to:
  /// **'Latest local server output'**
  String get setupDebugServerOutput;

  /// CodeWalk UI string — setupDebugStatus
  ///
  /// In en, this message translates to:
  /// **'Current status'**
  String get setupDebugStatus;

  /// CodeWalk UI string — setupDebugTimeEntrySource
  ///
  /// In en, this message translates to:
  /// **'{time} - {source}'**
  String setupDebugTimeEntrySource(String source, String time);

  /// CodeWalk UI string — setupDebugTimeline
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get setupDebugTimeline;

  /// CodeWalk UI string — setupDebugTimeline2
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get setupDebugTimeline2;

  /// CodeWalk UI string — setupDebugTitle
  ///
  /// In en, this message translates to:
  /// **'Focused on OpenCode setup'**
  String get setupDebugTitle;

  /// CodeWalk UI string — setupDebugWSL
  ///
  /// In en, this message translates to:
  /// **'WSL'**
  String get setupDebugWSL;

  /// CodeWalk UI string — setupDebugWsl
  ///
  /// In en, this message translates to:
  /// **'WSL'**
  String get setupDebugWsl;

  /// CodeWalk UI string — shortcutCloseApp
  ///
  /// In en, this message translates to:
  /// **'Close tab/application'**
  String get shortcutCloseApp;

  /// CodeWalk UI string — shortcutCloseAppDesc
  ///
  /// In en, this message translates to:
  /// **'Close the current session tab when available, otherwise close the app using platform behavior'**
  String get shortcutCloseAppDesc;

  /// CodeWalk UI string — shortcutFocusCloseDrawer
  ///
  /// In en, this message translates to:
  /// **'Focus/close drawer'**
  String get shortcutFocusCloseDrawer;

  /// CodeWalk UI string — shortcutFocusCloseDrawerDesc
  ///
  /// In en, this message translates to:
  /// **'Focus composer by default, or close drawer when open'**
  String get shortcutFocusCloseDrawerDesc;

  /// CodeWalk UI string — shortcutFocusInput
  ///
  /// In en, this message translates to:
  /// **'Focus input'**
  String get shortcutFocusInput;

  /// CodeWalk UI string — shortcutFocusInputDesc
  ///
  /// In en, this message translates to:
  /// **'Move focus to the prompt input'**
  String get shortcutFocusInputDesc;

  /// CodeWalk UI string — shortcutGroupApplication
  ///
  /// In en, this message translates to:
  /// **'Application'**
  String get shortcutGroupApplication;

  /// CodeWalk UI string — shortcutGroupGeneral
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get shortcutGroupGeneral;

  /// CodeWalk UI string — shortcutGroupModelAndAgent
  ///
  /// In en, this message translates to:
  /// **'Model and agent'**
  String get shortcutGroupModelAndAgent;

  /// CodeWalk UI string — shortcutGroupNavigation
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get shortcutGroupNavigation;

  /// CodeWalk UI string — shortcutGroupPrompt
  ///
  /// In en, this message translates to:
  /// **'Prompt'**
  String get shortcutGroupPrompt;

  /// CodeWalk UI string — shortcutGroupSession
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get shortcutGroupSession;

  /// CodeWalk UI string — shortcutNewConversation
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get shortcutNewConversation;

  /// CodeWalk UI string — shortcutNewConversationDesc
  ///
  /// In en, this message translates to:
  /// **'Create a new chat session'**
  String get shortcutNewConversationDesc;

  /// CodeWalk UI string — shortcutNextAgent
  ///
  /// In en, this message translates to:
  /// **'Next agent'**
  String get shortcutNextAgent;

  /// CodeWalk UI string — shortcutNextAgentDesc
  ///
  /// In en, this message translates to:
  /// **'Cycle to next available agent'**
  String get shortcutNextAgentDesc;

  /// CodeWalk UI string — shortcutNextRecentModel
  ///
  /// In en, this message translates to:
  /// **'Next recent model'**
  String get shortcutNextRecentModel;

  /// CodeWalk UI string — shortcutNextRecentModelDesc
  ///
  /// In en, this message translates to:
  /// **'Cycle through recently used models'**
  String get shortcutNextRecentModelDesc;

  /// CodeWalk UI string — shortcutNextVariant
  ///
  /// In en, this message translates to:
  /// **'Next variant'**
  String get shortcutNextVariant;

  /// CodeWalk UI string — shortcutNextVariantDesc
  ///
  /// In en, this message translates to:
  /// **'Cycle through available model variants'**
  String get shortcutNextVariantDesc;

  /// CodeWalk UI string — shortcutOpenSettings
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get shortcutOpenSettings;

  /// CodeWalk UI string — shortcutOpenSettingsDesc
  ///
  /// In en, this message translates to:
  /// **'Open settings page'**
  String get shortcutOpenSettingsDesc;

  /// CodeWalk UI string — shortcutPreviousAgent
  ///
  /// In en, this message translates to:
  /// **'Previous agent'**
  String get shortcutPreviousAgent;

  /// CodeWalk UI string — shortcutPreviousAgentDesc
  ///
  /// In en, this message translates to:
  /// **'Cycle to previous available agent'**
  String get shortcutPreviousAgentDesc;

  /// CodeWalk UI string — shortcutQuickOpenFiles
  ///
  /// In en, this message translates to:
  /// **'Quick open files'**
  String get shortcutQuickOpenFiles;

  /// CodeWalk UI string — shortcutQuickOpenFilesDesc
  ///
  /// In en, this message translates to:
  /// **'Open file quick search'**
  String get shortcutQuickOpenFilesDesc;

  /// CodeWalk UI string — shortcutQuitApp
  ///
  /// In en, this message translates to:
  /// **'Quit application'**
  String get shortcutQuitApp;

  /// CodeWalk UI string — shortcutQuitAppDesc
  ///
  /// In en, this message translates to:
  /// **'Force-exit the app'**
  String get shortcutQuitAppDesc;

  /// CodeWalk UI string — shortcutRefreshData
  ///
  /// In en, this message translates to:
  /// **'Refresh data'**
  String get shortcutRefreshData;

  /// CodeWalk UI string — shortcutRefreshDataDesc
  ///
  /// In en, this message translates to:
  /// **'Refresh current chat data'**
  String get shortcutRefreshDataDesc;

  /// CodeWalk UI string — shortcutStopResponse
  ///
  /// In en, this message translates to:
  /// **'Stop active response'**
  String get shortcutStopResponse;

  /// CodeWalk UI string — shortcutStopResponseDesc
  ///
  /// In en, this message translates to:
  /// **'Stop active response (while responding)'**
  String get shortcutStopResponseDesc;

  /// CodeWalk UI string — shortcutToggleVoiceInput
  ///
  /// In en, this message translates to:
  /// **'Toggle voice input'**
  String get shortcutToggleVoiceInput;

  /// CodeWalk UI string — shortcutToggleVoiceInputDesc
  ///
  /// In en, this message translates to:
  /// **'Start or stop speech-to-text in the composer'**
  String get shortcutToggleVoiceInputDesc;

  /// CodeWalk UI string — shortcutsApply
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get shortcutsApply;

  /// CodeWalk UI string — shortcutsConflictConflict
  ///
  /// In en, this message translates to:
  /// **'Conflict with {conflict}'**
  String shortcutsConflictConflict(String conflict);

  /// CodeWalk UI string — shortcutsKeyboardShortcuts
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get shortcutsKeyboardShortcuts;

  /// CodeWalk UI string — shortcutsReset
  ///
  /// In en, this message translates to:
  /// **'Reset all'**
  String get shortcutsReset;

  /// CodeWalk UI string — shortcutsSearchEditBindings
  ///
  /// In en, this message translates to:
  /// **'Search, edit bindings, and resolve conflicts before saving.'**
  String get shortcutsSearchEditBindings;

  /// CodeWalk UI string — shortcutsSetShortcutWidget
  ///
  /// In en, this message translates to:
  /// **'Set shortcut: {label}'**
  String shortcutsSetShortcutWidget(String label);

  /// CodeWalk UI string — shortcutsTheseBindingsStored
  ///
  /// In en, this message translates to:
  /// **'These bindings are stored in CodeWalk for the current app runtime and do not edit OpenCode `tui.json` keybinds.'**
  String get shortcutsTheseBindingsStored;

  /// CodeWalk UI string — speechAutoStopSilence
  ///
  /// In en, this message translates to:
  /// **'Auto-stop silence timeout'**
  String get speechAutoStopSilence;

  /// CodeWalk UI string — speechChooseRecognitionEngine
  ///
  /// In en, this message translates to:
  /// **'Choose the recognition engine, silence timeout, and model options.'**
  String get speechChooseRecognitionEngine;

  /// CodeWalk UI string — speechDesktopOnly
  ///
  /// In en, this message translates to:
  /// **'{service} is available on desktop only.'**
  String speechDesktopOnly(String service);

  /// CodeWalk UI string — speechDownload
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get speechDownload;

  /// CodeWalk UI string — speechEngine
  ///
  /// In en, this message translates to:
  /// **'Engine'**
  String get speechEngine;

  /// CodeWalk UI string — speechInstalledLanguages
  ///
  /// In en, this message translates to:
  /// **'Installed languages'**
  String get speechInstalledLanguages;

  /// CodeWalk UI string — speechListeningStopsAutomatically
  ///
  /// In en, this message translates to:
  /// **'Listening stops automatically after this many seconds of silence.'**
  String get speechListeningStopsAutomatically;

  /// CodeWalk UI string — speechMicPermissionDisabled
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is disabled.'**
  String get speechMicPermissionDisabled;

  /// CodeWalk UI string — speechModelFilesIncomplete
  ///
  /// In en, this message translates to:
  /// **'{service} model files are incomplete.'**
  String speechModelFilesIncomplete(String service);

  /// CodeWalk UI string — speechMoonshine
  ///
  /// In en, this message translates to:
  /// **'Moonshine'**
  String get speechMoonshine;

  /// CodeWalk UI string — speechMoonshineModelsDesktop
  ///
  /// In en, this message translates to:
  /// **'Moonshine models (desktop)'**
  String get speechMoonshineModelsDesktop;

  /// CodeWalk UI string — speechMoonshineStaysDownloadable
  ///
  /// In en, this message translates to:
  /// **'Moonshine stays downloadable and out of the app bundle. Pick one model for this desktop device and remove it later if you want the space back.'**
  String get speechMoonshineStaysDownloadable;

  /// CodeWalk UI string — speechNative
  ///
  /// In en, this message translates to:
  /// **'Native'**
  String get speechNative;

  /// CodeWalk UI string — speechNativeSTTDisabled
  ///
  /// In en, this message translates to:
  /// **'Native STT is disabled on Linux in this app. Parakeet is the default engine for new installs.'**
  String get speechNativeSTTDisabled;

  /// CodeWalk UI string — speechNativeSTTWorks
  ///
  /// In en, this message translates to:
  /// **'On Windows, CodeWalk uses local on-device speech recognition through its WASAPI microphone backend. Native Windows speech recognition is disabled for stability.'**
  String get speechNativeSTTWorks;

  /// CodeWalk UI string — speechNativeStartsFaster
  ///
  /// In en, this message translates to:
  /// **'Native starts faster. Sherpa runs fully on-device with heavier setup and deeper model control.'**
  String get speechNativeStartsFaster;

  /// CodeWalk UI string — speechOpenMicrophoneSettings
  ///
  /// In en, this message translates to:
  /// **'Open microphone settings'**
  String get speechOpenMicrophoneSettings;

  /// CodeWalk UI string — speechOpenSpeechPrivacy
  ///
  /// In en, this message translates to:
  /// **'Open speech privacy'**
  String get speechOpenSpeechPrivacy;

  /// CodeWalk UI string — speechOpenSpeechSettings
  ///
  /// In en, this message translates to:
  /// **'Open speech settings'**
  String get speechOpenSpeechSettings;

  /// CodeWalk UI string — speechParakeet
  ///
  /// In en, this message translates to:
  /// **'Parakeet'**
  String get speechParakeet;

  /// CodeWalk UI string — speechParakeetModelsDesktop
  ///
  /// In en, this message translates to:
  /// **'Parakeet models (desktop)'**
  String get speechParakeetModelsDesktop;

  /// CodeWalk UI string — speechParakeetStaysDownloadable
  ///
  /// In en, this message translates to:
  /// **'Parakeet stays downloadable and out of the app bundle. It currently exposes one multilingual model optimized for 25 European languages.'**
  String get speechParakeetStaysDownloadable;

  /// CodeWalk UI string — speechPickLanguagePacks
  ///
  /// In en, this message translates to:
  /// **'Pick language packs and download/remove models for on-device recognition.'**
  String get speechPickLanguagePacks;

  /// CodeWalk UI string — speechRemove
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get speechRemove;

  /// CodeWalk UI string — speechRuntimeFailed
  ///
  /// In en, this message translates to:
  /// **'{service} runtime failed to initialize.'**
  String speechRuntimeFailed(String service);

  /// CodeWalk UI string — speechSelectSherpaAbove
  ///
  /// In en, this message translates to:
  /// **'Select Sherpa above to manage language packs and download models.'**
  String get speechSelectSherpaAbove;

  /// CodeWalk UI string — speechSenseVoice
  ///
  /// In en, this message translates to:
  /// **'SenseVoice'**
  String get speechSenseVoice;

  /// CodeWalk UI string — speechSenseVoiceModelsDesktop
  ///
  /// In en, this message translates to:
  /// **'SenseVoice models (desktop)'**
  String get speechSenseVoiceModelsDesktop;

  /// CodeWalk UI string — speechSenseVoiceStaysDownloadable
  ///
  /// In en, this message translates to:
  /// **'SenseVoice stays downloadable and out of the app bundle. It is the strongest desktop option here for Chinese, Cantonese, Japanese, Korean, and English.'**
  String get speechSenseVoiceStaysDownloadable;

  /// CodeWalk UI string — speechSherpa
  ///
  /// In en, this message translates to:
  /// **'Sherpa'**
  String get speechSherpa;

  /// CodeWalk UI string — speechSherpaExperimentalFail
  ///
  /// In en, this message translates to:
  /// **'Sherpa is experimental and can fail on some devices. Prefer Native if you want the most stable behavior.'**
  String get speechSherpaExperimentalFail;

  /// CodeWalk UI string — speechSherpaModelsLinux
  ///
  /// In en, this message translates to:
  /// **'Sherpa models (Linux)'**
  String get speechSherpaModelsLinux;

  /// CodeWalk UI string — speechSpeechText
  ///
  /// In en, this message translates to:
  /// **'Speech to text'**
  String get speechSpeechText;

  /// CodeWalk UI string — speechUnavailableOnPlatform
  ///
  /// In en, this message translates to:
  /// **'{service} speech is unavailable on this platform.'**
  String speechUnavailableOnPlatform(String service);

  /// CodeWalk UI string — speechWindowsSetupHint
  ///
  /// In en, this message translates to:
  /// **'Windows voice input uses CodeWalk WASAPI capture with on-device models. Keep microphone access for desktop apps enabled; the buttons below open Windows settings for troubleshooting.'**
  String get speechWindowsSetupHint;

  /// CodeWalk UI string — statusConnected
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get statusConnected;

  /// CodeWalk UI string — statusDelayed
  ///
  /// In en, this message translates to:
  /// **'Delayed'**
  String get statusDelayed;

  /// CodeWalk UI string — statusFailed
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// CodeWalk UI string — statusOffline
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get statusOffline;

  /// CodeWalk UI string — statusOnline
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get statusOnline;

  /// CodeWalk UI string — statusReconnecting
  ///
  /// In en, this message translates to:
  /// **'Reconnecting'**
  String get statusReconnecting;

  /// CodeWalk UI string — statusStarting
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get statusStarting;

  /// CodeWalk UI string — statusStopped
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get statusStopped;

  /// CodeWalk UI string — statusStopping
  ///
  /// In en, this message translates to:
  /// **'Stopping'**
  String get statusStopping;

  /// CodeWalk UI string — statusSyncDelayed
  ///
  /// In en, this message translates to:
  /// **'Sync delayed'**
  String get statusSyncDelayed;

  /// CodeWalk UI string — tailscaleNoPeers
  ///
  /// In en, this message translates to:
  /// **'No peers found'**
  String get tailscaleNoPeers;

  /// CodeWalk UI string — tailscaleNotSupportedOnPlatform
  ///
  /// In en, this message translates to:
  /// **'Tailscale is not supported on this platform.'**
  String get tailscaleNotSupportedOnPlatform;

  /// CodeWalk UI string — tailscaleNotSupportedOnWindows
  ///
  /// In en, this message translates to:
  /// **'Tailscale is not supported on Windows.'**
  String get tailscaleNotSupportedOnWindows;

  /// CodeWalk UI string — tailscalePeerOffline
  ///
  /// In en, this message translates to:
  /// **'offline'**
  String get tailscalePeerOffline;

  /// CodeWalk UI string — tailscaleSelectPeer
  ///
  /// In en, this message translates to:
  /// **'Select a Tailscale peer'**
  String get tailscaleSelectPeer;

  /// CodeWalk UI string — tailscaleWaitingAdminApproval
  ///
  /// In en, this message translates to:
  /// **'This Tailscale node is waiting for admin approval.'**
  String get tailscaleWaitingAdminApproval;

  /// CodeWalk UI string — terminalClose
  ///
  /// In en, this message translates to:
  /// **'Close terminal'**
  String get terminalClose;

  /// CodeWalk UI string — terminalConnectingTo
  ///
  /// In en, this message translates to:
  /// **'Connecting to {serverName} terminal...'**
  String terminalConnectingTo(String serverName);

  /// CodeWalk UI string — terminalConnectionFailed
  ///
  /// In en, this message translates to:
  /// **'Terminal connection failed: {error}'**
  String terminalConnectionFailed(String error);

  /// CodeWalk UI string — terminalDisconnected
  ///
  /// In en, this message translates to:
  /// **'Terminal disconnected.'**
  String get terminalDisconnected;

  /// CodeWalk UI string — terminalEmbeddedUnavailable
  ///
  /// In en, this message translates to:
  /// **'Embedded terminal is not available on this runtime yet. Keep using composer shell mode for one-shot commands or open the terminal from a supported CodeWalk app runtime for {serverName}.'**
  String terminalEmbeddedUnavailable(String serverName);

  /// CodeWalk UI string — terminalExtraKeyAlt
  ///
  /// In en, this message translates to:
  /// **'Alt key'**
  String get terminalExtraKeyAlt;

  /// CodeWalk UI string — terminalExtraKeyArrowDown
  ///
  /// In en, this message translates to:
  /// **'Down arrow'**
  String get terminalExtraKeyArrowDown;

  /// CodeWalk UI string — terminalExtraKeyArrowLeft
  ///
  /// In en, this message translates to:
  /// **'Left arrow'**
  String get terminalExtraKeyArrowLeft;

  /// CodeWalk UI string — terminalExtraKeyArrowRight
  ///
  /// In en, this message translates to:
  /// **'Right arrow'**
  String get terminalExtraKeyArrowRight;

  /// CodeWalk UI string — terminalExtraKeyArrowUp
  ///
  /// In en, this message translates to:
  /// **'Up arrow'**
  String get terminalExtraKeyArrowUp;

  /// CodeWalk UI string — terminalExtraKeyControl
  ///
  /// In en, this message translates to:
  /// **'Control key'**
  String get terminalExtraKeyControl;

  /// CodeWalk UI string — terminalExtraKeyEscape
  ///
  /// In en, this message translates to:
  /// **'Escape key'**
  String get terminalExtraKeyEscape;

  /// CodeWalk UI string — terminalExtraKeyTab
  ///
  /// In en, this message translates to:
  /// **'Tab key'**
  String get terminalExtraKeyTab;

  /// CodeWalk UI string — terminalExtraKeys
  ///
  /// In en, this message translates to:
  /// **'Terminal extra keys'**
  String get terminalExtraKeys;

  /// CodeWalk UI string — terminalHide
  ///
  /// In en, this message translates to:
  /// **'Hide terminal'**
  String get terminalHide;

  /// CodeWalk UI string — terminalMaximize
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get terminalMaximize;

  /// CodeWalk UI string — terminalMinimize
  ///
  /// In en, this message translates to:
  /// **'Minimize terminal'**
  String get terminalMinimize;

  /// CodeWalk UI string — terminalNotAvailableYet
  ///
  /// In en, this message translates to:
  /// **'Embedded terminal is not available on this runtime yet.'**
  String get terminalNotAvailableYet;

  /// CodeWalk UI string — terminalOpen
  ///
  /// In en, this message translates to:
  /// **'Open terminal'**
  String get terminalOpen;

  /// CodeWalk UI string — terminalOpenInfo
  ///
  /// In en, this message translates to:
  /// **'Open terminal info'**
  String get terminalOpenInfo;

  /// CodeWalk UI string — terminalOpenProjectFirst
  ///
  /// In en, this message translates to:
  /// **'Open a project folder before starting the server terminal.'**
  String get terminalOpenProjectFirst;

  /// CodeWalk UI string — terminalOpenToConnect
  ///
  /// In en, this message translates to:
  /// **'Open Terminal to connect to the server project terminal.'**
  String get terminalOpenToConnect;

  /// CodeWalk UI string — terminalReconnect
  ///
  /// In en, this message translates to:
  /// **'Reconnect terminal'**
  String get terminalReconnect;

  /// CodeWalk UI string — terminalRestoreSize
  ///
  /// In en, this message translates to:
  /// **'Restore size'**
  String get terminalRestoreSize;

  /// CodeWalk UI string — terminalSelectServer
  ///
  /// In en, this message translates to:
  /// **'Select an active server before opening Terminal.'**
  String get terminalSelectServer;

  /// CodeWalk UI string — terminalSessionClosed
  ///
  /// In en, this message translates to:
  /// **'Terminal session closed.'**
  String get terminalSessionClosed;

  /// CodeWalk UI string — terminalTerminal
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get terminalTerminal;

  /// CodeWalk UI string — terminalTitle
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get terminalTitle;

  /// CodeWalk UI string — terminalTryAgain
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get terminalTryAgain;

  /// CodeWalk UI string — toolAwaitingInput
  ///
  /// In en, this message translates to:
  /// **'Awaiting input'**
  String get toolAwaitingInput;

  /// CodeWalk UI string — toolEditing
  ///
  /// In en, this message translates to:
  /// **'Editing'**
  String get toolEditing;

  /// CodeWalk UI string — toolEditingFiles
  ///
  /// In en, this message translates to:
  /// **'Editing files'**
  String get toolEditingFiles;

  /// CodeWalk UI string — toolFinding
  ///
  /// In en, this message translates to:
  /// **'Finding'**
  String get toolFinding;

  /// CodeWalk UI string — toolFindingFiles
  ///
  /// In en, this message translates to:
  /// **'Finding files'**
  String get toolFindingFiles;

  /// CodeWalk UI string — toolPresentationAwaitingInput
  ///
  /// In en, this message translates to:
  /// **'Awaiting input'**
  String get toolPresentationAwaitingInput;

  /// CodeWalk UI string — toolPresentationEditing
  ///
  /// In en, this message translates to:
  /// **'Editing'**
  String get toolPresentationEditing;

  /// CodeWalk UI string — toolPresentationEditingFiles
  ///
  /// In en, this message translates to:
  /// **'Editing files'**
  String get toolPresentationEditingFiles;

  /// CodeWalk UI string — toolPresentationFinding
  ///
  /// In en, this message translates to:
  /// **'Finding'**
  String get toolPresentationFinding;

  /// CodeWalk UI string — toolPresentationFindingFiles
  ///
  /// In en, this message translates to:
  /// **'Finding files'**
  String get toolPresentationFindingFiles;

  /// CodeWalk UI string — toolPresentationReading
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get toolPresentationReading;

  /// CodeWalk UI string — toolPresentationReadingFile
  ///
  /// In en, this message translates to:
  /// **'Reading file'**
  String get toolPresentationReadingFile;

  /// CodeWalk UI string — toolPresentationRunning
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get toolPresentationRunning;

  /// CodeWalk UI string — toolPresentationRunningCommand
  ///
  /// In en, this message translates to:
  /// **'Running command'**
  String get toolPresentationRunningCommand;

  /// CodeWalk UI string — toolPresentationRunningTool
  ///
  /// In en, this message translates to:
  /// **'Running {toolName}'**
  String toolPresentationRunningTool(String toolName);

  /// CodeWalk UI string — toolPresentationSearching
  ///
  /// In en, this message translates to:
  /// **'Searching'**
  String get toolPresentationSearching;

  /// CodeWalk UI string — toolPresentationSearchingCode
  ///
  /// In en, this message translates to:
  /// **'Searching code'**
  String get toolPresentationSearchingCode;

  /// CodeWalk UI string — toolPresentationSearchingWeb
  ///
  /// In en, this message translates to:
  /// **'Searching the web'**
  String get toolPresentationSearchingWeb;

  /// CodeWalk UI string — toolPresentationTool
  ///
  /// In en, this message translates to:
  /// **'Tool'**
  String get toolPresentationTool;

  /// CodeWalk UI string — toolPresentationUpdatingTaskList
  ///
  /// In en, this message translates to:
  /// **'Updating task list'**
  String get toolPresentationUpdatingTaskList;

  /// CodeWalk UI string — toolPresentationUpdatingTasks
  ///
  /// In en, this message translates to:
  /// **'Updating tasks'**
  String get toolPresentationUpdatingTasks;

  /// CodeWalk UI string — toolPresentationWaitingInput
  ///
  /// In en, this message translates to:
  /// **'Waiting for your input'**
  String get toolPresentationWaitingInput;

  /// CodeWalk UI string — toolPresentationWriting
  ///
  /// In en, this message translates to:
  /// **'Writing'**
  String get toolPresentationWriting;

  /// CodeWalk UI string — toolPresentationWritingFile
  ///
  /// In en, this message translates to:
  /// **'Writing file'**
  String get toolPresentationWritingFile;

  /// CodeWalk UI string — toolReading
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get toolReading;

  /// CodeWalk UI string — toolReadingFile
  ///
  /// In en, this message translates to:
  /// **'Reading file'**
  String get toolReadingFile;

  /// CodeWalk UI string — toolRunning
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get toolRunning;

  /// CodeWalk UI string — toolRunningCommand
  ///
  /// In en, this message translates to:
  /// **'Running command'**
  String get toolRunningCommand;

  /// CodeWalk UI string — toolRunningTask
  ///
  /// In en, this message translates to:
  /// **'Running task'**
  String get toolRunningTask;

  /// CodeWalk UI string — toolSearching
  ///
  /// In en, this message translates to:
  /// **'Searching'**
  String get toolSearching;

  /// CodeWalk UI string — toolSearchingCode
  ///
  /// In en, this message translates to:
  /// **'Searching code'**
  String get toolSearchingCode;

  /// CodeWalk UI string — toolSearchingWeb
  ///
  /// In en, this message translates to:
  /// **'Searching the web'**
  String get toolSearchingWeb;

  /// CodeWalk UI string — toolUpdatingTaskList
  ///
  /// In en, this message translates to:
  /// **'Updating task list'**
  String get toolUpdatingTaskList;

  /// CodeWalk UI string — toolUpdatingTasks
  ///
  /// In en, this message translates to:
  /// **'Updating tasks'**
  String get toolUpdatingTasks;

  /// CodeWalk UI string — toolWaitingForInput
  ///
  /// In en, this message translates to:
  /// **'Waiting for your input'**
  String get toolWaitingForInput;

  /// CodeWalk UI string — toolWriting
  ///
  /// In en, this message translates to:
  /// **'Writing'**
  String get toolWriting;

  /// CodeWalk UI string — toolWritingFile
  ///
  /// In en, this message translates to:
  /// **'Writing file'**
  String get toolWritingFile;

  /// CodeWalk UI string — tourBack
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get tourBack;

  /// CodeWalk UI string — tourSkip
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get tourSkip;

  /// CodeWalk UI string — trayQuit
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get trayQuit;

  /// CodeWalk UI string — trayShow
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get trayShow;

  /// CodeWalk UI string — useOAuthCloudflareAccess
  ///
  /// In en, this message translates to:
  /// **'Use OAuth (Cloudflare Access)'**
  String get useOAuthCloudflareAccess;

  /// CodeWalk UI string — useOAuthCloudflareAccessSubtitle
  ///
  /// In en, this message translates to:
  /// **'Opens a browser for Cloudflare Access Managed OAuth.'**
  String get useOAuthCloudflareAccessSubtitle;

  /// CodeWalk UI string — useOAuthCloudflareAccessUnsupported
  ///
  /// In en, this message translates to:
  /// **'Cloudflare Access OAuth is not available on this platform. Use Basic Auth instead.'**
  String get useOAuthCloudflareAccessUnsupported;

  /// CodeWalk UI string — useTailscale
  ///
  /// In en, this message translates to:
  /// **'Use Tailscale'**
  String get useTailscale;

  /// CodeWalk UI string — useTailscaleSubtitle
  ///
  /// In en, this message translates to:
  /// **'Routes traffic through the Tailscale network without a system VPN.'**
  String get useTailscaleSubtitle;

  /// CodeWalk UI string — useTailscaleUnsupported
  ///
  /// In en, this message translates to:
  /// **'Tailscale is not supported on this platform.'**
  String get useTailscaleUnsupported;

  /// CodeWalk UI string — utilityTitle
  ///
  /// In en, this message translates to:
  /// **'Utility'**
  String get utilityTitle;

  /// CodeWalk UI string — workspaceBrowseDirs
  ///
  /// In en, this message translates to:
  /// **'Browse directories'**
  String get workspaceBrowseDirs;

  /// CodeWalk UI string — workspaceChooseFolderOpen
  ///
  /// In en, this message translates to:
  /// **'Choose any folder to open as project context.'**
  String get workspaceChooseFolderOpen;

  /// CodeWalk UI string — workspaceCloseProject
  ///
  /// In en, this message translates to:
  /// **'Close {project}'**
  String workspaceCloseProject(String project);

  /// CodeWalk UI string — workspaceClosedProjects
  ///
  /// In en, this message translates to:
  /// **'Closed projects'**
  String get workspaceClosedProjects;

  /// CodeWalk UI string — workspaceCurrentDirectory
  ///
  /// In en, this message translates to:
  /// **'Current directory: {path}'**
  String workspaceCurrentDirectory(String path);

  /// CodeWalk UI string — workspaceFilterDirs
  ///
  /// In en, this message translates to:
  /// **'Filter directories'**
  String get workspaceFilterDirs;

  /// CodeWalk UI string — workspaceOpenFolder
  ///
  /// In en, this message translates to:
  /// **'Open folder'**
  String get workspaceOpenFolder;

  /// CodeWalk UI string — workspaceOpenProjectFolder
  ///
  /// In en, this message translates to:
  /// **'Open project folder'**
  String get workspaceOpenProjectFolder;

  /// CodeWalk UI string — workspaceOpenProjects
  ///
  /// In en, this message translates to:
  /// **'Open projects'**
  String get workspaceOpenProjects;

  /// CodeWalk UI string — workspaceProjectDirectory
  ///
  /// In en, this message translates to:
  /// **'Project directory'**
  String get workspaceProjectDirectory;

  /// CodeWalk UI string — workspaceProjectHint
  ///
  /// In en, this message translates to:
  /// **'/repo/my-project'**
  String get workspaceProjectHint;

  /// CodeWalk UI string — workspaceRemoveFromHistory
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from history'**
  String workspaceRemoveFromHistory(String name);

  /// Title for the opt-in floating session attention setting
  ///
  /// In en, this message translates to:
  /// **'Session attention'**
  String get settingsSessionAttentionTitle;

  /// Description for floating session attention modes
  ///
  /// In en, this message translates to:
  /// **'Show root-session status in an opt-in bubble or panel.'**
  String get settingsSessionAttentionDescription;

  /// Disabled session attention mode
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsSessionAttentionOff;

  /// Compact session attention mode
  ///
  /// In en, this message translates to:
  /// **'Bubble'**
  String get settingsSessionAttentionBubble;

  /// Expanded session attention mode
  ///
  /// In en, this message translates to:
  /// **'Panel'**
  String get settingsSessionAttentionPanel;

  /// Privacy, foreground-service, and cloud TTS disclosure
  ///
  /// In en, this message translates to:
  /// **'On Android, enabling this starts a persistent foreground service. Response text is stored encrypted; cloud TTS sends text only after you press Read.'**
  String get settingsSessionAttentionPrivacy;

  /// Unsupported platform explanation
  ///
  /// In en, this message translates to:
  /// **'Session attention is unavailable on this platform.'**
  String get settingsSessionAttentionUnavailable;

  /// Open Android overlay permission settings
  ///
  /// In en, this message translates to:
  /// **'Open display settings'**
  String get settingsSessionAttentionOpenSettings;

  /// Stop the active session attention host
  ///
  /// In en, this message translates to:
  /// **'Stop session attention'**
  String get settingsSessionAttentionStop;

  /// Third-party text-to-speech data use warning
  ///
  /// In en, this message translates to:
  /// **'When you press Read, response text may be sent to the configured third-party TTS provider.'**
  String get settingsSessionAttentionThirdPartyTtsWarning;

  /// CodeWalk UI string — workspaceSuggestions
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get workspaceSuggestions;

  /// Title for the session tab gesture onboarding dialog
  ///
  /// In en, this message translates to:
  /// **'Session tabs have new controls'**
  String get sessionTabsGestureHintTitle;

  /// Instructions for closing tabs, opening their menu, and disabling tabs
  ///
  /// In en, this message translates to:
  /// **'Double-click or double-tap a tab to close it. Right-click or touch and hold to open session actions. You can disable tabs in Display Toggles.'**
  String get sessionTabsGestureHintBody;

  /// Acknowledgement button for the session tab gesture dialog
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get sessionTabsGestureHintAcknowledge;

  /// Button that disables session tabs from the gesture dialog
  ///
  /// In en, this message translates to:
  /// **'Disable tabs'**
  String get sessionTabsGestureHintDisableTabs;

  /// Rename action in the active session tab menu
  ///
  /// In en, this message translates to:
  /// **'Rename session'**
  String get sessionTabRenameAction;

  /// Snackbar shown after closing a session tab
  ///
  /// In en, this message translates to:
  /// **'Tab \"{title}\" closed'**
  String sessionTabClosedMessage(String title);

  /// Snackbar action that restores a closed session tab
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get sessionTabUndo;

  /// Snackbar shown when undo cannot restore a closed session tab
  ///
  /// In en, this message translates to:
  /// **'Tab could not be restored.'**
  String get sessionTabRestoreFailed;

  /// Action that opens the icon picker for a session tab
  ///
  /// In en, this message translates to:
  /// **'Change icon'**
  String get sessionTabChangeIconAction;

  /// Title for the session tab icon picker
  ///
  /// In en, this message translates to:
  /// **'Choose tab icon'**
  String get sessionTabIconPickerTitle;

  /// Option that removes a session tab icon override
  ///
  /// In en, this message translates to:
  /// **'Use project icon'**
  String get sessionTabIconUseProjectIcon;

  /// Snackbar shown after a tab icon is saved
  ///
  /// In en, this message translates to:
  /// **'Tab icon updated.'**
  String get sessionTabIconApplied;

  /// Snackbar shown when a tab icon cannot be saved
  ///
  /// In en, this message translates to:
  /// **'Tab icon could not be saved.'**
  String get sessionTabIconSaveFailed;

  /// Label for the Code tab icon preset
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get sessionTabIconPresetCode;

  /// Label for the Terminal tab icon preset
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get sessionTabIconPresetTerminal;

  /// Label for the Bug tab icon preset
  ///
  /// In en, this message translates to:
  /// **'Bug'**
  String get sessionTabIconPresetBug;

  /// Label for the Tasks tab icon preset
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get sessionTabIconPresetTasks;

  /// Label for the Launch tab icon preset
  ///
  /// In en, this message translates to:
  /// **'Launch'**
  String get sessionTabIconPresetLaunch;

  /// Label for the Idea tab icon preset
  ///
  /// In en, this message translates to:
  /// **'Idea'**
  String get sessionTabIconPresetIdea;

  /// Label for the Research tab icon preset
  ///
  /// In en, this message translates to:
  /// **'Research'**
  String get sessionTabIconPresetResearch;

  /// Label for the Design tab icon preset
  ///
  /// In en, this message translates to:
  /// **'Design'**
  String get sessionTabIconPresetDesign;

  /// Label for the Data tab icon preset
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get sessionTabIconPresetData;

  /// Label for the Cloud tab icon preset
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get sessionTabIconPresetCloud;

  /// Label for the Security tab icon preset
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get sessionTabIconPresetSecurity;

  /// Label for the Tools tab icon preset
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get sessionTabIconPresetTools;

  /// CodeWalk UI string — workspaceNoActiveContext
  ///
  /// In en, this message translates to:
  /// **'No active context'**
  String get workspaceNoActiveContext;

  /// CodeWalk UI string — settingsAppearanceContrastLow
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get settingsAppearanceContrastLow;

  /// CodeWalk UI string — settingsAppearanceContrastStandard
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get settingsAppearanceContrastStandard;

  /// CodeWalk UI string — settingsAppearanceContrastMedium
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get settingsAppearanceContrastMedium;

  /// CodeWalk UI string — settingsAppearanceContrastMediumHigh
  ///
  /// In en, this message translates to:
  /// **'Medium High'**
  String get settingsAppearanceContrastMediumHigh;

  /// CodeWalk UI string — settingsNotificationsSystemSoundsWebUnavailable
  ///
  /// In en, this message translates to:
  /// **'Not available on web.'**
  String get settingsNotificationsSystemSoundsWebUnavailable;

  /// CodeWalk UI string — settingsNotificationsSystemSoundsAndroid
  ///
  /// In en, this message translates to:
  /// **'Android notification sounds from the system.'**
  String get settingsNotificationsSystemSoundsAndroid;

  /// CodeWalk UI string — settingsNotificationsSystemSoundsFreedesktop
  ///
  /// In en, this message translates to:
  /// **'Freedesktop sounds from /usr/share/sounds/freedesktop/stereo.'**
  String get settingsNotificationsSystemSoundsFreedesktop;

  /// CodeWalk UI string — settingsNotificationsSystemSoundsPlatform
  ///
  /// In en, this message translates to:
  /// **'Supported where the operating system exposes system sounds.'**
  String get settingsNotificationsSystemSoundsPlatform;

  /// CodeWalk UI string — serversQuickGuideTitle
  ///
  /// In en, this message translates to:
  /// **'Quick setup'**
  String get serversQuickGuideTitle;

  /// CodeWalk UI string — serversQuickGuideIntro
  ///
  /// In en, this message translates to:
  /// **'CodeWalk is the app. OpenCode is the engine that needs to be running before this connection can work.'**
  String get serversQuickGuideIntro;

  /// CodeWalk UI string — serversQuickGuideStepInstallCli
  ///
  /// In en, this message translates to:
  /// **'1. Install OpenCode CLI.'**
  String get serversQuickGuideStepInstallCli;

  /// CodeWalk UI string — serversQuickGuideRunPowerShell
  ///
  /// In en, this message translates to:
  /// **'2. Run in PowerShell:'**
  String get serversQuickGuideRunPowerShell;

  /// CodeWalk UI string — serversQuickGuideRunTerminal
  ///
  /// In en, this message translates to:
  /// **'2. Run in your terminal:'**
  String get serversQuickGuideRunTerminal;

  /// CodeWalk UI string — serversQuickGuideProtectPassword
  ///
  /// In en, this message translates to:
  /// **'Protect access with password'**
  String get serversQuickGuideProtectPassword;

  /// CodeWalk UI string — serversQuickGuideServerPassword
  ///
  /// In en, this message translates to:
  /// **'Server password'**
  String get serversQuickGuideServerPassword;

  /// CodeWalk UI string — serversQuickGuideInstallOptions
  ///
  /// In en, this message translates to:
  /// **'Other official install options: install script, npm, bun, pnpm, Homebrew, or a binary from GitHub Releases.'**
  String get serversQuickGuideInstallOptions;

  /// CodeWalk UI string — serversQuickGuideVerifyHint
  ///
  /// In en, this message translates to:
  /// **'After starting the server, confirm /global/health or /doc responds before pasting the URL into CodeWalk.'**
  String get serversQuickGuideVerifyHint;

  /// CodeWalk UI string — shortcutsPressKeyCombination
  ///
  /// In en, this message translates to:
  /// **'Press the key combination now'**
  String get shortcutsPressKeyCombination;

  /// CodeWalk UI string — settingsProvenanceOpenCodeBacked
  ///
  /// In en, this message translates to:
  /// **'OpenCode-backed'**
  String get settingsProvenanceOpenCodeBacked;

  /// CodeWalk UI string — settingsProvenanceCodeWalkLocal
  ///
  /// In en, this message translates to:
  /// **'CodeWalk-local'**
  String get settingsProvenanceCodeWalkLocal;

  /// CodeWalk UI string — settingsProvenanceCodeWalkException
  ///
  /// In en, this message translates to:
  /// **'CodeWalk exception'**
  String get settingsProvenanceCodeWalkException;

  /// CodeWalk UI string — shortcutsErrorInvalid
  ///
  /// In en, this message translates to:
  /// **'Invalid shortcut'**
  String get shortcutsErrorInvalid;

  /// CodeWalk UI string — shortcutsErrorUnsupportedKey
  ///
  /// In en, this message translates to:
  /// **'Unsupported shortcut key'**
  String get shortcutsErrorUnsupportedKey;

  /// CodeWalk UI string — shortcutsErrorConflict
  ///
  /// In en, this message translates to:
  /// **'Conflicts with \"{conflict}\"'**
  String shortcutsErrorConflict(String conflict);

  /// CodeWalk UI string — settingsSessionAttentionStopSaveFailed
  ///
  /// In en, this message translates to:
  /// **'Session attention was stopped but the setting could not be saved.'**
  String get settingsSessionAttentionStopSaveFailed;

  /// CodeWalk UI string — settingsSessionAttentionEnableFailed
  ///
  /// In en, this message translates to:
  /// **'Session attention could not be enabled.'**
  String get settingsSessionAttentionEnableFailed;

  /// CodeWalk UI string — settingsSessionAttentionSaveFailedStopped
  ///
  /// In en, this message translates to:
  /// **'Session attention could not be saved and was stopped.'**
  String get settingsSessionAttentionSaveFailedStopped;

  /// CodeWalk UI string — settingsSessionAttentionStillRunning
  ///
  /// In en, this message translates to:
  /// **'Session attention is still running. Try stopping it again.'**
  String get settingsSessionAttentionStillRunning;

  /// CodeWalk UI string — settingsSessionAttentionStopFailed
  ///
  /// In en, this message translates to:
  /// **'Session attention could not be stopped. Try again.'**
  String get settingsSessionAttentionStopFailed;

  /// CodeWalk UI string — settingsSessionAttentionCapabilityUnavailable
  ///
  /// In en, this message translates to:
  /// **'Session attention host capability is unavailable.'**
  String get settingsSessionAttentionCapabilityUnavailable;

  /// CodeWalk UI string — settingsServerFallbackProviderName
  ///
  /// In en, this message translates to:
  /// **'Configured on server'**
  String get settingsServerFallbackProviderName;

  /// CodeWalk UI string — composerStopResponse
  ///
  /// In en, this message translates to:
  /// **'Stop response'**
  String get composerStopResponse;

  /// CodeWalk UI string — composerSendMessageWhileResponding
  ///
  /// In en, this message translates to:
  /// **'Send message while response is running'**
  String get composerSendMessageWhileResponding;

  /// CodeWalk UI string — composerSendMessage
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get composerSendMessage;

  /// CodeWalk UI string — chatTourComposerDescription
  ///
  /// In en, this message translates to:
  /// **'Type your request here.'**
  String get chatTourComposerDescription;

  /// CodeWalk UI string — chatTourSendDescription
  ///
  /// In en, this message translates to:
  /// **'Send your message here.'**
  String get chatTourSendDescription;

  /// CodeWalk UI string — composerAttachmentFallbackName
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get composerAttachmentFallbackName;

  /// CodeWalk UI string — composerContextFallbackName
  ///
  /// In en, this message translates to:
  /// **'Context'**
  String get composerContextFallbackName;

  /// CodeWalk UI string — searchableDropdownSearchHint
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchableDropdownSearchHint;

  /// CodeWalk UI string — searchableDropdownEmptyText
  ///
  /// In en, this message translates to:
  /// **'No matches found'**
  String get searchableDropdownEmptyText;

  /// CodeWalk UI string — speechApiKeyStorageUnavailable
  ///
  /// In en, this message translates to:
  /// **'Secure TTS API key storage is unavailable.'**
  String get speechApiKeyStorageUnavailable;

  /// CodeWalk UI string — speechApiKeyRemoved
  ///
  /// In en, this message translates to:
  /// **'API key removed.'**
  String get speechApiKeyRemoved;

  /// CodeWalk UI string — speechApiKeySaved
  ///
  /// In en, this message translates to:
  /// **'API key saved securely on this device.'**
  String get speechApiKeySaved;

  /// CodeWalk UI string — speechReadAloudTestText
  ///
  /// In en, this message translates to:
  /// **'This is a CodeWalk text-to-speech test.'**
  String get speechReadAloudTestText;

  /// CodeWalk UI string — speechNativeDisabledWindows
  ///
  /// In en, this message translates to:
  /// **'Disabled on Windows for stability. Use Parakeet or another on-device engine through CodeWalk WASAPI capture.'**
  String get speechNativeDisabledWindows;

  /// CodeWalk UI string — speechNativeUnavailableLinux
  ///
  /// In en, this message translates to:
  /// **'Unavailable on Linux. Use Parakeet for speech input.'**
  String get speechNativeUnavailableLinux;

  /// CodeWalk UI string — speechNotAvailableOnPlatform
  ///
  /// In en, this message translates to:
  /// **'Not available on this platform.'**
  String get speechNotAvailableOnPlatform;

  /// CodeWalk UI string — speechSherpaUnavailableAndroid
  ///
  /// In en, this message translates to:
  /// **'Unavailable on Android builds optimized for small APK size.'**
  String get speechSherpaUnavailableAndroid;

  /// CodeWalk UI string — speechMoonshineDesktopOnlyHint
  ///
  /// In en, this message translates to:
  /// **'Available on desktop only. Android stays native-only.'**
  String get speechMoonshineDesktopOnlyHint;

  /// CodeWalk UI string — speechParakeetDesktopOnlyHint
  ///
  /// In en, this message translates to:
  /// **'Available on desktop only. Uses offline multilingual recognition.'**
  String get speechParakeetDesktopOnlyHint;

  /// CodeWalk UI string — speechSenseVoiceDesktopOnlyHint
  ///
  /// In en, this message translates to:
  /// **'Available on desktop only. Strongest for Chinese, Cantonese, Japanese, Korean, and English.'**
  String get speechSenseVoiceDesktopOnlyHint;

  /// CodeWalk UI string — speechNativeSubtitle
  ///
  /// In en, this message translates to:
  /// **'Simpler and faster startup.'**
  String get speechNativeSubtitle;

  /// CodeWalk UI string — speechSherpaSubtitle
  ///
  /// In en, this message translates to:
  /// **'Heavier, experimental, and bug-prone. Often more precise with downloaded models.'**
  String get speechSherpaSubtitle;

  /// CodeWalk UI string — speechMoonshineSubtitle
  ///
  /// In en, this message translates to:
  /// **'Desktop-only experimental path using sherpa_onnx offline recognition and downloadable models.'**
  String get speechMoonshineSubtitle;

  /// CodeWalk UI string — speechParakeetSubtitle
  ///
  /// In en, this message translates to:
  /// **'Desktop-only offline NeMo transducer path with one multilingual downloadable model.'**
  String get speechParakeetSubtitle;

  /// CodeWalk UI string — speechSenseVoiceSubtitle
  ///
  /// In en, this message translates to:
  /// **'Desktop-only offline path tuned for Chinese, Cantonese, Japanese, Korean, and English.'**
  String get speechSenseVoiceSubtitle;

  /// CodeWalk UI string — speechMoonshineModel
  ///
  /// In en, this message translates to:
  /// **'Moonshine model'**
  String get speechMoonshineModel;

  /// CodeWalk UI string — speechSherpaLanguage
  ///
  /// In en, this message translates to:
  /// **'Sherpa language'**
  String get speechSherpaLanguage;

  /// CodeWalk UI string — speechSearchSherpaLanguage
  ///
  /// In en, this message translates to:
  /// **'Search Sherpa language'**
  String get speechSearchSherpaLanguage;

  /// CodeWalk UI string — speechNoLanguagePacksFound
  ///
  /// In en, this message translates to:
  /// **'No language packs found'**
  String get speechNoLanguagePacksFound;

  /// CodeWalk UI string — speechTextToSpeechProvider
  ///
  /// In en, this message translates to:
  /// **'Text-to-speech provider'**
  String get speechTextToSpeechProvider;

  /// CodeWalk UI string — speechProviderSystemNative
  ///
  /// In en, this message translates to:
  /// **'System / Native'**
  String get speechProviderSystemNative;

  /// CodeWalk UI string — speechProviderEdgeExperimental
  ///
  /// In en, this message translates to:
  /// **'Microsoft Edge Speech (experimental)'**
  String get speechProviderEdgeExperimental;

  /// CodeWalk UI string — speechProviderOpenAiCompatible
  ///
  /// In en, this message translates to:
  /// **'OpenAI-compatible'**
  String get speechProviderOpenAiCompatible;

  /// CodeWalk UI string — speechProviderElevenLabs
  ///
  /// In en, this message translates to:
  /// **'ElevenLabs'**
  String get speechProviderElevenLabs;

  /// CodeWalk UI string — speechProviderNvidiaNim
  ///
  /// In en, this message translates to:
  /// **'NVIDIA NIM'**
  String get speechProviderNvidiaNim;

  /// CodeWalk UI string — speechNimSpeedNotSupported
  ///
  /// In en, this message translates to:
  /// **'Speed is not supported by NVIDIA NIM TTS and is hidden for this provider.'**
  String get speechNimSpeedNotSupported;

  /// CodeWalk UI string — speechRemoteVoice
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get speechRemoteVoice;

  /// CodeWalk UI string — speechRemoteVoiceUnavailable
  ///
  /// In en, this message translates to:
  /// **'The selected voice is no longer available in the provider catalog.'**
  String get speechRemoteVoiceUnavailable;

  /// CodeWalk UI string — speechRemoteVoiceListUnavailable
  ///
  /// In en, this message translates to:
  /// **'Using the default voice. The voice list could not be loaded right now.'**
  String get speechRemoteVoiceListUnavailable;

  /// CodeWalk UI string — speechRemoteVoicesLoaded
  ///
  /// In en, this message translates to:
  /// **'Loaded from the provider voices.'**
  String get speechRemoteVoicesLoaded;

  /// CodeWalk UI string — speechRemoteModel
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get speechRemoteModel;

  /// CodeWalk UI string — speechRemoteModelListUnavailable
  ///
  /// In en, this message translates to:
  /// **'The model list could not be loaded right now. You can type a custom model below.'**
  String get speechRemoteModelListUnavailable;

  /// CodeWalk UI string — speechRemoteModelsLoaded
  ///
  /// In en, this message translates to:
  /// **'Loaded from the provider models.'**
  String get speechRemoteModelsLoaded;

  /// CodeWalk UI string — speechRemoteModelUnavailable
  ///
  /// In en, this message translates to:
  /// **'The selected model is no longer available in the provider catalog.'**
  String get speechRemoteModelUnavailable;

  /// CodeWalk UI string — speechCustomModel
  ///
  /// In en, this message translates to:
  /// **'Custom model…'**
  String get speechCustomModel;

  /// CodeWalk UI string — speechEdgeExperimentalTitle
  ///
  /// In en, this message translates to:
  /// **'Microsoft Edge Speech is experimental'**
  String get speechEdgeExperimentalTitle;

  /// CodeWalk UI string — speechEdgeExperimentalDescription
  ///
  /// In en, this message translates to:
  /// **'Uses the unofficial Edge Read Aloud service directly from this device. Message text is sent to Microsoft when you use read aloud, and the service may break if Microsoft changes the private protocol.'**
  String get speechEdgeExperimentalDescription;

  /// CodeWalk UI string — speechEdgeVoice
  ///
  /// In en, this message translates to:
  /// **'Edge voice'**
  String get speechEdgeVoice;

  /// CodeWalk UI string — speechEdgeVoiceUnavailable
  ///
  /// In en, this message translates to:
  /// **'The selected voice is no longer available. Using the default Edge voice.'**
  String get speechEdgeVoiceUnavailable;

  /// CodeWalk UI string — speechEdgeVoiceListUnavailable
  ///
  /// In en, this message translates to:
  /// **'Using the default Edge voice. Voice list could not be loaded right now.'**
  String get speechEdgeVoiceListUnavailable;

  /// CodeWalk UI string — speechEdgeVoicesLoaded
  ///
  /// In en, this message translates to:
  /// **'Loaded from Microsoft Edge Speech voices.'**
  String get speechEdgeVoicesLoaded;

  /// CodeWalk UI string — speechCloudTtsPrivacy
  ///
  /// In en, this message translates to:
  /// **'Cloud TTS privacy'**
  String get speechCloudTtsPrivacy;

  /// CodeWalk UI string — speechCloudTtsPrivacyDescription
  ///
  /// In en, this message translates to:
  /// **'Cloud TTS sends the selected assistant message text to the configured provider. API keys are stored in secure storage on this device.'**
  String get speechCloudTtsPrivacyDescription;

  /// CodeWalk UI string — speechBaseUrl
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get speechBaseUrl;

  /// CodeWalk UI string — speechApiKey
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get speechApiKey;

  /// CodeWalk UI string — speechApiKeySavedHelper
  ///
  /// In en, this message translates to:
  /// **'A key is saved. Enter a new value to replace it, or save an empty value to remove it.'**
  String get speechApiKeySavedHelper;

  /// CodeWalk UI string — speechNoApiKeySaved
  ///
  /// In en, this message translates to:
  /// **'No API key saved.'**
  String get speechNoApiKeySaved;

  /// CodeWalk UI string — speechSaveApiKey
  ///
  /// In en, this message translates to:
  /// **'Save API key'**
  String get speechSaveApiKey;

  /// CodeWalk UI string — speechModel
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get speechModel;

  /// CodeWalk UI string — speechPitchNotSupported
  ///
  /// In en, this message translates to:
  /// **'Pitch is not supported by OpenAI-compatible TTS and is hidden for this provider.'**
  String get speechPitchNotSupported;

  /// CodeWalk UI string — speechPitchHiddenForProvider
  ///
  /// In en, this message translates to:
  /// **'Pitch is not supported by this TTS provider and is hidden.'**
  String get speechPitchHiddenForProvider;

  /// CodeWalk UI string — speechTestVoice
  ///
  /// In en, this message translates to:
  /// **'Test voice'**
  String get speechTestVoice;

  /// CodeWalk UI string — speechReadAloudTestPhraseLabel
  ///
  /// In en, this message translates to:
  /// **'Voice test phrase'**
  String get speechReadAloudTestPhraseLabel;

  /// CodeWalk UI string — speechReadAloudTestPhraseHint
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the default test phrase.'**
  String get speechReadAloudTestPhraseHint;

  /// CodeWalk UI string — dialogMoonshineVoiceSetupDescription
  ///
  /// In en, this message translates to:
  /// **'Moonshine runs on-device through sherpa_onnx. Pick a model once and download it only for this desktop device.'**
  String get dialogMoonshineVoiceSetupDescription;

  /// CodeWalk UI string — dialogParakeetVoiceSetupDescription
  ///
  /// In en, this message translates to:
  /// **'Parakeet runs on-device through sherpa_onnx offline recognition. Download it once for this desktop device to enable multilingual STT.'**
  String get dialogParakeetVoiceSetupDescription;

  /// CodeWalk UI string — dialogSenseVoiceSetupDescription
  ///
  /// In en, this message translates to:
  /// **'SenseVoice runs on-device through sherpa_onnx offline recognition. It is strongest for Chinese, Cantonese, Japanese, Korean, and English.'**
  String get dialogSenseVoiceSetupDescription;

  /// CodeWalk UI string — dialogSherpaVoiceSetupDescription
  ///
  /// In en, this message translates to:
  /// **'Sherpa voice input requires an on-device speech model. Select your language and download it once (~147 MB).'**
  String get dialogSherpaVoiceSetupDescription;

  /// CodeWalk UI string — speechSilenceSeconds
  ///
  /// In en, this message translates to:
  /// **'{value} seconds'**
  String speechSilenceSeconds(String value);

  /// CodeWalk UI string — speechModelInstalled
  ///
  /// In en, this message translates to:
  /// **'Model installed ({modelId})'**
  String speechModelInstalled(String modelId);

  /// CodeWalk UI string — speechModelMissing
  ///
  /// In en, this message translates to:
  /// **'Model missing ({modelId})'**
  String speechModelMissing(String modelId);

  /// CodeWalk UI string — speechModelSizeMb
  ///
  /// In en, this message translates to:
  /// **'~{sizeMb} MB'**
  String speechModelSizeMb(String sizeMb);

  /// CodeWalk UI string — speechSystemDefaultLanguage
  ///
  /// In en, this message translates to:
  /// **'System default ({language})'**
  String speechSystemDefaultLanguage(String language);

  /// CodeWalk UI string — speechModelListLoadFailed
  ///
  /// In en, this message translates to:
  /// **'Failed to load {service} model list: {error}'**
  String speechModelListLoadFailed(String error, String service);

  /// CodeWalk UI string — speechDownloadFailed
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String speechDownloadFailed(String error);

  /// CodeWalk UI string — speechFailedToRemoveModel
  ///
  /// In en, this message translates to:
  /// **'Failed to remove model: {error}'**
  String speechFailedToRemoveModel(String error);

  /// CodeWalk UI string — speechBaseUrlExample
  ///
  /// In en, this message translates to:
  /// **'Example: {url}'**
  String speechBaseUrlExample(String url);

  /// CodeWalk UI string — speechModelDefaultHelper
  ///
  /// In en, this message translates to:
  /// **'Default: {model}'**
  String speechModelDefaultHelper(String model);

  /// CodeWalk UI string — notificationPermissionOrQuestionNeedsInput
  ///
  /// In en, this message translates to:
  /// **'A tool permission or question needs your input.'**
  String get notificationPermissionOrQuestionNeedsInput;

  /// CodeWalk UI string — notificationPermissionNeedsInput
  ///
  /// In en, this message translates to:
  /// **'A tool permission needs your input.'**
  String get notificationPermissionNeedsInput;

  /// CodeWalk UI string — notificationQuestionNeedsInput
  ///
  /// In en, this message translates to:
  /// **'A tool question needs your input.'**
  String get notificationQuestionNeedsInput;

  /// CodeWalk UI string — notificationSessionError
  ///
  /// In en, this message translates to:
  /// **'A session reported an error.'**
  String get notificationSessionError;

  /// CodeWalk UI string — notificationChannelErrors
  ///
  /// In en, this message translates to:
  /// **'CodeWalk errors'**
  String get notificationChannelErrors;

  /// CodeWalk UI string — notificationChannelErrorsDescription
  ///
  /// In en, this message translates to:
  /// **'CodeWalk error alerts'**
  String get notificationChannelErrorsDescription;

  /// CodeWalk UI string — notificationChannelPermissions
  ///
  /// In en, this message translates to:
  /// **'CodeWalk permissions'**
  String get notificationChannelPermissions;

  /// CodeWalk UI string — notificationChannelPermissionsDescription
  ///
  /// In en, this message translates to:
  /// **'CodeWalk action required alerts'**
  String get notificationChannelPermissionsDescription;

  /// CodeWalk UI string — notificationChannelAgent
  ///
  /// In en, this message translates to:
  /// **'CodeWalk agent'**
  String get notificationChannelAgent;

  /// CodeWalk UI string — notificationChannelAgentDescription
  ///
  /// In en, this message translates to:
  /// **'CodeWalk agent completion alerts'**
  String get notificationChannelAgentDescription;

  /// CodeWalk UI string — notificationActionOpen
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get notificationActionOpen;

  /// CodeWalk UI string — foregroundMonitorNotificationBody
  ///
  /// In en, this message translates to:
  /// **'Reliable background alerts are active'**
  String get foregroundMonitorNotificationBody;

  /// CodeWalk UI string — foregroundMonitorNotificationTitle
  ///
  /// In en, this message translates to:
  /// **'Background monitoring active'**
  String get foregroundMonitorNotificationTitle;

  /// CodeWalk UI string — foregroundMonitorNotificationOneSession
  ///
  /// In en, this message translates to:
  /// **'Monitoring one session'**
  String get foregroundMonitorNotificationOneSession;

  /// CodeWalk UI string — foregroundMonitorNotificationSessionCount
  ///
  /// In en, this message translates to:
  /// **'Monitoring {count} sessions'**
  String foregroundMonitorNotificationSessionCount(int count);

  /// CodeWalk UI string — sessionAttentionSemanticLabel
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 session needs attention} other{{count} sessions need attention}}'**
  String sessionAttentionSemanticLabel(int count);

  /// CodeWalk UI string — sessionAttentionOverlayPermissionRequired
  ///
  /// In en, this message translates to:
  /// **'Display-over-other-apps permission is required.'**
  String get sessionAttentionOverlayPermissionRequired;

  /// CodeWalk UI string — sessionAttentionIosInAppOnly
  ///
  /// In en, this message translates to:
  /// **'Session attention is available only inside CodeWalk.'**
  String get sessionAttentionIosInAppOnly;

  /// CodeWalk UI string — sessionAttentionOverlayPermissionGrantPrompt
  ///
  /// In en, this message translates to:
  /// **'Grant display-over-other-apps permission, then try again.'**
  String get sessionAttentionOverlayPermissionGrantPrompt;

  /// CodeWalk UI string — sessionAttentionAndroidStartFailed
  ///
  /// In en, this message translates to:
  /// **'The Android session attention service could not start.'**
  String get sessionAttentionAndroidStartFailed;

  /// CodeWalk UI string — chatMessageTruncatedChars
  ///
  /// In en, this message translates to:
  /// **'[truncated {count} chars] {reason}'**
  String chatMessageTruncatedChars(int count, String reason);

  /// CodeWalk UI string — chatMessageJustNow
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get chatMessageJustNow;

  /// CodeWalk UI string — chatMessageMinutesAgo
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String chatMessageMinutesAgo(int count);

  /// CodeWalk UI string — chatMessageHoursAgo
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String chatMessageHoursAgo(int count);

  /// CodeWalk UI string — chatMessageDaysAgo
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String chatMessageDaysAgo(int count);

  /// CodeWalk UI string — chatMessageDateTime
  ///
  /// In en, this message translates to:
  /// **'{month}/{day} {hour}:{minute}'**
  String chatMessageDateTime(int day, int hour, int minute, int month);

  /// CodeWalk UI string — chatMessageYourMessage
  ///
  /// In en, this message translates to:
  /// **'Your message'**
  String get chatMessageYourMessage;

  /// CodeWalk UI string — chatMessageAssistantMessage
  ///
  /// In en, this message translates to:
  /// **'Assistant message'**
  String get chatMessageAssistantMessage;

  /// CodeWalk UI string — chatMessageStepStarted
  ///
  /// In en, this message translates to:
  /// **'Step started #{step}'**
  String chatMessageStepStarted(int step);

  /// CodeWalk UI string — chatMessageStepStartedWithSnapshot
  ///
  /// In en, this message translates to:
  /// **'Step started #{step}: {snapshot}'**
  String chatMessageStepStartedWithSnapshot(String snapshot, int step);

  /// CodeWalk UI string — chatMessageStepFinished
  ///
  /// In en, this message translates to:
  /// **'Step finished #{step}: {reason} • tokens {tokens} • \${cost}'**
  String chatMessageStepFinished(
    String cost,
    String reason,
    int step,
    int tokens,
  );

  /// CodeWalk UI string — chatMessagePatchCount
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 patch} other{{count} patches}}'**
  String chatMessagePatchCount(int count);

  /// CodeWalk UI string — chatMessageToolRun
  ///
  /// In en, this message translates to:
  /// **'Tool run'**
  String get chatMessageToolRun;

  /// CodeWalk UI string — chatMessageToolExecution
  ///
  /// In en, this message translates to:
  /// **'Tool execution'**
  String get chatMessageToolExecution;

  /// CodeWalk UI string — chatMessageToolChainMore
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{+1 more} other{+{count} more}}'**
  String chatMessageToolChainMore(int count);

  /// CodeWalk UI string — chatMessageToolChainExtraTypes
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{+1 type} other{+{count} types}}'**
  String chatMessageToolChainExtraTypes(int count);

  /// CodeWalk UI string — chatMessageToolAttentionCount
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 needs attention} other{{count} need attention}}'**
  String chatMessageToolAttentionCount(int count);

  /// CodeWalk UI string — chatMessageToolDoneCount
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 done} other{{count} done}}'**
  String chatMessageToolDoneCount(int count);

  /// CodeWalk UI string — chatMessageToolCallsTitle
  ///
  /// In en, this message translates to:
  /// **'Tool calls'**
  String get chatMessageToolCallsTitle;

  /// CodeWalk UI string — chatMessageDiffPreviewTruncated
  ///
  /// In en, this message translates to:
  /// **'Diff preview truncated for app stability.'**
  String get chatMessageDiffPreviewTruncated;

  /// CodeWalk UI string — chatMessageLargeMessageTruncated
  ///
  /// In en, this message translates to:
  /// **'Large message preview truncated for app stability.'**
  String get chatMessageLargeMessageTruncated;

  /// CodeWalk UI string — chatMessageInvalidLinkFormat
  ///
  /// In en, this message translates to:
  /// **'Invalid link format'**
  String get chatMessageInvalidLinkFormat;

  /// CodeWalk UI string — chatMessageUnableToOpenLink
  ///
  /// In en, this message translates to:
  /// **'Unable to open link'**
  String get chatMessageUnableToOpenLink;

  /// CodeWalk UI string — sessionTodoInProgressCompact
  ///
  /// In en, this message translates to:
  /// **'{current}/{total} in progress'**
  String sessionTodoInProgressCompact(int current, int total);

  /// CodeWalk UI string — sessionTodoTaskProgress
  ///
  /// In en, this message translates to:
  /// **'Task {index}/{total} {content}'**
  String sessionTodoTaskProgress(String content, int index, int total);

  /// CodeWalk UI string — sessionTodoDoneCompact
  ///
  /// In en, this message translates to:
  /// **'{count}/{total} done'**
  String sessionTodoDoneCompact(int count, int total);

  /// CodeWalk UI string — sessionTodoCompletedCount
  ///
  /// In en, this message translates to:
  /// **'Tasks {count}/{total} completed'**
  String sessionTodoCompletedCount(int count, int total);

  /// CodeWalk UI string — sessionTodoTasksCount
  ///
  /// In en, this message translates to:
  /// **'Tasks ({count})'**
  String sessionTodoTasksCount(int count);

  /// CodeWalk UI string — questionStepOfReview
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total} - Review'**
  String questionStepOfReview(int current, int total);

  /// CodeWalk UI string — questionStepOfQuestion
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total} - Question'**
  String questionStepOfQuestion(int current, int total);

  /// CodeWalk UI string — questionCustomAnswer
  ///
  /// In en, this message translates to:
  /// **'Custom answer'**
  String get questionCustomAnswer;

  /// CodeWalk UI string — questionSubmitAnswers
  ///
  /// In en, this message translates to:
  /// **'Submit Answers'**
  String get questionSubmitAnswers;

  /// CodeWalk UI string — questionReviewAnswers
  ///
  /// In en, this message translates to:
  /// **'Review Answers'**
  String get questionReviewAnswers;

  /// CodeWalk UI string — permissionRequestTitle
  ///
  /// In en, this message translates to:
  /// **'Permission request: {permission}'**
  String permissionRequestTitle(String permission);

  /// CodeWalk UI string — sessionTitleCannotBeEmpty
  ///
  /// In en, this message translates to:
  /// **'Title cannot be empty'**
  String get sessionTitleCannotBeEmpty;

  /// CodeWalk UI string — filesFailedToLoad
  ///
  /// In en, this message translates to:
  /// **'Failed to load files'**
  String get filesFailedToLoad;

  /// CodeWalk UI string — filesFailedToSearch
  ///
  /// In en, this message translates to:
  /// **'Failed to search files'**
  String get filesFailedToSearch;

  /// CodeWalk UI string — filesNoOpenFilesHint
  ///
  /// In en, this message translates to:
  /// **'No open files yet. Type to search.'**
  String get filesNoOpenFilesHint;

  /// CodeWalk UI string — filesNoContentMatches
  ///
  /// In en, this message translates to:
  /// **'No content matches found'**
  String get filesNoContentMatches;

  /// CodeWalk UI string — filesOpenFilesCount
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 open file} other{{count} open files}}'**
  String filesOpenFilesCount(int count);

  /// CodeWalk UI string — filesLinesSelectedCount
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 line selected} other{{count} lines selected}}'**
  String filesLinesSelectedCount(int count);

  /// CodeWalk UI string — filesDraftTooLargeToSave
  ///
  /// In en, this message translates to:
  /// **'Draft is too large to save from the editor.'**
  String get filesDraftTooLargeToSave;

  /// CodeWalk UI string — filesSaveChangesBeforeClose
  ///
  /// In en, this message translates to:
  /// **'Save changes before closing this file.'**
  String get filesSaveChangesBeforeClose;

  /// CodeWalk UI string — filesSaveChangesBeforePathChange
  ///
  /// In en, this message translates to:
  /// **'Save changes before changing this path.'**
  String get filesSaveChangesBeforePathChange;

  /// CodeWalk UI string — filesWaitForSaveBeforePathChange
  ///
  /// In en, this message translates to:
  /// **'Wait for the file save to finish before changing this path.'**
  String get filesWaitForSaveBeforePathChange;

  /// CodeWalk UI string — filesWaitForFileOperation
  ///
  /// In en, this message translates to:
  /// **'Wait for the file operation to finish.'**
  String get filesWaitForFileOperation;

  /// CodeWalk UI string — filesLargeFileReadOnly
  ///
  /// In en, this message translates to:
  /// **'Large files open read-only to keep editing responsive.'**
  String get filesLargeFileReadOnly;

  /// CodeWalk UI string — filesCheckingWriteSupport
  ///
  /// In en, this message translates to:
  /// **'Checking file write support...'**
  String get filesCheckingWriteSupport;

  /// CodeWalk UI string — filesActiveProjectRequired
  ///
  /// In en, this message translates to:
  /// **'File operations require an active project directory.'**
  String get filesActiveProjectRequired;

  /// CodeWalk UI string — filesReloadSkippedUnsavedChanges
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes; reload skipped.'**
  String get filesReloadSkippedUnsavedChanges;

  /// CodeWalk UI string — filesFailedToLoadContent
  ///
  /// In en, this message translates to:
  /// **'Failed to load file content'**
  String get filesFailedToLoadContent;

  /// CodeWalk UI string — filesFileSaved
  ///
  /// In en, this message translates to:
  /// **'File saved.'**
  String get filesFileSaved;

  /// CodeWalk UI string — filesParentNotDirectory
  ///
  /// In en, this message translates to:
  /// **'Parent is not a directory.'**
  String get filesParentNotDirectory;

  /// CodeWalk UI string — filesMalformedResponse
  ///
  /// In en, this message translates to:
  /// **'File operation returned an invalid response.'**
  String get filesMalformedResponse;

  /// CodeWalk UI string — filesShellCommandDidNotComplete
  ///
  /// In en, this message translates to:
  /// **'File operation shell command did not complete.'**
  String get filesShellCommandDidNotComplete;

  /// CodeWalk UI string — filesShellCommandNoResult
  ///
  /// In en, this message translates to:
  /// **'File operation shell command returned no result.'**
  String get filesShellCommandNoResult;

  /// CodeWalk UI string — filesShellCommandTruncated
  ///
  /// In en, this message translates to:
  /// **'File operation shell command was truncated by the server.'**
  String get filesShellCommandTruncated;

  /// CodeWalk UI string — filesShellCommandSyntaxError
  ///
  /// In en, this message translates to:
  /// **'File operation shell command failed with a syntax error.'**
  String get filesShellCommandSyntaxError;

  /// CodeWalk UI string — filesShellUtilityNotFound
  ///
  /// In en, this message translates to:
  /// **'A required shell utility was not found.'**
  String get filesShellUtilityNotFound;

  /// CodeWalk UI string — filesShellCommandFailed
  ///
  /// In en, this message translates to:
  /// **'File operation shell command failed before returning a result.'**
  String get filesShellCommandFailed;

  /// CodeWalk UI string — attachmentSaveTitle
  ///
  /// In en, this message translates to:
  /// **'Save attachment'**
  String get attachmentSaveTitle;

  /// CodeWalk UI string — attachmentBrowserSandboxLocalFile
  ///
  /// In en, this message translates to:
  /// **'Browser sandbox prevents opening local file:// attachments directly.'**
  String get attachmentBrowserSandboxLocalFile;

  /// CodeWalk UI string — attachmentLocalPathBrowserBlocked
  ///
  /// In en, this message translates to:
  /// **'This attachment points to a local path that cannot be opened from the browser.'**
  String get attachmentLocalPathBrowserBlocked;

  /// CodeWalk UI string — terminalConnectedTo
  ///
  /// In en, this message translates to:
  /// **'Connected to {serverName} in {directory}'**
  String terminalConnectedTo(String directory, String serverName);

  /// CodeWalk UI string — terminalTransportUnavailable
  ///
  /// In en, this message translates to:
  /// **'Terminal transport is unavailable.'**
  String get terminalTransportUnavailable;

  /// CodeWalk UI string — chatSlashCommandNew
  ///
  /// In en, this message translates to:
  /// **'Create a new chat session'**
  String get chatSlashCommandNew;

  /// CodeWalk UI string — chatSlashCommandModels
  ///
  /// In en, this message translates to:
  /// **'Open model selector'**
  String get chatSlashCommandModels;

  /// CodeWalk UI string — chatSlashCommandSessions
  ///
  /// In en, this message translates to:
  /// **'Open conversations list'**
  String get chatSlashCommandSessions;

  /// CodeWalk UI string — chatSlashCommandAgent
  ///
  /// In en, this message translates to:
  /// **'Open agent selector'**
  String get chatSlashCommandAgent;

  /// CodeWalk UI string — chatSlashCommandOpen
  ///
  /// In en, this message translates to:
  /// **'File open quick action'**
  String get chatSlashCommandOpen;

  /// CodeWalk UI string — chatSlashCommandHelp
  ///
  /// In en, this message translates to:
  /// **'Show command help'**
  String get chatSlashCommandHelp;

  /// CodeWalk UI string — chatSlashCommandCompact
  ///
  /// In en, this message translates to:
  /// **'Compact current session context'**
  String get chatSlashCommandCompact;

  /// CodeWalk UI string — chatSlashCommandThinking
  ///
  /// In en, this message translates to:
  /// **'Toggle thinking bubbles'**
  String get chatSlashCommandThinking;

  /// CodeWalk UI string — chatSlashCommandUndo
  ///
  /// In en, this message translates to:
  /// **'Undo the last visible user turn'**
  String get chatSlashCommandUndo;

  /// CodeWalk UI string — chatSlashCommandRedo
  ///
  /// In en, this message translates to:
  /// **'Redo the last undone turn'**
  String get chatSlashCommandRedo;

  /// CodeWalk UI string — chatSessionSubConversationCount
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 sub-conversation} other{{count} sub-conversations}}'**
  String chatSessionSubConversationCount(int count);

  /// CodeWalk UI string — chatMessageWeeksAgo
  ///
  /// In en, this message translates to:
  /// **'{count}w ago'**
  String chatMessageWeeksAgo(int count);

  /// CodeWalk UI string — chatMessageShortDate
  ///
  /// In en, this message translates to:
  /// **'{month}/{day}'**
  String chatMessageShortDate(int day, int month);

  /// CodeWalk UI string — chatProviderErrorLoadSessionStatus
  ///
  /// In en, this message translates to:
  /// **'Failed to load session status'**
  String get chatProviderErrorLoadSessionStatus;

  /// CodeWalk UI string — chatProviderErrorLoadSessionDetails
  ///
  /// In en, this message translates to:
  /// **'Some session details could not be loaded'**
  String get chatProviderErrorLoadSessionDetails;

  /// CodeWalk UI string — chatProviderErrorLoadSessionList
  ///
  /// In en, this message translates to:
  /// **'Failed to load session list: {error}'**
  String chatProviderErrorLoadSessionList(String error);

  /// CodeWalk UI string — chatProviderErrorCreateSession
  ///
  /// In en, this message translates to:
  /// **'Failed to create session'**
  String get chatProviderErrorCreateSession;

  /// CodeWalk UI string — chatProviderErrorSelectProviderModelBeforeSend
  ///
  /// In en, this message translates to:
  /// **'Select a connected provider or free OpenCode model before sending'**
  String get chatProviderErrorSelectProviderModelBeforeSend;

  /// CodeWalk UI string — chatProviderErrorStartMessageSend
  ///
  /// In en, this message translates to:
  /// **'Failed to start message send'**
  String get chatProviderErrorStartMessageSend;

  /// CodeWalk UI string — chatProviderErrorStopUnavailable
  ///
  /// In en, this message translates to:
  /// **'Stop is unavailable for the current session'**
  String get chatProviderErrorStopUnavailable;

  /// CodeWalk UI string — chatProviderErrorWaitForResponseFinish
  ///
  /// In en, this message translates to:
  /// **'Wait for the current response to finish before compacting'**
  String get chatProviderErrorWaitForResponseFinish;

  /// CodeWalk UI string — chatProviderErrorCompactUnavailable
  ///
  /// In en, this message translates to:
  /// **'Compact context is unavailable for the current session'**
  String get chatProviderErrorCompactUnavailable;

  /// CodeWalk UI string — chatProviderErrorSelectModelBeforeCompact
  ///
  /// In en, this message translates to:
  /// **'Select a model before compacting context'**
  String get chatProviderErrorSelectModelBeforeCompact;

  /// CodeWalk UI string — chatProviderErrorCompactSessionContext
  ///
  /// In en, this message translates to:
  /// **'Failed to compact session context'**
  String get chatProviderErrorCompactSessionContext;

  /// CodeWalk UI string — chatProviderErrorNetwork
  ///
  /// In en, this message translates to:
  /// **'Network connection failed. Please check network settings'**
  String get chatProviderErrorNetwork;

  /// CodeWalk UI string — chatProviderErrorServer
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again later'**
  String get chatProviderErrorServer;

  /// CodeWalk UI string — chatProviderErrorNotFound
  ///
  /// In en, this message translates to:
  /// **'Resource not found'**
  String get chatProviderErrorNotFound;

  /// CodeWalk UI string — chatProviderErrorInvalidInput
  ///
  /// In en, this message translates to:
  /// **'Invalid input parameters'**
  String get chatProviderErrorInvalidInput;

  /// CodeWalk UI string — chatProviderErrorUnknown
  ///
  /// In en, this message translates to:
  /// **'Unknown error. Please try again later'**
  String get chatProviderErrorUnknown;

  /// CodeWalk UI string — chatProviderErrorSessionFallback
  ///
  /// In en, this message translates to:
  /// **'Session error'**
  String get chatProviderErrorSessionFallback;

  /// CodeWalk UI string — projectProviderErrorNoProjectContext
  ///
  /// In en, this message translates to:
  /// **'No project context available from server'**
  String get projectProviderErrorNoProjectContext;

  /// CodeWalk UI string — projectProviderErrorInitializeFailed
  ///
  /// In en, this message translates to:
  /// **'Failed to initialize project context: {error}'**
  String projectProviderErrorInitializeFailed(String error);

  /// CodeWalk UI string — projectProviderErrorSwitchProjectNotFound
  ///
  /// In en, this message translates to:
  /// **'Failed to switch project: project not found'**
  String get projectProviderErrorSwitchProjectNotFound;

  /// CodeWalk UI string — projectProviderErrorSwitchDirectoryEmpty
  ///
  /// In en, this message translates to:
  /// **'Failed to switch project: directory is empty'**
  String get projectProviderErrorSwitchDirectoryEmpty;

  /// CodeWalk UI string — projectProviderErrorAtLeastOneContext
  ///
  /// In en, this message translates to:
  /// **'At least one context must remain open'**
  String get projectProviderErrorAtLeastOneContext;

  /// CodeWalk UI string — projectProviderErrorReopenProjectNotFound
  ///
  /// In en, this message translates to:
  /// **'Failed to reopen project: project not found'**
  String get projectProviderErrorReopenProjectNotFound;

  /// CodeWalk UI string — projectProviderErrorOnlyClosedArchivable
  ///
  /// In en, this message translates to:
  /// **'Only closed projects can be archived'**
  String get projectProviderErrorOnlyClosedArchivable;

  /// CodeWalk UI string — projectProviderErrorArchiveProjectNotFound
  ///
  /// In en, this message translates to:
  /// **'Failed to archive project: project not found'**
  String get projectProviderErrorArchiveProjectNotFound;

  /// CodeWalk UI string — projectProviderErrorArchiveProjectPathInvalid
  ///
  /// In en, this message translates to:
  /// **'Failed to archive project: project path is invalid'**
  String get projectProviderErrorArchiveProjectPathInvalid;

  /// CodeWalk UI string — projectProviderErrorLoadWorkspaces
  ///
  /// In en, this message translates to:
  /// **'Failed to load workspaces: {error}'**
  String projectProviderErrorLoadWorkspaces(String error);

  /// CodeWalk UI string — projectProviderErrorWorkspaceNameEmpty
  ///
  /// In en, this message translates to:
  /// **'Workspace name cannot be empty'**
  String get projectProviderErrorWorkspaceNameEmpty;

  /// CodeWalk UI string — projectProviderErrorCreateWorkspace
  ///
  /// In en, this message translates to:
  /// **'Failed to create workspace: {error}'**
  String projectProviderErrorCreateWorkspace(String error);

  /// CodeWalk UI string — projectProviderErrorResetWorkspace
  ///
  /// In en, this message translates to:
  /// **'Failed to reset workspace: {error}'**
  String projectProviderErrorResetWorkspace(String error);

  /// CodeWalk UI string — projectProviderErrorDeleteWorkspace
  ///
  /// In en, this message translates to:
  /// **'Failed to delete workspace: {error}'**
  String projectProviderErrorDeleteWorkspace(String error);

  /// CodeWalk UI string — projectProviderErrorDirectoryEmpty
  ///
  /// In en, this message translates to:
  /// **'Directory cannot be empty'**
  String get projectProviderErrorDirectoryEmpty;

  /// CodeWalk UI string — projectProviderErrorListDirectories
  ///
  /// In en, this message translates to:
  /// **'Failed to list directories: {error}'**
  String projectProviderErrorListDirectories(String error);

  /// CodeWalk UI string — projectProviderErrorValidateDirectory
  ///
  /// In en, this message translates to:
  /// **'Failed to validate directory: {error}'**
  String projectProviderErrorValidateDirectory(String error);

  /// CodeWalk UI string — projectProviderErrorPathEmpty
  ///
  /// In en, this message translates to:
  /// **'Path cannot be empty'**
  String get projectProviderErrorPathEmpty;

  /// CodeWalk UI string — projectProviderErrorListFiles
  ///
  /// In en, this message translates to:
  /// **'Failed to list files: {error}'**
  String projectProviderErrorListFiles(String error);

  /// CodeWalk UI string — projectProviderErrorSearchFiles
  ///
  /// In en, this message translates to:
  /// **'Failed to search files: {error}'**
  String projectProviderErrorSearchFiles(String error);

  /// CodeWalk UI string — projectProviderErrorContentSearchUnavailable
  ///
  /// In en, this message translates to:
  /// **'Content search not available: {error}'**
  String projectProviderErrorContentSearchUnavailable(String error);

  /// CodeWalk UI string — projectProviderErrorSearchSymbols
  ///
  /// In en, this message translates to:
  /// **'Failed to search symbols: {error}'**
  String projectProviderErrorSearchSymbols(String error);

  /// CodeWalk UI string — projectProviderErrorReadFile
  ///
  /// In en, this message translates to:
  /// **'Failed to read file: {error}'**
  String projectProviderErrorReadFile(String error);

  /// CodeWalk UI string — projectProviderErrorLoadProjectList
  ///
  /// In en, this message translates to:
  /// **'Failed to load project list: {error}'**
  String projectProviderErrorLoadProjectList(String error);

  /// CodeWalk UI string — workspaceProjectRemovedFromHistory
  ///
  /// In en, this message translates to:
  /// **'Project removed from history'**
  String get workspaceProjectRemovedFromHistory;

  /// CodeWalk UI string — workspaceProjectContextOpened
  ///
  /// In en, this message translates to:
  /// **'Project context opened: {directory}'**
  String workspaceProjectContextOpened(String directory);

  /// CodeWalk UI string — workspaceFailedToOpenProjectContext
  ///
  /// In en, this message translates to:
  /// **'Failed to open project context: {directory}'**
  String workspaceFailedToOpenProjectContext(String directory);

  /// CodeWalk UI string — chatAbortNotice
  ///
  /// In en, this message translates to:
  /// **'What you want to do different?'**
  String get chatAbortNotice;

  /// CodeWalk UI string — sessionTitleToday
  ///
  /// In en, this message translates to:
  /// **'Today {time} ({date})'**
  String sessionTitleToday(String date, String time);

  /// CodeWalk UI string — sessionTitleYesterday
  ///
  /// In en, this message translates to:
  /// **'Yesterday {time} ({date})'**
  String sessionTitleYesterday(String date, String time);

  /// CodeWalk UI string — sessionTitleWeekday
  ///
  /// In en, this message translates to:
  /// **'{weekday} {time} ({date})'**
  String sessionTitleWeekday(String date, String time, String weekday);

  /// CodeWalk UI string — sessionTitleDateAndTime
  ///
  /// In en, this message translates to:
  /// **'{date} {time}'**
  String sessionTitleDateAndTime(String date, String time);

  /// CodeWalk UI string — sessionWeekdayMon
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get sessionWeekdayMon;

  /// CodeWalk UI string — sessionWeekdayTue
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get sessionWeekdayTue;

  /// CodeWalk UI string — sessionWeekdayWed
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get sessionWeekdayWed;

  /// CodeWalk UI string — sessionWeekdayThu
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get sessionWeekdayThu;

  /// CodeWalk UI string — sessionWeekdayFri
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get sessionWeekdayFri;

  /// CodeWalk UI string — sessionWeekdaySat
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get sessionWeekdaySat;

  /// CodeWalk UI string — sessionWeekdaySun
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get sessionWeekdaySun;

  /// CodeWalk UI string — forwardTimeNow
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get forwardTimeNow;

  /// CodeWalk UI string — forwardTimeMinutes
  ///
  /// In en, this message translates to:
  /// **'{count}m'**
  String forwardTimeMinutes(int count);

  /// CodeWalk UI string — forwardTimeHours
  ///
  /// In en, this message translates to:
  /// **'{count}h'**
  String forwardTimeHours(int count);

  /// CodeWalk UI string — forwardTimeDays
  ///
  /// In en, this message translates to:
  /// **'{count}d'**
  String forwardTimeDays(int count);

  /// CodeWalk UI string — forwardTimeWeeks
  ///
  /// In en, this message translates to:
  /// **'{count}w'**
  String forwardTimeWeeks(int count);

  /// CodeWalk UI string — settingsBehaviorConfigFieldDefaultModel
  ///
  /// In en, this message translates to:
  /// **'default model'**
  String get settingsBehaviorConfigFieldDefaultModel;

  /// CodeWalk UI string — settingsBehaviorConfigFieldDefaultAgent
  ///
  /// In en, this message translates to:
  /// **'default agent'**
  String get settingsBehaviorConfigFieldDefaultAgent;

  /// CodeWalk UI string — settingsBehaviorConfigFieldSmallModel
  ///
  /// In en, this message translates to:
  /// **'small model'**
  String get settingsBehaviorConfigFieldSmallModel;

  /// CodeWalk UI string — settingsBehaviorConfigFieldAutoUpdateMode
  ///
  /// In en, this message translates to:
  /// **'auto-update mode'**
  String get settingsBehaviorConfigFieldAutoUpdateMode;

  /// CodeWalk UI string — settingsBehaviorConfigFieldSnapshotSetting
  ///
  /// In en, this message translates to:
  /// **'snapshot setting'**
  String get settingsBehaviorConfigFieldSnapshotSetting;

  /// CodeWalk UI string — settingsBehaviorConfigFieldConversationUsername
  ///
  /// In en, this message translates to:
  /// **'conversation username'**
  String get settingsBehaviorConfigFieldConversationUsername;

  /// CodeWalk UI string — settingsBehaviorConfigFieldSharingDefault
  ///
  /// In en, this message translates to:
  /// **'sharing default'**
  String get settingsBehaviorConfigFieldSharingDefault;

  /// CodeWalk UI string — speechMicNoInputDevice
  ///
  /// In en, this message translates to:
  /// **'No microphone input device is available.'**
  String get speechMicNoInputDevice;

  /// CodeWalk UI string — speechLinuxAudioServerUnavailable
  ///
  /// In en, this message translates to:
  /// **'A microphone tool was found, but the Linux audio server could not be reached. Make sure PipeWire or PulseAudio is running.'**
  String get speechLinuxAudioServerUnavailable;

  /// CodeWalk UI string — speechLinuxMicBackendMissing
  ///
  /// In en, this message translates to:
  /// **'No microphone recording tool was found on this system. Install PulseAudio tools (parecord), PipeWire tools (pw-record) or ALSA utilities (arecord), then try again.'**
  String get speechLinuxMicBackendMissing;

  /// CodeWalk UI string — speechMicDeviceBusy
  ///
  /// In en, this message translates to:
  /// **'The default microphone is currently in use by another app.'**
  String get speechMicDeviceBusy;

  /// CodeWalk UI string — speechMicUnsupportedFormat
  ///
  /// In en, this message translates to:
  /// **'The default microphone format is not supported.'**
  String get speechMicUnsupportedFormat;

  /// CodeWalk UI string — speechMicSpeechPrivacy
  ///
  /// In en, this message translates to:
  /// **'Windows speech services may be disabled (speech privacy, online speech recognition, or language packs).'**
  String get speechMicSpeechPrivacy;

  /// CodeWalk UI string — speechMicBackendUnavailable
  ///
  /// In en, this message translates to:
  /// **'The Windows microphone backend is not available in this build.'**
  String get speechMicBackendUnavailable;

  /// CodeWalk UI string — speechEngineFallbackNotice
  ///
  /// In en, this message translates to:
  /// **'Selected STT engine unavailable ({reason}). Using {fallback} instead.'**
  String speechEngineFallbackNotice(String fallback, String reason);

  /// CodeWalk UI string — oauthFlowSecureStorageUnavailable
  ///
  /// In en, this message translates to:
  /// **'Secure credential storage is unavailable for OAuth.'**
  String get oauthFlowSecureStorageUnavailable;

  /// CodeWalk UI string — oauthFlowUnexpectedError
  ///
  /// In en, this message translates to:
  /// **'OAuth flow failed unexpectedly. Please try again.'**
  String get oauthFlowUnexpectedError;

  /// CodeWalk UI string — oauthFlowNoEndpointsDiscovered
  ///
  /// In en, this message translates to:
  /// **'No OAuth endpoints discovered. Enable Managed OAuth in Cloudflare Dashboard → Access → Applications → [this app].'**
  String get oauthFlowNoEndpointsDiscovered;

  /// CodeWalk UI string — oauthFlowTokenResponseMissingAccessToken
  ///
  /// In en, this message translates to:
  /// **'OAuth token response did not include an access token.'**
  String get oauthFlowTokenResponseMissingAccessToken;

  /// CodeWalk UI string — oauthFlowProfileChanged
  ///
  /// In en, this message translates to:
  /// **'The server profile changed before OAuth could finish.'**
  String get oauthFlowProfileChanged;

  /// CodeWalk UI string — oauthFlowMetadataMissingEndpoints
  ///
  /// In en, this message translates to:
  /// **'OAuth metadata is missing authorization/token endpoints.'**
  String get oauthFlowMetadataMissingEndpoints;

  /// CodeWalk UI string — oauthFlowCallbackNotCompleted
  ///
  /// In en, this message translates to:
  /// **'Authorization callback was not completed'**
  String get oauthFlowCallbackNotCompleted;

  /// CodeWalk UI string — oauthFlowProviderDeclined
  ///
  /// In en, this message translates to:
  /// **'The authorization server declined the OAuth request. Please try again.'**
  String get oauthFlowProviderDeclined;

  /// CodeWalk UI string — oauthFlowCallbackValidationFailed
  ///
  /// In en, this message translates to:
  /// **'OAuth callback validation failed. Please try again.'**
  String get oauthFlowCallbackValidationFailed;

  /// CodeWalk UI string — oauthFlowCallbackServerStartFailed
  ///
  /// In en, this message translates to:
  /// **'Local OAuth callback server failed to start.'**
  String get oauthFlowCallbackServerStartFailed;

  /// CodeWalk UI string — oauthFlowSignInCanceled
  ///
  /// In en, this message translates to:
  /// **'OAuth sign-in was canceled.'**
  String get oauthFlowSignInCanceled;

  /// CodeWalk UI string — oauthFlowBrowserOpenFailed
  ///
  /// In en, this message translates to:
  /// **'Could not open the system browser for OAuth sign-in.'**
  String get oauthFlowBrowserOpenFailed;

  /// CodeWalk UI string — oauthFlowCallbackTimeout
  ///
  /// In en, this message translates to:
  /// **'No authorization callback reached the app within 5 minutes. The browser was expected to redirect to the local callback address after consent. If the browser showed a connection error instead, this device or network blocks loopback redirects.'**
  String get oauthFlowCallbackTimeout;

  /// CodeWalk UI string — oauthFlowTokenExchangeTransientFailure
  ///
  /// In en, this message translates to:
  /// **'Token exchange failed after {maxAttempts} attempts because of a temporary network problem. Please try again.'**
  String oauthFlowTokenExchangeTransientFailure(int maxAttempts);

  /// CodeWalk UI string — oauthFlowTokenExchangeHttpFailure
  ///
  /// In en, this message translates to:
  /// **'Token exchange failed (HTTP {statusCode}). Please try again.'**
  String oauthFlowTokenExchangeHttpFailure(int statusCode);

  /// CodeWalk UI string — oauthFlowTokenExchangeUnexpectedFailure
  ///
  /// In en, this message translates to:
  /// **'Token exchange failed unexpectedly. Please try again.'**
  String get oauthFlowTokenExchangeUnexpectedFailure;

  /// CodeWalk UI string — oauthFlowTokenExchangeIncomplete
  ///
  /// In en, this message translates to:
  /// **'Token exchange did not complete after the authorization code was sent. Please start OAuth sign-in again.'**
  String get oauthFlowTokenExchangeIncomplete;

  /// CodeWalk UI string — speechReadAloudFailed
  ///
  /// In en, this message translates to:
  /// **'Text-to-speech failed.'**
  String get speechReadAloudFailed;

  /// CodeWalk UI string — speechReadAloudNoText
  ///
  /// In en, this message translates to:
  /// **'There is no text to read aloud.'**
  String get speechReadAloudNoText;

  /// CodeWalk UI string — speechEdgeTextTooLong
  ///
  /// In en, this message translates to:
  /// **'Microsoft Edge Speech can read up to 4096 bytes at a time.'**
  String get speechEdgeTextTooLong;

  /// CodeWalk UI string — speechEdgeMalformedAudio
  ///
  /// In en, this message translates to:
  /// **'Microsoft Edge Speech returned malformed audio data.'**
  String get speechEdgeMalformedAudio;

  /// CodeWalk UI string — speechEdgeUnsupportedAudio
  ///
  /// In en, this message translates to:
  /// **'Microsoft Edge Speech returned unsupported audio data.'**
  String get speechEdgeUnsupportedAudio;

  /// CodeWalk UI string — speechEdgeUnsupportedFrame
  ///
  /// In en, this message translates to:
  /// **'Microsoft Edge Speech returned an unsupported websocket frame.'**
  String get speechEdgeUnsupportedFrame;

  /// CodeWalk UI string — speechEdgeSynthesisInterrupted
  ///
  /// In en, this message translates to:
  /// **'Microsoft Edge Speech ended before synthesis completed.'**
  String get speechEdgeSynthesisInterrupted;

  /// CodeWalk UI string — speechEdgeEmptyAudio
  ///
  /// In en, this message translates to:
  /// **'Microsoft Edge Speech returned an empty audio response.'**
  String get speechEdgeEmptyAudio;

  /// CodeWalk UI string — speechEdgeTimedOut
  ///
  /// In en, this message translates to:
  /// **'Microsoft Edge Speech timed out.'**
  String get speechEdgeTimedOut;

  /// CodeWalk UI string — speechEdgeUnreachable
  ///
  /// In en, this message translates to:
  /// **'Microsoft Edge Speech could not be reached.'**
  String get speechEdgeUnreachable;

  /// CodeWalk UI string — speechApiKeyMissing
  ///
  /// In en, this message translates to:
  /// **'Add an API key in Settings > Speech to use this TTS provider.'**
  String get speechApiKeyMissing;

  /// CodeWalk UI string — speechProviderEmptyAudio
  ///
  /// In en, this message translates to:
  /// **'The TTS provider returned an empty audio response.'**
  String get speechProviderEmptyAudio;

  /// CodeWalk UI string — speechProviderRequestRejected
  ///
  /// In en, this message translates to:
  /// **'The TTS provider rejected the speech request.'**
  String get speechProviderRequestRejected;

  /// CodeWalk UI string — speechApiKeyRejected
  ///
  /// In en, this message translates to:
  /// **'The TTS API key was rejected by the provider.'**
  String get speechApiKeyRejected;

  /// CodeWalk UI string — speechProviderQuotaRateLimit
  ///
  /// In en, this message translates to:
  /// **'The TTS provider reported a quota or rate limit.'**
  String get speechProviderQuotaRateLimit;

  /// CodeWalk UI string — speechReadAloudNoVoice
  ///
  /// In en, this message translates to:
  /// **'Select a voice for this TTS provider.'**
  String get speechReadAloudNoVoice;

  /// CodeWalk UI string — speechProviderTextTooLong
  ///
  /// In en, this message translates to:
  /// **'The text is too long for this TTS model.'**
  String get speechProviderTextTooLong;

  /// CodeWalk UI string — speechProviderInvalidAudio
  ///
  /// In en, this message translates to:
  /// **'The TTS provider returned unrecognized audio.'**
  String get speechProviderInvalidAudio;

  /// CodeWalk UI string — speechNimBaseUrlRequired
  ///
  /// In en, this message translates to:
  /// **'Enter the NVIDIA NIM deployment base URL in Settings > Speech.'**
  String get speechNimBaseUrlRequired;

  /// CodeWalk UI string — speechProviderTemporarilyUnavailable
  ///
  /// In en, this message translates to:
  /// **'The TTS provider is temporarily unavailable.'**
  String get speechProviderTemporarilyUnavailable;

  /// CodeWalk UI string — speechProviderUnreachable
  ///
  /// In en, this message translates to:
  /// **'The TTS provider could not be reached.'**
  String get speechProviderUnreachable;

  /// CodeWalk UI string — appProviderErrorFailedToStartProcess
  ///
  /// In en, this message translates to:
  /// **'Failed to start {tool} process.'**
  String appProviderErrorFailedToStartProcess(String tool);

  /// CodeWalk UI string — appProviderErrorToolNotAvailable
  ///
  /// In en, this message translates to:
  /// **'{tool} is not available. Install {runtime} first.'**
  String appProviderErrorToolNotAvailable(String runtime, String tool);

  /// CodeWalk UI string — appProviderErrorToolInstallFailed
  ///
  /// In en, this message translates to:
  /// **'{tool} install failed with exit code {exitCode}.'**
  String appProviderErrorToolInstallFailed(int exitCode, String tool);

  /// CodeWalk UI string — appProviderErrorBunBootstrapFailed
  ///
  /// In en, this message translates to:
  /// **'Bun bootstrap failed with exit code {exitCode}.'**
  String appProviderErrorBunBootstrapFailed(int exitCode);

  /// CodeWalk UI string — appProviderErrorInstalledButNotFoundInPath
  ///
  /// In en, this message translates to:
  /// **'OpenCode installation finished but command was not found in PATH.'**
  String get appProviderErrorInstalledButNotFoundInPath;

  /// CodeWalk UI string — appProviderErrorInstalledButPathNotResolved
  ///
  /// In en, this message translates to:
  /// **'OpenCode installation finished but command path could not be resolved.'**
  String get appProviderErrorInstalledButPathNotResolved;

  /// CodeWalk UI string — appProviderErrorConfiguredCommandNotFound
  ///
  /// In en, this message translates to:
  /// **'Configured command was not found and {tool} is not in PATH.'**
  String appProviderErrorConfiguredCommandNotFound(String tool);

  /// CodeWalk UI string — appProviderErrorConfiguredCommandPathMissing
  ///
  /// In en, this message translates to:
  /// **'Configured command path does not exist.'**
  String get appProviderErrorConfiguredCommandPathMissing;

  /// CodeWalk UI string — appProviderErrorConfiguredCommandVersionCheckFailed
  ///
  /// In en, this message translates to:
  /// **'Configured command exists but version check failed.'**
  String get appProviderErrorConfiguredCommandVersionCheckFailed;

  /// CodeWalk UI string — appProviderErrorConfiguredCommandExecutionFailed
  ///
  /// In en, this message translates to:
  /// **'Configured command could not be executed.'**
  String get appProviderErrorConfiguredCommandExecutionFailed;

  /// CodeWalk UI string — appProviderWslCheckWindowsOnly
  ///
  /// In en, this message translates to:
  /// **'WSL check only applies to Windows.'**
  String get appProviderWslCheckWindowsOnly;

  /// CodeWalk UI string — appProviderDesktopBuildRequired
  ///
  /// In en, this message translates to:
  /// **'Use a desktop build to configure a managed local server.'**
  String get appProviderDesktopBuildRequired;

  /// CodeWalk UI string — appProviderKnownInstallationDirectoryDetected
  ///
  /// In en, this message translates to:
  /// **'Detected from a known installation directory.'**
  String get appProviderKnownInstallationDirectoryDetected;

  /// CodeWalk UI string — appProviderKnownInstallationPathRefreshHint
  ///
  /// In en, this message translates to:
  /// **'Detected from a known installation directory. PATH may need refresh; reopen {appName} if a recent install is not detected yet.'**
  String appProviderKnownInstallationPathRefreshHint(String appName);

  /// CodeWalk UI string — appProviderErrorReleaseMetadataFetchFailed
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch latest release metadata from GitHub.'**
  String get appProviderErrorReleaseMetadataFetchFailed;

  /// CodeWalk UI string — appProviderErrorReleaseAssetListMissing
  ///
  /// In en, this message translates to:
  /// **'Latest release metadata did not include asset list.'**
  String get appProviderErrorReleaseAssetListMissing;

  /// CodeWalk UI string — appProviderErrorNoCompatibleAsset
  ///
  /// In en, this message translates to:
  /// **'No compatible OpenCode binary asset was found.'**
  String get appProviderErrorNoCompatibleAsset;

  /// CodeWalk UI string — appProviderErrorDownloadAssetFailed
  ///
  /// In en, this message translates to:
  /// **'Failed to download selected OpenCode asset.'**
  String get appProviderErrorDownloadAssetFailed;

  /// CodeWalk UI string — appProviderErrorChecksumVerificationFailed
  ///
  /// In en, this message translates to:
  /// **'Checksum verification failed for downloaded asset.'**
  String get appProviderErrorChecksumVerificationFailed;

  /// CodeWalk UI string — appProviderErrorExtractArchiveFailed
  ///
  /// In en, this message translates to:
  /// **'Failed to extract OpenCode binary archive.'**
  String get appProviderErrorExtractArchiveFailed;

  /// CodeWalk UI string — appProviderErrorExecutableNotFound
  ///
  /// In en, this message translates to:
  /// **'Could not find {tool} executable in extracted files.'**
  String appProviderErrorExecutableNotFound(String tool);

  /// CodeWalk UI string — chatNoResponseFromServer
  ///
  /// In en, this message translates to:
  /// **'No response from server. Please try again.'**
  String get chatNoResponseFromServer;

  /// CodeWalk UI string — chatNoResponseFromModel
  ///
  /// In en, this message translates to:
  /// **'No response from model. Please try again.'**
  String get chatNoResponseFromModel;

  /// CodeWalk UI string — speechJobCancelled
  ///
  /// In en, this message translates to:
  /// **'Speech job was cancelled.'**
  String get speechJobCancelled;

  /// CodeWalk UI string — speechEdgeCancelled
  ///
  /// In en, this message translates to:
  /// **'Microsoft Edge Speech was cancelled.'**
  String get speechEdgeCancelled;

  /// CodeWalk UI string — sessionAttentionKindActive
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get sessionAttentionKindActive;

  /// CodeWalk UI string — sessionAttentionKindReceiving
  ///
  /// In en, this message translates to:
  /// **'Receiving'**
  String get sessionAttentionKindReceiving;

  /// CodeWalk UI string — sessionAttentionKindDelayed
  ///
  /// In en, this message translates to:
  /// **'Delayed'**
  String get sessionAttentionKindDelayed;

  /// CodeWalk UI string — sessionAttentionKindCompleted
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get sessionAttentionKindCompleted;

  /// CodeWalk UI string — sessionAttentionKindPendingInteraction
  ///
  /// In en, this message translates to:
  /// **'Pending interaction'**
  String get sessionAttentionKindPendingInteraction;

  /// CodeWalk UI string — sessionAttentionKindError
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get sessionAttentionKindError;

  /// CodeWalk UI string — sessionAttentionPauseCellularDataSaver
  ///
  /// In en, this message translates to:
  /// **'Cellular data saver is active'**
  String get sessionAttentionPauseCellularDataSaver;

  /// CodeWalk UI string — sessionAttentionPauseOauthReopenRequired
  ///
  /// In en, this message translates to:
  /// **'OAuth sign-in required'**
  String get sessionAttentionPauseOauthReopenRequired;

  /// CodeWalk UI string — sessionAttentionPauseTailscaleReopenRequired
  ///
  /// In en, this message translates to:
  /// **'Tailscale connection required'**
  String get sessionAttentionPauseTailscaleReopenRequired;

  /// CodeWalk UI string — sessionAttentionPauseOffline
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get sessionAttentionPauseOffline;

  /// CodeWalk UI string — sessionAttentionPausePermissionRevoked
  ///
  /// In en, this message translates to:
  /// **'Permission revoked'**
  String get sessionAttentionPausePermissionRevoked;

  /// CodeWalk UI string — sessionAttentionPauseServiceStopped
  ///
  /// In en, this message translates to:
  /// **'Service stopped'**
  String get sessionAttentionPauseServiceStopped;

  /// CodeWalk UI string — sessionAttentionPauseHostUnavailable
  ///
  /// In en, this message translates to:
  /// **'Host unavailable'**
  String get sessionAttentionPauseHostUnavailable;

  /// CodeWalk UI string — errorRequestCancelled
  ///
  /// In en, this message translates to:
  /// **'Request cancelled'**
  String get errorRequestCancelled;

  /// CodeWalk UI string — errorUnknownNetworkError
  ///
  /// In en, this message translates to:
  /// **'Unknown network error: {error}'**
  String errorUnknownNetworkError(String error);

  /// CodeWalk UI string — errorCertificateError
  ///
  /// In en, this message translates to:
  /// **'Certificate error'**
  String get errorCertificateError;

  /// CodeWalk UI string — errorSessionBusy
  ///
  /// In en, this message translates to:
  /// **'Session is busy processing another request.'**
  String get errorSessionBusy;

  /// CodeWalk UI string — errorRunShellCommandFailed
  ///
  /// In en, this message translates to:
  /// **'Failed to run shell command'**
  String get errorRunShellCommandFailed;

  /// CodeWalk UI string — errorRunSlashCommandFailed
  ///
  /// In en, this message translates to:
  /// **'Failed to run slash command'**
  String get errorRunSlashCommandFailed;

  /// CodeWalk UI string — settingsBehaviorOpenCodeDefaultsLoadError
  ///
  /// In en, this message translates to:
  /// **'Could not load OpenCode-backed defaults from the active server.'**
  String get settingsBehaviorOpenCodeDefaultsLoadError;

  /// CodeWalk UI string — sessionTabIconRemoveFailed
  ///
  /// In en, this message translates to:
  /// **'Failed to remove local session tab icon data'**
  String get sessionTabIconRemoveFailed;

  /// CodeWalk UI string — forwardUntitled
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get forwardUntitled;

  /// CodeWalk UI string — setupDebugLinuxLogsPath
  ///
  /// In en, this message translates to:
  /// **'Linux logs: {path}'**
  String setupDebugLinuxLogsPath(String path);

  /// CodeWalk UI string — setupDebugRunOpenCodeCommand
  ///
  /// In en, this message translates to:
  /// **'Run OpenCode with: {command}'**
  String setupDebugRunOpenCodeCommand(String command);

  /// CodeWalk UI string — setupDebugServerHealthEndpoint
  ///
  /// In en, this message translates to:
  /// **'Server health: {endpoint}'**
  String setupDebugServerHealthEndpoint(String endpoint);

  /// CodeWalk UI string — setupDebugServerDocsEndpoint
  ///
  /// In en, this message translates to:
  /// **'Server docs: {endpoint}'**
  String setupDebugServerDocsEndpoint(String endpoint);

  /// CodeWalk UI string — logsEntryError
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get logsEntryError;

  /// CodeWalk UI string — logsEntryStack
  ///
  /// In en, this message translates to:
  /// **'Stack'**
  String get logsEntryStack;

  /// CodeWalk UI string — setupDebugSourceDiagnostics
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get setupDebugSourceDiagnostics;

  /// CodeWalk UI string — setupDebugSourceUseExisting
  ///
  /// In en, this message translates to:
  /// **'Use Existing'**
  String get setupDebugSourceUseExisting;

  /// CodeWalk UI string — setupDebugSourceLocalServer
  ///
  /// In en, this message translates to:
  /// **'Local Server'**
  String get setupDebugSourceLocalServer;

  /// CodeWalk UI string — setupDebugSourceOnboarding
  ///
  /// In en, this message translates to:
  /// **'Onboarding'**
  String get setupDebugSourceOnboarding;

  /// CodeWalk UI string — setupDebugSourceManualConnection
  ///
  /// In en, this message translates to:
  /// **'Manual connection'**
  String get setupDebugSourceManualConnection;

  /// CodeWalk UI string — setupDebugMessageDiagnosticsResult
  ///
  /// In en, this message translates to:
  /// **'{availability} on {platform}. {recommendation}'**
  String setupDebugMessageDiagnosticsResult(
    String availability,
    String platform,
    String recommendation,
  );

  /// CodeWalk UI string — setupDebugMessageDetectAttempt
  ///
  /// In en, this message translates to:
  /// **'Trying to detect an existing OpenCode command from the current environment.'**
  String get setupDebugMessageDetectAttempt;

  /// CodeWalk UI string — setupDebugMessageInstallStarted
  ///
  /// In en, this message translates to:
  /// **'Started OpenCode installation from CodeWalk.'**
  String get setupDebugMessageInstallStarted;

  /// CodeWalk UI string — setupDebugMessageStartLocalServer
  ///
  /// In en, this message translates to:
  /// **'Starting managed OpenCode server at {url}.'**
  String setupDebugMessageStartLocalServer(String url);

  /// CodeWalk UI string — setupDebugMessageHealthyRunning
  ///
  /// In en, this message translates to:
  /// **'Managed OpenCode server is healthy and running at {url}.'**
  String setupDebugMessageHealthyRunning(String url);

  /// CodeWalk UI string — setupDebugMessageStoppingLocalServer
  ///
  /// In en, this message translates to:
  /// **'Stopping managed OpenCode server.'**
  String get setupDebugMessageStoppingLocalServer;

  /// CodeWalk UI string — setupDebugMessageStoppedCleanly
  ///
  /// In en, this message translates to:
  /// **'Managed OpenCode server stopped cleanly.'**
  String get setupDebugMessageStoppedCleanly;

  /// CodeWalk UI string — setupDebugMessageExitedAfterRequestedStop
  ///
  /// In en, this message translates to:
  /// **'Managed OpenCode server exited after a requested stop.'**
  String get setupDebugMessageExitedAfterRequestedStop;

  /// CodeWalk UI string — setupDebugMessageOnboardingConnectExisting
  ///
  /// In en, this message translates to:
  /// **'User chose to connect to an existing OpenCode server.'**
  String get setupDebugMessageOnboardingConnectExisting;

  /// CodeWalk UI string — setupDebugMessageOnboardingGuidedPath
  ///
  /// In en, this message translates to:
  /// **'User opened the guided OpenCode setup path.'**
  String get setupDebugMessageOnboardingGuidedPath;

  /// CodeWalk UI string — setupDebugMessageOnboardingManagedLocal
  ///
  /// In en, this message translates to:
  /// **'User opened managed local OpenCode setup.'**
  String get setupDebugMessageOnboardingManagedLocal;

  /// CodeWalk UI string — setupDebugMessageOnboardingOpenedServerSettings
  ///
  /// In en, this message translates to:
  /// **'User opened server settings after a failed health check.'**
  String get setupDebugMessageOnboardingOpenedServerSettings;

  /// CodeWalk UI string — setupDebugMessageOnboardingAddAnotherServer
  ///
  /// In en, this message translates to:
  /// **'User chose to add another server after a failed health check.'**
  String get setupDebugMessageOnboardingAddAnotherServer;

  /// CodeWalk UI string — setupDebugMessageTestingServerUrl
  ///
  /// In en, this message translates to:
  /// **'Testing OpenCode server URL {url} from onboarding.'**
  String setupDebugMessageTestingServerUrl(String url);

  /// CodeWalk UI string — chatProviderErrorSessionNotFound
  ///
  /// In en, this message translates to:
  /// **'Session not found'**
  String get chatProviderErrorSessionNotFound;

  /// CodeWalk UI string — chatProviderErrorInvalidMessageFormat
  ///
  /// In en, this message translates to:
  /// **'Invalid message format'**
  String get chatProviderErrorInvalidMessageFormat;

  /// CodeWalk UI string — chatProviderErrorNetworkShort
  ///
  /// In en, this message translates to:
  /// **'Network connection failed'**
  String get chatProviderErrorNetworkShort;

  /// CodeWalk UI string — chatProviderErrorUnknownShort
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get chatProviderErrorUnknownShort;

  /// CodeWalk UI string — terminalCreateFailed
  ///
  /// In en, this message translates to:
  /// **'Failed to create terminal session'**
  String get terminalCreateFailed;

  /// CodeWalk UI string — terminalEndpointUnavailable
  ///
  /// In en, this message translates to:
  /// **'Terminal endpoint is not available'**
  String get terminalEndpointUnavailable;

  /// CodeWalk UI string — terminalInvalidDirectory
  ///
  /// In en, this message translates to:
  /// **'Invalid terminal directory'**
  String get terminalInvalidDirectory;

  /// CodeWalk UI string — terminalWebsocketUnavailable
  ///
  /// In en, this message translates to:
  /// **'Terminal websocket is not available here.'**
  String get terminalWebsocketUnavailable;

  /// CodeWalk UI string — chatMessageToolChainCallsCompact
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 call} other{{count} calls}}'**
  String chatMessageToolChainCallsCompact(int count);

  /// CodeWalk UI string — errorConnectionTimeout
  ///
  /// In en, this message translates to:
  /// **'Connection timeout'**
  String get errorConnectionTimeout;

  /// CodeWalk UI string — errorClientError
  ///
  /// In en, this message translates to:
  /// **'Client error'**
  String get errorClientError;

  /// CodeWalk UI string — chatProviderErrorSendMessage
  ///
  /// In en, this message translates to:
  /// **'Failed to send message'**
  String get chatProviderErrorSendMessage;

  /// CodeWalk UI string — speechApiEngine
  ///
  /// In en, this message translates to:
  /// **'API'**
  String get speechApiEngine;

  /// CodeWalk UI string — speechApiEngineSubtitle
  ///
  /// In en, this message translates to:
  /// **'OpenAI, Groq, or a custom OpenAI-compatible endpoint.'**
  String get speechApiEngineSubtitle;

  /// CodeWalk UI string — speechApiProvider
  ///
  /// In en, this message translates to:
  /// **'Speech-to-text provider'**
  String get speechApiProvider;

  /// CodeWalk UI string — speechCloudSttPrivacy
  ///
  /// In en, this message translates to:
  /// **'Cloud speech-to-text privacy'**
  String get speechCloudSttPrivacy;

  /// CodeWalk UI string — speechCloudSttPrivacyDescription
  ///
  /// In en, this message translates to:
  /// **'Recorded microphone audio is sent to the configured provider. API keys stay in secure storage on this device.'**
  String get speechCloudSttPrivacyDescription;

  /// CodeWalk UI string — speechApiKeyOptional
  ///
  /// In en, this message translates to:
  /// **'Optional for custom endpoints.'**
  String get speechApiKeyOptional;

  /// CodeWalk UI string — speechApiBatchHint
  ///
  /// In en, this message translates to:
  /// **'{provider} uses batch transcription. Tap the microphone again to stop and transcribe.'**
  String speechApiBatchHint(String provider);

  /// CodeWalk UI string — speechApiWebUnavailable
  ///
  /// In en, this message translates to:
  /// **'API speech-to-text is unavailable on the web build.'**
  String get speechApiWebUnavailable;

  /// CodeWalk UI string — speechApiConfigInvalid
  ///
  /// In en, this message translates to:
  /// **'Check the speech API endpoint and model. Remote endpoints must use HTTPS.'**
  String get speechApiConfigInvalid;

  /// CodeWalk UI string — speechApiRequestInvalid
  ///
  /// In en, this message translates to:
  /// **'The speech endpoint or model was rejected.'**
  String get speechApiRequestInvalid;

  /// CodeWalk UI string — speechApiRateLimited
  ///
  /// In en, this message translates to:
  /// **'The speech provider reported a quota or rate limit.'**
  String get speechApiRateLimited;

  /// CodeWalk UI string — speechApiUnavailable
  ///
  /// In en, this message translates to:
  /// **'The speech provider is temporarily unavailable.'**
  String get speechApiUnavailable;

  /// CodeWalk UI string — speechApiNetwork
  ///
  /// In en, this message translates to:
  /// **'The speech provider could not be reached.'**
  String get speechApiNetwork;

  /// CodeWalk UI string — speechApiInvalidResponse
  ///
  /// In en, this message translates to:
  /// **'The speech provider returned an invalid response.'**
  String get speechApiInvalidResponse;

  /// CodeWalk UI string — speechApiEmptyAudio
  ///
  /// In en, this message translates to:
  /// **'No microphone audio was captured.'**
  String get speechApiEmptyAudio;

  /// CodeWalk UI string — speechApiEmptyTranscript
  ///
  /// In en, this message translates to:
  /// **'The speech provider returned no transcription.'**
  String get speechApiEmptyTranscript;

  /// CodeWalk UI string — speechApiCustomProvider
  ///
  /// In en, this message translates to:
  /// **'Custom OpenAI-compatible'**
  String get speechApiCustomProvider;

  /// CodeWalk UI string — speechApiMaxDuration
  ///
  /// In en, this message translates to:
  /// **'API recordings stop automatically after 2 minutes.'**
  String get speechApiMaxDuration;

  /// CodeWalk UI string — speechApiLanguageHint
  ///
  /// In en, this message translates to:
  /// **'The active app language is sent as a transcription hint.'**
  String get speechApiLanguageHint;

  /// CodeWalk UI string — speechSttApiKeyStorageUnavailable
  ///
  /// In en, this message translates to:
  /// **'Secure speech API key storage is unavailable.'**
  String get speechSttApiKeyStorageUnavailable;

  /// CodeWalk UI string — speechSttApiKeyMissing
  ///
  /// In en, this message translates to:
  /// **'Add a speech API key in Settings > Speech.'**
  String get speechSttApiKeyMissing;

  /// CodeWalk UI string — speechSttApiKeyRejected
  ///
  /// In en, this message translates to:
  /// **'The speech API key was rejected.'**
  String get speechSttApiKeyRejected;

  /// No description provided for @carMessagingReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get carMessagingReply;

  /// No description provided for @carMessagingMarkRead.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get carMessagingMarkRead;

  /// No description provided for @carMessagingDeliveryFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'\'t send reply'**
  String get carMessagingDeliveryFailedTitle;

  /// No description provided for @carMessagingDeliveryFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Your voice reply could not be delivered. Open CodeWalk to retry.'**
  String get carMessagingDeliveryFailedBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'bn',
    'de',
    'en',
    'es',
    'fr',
    'hi',
    'it',
    'ja',
    'ko',
    'pt',
    'ru',
    'ur',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'bn':
      return AppLocalizationsBn();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'ur':
      return AppLocalizationsUr();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
