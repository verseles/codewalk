import 'package:codewalk/core/i18n/app_locales.dart';
import 'package:codewalk/core/i18n/l10n_bridge.dart';
import 'package:codewalk/l10n/generated/app_localizations.dart';
import 'package:codewalk/l10n/generated/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpLocalizedApp(
  WidgetTester tester, {
  required Widget child,
  String localeCode = 'en',
}) async {
  // Pre-initialize L10nBridge with English for services used during construction.
  L10nBridge.update(AppLocalizationsEn());

  final app = MaterialApp(
    locale: Locale(localeCode),
    theme: _testSafeTheme(null),
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocales.supported,
    home: child,
  );

  await tester.pumpWidget(app);
  await tester.pump();

  // Update with the actual localized instance from the tree.
  final context = tester.element(find.byWidget(child));
  L10nBridge.update(AppLocalizations.of(context));
}

Widget localizedMaterialApp({
  required Widget home,
  ThemeData? theme,
  TransitionBuilder? builder,
}) {
  // Pre-initialize L10nBridge with English for services used during construction.
  L10nBridge.update(AppLocalizationsEn());

  return MaterialApp(
    locale: const Locale('en'),
    theme: _testSafeTheme(theme),
    builder: (context, child) {
      final l10n = AppLocalizations.of(context);
      if (l10n != null) {
        L10nBridge.update(l10n);
      }
      return builder?.call(context, child) ?? child!;
    },
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocales.supported,
    home: home,
  );
}

ThemeData _testSafeTheme(ThemeData? theme) {
  return (theme ?? ThemeData()).copyWith(
    splashFactory: InkRipple.splashFactory,
  );
}
