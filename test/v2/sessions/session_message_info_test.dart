import 'package:codewalk/features/sessions/session_message_info.dart';
import 'package:codewalk/features/sessions/session_timeline_tile.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _created = DateTime.utc(2026, 10, 27, 12);

ItemMeta _meta(String id, {MessageContext? message}) => ItemMeta(
  id: ItemId('test/$id'),
  generation: 'test',
  status: OpenValue.unknown('test'),
  source: SourceProvenance(
    harness: const HarnessRef(HostId('h'), HarnessInstanceId('test')),
    version: '2.0.22',
    nativeType: 'assistant',
  ),
  message: message,
);

MessageContext _context({Duration? took, String id = 'msg_a'}) =>
    MessageContext(
      message: MessageRef(id),
      created: _created,
      completed: took == null ? null : _created.add(took),
      modelId: 'model-x',
      modelProviderId: 'provider-y',
      tokens: TokenBreakdown(input: 10, output: 5, cacheRead: 3),
      cost: Cost(amount: 0.25, currency: 'USD'),
      finish: 'stop',
    );

Widget _surface(Widget child) => MaterialApp(
  theme: ThemeData(
    cardTheme: const CardThemeData(
      shape: RoundedRectangleBorder(side: BorderSide(width: 1)),
    ),
  ),
  localizationsDelegates: V2Localizations.localizationsDelegates,
  supportedLocales: V2Localizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('history minimizes an unknown shell but keeps known shells readable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _surface(
        Column(
          children: [
            SessionTimelineTile(
              item: ShellRun(meta: _meta('unknown-shell'), command: 'hidden-command'),
              minimizeUnknownShell: true,
            ),
            SessionTimelineTile(
              item: ShellRun(
                meta: _meta('known-shell'),
                command: 'visible-command',
                shellStatus: const OpenValue.known(ShellStatus.exited),
              ),
              minimizeUnknownShell: true,
            ),
          ],
        ),
      ),
    );
    expect(find.textContaining('hidden-command'), findsNothing);
    expect(find.textContaining('visible-command'), findsOneWidget);
    expect(find.byKey(const ValueKey('tool-toggle-unknown-shell')), findsNothing);
  });
  test('elapsed time is compact and needs consistent harness times', () {
    String? format(Duration? took) =>
        formatMessageElapsed(_context(took: took));
    expect(format(const Duration(milliseconds: 200)), '200ms');
    expect(format(const Duration(seconds: 3, milliseconds: 900)), '3s');
    expect(format(const Duration(minutes: 1, seconds: 5)), '1m 5s');
    expect(format(const Duration(minutes: 2)), '2m');
    expect(format(const Duration(hours: 2)), '2h');
    expect(format(const Duration(hours: 1, minutes: 3)), '1h 3m');
    expect(format(null), isNull);
    expect(format(const Duration(seconds: -1)), isNull);
  });

  for (final (name, tokens) in [
    ('doubles', TokenBreakdown(input: 1e308, output: 1e308)),
    // Integers whose int sum would wrap past 2^63 on native platforms.
    (
      'integers',
      TokenBreakdown(input: 0x4000000000000000, output: 0x4000000000000000),
    ),
  ]) {
    testWidgets('an overflowing token count is unknown ($name)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _surface(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showMessageInfoDialog(
                context,
                MessageContext(message: MessageRef('m'), tokens: tokens),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Tokens'), findsNothing);
    });
  }

  test('only the first part of a message opens it', () {
    final a = _context();
    final b = _context(id: 'msg_b');
    final items = [
      AssistantText(
        meta: _meta('1', message: a),
        text: 'x',
        complete: true,
      ),
      Reasoning(
        meta: _meta('2', message: a),
        text: 'y',
        complete: true,
      ),
      AssistantText(
        meta: _meta('3', message: b),
        text: 'z',
        complete: true,
      ),
      AssistantText(meta: _meta('4'), text: 'w', complete: true),
    ];
    expect(
      [for (var i = 0; i < items.length; i++) opensMessage(items, i)],
      [true, false, true, false],
    );
  });

  testWidgets('the elapsed chip opens the message details', (tester) async {
    final context = _context(took: const Duration(seconds: 3));
    await tester.pumpWidget(
      _surface(
        SessionTimelineTile(
          item: AssistantText(
            meta: _meta('1', message: context),
            text: 'Body',
            complete: true,
          ),
          messageHeader: true,
        ),
      ),
    );
    final chip = find.byKey(const ValueKey('message-elapsed-msg_a'));
    expect(
      find.descendant(of: chip, matching: find.text('3s')),
      findsOneWidget,
    );
    await tester.tap(chip);
    await tester.pumpAndSettle();
    for (final text in [
      'Message Info',
      'Model: model-x',
      'Provider: provider-y',
      'Tokens: 18',
      r'Cost: $0.250000',
      'Step started #1',
      r'Step finished #1: stop • tokens 18 • $0.250000',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Message Info'), findsNothing);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('message-info-close')));
    await tester.pumpAndSettle();
    expect(find.text('Message Info'), findsNothing);
  });

  testWidgets('a running message shows a placeholder and still opens', (
    tester,
  ) async {
    await tester.pumpWidget(
      _surface(
        SessionTimelineTile(
          item: AssistantText(
            meta: _meta('1', message: MessageContext(message: MessageRef('m'))),
            text: 'Body',
            complete: false,
          ),
          messageHeader: true,
        ),
      ),
    );
    final chip = find.byKey(const ValueKey('message-elapsed-m'));
    expect(find.descendant(of: chip, matching: find.text('…')), findsOneWidget);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.text('No metadata available'), findsOneWidget);
  });

  testWidgets('assistant parts are borderless; user turns keep the frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      _surface(
        Column(
          children: [
            SessionTimelineTile(
              item: UserInput(
                meta: _meta('u'),
                text: 'Hi',
                delivery: const OpenValue.known(DeliveryState.delivered),
              ),
            ),
            SessionTimelineTile(
              item: AssistantText(
                meta: _meta('a', message: _context()),
                text: 'Hello',
                complete: true,
              ),
            ),
          ],
        ),
      ),
    );
    final cards = tester.widgetList<Card>(find.byType(Card)).toList();
    BorderSide side(Card card) =>
        (card.shape as RoundedRectangleBorder?)?.side ??
        const BorderSide(width: 1);
    expect(side(cards[0]).width, 1);
    expect(side(cards[1]), BorderSide.none);
    // Without the header flag the message details stay out of the row.
    expect(find.byType(MessageElapsedChip), findsNothing);
  });
}
