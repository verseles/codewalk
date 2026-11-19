import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/sessions/session_live_scroll.dart';
import 'package:codewalk/features/sessions/session_live_timeline.dart';
import 'package:codewalk/features/sessions/session_reasoning_body.dart';
import 'package:codewalk/features/sessions/session_timeline_tile.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/theme/chat_appearance.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

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
  ChatRenderMode renderMode = ChatRenderMode.live,
  bool showReasoning = true,
  bool showToolCalls = true,
  bool settle = true,
  ItemId? highlight,
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
        body: ChatAppearance(
          mathRendering: true,
          conversationTextScale: 1,
          renderMode: renderMode,
          showReasoning: showReasoning,
          showToolCalls: showToolCalls,
          child: SessionLiveTimeline(
            items: items,
            headerBuilder: (_) => const SizedBox(height: 8),
            scroll: rules,
            settled: settled,
            emptyBuilder: empty,
            highlight: highlight,
          ),
        ),
      ),
    ),
  );
  // A pending row's indicator never settles.
  settle ? await tester.pumpAndSettle() : await tester.pump();
  return rules;
}

V2Localizations _l10n(WidgetTester tester) =>
    V2Localizations.of(tester.element(find.byType(SessionLiveTimeline)));

void main() {
  testWidgets('a search match on cardless agent text is outlined around it', (
    tester,
  ) async {
    await _pump(
      tester,
      _turn('1'),
      settled: true,
      highlight: const ItemId('a1'),
    );
    final answer = find.text('answer 1');
    final outline = find.ancestor(
      of: answer,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).border != null,
      ),
    );
    expect(outline, findsOneWidget);
    final border =
        (tester.widget<DecoratedBox>(outline).decoration as BoxDecoration)
            .border!
            .top;
    // Drawn outside the row, so it never covers text with no card (#488).
    expect(border.strokeAlign, BorderSide.strokeAlignOutside);
    final row = tester.getRect(outline);
    expect(tester.getRect(answer).left, greaterThanOrEqualTo(row.left));
    // The 8 dp side margin of a phone leaves room for the 2 dp stroke.
    expect(row.left, greaterThanOrEqualTo(border.width));
  });

  testWidgets(
    'a turn with following answer compacts its activity into a descriptive summary',
    (tester) async {
      await _pump(tester, _turn('1'), settled: true);
      final l10n = _l10n(tester);
      final header = find.byKey(const ValueKey('work-group-work-r1'));
      expect(header, findsOneWidget);
      expect(
        find.text('${l10n.activityExplored(2)} · ${l10n.activityThought(1)}'),
        findsOneWidget,
      );
      expect(find.text('answer 1'), findsOneWidget);
      expect(find.byKey(const ValueKey('tool-result-t11')), findsNothing);
      final toggle = find.byKey(const ValueKey('work-group-toggle-work-r1'));
      expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      // Expanding shows compact single-line rows in place (reasoning stays 1-line until tapped).
      expect(find.text(l10n.chatThought), findsOneWidget);
      expect(find.byKey(const ValueKey('tool-result-t11')), findsOneWidget);
      expect(find.byKey(const ValueKey('tool-result-t21')), findsOneWidget);
      // Tapping the reasoning row reveals its full Markdown body.
      await tester.tap(find.byKey(const ValueKey('reasoning-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('thinking 1'), findsOneWidget);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tool-result-t11')), findsNothing);
    },
  );

  testWidgets(
    'activity compacts immediately when following answer streams and surfaces failures',
    (tester) async {
      final scroll = SessionLiveScroll();
      addTearDown(scroll.dispose);
      // Live work without following answer stays open as individual compact rows.
      final liveWork = [
        UserInput(
          meta: _meta('u1'),
          text: 'prompt 1',
          delivery: const OpenValue.known(DeliveryState.delivered),
        ),
        _tool('t1', 'm1', status: ItemStatus.failed),
        _tool('t2', 'm1', status: ItemStatus.streaming),
      ];
      await _pump(tester, liveWork, settled: false, scroll: scroll);
      expect(find.byKey(const ValueKey('work-group-work-t1')), findsNothing);
      expect(find.byKey(const ValueKey('tool-result-t1')), findsOneWidget);
      expect(find.byKey(const ValueKey('tool-result-t2')), findsOneWidget);

      // As soon as the answer begins streaming, the stretch compacts and keeps failure visible.
      await _pump(
        tester,
        [
          liveWork[0],
          liveWork[1],
          _tool('t2', 'm1'),
          AssistantText(
            meta: _meta('a1', message: 'm2', status: ItemStatus.streaming),
            text: 'Streaming answer...',
            complete: false,
          ),
        ],
        settled: false,
        scroll: scroll,
      );
      final l10n = _l10n(tester);
      expect(find.byKey(const ValueKey('work-group-work-t1')), findsOneWidget);
      expect(find.text(l10n.activityExplored(2)), findsOneWidget);
      expect(find.text('· ${l10n.activityFailed(1)}'), findsOneWidget);
      expect(find.text('Streaming answer...'), findsOneWidget);
    },
  );

  testWidgets('a collapsed stretch keeps its element through jitter (#274)', (
    tester,
  ) async {
    final scroll = SessionLiveScroll();
    addTearDown(scroll.dispose);
    await _pump(tester, _turn('1'), settled: true, scroll: scroll);
    final header = find.byKey(const ValueKey('work-group-work-r1'));
    final element = tester.element(header);
    for (final (items, settled) in [
      (_turn('1'), false),
      (_turn('1', generation: 'g2'), false),
      (_turn('1', generation: 'g2'), true),
    ]) {
      await _pump(tester, items, settled: settled, scroll: scroll);
      expect(header, findsOneWidget);
      expect(identical(tester.element(header), element), isTrue);
      expect(find.byKey(const ValueKey('tool-result-t11')), findsNothing);
    }
  });

  testWidgets('opening a stretch above the answer does not jump', (
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
    expect(controller.position.pixels, at);
    expect(controller.position.maxScrollExtent, greaterThan(at));
    expect(find.byKey(const ValueKey('tool-result-t15')), findsOneWidget);
  });

  testWidgets(
    'message elapsed chips stay reachable on collapsed and expanded stretches',
    (tester) async {
      await _pump(tester, [
        _tool('t1', 'm1'),
        _tool('t2', 'm1'),
        _tool('t3', 'm2'),
        AssistantText(
          meta: _meta('a1', message: 'm3'),
          text: 'done',
          complete: true,
        ),
      ], settled: true);
      // Closed: first message's chip sits on the stretch header.
      expect(find.byKey(const ValueKey('message-elapsed-m1')), findsOneWidget);
      expect(find.byKey(const ValueKey('message-elapsed-m2')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('work-group-toggle-work-t1')));
      await tester.pumpAndSettle();
      // Open: each row opening a message offers its own chip.
      expect(find.byKey(const ValueKey('message-elapsed-m1')), findsOneWidget);
      expect(find.byKey(const ValueKey('message-elapsed-m2')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('message-elapsed-m2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('message-info-m2')), findsOneWidget);
    },
  );

  for (final (name, size) in const [
    ('compact', Size(390, 844)),
    ('wide', Size(1280, 800)),
  ]) {
    testWidgets(
      'reasoning renders as a compact single line and expands on tap, $name',
      (tester) async {
        final start = DateTime.utc(2026, 11, 19, 1, 0, 0);
        final end = DateTime.utc(2026, 11, 19, 1, 0, 3);
        final text = [for (var i = 0; i < 12; i++) 'step $i'].join('\n\n');
        await _pump(
          tester,
          [
            Reasoning(
              meta: _meta('r', message: 'm'),
              text: text,
              complete: true,
              started: start,
              completed: end,
            ),
          ],
          settled: false,
          size: size,
        );
        final l10n = _l10n(tester);
        expect(find.text(l10n.chatThoughtDuration('3s')), findsOneWidget);
        expect(find.text('step 0'), findsNothing);
        final body = find.byType(SessionReasoningBody);
        final closed = tester.getSize(body).height;
        final toggle = find.byKey(const ValueKey('reasoning-toggle'));
        expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(tester.getSize(body).height, greaterThan(closed));
        expect(find.text('step 0'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'streaming reasoning shows extracted heading or Thinking and auto-expands on search highlight',
    (tester) async {
      await _pump(
        tester,
        [
          Reasoning(
            meta: _meta('r1', message: 'm1', status: ItemStatus.streaming),
            text: '**Checking parser**\nInspecting edge cases',
            complete: false,
          ),
          Reasoning(
            meta: _meta('r2', message: 'm2', status: ItemStatus.streaming),
            text: 'Plain thoughts without heading',
            complete: false,
          ),
        ],
        settled: false,
        highlight: const ItemId('r2'),
      );
      final l10n = _l10n(tester);
      expect(
        find.text(l10n.chatThinkingHeading('Checking parser')),
        findsOneWidget,
      );
      expect(find.text('Inspecting edge cases'), findsNothing);
      expect(find.text(l10n.chatStatusThinking), findsOneWidget);
      // Highlighted reasoning auto-expands so the search match is visible.
      expect(find.text('Plain thoughts without heading'), findsOneWidget);
    },
  );

  testWidgets('empty reasoning has no toggle', (tester) async {
    await _pump(tester, [
      Reasoning(
        meta: _meta('r', message: 'm'),
        text: '   ',
        complete: true,
      ),
    ], settled: false);
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

  testWidgets('the Block render mode shows a placeholder for the rest', (
    tester,
  ) async {
    final items = _turn('1', complete: false);
    await _pump(
      tester,
      items,
      settled: false,
      renderMode: ChatRenderMode.block,
      settle: false,
    );
    final l10n = _l10n(tester);
    expect(find.text(l10n.chatBlockResponsePendingTitle), findsOneWidget);
    // Nothing of the turn ended in a message, but its calls did.
    expect(find.textContaining('answer 1'), findsNothing);
    expect(find.textContaining('thinking 1'), findsNothing);
    expect(find.byKey(const ValueKey('tool-result-t11')), findsOne);
    // Once the session settles, the whole turn shows and the placeholder
    // leaves.
    await _pump(
      tester,
      _turn('1'),
      settled: true,
      renderMode: ChatRenderMode.block,
    );
    expect(find.text(l10n.chatBlockResponsePendingTitle), findsNothing);
    expect(find.textContaining('answer 1'), findsOneWidget);
  });

  testWidgets('hidden tool calls leave the timeline (#108)', (tester) async {
    await _pump(
      tester,
      _turn('1', complete: false),
      settled: false,
      showToolCalls: false,
    );
    expect(find.byKey(const ValueKey('tool-result-t11')), findsNothing);
    expect(find.textContaining('answer 1'), findsOneWidget);
  });

  testWidgets('showing hidden work again is not an arrival', (tester) async {
    final scroll = SessionLiveScroll();
    addTearDown(scroll.dispose);
    final items = [for (var n = 0; n < 6; n++) ..._turn('$n')];
    await _pump(
      tester,
      items,
      settled: true,
      scroll: scroll,
      showReasoning: false,
      showToolCalls: false,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(scroll.following, isFalse);
    final at = scroll.controller.position.pixels;
    await _pump(tester, items, settled: true, scroll: scroll);
    expect(scroll.unreadBelow, isFalse);
    expect(scroll.controller.position.pixels, at);
    // New content is still told.
    await _pump(
      tester,
      [...items, ..._turn('6')],
      settled: true,
      scroll: scroll,
    );
    expect(scroll.unreadBelow, isTrue);
  });

  for (final hidden in [false, true]) {
    testWidgets('content that arrives with a display change is still told'
        '${hidden ? ', while hidden' : ''}', (tester) async {
      final scroll = SessionLiveScroll();
      addTearDown(scroll.dispose);
      final items = [for (var n = 0; n < 6; n++) ..._turn('$n')];
      await _pump(
        tester,
        items,
        settled: true,
        scroll: scroll,
        showToolCalls: false,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(scroll.following, isFalse);
      if (hidden) {
        // The session is shown again from the timeline's memory.
        await tester.pumpWidget(const SizedBox());
      }
      await _pump(
        tester,
        [...items, ..._turn('6')],
        settled: true,
        scroll: scroll,
      );
      expect(scroll.unreadBelow, isTrue);
    });
  }

  testWidgets(
    'stretch and reasoning toggles expose SemanticsAction.tap and reasoning open state persists via PageStorage',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final items = <TimelineItem>[
          Reasoning(
            meta: _meta('r_top', message: 'm0'),
            text: 'persistent reasoning body',
            complete: true,
          ),
          for (var n = 0; n < 12; n++) ..._turn('p$n'),
        ];
        final scroll = SessionLiveScroll();
        addTearDown(scroll.dispose);
        await _pump(tester, items, settled: true, scroll: scroll);

        // Check SemanticsAction.tap on stretch toggle at bottom.
        final stretchToggle = find.byKey(
          const ValueKey('work-group-toggle-work-rp11'),
        );
        expect(
          tester
              .getSemantics(stretchToggle)
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );

        // Jump to top, expand r_top's stretch, then expand r_top itself,
        // verifying tap semantics and PageStorage persistence across unmount.
        scroll.controller.jumpTo(0);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('work-group-toggle-work-r_top')),
        );
        await tester.pumpAndSettle();
        final reasoningToggle = find.byKey(const ValueKey('reasoning-toggle'));
        expect(
          tester
              .getSemantics(reasoningToggle.first)
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );
        await tester.tap(reasoningToggle.first);
        await tester.pumpAndSettle();
        expect(find.text('persistent reasoning body'), findsOneWidget);

        // Scroll far away so r_top unmounts from SliverList, then scroll back.
        scroll.controller.jumpTo(scroll.controller.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(find.text('persistent reasoning body'), findsNothing);

        scroll.controller.jumpTo(0);
        await tester.pumpAndSettle();
        expect(find.text('persistent reasoning body'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'stretch header uses RTL-neutral expand icon and keeps running/failed tails visible at 320px 2x',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final scroll = SessionLiveScroll();
      addTearDown(scroll.dispose);
      final bgFacts = ToolRunFacts(
        shellId: 'sh_1',
        background: true,
        shellStatus: const OpenValue.known(ShellStatus.running),
      );
      final items = [
        ToolCall(
          meta: _meta('s1', message: 'm1'),
          kind: const OpenValue.known(ToolKind.shell),
          rawName: 'shell',
          runFacts: bgFacts,
        ),
        _tool('t1', 'm1', status: ItemStatus.failed),
        AssistantText(
          meta: _meta('a1', message: 'm2', status: ItemStatus.streaming),
          text: 'answer',
          complete: false,
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: V2Localizations.localizationsDelegates,
          supportedLocales: V2Localizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: ChatAppearance(
                mathRendering: true,
                conversationTextScale: 1,
                renderMode: ChatRenderMode.live,
                showReasoning: true,
                showToolCalls: true,
                child: SessionLiveTimeline(
                  items: items,
                  headerBuilder: (_) => const SizedBox(height: 8),
                  scroll: scroll,
                  settled: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = _l10n(tester);
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Symbols.expand_more), findsOneWidget);
      expect(find.text('· ${l10n.activityRunning(1)}'), findsOneWidget);
      expect(find.text('· ${l10n.activityFailed(1)}'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('work-group-toggle-work-s1')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Symbols.expand_less), findsOneWidget);
    },
  );

  testWidgets(
    'ToolCall.runFacts update counts as a live arrival when scrolled up',
    (tester) async {
      final scroll = SessionLiveScroll();
      addTearDown(scroll.dispose);
      final base = [
        for (var n = 0; n < 6; n++) ..._turn('rf$n'),
        ToolCall(
          meta: _meta('sh_call', message: 'm_last'),
          kind: const OpenValue.known(ToolKind.shell),
          rawName: 'shell',
          runFacts: ToolRunFacts(
            shellId: 'sh_1',
            background: true,
            shellStatus: const OpenValue.known(ShellStatus.running),
          ),
        ),
      ];
      await _pump(tester, base, settled: false, scroll: scroll);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(scroll.following, isFalse);
      expect(scroll.unreadBelow, isFalse);

      final updated = [
        ...base.take(base.length - 1),
        ToolCall(
          meta: _meta('sh_call', message: 'm_last'),
          kind: const OpenValue.known(ToolKind.shell),
          rawName: 'shell',
          runFacts: ToolRunFacts(
            shellId: 'sh_1',
            background: true,
            exitCode: 0,
            shellStatus: const OpenValue.known(ShellStatus.exited),
          ),
        ),
      ];
      await _pump(tester, updated, settled: false, scroll: scroll);
      expect(scroll.unreadBelow, isTrue);
    },
  );

  testWidgets(
    'expanded subagent card body tap still opens child while Details button opens dialog',
    (tester) async {
      var opened = false;
      final subagent = ToolCall(
        meta: _meta('sub1', message: 'm1'),
        kind: const OpenValue.known(ToolKind.subagent),
        rawName: 'subagent',
        input: CanonicalValue(const {'prompt': 'check tests'}),
        output: CanonicalValue(const [
          {'type': 'text', 'text': 'all clear'},
        ]),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: V2Localizations.localizationsDelegates,
          supportedLocales: V2Localizations.supportedLocales,
          home: Scaffold(
            body: ListView(
              children: [
                SessionTimelineTile(
                  item: subagent,
                  onOpenChild: (_) => opened = true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tool-status-sub1')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('tool-title-sub1')));
      await tester.pumpAndSettle();
      expect(opened, isTrue);
      expect(find.byKey(const ValueKey('tool-details-sub1')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('tool-toggle-sub1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tool-details-sub1')), findsOneWidget);
    },
  );

  testWidgets(
    'initial autoExpand on search highlight persists reasoning open state in PageStorage',
    (tester) async {
      final items = <TimelineItem>[
        Reasoning(
          meta: _meta('r_hit', message: 'm0', status: ItemStatus.streaming),
          text: 'highlighted reasoning body',
          complete: false,
        ),
        for (var n = 0; n < 12; n++) ..._turn('h$n'),
      ];
      final scroll = SessionLiveScroll();
      addTearDown(scroll.dispose);
      await _pump(
        tester,
        items,
        settled: false,
        scroll: scroll,
        highlight: const ItemId('r_hit'),
      );
      scroll.controller.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('highlighted reasoning body'), findsOneWidget);

      // Clear highlight, unmount by scrolling to bottom, then scroll back.
      await _pump(tester, items, settled: false, scroll: scroll);
      scroll.controller.jumpTo(scroll.controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('highlighted reasoning body'), findsNothing);

      scroll.controller.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('highlighted reasoning body'), findsOneWidget);
    },
  );
}
