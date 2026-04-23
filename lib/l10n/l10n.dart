import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

String? appLocaleToTag(Locale? locale) {
  if (locale == null) {
    return null;
  }
  final languageCode = locale.languageCode.trim();
  final countryCode = locale.countryCode?.trim();
  if (languageCode.isEmpty) {
    return null;
  }
  if (countryCode == null || countryCode.isEmpty) {
    return languageCode;
  }
  return '$languageCode-$countryCode';
}

Locale? appLocaleFromTag(String? localeTag) {
  final normalized = localeTag?.trim().replaceAll('_', '-').toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  for (final locale in AppLocalizations.supportedLocales) {
    if (appLocaleToTag(locale)?.toLowerCase() == normalized) {
      return locale;
    }
    if (locale.languageCode.toLowerCase() == normalized) {
      return locale;
    }
  }
  return null;
}
