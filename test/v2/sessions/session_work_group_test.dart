import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/sessions/session_live_scroll.dart';
import 'package:codewalk/features/sessions/session_live_timeline.dart';
import 'package:codewalk/features/sessions/session_reasoning_body.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../hosts/fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';
import 'workspace_support.dart';

ItemMeta _meta(
  String id, {
  String? message,
  ItemStatus status = ItemStatus.completed,
  String generation = 'g1',
}) => ItemMeta(
  id: ItemId(id),
  generation: generation,
  status: OpenValue.known(status),
  source: SourceProvenance(
    harness: const HarnessRef(HostId('h'), HarnessInstanceId('test')),
    version: '2.0.22',
    nativeType: 'test',
  ),
  message: message == null
      ? null
      : MessageContext(message: MessageRef(message)),
);

ToolCall _tool(
  String id,
  String message, {
  ItemStatus status = ItemStatus.completed,
  String name = 'read',
  String generation = 'g1',
}) => ToolCall(
  meta: _meta(id, message: message, status: status, generation: generation),
  kind: const OpenValue.known(ToolKind.read),
  rawName: name,
  input: CanonicalValue(const {'path': 'lib/main.dart'}),
);

/// A finished turn: a prompt, two work messages and the final answer.
List<TimelineItem> _turn(
  String n, {
  bool complete = true,
  String generation = 'g1',
}) => [
  UserInput(
    meta: _meta('u$n', generation: generation),
    text: 'prompt $n',
    delivery: const OpenValue.known(DeliveryState.delivered),
  ),
  Reasoning(
    meta: _meta('r$n', message: 'm1$n', generation: generation),
    text: 'thinking $n',
    complete: true,
  ),
  _tool('t1$n', 'm1$n', generation: generation),
  _tool('t2$n', 'm2$n', generation: generation),
  AssistantText(
    meta: _meta(
      'a$n',
      message: 'm3$n',
      status: complete ? ItemStatus.completed : ItemStatus.streaming,
      generation: generation,
    ),
    text: 'answer $n',
    complete: complete,
  ),
];

Future<SessionLiveScroll> _pump(
  WidgetTester tester,
  List<TimelineItem> items, {
  required bool settled,
  Size size = const Size(390, 844),
  SessionLiveScroll? scroll,
  WidgetBuilder? empty,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final rules = scroll ?? SessionLiveScroll();
  if (scroll == null) addTearDown(rules.dispose);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: V2Localizations.localizationsDelegates,
      supportedLocales: V2Localizations.supportedLocales,
      home: Scaffold(
        body: SessionLiveTimeline(
          items: items,
          headerBuilder: (_) => const SizedBox(height: 8),
          scroll: rules,
          settled: settled,
          emptyBuilder: empty,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return rules;
}

V2Localizations _l10n(WidgetTester tester) =>
    V2Localizations.of(tester.element(find.byType(SessionLiveTimeline)));

void main() {
  testWidgets('a finished turn shows its work as one header to open', (
    tester,
  ) async {
    await _pump(tester, _turn('1'), settled: true);
    final l10n = _l10n(tester);
    final header = find.byKey(const ValueKey('work-group-work-r1'));
    expect(header, findsOneWidget);
    expect(find.text(l10n.chatWorkMessagesMultiple(2)), findsOneWidget);
    expect(find.text('answer 1'), findsOneWidget);
    expect(find.text('thinking 1'), findsNothing);
    final toggle = find.byKey(const ValueKey('work-group-toggle-work-r1'));
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('thinking 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('tool-run-tools-t11')), findsOneWidget);
    expect(find.text(l10n.chatWorkHide), findsOneWidget);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('thinking 1'), findsNothing);
  });

  testWidgets('the work collapses only once the turn finished (#273)', (
    tester,
  ) async {
    final scroll = SessionLiveScroll();
    addTearDown(scroll.dispose);
    await _pump(
      tester,
      _turn('1', complete: false),
      settled: false,
      scroll: scroll,
    );
    expect(find.byKey(const ValueKey('work-group-work-r1')), findsNothing);
    expect(find.text('thinking 1'), findsOneWidget);
    // The session settles before the answer completes: still open.
    await _pump(
      tester,
      _turn('1', complete: false),
      settled: true,
      scroll: scroll,
    );
    expect(find.byKey(const ValueKey('work-group-work-r1')), findsNothing);
    await _pump(tester, _turn('1'), settled: true, scroll: scroll);
    expect(find.byKey(const ValueKey('work-group-work-r1')), findsOneWidget);
    expect(find.text('thinking 1'), findsNothing);
  });

  testWidgets('a settled group keeps its element through jitter (#274)', (
    tester,
  ) async {
    final scroll = SessionLiveScroll();
    addTearDown(scroll.dispose);
    await _pump(tester, _turn('1'), settled: true, scroll: scroll);
    final header = find.byKey(const ValueKey('work-group-work-r1'));
    final element = tester.element(header);
    // A status pulse that reports the session busy, a rehydration under a
    // new generation, and the session settling again.
    for (final (items, settled) in [
      (_turn('1'), false),
      (_turn('1', generation: 'g2'), false),
      (_turn('1', generation: 'g2'), true),
    ]) {
      await _pump(tester, items, settled: settled, scroll: scroll);
      expect(header, findsOneWidget);
      expect(identical(tester.element(header), element), isTrue);
      expect(find.text('thinking 1'), findsNothing);
    }
  });

  testWidgets('opening a work group above the answer does not jump', (
    tester,
  ) async {
    final scroll = SessionLiveScroll();
    addTearDown(scroll.dispose);
    final items = [for (var n = 0; n < 6; n++) ..._turn('$n')];
    await _pump(tester, items, settled: true, scroll: scroll);
    final controller = scroll.controller;
    final before = controller.position.pixels;
    expect(before, controller.position.maxScrollExtent);
    final toggle = find.byKey(const ValueKey('work-group-toggle-work-r5'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    final at = controller.position.pixels;
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    // The work opened under the header; the follow did not chase it.
    expect(controller.position.pixels, at);
    expect(controller.position.maxScrollExtent, greaterThan(at));
    expect(find.text('thinking 5'), findsOneWidget);
  });

  testWidgets('a run of calls counts first and shows each on demand', (
    tester,
  ) async {
    final items = [
      UserInput(
        meta: _meta('u'),
        text: 'go',
        delivery: const OpenValue.known(DeliveryState.delivered),
      ),
      _tool('t1', 'm1'),
      _tool('t2', 'm1', status: ItemStatus.streaming, name: 'grep'),
      _tool('t3', 'm1', status: ItemStatus.pending, name: 'bash'),
    ];
    await _pump(tester, items, settled: false);
    final l10n = _l10n(tester);
    const title = ValueKey('tool-run-title-tools-t1');
    const progress = ValueKey('tool-run-progress-tools-t1');
    String text(ValueKey<String> key) =>
        tester.widget<Text>(find.byKey(key)).data!;
    // Compact: count first, with what still runs.
    expect(text(title), l10n.chatMessageToolChainCallsCompact(3));
    expect(
      text(progress),
      '${l10n.chatMessageToolRunningCount(1)} • '
      '${l10n.chatMessageToolQueuedCount(1)}',
    );
    expect(find.byKey(const ValueKey('tool-result-t1')), findsNothing);
    final toggle = find.byKey(const ValueKey('tool-run-toggle-tools-t1'));
    expect(
      find.descendant(of: toggle, matching: find.text(l10n.chatMessageShow)),
      findsOneWidget,
    );
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(text(title), l10n.chatMessageToolCallsTitle);
    expect(
      text(progress),
      '${l10n.chatMessageToolChainCallsCompact(3)} • '
      '${l10n.chatMessageToolDoneCount(1)} • '
      '${l10n.chatMessageToolRunningCount(1)} • '
      '${l10n.chatMessageToolQueuedCount(1)}',
    );
    expect(find.byKey(const ValueKey('tool-result-t1')), findsOneWidget);
    // A call appended to the open run keeps the row and its state.
    final row = tester.element(find.byKey(const ValueKey('tool-run-tools-t1')));
    await _pump(tester, [
      ...items,
      _tool('t4', 'm1', status: ItemStatus.pending),
    ], settled: false);
    expect(
      identical(
        tester.element(find.byKey(const ValueKey('tool-run-tools-t1'))),
        row,
      ),
      isTrue,
    );
    expect(find.byKey(const ValueKey('tool-result-t4')), findsOneWidget);
  });

  testWidgets('a message that opens in a run keeps its details', (
    tester,
  ) async {
    await _pump(tester, [
      _tool('t1', 'm1'),
      _tool('t2', 'm1'),
      _tool('t3', 'm2'),
    ], settled: false);
    final run = find.byKey(const ValueKey('tool-run-tools-t1'));
    Finder chip(String message) => find.descendant(
      of: run,
      matching: find.byKey(ValueKey('message-elapsed-$message')),
    );
    // Closed: the first message's details, on the run.
    expect(chip('m1'), findsOneWidget);
    expect(chip('m2'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('tool-run-toggle-tools-t1')));
    await tester.pumpAndSettle();
    // Open: each call that opens a message offers its own.
    expect(chip('m1'), findsOneWidget);
    expect(chip('m2'), findsOneWidget);
    await tester.tap(chip('m2'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('message-info-m2')), findsOneWidget);
  });

  testWidgets('a wide run names its calls', (tester) async {
    await _pump(
      tester,
      [
        _tool('t1', 'm1'),
        _tool('t2', 'm1', name: 'grep'),
        _tool('t3', 'm1', name: 'bash'),
      ],
      settled: false,
      size: const Size(1280, 800),
    );
    final l10n = _l10n(tester);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('tool-run-title-tools-t1')))
          .data,
      'read • grep • ${l10n.chatMessageToolChainMore(1)}',
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tool-run-toggle-tools-t1')),
        matching: find.text(l10n.chatMessageDetails),
      ),
      findsOneWidget,
    );
  });

  for (final (name, size) in const [
    ('compact', Size(390, 844)),
    ('wide', Size(1280, 800)),
  ]) {
    testWidgets('a long reasoning shows a few lines and more, $name', (
      tester,
    ) async {
      final text = [for (var i = 0; i < 30; i++) 'step $i'].join('\n\n');
      await _pump(
        tester,
        [
          Reasoning(
            meta: _meta('r', message: 'm'),
            text: text,
            complete: true,
          ),
        ],
        settled: false,
        size: size,
      );
      final l10n = _l10n(tester);
      final compact = size.width < 600;
      expect(
        find.text(
          compact ? l10n.chatMessageThinking : l10n.chatMessageThinkingProcess,
        ),
        findsOneWidget,
      );
      final body = find.byType(SessionReasoningBody);
      final closed = tester.getSize(body).height;
      final toggle = find.byKey(const ValueKey('reasoning-toggle'));
      expect(
        find.descendant(
          of: toggle,
          matching: find.text(
            compact
                ? l10n.chatMessageShowMoreCompact
                : l10n.chatMessageShowMore,
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.getSize(body).height, greaterThan(closed));
      expect(
        find.descendant(
          of: toggle,
          matching: find.text(
            compact
                ? l10n.chatMessageShowLessCompact
                : l10n.chatMessageShowLess,
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a reasoning that overflows after a resize offers more', (
    tester,
  ) async {
    final text = ['A' * 40, 'B' * 40].join('\n\n');
    final items = [
      Reasoning(
        meta: _meta('r', message: 'm'),
        text: text,
        complete: true,
      ),
    ];
    final scroll = SessionLiveScroll();
    addTearDown(scroll.dispose);
    await _pump(
      tester,
      items,
      settled: false,
      size: const Size(1280, 800),
      scroll: scroll,
    );
    expect(find.byKey(const ValueKey('reasoning-toggle')), findsNothing);
    await _pump(tester, items, settled: false, scroll: scroll);
    expect(find.byKey(const ValueKey('reasoning-toggle')), findsOneWidget);
  });

  for (final (name, height, offered) in const [
    ('a short reasoning that scrolls sideways', 20.0, false),
    ('a tall reasoning', 400.0, true),
  ]) {
    testWidgets('only the reasoning\'s own height offers more: $name', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: V2Localizations.localizationsDelegates,
          supportedLocales: V2Localizations.supportedLocales,
          home: Scaffold(
            body: SessionReasoningBody(
              text: 'x',
              complete: true,
              // Like a code block or a formula that scrolls sideways.
              child: SizedBox(
                height: height,
                child: const SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(width: 4000, height: 10),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('reasoning-toggle')),
        offered ? findsOneWidget : findsNothing,
      );
    });
  }

  testWidgets('a short reasoning shows in full', (tester) async {
    await _pump(tester, [
      Reasoning(
        meta: _meta('r', message: 'm'),
        text: 'brief',
        complete: true,
      ),
    ], settled: false);
    expect(find.text('brief'), findsOneWidget);
    expect(find.byKey(const ValueKey('reasoning-toggle')), findsNothing);
  });

  testWidgets('the empty block shows only without items', (tester) async {
    Widget empty(BuildContext context) =>
        const Text('empty', key: ValueKey('empty'));
    await _pump(tester, const [], settled: true, empty: empty);
    expect(find.byKey(const ValueKey('empty')), findsOneWidget);
    await _pump(tester, _turn('1'), settled: true, empty: empty);
    expect(find.byKey(const ValueKey('empty')), findsNothing);
  });

  testWidgets('a loading session shows a quiet loader, then its state (#69)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
    await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: dependencies));
    await showSessionList(tester);
    final l10n = dependencies.localizations.current;
    final read = dependencies.sessions!.selectProfile('profile_a');
    final catalog = rig.sources.single;
    final row = catalog.row('one');
    catalog.respond([row]);
    await read;
    await tester.pumpAndSettle();
    final button = find.byKey(ValueKey('live-open-${row.info.ref.storageKey}'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump();
    final ref = row.info.ref;
    final handle = directory.grant(ref);
    await tester.pump();
    void emit(
      SessionLivePhase phase,
      List<TimelineItem> items, {
      DateTime? synced,
    }) => handle.emit(
      SessionLiveView(
        session: ref,
        phase: phase,
        lastSyncedAt: synced,
        state: liveState(ref, items: items),
      ),
    );
    const loader = ValueKey('live-hydrating');
    const hello = ValueKey('live-empty');
    emit(SessionLivePhase.hydrating, const []);
    await tester.pump();
    expect(find.byKey(loader), findsOneWidget);
    expect(find.byKey(hello), findsNothing);
    expect(find.text(l10n.chatHelloAssistant), findsNothing);
    // Resident items show at once, without the loader.
    final answer = AssistantText(
      meta: liveMeta(ref, 'a1'),
      text: 'resident answer',
      complete: true,
    );
    emit(SessionLivePhase.hydrating, [answer]);
    await tester.pump();
    expect(find.text('resident answer'), findsOneWidget);
    expect(find.byKey(loader), findsNothing);
    // A first read that failed may leave a state with no items: it is not
    // known to be empty.
    emit(SessionLivePhase.degraded, const []);
    await tester.pumpAndSettle();
    expect(find.byKey(loader), findsNothing);
    expect(find.byKey(hello), findsNothing);
    // A session a read reported empty shows the empty conversation.
    emit(SessionLivePhase.live, const [], synced: DateTime.utc(2026, 10, 27));
    await tester.pumpAndSettle();
    expect(find.byKey(loader), findsNothing);
    expect(find.byKey(hello), findsOneWidget);
    expect(find.text(l10n.chatHelloAssistant), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
