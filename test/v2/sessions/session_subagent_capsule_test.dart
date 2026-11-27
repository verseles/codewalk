import 'package:codewalk/features/sessions/session_live_timeline.dart';
import 'package:codewalk/features/sessions/session_subagent_capsule.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'live_fakes.dart';
import 'subagent_capsule_support.dart';

void main() {
  final capsule = find.byKey(const ValueKey('subagent-capsule'));
  final count = find.byKey(const ValueKey('subagent-count'));
  final popin = find.byKey(const ValueKey('subagent-popin'));

  testWidgets('robot floats inside the unchanged timeline viewport', (
    tester,
  ) async {
    final rig = await SubagentCapsuleRig.mount(tester, fullPage: true);
    final timeline = find.byType(SessionLiveTimeline);
    final before = tester.getRect(timeline);
    rig.emit([rig.work('runner', WorkStatus.running)]);
    await tester.pumpAndSettle();
    expect(tester.getRect(timeline), before);
    final robot = tester.getRect(capsule);
    expect(before.contains(robot.topLeft), isTrue);
    expect(before.contains(robot.bottomRight), isTrue);
    // A drag next to the robot still reaches the timeline scrollable.
    final beside = Offset(before.left + 30, robot.center.dy);
    final hits = tester.hitTestOnBinding(beside).path;
    final scroll = tester.renderObject(find.byType(CustomScrollView).first);
    expect(hits.any((entry) => entry.target == scroll), isTrue);
    rig.emit([]);
    await tester.pumpAndSettle();
    expect(tester.getRect(timeline), before);
    expect(capsule, findsNothing);
  });

  testWidgets(
    'latest content clears robot and jump controls preserve its state',
    (tester) async {
      tester.view.physicalSize = const Size(390, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final rig = await SubagentCapsuleRig.mount(tester, fullPage: true);
      rig.emit(
        [rig.work('runner', WorkStatus.running)],
        items: [
          for (var i = 0; i < 30; i++)
            AssistantText(
              meta: liveMeta(rig.parent, 'a$i'),
              text: 'Message $i',
              complete: true,
            ),
        ],
      );
      await tester.pumpAndSettle();
      final capsuleState = tester.state(find.byType(SessionSubagentCapsule));
      final last = find.text('Message 29');
      expect(last, findsOneWidget);
      expect(
        tester.getBottomRight(last).dy,
        lessThanOrEqualTo(tester.getTopLeft(capsule).dy),
      );
      final scroll = rig.live.scroll;
      scroll.markUserIntent();
      scroll.controller.jumpTo(scroll.controller.position.minScrollExtent);
      await tester.pumpAndSettle();
      final jump = find.byKey(const ValueKey('live-jump-latest'));
      expect(jump, findsOneWidget);
      expect(
        tester.getBottomRight(jump).dy,
        lessThan(tester.getTopLeft(capsule).dy),
      );
      expect(
        tester.state(find.byType(SessionSubagentCapsule)),
        same(capsuleState),
      );
      await tester.tap(jump);
      await tester.pumpAndSettle();
      expect(
        tester.state(find.byType(SessionSubagentCapsule)),
        same(capsuleState),
      );
      expect(
        tester.getBottomRight(last).dy,
        lessThanOrEqualTo(tester.getTopLeft(capsule).dy),
      );
      tester.view.physicalSize = const Size(390, 240);
      await tester.pumpAndSettle();
      scroll.markUserIntent();
      scroll.controller.jumpTo(scroll.controller.position.minScrollExtent);
      await tester.pumpAndSettle();
      final viewport = tester.getRect(find.byType(SessionLiveTimeline));
      for (final control in [
        capsule,
        jump,
        find.byKey(const ValueKey('live-jump-first')),
      ]) {
        expect(viewport.contains(tester.getTopLeft(control)), isTrue);
        expect(viewport.contains(tester.getBottomRight(control)), isTrue);
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('capsule and pop-in use the local $brightness theme', (
      tester,
    ) async {
      final theme = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          brightness: brightness,
        ),
        useMaterial3: true,
      );
      final rig = await SubagentCapsuleRig.mount(tester, localTheme: theme);
      rig.emit([rig.work('runner', WorkStatus.running)]);
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(capsule);
      final context = tester.element(capsule);
      final style = button.style!;
      expect(
        style.backgroundColor!.resolve({}),
        theme.colorScheme.secondaryContainer,
      );
      expect(
        style.foregroundColor!.resolve({}),
        theme.colorScheme.onSecondaryContainer,
      );
      expect(Theme.of(context).brightness, brightness);
      await tester.tap(capsule);
      await tester.pumpAndSettle();
      final row = find.byKey(
        ValueKey(
          'subagent-row-${rig.work('runner', WorkStatus.running).child!.storageKey}',
        ),
      );
      expect(Theme.of(tester.element(row)).colorScheme, theme.colorScheme);
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    });
  }

  testWidgets(
    'no child means no robot; completed children keep it without count',
    (tester) async {
      final rig = await SubagentCapsuleRig.mount(tester);
      rig.emit([]);
      await tester.pump();
      expect(capsule, findsNothing);
      rig.emit([rig.work('review', WorkStatus.completed)]);
      await tester.pump();
      expect(capsule, findsOneWidget);
      expect(count, findsNothing);
      await tester.tap(capsule);
      await tester.pumpAndSettle();
      expect(popin, findsOneWidget);
      expect(find.text('review'), findsOneWidget);
      expect(find.text('Completed'), findsNWidgets(2));
      await tester.tap(find.text('review'));
      await tester.pumpAndSettle();
      expect(rig.opened.single.nativeId, 'ses_review');
      expect(popin, findsNothing);
    },
  );

  testWidgets(
    'active count includes one waiting child, not requests or unknown',
    (tester) async {
      final rig = await SubagentCapsuleRig.mount(tester);
      final waiting = rig.work('waiting', WorkStatus.completed);
      final requests = [
        for (final kind in [InteractionKind.permission, InteractionKind.form])
          InteractionRequest(
            id: InteractionId(kind.name),
            owner: SessionOwner(waiting.child!, origin: rig.parent),
            kind: OpenValue.known(kind),
            title: 'Needs you',
            requiresInput: true,
          ),
      ];
      final rows = [
        rig.work('running', WorkStatus.running),
        waiting,
        rig.work('unknown', WorkStatus.unknown),
        rig.work('queued', WorkStatus.queued),
        rig.work('failed', WorkStatus.failed),
        rig.work('cancelled', WorkStatus.cancelled),
      ];
      rig.emit(rows, interactions: requests);
      await tester.pump();
      await tester.pump();
      expect(tester.widget<Text>(count).data, '3');
      await tester.tap(capsule);
      await tester.pumpAndSettle();
      expect(find.text('Waiting for your answer'), findsOneWidget);
      expect(find.text('Status unconfirmed'), findsOneWidget);
      expect(find.text('Queued'), findsOneWidget);
      expect(find.text('failed'), findsNothing);
      await tester.tap(find.text('Completed').first);
      await tester.pumpAndSettle();
      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('unknown'), findsNothing);
      expect(find.text('waiting'), findsNothing);
    },
  );

  testWidgets(
    'live completion updates an open popup and never removes the robot',
    (tester) async {
      final rig = await SubagentCapsuleRig.mount(tester);
      rig.emit([rig.work('runner', WorkStatus.running)]);
      await tester.pump();
      await tester.pump();
      await tester.tap(capsule);
      await tester.pumpAndSettle();
      rig.emit([rig.work('runner', WorkStatus.completed)]);
      await tester.pump();
      await tester.pump();
      expect(find.text('No sub-agents here.'), findsOneWidget);
      expect(count, findsNothing);
      await tester.tap(find.text('Completed').first);
      await tester.pumpAndSettle();
      expect(find.text('runner'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(popin, findsNothing);
      expect(capsule, findsOneWidget);
    },
  );

  testWidgets('unknown and stale rows are not completed or active counts', (
    tester,
  ) async {
    final rig = await SubagentCapsuleRig.mount(tester);
    rig.emit([rig.work('unknown', WorkStatus.unknown)]);
    await tester.pump();
    await tester.pump();
    expect(count, findsNothing);
    await tester.tap(capsule);
    await tester.pumpAndSettle();
    expect(find.text('Status unconfirmed'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(popin, findsNothing);
    rig.emit(
      [rig.work('old', WorkStatus.completed)],
      phase: SessionLivePhase.reconnecting,
      stale: true,
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(capsule);
    await tester.pumpAndSettle();
    expect(find.text('Status unconfirmed'), findsOneWidget);
    await tester.tap(find.text('old'));
    await tester.pump();
    expect(rig.opened, isEmpty);
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(popin, findsNothing);
  });

  test(
    'foreign work and parent completion notices never become child rows',
    () {
      const parent = SessionRef(
        HostId('host'),
        HarnessInstanceId('h'),
        'ses_p',
      );
      final foreign = SessionRef(
        parent.host,
        const HarnessInstanceId('other'),
        'ses_c',
      );
      final state = liveState(
        parent,
        work: const [
          WorkItem(
            id: WorkId('notice'),
            owner: SessionOwner(parent),
            status: OpenValue.known(WorkStatus.completed),
            completionScope: OpenValue.known(CompletionScope.notice),
          ),
        ],
      );
      expect(subagentWork(state), isEmpty);
      expect(subagentWork(null), isEmpty);
      final unknown = WorkItem(
        id: const WorkId('future'),
        owner: SessionOwner(foreign, origin: parent),
        child: foreign,
        parent: parent,
        status: OpenValue<WorkStatus>.unknown('future'),
        completionScope: const OpenValue.known(CompletionScope.child),
      );
      expect(subagentStatus(unknown, state), WorkStatus.unknown);
      expect(subagentIsActive(WorkStatus.failed), isFalse);
      expect(subagentIsCompleted(WorkStatus.unknown), isFalse);
    },
  );

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets('compact full page and popup fit 2x ${locale.languageCode}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 480);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 160);
      addTearDown(tester.view.reset);
      final rig = await SubagentCapsuleRig.mount(
        tester,
        locale: locale,
        scale: 2,
        fullPage: true,
      );
      rig.emit([
        rig.work('A long subagent title for layout', WorkStatus.running),
        rig.work('Previous work', WorkStatus.completed),
      ]);
      await tester.pump();
      expect(tester.takeException(), isNull);
      final robot = tester.getRect(capsule);
      final status = tester.getRect(
        find.byKey(const ValueKey('composer-status')),
      );
      expect(robot.bottom, lessThanOrEqualTo(status.top));
      await tester.tap(capsule);
      await tester.pumpAndSettle();
      expect(popin, findsOneWidget);
      expect(tester.getBottomRight(popin).dy, lessThanOrEqualTo(robot.top));
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    });

    testWidgets(
      'a disappearing anchor keeps a visible popup ${locale.languageCode}',
      (tester) async {
        final rig = await SubagentCapsuleRig.mount(tester, locale: locale);
        rig.emit([rig.work('runner', WorkStatus.running)]);
        await tester.pumpAndSettle();
        await tester.tap(capsule);
        await tester.pumpAndSettle();
        rig.emit([]);
        await tester.pumpAndSettle();
        expect(capsule, findsNothing);
        // Force the dialog's geometry builder to run after its anchor disappeared.
        tester.view.physicalSize = const Size(780, 590);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpAndSettle();
        expect(popin, findsOneWidget);
        expect(tester.getSize(popin).height, greaterThan(0));
        expect(tester.takeException(), isNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(popin, findsNothing);
      },
    );

    testWidgets(
      'a popup shorter than its tabs scrolls ${locale.languageCode}',
      (tester) async {
        tester.view.physicalSize = const Size(390, 240);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final rig = await SubagentCapsuleRig.mount(
          tester,
          locale: locale,
          scale: 2,
        );
        rig.emit([rig.work('runner', WorkStatus.running)]);
        await tester.pumpAndSettle();
        final robot = tester.getRect(capsule);
        await tester.tap(capsule);
        await tester.pumpAndSettle();
        expect(popin, findsOneWidget);
        expect(tester.takeException(), isNull);
        final viewport = find.descendant(
          of: popin,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SingleChildScrollView &&
                widget.scrollDirection == Axis.vertical,
          ),
        );
        expect(viewport, findsOneWidget);
        expect(tester.getSize(viewport).height, lessThan(48));
        expect(
          tester.getBottomRight(viewport).dy,
          lessThanOrEqualTo(robot.top),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(popin, findsNothing);
      },
    );
  }
}
