import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/features/sessions/session_selection_chip.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/sessions/session_selection.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'live_fakes.dart';

void main() {
  late CatalogRig rig;
  late LiveDirectory directory;
  late SessionLiveController live;
  late SessionRef ref;

  final alpha = ModelEntry(
    id: 'alpha',
    providerId: 'prov',
    label: 'Alpha',
    variants: ['low', 'high'],
  );
  final beta = ModelEntry(id: 'beta', providerId: 'other', label: 'Beta');
  final build = CatalogEntry(
    id: 'build',
    kind: const OpenValue.known(CatalogKind.agent),
    label: 'Build',
    description: 'Builds',
  );
  final plan = CatalogEntry(
    id: 'plan',
    kind: const OpenValue.known(CatalogKind.agent),
    label: 'Plan',
  );
  SessionSelectionState offered({
    Selection selection = const Selection(
      modelId: 'alpha',
      modelProviderId: 'prov',
      modelVariant: 'high',
      agentId: 'build',
    ),
    SessionSelectionPhase phase = SessionSelectionPhase.idle,
    SessionSelectionNotice notice = SessionSelectionNotice.none,
  }) => SessionSelectionState(
    selection: selection,
    models: [alpha, beta],
    agents: [build, plan],
    phase: phase,
    notice: notice,
  );

  setUp(() async {
    rig = CatalogRig();
    await rig.save('a');
    await rig.sessions.initialize();
    directory = LiveDirectory();
    final summary = CatalogSource(profile('a')).row('one');
    ref = summary.info.ref;
    live = SessionLiveController(
      hosts: rig.hosts,
      profile: profile('a'),
      summary: summary,
      directory: directory,
    );
  });

  tearDown(() {
    live.dispose();
    rig.dispose();
  });

  Future<LiveHandle> openLive(
    WidgetTester tester,
    SessionSelectionState state,
  ) async {
    final opening = live.start();
    final handle = directory.grant(ref)
      ..selectionAvailable = true
      ..selectionState = state;
    await opening;
    handle.emit(
      SessionLiveView(
        session: ref,
        phase: SessionLivePhase.live,
        state: liveState(ref),
      ),
    );
    await tester.pump();
    return handle;
  }

  Future<void> pumpChip(
    WidgetTester tester, {
    double width = 800,
    double textScale = 1,
    bool settle = true,
    bool? compact,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: V2Localizations.localizationsDelegates,
        supportedLocales: V2Localizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          appBar: AppBar(
            title: const Text('A session title that is long'),
            actions: [SessionSelectionChip(live: live, compact: compact)],
          ),
        ),
      ),
    );
    // A spinner never settles.
    settle ? await tester.pumpAndSettle() : await tester.pump();
  }

  testWidgets('is absent when the lease cannot switch', (tester) async {
    final opening = live.start();
    directory.grant(ref);
    await opening;
    await pumpChip(tester);
    expect(find.byKey(const ValueKey('live-selection')), findsNothing);
  });

  testWidgets('labels the model, variant and agent on wide screens', (
    tester,
  ) async {
    await openLive(tester, offered());
    await pumpChip(tester);
    expect(find.text('Alpha#high · Build'), findsOneWidget);
  });

  testWidgets('is icon-only on compact screens, labelled for readers', (
    tester,
  ) async {
    await openLive(tester, offered());
    await pumpChip(tester, width: 360, textScale: 2);
    expect(tester.takeException(), isNull);
    expect(find.text('Alpha#high · Build'), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp('Model and agent: Alpha#high · Build')),
      findsOneWidget,
    );
  });

  testWidgets('a picked variant sends one switch with its model', (
    tester,
  ) async {
    final handle = await openLive(tester, offered());
    await pumpChip(tester);
    await tester.tap(find.byKey(const ValueKey('live-selection')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    // The lists are read again when the pick opens.
    expect(handle.selectionCalls, ['refresh']);
    await tester.tap(
      find.byKey(const ValueKey('live-selection-variant-prov/alpha#low')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(handle.selectionCalls, ['refresh', 'model:prov/alpha:low']);
  });

  testWidgets('compact screens pick an agent from a bottom sheet', (
    tester,
  ) async {
    final handle = await openLive(tester, offered());
    await pumpChip(tester, width: 360);
    await tester.tap(find.byKey(const ValueKey('live-selection')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('live-selection-agent-plan')));
    await tester.pumpAndSettle();
    expect(handle.selectionCalls, ['refresh', 'agent:plan']);
  });

  testWidgets('a value the list does not offer stays visible', (tester) async {
    await openLive(
      tester,
      offered(
        selection: const Selection(
          modelId: 'gone',
          modelProviderId: 'prov',
          agentId: 'retired',
        ),
      ),
    );
    await pumpChip(tester);
    expect(find.text('gone · retired'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('live-selection')));
    await tester.pumpAndSettle();
    expect(find.text('Not offered here'), findsNWidgets(2));
  });

  testWidgets('a narrow page uses the compact chip on a wide window', (
    tester,
  ) async {
    await openLive(tester, offered());
    await pumpChip(tester, compact: true);
    expect(find.text('Alpha#high · Build'), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp('Model and agent: Alpha#high · Build')),
      findsOneWidget,
    );
  });

  testWidgets('a wide label stays on one line with 2x text', (tester) async {
    await openLive(
      tester,
      offered(
        selection: const Selection(
          modelId: 'a-model-whose-name-is-much-longer-than-the-chip',
          modelProviderId: 'prov',
          agentId: 'an-agent-whose-name-is-long-as-well',
        ),
      ),
    );
    await pumpChip(tester, width: 900, textScale: 2);
    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('live-selection')),
        matching: find.byType(Text),
      ),
    );
    expect(text.maxLines, 1);
  });

  testWidgets('an unread session claims no default', (tester) async {
    await openLive(tester, const SessionSelectionState());
    await pumpChip(tester);
    expect(find.text('Default'), findsNothing);
    expect(find.text('Model and agent'), findsOneWidget);
  });

  testWidgets('a current variant the model no longer lists stays visible', (
    tester,
  ) async {
    await openLive(
      tester,
      offered(
        selection: const Selection(
          modelId: 'alpha',
          modelProviderId: 'prov',
          modelVariant: 'max',
          agentId: 'build',
        ),
      ),
    );
    await pumpChip(tester);
    await tester.tap(find.byKey(const ValueKey('live-selection')));
    await tester.pumpAndSettle();
    expect(find.text('alpha#max'), findsOneWidget);
    expect(find.text('Not offered here'), findsOneWidget);
  });

  testWidgets('a pending switch disables the pick and shows progress', (
    tester,
  ) async {
    await openLive(tester, offered(phase: SessionSelectionPhase.pending));
    await pumpChip(tester, settle: false);
    final chip = tester.widget<ActionChip>(
      find.byKey(const ValueKey('live-selection')),
    );
    expect(chip.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('an unconfirmed switch offers Check again', (tester) async {
    final handle = await openLive(
      tester,
      offered(phase: SessionSelectionPhase.unconfirmed),
    );
    await pumpChip(tester);
    expect(
      find.bySemanticsLabel(RegExp('Change not confirmed')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('live-selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();
    expect(handle.selectionCalls, ['refresh', 'refresh']);
  });

  testWidgets('a refusal after a pick is reported', (tester) async {
    final handle = await openLive(tester, offered());
    handle.selectionAction = (_) async =>
        offered(notice: SessionSelectionNotice.refused);
    await pumpChip(tester);
    await tester.tap(find.byKey(const ValueKey('live-selection')));
    await tester.pumpAndSettle();
    // The refresh on open already answers with the refusal state; the pick
    // reports the outcome of the switch itself.
    await tester.tap(find.byKey(const ValueKey('live-selection-agent-plan')));
    await tester.pumpAndSettle();
    expect(find.text('The server refused the change.'), findsWidgets);
  });

  testWidgets('a pick replaced elsewhere is reported', (tester) async {
    final handle = await openLive(tester, offered());
    await pumpChip(tester);
    await tester.tap(find.byKey(const ValueKey('live-selection')));
    await tester.pumpAndSettle();
    handle.selectionAction = (_) async =>
        offered(notice: SessionSelectionNotice.changedElsewhere);
    await tester.tap(find.byKey(const ValueKey('live-selection-agent-plan')));
    await tester.pumpAndSettle();
    expect(find.text('Changed by another client.'), findsOneWidget);
  });

  testWidgets('one half that can be picked reports no reason', (tester) async {
    await openLive(
      tester,
      SessionSelectionState(
        selection: const Selection(agentId: 'build'),
        models: [alpha],
        agentUnavailable: SessionSelectionUnavailable.emptyCatalog,
      ),
    );
    await pumpChip(tester);
    expect(find.bySemanticsLabel(RegExp('Nothing to choose')), findsNothing);
    final chip = tester.widget<ActionChip>(
      find.byKey(const ValueKey('live-selection')),
    );
    expect(chip.onPressed, isNotNull);
  });

  testWidgets('a change made elsewhere is shown', (tester) async {
    await openLive(
      tester,
      offered(notice: SessionSelectionNotice.changedElsewhere),
    );
    await pumpChip(tester);
    expect(
      find.bySemanticsLabel(RegExp('Changed by another client')),
      findsOneWidget,
    );
  });

  testWidgets('lists that cannot be read close the pick with a reason', (
    tester,
  ) async {
    await openLive(
      tester,
      const SessionSelectionState(
        selection: Selection(),
        modelUnavailable: SessionSelectionUnavailable.routeAbsent,
        agentUnavailable: SessionSelectionUnavailable.routeAbsent,
      ),
    );
    await pumpChip(tester);
    final chip = tester.widget<ActionChip>(
      find.byKey(const ValueKey('live-selection')),
    );
    expect(chip.onPressed, isNull);
    expect(find.text('Default'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        RegExp('This server does not list models and agents'),
      ),
      findsOneWidget,
    );
  });
}
