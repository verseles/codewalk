import 'package:codewalk/features/sessions/session_subagent_capsule.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'live_fakes.dart';
import 'subagent_capsule_support.dart';

void main() {
  final capsule = find.byKey(const ValueKey('subagent-capsule'));
  final count = find.byKey(const ValueKey('subagent-count'));
  final popin = find.byKey(const ValueKey('subagent-popin'));

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
