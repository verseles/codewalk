import 'dart:async';
import 'dart:convert';

import 'package:codewalk/app/app_dependencies.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/settings/release_history_controller.dart';
import 'package:codewalk/features/settings/update_check_controller.dart';
import 'package:codewalk/features/settings/updates_settings_page.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/diagnostics/diagnostics_controller.dart';
import 'package:codewalk/shared/releases/release_source.dart';
import 'package:codewalk/shared/releases/update_selector.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../storage/storage_fakes.dart';

class ImmediateArchive implements ReleaseSource {
  String body = List.generate(
    25,
    (i) => '## v2.0.$i - 2026-10-09\n> 📣 Announcement $i\n\nNotes $i',
  ).join('\n');
  bool fail = false;
  int requests = 0;
  @override
  ReleaseSourceTask start({String? until}) {
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

/// Answers only when [release] is called, like a slow first download.
class HeldArchive extends ImmediateArchive {
  final _held = <Completer<ReleaseSourceResult>>[];
  @override
  ReleaseSourceTask start({String? until}) {
    requests++;
    final completer = Completer<ReleaseSourceResult>();
    _held.add(completer);
    return HeldTask(completer.future);
  }

  void release() {
    for (final completer in _held) {
      completer.complete(
        this.fail
            ? const ReleaseSourceResult.failure(
                ReleaseSourceFailure.unavailable,
              )
            : ReleaseSourceResult.success(body),
      );
    }
    _held.clear();
  }
}

class HeldTask implements ReleaseSourceTask {
  HeldTask(this.result);
  @override
  final Future<ReleaseSourceResult> result;
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
    'history under Version and updates, stale copy and resize keep the section',
    (tester) async {
      final source = ImmediateArchive();
      final graph = await mount(tester, source, width: 1280);
      await select(tester, 'updates');
      expect(source.requests, 1);
      expect(graph.releaseHistory!.entries.length, 25);
      expect(find.text('v2.0.0'), findsNothing);
      final more = find.byKey(const ValueKey('release_history_load_more'));
      await tester.scrollUntilVisible(
        more,
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('settings_updates_page')),
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
              of: find.byKey(const ValueKey('settings_updates_page')),
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
        find.byKey(const ValueKey('settings_release_history')),
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

  Rect viewport(WidgetTester tester) => tester.getRect(
    find
        .descendant(
          of: find.byKey(const ValueKey('settings_updates_page')),
          matching: find.byType(Scrollable),
        )
        .first,
  );

  Rect historyHeading(WidgetTester tester) => tester.getRect(
    find.descendant(
      of: find.byKey(const ValueKey('settings_release_history')),
      matching: find.text('Release history'),
    ),
  );

  testWidgets('one Version and updates destination holds the history (#519)', (
    tester,
  ) async {
    final source = ImmediateArchive();
    await mount(tester, source, width: 1280);
    expect(
      find.byKey(const ValueKey('settings_destination_releaseHistory')),
      findsNothing,
    );
    await tester.enterText(
      find.byKey(const ValueKey('settings_navigation_search')),
      'history',
    );
    await tester.pumpAndSettle();
    await select(tester, 'updates');
    expect(source.requests, 1, reason: 'opening the section loads history');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('settings_updates_page')),
        matching: find.byKey(const ValueKey('settings_release_history')),
      ),
      findsOneWidget,
    );
    expect(find.text('Announcement 24'), findsOneWidget);
  });

  testWidgets('About opens Version and updates at its history; the row opens '
      'it at the top', (tester) async {
    await mount(tester, ImmediateArchive());
    await select(tester, 'about');
    // A short window keeps the history below the updates controls.
    tester.view.physicalSize = const Size(390, 520);
    await tester.pumpAndSettle();
    final aboutHistory = find.descendant(
      of: find.byKey(const ValueKey('about_settings_list')),
      matching: find.text('Release history'),
    );
    await tester.ensureVisible(aboutHistory);
    await tester.pumpAndSettle();
    await tester.tap(aboutHistory);
    await tester.pumpAndSettle();
    final shown = viewport(tester);
    final heading = historyHeading(tester);
    expect(heading.top, greaterThanOrEqualTo(shown.top));
    expect(heading.bottom, lessThanOrEqualTo(shown.bottom));
    await tester.tap(find.byKey(const ValueKey('settings_detail_back')));
    tester.view.physicalSize = const Size(390, 1000);
    await tester.pumpAndSettle();
    await select(tester, 'updates');
    // Short enough that the history starts below the first screen (#551
    // took the page's own title away).
    tester.view.physicalSize = const Size(390, 440);
    await tester.pumpAndSettle();
    expect(
      historyHeading(tester).top,
      greaterThan(viewport(tester).bottom),
      reason: 'the destination itself opens at version and updates',
    );
  });

  // The page alone, reopened by changing [open] as the settings shell does.
  Future<ReleaseHistoryController> page(
    WidgetTester tester,
    ReleaseSource source,
    ValueNotifier<(int, bool)> open, {
    UpdateCheckController? updates,
  }) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    final history = ReleaseHistoryController(
      source: source,
      store: V2MetadataStore(backend: FakeMetadataBackend()),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      history.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiProvider(
            providers: [
              ChangeNotifierProvider<ReleaseHistoryController?>.value(
                value: history,
              ),
              ChangeNotifierProvider<UpdateCheckController?>.value(
                value: updates,
              ),
            ],
            child: ValueListenableBuilder(
              valueListenable: open,
              builder: (context, value, _) =>
                  UpdatesSettingsPage(request: value.$1, history: value.$2),
            ),
          ),
        ),
      ),
    );
    // A held load keeps its progress bar running, so no pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return history;
  }

  double offset(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const ValueKey('settings_updates_page')),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position
      .pixels;

  testWidgets('an open section scrolls to its history and back to the top', (
    tester,
  ) async {
    final open = ValueNotifier((1, false));
    addTearDown(open.dispose);
    await page(tester, ImmediateArchive(), open);
    expect(offset(tester), 0);
    open.value = (2, true);
    // One frame: the reveal jumps, leaving no animation a key could take over.
    await tester.pump();
    final jumped = offset(tester);
    await tester.pumpAndSettle();
    expect(jumped, greaterThan(0));
    expect(offset(tester), jumped);
    expect(historyHeading(tester).top, moreOrLessEquals(viewport(tester).top));
    open.value = (3, false);
    await tester.pumpAndSettle();
    expect(offset(tester), 0, reason: 'a plain opening shows the top');
  });

  testWidgets('the history stays in view while it loads, until the user '
      'scrolls', (tester) async {
    final source = HeldArchive();
    final open = ValueNotifier((1, true));
    addTearDown(open.dispose);
    final history = await page(tester, source, open);
    expect(offset(tester), 0, reason: 'nothing to scroll before the load');
    source.release();
    await tester.pumpAndSettle();
    expect(historyHeading(tester).top, moreOrLessEquals(viewport(tester).top));
    final anchored = offset(tester);
    await tester.drag(
      find.byKey(const ValueKey('settings_updates_page')),
      const Offset(0, 60),
    );
    await tester.pumpAndSettle();
    final scrolled = offset(tester);
    expect(scrolled, lessThan(anchored));
    source.fail = true;
    final refresh = history.load(forceRefresh: true);
    source.release();
    await refresh;
    await tester.pumpAndSettle();
    expect(history.failed, isTrue);
    expect(offset(tester), scrolled, reason: 'the user scrolled away');
  });

  testWidgets('an update card appearing above keeps the history in view', (
    tester,
  ) async {
    final releases = ImmediateArchive()
      ..body = jsonEncode([
        {
          'tag_name': 'v2.0.1',
          'draft': false,
          'prerelease': false,
          'assets': [
            for (final target in UpdateTarget.values)
              {
                'name': target.assetName,
                'browser_download_url':
                    'https://github.com/verseles/codewalk/releases/download/v2.0.1/${target.assetName}',
              },
          ],
        },
      ]);
    final updates = UpdateCheckController(
      source: releases,
      store: V2MetadataStore(backend: FakeMetadataBackend()),
      installedVersion: () async => '2.0.0',
      target: UpdateTarget.linuxX64,
    );
    addTearDown(updates.dispose);
    final open = ValueNotifier((1, true));
    addTearDown(open.dispose);
    await page(tester, ImmediateArchive(), open, updates: updates);
    await tester.pumpAndSettle();
    expect(historyHeading(tester).top, moreOrLessEquals(viewport(tester).top));
    await updates.check();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('updates_available')), findsOneWidget);
    expect(historyHeading(tester).top, moreOrLessEquals(viewport(tester).top));
  });

  testWidgets('keys, focus or a scrollbar moving the page release the '
      'history', (tester) async {
    final source = HeldArchive();
    final open = ValueNotifier((1, true));
    addTearDown(open.dispose);
    final history = await page(tester, source, open);
    source.release();
    await tester.pumpAndSettle();
    final position = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const ValueKey('settings_updates_page')),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    // The same programmatic move keyboard paging and focus traversal make.
    // Test time advances only while pumping, so the move is not awaited.
    unawaited(
      position.moveTo(
        position.pixels - 60,
        duration: const Duration(milliseconds: 100),
      ),
    );
    await tester.pumpAndSettle();
    final moved = offset(tester);
    source.fail = true;
    final refresh = history.load(forceRefresh: true);
    source.release();
    await refresh;
    await tester.pumpAndSettle();
    expect(offset(tester), moved);
  });

  testWidgets('the page keeps the route primary scroll for keyboard paging', (
    tester,
  ) async {
    final open = ValueNotifier((1, false));
    addTearDown(open.dispose);
    await page(tester, ImmediateArchive(), open);
    final primary = PrimaryScrollController.of(
      tester.element(find.byKey(const ValueKey('settings_updates_page'))),
    );
    expect(primary.hasClients, isTrue);
    open.value = (2, true);
    await tester.pumpAndSettle();
    expect(primary.offset, offset(tester));
  });

  for (final locale in [const Locale('ar'), const Locale('ur')]) {
    testWidgets('RTL history $locale preserves text with enlarged layout', (
      tester,
    ) async {
      await mount(tester, ImmediateArchive(), locale: locale);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await select(tester, 'updates');
      expect(find.text('Announcement 24'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
