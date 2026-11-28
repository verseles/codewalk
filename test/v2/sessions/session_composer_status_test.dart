import 'package:codewalk/app/app_preferences_controller.dart';
import 'package:codewalk/features/sessions/session_composer_status.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/theme/chat_appearance.dart';
import 'package:codewalk_core/codewalk_core.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'live_fakes.dart';

const _ref = SessionRef(HostId('h'), HarnessInstanceId('h'), 'ses_1');

ItemMeta _meta(
  String id, {
  String? message,
  bool ended = false,
  ItemStatus status = ItemStatus.completed,
}) => ItemMeta(
  id: ItemId(id),
  generation: 'live',
  status: OpenValue.known(status),
  source: SourceProvenance(
    harness: _ref.harnessRef,
    version: '2.0.22',
    nativeType: 'live',
  ),
  message: message == null
      ? null
      : MessageContext(
          message: MessageRef(message),
          completed: ended ? DateTime.utc(2026, 10, 27) : null,
        ),
);

UserInput _prompt(String id) => UserInput(
  meta: _meta(id),
  text: 'go',
  delivery: const OpenValue.known(DeliveryState.delivered),
);

ToolCall _tool(
  String id,
  String message, {
  String name = 'read',
  ToolKind kind = ToolKind.read,
  bool ended = false,
}) => ToolCall(
  meta: _meta(id, message: message, ended: ended),
  kind: OpenValue.known(kind),
  rawName: name,
);

Reasoning _think(
  String id,
  String message,
  String text, {
  bool ended = false,
}) => Reasoning(
  meta: _meta(id, message: message, ended: ended),
  text: text,
  complete: ended,
);

SessionState _state(ExecutionKind? execution, List<TimelineItem> items) =>
    liveState(
      _ref,
      execution: execution == null
          ? null
          : ExecutionState(kind: OpenValue.known(execution)),
      items: items,
    );

Future<V2Localizations> _l10n(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      localizationsDelegates: V2Localizations.localizationsDelegates,
      supportedLocales: V2Localizations.supportedLocales,
      home: SizedBox(),
    ),
  );
  return V2Localizations.of(tester.element(find.byType(SizedBox)));
}

Future<void> _pump(
  WidgetTester tester,
  ComposerActivity? activity, {
  bool tips = true,
}) => tester.pumpWidget(
  MaterialApp(
    localizationsDelegates: V2Localizations.localizationsDelegates,
    supportedLocales: V2Localizations.supportedLocales,
    home: Scaffold(
      body: ChatAppearance(
        mathRendering: true,
        conversationTextScale: 1,
        composerTips: tips,
        child: SessionComposerStatus(activity: activity, pick: (_) => 0),
      ),
    ),
  ),
);

void main() {
  testWidgets('the slot reports the call or reasoning in flight', (
    tester,
  ) async {
    final l10n = await _l10n(tester);
    ComposerActivity? of(ExecutionKind? execution, List<TimelineItem> items) =>
        composerActivity(_state(execution, items), l10n);

    // Nothing while the session does not work.
    expect(of(ExecutionKind.idle, [_prompt('u1'), _tool('t1', 'm1')]), isNull);
    expect(of(null, [_prompt('u1')]), isNull);
    expect(
      of(ExecutionKind.retrying, const [])?.kind,
      ComposerStatusKind.retrying,
    );
    // The last call or reasoning of the message in flight.
    expect(
      of(ExecutionKind.running, [
        _prompt('u1'),
        _think('r1', 'm1', 'hmm'),
        _tool('t1', 'm1', name: 'grep', kind: ToolKind.search),
      ]),
      (kind: ComposerStatusKind.progress, label: l10n.toolKindSearch),
    );
    expect(
      of(ExecutionKind.running, [
        _prompt('u1'),
        _tool('t1', 'm1', ended: true),
        _think('r1', 'm2', '**Planning the fix**\nfirst'),
      ]),
      (kind: ComposerStatusKind.reasoning, label: 'Planning the fix'),
    );
    expect(
      of(ExecutionKind.running, [_prompt('u1'), _think('r1', 'm1', 'just')]),
      (kind: ComposerStatusKind.reasoning, label: l10n.chatStatusThinking),
    );
    // Finished messages, a sub-agent, a todo list and an earlier turn say
    // nothing about now.
    expect(
      of(ExecutionKind.running, [
        _tool('t0', 'm0'),
        _prompt('u1'),
        _tool('t1', 'm1', ended: true),
        _tool('t2', 'm2', name: 'task', kind: ToolKind.subagent),
        _tool('t3', 'm2', name: 'todowrite', kind: ToolKind.plan),
      ]),
      (kind: ComposerStatusKind.working, label: l10n.chatReasoning),
    );
  });

  testWidgets('a prompt still waiting is not where the turn starts (#502)', (
    tester,
  ) async {
    final l10n = await _l10n(tester);
    final waiting = UserInput(
      meta: _meta('u2', status: ItemStatus.pending),
      text: 'also do this',
      delivery: const OpenValue.known(DeliveryState.accepted),
    );
    expect(
      composerActivity(
        _state(ExecutionKind.running, [
          _prompt('u1'),
          _think('r1', 'm1', '**Reading the code**'),
          waiting,
        ]),
        l10n,
      ),
      (kind: ComposerStatusKind.reasoning, label: 'Reading the code'),
    );
  });

  testWidgets('shell commands never fill the slot (#521)', (tester) async {
    final l10n = await _l10n(tester);
    ShellRun shell(String id, ShellStatus status) => ShellRun(
      meta: _meta(id),
      command: 'make check',
      shellStatus: OpenValue.known(status),
    );
    ComposerActivity? of(List<TimelineItem> items) =>
        composerActivity(_state(ExecutionKind.running, items), l10n);
    // A running shell outside any message gives way to what came before.
    expect(of([_prompt('u1'), shell('s1', ShellStatus.running)]), (
      kind: ComposerStatusKind.working,
      label: l10n.chatReasoning,
    ));
    for (final status in ShellStatus.values) {
      expect(
        of([
          _prompt('u1'),
          _think('r1', 'm1', '**Writing the reply**'),
          shell('s1', status),
        ]),
        (kind: ComposerStatusKind.reasoning, label: 'Writing the reply'),
        reason: '$status',
      );
    }
    // A shell tool call in the message in flight is skipped too, for the
    // call before it.
    expect(
      of([
        _prompt('u1'),
        _tool('t1', 'm1', name: 'grep', kind: ToolKind.search),
        _tool('t2', 'm1', name: 'bash', kind: ToolKind.shell),
      ]),
      (kind: ComposerStatusKind.progress, label: l10n.toolKindSearch),
    );
    expect(
      of([
        _prompt('u1'),
        _tool('t1', 'm1', name: 'bash', kind: ToolKind.shell),
      ]),
      (kind: ComposerStatusKind.working, label: l10n.chatReasoning),
    );
  });

  testWidgets('an item outside any message counts only while it runs', (
    tester,
  ) async {
    final l10n = await _l10n(tester);
    ToolCall loose(ItemStatus status) => ToolCall(
      meta: _meta('t9', status: status),
      kind: const OpenValue.known(ToolKind.search),
      rawName: 'grep',
    );
    expect(
      composerActivity(
        _state(ExecutionKind.running, [
          _prompt('u1'),
          loose(ItemStatus.streaming),
        ]),
        l10n,
      )?.label,
      l10n.toolKindSearch,
    );
    expect(
      composerActivity(
        _state(ExecutionKind.running, [
          _prompt('u1'),
          _think('r1', 'm1', '**Writing the reply**'),
          loose(ItemStatus.completed),
        ]),
        l10n,
      ),
      (kind: ComposerStatusKind.reasoning, label: 'Writing the reply'),
    );
    // A finished call still names its message while the message runs.
    expect(
      composerActivity(
        _state(ExecutionKind.running, [_prompt('u1'), _tool('t1', 'm1')]),
        l10n,
      )?.label,
      l10n.toolKindRead,
    );
  });

  test('a reasoning heading reads as words', () {
    expect(
      reasoningHeading('**Reading the tests**\nmore'),
      'Reading the tests',
    );
    expect(reasoningHeading('  **Plan**'), 'Plan');
    expect(reasoningHeading('no heading'), isNull);
    expect(reasoningHeading('**[x]**'), isNull);
    expect(reasoningHeading('**${'a' * 65}**'), isNull);
  });

  testWidgets('tips wait a moment, rotate, and clear after the work', (
    tester,
  ) async {
    final l10n = await _l10n(tester);
    final tips = composerTips(l10n);
    const working = (kind: ComposerStatusKind.working, label: 'Reasoning...');
    await _pump(tester, working);
    expect(find.text(tips[0].text), findsNothing);
    await tester.pump(SessionComposerStatus.showDelay);
    expect(find.text(tips[0].text), findsOneWidget);
    await tester.pump(SessionComposerStatus.tipInterval);
    await tester.pumpAndSettle();
    expect(find.text(tips[1].text), findsOneWidget);
    // Real activity shows at once and stops the tips.
    await _pump(tester, (kind: ComposerStatusKind.progress, label: 'grep'));
    await tester.pumpAndSettle();
    expect(find.text('grep'), findsOneWidget);
    // The slot clears a moment after the work ends, and keeps its height.
    await _pump(tester, null);
    expect(find.text('grep'), findsOneWidget);
    await tester.pump(SessionComposerStatus.hideDelay);
    await tester.pumpAndSettle();
    expect(find.text('grep'), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('composer-status'))).height,
      SessionComposerStatus.height,
    );
  });

  testWidgets('without tips the slot says the assistant reasons', (
    tester,
  ) async {
    final l10n = await _l10n(tester);
    await _pump(tester, (
      kind: ComposerStatusKind.working,
      label: l10n.chatReasoning,
    ), tips: false);
    await tester.pump(SessionComposerStatus.showDelay);
    await tester.pumpAndSettle();
    expect(find.text(l10n.chatReasoning), findsOneWidget);
    for (final tip in composerTips(l10n)) {
      expect(find.text(tip.text), findsNothing);
    }
  });

  test('tips are offered only where they apply, in every language (#548)', () {
    for (final locale in V2Localizations.supportedLocales) {
      final l10n = lookupV2Localizations(locale);
      final plain = composerTips(l10n);
      expect(plain.where((tip) => tip.link != null), isEmpty);
      final all = composerTips(
        l10n,
        display: true,
        keyboard: true,
        readAloud: true,
      );
      expect(all.length, plain.length + 5, reason: '$locale');
      // The link sits where the language puts its label.
      final linked = all.where((tip) => tip.link != null).toList();
      expect(linked.map((tip) => tip.link), [
        ComposerTipLink.display,
        ComposerTipLink.shortcuts,
        ComposerTipLink.readAloud,
        ComposerTipLink.display,
      ], reason: '$locale');
      for (final tip in linked) {
        expect(tip.label, isNotEmpty);
        expect(tip.text, contains(tip.label));
      }
      // Tabs already shown need no tip.
      expect(
        composerTips(l10n, display: true, tabsShown: true).length,
        composerTips(l10n, display: true).length - 1,
      );
    }
  });

  testWidgets('a tip about a menu opens it from its link (#548)', (
    tester,
  ) async {
    final l10n = await _l10n(tester);
    final preferences = AppPreferencesController();
    addTearDown(preferences.dispose);
    preferences.setShowSessionTabs(false);
    final tips = composerTips(l10n, display: true);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppPreferencesController?>.value(
        value: preferences,
        child: MaterialApp(
          localizationsDelegates: V2Localizations.localizationsDelegates,
          supportedLocales: V2Localizations.supportedLocales,
          home: Scaffold(
            body: ChatAppearance(
              mathRendering: true,
              conversationTextScale: 1,
              composerTips: true,
              child: SessionComposerStatus(
                activity: (
                  kind: ComposerStatusKind.working,
                  label: 'Reasoning...',
                ),
                pick: (_) => 0,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(SessionComposerStatus.showDelay);
    await tester.pumpAndSettle();
    expect(tips.first.link, ComposerTipLink.display);
    expect(find.text(tips.first.text), findsOneWidget);
    await tester.tapOnText(find.textRange.ofSubstring(l10n.chatDisplayMenu));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('workspace-display-sheet')),
      findsOneWidget,
    );
  });

  testWidgets('a label longer than the bar offers its whole text', (
    tester,
  ) async {
    final l10n = await _l10n(tester);
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester, (
      kind: ComposerStatusKind.notice,
      label: l10n.liveExecutionUnconfirmed,
    ));
    await tester.pumpAndSettle();
    final more = find.byKey(const ValueKey('composer-status-more'));
    expect(more, findsOneWidget);
    expect(
      tester.getTopRight(more).dx,
      greaterThan(
        tester.getTopRight(find.text(l10n.liveExecutionUnconfirmed)).dx,
      ),
    );
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('composer-status-whole')),
        matching: find.text(l10n.liveExecutionUnconfirmed),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text(l10n.chatClose));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('composer-status-whole')), findsNothing);

    // A short label needs no More, and a resolved notice clears at once.
    await _pump(tester, (kind: ComposerStatusKind.idle, label: l10n.liveIdle));
    await tester.pumpAndSettle();
    expect(more, findsNothing);
    await _pump(tester, (
      kind: ComposerStatusKind.attention,
      label: l10n.liveNeedsYou,
    ));
    await tester.pump();
    await _pump(tester, null);
    expect(find.text(l10n.liveNeedsYou), findsNothing);
  });
}
