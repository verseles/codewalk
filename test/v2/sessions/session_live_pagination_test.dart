import 'dart:async';

import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/sessions/session_history_page.dart';
import 'package:codewalk/features/sessions/session_timeline_tile.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../hosts/fakes.dart';
import 'fakes.dart';
import 'history_fakes.dart';
import 'live_fakes.dart';
import 'workspace_support.dart';

/// The rows `m<from>`..`m<to - 1>` of a long session, in chronological order.
/// Their heights differ, like real answers, so an anchor cannot hold by luck.
List<TimelineItem> _rows(SessionRef ref, int from, int to) => [
  for (var i = from; i < to; i++)
    AssistantText(
      meta: liveMeta(ref, 'm$i'),
      text: 'row $i${' word' * (i % 5 * 9)}',
      complete: true,
    ),
];

/// A live session of [total] rows whose window starts with the newest 200
/// and pages older ones in 200 at a time, keeping the newest 500, as the
/// stream owner does.
final class _Session {
  _Session(this.ref, {this.total = 2000});
  final SessionRef ref;
  final int total;
  late int first = total - 200;
  int pages = 0;
  Completer<void>? gate;
  List<TimelineItem> extra = const [];

  String? get cursor => first > 0 ? '$first' : null;

  SessionLiveView view() => SessionLiveView(
    session: ref,
    phase: SessionLivePhase.live,
    state: liveState(
      ref,
      items: [..._rows(ref, first, total), ...extra],
      execution: const ExecutionState(
        kind: OpenValue.known(ExecutionKind.idle),
      ),
      cursor: cursor,
      // Like the reducer: a partial page never clears the flag.
      hasMore: pages > 0,
    ),
  );

  /// One older page: the newest 500 stay resident.
  Future<SessionLiveFailure?> page(LiveHandle handle) async {
    pages++;
    await gate?.future;
    final older = (first - 200).clamp(0, total);
    first = total - 500 > older ? total - 500 : older;
    handle.emit(view());
    return null;
  }
}

Future<({CatalogRig rig, LiveHandle handle, _Session session})> _open(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  int total = 2000,
  List<HistorySource>? histories,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final rig = CatalogRig();
  await rig.save('a');
  final directory = LiveDirectory();
  final dependencies = createAppDependencies(
    initialLink: Uri(path: '/sessions'),
    profileRepository: rig.repository,
    endpointProber: FakeProber(),
    sessionCatalogFactory: rig.create,
    sessionLiveDirectory: () => directory,
    sessionHistoryFactory: (p, c, ref) {
      final source = HistorySource(ref);
      histories?.add(source);
      return source;
    },
  );
  await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: dependencies));
  await showSessionList(tester);
  final read = dependencies.sessions!.selectProfile('profile_a');
  final catalog = rig.sources.single;
  final row = catalog.row('one', title: 'One');
  catalog.respond([row]);
  await read;
  await tester.pumpAndSettle();
  final button = find.byKey(ValueKey('live-open-${row.info.ref.storageKey}'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
  await tester.pump();
  final handle = directory.grant(row.info.ref);
  final session = _Session(row.info.ref, total: total);
  handle.olderAction = () => session.page(handle);
  await tester.pump();
  handle.emit(session.view());
  await tester.pumpAndSettle();
  return (rig: rig, handle: handle, session: session);
}

ScrollController _controller(WidgetTester tester) =>
    tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;

/// The reader scrolls up to the top: away from it first, then to it.
Future<void> _reachTop(WidgetTester tester) async {
  final controller = _controller(tester);
  // In steps, as a reader scrolls: the extent above the rows already laid
  // out is an estimate that firms up as the rows come into view.
  for (var step = 0; step < 200; step++) {
    final position = controller.position;
    final target = position.minScrollExtent + 400;
    if (position.pixels <= target + 0.5) break;
    controller.jumpTo(
      position.pixels - 1500 < target ? target : position.pixels - 1500,
    );
    await tester.pump();
  }
  await tester.drag(find.byType(CustomScrollView), const Offset(0, 380));
  await tester.pump();
}

/// The first row label fully inside the viewport, and its vertical position.
(String, double) _anchor(WidgetTester tester) {
  final top = tester.getTopLeft(find.byType(CustomScrollView)).dy;
  final rows = <(String, double)>[];
  for (final element in find.byType(SessionTimelineTile).evaluate()) {
    final box = element.renderObject! as RenderBox;
    final dy = box.localToGlobal(Offset.zero).dy;
    final tile = element.widget as SessionTimelineTile;
    if (dy >= top + 40) rows.add((tile.item.id.value, dy));
  }
  rows.sort((a, b) => a.$2.compareTo(b.$2));
  return rows.first;
}

double _dyOf(WidgetTester tester, String id) {
  final element = find
      .byType(SessionTimelineTile)
      .evaluate()
      .firstWhere((e) => (e.widget as SessionTimelineTile).item.id.value == id);
  return (element.renderObject! as RenderBox).localToGlobal(Offset.zero).dy;
}

void main() {
  testWidgets('reaching the top reads one older page, with the pill', (
    tester,
  ) async {
    final live = await _open(tester);
    live.session.gate = Completer<void>();
    await _reachTop(tester);
    expect(live.handle.olderLoads, 1);
    expect(find.byKey(const ValueKey('live-older-loading')), findsOneWidget);
    // Staying at the top asks for nothing more while the page is read.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 40));
    await tester.pump();
    expect(live.handle.olderLoads, 1);
    live.session.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('live-older-loading')), findsNothing);
    expect(live.session.first, 1600);
    await tester.pumpWidget(const SizedBox.shrink());
    live.rig.dispose();
  });

  testWidgets('an older page keeps the row the reader is reading', (
    tester,
  ) async {
    for (final size in const [Size(390, 844), Size(1280, 800)]) {
      final live = await _open(tester, size: size);
      live.session.gate = Completer<void>();
      await _reachTop(tester);
      final (id, before) = _anchor(tester);
      live.session.gate!.complete();
      await tester.pumpAndSettle();
      expect((_dyOf(tester, id) - before).abs(), lessThanOrEqualTo(1));
      // The page is history, not an arrival: nothing is marked below.
      final jump = find.byKey(const ValueKey('live-jump-latest'));
      expect(
        tester.widget<FloatingActionButton>(jump).child,
        isA<Icon>().having(
          (icon) => icon.icon,
          'icon',
          Icons.arrow_downward_rounded,
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      live.rig.dispose();
    }
  });

  testWidgets('a live row that lands during the read is still an arrival', (
    tester,
  ) async {
    final live = await _open(tester);
    live.session.gate = Completer<void>();
    await _reachTop(tester);
    final (id, before) = _anchor(tester);
    live.session.extra = [
      AssistantText(
        meta: liveMeta(live.session.ref, 'late'),
        text: 'late',
        complete: true,
      ),
    ];
    live.session.gate!.complete();
    await tester.pumpAndSettle();
    expect((_dyOf(tester, id) - before).abs(), lessThanOrEqualTo(1));
    final jump = find.byKey(const ValueKey('live-jump-latest'));
    expect(
      tester.widget<FloatingActionButton>(jump).child,
      isA<Icon>().having((icon) => icon.icon, 'icon', Icons.mark_chat_unread),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    live.rig.dispose();
  });

  testWidgets(
    'the 2,000-row session stops at 500 resident and offers the history',
    (tester) async {
      final histories = <HistorySource>[];
      final live = await _open(tester, histories: histories);
      for (var round = 0; round < 4; round++) {
        final pages = live.session.pages;
        live.session.gate = Completer<void>();
        await _reachTop(tester);
        // The rows above settle their estimated extent first; the anchor is
        // taken once they did, so only the page can move it.
        await tester.pump(const Duration(seconds: 1));
        final (id, before) = _anchor(tester);
        live.session.gate!.complete();
        await tester.pumpAndSettle();
        if (live.session.pages > pages) {
          expect((_dyOf(tester, id) - before).abs(), lessThanOrEqualTo(1));
        }
      }
      // Two older pages fill the window; the newest rows were never evicted.
      expect(live.session.pages, 2);
      final state = live.handle.current.state!;
      expect(state.timeline, hasLength(500));
      expect(state.timeline.first.id.value, contains('m1500'));
      expect(state.timeline.last.id.value, contains('m1999'));
      // Only the rows near the viewport are mounted.
      expect(
        find.byType(SessionTimelineTile).evaluate().length,
        lessThanOrEqualTo(40),
      );
      // The window holds all it can: the history viewer is the way back.
      expect(find.byKey(const ValueKey('live-history-limit')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('live-open-history')));
      // The viewer's first read stays pending, so its progress keeps moving.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(SessionHistoryPage), findsOneWidget);
      expect(histories, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      live.rig.dispose();
    },
  );

  testWidgets('a failed page keeps the rows and offers a retry', (
    tester,
  ) async {
    final live = await _open(tester);
    live.handle.olderAction = () async => SessionLiveFailure.timeout;
    await _reachTop(tester);
    await tester.pumpAndSettle();
    expect(live.handle.current.state!.timeline, hasLength(200));
    live.handle.olderAction = () => live.session.page(live.handle);
    final retry = find.byKey(const ValueKey('live-older-retry'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(live.session.first, 1600);
    await tester.pumpWidget(const SizedBox.shrink());
    live.rig.dispose();
  });

  testWidgets('a session loaded to its first row shows no limit', (
    tester,
  ) async {
    final live = await _open(tester, total: 300);
    await _reachTop(tester);
    await tester.pumpAndSettle();
    expect(live.session.first, 0);
    expect(live.handle.current.state!.hasMoreHistory, isTrue);
    expect(find.byKey(const ValueKey('live-history-limit')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    live.rig.dispose();
  });

  testWidgets('a window that lost rows in front keeps the history fallback', (
    tester,
  ) async {
    final live = await _open(tester, total: 300);
    await _reachTop(tester);
    await tester.pumpAndSettle();
    expect(live.session.cursor, isNull);
    // The owner knows rows were trimmed in front, whatever the cursor says.
    live.handle.olderHistory = const SessionOlderHistoryState(trimmed: true);
    live.handle.emit(live.session.view());
    await tester.pumpAndSettle();
    // The block tops the older rows, above the reader.
    final controller = _controller(tester);
    for (var step = 0; step < 200; step++) {
      final position = controller.position;
      if (position.pixels <= position.minScrollExtent + 0.5) break;
      controller.jumpTo(
        position.pixels - 1500 < position.minScrollExtent
            ? position.minScrollExtent
            : position.pixels - 1500,
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('live-history-limit')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    live.rig.dispose();
  });

  testWidgets('a window paused while not live shows no limit', (
    tester,
  ) async {
    final live = await _open(tester);
    final view = live.handle.current;
    live.handle.emit(
      SessionLiveView(
        session: view.session,
        phase: SessionLivePhase.reconnecting,
        stale: true,
        lastSyncedAt: DateTime.utc(2026, 10, 21),
        state: view.state,
      ),
    );
    await tester.pumpAndSettle();
    await _reachTop(tester);
    await tester.pumpAndSettle();
    expect(live.handle.olderLoads, 0);
    expect(find.byKey(const ValueKey('live-history-limit')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    live.rig.dispose();
  });

  testWidgets('a short session never pages and shows no limit', (
    tester,
  ) async {
    final live = await _open(tester, total: 150);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(live.handle.olderLoads, 0);
    expect(find.byKey(const ValueKey('live-history-limit')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    live.rig.dispose();
  });
}
