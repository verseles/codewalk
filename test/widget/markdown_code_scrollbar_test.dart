import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/presentation/widgets/chat_message_widget.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_localized_app.dart';

String _fence(String text) => '```text\n$text\n```';
final _longLine = List.filled(100, 'long_value').join(' ');

Widget _host(
  String text, {
  TargetPlatform platform = TargetPlatform.linux,
  double width = 340,
  EdgeInsets padding = EdgeInsets.zero,
  Widget? after,
}) => localizedMaterialApp(
  theme: ThemeData(platform: platform),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(padding: padding),
    child: child!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(
            width: width,
            child: ChatMessageWidget(
              message: AssistantMessage(
                id: 'scroll_message',
                sessionId: 'scroll_session',
                time: DateTime.fromMillisecondsSinceEpoch(0),
                completedTime: DateTime.fromMillisecondsSinceEpoch(1),
                parts: [
                  TextPart(
                    id: 'scroll_part',
                    messageId: 'scroll_message',
                    sessionId: 'scroll_session',
                    text: text,
                  ),
                ],
              ),
            ),
          ),
          ?after,
          const SizedBox(height: 1400),
        ],
      ),
    ),
  ),
);

Finder get _bars => find.byWidgetPredicate(
  (widget) =>
      widget is Scrollbar &&
      widget.scrollbarOrientation == ScrollbarOrientation.bottom,
);
List<Scrollbar> _scrollbars(WidgetTester tester) =>
    tester.widgetList<Scrollbar>(_bars).toList();
List<Focus> _focusControls(WidgetTester tester) => tester
    .widgetList<Focus>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Focus &&
            widget.focusNode?.debugLabel == 'Markdown code scrolling',
      ),
    )
    .toList();

void main() {
  testWidgets('code scrollbar hover, mouse drag and track click do not copy', (
    tester,
  ) async {
    var copies = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') copies++;
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
      _host(
        _fence(_longLine),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 34),
      ),
    );
    await tester.pumpAndSettle();
    expect(MediaQuery.paddingOf(tester.element(_bars)), EdgeInsets.zero);
    var bar = _scrollbars(tester).single;
    expect(bar.controller!.position.maxScrollExtent, greaterThan(0));
    expect(bar.thumbVisibility, isFalse);
    final rect = tester.getRect(_bars);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(rect.center);
    await tester.pumpAndSettle();
    bar = _scrollbars(tester).single;
    expect(bar.thumbVisibility, isTrue);
    expect(bar.trackVisibility, isTrue);
    final thumb = Offset(rect.left + 20, rect.bottom - 6);
    await mouse.moveTo(thumb);
    await mouse.down(thumb);
    await mouse.moveBy(const Offset(65, 0));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(bar.controller!.offset, greaterThan(0));
    final before = bar.controller!.offset;
    final track = Offset(rect.right - 20, rect.bottom - 6);
    await mouse.moveTo(track);
    await mouse.down(track);
    await mouse.up();
    await tester.pumpAndSettle();
    expect(bar.controller!.offset, greaterThan(before));
    expect(copies, 0);
    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(_scrollbars(tester).single.thumbVisibility, isFalse);
    await mouse.removePointer();
  });

  testWidgets(
    'code scrollbar keyboard focus is local and leaves modifiers alone',
    (tester) async {
      final editorFocus = FocusNode();
      addTearDown(editorFocus.dispose);
      await tester.pumpWidget(
        _host(_fence(_longLine), after: TextField(focusNode: editorFocus)),
      );
      await tester.pumpAndSettle();
      final bar = _scrollbars(tester).single;
      final control = _focusControls(tester).single;
      control.focusNode!.requestFocus();
      await tester.pumpAndSettle();
      expect(_scrollbars(tester).single.thumbVisibility, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(bar.controller!.offset, 80);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(bar.controller!.offset, 80);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(bar.controller!.offset, bar.controller!.position.maxScrollExtent);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(bar.controller!.offset, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(control.focusNode!.hasPrimaryFocus, isFalse);
      editorFocus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(bar.controller!.offset, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'code scrollbar preserves independent offsets through Markdown updates and resize',
    (tester) async {
      final text = '${_fence(_longLine)}\n\n${_fence(_longLine)}';
      await tester.pumpWidget(_host(text));
      await tester.pumpAndSettle();
      final first = _scrollbars(tester)[0].controller!;
      final second = _scrollbars(tester)[1].controller!;
      first.jumpTo(100);
      await tester.pumpAndSettle();
      expect(second.offset, 0);
      await tester.pumpWidget(_host('$text\n\nNew streaming text', width: 280));
      await tester.pumpAndSettle();
      expect(identical(_scrollbars(tester)[0].controller, first), isTrue);
      expect(first.offset, 100);
      expect(second.offset, 0);
      await tester.pumpWidget(_host(_fence('short')));
      await tester.pumpAndSettle();
      expect(
        _scrollbars(tester).single.controller!.position.maxScrollExtent,
        0,
      );
      expect(_scrollbars(tester).single.controller!.offset, 0);
      expect(_focusControls(tester).single.canRequestFocus, isFalse);
      expect(_scrollbars(tester).single.thumbVisibility, isFalse);
      final scroll = tester.widget<SingleChildScrollView>(
        find.descendant(
          of: _bars,
          matching: find.byType(SingleChildScrollView),
        ),
      );
      expect(scroll.padding, const EdgeInsets.all(8));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mobile code scrollbar keeps touch and horizontal wheel without trapping chat wheel',
    (tester) async {
      await tester.pumpWidget(
        _host(_fence(_longLine), platform: TargetPlatform.android),
      );
      await tester.pumpAndSettle();
      final bar = _scrollbars(tester).single;
      expect(bar.thumbVisibility, isFalse);
      await tester.dragFrom(tester.getCenter(_bars), const Offset(-100, 0));
      await tester.pumpAndSettle();
      expect(bar.controller!.offset, greaterThan(0));
      final before = bar.controller!.offset;
      final center = tester.getCenter(_bars);
      await tester.sendEventToBinding(
        PointerScrollEvent(position: center, scrollDelta: const Offset(80, 0)),
      );
      await tester.pumpAndSettle();
      expect(bar.controller!.offset, greaterThan(before));
      final horizontal = bar.controller!.offset;
      await tester.sendEventToBinding(
        PointerScrollEvent(position: center, scrollDelta: const Offset(0, 100)),
      );
      await tester.pumpAndSettle();
      expect(bar.controller!.offset, horizontal);
      final vertical = tester.state<ScrollableState>(
        find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(vertical.position.pixels, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('iOS code scrollbar stays in its gutter with safe-area insets', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _fence(_longLine),
        platform: TargetPlatform.iOS,
        padding: const EdgeInsets.fromLTRB(20, 44, 20, 34),
      ),
    );
    await tester.pumpAndSettle();
    expect(MediaQuery.paddingOf(tester.element(_bars)), EdgeInsets.zero);
    final bar = _scrollbars(tester).single;
    await tester.dragFrom(tester.getCenter(_bars), const Offset(-100, 0));
    await tester.pump();
    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: _bars,
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.foregroundPainter is ScrollbarPainter,
        ),
      ),
    );
    expect(
      (paint.foregroundPainter! as ScrollbarPainter).padding,
      EdgeInsets.zero,
    );
    expect(bar.controller!.offset, greaterThan(0));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
  });
}
