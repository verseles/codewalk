// Generated with Flutter gen-l10n from lib/shared/l10n/arb. Do not edit.
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
