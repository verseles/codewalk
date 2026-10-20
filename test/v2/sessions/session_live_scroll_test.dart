import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/sessions/session_live_scroll.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../hosts/fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';

/// The assistant answers of a session, one per row.
List<TimelineItem> _answers(
  SessionRef ref,
  int count, {
  String text = 'row',
}) => [
  for (var i = 0; i < count; i++)
    AssistantText(meta: liveMeta(ref, 'a$i'), text: '$text $i', complete: true),
];

const _delivered = OpenValue<DeliveryState>.known(DeliveryState.delivered);

ScrollController _controller(WidgetTester tester) =>
    tester.widget<ListView>(find.byType(ListView)).controller!;

/// Opens the live screen with [items] and returns the lease, so a test can
/// push a live update.
Future<({CatalogRig rig, LiveHandle handle, SessionRef ref})> _openLive(
  WidgetTester tester,
  List<TimelineItem> Function(SessionRef ref) items, {
  Size size = const Size(390, 844),
  Locale? locale,
  double textScale = 1,
  bool settled = true,
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
  );
  if (locale != null) dependencies.preferences.setLocale(locale);
  Widget app(double scale) => MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: CodeWalkV2Bootstrap(dependencies: dependencies),
  );
  // The catalog is reached at the regular scale; the live screen is then
  // laid out at the requested one.
  await tester.pumpWidget(app(1));
  await tester.pumpAndSettle();
  final read = dependencies.sessions!.selectProfile('profile_a');
  final catalog = rig.sources.single;
  final row = catalog.row('one', title: 'One');
  catalog.respond([row]);
  await read;
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey(row.info.ref)));
  await tester.pumpAndSettle();
  final button = find.byKey(ValueKey('live-open-${row.info.ref.storageKey}'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
  await tester.pump();
  final ref = row.info.ref;
  final handle = directory.grant(ref);
  await tester.pump();
  if (textScale != 1) {
    await tester.pumpWidget(app(textScale));
    await tester.pump();
  }
  handle.emit(
    SessionLiveView(
      session: ref,
      phase: SessionLivePhase.live,
      state: liveState(
        ref,
        items: items(ref),
        execution: ExecutionState(
          kind: OpenValue.known(
            settled ? ExecutionKind.idle : ExecutionKind.running,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (rig: rig, handle: handle, ref: ref);
}

void main() {
  group('the live timeline', () {
    testWidgets('the list opens on the newest content', (tester) async {
      final live = await _openLive(tester, (ref) => _answers(ref, 2));
      final list = tester.widget<ListView>(find.byType(ListView));
      final controller = list.controller!;
      expect(controller.offset, controller.position.maxScrollExtent);
      expect(find.text('row 1'), findsOneWidget);
      expect(find.byKey(const ValueKey('live-jump-latest')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      live.rig.dispose();
    });

    testWidgets('a live update follows the newest content', (tester) async {
      final live = await _openLive(tester, (ref) => _answers(ref, 1));
      final list = tester.widget<ListView>(find.byType(ListView));
      final controller = list.controller!;
      expect(controller.offset, controller.position.maxScrollExtent);
      live.handle.emit(
        SessionLiveView(
          session: live.ref,
          phase: SessionLivePhase.live,
          state: liveState(
            live.ref,
            items: _answers(live.ref, 2),
            execution: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.running),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.offset, controller.position.maxScrollExtent);
      expect(find.text('row 1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      live.rig.dispose();
    });

    testWidgets('a user scroll keeps the content and offers the control', (
      tester,
    ) async {
      final live = await _openLive(tester, (ref) => _answers(ref, 40));
      final list = tester.widget<ListView>(find.byType(ListView));
      final controller = list.controller!;
      final bottom = controller.position.maxScrollExtent;
      expect(bottom, greaterThan(0));

      // The reader scrolls up by a drag: the timeline stays where the reader
      // put it and the control appears.
      await tester.drag(find.byType(ListView), const Offset(0, 120));
      await tester.pumpAndSettle();
      expect(controller.offset, lessThan(bottom));
      expect(find.byKey(const ValueKey('live-jump-latest')), findsOneWidget);

      // A live update does not pull the content away from the reader.
      live.handle.emit(
        SessionLiveView(
          session: live.ref,
          phase: SessionLivePhase.live,
          state: liveState(
            live.ref,
            items: _answers(live.ref, 41),
            execution: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.running),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.offset, lessThan(controller.position.maxScrollExtent));
      await tester.pumpWidget(const SizedBox.shrink());
      live.rig.dispose();
    });

    testWidgets('the control returns to the newest content', (tester) async {
      final live = await _openLive(tester, (ref) => _answers(ref, 40));
      final list = tester.widget<ListView>(find.byType(ListView));
      final controller = list.controller!;
      await tester.drag(find.byType(ListView), const Offset(0, 120));
      await tester.pumpAndSettle();
      final control = find.byKey(const ValueKey('live-jump-latest'));
      expect(control, findsOneWidget);
      await tester.tap(control);
      await tester.pumpAndSettle();
      expect(controller.offset, controller.position.maxScrollExtent);
      expect(find.byKey(const ValueKey('live-jump-latest')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      live.rig.dispose();
    });

    testWidgets('the control is offered in a right-to-left locale', (
      tester,
    ) async {
      final live = await _openLive(
        tester,
        (ref) => _answers(ref, 40),
        locale: const Locale('ar'),
      );
      await tester.drag(find.byType(ListView), const Offset(0, 120));
      await tester.pumpAndSettle();
      final control = find.byKey(const ValueKey('live-jump-latest'));
      expect(control, findsOneWidget);
      final context = tester.element(control);
      expect(Directionality.of(context), TextDirection.rtl);
      await tester.pumpWidget(const SizedBox.shrink());
      live.rig.dispose();
    });

    testWidgets('a settled answer taller than the viewport is revealed', (
      tester,
    ) async {
      final live = await _openLive(
        tester,
        (ref) => [
          AssistantText(
            meta: liveMeta(ref, 'a1'),
            text: 'a long answer ' * 200,
            complete: true,
          ),
        ],
      );
      final list = tester.widget<ListView>(find.byType(ListView));
      final controller = list.controller!;
      // The answer starts at the top of the viewport, not at its end.
      expect(controller.offset, lessThan(controller.position.maxScrollExtent));
      expect(find.byKey(const ValueKey('live-jump-latest')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      live.rig.dispose();
    });
  });

  group('the live timeline, streaming and turns', () {
    testWidgets('a growing answer is followed without a new item', (
      tester,
    ) async {
      final rig = await _openLive(tester, (ref) => _answers(ref, 30));
      final controller = _controller(tester);
      expect(controller.offset, controller.position.maxScrollExtent);
      // The same item grows, as a streamed answer does.
      rig.handle.emit(
        SessionLiveView(
          session: rig.ref,
          phase: SessionLivePhase.live,
          state: liveState(
            rig.ref,
            items: [
              ..._answers(rig.ref, 29),
              AssistantText(
                meta: liveMeta(rig.ref, 'a29'),
                text: 'row 29 ${'streamed ' * 120}',
                complete: false,
              ),
            ],
            execution: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.running),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.offset, controller.position.maxScrollExtent);
      expect(find.byKey(const ValueKey('live-jump-latest')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      rig.rig.dispose();
    });

    testWidgets('content under a reader marks the control', (tester) async {
      final rig = await _openLive(tester, (ref) => _answers(ref, 40));
      final controller = _controller(tester);
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();
      final before = controller.offset;
      rig.handle.emit(
        SessionLiveView(
          session: rig.ref,
          phase: SessionLivePhase.live,
          state: liveState(
            rig.ref,
            items: _answers(rig.ref, 42),
            execution: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.running),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.offset, before);
      final fab = tester.widget<FloatingActionButton>(
        find.byKey(const ValueKey('live-jump-latest')),
      );
      final scheme = Theme.of(
        tester.element(find.byKey(const ValueKey('live-jump-latest'))),
      ).colorScheme;
      expect(fab.backgroundColor, scheme.primary);
      await tester.pumpWidget(const SizedBox.shrink());
      rig.rig.dispose();
    });

    testWidgets('a wheel scroll keeps priority like a drag', (tester) async {
      final rig = await _openLive(
        tester,
        (ref) => _answers(ref, 40),
        size: const Size(1280, 800),
      );
      final controller = _controller(tester);
      final bottom = controller.position.maxScrollExtent;
      final center = tester.getCenter(find.byType(ListView));
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(center));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -200)));
      await tester.pumpAndSettle();
      expect(controller.offset, lessThan(bottom));
      expect(find.byKey(const ValueKey('live-jump-latest')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      rig.rig.dispose();
    });

    testWidgets('a drag that cannot leave the bottom keeps the follow', (
      tester,
    ) async {
      final rig = await _openLive(tester, (ref) => _answers(ref, 40));
      // Dragging up at the tail cannot move past it.
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('live-jump-latest')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      rig.rig.dispose();
    });

    testWidgets('a long answer after many items is revealed from its start', (
      tester,
    ) async {
      final rig = await _openLive(
        tester,
        (ref) => [
          ..._answers(ref, 30, text: 'earlier'),
          UserInput(
            meta: liveMeta(ref, 'u1'),
            text: 'question',
            delivery: _delivered,
          ),
          AssistantText(
            meta: liveMeta(ref, 'final'),
            text: 'final answer ${'body ' * 400}',
            complete: true,
          ),
        ],
      );
      final controller = _controller(tester);
      expect(controller.offset, lessThan(controller.position.maxScrollExtent));
      expect(find.textContaining('final answer'), findsOneWidget);
      expect(find.byKey(const ValueKey('live-jump-latest')), findsNothing);

      // A new turn starts: the revealed answer was the timeline's place, so
      // the follow returns to the newest content.
      rig.handle.emit(
        SessionLiveView(
          session: rig.ref,
          phase: SessionLivePhase.live,
          state: liveState(
            rig.ref,
            items: [
              ..._answers(rig.ref, 30, text: 'earlier'),
              UserInput(
                meta: liveMeta(rig.ref, 'u1'),
                text: 'question',
                delivery: _delivered,
              ),
              AssistantText(
                meta: liveMeta(rig.ref, 'final'),
                text: 'final answer ${'body ' * 400}',
                complete: true,
              ),
              UserInput(
                meta: liveMeta(rig.ref, 'u2'),
                text: 'follow-up',
                delivery: _delivered,
              ),
            ],
            execution: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.running),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.offset, controller.position.maxScrollExtent);
      expect(find.text('follow-up'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      rig.rig.dispose();
    });

    testWidgets('a running session is never revealed', (tester) async {
      final rig = await _openLive(
        tester,
        (ref) => [
          AssistantText(
            meta: liveMeta(ref, 'a1'),
            text: 'a long answer ' * 200,
            complete: false,
          ),
        ],
        settled: false,
      );
      final controller = _controller(tester);
      expect(controller.offset, controller.position.maxScrollExtent);
      await tester.pumpWidget(const SizedBox.shrink());
      rig.rig.dispose();
    });

    testWidgets('the timeline fits a compact 2x right-to-left layout', (
      tester,
    ) async {
      final rig = await _openLive(
        tester,
        (ref) => _answers(ref, 20, text: 'صف'),
        locale: const Locale('ar'),
        textScale: 2,
      );
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();
      final control = find.byKey(const ValueKey('live-jump-latest'));
      expect(control, findsOneWidget);
      // The control sits at the end edge, which is the left in Arabic.
      final list = tester.getRect(find.byType(ListView));
      expect(tester.getCenter(control).dx, lessThan(list.center.dx));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      rig.rig.dispose();
    });
  });

  group('the scroll rules', () {
    test('the follow stops when the user scrolls', () {
      final scroll = SessionLiveScroll(now: () => DateTime.utc(2026, 10, 20));
      expect(scroll.following, isTrue);
      expect(scroll.mayFollow, isTrue);
      scroll.markUserIntent();
      expect(scroll.following, isFalse);
      expect(scroll.mayFollow, isFalse);
      // The intent holds for the retained reference's window.
      expect(scroll.hasUserIntent, isTrue);
    });

    test('the content that grows under a reader is marked', () {
      final scroll = SessionLiveScroll(now: () => DateTime.utc(2026, 10, 20));
      scroll.markUserIntent();
      scroll.onContentGrewAway();
      expect(scroll.unreadBelow, isTrue);
    });

    test('a reader at the bottom is followed and not marked', () {
      final scroll = SessionLiveScroll(now: () => DateTime.utc(2026, 10, 20));
      scroll.onContentGrewAway();
      expect(scroll.unreadBelow, isFalse);
    });

    test('the intent hold expires', () {
      var now = DateTime.utc(2026, 10, 20);
      final scroll = SessionLiveScroll(now: () => now);
      scroll.markUserIntent();
      expect(scroll.hasUserIntent, isTrue);
      now = now.add(const Duration(seconds: 2));
      expect(scroll.hasUserIntent, isFalse);
    });

    test('a revealed answer is not a reader\'s scroll', () {
      final scroll = SessionLiveScroll(now: () => DateTime.utc(2026, 10, 20));
      scroll.reveal();
      expect(scroll.revealed, isTrue);
      expect(scroll.following, isFalse);
      // A programmatic move never counts as the reader's.
      scroll.runProgrammatic(scroll.markUserIntent);
      expect(scroll.revealed, isTrue);
      expect(scroll.hasUserIntent, isFalse);
      scroll.markUserIntent();
      expect(scroll.revealed, isFalse);
    });
  });
}
