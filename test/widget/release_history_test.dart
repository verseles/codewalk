import 'dart:async';

import 'package:codewalk/l10n/generated/app_localizations.dart';
import 'package:codewalk/presentation/pages/settings/release_history_page.dart';
import 'package:codewalk/presentation/pages/settings/sections/about_settings_section.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:codewalk/presentation/services/release_history_service.dart';
import 'package:codewalk/presentation/services/sound_service.dart';
import 'package:codewalk/presentation/widgets/release_announcements_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';
import '../support/release_history_fakes.dart';

Widget _app(Widget home, {SettingsProvider? settings, double scale = 1}) {
  final app = MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: home,
  );
  return settings == null
      ? app
      : ChangeNotifierProvider.value(value: settings, child: app);
}

void main() {
  for (final dismiss in ['checked', 'unchecked', 'back', 'barrier']) {
    testWidgets('announcement dialog $dismiss returns explicit user choice', (
      tester,
    ) async {
      bool? result;
      var completed = false;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<bool>(
                    context: context,
                    builder: (_) => ReleaseAnnouncementsDialog(
                      entries: parseReleaseHistory(releaseHistoryFixture),
                    ),
                  );
                  completed = true;
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final checkbox = find.byKey(
        const ValueKey('release_announcements_suppress'),
      );
      await tester.ensureVisible(checkbox);
      expect(tester.widget<CheckboxListTile>(checkbox).value, isTrue);
      if (dismiss == 'unchecked') await tester.tap(checkbox);
      if (dismiss == 'back') {
        Navigator.of(
          tester.element(find.byType(ReleaseAnnouncementsDialog)),
        ).pop();
      } else if (dismiss == 'barrier') {
        await tester.tapAt(const Offset(5, 5));
      } else {
        await tester.tap(
          find.byKey(const ValueKey('release_announcements_close')),
        );
      }
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(
        result,
        dismiss == 'checked'
            ? true
            : dismiss == 'unchecked'
            ? false
            : null,
      );
    });
  }

  testWidgets(
    'long announcement dialog scrolls at mobile size and large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => ReleaseAnnouncementsDialog(
                    entries: parseReleaseHistory(releaseHistoryFixture),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
          scale: 2,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('release_announcements_suppress')),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.byKey(const ValueKey('release_announcements_close')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ReleaseAnnouncementsDialog), findsNothing);
    },
  );

  testWidgets(
    'About history entry stays available after dismissal and shows notes',
    (tester) async {
      PackageInfo.setMockInitialValues(
        appName: 'CodeWalk',
        packageName: 'codewalk',
        version: '1.2.0',
        buildNumber: '1',
        buildSignature: '',
      );
      final local = InMemoryAppLocalDataSource()
        ..dismissedNewsVersion = '1.2.0';
      final settings = SettingsProvider(
        localDataSource: local,
        dioClient: ReleaseHistoryNoopDioClient(),
        soundService: SoundService(),
        releaseHistoryService: FakeReleaseHistoryService(),
      );
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        _app(const Scaffold(body: AboutSettingsSection()), settings: settings),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('settings_about_release_history')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ReleaseHistoryPage), findsOneWidget);
      expect(find.text('Future announcement'), findsOneWidget);
      await tester.tap(find.text('Changelog').first);
      await tester.pumpAndSettle();
      expect(find.text('- Future fix'), findsOneWidget);
      expect(local.dismissedNewsVersion, '1.2.0');
    },
  );

  testWidgets(
    'history handles loading, error, retry, empty and offline cache',
    (tester) async {
      final service = FakeReleaseHistoryService();
      final pending = Completer<ReleaseHistorySnapshot>();
      service.pending = pending.future;
      final settings = SettingsProvider(
        localDataSource: InMemoryAppLocalDataSource(),
        dioClient: ReleaseHistoryNoopDioClient(),
        soundService: SoundService(),
        releaseHistoryService: service,
      );
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        _app(const ReleaseHistoryPage(), settings: settings),
      );
      await tester.pump();
      expect(settings.releaseHistoryLoading, isTrue);
      pending.complete(const ReleaseHistorySnapshot(failed: true));
      service.pending = null;
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Unable to load release history'),
        findsOneWidget,
      );
      service.snapshot = const ReleaseHistorySnapshot();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('No release notes available.'), findsOneWidget);
      service.snapshot = ReleaseHistorySnapshot(
        entries: parseReleaseHistory(releaseHistoryFixture),
        failed: true,
      );
      await settings.loadReleaseHistory(forceRefresh: true);
      await tester.pumpAndSettle();
      expect(find.textContaining('Showing a saved copy'), findsOneWidget);
      expect(find.text('Future announcement'), findsOneWidget);
    },
  );
}
