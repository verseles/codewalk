import 'package:codewalk/core/i18n/app_locales.dart';
import 'package:codewalk/l10n/generated/app_localizations.dart';
import 'package:codewalk/presentation/pages/settings_page.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:codewalk/presentation/services/sound_service.dart';
import 'package:codewalk/presentation/services/update_check_service.dart';
import 'package:codewalk/presentation/widgets/major_update_gate_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';
import '../support/release_history_fakes.dart';

const _v2 = UpdateCheckResult(
  latestVersion: '2.0.0',
  releaseTag: 'v2.0.0',
  releaseUrl: 'https://github.com/verseles/codewalk/releases/tag/v2.0.0',
  apkUrl: 'https://example.com/v2.0.0/codewalk.apk',
  isNewer: true,
  isMajorUpgrade: true,
);

class _MajorUpdateService extends UpdateCheckService {
  UpdateCheckResult? latest = _v2;
  int v1Calls = 0;

  @override
  Future<UpdateCheckResult?> check(
    String currentVersion, {
    bool ignoreCooldown = false,
  }) async => latest;

  @override
  Future<UpdateCheckResult?> checkV1Only(
    String currentVersion, {
    bool ignoreCooldown = false,
  }) async {
    v1Calls += 1;
    return null;
  }

  @override
  void clearCache() {}
}

class _Calls {
  int update = 0;
  int stay = 0;
  int later = 0;
  int notes = 0;
}

Widget _app({
  required Widget home,
  Locale locale = const Locale('en'),
  double textScale = 1,
  TextDirection? direction,
}) {
  return MaterialApp(
    locale: locale,
    theme: ThemeData(splashFactory: InkRipple.splashFactory),
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocales.supported,
    builder: (context, child) {
      Widget result = MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      );
      if (direction != null) {
        result = Directionality(textDirection: direction, child: result);
      }
      return result;
    },
    home: home,
  );
}

/// Opens the gate through showDialog, like the app does, with counting
/// callbacks that leave the dialog open.
Future<_Calls> _pumpGate(
  WidgetTester tester, {
  bool withReleaseNotes = true,
  bool androidNote = false,
  Locale locale = const Locale('en'),
  double textScale = 1,
  TextDirection? direction,
}) async {
  final calls = _Calls();
  await tester.pumpWidget(
    _app(
      locale: locale,
      textScale: textScale,
      direction: direction,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => MajorUpdateGateDialog(
                  version: '2.0.0',
                  showAndroidReplacementNote: androidNote,
                  onOpenReleaseNotes: withReleaseNotes
                      ? () => calls.notes += 1
                      : null,
                  onUpdate: () => calls.update += 1,
                  onStay: () => calls.stay += 1,
                  onLater: () => calls.later += 1,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return calls;
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<SettingsProvider> _provider(_MajorUpdateService service) async {
  PackageInfo.setMockInitialValues(
    appName: 'CodeWalk',
    packageName: 'com.verseles.codewalk',
    version: '1.265.1',
    buildNumber: '45',
    buildSignature: '',
  );
  final provider = SettingsProvider(
    localDataSource: InMemoryAppLocalDataSource()
      ..experienceSettingsJson = '{"checkUpdatesOnOpen": false}',
    dioClient: ReleaseHistoryNoopDioClient(),
    soundService: SoundService(),
    updateCheckService: service,
  );
  await provider.initialize();
  return provider;
}

void main() {
  testWidgets(
    'shows the requirement, the changes, the link and three actions',
    (tester) async {
      await _pumpGate(tester, androidNote: true);

      expect(find.text('CodeWalk 2 is available (v2.0.0)'), findsOneWidget);
      expect(
        find.text(
          'CodeWalk 2 requires OpenCode 2 servers. Your OpenCode 1 servers '
          'will stop working in this app after the update.',
        ),
        findsOneWidget,
      );
      expect(find.text('What changes'), findsOneWidget);
      expect(find.text('•'), findsNWidgets(4));
      expect(
        find.byKey(const ValueKey('major_update_gate_android_note')),
        findsOneWidget,
      );
      expect(find.text('Release notes and migration'), findsOneWidget);
      expect(find.text('Update to CodeWalk 2'), findsOneWidget);
      expect(find.text('Stay on CodeWalk 1'), findsOneWidget);
      expect(find.text('Remind me in 7 days'), findsOneWidget);
    },
  );

  testWidgets('hides the release link and Android note when not applicable', (
    tester,
  ) async {
    await _pumpGate(tester, withReleaseNotes: false);

    expect(find.text('Release notes and migration'), findsNothing);
    expect(
      find.byKey(const ValueKey('major_update_gate_android_note')),
      findsNothing,
    );
  });

  testWidgets('each action calls only its own callback', (tester) async {
    final calls = await _pumpGate(tester);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('major_update_gate_release_notes')),
    );
    expect(
      [calls.notes, calls.update, calls.stay, calls.later],
      <int>[1, 0, 0, 0],
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('major_update_gate_update')),
    );
    expect(
      [calls.notes, calls.update, calls.stay, calls.later],
      <int>[1, 1, 0, 0],
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('major_update_gate_stay')),
    );
    expect(
      [calls.notes, calls.update, calls.stay, calls.later],
      <int>[1, 1, 1, 0],
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('major_update_gate_later')),
    );
    expect(
      [calls.notes, calls.update, calls.stay, calls.later],
      <int>[1, 1, 1, 1],
    );
  });

  testWidgets('Back and Escape mean Later; the barrier is inert', (
    tester,
  ) async {
    final calls = await _pumpGate(tester);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byType(MajorUpdateGateDialog), findsOneWidget);
    expect(calls.later, 0);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(calls.later, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(calls.later, 2);
    expect([calls.update, calls.stay], <int>[0, 0]);
    expect(find.byType(MajorUpdateGateDialog), findsOneWidget);
  });

  for (final (name, locale, direction) in <(String, Locale, TextDirection?)>[
    ('LTR', const Locale('en'), null),
    ('RTL', const Locale('en'), TextDirection.rtl),
    ('Arabic', const Locale('ar'), null),
    ('German', const Locale('de'), null),
  ]) {
    testWidgets('fits 320 dp at 2x text scale ($name)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final calls = await _pumpGate(
        tester,
        androidNote: true,
        locale: locale,
        textScale: 2,
        direction: direction,
      );

      expect(tester.takeException(), isNull);
      for (final key in <String>[
        'major_update_gate_update',
        'major_update_gate_stay',
        'major_update_gate_later',
      ]) {
        await _tapVisible(tester, find.byKey(ValueKey(key)));
        expect(tester.takeException(), isNull);
      }
      expect([calls.update, calls.stay, calls.later], <int>[1, 1, 1]);
    });
  }

  // iOS keeps these Settings tests free of Android/desktop side effects.
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

  group('Settings surfaces', () {
    testWidgets('landing shows a gate card instead of the install card', (
      tester,
    ) async {
      final service = _MajorUpdateService();
      final settings = await _provider(service);
      addTearDown(settings.dispose);
      expect(await settings.checkForUpdate(), isTrue);

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: _app(home: const SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('settings_major_update_banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('settings_update_available_banner')),
        findsNothing,
      );
      expect(find.text('Install update'), findsNothing);
      expect(find.text('Dismiss'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('settings_major_update_review')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MajorUpdateGateDialog), findsOneWidget);

      await _tapVisible(
        tester,
        find.byKey(const ValueKey('major_update_gate_later')),
      );
      expect(find.byType(MajorUpdateGateDialog), findsNothing);
      expect(settings.majorUpdateCandidate, isNull);
      expect(settings.majorUpdateRemindUntil, isNotNull);
      expect(
        find.byKey(const ValueKey('settings_major_update_banner')),
        findsNothing,
      );
    }, variant: ios);

    testWidgets(
      'About opens the gate from a manual check and Stay switches channel',
      (tester) async {
        final service = _MajorUpdateService();
        final settings = await _provider(service);
        addTearDown(settings.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider<SettingsProvider>.value(
            value: settings,
            child: _app(home: const SettingsPage(initialSectionId: 'about')),
          ),
        );
        await tester.pumpAndSettle();

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('settings_about_check_now')),
        );
        expect(find.byType(MajorUpdateGateDialog), findsOneWidget);

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('major_update_gate_stay')),
        );
        expect(find.byType(MajorUpdateGateDialog), findsNothing);
        expect(settings.updateChannel, UpdateChannel.v1);
        expect(settings.majorUpdateCandidate, isNull);
        expect(service.v1Calls, 1);

        final stable = find.byKey(
          const ValueKey('settings_about_update_channel_stable'),
        );
        await _tapVisible(tester, stable);
        expect(settings.updateChannel, UpdateChannel.stable);
        // Returning to stable re-checks and asks again; it never installs.
        expect(find.byType(MajorUpdateGateDialog), findsOneWidget);
        expect(settings.installState, UpdateInstallState.idle);

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('major_update_gate_later')),
        );
        expect(settings.updateChannel, UpdateChannel.stable);
      },
      variant: ios,
    );
  });
}
