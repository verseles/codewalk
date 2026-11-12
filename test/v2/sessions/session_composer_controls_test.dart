import 'dart:async';

import 'package:codewalk/features/sessions/session_agent_color.dart';
import 'package:codewalk/features/sessions/session_composer_controls.dart';
import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/features/sessions/session_selection_chip.dart';
import 'package:codewalk/platform/sessions/permission_mode_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/permission_mode.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/sessions/session_selection.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';

final _alpha = ModelEntry(
  id: 'alpha',
  providerId: 'prov',
  label: 'Alpha',
  variants: ['low', 'high'],
);
final _build = CatalogEntry(
  id: 'build',
  kind: const OpenValue.known(CatalogKind.agent),
  label: 'Build',
);
final _plan = CatalogEntry(
  id: 'plan',
  kind: const OpenValue.known(CatalogKind.agent),
  label: 'Plan',
);

InteractionRequest _permission(SessionRef ref, String id) => InteractionRequest(
  id: InteractionId(id),
  owner: SessionOwner(ref),
  kind: const OpenValue.known(InteractionKind.permission),
  title: 'Run a command',
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

void main() {
  late CatalogRig rig;
  late LiveDirectory directory;
  late PermissionModeStore policy;

  setUp(() async {
    rig = CatalogRig();
    await rig.save('a');
    await rig.sessions.initialize();
    directory = LiveDirectory();
    policy = PermissionModeStore(
      store: V2MetadataStore(backend: FakeMetadataBackend()),
    );
    await policy.initialize();
  });

  tearDown(() {
    policy.dispose();
    rig.dispose();
  });

  /// A live session showing [selection], with [permissions] waiting, under
  /// the composer's controls.
  Future<(SessionLiveController, LiveHandle)> open(
    WidgetTester tester, {
    String id = 'one',
    String? parent,
    int permissions = 0,
    Size size = const Size(800, 900),
    double keyboard = 0,
    bool nestedNavigator = false,
    Alignment alignment = Alignment.bottomCenter,
    Locale locale = const Locale('en'),
    double textScale = 1,
  }) async {
    final source = CatalogSource(profile('a'));
    final summary = source.row(id, parent: parent);
    final ref = summary.info.ref;
    final live = SessionLiveController(
      hosts: rig.hosts,
      profile: profile('a'),
      summary: summary,
      directory: directory,
      permissionModes: policy,
    );
    addTearDown(live.dispose);
    final opening = live.start();
    final handle = directory.grant(ref)
      ..selectionAvailable = true
      ..selectionState = SessionSelectionState(
        selection: const Selection(
          modelId: 'alpha',
          modelProviderId: 'prov',
          modelVariant: 'high',
          agentId: 'build',
        ),
        models: [_alpha],
        agents: [_build, _plan],
      );
    await opening;
    handle.emit(
      SessionLiveView(
        session: ref,
        phase: SessionLivePhase.live,
        state: liveState(
          ref,
          interactions: [
            for (var i = 0; i < permissions; i++) _permission(ref, 'p$i'),
          ],
        ),
      ),
    );
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);
    final controls = Align(
      alignment: alignment,
      child: SessionModelChip(live: live),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: V2Localizations.localizationsDelegates,
        supportedLocales: V2Localizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: nestedNavigator
              ? Row(
                  children: [
                    const SizedBox(width: 260),
                    Expanded(
                      child: Navigator(
                        onGenerateRoute: (_) =>
                            MaterialPageRoute<void>(builder: (_) => controls),
                      ),
                    ),
                  ],
                )
              : controls,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (live, handle);
  }

  Finder chip(String key, String text) =>
      find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text));

  final modelChip = find.byKey(const ValueKey('live-model-chip'));

  final autoApprove = find.byKey(const ValueKey('live-auto-approve'));
  final pickOpen = find.byKey(const ValueKey('live-selection-search'));

  /// Scrolls the pick's list until [target] is built and shown.
  Future<void> reach(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      80,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('live-selection-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  /// Opens the one pick as the chip, `/model` and `/agent` open it (#485).
  Future<void> openPick(WidgetTester tester, SessionLiveController live) async {
    unawaited(showSessionSelection(tester.element(modelChip), live));
    await tester.pumpAndSettle();
  }

  Color chipColor(WidgetTester tester) =>
      tester.widget<ActionChip>(modelChip).color!.resolve({})!;

  /// The chip shows a wash of the agent's color over the surface.
  Color washed(WidgetTester tester, Color agent) => sessionAgentWash(
    agent,
    Theme.of(tester.element(modelChip)).colorScheme.surface,
  );

  testWidgets('one chip shows the model and variant on the agent color', (
    tester,
  ) async {
    await open(tester, permissions: 2);
    expect(chip('live-model-chip', 'Alpha high'), findsOneWidget);
    expect(find.byKey(const ValueKey('live-agent-chip')), findsNothing);
    expect(find.byKey(const ValueKey('live-variant-chip')), findsNothing);
    // Build without a color of its own is green.
    expect(chipColor(tester), washed(tester, sessionDefaultAgentColor));
    // The pending permissions moved into the pick (#485).
    expect(find.byType(Badge), findsNothing);
  });

  testWidgets('the chip takes the agent color: own, plan, or the palette', (
    tester,
  ) async {
    final (_, handle) = await open(tester);
    Future<void> pick(String agent, List<CatalogEntry> agents) async {
      handle.selectionState = SessionSelectionState(
        selection: Selection(
          modelId: 'alpha',
          modelProviderId: 'prov',
          agentId: agent,
        ),
        models: [_alpha],
        agents: agents,
      );
      handle.emit(handle.current);
      await tester.pump();
      await tester.pump();
    }

    await pick('plan', [_build, _plan]);
    expect(chipColor(tester), washed(tester, sessionPlanAgentColor));
    final review = CatalogEntry(
      id: 'review',
      kind: const OpenValue.known(CatalogKind.agent),
      label: 'Review',
      color: '#123456',
    );
    await pick('review', [_build, _plan, review]);
    expect(chipColor(tester), washed(tester, const Color(0xFF123456)));
    final docs = CatalogEntry(
      id: 'docs',
      kind: const OpenValue.known(CatalogKind.agent),
      label: 'Docs',
    );
    await pick('docs', [_build, _plan, review, docs]);
    final docsColor = chipColor(tester);
    expect([
      for (final color in sessionAgentPalette) washed(tester, color),
    ], contains(docsColor));
    // The palette color follows the id alone, never the roster.
    await pick('docs', [docs]);
    expect(chipColor(tester), docsColor);
    expect(
      washed(tester, sessionAgentColor([_build, review, docs], 'docs')),
      docsColor,
    );
    // The label reads on any of them.
    expect(sessionAgentForeground(sessionPlanAgentColor), Colors.black);
    expect(sessionAgentForeground(sessionDefaultAgentColor), Colors.white);
  });

  testWidgets('the chip opens the pick of agent, model and variant', (
    tester,
  ) async {
    final (_, handle) = await open(tester);
    await tester.tap(modelChip);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('live-selection-agent-plan')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('live-selection-agent-plan')));
    await tester.pumpAndSettle();
    expect(handle.selectionCalls, contains('agent:plan'));
  });

  testWidgets(
    'the pick\'s footer switches Ask or Allow all and picks an agent',
    (tester) async {
      final (live, handle) = await open(tester, permissions: 2);
      final l10n = V2Localizations.of(
        tester.element(find.byType(SessionModelChip)),
      );
      await openPick(tester, live);
      // The requests waiting for the user are counted beside the switch.
      expect(
        find.text(l10n.liveSelectionPermissionsWaiting(2)),
        findsOneWidget,
      );
      // The switch starts on the acknowledged default (auto-approve), turns it
      // off for this session and keeps the pick open.
      expect(tester.widget<SwitchListTile>(autoApprove).value, isTrue);
      expect(find.text(l10n.chatPermissionAutoApproveOn), findsOneWidget);
      await tester.tap(autoApprove);
      await tester.pumpAndSettle();
      expect(live.permissionModeState.mode, PermissionMode.ask);
      expect(tester.widget<SwitchListTile>(autoApprove).value, isFalse);
      expect(find.text(l10n.chatPermissionAutoApproveOff), findsOneWidget);
      expect(pickOpen, findsOneWidget);
      await tester.tap(autoApprove);
      await tester.pumpAndSettle();
      expect(live.permissionModeState.mode, PermissionMode.allowAll);
      // Each agent shows its color.
      final dot = tester.widget<CircleAvatar>(
        find.descendant(
          of: find.byKey(const ValueKey('live-selection-agent-plan')),
          matching: find.byType(CircleAvatar),
        ),
      );
      expect(dot.backgroundColor, sessionPlanAgentColor);
      // The current agent sends nothing; another sends one switch and closes.
      await tester.tap(
        find.byKey(const ValueKey('live-selection-agent-build')),
      );
      await tester.pumpAndSettle();
      expect(pickOpen, findsNothing);
      expect(
        handle.selectionCalls.where((c) => c.startsWith('agent')),
        isEmpty,
      );
      await openPick(tester, live);
      await tester.tap(find.byKey(const ValueKey('live-selection-agent-plan')));
      await tester.pumpAndSettle();
      expect(handle.selectionCalls, contains('agent:plan'));
      expect(pickOpen, findsNothing);
    },
  );

  testWidgets('a pick the session can no longer take is said (#431)', (
    tester,
  ) async {
    final (live, handle) = await open(tester);
    final l10n = V2Localizations.of(
      tester.element(find.byType(SessionModelChip)),
    );
    await openPick(tester, live);
    // The server took an earlier switch and has not reported it yet.
    handle.awaitingEcho = true;
    await tester.tap(find.byKey(const ValueKey('live-selection-agent-plan')));
    await tester.pumpAndSettle();
    expect(handle.selectionCalls.where((c) => c.startsWith('agent')), isEmpty);
    expect(find.text(l10n.liveSelectionNotApplied), findsOneWidget);
  });

  testWidgets('a sub-conversation keeps its parent\'s choice', (tester) async {
    await open(tester, id: 'child', parent: 'one');
    expect(tester.widget<ActionChip>(modelChip).onPressed, isNull);
  });

  testWidgets('a short keyboard viewport keeps the footer reachable', (
    tester,
  ) async {
    final (live, handle) = await open(
      tester,
      size: const Size(800, 240),
      keyboard: 100,
    );
    await openPick(tester, live);
    // Too short for a fixed footer: it ends the list instead.
    await reach(tester, autoApprove);
    expect(autoApprove.hitTestable(), findsOneWidget);
    await tester.tap(autoApprove);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(autoApprove).value, isFalse);
    final plan = find.byKey(const ValueKey('live-selection-agent-plan'));
    await reach(tester, plan);
    expect(plan.hitTestable(), findsOneWidget);
    await tester.tap(plan);
    await tester.pumpAndSettle();
    expect(handle.selectionCalls, contains('agent:plan'));
    expect(tester.takeException(), isNull);
  });

  for (final (size, keyboard, locale) in [
    (const Size(390, 844), 350.0, const Locale('ar')),
    (const Size(800, 360), 140.0, const Locale('en')),
  ]) {
    testWidgets('the pick stays usable at 2x text: $size/$locale', (
      tester,
    ) async {
      final (live, _) = await open(
        tester,
        size: size,
        keyboard: keyboard,
        locale: locale,
        textScale: 2,
      );
      await openPick(tester, live);
      await reach(tester, autoApprove);
      await tester.ensureVisible(autoApprove);
      await tester.pumpAndSettle();
      // Shown above the keyboard and really reachable, inside the list's
      // clip.
      expect(autoApprove.hitTestable(), findsOneWidget);
      expect(
        tester.getCenter(autoApprove).dy,
        lessThanOrEqualTo(size.height - keyboard),
      );
      await tester.tap(autoApprove);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(autoApprove).value, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('an unset session selection is presented as the server default', (
    tester,
  ) async {
    final (_, handle) = await open(tester);
    handle.selectionState = SessionSelectionState(
      selection: const Selection(),
      models: [_alpha],
      agents: [_build],
    );
    handle.emit(handle.current);
    await tester.pump();
    await tester.pump();
    expect(chip('live-model-chip', 'Default'), findsOneWidget);
    // The server's default agent is green.
    expect(chipColor(tester), washed(tester, sessionDefaultAgentColor));
  });

  testWidgets('the model chip retains selection status in its semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final (_, handle) = await open(tester);
    final l10n = V2Localizations.of(
      tester.element(find.byType(SessionModelChip)),
    );
    final initial = handle.selectionState;
    for (final (phase, notice, expected) in [
      (
        SessionSelectionPhase.pending,
        SessionSelectionNotice.none,
        l10n.liveSelectionPending,
      ),
      (
        SessionSelectionPhase.unconfirmed,
        SessionSelectionNotice.none,
        l10n.liveSelectionUnconfirmed,
      ),
      (
        initial.phase,
        SessionSelectionNotice.changedElsewhere,
        l10n.liveSelectionChangedElsewhere,
      ),
    ]) {
      handle.selectionState = SessionSelectionState(
        selection: initial.selection,
        models: initial.models,
        agents: initial.agents,
        phase: phase,
        notice: notice,
      );
      handle.emit(handle.current);
      // The fake broadcasts asynchronously; deliver the update before the
      // frame that rebuilds the chips (pending has a repeating spinner).
      await tester.pump();
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(expected))),
        findsOneWidget,
      );
      final tooltip = tester.widget<Tooltip>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('live-model-chip')),
              matching: find.byType(Tooltip),
            )
            .first,
      );
      expect(tooltip.message, contains(expected));
      expect(tooltip.message, contains('Alpha#high'));
    }
    // A switch the server took and has not reported yet says why the chip
    // waits (#431).
    handle.selectionState = SessionSelectionState(
      selection: initial.selection,
      models: initial.models,
      agents: initial.agents,
      awaitingReport: true,
    );
    handle.emit(handle.current);
    await tester.pump();
    await tester.pump();
    expect(
      tester
          .widget<Tooltip>(
            find.ancestor(of: modelChip, matching: find.byType(Tooltip)).first,
          )
          .message,
      contains(l10n.liveSelectionAwaitingReport),
    );
    semantics.dispose();
  });

  testWidgets('a failed permission write is said inside the pick', (
    tester,
  ) async {
    final backend = FakeMetadataBackend()
      ..failWrite = PermissionModeStore.overridesKey;
    policy.dispose();
    policy = PermissionModeStore(store: V2MetadataStore(backend: backend));
    await policy.initialize();
    final (live, _) = await open(tester);
    final l10n = V2Localizations.of(
      tester.element(find.byType(SessionModelChip)),
    );
    await openPick(tester, live);
    await tester.tap(autoApprove);
    await tester.pumpAndSettle();
    // The sheet would cover a snack bar, so the switch itself says it.
    expect(
      find.descendant(
        of: autoApprove,
        matching: find.text(l10n.livePermissionModeFailed),
      ),
      findsOneWidget,
    );
    expect(tester.widget<SwitchListTile>(autoApprove).value, isTrue);
    expect(pickOpen, findsOneWidget);
    // The next attempt clears it.
    backend.failWrite = null;
    await tester.tap(autoApprove);
    await tester.pumpAndSettle();
    expect(find.text(l10n.livePermissionModeFailed), findsNothing);
    expect(live.permissionModeState.mode, PermissionMode.ask);
  });

  testWidgets('an unreadable permission policy is unavailable, not off', (
    tester,
  ) async {
    policy.dispose();
    policy = PermissionModeStore(
      store: V2MetadataStore(backend: FakeMetadataBackend()..failRead = true),
    );
    await policy.initialize();
    final (live, _) = await open(tester);
    final l10n = V2Localizations.of(
      tester.element(find.byType(SessionModelChip)),
    );
    await openPick(tester, live);
    expect(find.text(l10n.livePermissionModeUnavailable), findsOneWidget);
    expect(find.text(l10n.chatPermissionAutoApproveOff), findsNothing);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('live-auto-approve')),
          )
          .onChanged,
      isNull,
    );
  });
}
