import 'dart:convert';

import 'package:codewalk/core/constants/app_constants.dart';
import 'package:codewalk/core/i18n/l10n_bridge.dart';
import 'package:codewalk/l10n/generated/app_localizations_de.dart';
import 'package:codewalk/l10n/generated/app_localizations_en.dart';
import 'package:codewalk/l10n/generated/app_localizations_pt.dart';
import 'package:codewalk/presentation/services/android_background_alert_worker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() => L10nBridge.update(null));

  test(
    'initializes the locale bridge from persisted experience settings',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppConstants.experienceSettingsKey: jsonEncode(<String, Object>{
          'localeCode': 'pt',
        }),
      });

      await AndroidBackgroundAlertWorker.initializeBackgroundLocale();

      expect(L10nBridge.current, isA<AppLocalizationsPt>());
      expect(
        L10nBridge.current?.notificationSession,
        AppLocalizationsPt().notificationSession,
      );
    },
  );

  test('falls back to English when no locale is persisted', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await AndroidBackgroundAlertWorker.initializeBackgroundLocale();

    expect(L10nBridge.current, isA<AppLocalizationsEn>());
  });

  test('refreshes an existing localization from persisted settings', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppConstants.experienceSettingsKey: jsonEncode(<String, Object>{
        'localeCode': 'pt',
      }),
    });
    L10nBridge.update(AppLocalizationsDe());

    await AndroidBackgroundAlertWorker.initializeBackgroundLocale();

    expect(L10nBridge.current, isA<AppLocalizationsPt>());
  });
}
