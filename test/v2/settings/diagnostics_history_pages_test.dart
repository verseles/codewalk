import 'package:codewalk/app/app_dependencies.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/diagnostics/diagnostics_controller.dart';
import 'package:codewalk/shared/releases/release_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';

class ImmediateArchive implements ReleaseSource {
  String body = List.generate(
    25,
    (i) => '## v2.0.$i - 2026-10-09\n> 📣 Announcement $i\n\nNotes $i',
  ).join('\n');
  bool fail = false;
  int requests = 0;
  @override
  ReleaseSourceTask start() {
    requests++;
    return ImmediateTask(
      fail
          ? const ReleaseSourceResult.failure(ReleaseSourceFailure.unavailable)
          : ReleaseSourceResult.success(body),
    );
  }

  @override
  void close() {}
}

class ImmediateTask implements ReleaseSourceTask {
  ImmediateTask(this.value);
  final ReleaseSourceResult value;
  @override
  Future<ReleaseSourceResult> get result async => value;
  @override
  void cancel() {}
}

void main() {
  Future<AppDependencies> mount(
    WidgetTester tester,
    ImmediateArchive source, {
    double width = 390,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    final graph = createAppDependencies(
      initialLink: Uri(path: '/settings'),
      metadataStore: V2MetadataStore(backend: FakeMetadataBackend()),
      releaseSource: source,
    );
    await graph.preferences.initialize();
    graph.preferences.setLocale(locale);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      graph.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      CodeWalkV2Bootstrap(
        dependencies: graph,
        dynamicColors: (builder) => builder(null, null),
      ),
    );
    await tester.pumpAndSettle();
    return graph;
  }

  Future<void> select(WidgetTester tester, String section) async {
    final row = find.byKey(ValueKey('settings_destination_$section'));
    await tester.scrollUntilVisible(
      row,
      150,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('settings_destinations')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  testWidgets('compact log opt-in and finite filtered clipboard are explicit', (
    tester,
  ) async {
    final graph = await mount(tester, ImmediateArchive());
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await select(tester, 'logs');
    expect(graph.diagnostics!.enabled, isFalse);
    await tester.tap(find.byKey(const ValueKey('settings_logging_enabled')));
    await tester.pumpAndSettle();
    graph.diagnostics!.record(
      DiagnosticOperation.hostProbe,
      DiagnosticOutcome.failure,
    );
    await tester.pumpAndSettle();
    final copy = find.byKey(const ValueKey('logs_copy_filtered'));
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pumpAndSettle();
    expect(copied, contains('hostProbe'));
    expect(copied, isNot(contains('Authorization')));
    await tester.ensureVisible(
      find.byKey(const ValueKey('settings_logging_enabled')),
    );
    await tester.tap(find.byKey(const ValueKey('settings_logging_enabled')));
    await tester.pumpAndSettle();
    expect(graph.diagnostics!.events, isEmpty);
    await tester.tap(find.byKey(const ValueKey('settings_detail_back')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('settings_navigation_search')),
      findsOneWidget,
    );
  });

  testWidgets(
    'history pages, stale copy and resize preserve the open section',
    (tester) async {
      final source = ImmediateArchive();
      final graph = await mount(tester, source, width: 1280);
      await select(tester, 'releaseHistory');
      expect(source.requests, 1);
      expect(graph.releaseHistory!.entries.length, 25);
      expect(find.text('v2.0.0'), findsNothing);
      final more = find.byKey(const ValueKey('release_history_load_more'));
      await tester.scrollUntilVisible(
        more,
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('settings_release_history_page')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(more);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('v2.0.0'),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('settings_release_history_page')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('v2.0.0'), findsOneWidget);
      source.fail = true;
      await graph.releaseHistory!.load(forceRefresh: true);
      await tester.pumpAndSettle();
      expect(graph.releaseHistory!.failed, isTrue);
      expect(graph.releaseHistory!.entries.length, 25);
      tester.view.physicalSize = const Size(390, 1000);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings_release_history_page')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('settings_detail_back')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings_navigation_search')),
        findsOneWidget,
      );
    },
  );

  for (final locale in [const Locale('ar'), const Locale('ur')]) {
    testWidgets('RTL history $locale preserves text with enlarged layout', (
      tester,
    ) async {
      await mount(tester, ImmediateArchive(), locale: locale);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await select(tester, 'releaseHistory');
      expect(find.text('Announcement 24'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
