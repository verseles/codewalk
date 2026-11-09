import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/features/sessions/session_timeline_tile.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'live_fakes.dart';

void main() {
  late CatalogRig rig;
  late LiveDirectory directory;
  late SessionLiveController controller;
  late SessionRef ref;

  setUp(() async {
    rig = CatalogRig();
    await rig.save('a');
    await rig.sessions.initialize();
    directory = LiveDirectory();
    final summary = CatalogSource(profile('a')).row('one');
    ref = summary.info.ref;
    controller = SessionLiveController(
      hosts: rig.hosts,
      profile: profile('a'),
      summary: summary,
      directory: directory,
    );
  });
  tearDown(() {
    controller.dispose();
    rig.dispose();
  });

  UserInput prompt([String id = 'prompt']) => UserInput(
    meta: liveMeta(ref, id),
    text: 'once',
    delivery: const OpenValue.known(DeliveryState.delivered),
  );
  TurnOutcome outcome(String id) => TurnOutcome(
    meta: liveMeta(ref, id),
    kind: const OpenValue.known(OutcomeKind.succeeded),
  );
  Notice interruption() => Notice(
    meta: liveMeta(ref, 'interruption'),
    kind: const OpenValue.known(NoticeKind.interruption),
    text: '',
  );
  Future<LiveHandle> start() async {
    final opening = controller.start();
    final handle = directory.grant(ref);
    await opening;
    return handle;
  }

  Future<void> emit(
    LiveHandle handle,
    ExecutionKind kind, {
    List<TimelineItem>? items,
    SessionLivePhase phase = SessionLivePhase.live,
    bool stale = false,
    ExecutionOutcome? result,
  }) async {
    handle.emit(
      SessionLiveView(
        session: ref,
        phase: phase,
        stale: stale,
        state: liveState(
          ref,
          items: items ?? [prompt()],
          execution: ExecutionState(
            kind: OpenValue.known(kind),
            lastOutcome: result,
          ),
        ),
      ),
    );
    await pumpEventQueue();
  }

  test(
    'observed shutdown survives idle without inventing canonical execution',
    () async {
      final handle = await start();
      final items = [outcome('previous'), prompt()];
      await emit(handle, ExecutionKind.running, items: items);
      await emit(handle, ExecutionKind.interruptedPendingResume, items: items);
      expect(controller.executionNotice, isNull); // The chip already says it.
      await emit(
        handle,
        ExecutionKind.idle,
        items: items,
        phase: SessionLivePhase.reconnecting,
        stale: true,
      );
      await emit(handle, ExecutionKind.idle, items: items);
      expect(controller.executionNotice, SessionExecutionNotice.interrupted);
      expect(controller.state!.execution!.kind.known, ExecutionKind.idle);
      expect(controller.state!.timeline.whereType<UserInput>(), hasLength(1));
      expect(handle.stops, isEmpty);
      await emit(handle, ExecutionKind.running, items: items);
      expect(controller.executionNotice, isNull);
    },
  );

  test('old success and disconnect do not prove the current outcome', () async {
    final handle = await start();
    final items = [outcome('previous'), prompt()];
    await emit(handle, ExecutionKind.running, items: items);
    await emit(
      handle,
      ExecutionKind.idle,
      items: items,
      phase: SessionLivePhase.reconnecting,
      stale: true,
    );
    expect(controller.executionNotice, isNull);
    await emit(handle, ExecutionKind.idle, items: items);
    expect(controller.executionNotice, SessionExecutionNotice.unconfirmed);
    await emit(handle, ExecutionKind.idle, items: items);
    expect(controller.executionNotice, SessionExecutionNotice.unconfirmed);
    await emit(
      handle,
      ExecutionKind.idle,
      items: [...items, outcome('current')],
    );
    expect(controller.executionNotice, isNull);
    expect(handle.stops, isEmpty);
  });

  test('a reported result settles the run in either order', () async {
    final handle = await start();
    // Each report is a fresh instance, as the harness builds it; a const
    // would make both reports one object.
    // ignore: prefer_const_constructors
    final previous = ExecutionOutcome(
      const OpenValue.known(ExecutionOutcomeKind.succeeded),
    );
    final items = [outcome('previous'), prompt()];
    // A harness that reports the result only on the execution state.
    await emit(handle, ExecutionKind.running, items: items);
    await emit(handle, ExecutionKind.idle, items: items, result: previous);
    expect(controller.executionNotice, isNull);
    // OpenCode carries the previous result while running, then reports the
    // new one before the outcome item that follows it.
    await emit(handle, ExecutionKind.running, items: items, result: previous);
    // ignore: prefer_const_constructors
    final current = ExecutionOutcome(
      const OpenValue.known(ExecutionOutcomeKind.succeeded),
    );
    await emit(handle, ExecutionKind.idle, items: items, result: current);
    expect(controller.executionNotice, isNull);
    await emit(
      handle,
      ExecutionKind.idle,
      items: [...items, outcome('current')],
      result: current,
    );
    expect(controller.executionNotice, isNull);
    // The same result carried through the run proves nothing new.
    await emit(handle, ExecutionKind.running, items: items, result: current);
    await emit(handle, ExecutionKind.idle, items: items, result: current);
    expect(controller.executionNotice, SessionExecutionNotice.unconfirmed);
  });

  test(
    'an earlier prompt\'s interruption does not speak for the next',
    () async {
      final handle = await start();
      final first = [prompt(), interruption()];
      await emit(handle, ExecutionKind.idle, items: first);
      expect(controller.hasInterruptedStep, isTrue);
      final items = [...first, prompt('next')];
      await emit(handle, ExecutionKind.running, items: items);
      await emit(handle, ExecutionKind.idle, items: items);
      expect(controller.executionNotice, SessionExecutionNotice.unconfirmed);
    },
  );

  test('a Stop settles through its interrupted outcome', () async {
    final handle = await start();
    final items = [outcome('previous'), prompt()];
    TurnOutcome stopped() => TurnOutcome(
      meta: liveMeta(ref, 'stopped'),
      kind: const OpenValue.known(OutcomeKind.interrupted),
    );
    // The projected order: the step notice, then idle, then the outcome.
    await emit(handle, ExecutionKind.running, items: items);
    await emit(
      handle,
      ExecutionKind.running,
      items: [...items, interruption()],
    );
    await emit(handle, ExecutionKind.idle, items: [...items, interruption()]);
    expect(controller.executionNotice, isNull);
    expect(controller.hasInterruptedStep, isTrue);
    await emit(
      handle,
      ExecutionKind.idle,
      items: [...items, interruption(), stopped()],
    );
    expect(controller.executionNotice, isNull);
    expect(controller.hasInterruptedStep, isFalse);
  });

  test('a re-read that already holds the new outcome settles', () async {
    final handle = await start();
    final done = [outcome('previous'), prompt(), outcome('current')];
    // ignore: prefer_const_constructors
    final read = ExecutionOutcome(
      const OpenValue.known(ExecutionOutcomeKind.succeeded),
    );
    // The execution was read before its end, the timeline after it; the
    // replayed end then reports a new result.
    await emit(handle, ExecutionKind.running, items: done, result: read);
    // ignore: prefer_const_constructors
    final ended = ExecutionOutcome(
      const OpenValue.known(ExecutionOutcomeKind.succeeded),
    );
    await emit(handle, ExecutionKind.idle, items: done, result: ended);
    expect(controller.executionNotice, isNull);
  });

  test('cold idle and unknown state do not invent an interruption', () async {
    final handle = await start();
    await emit(handle, ExecutionKind.idle);
    expect(controller.executionNotice, isNull);
    await emit(handle, ExecutionKind.unknown);
    await emit(handle, ExecutionKind.idle);
    expect(controller.executionNotice, isNull);
  });

  test('a canonical notice avoids a second local warning', () async {
    final handle = await start();
    await emit(handle, ExecutionKind.running);
    await emit(handle, ExecutionKind.idle, items: [prompt(), interruption()]);
    expect(controller.hasInterruptedStep, isTrue);
    expect(controller.executionNotice, isNull);
  });

  test('an unconfirmed result is not attributed to a later prompt', () async {
    final handle = await start();
    await emit(handle, ExecutionKind.running);
    await emit(handle, ExecutionKind.idle);
    expect(controller.executionNotice, SessionExecutionNotice.unconfirmed);
    await emit(handle, ExecutionKind.idle, items: [prompt(), prompt('next')]);
    expect(controller.executionNotice, isNull);
  });

  for (final locale in ['en', 'pt', 'ar']) {
    testWidgets(
      'step interruption is localized without exposing server text: $locale',
      (tester) async {
        final l10n = await V2Localizations.delegate.load(Locale(locale));
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: V2Localizations.localizationsDelegates,
            supportedLocales: V2Localizations.supportedLocales,
            home: Scaffold(body: SessionTimelineTile(item: interruption())),
          ),
        );
        expect(find.text(l10n.liveStepInterrupted), findsOneWidget);
        expect(find.text('Last turn succeeded'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
