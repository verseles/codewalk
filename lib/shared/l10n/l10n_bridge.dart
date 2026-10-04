import 'package:flutter/widgets.dart';

import 'generated/v2_localizations.dart';

/// Resolves regional variants to the supported language, with English fallback.
Locale resolveV2Locale(Locale? locale) {
  final language = locale?.languageCode.toLowerCase();
  return V2Localizations.supportedLocales.firstWhere(
    (supported) => supported.languageCode == language,
    orElse: () => const Locale('en'),
  );
}

/// Uses the first supported device language rather than falling back too early.
Locale resolveV2LocaleList(
  List<Locale>? locales,
  Iterable<Locale> supportedLocales,
) {
  for (final locale in locales ?? const <Locale>[]) {
    for (final supported in supportedLocales) {
      if (locale.languageCode.toLowerCase() == supported.languageCode) {
        return supported;
      }
    }
  }
  return const Locale('en');
}

/// Localized UI copy for consumers outside the widget tree.
///
/// Each composed app owns its bridge; there is no process-wide active locale.
class L10nBridge {
  L10nBridge({Locale? locale})
    : _current = lookupV2Localizations(resolveV2Locale(locale));

  V2Localizations _current;

  V2Localizations get current => _current;

  void setLocale(Locale? locale) {
    _current = lookupV2Localizations(resolveV2Locale(locale));
  }

  void update(V2Localizations? localizations) {
    _current = localizations ?? lookupV2Localizations(const Locale('en'));
  }
}
