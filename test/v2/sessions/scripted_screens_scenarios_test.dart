import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/features/sessions/session_live_page.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/rendering/canonical_message_body.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart' hide ConnectionState, FormField;
import 'package:flutter_test/flutter_test.dart';

import '../../../packages/codewalk_core/test/support/scripted_harness_adapter.dart';
import '../../../packages/codewalk_core/test/support/scripted_harness_scenarios.dart';
import 'fakes.dart';
import 'scripted_live_bridge.dart';

/// Drives the six synthetic V2-024A scenarios through the real shared
/// screens: the accepted reducer, the live controller, the composer and the
/// permission cards, with only the transport replaced by the scripted
/// adapter through [ScriptedLiveBridge]. Nothing here imports harness code
/// into `lib/`.
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

/// The rendered source of one timeline item's body; rich text never matches
/// `find.text`, so the screen is asserted through what it actually rendered.
String _body(WidgetTester tester, String itemId) => tester
    .widget<CanonicalMessageBody>(
      find.byKey(ValueKey('timeline-content-$itemId')),
    )
    .source;

void main() {
  group('six synthetic scenarios through the real session screens', () {
    testWidgets('owned_stream: composed deltas, unknowns and stuck effects '
        'never regress the live chat', (tester) async {
      final scenario = ownedStream();
      addTearDown(scenario.adapter.dispose);
      final bridge = ScriptedLiveBridge(
        scenario,
        hydrations: const ['owned-hydration'],
        sendIds: const [sendId],
        interruptIds: const [interruptId],
      );
      final live = await _mount(tester, bridge);
      await _pumpUntil(tester, () => live.phase == SessionLivePhase.live);
      expect(live.phase, SessionLivePhase.live);
      expect(find.text('Live'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('live-composer-input')),
        'synthetic prompt',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('live-composer-send')));
      await tester.pump();
      expect(scenario.adapter.commands, hasLength(1));
      final sent = scenario.adapter.commands.single;
      expect(sent.id, sendId);
      expect(sent.operation.known, MutationOperation.prompt);

      await _steps(tester, scenario.adapter, 1);
      expect(find.text('Running'), findsOneWidget);
      expect(live.canStop, isTrue);
      expect(find.byKey(const ValueKey('live-stop')), findsOneWidget);

      await _steps(tester, scenario.adapter, 2);
      expect(_body(tester, 'assistant'), 'prefix-fragment');
      final beforeDuplicate = live.state;
      await _steps(tester, scenario.adapter, 1);
      expect(live.state, same(beforeDuplicate));

      await _steps(tester, scenario.adapter, 3);
      expect(_body(tester, 'assistant'), 'complete answer');
      expect(
        live.state!.execution!.lastOutcome!.kind.known,
        ExecutionOutcomeKind.succeeded,
      );
      await _steps(tester, scenario.adapter, 2);
      expect(
        live.state!.timeline.whereType<AssistantText>(),
        hasLength(1),
      );
      expect(
        live.state!.timeline.whereType<UnknownItem>().single.rawType,
        'future.item.v9',
      );

      // Steps 10-12: Refetch and two out-of-scope/epoch events are consumed
      // by the reducer; the screen must stay live and unchanged.
      await _steps(tester, scenario.adapter, 3);
      expect(_body(tester, 'assistant'), 'complete answer');
      expect(live.phase, SessionLivePhase.live);
      expect(find.text('Last turn succeeded'), findsOneWidget);
      expect(scenario.adapter.remainingSteps, 0);
      expect(scenario.adapter.commands, hasLength(1));
    });

    testWidgets('offered_permission: coincident ids in parent, child and '
        'project scopes stay independent on screen', (tester) async {
      final scenario = offeredPermission();
      addTearDown(scenario.adapter.dispose);
      final bridge = ScriptedLiveBridge(scenario);
      final live = await _mount(tester, bridge);
      await _pumpUntil(tester, () => live.view != null);
      expect(live.phase, SessionLivePhase.connecting);
      expect(live.supportsReplies, isTrue);

      // Three resident requests share the native id 'coincident-request-id'
      // across distinct scopes: child, own session and another project.
      await _steps(tester, scenario.adapter, 3);
      expect(find.text('Synthetic permission'), findsNWidgets(3));
      const childKey = ValueKey(
        'live-permission-child/coincident-request-id',
      );
      const ownKey = ValueKey('live-permission-coincident-request-id');
      final projectKey = ValueKey(
        'live-permission-${ProjectOwner(otherProject, harness: scriptedHarness).scopeKey}/coincident-request-id',
      );
      expect(find.byKey(childKey), findsOneWidget);
      expect(find.byKey(ownKey), findsOneWidget);
      expect(find.byKey(projectKey), findsOneWidget);
      // Non-native choices are never offered as actions.
      expect(find.text('Allow once'), findsNothing);
      expect(find.text('Reject and stop'), findsNothing);

      // Step 4: the child request resolves. Step 5: the session's own request
      // resolves elsewhere. Step 6: an unknown-kind request is accepted by
      // the reducer and safely skipped by the screen.
      await _steps(tester, scenario.adapter, 2);
      expect(find.text('Synthetic permission'), findsOneWidget);
      expect(find.byKey(childKey), findsNothing);
      expect(find.byKey(ownKey), findsNothing);
      expect(find.byKey(projectKey), findsOneWidget);
      expect(scenario.adapter.commands, isEmpty);
      await _steps(tester, scenario.adapter, 1);
      expect(find.text('Synthetic permission'), findsOneWidget);
      expect(find.byKey(projectKey), findsOneWidget);
      // Step 6 adds a future-kind request: it stays in the live state but
      // never renders a card, so only the project card remains answerable.
      expect(live.state!.interactions, hasLength(2));
      expect(
        live.state!.interactions.map((request) => request.kind.known),
        contains(InteractionKind.permission),
      );
      expect(
        live.state!.interactions.where((request) => request.kind.known == null),
        hasLength(1),
      );
      expect(scenario.adapter.remainingSteps, 0);
    });

    testWidgets('structured_usage: nullable, estimated and cumulative series '
        'stay distinct through the controller', (tester) async {
      final scenario = structuredUsage();
      addTearDown(scenario.adapter.dispose);
      final bridge = ScriptedLiveBridge(scenario);
      final live = await _mount(tester, bridge);
      await _pumpUntil(tester, () => live.view != null);

      await _steps(tester, scenario.adapter, 2);
      final beforeDuplicate = live.state;
      await _steps(tester, scenario.adapter, 1);
      expect(live.state, same(beforeDuplicate));
      await _steps(tester, scenario.adapter, 4);
      final usage = live.state!.usage;
      expect(usage, hasLength(5));
      final cumulative = usage.singleWhere(
        (entry) => entry.cumulative && !entry.partial,
      );
      expect(cumulative.id, 'cumulative-2');
      expect(cumulative.tokens!.input, 125);
      expect(cumulative.cost!.amount, 0.75);
      final partialSeries = usage.singleWhere(
        (entry) => entry.id == 'partial-series',
      );
      expect(partialSeries.tokens!.input, 3);
      expect(
        partialSeries.aggregationIdentity,
        cumulative.aggregationIdentity,
      );
      final quota = usage.singleWhere((entry) => entry.id == 'quota');
      expect(quota.quotas.single.usedPercent, 123.4);
      expect(usage.last.scope.known, isNull);

      // Step 8: the usage recovery request is consumed by the reducer; the
      // screen stays stable and never posts.
      await _steps(tester, scenario.adapter, 1);
      expect(scenario.adapter.commands, isEmpty);
      expect(scenario.adapter.remainingSteps, 0);
    });

    testWidgets('error_and_uncertain_admission: reconnecting disables the '
        'composer and a failed turn stays visible', (tester) async {
      final scenario = errorAndUncertainAdmission();
      addTearDown(scenario.adapter.dispose);
      final bridge = ScriptedLiveBridge(
        scenario,
        sendIds: const [sendId],
        interruptIds: const [interruptId],
      );
      final live = await _mount(tester, bridge);
      await _pumpUntil(tester, () => live.view != null);
      expect(live.phase, SessionLivePhase.connecting);

      await _steps(tester, scenario.adapter, 2);
      expect(live.phase, SessionLivePhase.reconnecting);
      expect(find.text('Reconnecting…'), findsOneWidget);
      expect(live.state!.execution!.kind.known, ExecutionKind.retrying);

      // Sending is disabled while reconnecting: a tap must not post.
      await tester.tap(
        find.byKey(const ValueKey('live-composer-send')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(scenario.adapter.commands, isEmpty);
      expect(await live.outbox!.entries(live.session), isEmpty);

      await _steps(tester, scenario.adapter, 1);
      expect(find.text('Last turn failed'), findsOneWidget);
      expect(
        live.state!.execution!.lastOutcome!.kind.known,
        ExecutionOutcomeKind.failed,
      );
      expect(scenario.adapter.commands, isEmpty);
      expect(scenario.adapter.remainingSteps, 0);
    });

    testWidgets('disconnect_hydrate: reverse read completion never regresses '
        'the screen', (tester) async {
      final scenario = disconnectHydrate();
      addTearDown(scenario.adapter.dispose);
      final bridge = ScriptedLiveBridge(
        scenario,
        hydrations: const ['old-hydration', 'new-hydration'],
      );
      final live = await _mount(tester, bridge);
      await _pumpUntil(tester, () => live.view != null);
      expect(live.phase, SessionLivePhase.hydrating);

      await _steps(tester, scenario.adapter, 3);
      expect(live.phase, SessionLivePhase.reconnecting);
      expect(find.text('Reconnecting…'), findsOneWidget);
      expect(live.state!.execution!.kind.known, ExecutionKind.running);
      expect(
        (live.state!.item(assistantId)! as AssistantText).prefixMissing,
        isTrue,
      );

      await _steps(tester, scenario.adapter, 9);
      expect(
        (live.state!.item(assistantId)! as AssistantText).text,
        'authoritative finished',
      );
      expect(_body(tester, 'assistant'), 'authoritative finished');

      // Step 13: the newer read finishes first and hydrates the session.
      await _steps(tester, scenario.adapter, 1);
      expect(live.phase, SessionLivePhase.live);
      expect(find.text('Live'), findsOneWidget);
      final hydrated = live.state!.item(assistantId)! as AssistantText;
      expect(hydrated.complete, isTrue);
      expect(hydrated.prefixMissing, isFalse);

      // Steps 14-16: the older read is superseded, then buffered events land;
      // the authoritative text survives.
      await _steps(tester, scenario.adapter, 3);
      expect(_body(tester, 'assistant'), 'authoritative finished');
      expect(live.phase, SessionLivePhase.live);
      expect(scenario.adapter.commands, isEmpty);
      expect(scenario.adapter.remainingSteps, 0);
    });

    testWidgets('history_only_external: a read-only external session never '
        'sends and ignores foreign events', (tester) async {
      final scenario = historyOnlyExternal();
      addTearDown(scenario.adapter.dispose);
      final bridge = ScriptedLiveBridge(
        scenario,
        intent: OpenIntent.viewHistory,
        hydrations: const ['external-hydration'],
      );
      final live = await _mount(tester, bridge);
      await _pumpUntil(tester, () => live.phase == SessionLivePhase.live);
      expect(_body(tester, 'history'), 'historical only');
      expect(
        find.text('Prompt sending is unavailable in this view.'),
        findsOneWidget,
      );
      expect(live.supportsReplies, isFalse);
      expect(live.outbox, isNull);

      // Step 1 is an unknown external event; step 2 targets this client's own
      // session with no lease. Both stay inert.
      await _steps(tester, scenario.adapter, 2);
      expect(
        live.state!.diagnostics.single.rawType,
        'future.external.v9',
      );
      expect(live.state!.execution!.kind.known, ExecutionKind.unknown);
      expect(_body(tester, 'history'), 'historical only');
      expect(live.phase, SessionLivePhase.live);
      expect(scenario.adapter.commands, isEmpty);
      expect(scenario.adapter.remainingSteps, 0);
    });
  });

  testWidgets('screen shape: native once/reject choices reply and stop '
      'through the real cards', (tester) async {
    final scenario = _shapeScenario();
    addTearDown(scenario.adapter.dispose);
    final bridge = ScriptedLiveBridge(
      scenario,
      hydrations: const ['shape-hydration'],
      respondIds: const [respondId],
      interruptIds: const [interruptId],
    );
    final live = await _mount(tester, bridge);
    await _pumpUntil(tester, () => live.phase == SessionLivePhase.live);
    expect(live.phase, SessionLivePhase.live);

    await _steps(tester, scenario.adapter, 2);
    const allowKey = ValueKey('live-permission-allow-shape-permission');
    const rejectKey = ValueKey('live-permission-reject-stop-shape-permission');
    expect(
      tester.widget<FilledButton>(find.byKey(allowKey)).onPressed,
      isNotNull,
    );
    expect(
      tester.widget<TextButton>(find.byKey(rejectKey)).onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(allowKey));
    await tester.pump();
    expect(scenario.adapter.commands, hasLength(1));
    final replied = scenario.adapter.commands.single;
    expect(replied.id, respondId);
    expect(replied.operation.known, MutationOperation.respond);
    expect(find.text('Reply sent. Follow the live state.'), findsOneWidget);
    // 204 never removes a card; only the stream does, and the fence holds.
    expect(find.byKey(allowKey), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(allowKey)).onPressed,
      isNull,
    );

    // Execution is running and the field is empty, so the stop control takes
    // the send slot; stopping posts the authored interrupt id.
    await tester.tap(find.byKey(const ValueKey('live-stop')));
    await tester.pump();
    expect(scenario.adapter.commands, hasLength(2));
    expect(scenario.adapter.commands.last.id, interruptId);
    expect(
      scenario.adapter.commands.last.operation.known,
      MutationOperation.interrupt,
    );
    expect(live.stopping, isTrue);

    // Step 3 resolves the interaction: the stream removes the card, never the
    // 204.
    await _steps(tester, scenario.adapter, 1);
    expect(find.byKey(allowKey), findsNothing);
    expect(scenario.adapter.remainingSteps, 0);
  });

  testWidgets('coincident reply: answering the own card never leaks busy or '
      'notice state onto the foreign card with the same native id',
      (tester) async {
    final scenario = _coincidentReplyScenario();
    addTearDown(scenario.adapter.dispose);
    final bridge = ScriptedLiveBridge(
      scenario,
      hydrations: const ['coincident-reply-hydration'],
      respondIds: const [respondId],
    );
    final live = await _mount(tester, bridge);
    await _pumpUntil(tester, () => live.phase == SessionLivePhase.live);

    // The own and the project request share one native interaction id but
    // mount as independent cards.
    await _steps(tester, scenario.adapter, 3);
    const ownKey = ValueKey('live-permission-coincident-reply');
    final projectKey = ValueKey(
      'live-permission-${ProjectOwner(otherProject, harness: scriptedHarness).scopeKey}/coincident-reply',
    );
    expect(find.byKey(ownKey), findsOneWidget);
    expect(find.byKey(projectKey), findsOneWidget);
    // The foreign card is never answerable, before or after the own reply.
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: find.byKey(projectKey),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(ownKey),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pump();
    expect(scenario.adapter.commands, hasLength(1));
    expect(scenario.adapter.commands.single.id, respondId);
    expect(find.text('Reply sent. Follow the live state.'), findsOneWidget);
    // The notice and the busy indicator stay on the answered card only.
    expect(
      find.descendant(
        of: find.byKey(projectKey),
        matching: find.text('Reply sent. Follow the live state.'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(projectKey),
        matching: find.byType(LinearProgressIndicator),
      ),
      findsNothing,
    );
    expect(scenario.adapter.remainingSteps, 0);
  });

  testWidgets('coincident forms: an own and a project form with the same '
      'native id mount with independent keys', (tester) async {
    final scenario = _coincidentFormsScenario();
    addTearDown(scenario.adapter.dispose);
    final bridge = ScriptedLiveBridge(
      scenario,
      hydrations: const ['coincident-forms-hydration'],
    );
    final live = await _mount(tester, bridge);
    await _pumpUntil(tester, () => live.phase == SessionLivePhase.live);

    await _steps(tester, scenario.adapter, 3);
    const ownFormKey = ValueKey('live-form-coincident-form');
    final projectFormKey = ValueKey(
      'live-form-${ProjectOwner(otherProject, harness: scriptedHarness).scopeKey}/coincident-form',
    );
    expect(find.byKey(ownFormKey), findsOneWidget);
    expect(find.byKey(projectFormKey), findsOneWidget);
    // The lease cannot reply to forms, so both submits stay disabled.
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('form-submit-coincident-form')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(
              ValueKey(
                'form-submit-${ProjectOwner(otherProject, harness: scriptedHarness).scopeKey}/coincident-form',
              ),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(scenario.adapter.remainingSteps, 0);
  });
}

ScriptedScenario _shapeScenario() {
  const owner = SessionOwner(ownedRef);
  const shapeId = InteractionId('shape-permission');
  final request = InteractionRequest(
    id: shapeId,
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
  return ScriptedScenario(
    'screen_shape',
    scriptedAdapter(
      reads: [
        ScriptedRead(
          id: 'shape-read',
          ref: ownedRef,
          generation: 'shape-hydration',
          collections: const [
            SessionCollection.info,
            SessionCollection.timeline,
            SessionCollection.execution,
          ],
          build: (b) => SessionSnapshot(
            ref: ownedRef,
            hydrationGeneration: 'shape-hydration',
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
          responseIntent(shapeId, ApprovalResponse('once')),
        ),
        acceptedOutcome(
          interruptId,
          owner,
          MutationOperation.interrupt,
          interruptIntent(scriptedInterrupt),
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
          InteractionOpened(meta: scriptedMeta(2), request: request),
        ),
        EmitEvent(
          ownedRef,
          InteractionResolved(
            meta: scriptedMeta(3),
            resolution: InteractionResolution(
              id: shapeId,
              owner: owner,
              kind: const OpenValue.known(InteractionResolutionKind.self),
              response: ApprovalResponse('once'),
              resolvedAt: scriptedNow,
              source: CanonicalValue({'syntheticResponder': 'this-client'}),
            ),
          ),
        ),
      ],
    ),
  );
}

/// An own and a project permission request sharing one native id. Only the
/// own request is answerable; replying to it must not leak busy, notice or
/// draft state onto the foreign card.
ScriptedScenario _coincidentReplyScenario() {
  const owner = SessionOwner(ownedRef);
  const id = InteractionId('coincident-reply');
  InteractionRequest permission(DomainOwner requestOwner) =>
      InteractionRequest(
        id: id,
        owner: requestOwner,
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
    'screen_coincident_reply',
    scriptedAdapter(
      reads: [
        ScriptedRead(
          id: 'coincident-reply-read',
          ref: ownedRef,
          generation: 'coincident-reply-hydration',
          collections: const [
            SessionCollection.info,
            SessionCollection.timeline,
            SessionCollection.execution,
          ],
          build: (b) => SessionSnapshot(
            ref: ownedRef,
            hydrationGeneration: 'coincident-reply-hydration',
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
          responseIntent(id, ApprovalResponse('once')),
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
          InteractionOpened(
            meta: scriptedMeta(2),
            request: permission(owner),
          ),
        ),
        EmitEvent(
          ownedRef,
          InteractionOpened(
            meta: scriptedMeta(3),
            request: permission(
              ProjectOwner(otherProject, harness: scriptedHarness),
            ),
          ),
        ),
      ],
    ),
  );
}

/// An own and a project form sharing one native id, proving the scope
/// qualification of form keys mirrors the permission fix.
ScriptedScenario _coincidentFormsScenario() {
  const owner = SessionOwner(ownedRef);
  const id = InteractionId('coincident-form');
  InteractionRequest form(DomainOwner requestOwner) => InteractionRequest(
    id: id,
    owner: requestOwner,
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
    'screen_coincident_forms',
    scriptedAdapter(
      reads: [
        ScriptedRead(
          id: 'coincident-forms-read',
          ref: ownedRef,
          generation: 'coincident-forms-hydration',
          collections: const [
            SessionCollection.info,
            SessionCollection.timeline,
            SessionCollection.execution,
          ],
          build: (b) => SessionSnapshot(
            ref: ownedRef,
            hydrationGeneration: 'coincident-forms-hydration',
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
      outcomes: const [],
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
          InteractionOpened(meta: scriptedMeta(2), request: form(owner)),
        ),
        EmitEvent(
          ownedRef,
          InteractionOpened(
            meta: scriptedMeta(3),
            request: form(
              ProjectOwner(otherProject, harness: scriptedHarness),
            ),
          ),
        ),
      ],
    ),
  );
}
