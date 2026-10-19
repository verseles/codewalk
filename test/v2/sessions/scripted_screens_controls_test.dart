import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/features/sessions/session_live_page.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/sessions/session_stop.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart' hide ConnectionState, FormField;
import 'package:flutter_test/flutter_test.dart';

import '../../../packages/codewalk_core/test/support/scripted_harness_adapter.dart';
import '../../../packages/codewalk_core/test/support/scripted_harness_scenarios.dart';
import 'fakes.dart';
import 'scripted_live_bridge.dart';

/// Control matrix for the shared session screens, driven through the same
/// test-only bridge as the scenario suite: which actions exist, which are
/// enabled, and how they gate per lease state (running, stopping, stale,
/// replies off, outbox missing). Every assertion goes through the real screen.
Future<SessionLiveController> _mount(
  WidgetTester tester,
  ScriptedLiveBridge bridge,
) async {
  final rig = CatalogRig();
  await rig.save('a');
  await rig.sessions.initialize();
  final live = SessionLiveController(
    hosts: rig.hosts,
    profile: profile('a'),
    summary: SessionSummary(info: scriptedInfo(bridge.ref)),
    directory: bridge,
  );
  addTearDown(rig.dispose);
  addTearDown(() => tester.pumpWidget(const SizedBox()));
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: V2Localizations.localizationsDelegates,
      supportedLocales: V2Localizations.supportedLocales,
      home: SessionLivePage(controller: live),
    ),
  );
  await tester.pump();
  await tester.pump();
  return live;
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int max = 16,
}) async {
  for (var i = 0; i < max && !condition(); i++) {
    await tester.pump();
  }
}

Future<void> _steps(
  WidgetTester tester,
  ScriptedHarnessAdapter adapter,
  int count,
) async {
  for (var i = 0; i < count; i++) {
    await adapter.step();
    await tester.pump();
  }
  // The step's view is delivered through an async stream microtask, which
  // flushes after the frame drawn by that pump; one settle pump paints it.
  await tester.pump();
}

/// A second authored interrupt id, so the matrix can prove the stop gate stays
/// shut while the first request is still busy.
const interruptId2 = CommandId('scripted-interrupt-2');

const _noOutboxAllow = ValueKey(
  'live-permission-allow-nooutbox-permission',
);

ScriptedLiveBridge _bridge(
  ScriptedScenario scenario, {
  OpenIntent intent = OpenIntent.attachLive,
  List<CommandId> sendIds = const [],
  List<CommandId> respondIds = const [],
  List<CommandId> interruptIds = const [],
}) => ScriptedLiveBridge(
  scenario,
  intent: intent,
  hydrations: const ['controls-hydration'],
  sendIds: sendIds,
  respondIds: respondIds,
  interruptIds: interruptIds,
);

/// Whether the composer's send control is currently enabled, whatever its
/// wide/narrow variant is.
bool? _sendEnabled(WidgetTester tester) {
  final widget = tester.widget(
    find.byKey(const ValueKey('live-composer-send')),
  );
  return switch (widget) {
    FilledButton(onPressed: final callback) => callback != null,
    IconButton(onPressed: final callback) => callback != null,
    _ => null,
  };
}

const _allowKey = ValueKey('live-permission-allow-controls-permission');
const _rejectKey = ValueKey(
  'live-permission-reject-stop-controls-permission',
);const _formKey = ValueKey('live-form-controls-form');
const _submitKey = ValueKey('form-submit-controls-form');
const _dismissKey = ValueKey('form-dismiss-controls-form');

void main() {
  group('session screens control matrix', () {
    testWidgets('running: send, delivery toggle, stop, reply and the gated '
        'form all behave through the real screen', (tester) async {
      final scenario = _controlsScenario(sendFirst: true);
      addTearDown(scenario.adapter.dispose);
      final bridge = _bridge(
        scenario,
        sendIds: const [sendId],
        interruptIds: const [interruptId, interruptId2],
      );
      final live = await _mount(tester, bridge);
      await _pumpUntil(tester, () => live.phase == SessionLivePhase.live);
      expect(find.text('Live session'), findsOneWidget);

      await _steps(tester, scenario.adapter, 3);
      expect(live.state!.execution!.kind.known, ExecutionKind.running);

      // The native permission choices are answerable.
      expect(tester.widget<FilledButton>(find.byKey(_allowKey)).onPressed, isNotNull);
      expect(
        tester.widget<TextButton>(find.byKey(_rejectKey)).onPressed,
        isNotNull,
      );

      // Forms render structurally, but this lease cannot reply to forms.
      expect(find.byKey(_formKey), findsOneWidget);
      expect(find.byKey(const ValueKey('form-field-name')), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(_submitKey)).onPressed, isNull);
      expect(tester.widget<TextButton>(find.byKey(_dismissKey)).onPressed, isNull);
      expect(live.canReplyForm(live.state!.interactions.last), isFalse);

      // Delivery toggle is always offered and flips the local choice.
      final queue = find.byKey(const ValueKey('live-delivery-queue'));
      await tester.ensureVisible(queue);
      await tester.tap(queue);
      await tester.pump();
      expect(tester.widget<ChoiceChip>(queue).selected, isTrue);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('live-delivery-steer')))
            .selected,
        isFalse,
      );

      // Typing makes the send available and posting reaches the adapter.
      await tester.enterText(
        find.byKey(const ValueKey('live-composer-input')),
        'synthetic prompt',
      );
      await tester.pump();
      final send = find.byKey(const ValueKey('live-composer-send'));
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pump();
      expect(scenario.adapter.commands, hasLength(1));
      expect(scenario.adapter.commands.single.id, sendId);
      expect(
        scenario.adapter.commands.single.operation.known,
        MutationOperation.prompt,
      );

      // Stop is offered while the turn runs and posts under the authored id.
      expect(live.canStop, isTrue);
      final stop = find.byKey(const ValueKey('live-stop'));
      expect(stop, findsOneWidget);
      expect(tester.widget<IconButton>(stop).onPressed, isNotNull);
      await tester.ensureVisible(stop);
      await tester.tap(stop);
      await tester.pump();
      await tester.pump();
      expect(scenario.adapter.commands, hasLength(2));
      expect(scenario.adapter.commands.last.id, interruptId);
      expect(
        scenario.adapter.commands.last.operation.known,
        MutationOperation.interrupt,
      );
      // The accepted receipt leaves the stop in its requested phase: the
      // notice stays, the ready control gives way to the busy state, and the
      // slot stays occupied while the request waits. The gate stays shut even
      // though a second authored interrupt id remains.
      expect(live.stopState.phase, SessionStopPhase.requested);
      expect(live.stopping, isTrue);
      expect(live.canStop, isFalse);
      expect(find.text('Stop requested…'), findsOneWidget);
      expect(find.byKey(const ValueKey('live-stop')), findsNothing);
      expect(send, findsNothing);

      // The shared v2 screens expose no terminal, undo or usage controls.
      for (final absent in const [
        'live-terminal',
        'live-undo',
        'live-usage',
        'live-quota',
      ]) {
        expect(find.byKey(ValueKey(absent)), findsNothing);
      }
      expect(scenario.adapter.remainingSteps, 1);
    });

    testWidgets('stopping: the stop slot reports the requested receipt and '
        'leaves no ready control behind', (tester) async {
      final scenario = _controlsScenario();
      addTearDown(scenario.adapter.dispose);
      final bridge = _bridge(
        scenario,
        interruptIds: const [interruptId],
      );
      final live = await _mount(tester, bridge);
      await _pumpUntil(tester, () => live.phase == SessionLivePhase.live);

      await _steps(tester, scenario.adapter, 1);
      expect(live.canStop, isTrue);
      final stop = find.byKey(const ValueKey('live-stop'));
      await tester.ensureVisible(stop);
      await tester.tap(stop);
      await tester.pump();
      await tester.pump();
      expect(scenario.adapter.commands.single.id, interruptId);
      expect(live.stopState.phase, SessionStopPhase.requested);
      expect(find.text('Stop requested…'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('live-stop')),
        findsNothing,
      );
      expect(scenario.adapter.remainingSteps, 3);
    });

    testWidgets('reconnecting: every action gates off while the synced state '
        'stays readable and flagged', (tester) async {
      final scenario = _controlsScenario();
      addTearDown(scenario.adapter.dispose);
      final bridge = _bridge(
        scenario,
        sendIds: const [sendId],
        interruptIds: const [interruptId],
      );
      final live = await _mount(tester, bridge);
      await _pumpUntil(tester, () => live.phase == SessionLivePhase.live);
      expect(live.phase, SessionLivePhase.live);

      await _steps(tester, scenario.adapter, 4);
      expect(live.phase, SessionLivePhase.reconnecting);
      expect(
        find.text('Not up to date; showing the last synced state.'),
        findsOneWidget,
      );
      // The synced state is still on screen.
      expect(live.state!.interactions, hasLength(2));

      // Sending is disabled while stale: a tap must not post.
      await tester.enterText(
        find.byKey(const ValueKey('live-composer-input')),
        'synthetic prompt',
      );
      await tester.pump();
      expect(_sendEnabled(tester), isFalse);
      final send = find.byKey(const ValueKey('live-composer-send'));
      await tester.ensureVisible(send);
      await tester.tap(send, warnIfMissed: false);
      await tester.pump();
      expect(scenario.adapter.commands, isEmpty);

      // The reply gate follows the same live/stale rule.
      expect(tester.widget<FilledButton>(find.byKey(_allowKey)).onPressed, isNull);
      // Stop is not offered while not live.
      expect(find.byKey(const ValueKey('live-stop')), findsNothing);
      // The local delivery choice keeps working offline.
      final queue = find.byKey(const ValueKey('live-delivery-queue'));
      await tester.ensureVisible(queue);
      await tester.tap(queue);
      await tester.pump();
      expect(tester.widget<ChoiceChip>(queue).selected, isTrue);

      expect(scenario.adapter.remainingSteps, 0);
    });

    testWidgets('gates off: without replies and outbox the resident requests '
        'render nothing and the footer explains the read-only view',
        (tester) async {
      final scenario = _controlsScenario();
      addTearDown(scenario.adapter.dispose);
      final bridge = _bridge(scenario, intent: OpenIntent.viewHistory);
      final live = await _mount(tester, bridge);
      await _pumpUntil(tester, () => live.phase == SessionLivePhase.live);

      expect(live.supportsReplies, isFalse);
      expect(live.outbox, isNull);
      expect(find.text('Live session (read-only)'), findsOneWidget);
      expect(
        find.text('Prompt sending is unavailable in this view.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('live-composer-input')), findsNothing);

      // Running, permission and form interactions arrive but render nothing:
      // no cards, and no stop control even while the turn runs.
      await _steps(tester, scenario.adapter, 3);
      expect(live.state!.interactions, hasLength(2));
      expect(find.byKey(_allowKey), findsNothing);
      expect(find.byKey(_rejectKey), findsNothing);
      expect(find.byKey(_formKey), findsNothing);
      expect(find.byKey(const ValueKey('live-stop')), findsNothing);
      expect(scenario.adapter.commands, isEmpty);

      await _steps(tester, scenario.adapter, 1);
      expect(find.byKey(const ValueKey('live-composer-input')), findsNothing);
      expect(
        find.text('Prompt sending is unavailable in this view.'),
        findsOneWidget,
      );
      expect(scenario.adapter.commands, isEmpty);
      expect(scenario.adapter.remainingSteps, 0);
    });

    testWidgets('replies without a ledger: the permission card stays '
        'answerable while the composer explains the missing outbox',
        (tester) async {
      final scenario = _noOutboxScenario();
      addTearDown(scenario.adapter.dispose);
      // attachLive with no sendIds: the lease keeps replies but the outbox
      // is missing, so cards gate on while the composer gates off.
      final bridge = _bridge(scenario, respondIds: const [respondId]);
      final live = await _mount(tester, bridge);
      await _pumpUntil(tester, () => live.phase == SessionLivePhase.live);

      await _steps(tester, scenario.adapter, 2);
      expect(live.supportsReplies, isTrue);
      expect(live.outbox, isNull);
      expect(
        find.text('Prompt sending is unavailable in this view.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('live-composer-input')), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byKey(_noOutboxAllow)).onPressed,
        isNotNull,
      );

      await tester.tap(find.byKey(_noOutboxAllow));
      await tester.pump();
      expect(scenario.adapter.commands, hasLength(1));
      expect(scenario.adapter.commands.single.id, respondId);
      expect(
        scenario.adapter.commands.single.operation.known,
        MutationOperation.respond,
      );
      expect(find.text('Reply sent. Follow the live state.'), findsOneWidget);
      expect(scenario.adapter.remainingSteps, 0);
    });
  });
}

/// One live lease with a native (answerable) permission, a form request and a
/// running turn, then a transport reconnect: the shared superset of states the
/// controls must gate on. Authored outcomes are consumed in strict FIFO
/// command order, so [sendFirst] mirrors the order a test drives the screen.
ScriptedScenario _controlsScenario({bool sendFirst = false}) {
  const owner = SessionOwner(ownedRef);
  const permissionId = InteractionId('controls-permission');
  const formId = InteractionId('controls-form');
  final permission = InteractionRequest(
    id: permissionId,
    owner: owner,
    kind: const OpenValue.known(InteractionKind.permission),
    title: 'Synthetic permission',
    autoApprovable: false,
    choices: [
      ApprovalChoice(
        id: 'once',
        label: 'Allow once',
        allows: true,
        scope: const OpenValue.known(ApprovalScope.once),
        resolutionScope: const OpenValue.known(ResolutionScope.request),
      ),
      ApprovalChoice(
        id: 'reject',
        label: 'Reject',
        allows: false,
        acceptsNote: true,
        scope: const OpenValue.known(ApprovalScope.once),
        resolutionScope: const OpenValue.known(ResolutionScope.session),
      ),
    ],
  );
  final form = InteractionRequest(
    id: formId,
    owner: owner,
    kind: const OpenValue.known(InteractionKind.form),
    title: 'Synthetic form',
    form: FormSpec(
      fields: [
        FormField(
          key: 'name',
          kind: const OpenValue.known(FormFieldKind.string),
          title: 'Name',
        ),
      ],
    ),
  );
  return ScriptedScenario(
    'screen_controls',
    scriptedAdapter(
      reads: [
        ScriptedRead(
          id: 'controls-read',
          ref: ownedRef,
          generation: 'controls-hydration',
          collections: const [
            SessionCollection.info,
            SessionCollection.timeline,
            SessionCollection.execution,
          ],
          build: (b) => SessionSnapshot(
            ref: ownedRef,
            hydrationGeneration: 'controls-hydration',
            info: SnapshotValue(
              value: scriptedInfo(ownedRef),
              boundary: b[SessionCollection.info]!,
            ),
            timeline: SnapshotCollection(
              values: const [],
              boundary: b[SessionCollection.timeline]!,
            ),
            execution: SnapshotValue(
              value: const ExecutionState(
                kind: OpenValue.known(ExecutionKind.idle),
              ),
              boundary: b[SessionCollection.execution]!,
            ),
          ),
        ),
      ],
      outcomes: [
        // Authored outcomes are consumed in strict FIFO command order.
        if (sendFirst) ...[
          acceptedOutcome(
            sendId,
            owner,
            MutationOperation.prompt,
            promptIntent(scriptedDraft()),
          ),
          acceptedOutcome(
            interruptId,
            owner,
            MutationOperation.interrupt,
            interruptIntent(scriptedInterrupt),
          ),
          acceptedOutcome(
            interruptId2,
            owner,
            MutationOperation.interrupt,
            interruptIntent(scriptedInterrupt),
          ),
        ] else ...[
          acceptedOutcome(
            interruptId,
            owner,
            MutationOperation.interrupt,
            interruptIntent(scriptedInterrupt),
          ),
          acceptedOutcome(
            sendId,
            owner,
            MutationOperation.prompt,
            promptIntent(scriptedDraft()),
          ),
        ],
      ],
      steps: [
        EmitEvent(
          ownedRef,
          ExecutionChanged(
            meta: scriptedMeta(1),
            state: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.running),
            ),
          ),
        ),
        EmitEvent(
          ownedRef,
          InteractionOpened(meta: scriptedMeta(2), request: permission),
        ),
        EmitEvent(
          ownedRef,
          InteractionOpened(meta: scriptedMeta(3), request: form),
        ),
        const EmitConnection(
          ConnectionState(kind: OpenValue.known(ConnectionKind.reconnecting)),
        ),
      ],
    ),
  );
}

/// A live lease with replies but no outbox ledger: one native permission on a
/// running turn, answerable through the card while the composer stays off.
ScriptedScenario _noOutboxScenario() {
  const owner = SessionOwner(ownedRef);
  const permissionId = InteractionId('nooutbox-permission');
  final permission = InteractionRequest(
    id: permissionId,
    owner: owner,
    kind: const OpenValue.known(InteractionKind.permission),
    title: 'Synthetic permission',
    autoApprovable: false,
    choices: [
      ApprovalChoice(
        id: 'once',
        label: 'Allow once',
        allows: true,
        scope: const OpenValue.known(ApprovalScope.once),
        resolutionScope: const OpenValue.known(ResolutionScope.request),
      ),
    ],
  );
  return ScriptedScenario(
    'screen_no_outbox',
    scriptedAdapter(
      reads: [
        ScriptedRead(
          id: 'nooutbox-read',
          ref: ownedRef,
          generation: 'controls-hydration',
          collections: const [
            SessionCollection.info,
            SessionCollection.timeline,
            SessionCollection.execution,
          ],
          build: (b) => SessionSnapshot(
            ref: ownedRef,
            hydrationGeneration: 'controls-hydration',
            info: SnapshotValue(
              value: scriptedInfo(ownedRef),
              boundary: b[SessionCollection.info]!,
            ),
            timeline: SnapshotCollection(
              values: const [],
              boundary: b[SessionCollection.timeline]!,
            ),
            execution: SnapshotValue(
              value: const ExecutionState(
                kind: OpenValue.known(ExecutionKind.idle),
              ),
              boundary: b[SessionCollection.execution]!,
            ),
          ),
        ),
      ],
      outcomes: [
        acceptedOutcome(
          respondId,
          owner,
          MutationOperation.respond,
          responseIntent(permissionId, ApprovalResponse('once')),
        ),
      ],
      steps: [
        EmitEvent(
          ownedRef,
          ExecutionChanged(
            meta: scriptedMeta(1),
            state: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.running),
            ),
          ),
        ),
        EmitEvent(
          ownedRef,
          InteractionOpened(meta: scriptedMeta(2), request: permission),
        ),
      ],
    ),
  );
}
