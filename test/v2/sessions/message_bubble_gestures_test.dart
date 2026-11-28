import 'package:codewalk/features/sessions/message_action_bar.dart';
import 'package:codewalk/features/sessions/session_live_timeline.dart';
import 'package:codewalk/features/sessions/session_timeline_tile.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/gestures.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// #539: a message's always selectable text and its action bar.

ItemMeta _meta(String id) => ItemMeta(
  id: ItemId('test/$id'),
  generation: 'test',
  status: const OpenValue.known(ItemStatus.completed),
  source: SourceProvenance(
    harness: const HarnessRef(HostId('h'), HarnessInstanceId('test')),
    version: '2.0.22',
    nativeType: 'test',
  ),
);

UserInput _user(String text) => UserInput(
  meta: _meta('u'),
  text: text,
  delivery: const OpenValue.known(DeliveryState.delivered),
);

AssistantText _agent(String text) =>
    AssistantText(meta: _meta('a'), text: text, complete: true);

/// Pumps [tiles] and records what reaches the clipboard.
Future<List<String>> _pump(WidgetTester tester, List<Widget> tiles) async {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: V2Localizations.localizationsDelegates,
      supportedLocales: V2Localizations.supportedLocales,
      home: Scaffold(
        // The list fills the screen, as the timeline does.
        body: SingleChildScrollView(
          child: Column(children: [...tiles, const SizedBox(height: 600)]),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return copied;
}

Finder get _bar => find.byKey(const ValueKey('message-action-bar'));

Finder _action(MessageActionId id) =>
    find.byKey(ValueKey('message-action-${id.name}'));

MessageAction _undo(void Function() run) => MessageAction(
  id: MessageActionId.undo,
  label: 'Undo this turn',
  icon: Icons.undo,
  onSelected: (_) => run(),
);

void main() {
  testWidgets('a tap on the text opens the bar, whose copy copies all', (
    tester,
  ) async {
    final copied = await _pump(tester, [
      SessionTimelineTile(item: _user('please **fix** it')),
      SessionTimelineTile(item: _agent('# Done\n\nAll **good**.')),
    ]);
    expect(_bar, findsNothing);
    await tester.tap(find.textContaining('All'));
    await tester.pumpAndSettle();
    expect(_bar, findsOneWidget);
    await tester.tap(_action(MessageActionId.copy));
    await tester.pumpAndSettle();
    expect(copied, ['# Done\n\nAll **good**.']);
    expect(find.text('Copied to clipboard'), findsOneWidget);
    expect(_bar, findsNothing);
  });

  testWidgets('a tap beside the bubble opens its bar; a tap outside closes', (
    tester,
  ) async {
    await _pump(tester, [
      SessionTimelineTile(item: _user('hi')),
      const SizedBox(height: 200),
    ]);
    final bubble = tester.getRect(find.textContaining('hi'));
    // Left of the user's bubble, in its row.
    await tester.tapAt(Offset(20, bubble.center.dy));
    await tester.pumpAndSettle();
    expect(_bar, findsOneWidget);
    await tester.tapAt(const Offset(20, 400));
    await tester.pumpAndSettle();
    expect(_bar, findsNothing);
  });

  testWidgets('one bar at a time', (tester) async {
    await _pump(tester, [
      SessionTimelineTile(item: _user('first one')),
      const SizedBox(height: 80),
      SessionTimelineTile(item: _agent('second one')),
    ]);
    await tester.tap(find.text('first one'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('second one'));
    await tester.pumpAndSettle();
    expect(_bar, findsOneWidget);
  });

  testWidgets('a long press on words selects them, not the bar', (
    tester,
  ) async {
    await _pump(tester, [
      SessionTimelineTile(item: _agent('select these words please')),
    ]);
    expect(
      find.ancestor(
        of: find.text('select these words please'),
        matching: find.byType(SelectionArea),
      ),
      findsOneWidget,
    );
    await tester.longPress(find.text('select these words please'));
    await tester.pumpAndSettle();
    expect(_bar, findsNothing);
    expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
  });

  testWidgets('a long press on a clean area opens the bar', (tester) async {
    await _pump(tester, [SessionTimelineTile(item: _user('my prompt'))]);
    final card = tester.getRect(find.byType(Card));
    // The bubble's padding, below the text.
    await tester.longPressAt(Offset(card.right - 6, card.bottom - 4));
    await tester.pumpAndSettle();
    expect(_bar, findsOneWidget);
    expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
  });

  testWidgets('a double tap selects a word and copies nothing', (tester) async {
    final copied = await _pump(tester, [
      SessionTimelineTile(item: _agent('two words')),
    ]);
    await tester.tap(find.text('two words'));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('two words'));
    await tester.pumpAndSettle();
    expect(copied, isEmpty);
    expect(_bar, findsNothing);
  });

  testWidgets('a secondary click beside the message opens the bar', (
    tester,
  ) async {
    await _pump(tester, [SessionTimelineTile(item: _user('hi'))]);
    final bubble = tester.getRect(find.textContaining('hi'));
    await tester.tapAt(Offset(20, bubble.center.dy), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(_bar, findsOneWidget);
  });

  testWidgets('the Menu key opens the bar on its first button; Escape '
      'closes it', (tester) async {
    await _pump(tester, [SessionTimelineTile(item: _agent('the answer'))]);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pumpAndSettle();
    expect(_bar, findsOneWidget);
    final copy = tester.widget<IconButton>(
      find.descendant(
        of: _action(MessageActionId.copy),
        matching: find.byType(IconButton),
      ),
    );
    expect(copy.focusNode?.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_bar, findsNothing);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(_bar, findsOneWidget);
  });

  testWidgets('the mouse shows the bar on rest and hides it after leaving', (
    tester,
  ) async {
    await _pump(tester, [
      SessionTimelineTile(item: _agent('the answer')),
      const SizedBox(height: 300),
    ]);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(700, 500));
    await tester.pump();
    await mouse.moveTo(tester.getCenter(find.text('the answer')));
    await tester.pump(messageBarHoverDelay ~/ 2);
    expect(_bar, findsNothing);
    await tester.pump(messageBarHoverDelay);
    await tester.pumpAndSettle();
    expect(_bar, findsOneWidget);
    // Crossing to the bar keeps it.
    await mouse.moveTo(tester.getCenter(_bar));
    await tester.pump(messageBarHideDelay * 2);
    expect(_bar, findsOneWidget);
    await mouse.moveTo(const Offset(700, 500));
    await tester.pump(messageBarHideDelay ~/ 2);
    expect(_bar, findsOneWidget);
    await tester.pump(messageBarHideDelay);
    await tester.pumpAndSettle();
    expect(_bar, findsNothing);
  });

  testWidgets('the bar sits on the top edge, or the bottom one at the top', (
    tester,
  ) async {
    await _pump(tester, [
      SessionTimelineTile(item: _agent('at the very top')),
      const SizedBox(height: 120),
      SessionTimelineTile(item: _user('lower down')),
    ]);
    await tester.tap(find.text('lower down'));
    await tester.pumpAndSettle();
    final card = tester.getRect(find.byType(Card));
    expect(tester.getCenter(_bar).dy, moreOrLessEquals(card.top, epsilon: 1));
    // The user's bar sits at the bubble's end.
    expect(tester.getRect(_bar).right, lessThanOrEqualTo(card.right));
    await tester.tapAt(const Offset(400, 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('at the very top'));
    await tester.pumpAndSettle();
    final top = tester.getRect(
      find.byKey(const ValueKey('message-bubble-test/a')),
    );
    expect(tester.getCenter(_bar).dy, greaterThan(top.top));
  });

  testWidgets('turn actions show where offered; overflow ones in the menu', (
    tester,
  ) async {
    var undone = 0;
    var forked = 0;
    await _pump(tester, [
      SessionTimelineTile(
        item: _user('my prompt'),
        actions: [
          _undo(() => undone++),
          MessageAction(
            id: MessageActionId.fork,
            label: 'Fork from here',
            icon: Icons.call_split,
            overflow: true,
            onSelected: (_) => forked++,
          ),
        ],
      ),
    ]);
    await tester.tap(find.text('my prompt'));
    await tester.pumpAndSettle();
    final buttons = tester
        .widgetList(
          find.descendant(
            of: _bar,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget.key is ValueKey<String> &&
                  (widget.key! as ValueKey<String>).value.startsWith(
                    'message-action-',
                  ),
            ),
          ),
        )
        .map((button) => (button.key! as ValueKey<String>).value)
        .toList();
    // Copy first, then the turn, then the menu.
    expect(buttons, [
      'message-action-copy',
      'message-action-undo',
      'message-action-more',
    ]);
    await tester.tap(_action(MessageActionId.undo));
    await tester.pumpAndSettle();
    expect(undone, 1);
    expect(_bar, findsNothing);
    await tester.tap(find.text('my prompt'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('message-action-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fork from here'));
    await tester.pumpAndSettle();
    expect(forked, 1);
  });

  testWidgets('a long press on a bar button shows what it does', (
    tester,
  ) async {
    await _pump(tester, [SessionTimelineTile(item: _agent('the answer'))]);
    await tester.tap(find.text('the answer'));
    await tester.pumpAndSettle();
    await tester.longPress(_action(MessageActionId.copy));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('message-action-hint')),
        matching: find.text('Copy all text'),
      ),
      findsOneWidget,
    );
    // It runs nothing, and the name goes away by itself.
    expect(_bar, findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('message-action-hint')), findsNothing);
  });

  testWidgets('a waiting prompt is selectable but has no bar (#502)', (
    tester,
  ) async {
    // Its fill breathes, so the frames are pumped by hand.
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: V2Localizations.localizationsDelegates,
        supportedLocales: V2Localizations.supportedLocales,
        home: Scaffold(
          body: SessionTimelineTile(
            item: UserInput(
              meta: _meta('w'),
              text: 'on its way',
              delivery: const OpenValue.known(DeliveryState.queued),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('on its way'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_bar, findsNothing);
    expect(
      find.ancestor(
        of: find.text('on its way'),
        matching: find.byType(SelectionArea),
      ),
      findsOneWidget,
    );
  });

  testWidgets('screen readers get the message actions', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, [
      SessionTimelineTile(item: _user('my prompt'), actions: [_undo(() {})]),
    ]);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('message-row-test/u'))),
      matchesSemantics(
        customActions: const [
          CustomSemanticsAction(label: 'Copy all text'),
          CustomSemanticsAction(label: 'Undo this turn'),
        ],
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('a tap on inline code copies only that code', (tester) async {
    final copied = await _pump(tester, [
      SessionTimelineTile(item: _agent('Run `make check` now.')),
    ]);
    // The code flows in its paragraph, one run of text with the words.
    expect(
      find.text('Run make check now.', findRichText: true),
      findsOneWidget,
    );
    await tester.tapOnText(find.textRange.ofSubstring('make check'));
    await tester.pump();
    expect(copied, ['make check']);
    expect(find.text('Copied to clipboard'), findsOneWidget);
  });

  testWidgets('the same code in and out of a link: each keeps its tap', (
    tester,
  ) async {
    final opened = <String>[];
    final copied = await _pump(tester, [
      SessionTimelineTile(
        item: _agent('Run `pkg` or see [`pkg`](https://example.com/pkg).'),
        onTapLink: (text, href, title) => opened.add(href),
      ),
    ]);
    final first = find.textRange.ofSubstring('pkg').first;
    final second = find.textRange.ofSubstring('pkg').last;
    await tester.tapOnText(first);
    await tester.pump(const Duration(seconds: 1));
    expect(copied, ['pkg']);
    await tester.tapOnText(second);
    await tester.pump();
    expect(opened, ['https://example.com/pkg']);
    expect(copied, ['pkg']);
  });

  testWidgets('code in a link keeps opening it after a theme change', (
    tester,
  ) async {
    final opened = <String>[];
    Widget app(Brightness brightness) => MaterialApp(
      theme: ThemeData(brightness: brightness),
      localizationsDelegates: V2Localizations.localizationsDelegates,
      supportedLocales: V2Localizations.supportedLocales,
      home: Scaffold(
        body: SessionTimelineTile(
          item: _agent('See [`pkg`](https://example.com/pkg).'),
          onTapLink: (text, href, title) => opened.add(href),
        ),
      ),
    );
    await tester.pumpWidget(app(Brightness.light));
    await tester.pumpWidget(app(Brightness.dark));
    await tester.pumpAndSettle();
    await tester.tapOnText(find.textRange.ofSubstring('pkg'));
    await tester.pump();
    expect(opened, ['https://example.com/pkg']);
  });

  testWidgets('code in a reference link opens the link', (tester) async {
    final opened = <String>[];
    final copied = await _pump(tester, [
      SessionTimelineTile(
        item: _agent('See [`arr[0]`][doc].\n\n[doc]: https://example.com/a'),
        onTapLink: (text, href, title) => opened.add(href),
      ),
    ]);
    await tester.tapOnText(find.textRange.ofSubstring('arr[0]'));
    await tester.pump();
    expect(opened, ['https://example.com/a']);
    expect(copied, isEmpty);
  });

  testWidgets('inline code inside a link opens the link', (tester) async {
    final opened = <String>[];
    final copied = await _pump(tester, [
      SessionTimelineTile(
        item: _agent('See [`pkg`](https://example.com/pkg).'),
        onTapLink: (text, href, title) => opened.add(href),
      ),
    ]);
    await tester.tapOnText(find.textRange.ofSubstring('pkg'));
    await tester.pump();
    expect(opened, ['https://example.com/pkg']);
    expect(copied, isEmpty);
  });

  testWidgets('links keep opening at once', (tester) async {
    final opened = <String>[];
    await _pump(tester, [
      SessionTimelineTile(
        item: _agent('[docs](https://example.com)'),
        onTapLink: (text, href, title) => opened.add(href),
      ),
    ]);
    await tester.tapOnText(find.textRange.ofSubstring('docs'));
    await tester.pump();
    expect(opened, ['https://example.com']);
  });

  test('each message belongs to the confirmed turn before it', () {
    UserInput turn(String id, {bool confirmed = true}) => UserInput(
      meta: _meta(id),
      text: id,
      delivery: const OpenValue.known(DeliveryState.delivered),
      confirmed: confirmed,
    );
    AssistantText answer(String id) =>
        AssistantText(meta: _meta(id), text: id, complete: true);
    final early = answer('early');
    final u1 = turn('u1');
    final a1 = answer('a1');
    final echo = turn('echo', confirmed: false);
    final u2 = turn('u2');
    final a2 = answer('a2');
    final turns = messageTurns([early, u1, a1, echo, u2, a2]);
    expect(turns[early.id], isNull);
    expect(turns[a1.id]?.owner, u1);
    expect(turns[a1.id]?.latest, isFalse);
    expect(turns[a1.id]?.next, u2);
    // A prompt not confirmed yet starts no turn.
    expect(turns[echo.id]?.owner, u1);
    expect(turns[u2.id]?.owner, u2);
    expect(turns[a2.id]?.latest, isTrue);
    expect(turns[a2.id]?.next, isNull);
  });
}
