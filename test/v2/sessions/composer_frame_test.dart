import 'package:codewalk/features/sessions/composer_input.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A frame like the composers build it: the field's lines follow [open].
Widget _frame({
  required FocusNode field,
  FocusNode? chip,
  String chipLabel = 'Model',
  bool autofocus = false,
  bool voiceTakesAction = false,
  bool listening = false,
  Widget? voice,
  TextDirection direction = TextDirection.ltr,
  bool reducedMotion = false,
}) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: 390,
        child: ComposerFrame(
          attachTooltip: 'Attach',
          voiceTooltip: 'Voice',
          voice: voice,
          voiceTakesAction: voiceTakesAction,
          listening: listening,
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
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
    child: Directionality(textDirection: direction, child: child!),
  ),
);

/// A mic that counts its builds' State, to prove a move keeps it.
class _Mic extends StatefulWidget {
  const _Mic({super.key});

  @override
  State<_Mic> createState() => _MicState();
}

class _MicState extends State<_Mic> {
  @override
  Widget build(BuildContext context) => SizedBox.square(
    key: const ValueKey('mic'),
    dimension: composerActionSize,
    child: IconButton(onPressed: () {}, icon: const Icon(Icons.mic)),
  );
}

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

  testWidgets('a dictation opens a phone composer, keyboard closed (#546)', (
    tester,
  ) async {
    await tester.pumpWidget(_frame(field: field, chip: chip));
    expect(maxLines(tester), 1);
    await tester.pumpWidget(_frame(field: field, chip: chip, listening: true));
    expect(maxLines(tester), 4);
    expect(find.byKey(const ValueKey('chip')), findsOneWidget);
    // No focus, so no keyboard.
    expect(field.hasFocus, isFalse);
    await tester.pumpWidget(_frame(field: field, chip: chip));
    expect(maxLines(tester), 1);
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

  group('the mic takes an idle Send\'s place (#501)', () {
    const micKey = GlobalObjectKey('test mic');
    Rect rect(WidgetTester tester, String key) =>
        tester.getRect(find.byKey(ValueKey(key)));

    testWidgets('it slides into the end slot and back, keeping its state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _frame(
          field: field,
          voice: const _Mic(key: micKey),
        ),
      );
      final send = rect(tester, 'send');
      final beside = rect(tester, 'mic');
      expect(beside.right, closeTo(send.left - 4, 0.5));
      final state = micKey.currentState;
      final fieldWidth = tester.getSize(find.byKey(const ValueKey('field')));

      await tester.pumpWidget(
        _frame(
          field: field,
          voice: const _Mic(key: micKey),
          voiceTakesAction: true,
        ),
      );
      // It waits a moment first, in case work starts (#545).
      await tester.pump(ComposerFrame.voiceTakeDelay ~/ 2);
      expect(rect(tester, 'mic'), beside);
      await tester.pump(ComposerFrame.voiceTakeDelay ~/ 2);
      // Halfway through, the mic is between its place and Send's.
      await tester.pump(ComposerFrame.voiceSlide ~/ 2);
      final moving = rect(tester, 'mic');
      expect(moving.left, greaterThan(beside.left));
      expect(moving.left, lessThan(send.left));
      await tester.pumpAndSettle();
      expect(rect(tester, 'mic'), send);
      expect(micKey.currentState, same(state));
      // The field takes the room the pair left.
      expect(
        tester.getSize(find.byKey(const ValueKey('field'))).width,
        greaterThan(fieldWidth.width),
      );
      // Send is neither tapped, read nor focused while the mic stands there.
      expect(find.byKey(const ValueKey('send')).hitTestable(), findsNothing);
      expect(
        find.descendant(
          of: find.byType(ExcludeSemantics),
          matching: find.byKey(const ValueKey('send')),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ExcludeSemantics>(
              find
                  .ancestor(
                    of: find.byKey(const ValueKey('send')),
                    matching: find.byType(ExcludeSemantics),
                  )
                  .first,
            )
            .excluding,
        isTrue,
      );

      await tester.pumpWidget(
        _frame(
          field: field,
          voice: const _Mic(key: micKey),
        ),
      );
      await tester.pumpAndSettle();
      expect(rect(tester, 'mic'), beside);
      expect(rect(tester, 'send'), send);
      expect(micKey.currentState, same(state));
      expect(find.byKey(const ValueKey('send')).hitTestable(), findsOneWidget);
    });

    testWidgets('it moves at once with reduced motion', (tester) async {
      await tester.pumpWidget(
        _frame(
          field: field,
          voice: const _Mic(key: micKey),
        ),
      );
      final send = rect(tester, 'send');
      await tester.pumpWidget(
        _frame(
          field: field,
          voice: const _Mic(key: micKey),
          voiceTakesAction: true,
          reducedMotion: true,
        ),
      );
      await tester.pump(ComposerFrame.voiceTakeDelay);
      await tester.pump();
      expect(rect(tester, 'mic'), send);
    });

    testWidgets('a send whose work starts at once never moves it (#545)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _frame(
          field: field,
          voice: const _Mic(key: micKey),
        ),
      );
      final beside = rect(tester, 'mic');
      await tester.pumpWidget(
        _frame(
          field: field,
          voice: const _Mic(key: micKey),
          voiceTakesAction: true,
        ),
      );
      await tester.pump(ComposerFrame.voiceTakeDelay ~/ 2);
      // Stop appears: the mic stays where it was.
      await tester.pumpWidget(
        _frame(
          field: field,
          voice: const _Mic(key: micKey),
        ),
      );
      await tester.pumpAndSettle();
      expect(rect(tester, 'mic'), beside);
    });

    testWidgets('it keeps to the end edge right to left', (tester) async {
      await tester.pumpWidget(
        _frame(
          field: field,
          voice: const _Mic(key: micKey),
          voiceTakesAction: true,
          direction: TextDirection.rtl,
        ),
      );
      await tester.pumpAndSettle();
      final bubble = rect(tester, 'composer-bubble');
      expect(rect(tester, 'mic').left, closeTo(bubble.left + 4, 0.5));
    });

    testWidgets('it moves with the open row and back', (tester) async {
      await tester.pumpWidget(
        _frame(
          field: field,
          chip: chip,
          voice: const _Mic(key: micKey),
          voiceTakesAction: true,
        ),
      );
      await tester.pumpAndSettle();
      final state = micKey.currentState;
      field.requestFocus();
      await tester.pump();
      final bubble = rect(tester, 'composer-bubble');
      expect(rect(tester, 'mic').right, closeTo(bubble.right - 4, 0.5));
      expect(micKey.currentState, same(state));
    });
  });
}
