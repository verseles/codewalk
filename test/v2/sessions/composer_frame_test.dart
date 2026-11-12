import 'package:codewalk/features/sessions/composer_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A frame like the composers build it: the field's lines follow [open].
Widget _frame({
  required FocusNode field,
  FocusNode? chip,
  String chipLabel = 'Model',
  bool autofocus = false,
}) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: 390,
        child: ComposerFrame(
          attachTooltip: 'Attach',
          voiceTooltip: 'Voice',
          chip: TextButton(
            key: const ValueKey('chip'),
            focusNode: chip,
            onPressed: () {},
            child: Text(chipLabel, maxLines: 1, softWrap: false),
          ),
          field: (context, open) => TextField(
            key: const ValueKey('field'),
            focusNode: field,
            autofocus: autofocus,
            minLines: 1,
            maxLines: open ? 4 : 1,
          ),
          action: IconButton(
            key: const ValueKey('send'),
            onPressed: () {},
            icon: const Icon(Icons.send),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  late FocusNode field;
  late FocusNode chip;

  setUp(() {
    field = FocusNode();
    chip = FocusNode();
  });

  tearDown(() {
    field.dispose();
    chip.dispose();
  });

  int maxLines(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(const ValueKey('field'))).maxLines!;

  testWidgets('a phone composer is one line until it has focus (#484)', (
    tester,
  ) async {
    await tester.pumpWidget(_frame(field: field, chip: chip));
    expect(maxLines(tester), 1);
    // The chip's row stays mounted but hidden.
    expect(find.byKey(const ValueKey('chip')), findsNothing);
    expect(
      find.byKey(const ValueKey('chip'), skipOffstage: false),
      findsOneWidget,
    );
    final closed = tester.getRect(
      find.byKey(const ValueKey('composer-bubble')),
    );
    field.requestFocus();
    await tester.pump();
    expect(maxLines(tester), 4);
    expect(find.byKey(const ValueKey('chip')), findsOneWidget);
    final open = tester.getRect(find.byKey(const ValueKey('composer-bubble')));
    expect(open.height, greaterThan(closed.height));
  });

  testWidgets('a desktop composer is always open', (tester) async {
    await tester.pumpWidget(_frame(field: field, chip: chip));
    expect(field.hasFocus, isFalse);
    expect(maxLines(tester), 4);
    expect(find.byKey(const ValueKey('chip')), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('focus moving to the chip keeps the composer open', (
    tester,
  ) async {
    await tester.pumpWidget(_frame(field: field, chip: chip));
    field.requestFocus();
    await tester.pump();
    chip.requestFocus();
    await tester.pump();
    expect(chip.hasPrimaryFocus, isTrue);
    expect(maxLines(tester), 4);
    expect(find.byKey(const ValueKey('chip')), findsOneWidget);
    // Focus leaving the frame closes it.
    chip.unfocus();
    await tester.pump();
    expect(maxLines(tester), 1);
  });

  testWidgets('a field focused as the frame is built opens it', (tester) async {
    await tester.pumpWidget(_frame(field: field, autofocus: true));
    await tester.pump();
    expect(field.hasPrimaryFocus, isTrue);
    expect(maxLines(tester), 4);
  });

  testWidgets('the chip may use the whole gap and Send keeps to the end', (
    tester,
  ) async {
    await tester.pumpWidget(
      _frame(field: field, chip: chip, chipLabel: 'M' * 80),
    );
    field.requestFocus();
    await tester.pump();
    final bubble = tester.getRect(
      find.byKey(const ValueKey('composer-bubble')),
    );
    final send = tester.getRect(find.byKey(const ValueKey('send')));
    final voice = tester.getRect(find.byKey(const ValueKey('composer-voice')));
    final attach = tester.getRect(
      find.byKey(const ValueKey('composer-attach')),
    );
    final slot = tester.getRect(find.byKey(const ValueKey('composer-chip')));
    // The bubble pads its content by 4.
    expect(send.right, closeTo(bubble.right - 4, 0.5));
    // The chip's slot spans everything between Attach and Voice.
    expect(slot.left, closeTo(attach.right + 4, 0.5));
    expect(slot.right, closeTo(voice.left, 0.5));
    // A short chip leaves the rest of the gap after it, not before Send.
    await tester.pumpWidget(_frame(field: field, chip: chip));
    await tester.pump();
    expect(
      tester.getRect(find.byKey(const ValueKey('send'))).right,
      closeTo(bubble.right - 4, 0.5),
    );
  });
}
