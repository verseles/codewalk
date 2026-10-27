import 'package:codewalk/features/sessions/session_composer_status.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/theme/chat_appearance.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
        _tool('t1', 'm1', name: 'grep'),
      ]),
      (kind: ComposerStatusKind.progress, label: 'grep'),
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
        _tool('t3', 'm2', name: 'todowrite', kind: ToolKind.other),
      ]),
      (kind: ComposerStatusKind.working, label: l10n.chatReasoning),
    );
  });

  testWidgets('an item outside any message counts only while it runs', (
    tester,
  ) async {
    final l10n = await _l10n(tester);
    ShellRun shell(String id, ShellStatus status) => ShellRun(
      meta: _meta(id),
      command: 'make check',
      shellStatus: OpenValue.known(status),
    );
    expect(
      composerActivity(
        _state(ExecutionKind.running, [
          _prompt('u1'),
          shell('s1', ShellStatus.running),
        ]),
        l10n,
      ),
      (kind: ComposerStatusKind.progress, label: r'$ make check'),
    );
    for (final status in [
      ShellStatus.exited,
      ShellStatus.timeout,
      ShellStatus.killed,
    ]) {
      expect(
        composerActivity(
          _state(ExecutionKind.running, [
            _prompt('u1'),
            _think('r1', 'm1', '**Writing the reply**'),
            shell('s1', status),
          ]),
          l10n,
        ),
        (kind: ComposerStatusKind.reasoning, label: 'Writing the reply'),
        reason: '$status',
      );
    }
    // A finished call still names its message while the message runs.
    expect(
      composerActivity(
        _state(ExecutionKind.running, [_prompt('u1'), _tool('t1', 'm1')]),
        l10n,
      )?.label,
      'read',
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
    expect(find.text(tips[0]), findsNothing);
    await tester.pump(SessionComposerStatus.showDelay);
    expect(find.text(tips[0]), findsOneWidget);
    await tester.pump(SessionComposerStatus.tipInterval);
    await tester.pumpAndSettle();
    expect(find.text(tips[1]), findsOneWidget);
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
      expect(find.text(tip), findsNothing);
    }
  });
}
