import 'package:codewalk/features/sessions/session_timeline_tile.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// #492: a message's own gestures and menu.

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
        body: SingleChildScrollView(child: Column(children: tiles)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return copied;
}

Future<void> _doubleTap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 80));
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  testWidgets('a double tap copies the whole message, Markdown kept', (
    tester,
  ) async {
    final copied = await _pump(tester, [
      SessionTimelineTile(item: _user('please **fix** it')),
      SessionTimelineTile(item: _agent('# Done\n\nAll **good**.')),
    ]);
    await _doubleTap(tester, find.textContaining('please'));
    expect(copied, ['please **fix** it']);
    expect(find.text('Copied to clipboard'), findsOneWidget);
    await _doubleTap(tester, find.textContaining('All'));
    expect(copied.last, '# Done\n\nAll **good**.');
  });

  testWidgets('two taps far apart in time copy nothing', (tester) async {
    final copied = await _pump(tester, [
      SessionTimelineTile(item: _user('hello')),
    ]);
    await tester.tap(find.text('hello'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('hello'));
    await tester.pump();
    expect(copied, isEmpty);
  });

  testWidgets('a long press offers copy and select, and copy copies all', (
    tester,
  ) async {
    final copied = await _pump(tester, [
      SessionTimelineTile(item: _agent('the answer')),
    ]);
    await tester.longPress(find.text('the answer'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('message-menu-revert')), findsNothing);
    expect(find.text('Copy all text'), findsOneWidget);
    expect(find.text('Select text'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('message-menu-copy')));
    await tester.pumpAndSettle();
    expect(copied, ['the answer']);
  });

  testWidgets('a secondary click opens the same menu', (tester) async {
    await _pump(tester, [SessionTimelineTile(item: _agent('the answer'))]);
    await tester.tap(find.text('the answer'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('message-menu-copy')), findsOneWidget);
  });

  testWidgets('the Menu key opens the menu of the focused message', (
    tester,
  ) async {
    await _pump(tester, [SessionTimelineTile(item: _agent('the answer'))]);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('message-menu-copy')), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('message-menu-copy')), findsOneWidget);
  });

  testWidgets('revert shows only where offered and runs on the message', (
    tester,
  ) async {
    BuildContext? reverted;
    await _pump(tester, [
      SessionTimelineTile(
        item: _user('my prompt'),
        revert: SessionBubbleAction(
          label: 'Undo this turn',
          icon: Icons.undo,
          onSelected: (context) => reverted = context,
        ),
      ),
    ]);
    await tester.longPress(find.text('my prompt'));
    await tester.pumpAndSettle();
    expect(find.text('Undo this turn'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('message-menu-revert')));
    await tester.pumpAndSettle();
    expect(reverted, isNotNull);
  });

  testWidgets('select text is a mode of one message until Escape', (
    tester,
  ) async {
    await _pump(tester, [
      SessionTimelineTile(item: _user('first one')),
      SessionTimelineTile(item: _agent('second one')),
    ]);
    // No message selects by default: the long press is the menu's.
    expect(find.byType(SelectionArea), findsNothing);
    await tester.longPress(find.text('second one'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('message-menu-select')));
    await tester.pumpAndSettle();
    final area = find.byType(SelectionArea);
    expect(area, findsOneWidget);
    expect(
      find.descendant(of: area, matching: find.text('second one')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: area, matching: find.text('first one')),
      findsNothing,
    );
    // One Escape leaves, even with the selection's toolbar up.
    expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(SelectionArea), findsNothing);
  });

  testWidgets('the selection toolbar copies, then the mode ends', (
    tester,
  ) async {
    final copied = await _pump(tester, [
      SessionTimelineTile(item: _agent('second one')),
    ]);
    await tester.longPress(find.text('second one'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('message-menu-select')));
    await tester.pumpAndSettle();
    // Pressing the toolbar, which lives in the overlay, keeps the mode
    // until the copy runs.
    final copy = find.descendant(
      of: find.byType(AdaptiveTextSelectionToolbar),
      matching: find.text('Copy'),
    );
    final gesture = await tester.startGesture(tester.getCenter(copy));
    await tester.pump();
    expect(find.byType(SelectionArea), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(copied, ['second one']);
    expect(find.byType(SelectionArea), findsNothing);
  });

  testWidgets('a long press in the padding of agent text opens the menu', (
    tester,
  ) async {
    await _pump(tester, [SessionTimelineTile(item: _agent('the answer'))]);
    final bubble = tester.getRect(
      find.byKey(const ValueKey('message-bubble-test/a')),
    );
    await tester.longPressAt(bubble.topLeft + const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('message-menu-copy')), findsOneWidget);
  });

  testWidgets('screen readers get the message actions', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, [SessionTimelineTile(item: _agent('the answer'))]);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('message-bubble-test/a'))),
      isSemantics(
        customActions: const [
          CustomSemanticsAction(label: 'Copy all text'),
          CustomSemanticsAction(label: 'Select text'),
        ],
      ),
    );
    semantics.dispose();
  });

  testWidgets('a tap outside ends the selection', (tester) async {
    await _pump(tester, [
      SessionTimelineTile(item: _user('first one')),
      SessionTimelineTile(item: _agent('second one')),
    ]);
    await tester.longPress(find.text('second one'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('message-menu-select')));
    await tester.pumpAndSettle();
    expect(find.byType(SelectionArea), findsOneWidget);
    await tester.tap(find.text('first one'));
    await tester.pumpAndSettle();
    expect(find.byType(SelectionArea), findsNothing);
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

  testWidgets('a double tap on inline code still copies the whole message', (
    tester,
  ) async {
    final copied = await _pump(tester, [
      SessionTimelineTile(item: _agent('Run `make check` now.')),
    ]);
    final code = find.textRange.ofSubstring('make check');
    await tester.tapOnText(code);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapOnText(code);
    await tester.pump();
    expect(copied.last, 'Run `make check` now.');
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

  testWidgets('selecting in another item ends the message selection', (
    tester,
  ) async {
    // The notice sits below, clear of the toolbar shown above the message.
    await _pump(tester, [
      SessionTimelineTile(item: _agent('second one')),
      const SizedBox(height: 120),
      SessionTimelineTile(
        item: Notice(
          meta: _meta('n'),
          kind: const OpenValue.known(NoticeKind.system),
          text: 'a thought',
        ),
      ),
    ]);
    await tester.longPress(find.text('second one'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('message-menu-select')));
    await tester.pumpAndSettle();
    expect(
      find.ancestor(
        of: find.text('second one'),
        matching: find.byType(SelectionArea),
      ),
      findsOneWidget,
    );
    await tester.tap(find.textContaining('a thought'));
    await tester.pumpAndSettle();
    expect(
      find.ancestor(
        of: find.text('second one'),
        matching: find.byType(SelectionArea),
      ),
      findsNothing,
    );
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
}
