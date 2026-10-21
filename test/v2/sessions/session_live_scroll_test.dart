import 'dart:async';

import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/sessions/session_live_scroll.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

/// An item meta of a rehydration: the same row, read again, with the
/// generation the new read gives it.
ItemMeta _rehydrated(SessionRef ref, String id) => ItemMeta(
  id: ItemId(id),
  generation: 'rehydrated',
  status: const OpenValue.known(ItemStatus.completed),
  source: SourceProvenance(
    harness: ref.harnessRef,
    version: '2.0.22',
    nativeType: 'live',
  ),
);

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

  group('the review corrections', () {
    testWidgets('a code block scrolled sideways does not stop the follow', (
      tester,
    ) async {
      final live = await _openLive(
        tester,
        (ref) => [
          ..._answers(ref, 3),
          AssistantText(
            meta: liveMeta(ref, 'code'),
            text: '```\n${'wide_code_line ' * 60}\n```',
            complete: true,
          ),
        ],
        settled: false,
      );
      final controller = _controller(tester);
      final sideways = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable &&
            axisDirectionToAxis(widget.axisDirection) == Axis.horizontal,
      );
      expect(sideways, findsWidgets);
      // The reader scrolls the code block sideways and keeps the finger down
      // while the turn streams: the timeline is not the one being scrolled.
      final gesture = await tester.startGesture(
        tester.getCenter(sideways.first),
      );
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-120, 0));
      await tester.pump();
      expect(find.byKey(const ValueKey('live-jump-latest')), findsNothing);
      live.handle.emit(
        SessionLiveView(
          session: live.ref,
          phase: SessionLivePhase.live,
          state: liveState(
            live.ref,
            items: [
              ..._answers(live.ref, 3),
              AssistantText(
                meta: liveMeta(live.ref, 'code'),
                text: '```\n${'wide_code_line ' * 60}\n```',
                complete: true,
              ),
              ..._answers(live.ref, 6).skip(3),
            ],
            execution: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.running),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(controller.offset, controller.position.maxScrollExtent);
      expect(find.byKey(const ValueKey('live-jump-latest')), findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.offset, controller.position.maxScrollExtent);
      await tester.pumpWidget(const SizedBox.shrink());
      live.rig.dispose();
    });

    testWidgets(
      'a streamed growth is followed without any other frame request',
      (tester) async {
        final live = await _openLive(
          tester,
          (ref) => _answers(ref, 30),
          settled: false,
        );
        final controller = _controller(tester);
        live.handle.emit(
          SessionLiveView(
            session: live.ref,
            phase: SessionLivePhase.live,
            state: liveState(
              live.ref,
              items: [
                ..._answers(live.ref, 29),
                AssistantText(
                  meta: liveMeta(live.ref, 'a29'),
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
        await tester.pumpWidget(const SizedBox.shrink());
        live.rig.dispose();
      },
      // Without semantics nothing else requests the frame the follow waits
      // for, as on a phone without a screen reader.
      semanticsEnabled: false,
    );

    testWidgets('a slow drag that starts at the tail keeps its priority', (
      tester,
    ) async {
      final live = await _openLive(
        tester,
        (ref) => _answers(ref, 40),
        settled: false,
      );
      final controller = _controller(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ListView)),
      );
      // The first move stays within the bottom epsilon, then the drag goes
      // farther in the same direction, which reports no new direction.
      await gesture.moveBy(const Offset(0, 0.5));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 150));
      await tester.pump();
      final held = controller.offset;
      expect(held, lessThan(controller.position.maxScrollExtent));
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
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(controller.offset, held);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.offset, lessThan(controller.position.maxScrollExtent));
      expect(find.byKey(const ValueKey('live-jump-latest')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      live.rig.dispose();
    });

    testWidgets('an answer that settled while the reader was away stays put', (
      tester,
    ) async {
      List<TimelineItem> turn(SessionRef ref, {int extra = 0}) => [
        ..._answers(ref, 10),
        AssistantText(
          meta: liveMeta(ref, 'final'),
          text: 'final answer ${'body ' * 400}',
          complete: true,
        ),
        // Content that is not an answer, so the old answer stays the last.
        for (var i = 0; i < extra; i++)
          TurnOutcome(
            meta: liveMeta(ref, 'late$i'),
            kind: const OpenValue.known(OutcomeKind.succeeded),
          ),
      ];
      final live = await _openLive(tester, turn, settled: false);
      final controller = _controller(tester);
      // The reader moves away while the turn runs, then the turn settles.
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();
      live.handle.emit(
        SessionLiveView(
          session: live.ref,
          phase: SessionLivePhase.live,
          state: liveState(
            live.ref,
            items: turn(live.ref),
            execution: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.idle),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The reader drags back to the tail, then content arrives: the old
      // answer is not revealed on top of the tail the reader came back to.
      await tester.drag(find.byType(ListView), const Offset(0, -20000));
      await tester.pumpAndSettle();
      expect(controller.offset, controller.position.maxScrollExtent);
      live.handle.emit(
        SessionLiveView(
          session: live.ref,
          phase: SessionLivePhase.live,
          state: liveState(
            live.ref,
            items: turn(live.ref, extra: 1),
            execution: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.idle),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.offset, controller.position.maxScrollExtent);
      await tester.pumpWidget(const SizedBox.shrink());
      live.rig.dispose();
    });

    testWidgets(
      'an answer that settled while the reader was away is not offered after the control',
      (tester) async {
        List<TimelineItem> turn(SessionRef ref, {int extra = 0}) => [
          ..._answers(ref, 10),
          AssistantText(
            meta: liveMeta(ref, 'final'),
            text: 'final answer ${'body ' * 400}',
            complete: true,
          ),
          // Content that is not an answer, so the old answer stays the last.
          for (var i = 0; i < extra; i++)
            TurnOutcome(
              meta: liveMeta(ref, 'late$i'),
              kind: const OpenValue.known(OutcomeKind.succeeded),
            ),
        ];
        final live = await _openLive(tester, turn, settled: false);
        final controller = _controller(tester);
        // The reader moves away while the turn runs, then the turn settles.
        await tester.drag(find.byType(ListView), const Offset(0, 300));
        await tester.pumpAndSettle();
        live.handle.emit(
          SessionLiveView(
            session: live.ref,
            phase: SessionLivePhase.live,
            state: liveState(
              live.ref,
              items: turn(live.ref),
              execution: const ExecutionState(
                kind: OpenValue.known(ExecutionKind.idle),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // The reader returns with the control, then content arrives.
        await tester.tap(find.byKey(const ValueKey('live-jump-latest')));
        await tester.pumpAndSettle();
        live.handle.emit(
          SessionLiveView(
            session: live.ref,
            phase: SessionLivePhase.live,
            state: liveState(
              live.ref,
              items: turn(live.ref, extra: 1),
              execution: const ExecutionState(
                kind: OpenValue.known(ExecutionKind.idle),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(controller.offset, controller.position.maxScrollExtent);
        await tester.pumpWidget(const SizedBox.shrink());
        live.rig.dispose();
      },
    );

    testWidgets('a tail that grows far below the reader marks the control', (
      tester,
    ) async {
      final live = await _openLive(
        tester,
        (ref) => _answers(ref, 80),
        settled: false,
      );
      final controller = _controller(tester);
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      // The drag marks the reader's priority; the reader is now far above
      // the tail, outside the list's cache.
      await tester.drag(find.byType(ListView), const Offset(0, 50));
      await tester.pumpAndSettle();
      live.handle.emit(
        SessionLiveView(
          session: live.ref,
          phase: SessionLivePhase.live,
          state: liveState(
            live.ref,
            items: [
              ..._answers(live.ref, 79),
              AssistantText(
                meta: liveMeta(live.ref, 'a79'),
                text: 'row 79 ${'streamed ' * 60}',
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
      final control = find.byKey(const ValueKey('live-jump-latest'));
      final fab = tester.widget<FloatingActionButton>(control);
      expect(
        fab.backgroundColor,
        Theme.of(tester.element(control)).colorScheme.primary,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      live.rig.dispose();
    });

    testWidgets('a removal or a smaller viewport does not mark the control', (
      tester,
    ) async {
      final live = await _openLive(
        tester,
        (ref) => _answers(ref, 40),
        settled: false,
      );
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();
      Color? background() => tester
          .widget<FloatingActionButton>(
            find.byKey(const ValueKey('live-jump-latest')),
          )
          .backgroundColor;
      final plain = background();
      // The last items are removed (a revert): nothing arrived below.
      live.handle.emit(
        SessionLiveView(
          session: live.ref,
          phase: SessionLivePhase.live,
          state: liveState(
            live.ref,
            items: _answers(live.ref, 38),
            execution: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.running),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(background(), plain);
      // The viewport shrinks, as when the keyboard opens.
      tester.view.physicalSize = const Size(390, 600);
      await tester.pumpAndSettle();
      expect(background(), plain);
      await tester.pumpWidget(const SizedBox.shrink());
      live.rig.dispose();
    });
  });

  group('the second review corrections', () {
    /// The control that returns to the newest content, and the color that
    /// marks the content that arrived below the reader.
    Finder jumpControl() => find.byKey(const ValueKey('live-jump-latest'));

    Color? controlColor(WidgetTester tester) => tester
        .widget<FloatingActionButton>(jumpControl())
        .backgroundColor;

    testWidgets('a row that is not the last one is an arrival', (tester) async {
      final live = await _openLive(
        tester,
        (ref) => _answers(ref, 40),
        settled: false,
      );
      // The reader moves away, so the content that arrives is marked.
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(jumpControl(), findsOneWidget);
      final plain = controlColor(tester);
      // A row in the middle grows: the tail is untouched, but content
      // arrived under the reader.
      live.handle.emit(
        SessionLiveView(
          session: live.ref,
          phase: SessionLivePhase.live,
          state: liveState(
            live.ref,
            items: [
              for (var i = 0; i < 40; i++)
                AssistantText(
                  meta: liveMeta(live.ref, 'a$i'),
                  text: i == 10 ? 'row 10 ${'more ' * 40}' : 'row $i',
                  complete: true,
                ),
            ],
            execution: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.running),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(controlColor(tester), isNot(plain));
      await tester.pumpWidget(const SizedBox.shrink());
      live.rig.dispose();
    });

    testWidgets('a scroll with no direction of its own keeps the reader', (
      tester,
    ) async {
      final live = await _openLive(
        tester,
        (ref) => _answers(ref, 40),
        size: const Size(1280, 800),
        settled: false,
      );
      final controller = _controller(tester);
      // A page key and a click on the scrollbar track move the list with
      // `moveTo`, which reports no scroll direction of its own.
      unawaited(
        controller.position.moveTo(
          controller.position.pixels - 200,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeInOut,
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.position.userScrollDirection, ScrollDirection.idle);
      expect(jumpControl(), findsOneWidget);
      final held = controller.offset;
      expect(held, lessThan(controller.position.maxScrollExtent));
      // Content arrives: the reader's place is kept.
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
      expect(controller.offset, held);
      await tester.pumpWidget(const SizedBox.shrink());
      live.rig.dispose();
    });

    testWidgets('the notice, the outcome and the unknown row are arrivals', (
      tester,
    ) async {
      // The same row before and after: only the field under test changes, so
      // the arrival can only come from that field.
      Future<void> expectMarked(
        List<TimelineItem> Function(SessionRef ref) before,
        List<TimelineItem> Function(SessionRef ref) after,
      ) async {
        final live = await _openLive(tester, before, settled: false);
        await tester.drag(find.byType(ListView), const Offset(0, 300));
        await tester.pumpAndSettle();
        final plain = controlColor(tester);
        live.handle.emit(
          SessionLiveView(
            session: live.ref,
            phase: SessionLivePhase.live,
            state: liveState(
              live.ref,
              items: after(live.ref),
              execution: const ExecutionState(
                kind: OpenValue.known(ExecutionKind.running),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(controlColor(tester), isNot(plain));
        await tester.pumpWidget(const SizedBox.shrink());
        live.rig.dispose();
      }

      // The tail is a notice whose text arrives.
      await expectMarked(
        (ref) => [
          ..._answers(ref, 39),
          Notice(
            meta: liveMeta(ref, 'n1'),
            kind: const OpenValue.known(NoticeKind.continuation),
            text: '',
          ),
        ],
        (ref) => [
          ..._answers(ref, 39),
          Notice(
            meta: liveMeta(ref, 'n1'),
            kind: const OpenValue.known(NoticeKind.continuation),
            text: 'the turn continues',
          ),
        ],
      );
      // The tail is an outcome whose reason arrives.
      await expectMarked(
        (ref) => [
          ..._answers(ref, 39),
          TurnOutcome(
            meta: liveMeta(ref, 'o1'),
            kind: const OpenValue.known(OutcomeKind.succeeded),
          ),
        ],
        (ref) => [
          ..._answers(ref, 39),
          TurnOutcome(
            meta: liveMeta(ref, 'o1'),
            kind: const OpenValue.known(OutcomeKind.succeeded),
            reason: 'the turn ended',
          ),
        ],
      );
      // The tail is an unknown row whose fallback text arrives.
      await expectMarked(
        (ref) => [
          ..._answers(ref, 39),
          UnknownItem(
            meta: liveMeta(ref, 'u1'),
            rawType: 'custom',
            raw: CanonicalValue('payload'),
          ),
        ],
        (ref) => [
          ..._answers(ref, 39),
          UnknownItem(
            meta: liveMeta(ref, 'u1'),
            rawType: 'custom',
            raw: CanonicalValue('payload'),
            fallbackText: 'a part this client does not know',
          ),
        ],
      );
      // The tail is a shell run whose exit code arrives.
      await expectMarked(
        (ref) => [
          ..._answers(ref, 39),
          ShellRun(meta: liveMeta(ref, 's1'), command: 'echo done'),
        ],
        (ref) => [
          ..._answers(ref, 39),
          ShellRun(
            meta: liveMeta(ref, 's1'),
            command: 'echo done',
            exitCode: 0,
          ),
        ],
      );
    });

    testWidgets('content under a revealed answer offers the control', (
      tester,
    ) async {
      final live = await _openLive(
        tester,
        (ref) => [
          ..._answers(ref, 10),
          AssistantText(
            meta: liveMeta(ref, 'final'),
            text: 'final answer ${'body ' * 400}',
            complete: true,
          ),
        ],
      );
      // The settled answer is revealed from its start, so the control stays
      // hidden: the reader is at the answer, not away from the newest.
      expect(jumpControl(), findsNothing);
      live.handle.emit(
        SessionLiveView(
          session: live.ref,
          phase: SessionLivePhase.live,
          state: liveState(
            live.ref,
            items: [
              ..._answers(live.ref, 10),
              AssistantText(
                meta: liveMeta(live.ref, 'final'),
                text: 'final answer ${'body ' * 400}',
                complete: true,
              ),
              ..._answers(live.ref, 2).skip(1),
            ],
            execution: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.idle),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Content arrived under the revealed answer: the reader has to come
      // back to the newest content, so the control is offered.
      expect(jumpControl(), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      live.rig.dispose();
    });

    testWidgets('a rehydration that changes no content is not an arrival', (
      tester,
    ) async {
      final live = await _openLive(
        tester,
        (ref) => _answers(ref, 40),
        settled: false,
      );
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(jumpControl(), findsOneWidget);
      final plain = controlColor(tester);
      // The same content, read again: the rows carry a new generation, but
      // nothing arrived.
      live.handle.emit(
        SessionLiveView(
          session: live.ref,
          phase: SessionLivePhase.live,
          state: liveState(
            live.ref,
            items: [
              for (var i = 0; i < 40; i++)
                AssistantText(
                  meta: _rehydrated(live.ref, 'a$i'),
                  text: 'row $i',
                  complete: true,
                ),
            ],
            execution: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.running),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(controlColor(tester), plain);
      await tester.pumpWidget(const SizedBox.shrink());
      live.rig.dispose();
    });
  });

  group('the scroll rules', () {
    test('the follow stops when the reader scrolls', () {
      final scroll = SessionLiveScroll();
      expect(scroll.following, isTrue);
      expect(scroll.mayFollow, isTrue);
      scroll.markUserIntent();
      expect(scroll.following, isFalse);
      expect(scroll.mayFollow, isFalse);
    });

    test('content that arrives under a reader is marked', () {
      final scroll = SessionLiveScroll();
      scroll.markUserIntent();
      scroll.onContentArrivedAway();
      expect(scroll.unreadBelow, isTrue);
    });

    test('a reader at the bottom is followed and not marked', () {
      final scroll = SessionLiveScroll();
      scroll.onContentArrivedAway();
      expect(scroll.unreadBelow, isFalse);
    });

    test('a revealed answer is not a reader\'s scroll', () {
      final scroll = SessionLiveScroll();
      scroll.reveal();
      expect(scroll.revealed, isTrue);
      expect(scroll.following, isFalse);
      // A programmatic move never counts as the reader's.
      scroll.runProgrammatic(scroll.markUserIntent);
      expect(scroll.revealed, isTrue);
      scroll.markUserIntent();
      expect(scroll.revealed, isFalse);
    });

    test('the control resumes the follow and clears the mark', () {
      final scroll = SessionLiveScroll();
      scroll.markUserIntent();
      scroll.onContentArrivedAway();
      scroll.jumpToLatest();
      expect(scroll.following, isTrue);
      expect(scroll.unreadBelow, isFalse);
    });
  });
}
