import 'dart:async';
import 'dart:convert';

import 'package:codewalk/core/logging/app_logger.dart';
import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/presentation/pages/logs_page.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:codewalk/presentation/services/sound_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';
import '../support/pump_localized_app.dart';

class _GatedLoggingStore extends InMemoryAppLocalDataSource {
  final gate = Completer<void>();
  @override
  Future<void> saveExperienceSettingsJson(String settingsJson) async {
    await gate.future;
    await super.saveExperienceSettingsJson(settingsJson);
  }
}

void main() {
  testWidgets(
    'logging flags repaint before persistence without inherited forwarding',
    (tester) async {
      final store = _GatedLoggingStore();
      final settings = SettingsProvider(
        localDataSource: store,
        dioClient: DioClient(),
        soundService: SoundService(),
      );
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        localizedMaterialApp(
          home: InheritedProvider<SettingsProvider>.value(
            value: settings,
            child: const LogsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final enable = settings.setLoggingEnabled(true);
      await tester.pump();
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('settings_logs_enabled')),
            )
            .value,
        isTrue,
      );
      expect(find.text('Logging is disabled'), findsNothing);
      expect(store.experienceSettingsJson, isNull);
      final perf = settings.setPerformanceLoggingEnabled(true);
      await tester.pump();
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('settings_logs_performance')),
            )
            .value,
        isTrue,
      );
      store.gate.complete();
      await Future.wait([enable, perf]);
      await settings.setLoggingEnabled(false);
      await tester.pump();
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('settings_logs_enabled')),
            )
            .value,
        isFalse,
      );
      expect(find.text('Logging is disabled'), findsOneWidget);
    },
  );
  setUp(() {
    AppLogger.clearEntries();
    AppLogger.setLoggingEnabled(false);
    AppLogger.setPerformanceLoggingEnabled(false);
  });

  tearDown(() {
    AppLogger.clearEntries();
    AppLogger.setLoggingEnabled(false);
    AppLogger.setPerformanceLoggingEnabled(false);
  });

  SettingsProvider buildSettingsProvider(InMemoryAppLocalDataSource local) {
    return SettingsProvider(
      localDataSource: local,
      dioClient: DioClient(),
      soundService: SoundService(),
    );
  }

  Widget logsPageWithProvider(SettingsProvider provider) {
    return ChangeNotifierProvider<SettingsProvider>.value(
      value: provider,
      child: const LogsPage(),
    );
  }

  testWidgets('renders, filters, and clears logs', (tester) async {
    final provider = buildSettingsProvider(InMemoryAppLocalDataSource());
    await provider.setLoggingEnabled(true);
    AppLogger.info('alpha message');
    AppLogger.warn('beta message');

    await tester.pumpWidget(
      localizedMaterialApp(home: logsPageWithProvider(provider)),
    );
    await tester.pumpAndSettle();

    expect(find.text('App Logs'), findsOneWidget);
    expect(find.textContaining('Showing 4 of 4 entries'), findsOneWidget);

    await tester.tap(find.byTooltip('Search logs'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'beta');
    await tester.pumpAndSettle();

    expect(find.textContaining('Showing 1 of 4 entries'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear logs'));
    await tester.pumpAndSettle();

    expect(find.text('No logs captured yet.'), findsOneWidget);
  });

  testWidgets('defaults app logging off and toggles collection', (
    tester,
  ) async {
    final local = InMemoryAppLocalDataSource();
    final provider = buildSettingsProvider(local);

    AppLogger.info('hidden message');

    await tester.pumpWidget(
      localizedMaterialApp(home: logsPageWithProvider(provider)),
    );
    await tester.pumpAndSettle();

    expect(provider.loggingEnabled, isFalse);
    expect(AppLogger.loggingEnabled, isFalse);
    expect(AppLogger.entries.value, isEmpty);
    expect(find.text('Logging is disabled'), findsOneWidget);

    await tester.ensureVisible(find.text('Enable logging'));
    await tester.tap(find.text('Enable logging'));
    await tester.pumpAndSettle();

    expect(provider.loggingEnabled, isTrue);
    expect(AppLogger.loggingEnabled, isTrue);
    final persistedEnabled = jsonDecode(local.experienceSettingsJson!);
    expect(persistedEnabled['loggingEnabled'], isTrue);

    AppLogger.info('visible message');
    await tester.pumpAndSettle();

    expect(find.textContaining('visible message'), findsOneWidget);

    await tester.ensureVisible(find.text('Enable app logging'));
    await tester.tap(find.text('Enable app logging'));
    await tester.pumpAndSettle();

    expect(provider.loggingEnabled, isFalse);
    expect(AppLogger.loggingEnabled, isFalse);
    expect(AppLogger.entries.value, isEmpty);
    final persistedDisabled = jsonDecode(local.experienceSettingsJson!);
    expect(persistedDisabled['loggingEnabled'], isFalse);

    AppLogger.info('hidden again');
    await tester.pumpAndSettle();

    expect(AppLogger.entries.value, isEmpty);
    expect(find.textContaining('hidden again'), findsNothing);
  });

  testWidgets('toggles, persists, and filters performance logs', (
    tester,
  ) async {
    final local = InMemoryAppLocalDataSource();
    final provider = buildSettingsProvider(local);

    await tester.pumpWidget(
      localizedMaterialApp(home: logsPageWithProvider(provider)),
    );
    await tester.pumpAndSettle();

    expect(provider.loggingEnabled, isFalse);
    expect(AppLogger.loggingEnabled, isFalse);
    expect(find.text('Logging is disabled'), findsOneWidget);

    await tester.ensureVisible(find.text('Enable app logging'));
    await tester.tap(find.text('Enable app logging'));
    await tester.pumpAndSettle();

    expect(provider.loggingEnabled, isTrue);
    expect(AppLogger.loggingEnabled, isTrue);

    expect(provider.performanceLoggingEnabled, isFalse);
    expect(AppLogger.performanceLoggingEnabled, isFalse);

    await tester.ensureVisible(find.text('Measure performance'));
    await tester.tap(find.text('Measure performance'));
    await tester.pumpAndSettle();

    expect(provider.performanceLoggingEnabled, isTrue);
    expect(AppLogger.performanceLoggingEnabled, isTrue);
    final persisted = jsonDecode(local.experienceSettingsJson!);
    expect(persisted['performanceLoggingEnabled'], isTrue);

    AppLogger.info('regular message');
    await AppLogger.runPerformanceTask('load_messages', () async {});
    await tester.pumpAndSettle();

    expect(find.textContaining('PERFORMANCE load_messages'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('regular message'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('regular message'), findsOneWidget);

    await tester.ensureVisible(find.text('Performance'));
    await tester.tap(find.text('Performance'));
    await tester.pumpAndSettle();

    expect(find.textContaining('regular message'), findsNothing);
    expect(find.textContaining('PERFORMANCE load_messages'), findsOneWidget);

    await tester.tap(find.byTooltip('Slowest performance logs'));
    await tester.pumpAndSettle();

    expect(find.text('Slowest performance logs'), findsOneWidget);
    expect(find.text('load_messages'), findsOneWidget);
  });

  testWidgets('filters by task tag and opens slowest tasks', (tester) async {
    final provider = buildSettingsProvider(InMemoryAppLocalDataSource());
    await provider.setLoggingEnabled(true);

    AppLogger.info('regular message');
    final task = AppLogger.beginTask('select_session');
    task.end();

    await tester.pumpWidget(
      localizedMaterialApp(home: logsPageWithProvider(provider)),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.textContaining('regular message'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('regular message'), findsOneWidget);

    await tester.ensureVisible(find.text('task:select_session'));
    await tester.tap(find.text('task:select_session'));
    await tester.pumpAndSettle();

    expect(find.textContaining('regular message'), findsNothing);
    expect(find.textContaining('TASK select_session'), findsOneWidget);
    expect(find.textContaining('Showing 2 of 5 entries'), findsOneWidget);

    await tester.tap(find.byTooltip('Slowest tasks'));
    await tester.pumpAndSettle();

    expect(find.text('Slowest tasks'), findsOneWidget);
    expect(find.textContaining('select_session'), findsWidgets);
  });

  testWidgets('adds and displays a custom tag filter', (tester) async {
    final provider = buildSettingsProvider(InMemoryAppLocalDataSource());
    await provider.setLoggingEnabled(true);

    AppLogger.info('custom tagged message', tags: const <String>{'custom:tag'});
    AppLogger.info('plain message');

    await tester.pumpWidget(
      localizedMaterialApp(home: logsPageWithProvider(provider)),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Custom...'));
    await tester.tap(find.text('Custom...'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'custom:tag');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('custom:tag'), findsOneWidget);
    expect(find.textContaining('custom tagged message'), findsOneWidget);
    expect(find.textContaining('plain message'), findsNothing);
  });
}
