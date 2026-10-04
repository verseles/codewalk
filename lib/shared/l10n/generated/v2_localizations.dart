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
