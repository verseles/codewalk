import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/l10n/l10n_bridge.dart';
import 'package:codewalk/shared/l10n/l10n_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'bridge instances have independent locales and a safe English fallback',
    () {
      final portuguese = L10nBridge(locale: const Locale('pt', 'BR'));
      final arabic = L10nBridge(locale: const Locale('ar'));

      expect(portuguese.current.settingsTitle, 'Configurações');
      expect(arabic.current.settingsTitle, 'الإعدادات');

      portuguese.setLocale(const Locale('ja'));
      expect(portuguese.current.settingsTitle, '設定');
      expect(arabic.current.settingsTitle, 'الإعدادات');

      portuguese.update(null);
      expect(portuguese.current.settingsTitle, 'Settings');
      expect(arabic.current.settingsTitle, 'الإعدادات');
      portuguese.setLocale(const Locale('unsupported'));
      expect(portuguese.current.unsupportedLink, 'This link is not supported.');
      expect(L10nBridge().current.commonCancel, 'Cancel');
    },
  );

  test(
    'bridge can receive a delegate localization without touching other apps',
    () {
      final first = L10nBridge();
      final second = L10nBridge();
      first.update(lookupV2Localizations(const Locale('fr')));
      expect(first.current.settingsBack, 'Retour');
      expect(second.current.settingsBack, 'Back');
      expect(
        first.current.onboardingConnectRunningServer,
        "Se connecter à un serveur en cours d'exécution",
      );
    },
  );

  test(
    'locale resolution supports regional variants and the device language list',
    () {
      expect(resolveV2Locale(const Locale('pt', 'BR')), const Locale('pt'));
      expect(resolveV2Locale(const Locale('en', 'AU')), const Locale('en'));
      expect(resolveV2Locale(const Locale('unsupported')), const Locale('en'));
      expect(resolveV2Locale(null), const Locale('en'));
      expect(
        resolveV2LocaleList(const [
          Locale('unsupported'),
          Locale('pt', 'BR'),
        ], V2Localizations.supportedLocales),
        const Locale('pt'),
      );
      expect(
        resolveV2LocaleList(null, V2Localizations.supportedLocales),
        const Locale('en'),
      );
    },
  );

  test(
    'the official delegate loads translated copy in all fourteen languages',
    () async {
      const expectedSettings = {
        'ar': 'الإعدادات',
        'bn': 'সেটিংস',
        'de': 'Einstellungen',
        'en': 'Settings',
        'es': 'Configuración',
        'fr': 'Paramètres',
        'hi': 'सेटिंग्स',
        'it': 'Impostazioni',
        'ja': '設定',
        'ko': '설정',
        'pt': 'Configurações',
        'ru': 'Настройки',
        'ur': 'ترتیبات',
        'zh': '设置',
      };
      expect(V2Localizations.supportedLocales, hasLength(14));
      for (final locale in V2Localizations.supportedLocales) {
        expect(V2Localizations.delegate.isSupported(locale), isTrue);
        final localizations = await V2Localizations.delegate.load(locale);
        expect(
          localizations.settingsTitle,
          expectedSettings[locale.languageCode],
        );
        expect(localizations.unsupportedLink, isNotEmpty);
        if (locale.languageCode != 'en') {
          expect(
            localizations.unsupportedLink,
            isNot('This link is not supported.'),
          );
        }
      }
    },
  );

  for (final locale in [
    const Locale('pt', 'BR'),
    const Locale('unsupported'),
    const Locale('ar'),
    const Locale('ur'),
  ]) {
    testWidgets('localized widgets resolve $locale and its text direction', (
      tester,
    ) async {
      Locale? resolved;
      TextDirection? direction;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localeListResolutionCallback: resolveV2LocaleList,
          localizationsDelegates: V2Localizations.localizationsDelegates,
          supportedLocales: V2Localizations.supportedLocales,
          home: Builder(
            builder: (context) {
              resolved = Localizations.localeOf(context);
              direction = Directionality.of(context);
              return Scaffold(body: Text(context.v2L10n.settingsTitle));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final expectedLocale = resolveV2Locale(locale);
      expect(resolved, expectedLocale);
      expect(
        direction,
        ['ar', 'ur'].contains(expectedLocale.languageCode)
            ? TextDirection.rtl
            : TextDirection.ltr,
      );
      expect(
        find.text(lookupV2Localizations(expectedLocale).settingsTitle),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'reusable widgets get English copy without localization delegates',
    (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) => Text(context.v2L10n.commonCancel),
          ),
        ),
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
