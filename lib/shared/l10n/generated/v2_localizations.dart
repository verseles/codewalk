// GENERATED CODE with Flutter gen-l10n from lib/shared/l10n/arb. Do not edit.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'v2_localizations_ar.dart';
import 'v2_localizations_bn.dart';
import 'v2_localizations_de.dart';
import 'v2_localizations_en.dart';
import 'v2_localizations_es.dart';
import 'v2_localizations_fr.dart';
import 'v2_localizations_hi.dart';
import 'v2_localizations_it.dart';
import 'v2_localizations_ja.dart';
import 'v2_localizations_ko.dart';
import 'v2_localizations_pt.dart';
import 'v2_localizations_ru.dart';
import 'v2_localizations_ur.dart';
import 'v2_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of V2Localizations
/// returned by `V2Localizations.of(context)`.
///
/// Applications need to include `V2Localizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/v2_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: V2Localizations.localizationsDelegates,
///   supportedLocales: V2Localizations.supportedLocales,
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
/// be consistent with the languages listed in the V2Localizations.supportedLocales
/// property.
abstract class V2Localizations {
  V2Localizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static V2Localizations of(BuildContext context) {
    return Localizations.of<V2Localizations>(context, V2Localizations)!;
  }

  static const LocalizationsDelegate<V2Localizations> delegate =
      _V2LocalizationsDelegate();

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
    Locale('en'),
    Locale('ar'),
    Locale('bn'),
    Locale('de'),
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

  /// CodeWalk UI string — chatAddServerToStart
  ///
  /// In en, this message translates to:
  /// **'Add a server to start chatting.'**
  String get chatAddServerToStart;

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

  /// CodeWalk UI string — commonCancel
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// CodeWalk UI string — onboardingConnectRunningServer
  ///
  /// In en, this message translates to:
  /// **'Connect to a running server'**
  String get onboardingConnectRunningServer;

  /// CodeWalk UI string — serversCopy
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get serversCopy;

  /// CodeWalk UI string — settingsBack
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get settingsBack;

  /// CodeWalk UI string — settingsServersTitle
  ///
  /// In en, this message translates to:
  /// **'Servers'**
  String get settingsServersTitle;

  /// CodeWalk UI string — settingsTitle
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Shown when CodeWalk cannot resolve an incoming navigation link.
  ///
  /// In en, this message translates to:
  /// **'This link is not supported.'**
  String get unsupportedLink;

  /// CodeWalk UI string — chatRetry
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get chatRetry;

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

  /// CodeWalk UI string — settingsAppearanceCodeWalkClassic
  ///
  /// In en, this message translates to:
  /// **'CodeWalk Classic'**
  String get settingsAppearanceCodeWalkClassic;

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

  /// CodeWalk UI string — settingsAppearanceContrastLow
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get settingsAppearanceContrastLow;

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

  /// CodeWalk UI string — settingsAppearanceContrastStandard
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get settingsAppearanceContrastStandard;

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

  /// CodeWalk UI string — settingsAppearanceLight
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsAppearanceLight;

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

  /// CodeWalk UI string — settingsAppearanceVisualStyleClassic
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get settingsAppearanceVisualStyleClassic;

  /// CodeWalk UI string — settingsAppearanceVisualStyleDescription
  ///
  /// In en, this message translates to:
  /// **'Choose Classic or softer Refined surfaces.'**
  String get settingsAppearanceVisualStyleDescription;

  /// CodeWalk UI string — settingsAppearanceVisualStyleRefined
  ///
  /// In en, this message translates to:
  /// **'Refined'**
  String get settingsAppearanceVisualStyleRefined;

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

  /// Appearance persistence failure; settings may be temporary
  ///
  /// In en, this message translates to:
  /// **'Appearance settings could not be loaded or saved. Changes remain temporary until retry succeeds.'**
  String get appearanceStorageError;

  /// CodeWalk UI string — settingsAppearanceDescription
  ///
  /// In en, this message translates to:
  /// **'Choose themes, colors, text size, and chat display'**
  String get settingsAppearanceDescription;

  /// CodeWalk UI string — settingsAppearanceTitle
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearanceTitle;

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

  /// CodeWalk UI string — settingsProvenanceCodeWalkLocal
  ///
  /// In en, this message translates to:
  /// **'CodeWalk-local'**
  String get settingsProvenanceCodeWalkLocal;

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

  /// CodeWalk UI string — shortcutNextTab
  ///
  /// In en, this message translates to:
  /// **'Next tab'**
  String get shortcutNextTab;

  /// CodeWalk UI string — shortcutNextTabDesc
  ///
  /// In en, this message translates to:
  /// **'Show the tab switcher and cycle to the next tab'**
  String get shortcutNextTabDesc;

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

  /// CodeWalk UI string — shortcutPreviousTab
  ///
  /// In en, this message translates to:
  /// **'Previous tab'**
  String get shortcutPreviousTab;

  /// CodeWalk UI string — shortcutPreviousTabDesc
  ///
  /// In en, this message translates to:
  /// **'Show the tab switcher and cycle to the previous tab'**
  String get shortcutPreviousTabDesc;

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

  /// CodeWalk UI string — shortcutsErrorConflict
  ///
  /// In en, this message translates to:
  /// **'Conflicts with \"{conflict}\"'**
  String shortcutsErrorConflict(String conflict);

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

  /// CodeWalk UI string — shortcutsKeyboardShortcuts
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get shortcutsKeyboardShortcuts;

  /// CodeWalk UI string — shortcutsPressKeyCombination
  ///
  /// In en, this message translates to:
  /// **'Press the key combination now'**
  String get shortcutsPressKeyCombination;

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

  /// V2 local settings and shortcut UI
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get shortcutsUnassigned;

  /// V2 local settings and shortcut UI
  ///
  /// In en, this message translates to:
  /// **'Unassign'**
  String get shortcutsUnassign;

  /// V2 local settings and shortcut UI
  ///
  /// In en, this message translates to:
  /// **'This action is unavailable in this version.'**
  String get shortcutsUnavailable;

  /// V2 local settings and shortcut UI
  ///
  /// In en, this message translates to:
  /// **'Settings could not be loaded or saved. Retry; changes may be temporary.'**
  String get settingsStorageError;

  /// V2 local settings and shortcut UI
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get settingsSearchClear;

  /// CodeWalk UI string — commonDelete
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// CodeWalk UI string — commonSave
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// CodeWalk UI string — onboardingCouldNotVerify
  ///
  /// In en, this message translates to:
  /// **'Could not verify the server connection.'**
  String get onboardingCouldNotVerify;

  /// CodeWalk UI string — onboardingFailed
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get onboardingFailed;

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

  /// CodeWalk UI string — onboardingNotAvailable
  ///
  /// In en, this message translates to:
  /// **'not available'**
  String get onboardingNotAvailable;

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

  /// CodeWalk UI string — onboardingReady
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get onboardingReady;

  /// CodeWalk UI string — onboardingServerUrl
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get onboardingServerUrl;

  /// CodeWalk UI string — onboardingStarting
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get onboardingStarting;

  /// CodeWalk UI string — onboardingStopping
  ///
  /// In en, this message translates to:
  /// **'Stopping'**
  String get onboardingStopping;

  /// CodeWalk UI string — serversAddServer
  ///
  /// In en, this message translates to:
  /// **'Add Server'**
  String get serversAddServer;

  /// CodeWalk UI string — serversNoServersFound
  ///
  /// In en, this message translates to:
  /// **'No servers found'**
  String get serversNoServersFound;

  /// V2 endpoint profile and compatibility UI
  ///
  /// In en, this message translates to:
  /// **'This server runs OpenCode 1. CodeWalk 2 needs OpenCode 2.'**
  String get hostsLegacyExplanation;

  /// V2 endpoint profile and compatibility UI
  ///
  /// In en, this message translates to:
  /// **'Run opencode upgrade on your server. Minimum: 2.0.20; tested: 2.0.21–2.0.22. CodeWalk does not install or change your server.'**
  String get hostsUpgradeInstructions;

  /// V2 endpoint profile and compatibility UI
  ///
  /// In en, this message translates to:
  /// **'Download CodeWalk 1'**
  String get hostsLegacyDownload;

  /// V2 endpoint profile and compatibility UI
  ///
  /// In en, this message translates to:
  /// **'Server upgrade required'**
  String get hostsUpgradeRequired;

  /// V2 endpoint profile and compatibility UI
  ///
  /// In en, this message translates to:
  /// **'Untested version'**
  String get hostsUntested;

  /// V2 endpoint profile and compatibility UI
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Check the URL, TLS and VPN connection.'**
  String get hostsTransportHelp;

  /// V2 endpoint profile and compatibility UI
  ///
  /// In en, this message translates to:
  /// **'Endpoint detection is available on native Android and Linux in this MVP.'**
  String get hostsNativeOnly;

  /// V2 endpoint profile and compatibility UI
  ///
  /// In en, this message translates to:
  /// **'Check the server password or pairing credentials.'**
  String get hostsAuthRequired;

  /// V2 endpoint profile and compatibility UI
  ///
  /// In en, this message translates to:
  /// **'Could not load or save profiles. Retry to reconcile the saved state.'**
  String get hostsProfileStorageError;

  /// V2 endpoint profile and compatibility UI
  ///
  /// In en, this message translates to:
  /// **'The server requested a delay. Retry after the indicated time; no automatic retry is running.'**
  String get hostsRetryLater;

  /// V2 endpoint profile and compatibility UI
  ///
  /// In en, this message translates to:
  /// **'Check connection'**
  String get hostsCheckConnection;

  /// V2 pairing and credential lifecycle
  ///
  /// In en, this message translates to:
  /// **'Pair a server'**
  String get pairingTitle;

  /// V2 pairing and credential lifecycle
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get pairingScanQr;

  /// V2 pairing and credential lifecycle
  ///
  /// In en, this message translates to:
  /// **'Open QR image'**
  String get pairingImageQr;

  /// V2 pairing and credential lifecycle
  ///
  /// In en, this message translates to:
  /// **'Pairing link'**
  String get pairingLink;

  /// V2 pairing and credential lifecycle
  ///
  /// In en, this message translates to:
  /// **'Confirm and pair'**
  String get pairingConfirm;

  /// V2 pairing and credential lifecycle
  ///
  /// In en, this message translates to:
  /// **'This link is invalid, expired or already used. Generate a new link.'**
  String get pairingRejected;

  /// V2 pairing and credential lifecycle
  ///
  /// In en, this message translates to:
  /// **'The pairing outcome is unknown. Generate a new link; this request will not be repeated.'**
  String get pairingUncertain;

  /// V2 pairing and credential lifecycle
  ///
  /// In en, this message translates to:
  /// **'Could not read this QR. Use a PNG/JPEG image or paste the link.'**
  String get pairingCaptureError;

  /// V2 pairing and credential lifecycle
  ///
  /// In en, this message translates to:
  /// **'Renew token'**
  String get pairingRenew;

  /// V2 pairing and credential lifecycle
  ///
  /// In en, this message translates to:
  /// **'Pair again'**
  String get pairingAgain;

  /// V2 pairing and credential lifecycle
  ///
  /// In en, this message translates to:
  /// **'Declared token expiry'**
  String get pairingExpires;

  /// V2 pairing and credential lifecycle
  ///
  /// In en, this message translates to:
  /// **'Paired'**
  String get pairingPaired;

  /// CodeWalk UI string — chatLoadMore
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get chatLoadMore;

  /// CodeWalk UI string — chatRefresh
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get chatRefresh;

  /// CodeWalk UI string — commonCopiedToClipboard
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get commonCopiedToClipboard;

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

  /// CodeWalk UI string — logsEnableLoggingDescription
  ///
  /// In en, this message translates to:
  /// **'Collect in-memory diagnostic logs. Keep this off unless you are troubleshooting.'**
  String get logsEnableLoggingDescription;

  /// CodeWalk UI string — logsFilterAll
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get logsFilterAll;

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

  /// About release history entry subtitle
  ///
  /// In en, this message translates to:
  /// **'Recent announcements and changelogs'**
  String get releaseHistoryDescription;

  /// No cached changelog available after a failed fetch
  ///
  /// In en, this message translates to:
  /// **'Unable to load release history. Check your connection and try again.'**
  String get releaseHistoryLoadError;

  /// Cached release notes remain readable after a failed refresh
  ///
  /// In en, this message translates to:
  /// **'Showing a saved copy. Refresh failed; newer notes may be missing.'**
  String get releaseHistoryStale;

  /// Permanent release history entry and page title
  ///
  /// In en, this message translates to:
  /// **'Release history'**
  String get releaseHistoryTitle;

  /// CodeWalk UI string — settingsGroupHelp
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get settingsGroupHelp;

  /// V2 finite diagnostics and archive UI
  ///
  /// In en, this message translates to:
  /// **'Load host catalog'**
  String get diagnosticsHostCatalog;

  /// V2 finite diagnostics and archive UI
  ///
  /// In en, this message translates to:
  /// **'Check host'**
  String get diagnosticsHostProbe;

  /// V2 finite diagnostics and archive UI
  ///
  /// In en, this message translates to:
  /// **'Save profile'**
  String get diagnosticsProfileSave;

  /// V2 finite diagnostics and archive UI
  ///
  /// In en, this message translates to:
  /// **'Remove profile'**
  String get diagnosticsProfileRemove;

  /// V2 finite diagnostics and archive UI
  ///
  /// In en, this message translates to:
  /// **'Load preferences'**
  String get diagnosticsPreferencesLoad;

  /// V2 finite diagnostics and archive UI
  ///
  /// In en, this message translates to:
  /// **'Save preferences'**
  String get diagnosticsPreferencesSave;

  /// V2 finite diagnostics and archive UI
  ///
  /// In en, this message translates to:
  /// **'Load release history'**
  String get diagnosticsArchiveLoad;

  /// V2 finite diagnostics and archive UI
  ///
  /// In en, this message translates to:
  /// **'Save release history'**
  String get diagnosticsArchiveSave;

  /// V2 finite diagnostics and archive UI
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get diagnosticsInfo;

  /// V2 finite diagnostics and archive UI
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get diagnosticsWarning;

  /// V2 finite diagnostics and archive UI
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get diagnosticsError;

  /// V2 finite diagnostics and archive UI
  ///
  /// In en, this message translates to:
  /// **'Unable to copy logs.'**
  String get diagnosticsCopyFailed;

  /// V2 finite diagnostics and archive UI
  ///
  /// In en, this message translates to:
  /// **'Logs copied; the copy was limited to 64 KiB.'**
  String get diagnosticsCopyTruncated;

  /// V2 finite diagnostics and archive UI
  ///
  /// In en, this message translates to:
  /// **'Memory only: operation, outcome, severity, UTC time and bounded duration. No content, credentials or addresses are collected.'**
  String get diagnosticsPrivacy;

  /// CodeWalk UI string — logsPerformanceDuration
  ///
  /// In en, this message translates to:
  /// **'{elapsedMs} ms'**
  String logsPerformanceDuration(int elapsedMs);

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Select a saved profile'**
  String get sessionsSelectProfile;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'No sessions in the loaded results.'**
  String get sessionsEmpty;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Loading sessions…'**
  String get sessionsLoading;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Previous results; refresh has not succeeded yet.'**
  String get sessionsPreviousResults;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Local limit reached (200 sessions or 10 pages). These results may be incomplete.'**
  String get sessionsLimit;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Read-only details. Conversation history is unavailable in this preview.'**
  String get sessionsHistoryUnavailable;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Session reading is unavailable on this platform.'**
  String get sessionsUnavailable;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Could not read sessions. Refresh or retry loading the next page manually.'**
  String get sessionsReadFailed;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Session reading timed out. Retry manually.'**
  String get sessionsTimeout;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Invalid continuation. Refresh to start a new list.'**
  String get sessionsInvalidCursor;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'The server limited requests. Wait before retrying manually.'**
  String get sessionsRateLimited;

  /// CodeWalk UI string — sessionExportUntitled
  ///
  /// In en, this message translates to:
  /// **'Untitled session'**
  String get sessionExportUntitled;

  /// CodeWalk UI string — chatMessageMessagePartUnavailable
  ///
  /// In en, this message translates to:
  /// **'Message part unavailable'**
  String get chatMessageMessagePartUnavailable;

  /// CodeWalk UI string — chatMessageThinkingProcess
  ///
  /// In en, this message translates to:
  /// **'Thinking Process'**
  String get chatMessageThinkingProcess;

  /// CodeWalk UI string — chatMessageYou
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get chatMessageYou;

  /// V2 auxiliary read-only history preview
  ///
  /// In en, this message translates to:
  /// **'View history'**
  String get historyOpen;

  /// V2 auxiliary read-only history preview
  ///
  /// In en, this message translates to:
  /// **'Read-only history'**
  String get historyReadOnly;

  /// V2 auxiliary read-only history preview
  ///
  /// In en, this message translates to:
  /// **'Live state and delivery are not verified.'**
  String get historyUnverified;

  /// V2 auxiliary read-only history preview
  ///
  /// In en, this message translates to:
  /// **'No history items in this page.'**
  String get historyEmpty;

  /// V2 auxiliary read-only history preview
  ///
  /// In en, this message translates to:
  /// **'Local history limit reached; more items may exist.'**
  String get historyLimit;

  /// V2 auxiliary read-only history preview
  ///
  /// In en, this message translates to:
  /// **'The server version changed. Refresh to start again.'**
  String get historySourceChanged;

  /// V2 auxiliary read-only history preview
  ///
  /// In en, this message translates to:
  /// **'History could not be read. Check the server and try again.'**
  String get historyUnavailable;

  /// V2 auxiliary read-only history preview
  ///
  /// In en, this message translates to:
  /// **'Sending is unavailable in this read-only preview.'**
  String get historySendUnavailable;

  /// V2 auxiliary read-only history preview
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get historyAssistant;

  /// V2 auxiliary read-only history preview
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get historyDetails;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'Open live'**
  String get liveOpen;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'Live session (read-only)'**
  String get liveReadOnly;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get liveConnecting;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'Loading the latest state…'**
  String get liveHydrating;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get liveLive;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get liveReconnecting;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'Not up to date; showing the last synced state.'**
  String get liveStale;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'Last synced'**
  String get liveLastSynced;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'This session could not be kept up to date.'**
  String get liveDegraded;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'This session no longer exists on the server.'**
  String get liveEvicted;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'This server version is not supported for the live view.'**
  String get liveIncompatible;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'Server restarted, resuming'**
  String get liveResuming;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get liveRunning;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get liveIdle;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'Last turn succeeded'**
  String get liveOutcomeSucceeded;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'Last turn failed'**
  String get liveOutcomeFailed;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'Last turn interrupted'**
  String get liveOutcomeInterrupted;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'Waiting for your answer'**
  String get liveNeedsYou;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'Too many live sessions are open for this server.'**
  String get liveCapacity;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'The live view could not be opened. Check the server and try again.'**
  String get liveUnavailable;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'Prompt sending is unavailable in this view.'**
  String get liveSendUnavailable;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get liveRetry;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'Live session'**
  String get composerLiveSession;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get composerHint;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get composerSend;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'Steer'**
  String get composerSteer;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get composerQueue;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'Steering'**
  String get composerSteering;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get composerQueued;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get composerCancel;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'Steer now'**
  String get composerMoveToSteer;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'Move to queue'**
  String get composerMoveToQueue;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get composerCheckAgain;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'Send again (may duplicate)'**
  String get composerSendAgain;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get composerDiscard;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get composerSending;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'Delivery not confirmed'**
  String get composerNotConfirmed;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'Cancellation not confirmed yet'**
  String get composerCancelling;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'Not sent'**
  String get composerNotSent;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'This message could not be saved on this device, so it was not sent.'**
  String get composerNoticeNotSaved;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'Too many unsent messages are kept on this device. Discard one to send more.'**
  String get composerNoticeFull;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'The saved messages could not be read; sending is unavailable.'**
  String get composerNoticeUnreadable;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'This message cannot be sent here.'**
  String get composerNoticeUnavailable;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'The server refused this message because the session changed. Your text was kept.'**
  String get composerNoticeConflict;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'Another message already uses this message’s identity; it was not sent again.'**
  String get composerNoticeIdentity;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'The server did not accept this message. Your text was kept.'**
  String get composerNoticeRejected;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'Message cancelled.'**
  String get composerNoticeCancelled;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'The message was delivered before it could be cancelled.'**
  String get composerNoticeDeliveredFirst;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'Delivery changed.'**
  String get composerNoticeSwitched;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'Delivery could not be changed; the message was already delivered.'**
  String get composerNoticeSwitchNotApplied;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'The change could not be confirmed.'**
  String get composerNoticeChangeFailed;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'The server version changed; this message cannot be changed here.'**
  String get composerNoticeVersionChanged;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'Sending resumes when the live view is up to date.'**
  String get composerOffline;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'From another client'**
  String get composerOtherClient;

  /// V2 live session composer
  ///
  /// In en, this message translates to:
  /// **'Waiting messages'**
  String get composerInbox;

  /// V2 explicit execution stop control
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get liveStop;

  /// V2 explicit execution stop control
  ///
  /// In en, this message translates to:
  /// **'Stop requested…'**
  String get liveStopping;

  /// V2 explicit execution stop control
  ///
  /// In en, this message translates to:
  /// **'No active execution was interrupted.'**
  String get liveStopIdle;

  /// V2 explicit execution stop control
  ///
  /// In en, this message translates to:
  /// **'Stop not confirmed. Follow the live execution state.'**
  String get liveStopUnconfirmed;

  /// V2 explicit execution stop control
  ///
  /// In en, this message translates to:
  /// **'The stop request was refused.'**
  String get liveStopFailed;

  /// V2 explicit execution stop control
  ///
  /// In en, this message translates to:
  /// **'Press Escape again to stop.'**
  String get liveStopEscapeHint;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Allow once'**
  String get livePermissionAllowOnce;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Always for this project'**
  String get livePermissionAlwaysProject;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Persists for this project'**
  String get livePermissionProjectHint;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Reject with note'**
  String get livePermissionRejectNote;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Reject and stop'**
  String get livePermissionRejectStop;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Note (required to send this rejection)'**
  String get livePermissionNoteHint;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Rejecting also settles the other pending requests in this session.'**
  String get livePermissionBatchScope;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Sending reply…'**
  String get livePermissionSending;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Reply sent. Follow the live state.'**
  String get livePermissionSent;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Reply not confirmed. Follow the live state.'**
  String get livePermissionUnconfirmed;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'The reply was refused.'**
  String get livePermissionRefused;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Send rejection with note'**
  String get livePermissionRejectSend;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Permission mode'**
  String get livePermissionMode;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get livePermissionModeAsk;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Allow all'**
  String get livePermissionModeAllowAll;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Set for this session'**
  String get livePermissionModeSession;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'App default'**
  String get livePermissionModeDefault;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Use app default'**
  String get livePermissionModeUseDefault;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Permission mode unavailable'**
  String get livePermissionModeUnavailable;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Could not save the permission mode.'**
  String get livePermissionModeFailed;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Unrestricted'**
  String get livePermissionModeUnrestricted;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Set outside CodeWalk'**
  String get livePermissionModeUnrestrictedExternal;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Turn on Unrestricted…'**
  String get livePermissionModeUnrestrictedTurnOn;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Turn off Unrestricted'**
  String get livePermissionModeUnrestrictedTurnOff;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Refresh session rules'**
  String get livePermissionModeRulesRefresh;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Turn on Unrestricted for this session?'**
  String get liveUnrestrictedTitle;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'OpenCode will run every action in this session without asking, overriding the agent’s ask and deny rules. Requests already waiting still need an answer.'**
  String get liveUnrestrictedOverride;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'New child sessions copy this rule. Existing child sessions keep their rules, and turning it off later does not change children that already copied it.'**
  String get liveUnrestrictedChildren;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Other clients can see and change this rule; CodeWalk only removes the rule it added. Turning it off does not undo actions already taken.'**
  String get liveUnrestrictedOthers;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Turn on Unrestricted'**
  String get liveUnrestrictedConfirm;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'The session rules were not changed.'**
  String get liveUnrestrictedRefused;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'The rules change was not confirmed. Refresh to check.'**
  String get liveUnrestrictedUnconfirmed;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'The session rules changed elsewhere. CodeWalk did not overwrite them.'**
  String get liveUnrestrictedChangedElsewhere;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Session rules are unavailable.'**
  String get liveUnrestrictedUnavailable;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Unrestricted turned off. Existing child sessions keep the rule they copied.'**
  String get liveUnrestrictedTurnedOff;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Sub-agent'**
  String get livePermissionChildBadge;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Rejecting also settles this sub-agent’s other pending requests.'**
  String get livePermissionChildBatchScope;

  /// V2 manual permission cards
  ///
  /// In en, this message translates to:
  /// **'Already answered elsewhere or no longer pending. Follow the live state.'**
  String get livePermissionAnsweredElsewhere;

  /// V2 interactive form cards
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get liveFormSubmit;

  /// V2 interactive form cards
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get liveFormDismiss;

  /// V2 interactive form cards
  ///
  /// In en, this message translates to:
  /// **'Submitting form…'**
  String get liveFormSending;

  /// V2 interactive form cards
  ///
  /// In en, this message translates to:
  /// **'Dismissing form…'**
  String get liveFormDismissing;

  /// V2 interactive form cards
  ///
  /// In en, this message translates to:
  /// **'Form submitted. Follow the live state.'**
  String get liveFormSent;

  /// V2 interactive form cards
  ///
  /// In en, this message translates to:
  /// **'Submission not confirmed. Follow the live state.'**
  String get liveFormUnconfirmed;

  /// V2 interactive form cards
  ///
  /// In en, this message translates to:
  /// **'The submission was refused.'**
  String get liveFormRefused;

  /// V2 interactive form cards
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get liveFormRequiredField;

  /// V2 interactive form cards
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid number.'**
  String get liveFormInvalidNumber;

  /// V2 interactive form cards
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid integer.'**
  String get liveFormInvalidInteger;

  /// V2 interactive form cards
  ///
  /// In en, this message translates to:
  /// **'Open external link'**
  String get liveFormOpenLink;

  /// V2 interactive form cards
  ///
  /// In en, this message translates to:
  /// **'Toggle secret visibility'**
  String get liveFormSecretToggle;

  /// V2 interactive form cards
  ///
  /// In en, this message translates to:
  /// **'Select an option'**
  String get liveFormSelectOption;

  /// V2 interactive form cards
  ///
  /// In en, this message translates to:
  /// **'Custom answer'**
  String get liveFormCustomAnswer;

  /// CodeWalk UI string — chatMessageLargeMessageTruncated
  ///
  /// In en, this message translates to:
  /// **'Large message preview truncated for app stability.'**
  String get chatMessageLargeMessageTruncated;

  /// CodeWalk UI string — chatMessageToolStatusInProgress
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get chatMessageToolStatusInProgress;

  /// CodeWalk UI string — chatMessageTruncatedChars
  ///
  /// In en, this message translates to:
  /// **'[truncated {count} chars] {reason}'**
  String chatMessageTruncatedChars(int count, String reason);

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

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Sessions without a reported project'**
  String get sessionsUnknownProject;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Live shared'**
  String get sessionsOwnershipLiveShared;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Owned by this host'**
  String get sessionsOwnershipHostOwned;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Saved history'**
  String get sessionsOwnershipSavedHistory;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Running elsewhere'**
  String get sessionsOwnershipRunningElsewhere;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Ownership unknown'**
  String get sessionsOwnershipUnknown;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get sessionsActionsMenu;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Mark as viewed'**
  String get sessionsActionMarkViewed;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get sessionsActionRename;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Fork from here'**
  String get sessionsActionFork;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Hide in CodeWalk'**
  String get sessionsActionHide;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Show in CodeWalk'**
  String get sessionsActionUnhide;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get sessionsActionDelete;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Rename the session'**
  String get sessionsActionRenameTitle;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'New title'**
  String get sessionsActionRenameLabel;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get sessionsActionRenameSave;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Delete the session'**
  String get sessionsActionDeleteTitle;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'This deletes \"{title}\" for good. A running turn is stopped.'**
  String sessionsActionDeleteBody(Object title);

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'This also deletes {count} child sessions and everything below them.'**
  String sessionsActionDeleteChildren(Object count);

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'This also deletes at least {count} child sessions and everything below them.'**
  String sessionsActionDeleteChildrenAtLeast(Object count);

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'This also deletes the child sessions and everything below them.'**
  String get sessionsActionDeleteChildrenUnknown;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Counting the child sessions…'**
  String get sessionsActionDeleteCounting;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'The endpoint\'\'s version is not verified.'**
  String get sessionsActionUnavailableVersion;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'This platform cannot reach the endpoint.'**
  String get sessionsActionUnavailablePlatform;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'The endpoint refused the credential.'**
  String get sessionsActionUnavailableAuth;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'The list is not the endpoint\'\'s current answer.'**
  String get sessionsActionUnavailableList;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Another command is running for this session.'**
  String get sessionsActionUnavailableBusy;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'This session has nothing to mark as viewed.'**
  String get sessionsActionUnavailableMarker;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get sessionsActionUnread;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get sessionsActionPending;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'The command did not go through.'**
  String get sessionsActionFailed;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get sessionsFilterActive;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get sessionsFilterHidden;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get sessionsFilterAll;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'The hidden list could not be read.'**
  String get sessionsActionUnavailableStore;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get sessionsCreateNew;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Create a session'**
  String get sessionsCreateTitle;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get sessionsCreateProject;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Other directory…'**
  String get sessionsCreateOtherDirectory;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'The absolute path of the directory'**
  String get sessionsCreateDirectoryHint;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get sessionsCreateConfirm;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'The path must be absolute'**
  String get sessionsCreateDirectoryAbsolute;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'The path is too long'**
  String get sessionsCreateDirectoryTooLong;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Child session'**
  String get sessionsChildSession;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Child session · parent not shown here'**
  String get sessionsChildParentElsewhere;

  /// CodeWalk UI string — chatGoToLatest
  ///
  /// In en, this message translates to:
  /// **'Go to latest message'**
  String get chatGoToLatest;

  /// CodeWalk UI string — chatGoToFirst
  ///
  /// In en, this message translates to:
  /// **'Go to first message'**
  String get chatGoToFirst;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'Loading older messages…'**
  String get liveOlderLoading;

  /// CodeWalk UI string — chatMessageDetails
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get chatMessageDetails;

  /// CodeWalk UI string — chatMessageShowLess
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get chatMessageShowLess;

  /// CodeWalk UI string — chatMessageShowMore
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get chatMessageShowMore;

  /// CodeWalk UI string — chatMessageToolCommand
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get chatMessageToolCommand;

  /// CodeWalk UI string — chatMessageToolInput
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get chatMessageToolInput;

  /// CodeWalk UI string — chatMessageToolOutputTruncated
  ///
  /// In en, this message translates to:
  /// **'Large tool output preview truncated for app stability.'**
  String get chatMessageToolOutputTruncated;

  /// CodeWalk UI string — statusFailed
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// CodeWalk UI string — toolRunning
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get toolRunning;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get liveToolOutput;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get liveToolDone;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'Interrupted'**
  String get liveToolInterrupted;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'Exit code'**
  String get liveShellExitCode;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'Timed out'**
  String get liveShellTimedOut;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'Killed'**
  String get liveShellKilled;

  /// V2 live read-only session view
  ///
  /// In en, this message translates to:
  /// **'The server kept more output than shown here.'**
  String get liveShellOutputPartial;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Choose a session in the list to open it here.'**
  String get workspaceSelectSession;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'This link points to a server that is not saved on this device.'**
  String get sessionLinkUnknownServer;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'This session no longer exists on its server.'**
  String get sessionLinkNotFound;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Could not open this session. Retry.'**
  String get sessionLinkUnreadable;

  /// CodeWalk UI string — chatClose
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get chatClose;

  /// CodeWalk UI string — chatSessionTabsToggle
  ///
  /// In en, this message translates to:
  /// **'Session tabs'**
  String get chatSessionTabsToggle;

  /// Snackbar shown after closing a session tab
  ///
  /// In en, this message translates to:
  /// **'Tab \"{title}\" closed'**
  String sessionTabClosedMessage(String title);

  /// CodeWalk UI string — sessionTabSwitcherHint
  ///
  /// In en, this message translates to:
  /// **'Release Ctrl to switch, Esc to cancel'**
  String get sessionTabSwitcherHint;

  /// CodeWalk UI string — sessionTabSwitcherTitle
  ///
  /// In en, this message translates to:
  /// **'Switch tab'**
  String get sessionTabSwitcherTitle;

  /// Snackbar action that restores a closed session tab
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get sessionTabUndo;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Tabs of sessions that no longer exist were closed.'**
  String get sessionTabsRemoved;

  /// V2 bounded read-only session catalog
  ///
  /// In en, this message translates to:
  /// **'Too many open tabs. Close one to open another.'**
  String get sessionTabsFull;
}

class _V2LocalizationsDelegate extends LocalizationsDelegate<V2Localizations> {
  const _V2LocalizationsDelegate();

  @override
  Future<V2Localizations> load(Locale locale) {
    return SynchronousFuture<V2Localizations>(lookupV2Localizations(locale));
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
  bool shouldReload(_V2LocalizationsDelegate old) => false;
}

V2Localizations lookupV2Localizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return V2LocalizationsAr();
    case 'bn':
      return V2LocalizationsBn();
    case 'de':
      return V2LocalizationsDe();
    case 'en':
      return V2LocalizationsEn();
    case 'es':
      return V2LocalizationsEs();
    case 'fr':
      return V2LocalizationsFr();
    case 'hi':
      return V2LocalizationsHi();
    case 'it':
      return V2LocalizationsIt();
    case 'ja':
      return V2LocalizationsJa();
    case 'ko':
      return V2LocalizationsKo();
    case 'pt':
      return V2LocalizationsPt();
    case 'ru':
      return V2LocalizationsRu();
    case 'ur':
      return V2LocalizationsUr();
    case 'zh':
      return V2LocalizationsZh();
  }

  throw FlutterError(
    'V2Localizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
