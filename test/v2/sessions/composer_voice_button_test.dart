import 'dart:async';

import 'package:codewalk/features/sessions/composer_input.dart';
import 'package:codewalk/features/sessions/composer_voice_button.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/voice/speech_dictation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A recognizer the test speaks through.
class FakeDictation implements SpeechDictation {
  FakeDictation({this.supported = true, this.startsWith});

  @override
  final bool supported;

  /// When set, the next start ends at once with this reason.
  SpeechDictationEnd? startsWith;

  int starts = 0;
  int stops = 0;
  int cancels = 0;
  void Function(String words, bool done)? words;
  void Function(double level)? level;
  void Function(SpeechDictationEnd end)? end;

  @override
  Future<bool> start({
    required void Function(String words, bool done) onWords,
    required void Function(double level) onLevel,
    required void Function(SpeechDictationEnd end) onEnd,
  }) async {
    starts++;
    words = onWords;
    level = onLevel;
    end = onEnd;
    if (startsWith case final reason?) {
      onEnd(reason);
      return false;
    }
    return true;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> cancel() async {
    cancels++;
    end?.call(SpeechDictationEnd.finished);
  }
}

final _mic = find.byKey(const ValueKey('composer-voice-button'));
final _ball = find.byKey(const ValueKey('composer-voice-ball'));

/// The scales the ball and its halo are drawn at, halo first.
List<double> _scales(WidgetTester tester) => [
  for (final transform in tester.widgetList<Transform>(
    find.descendant(of: _ball, matching: find.byType(Transform)),
  ))
    transform.transform.entry(0, 0),
];

Future<TextEditingController> _pump(
  WidgetTester tester,
  SpeechDictation? dictation, {
  String text = '',
  bool still = false,
  ValueNotifier<bool>? enabled,
  GlobalKey<ComposerVoiceButtonState>? key,
}) async {
  final controller = TextEditingController(text: text);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    Provider<SpeechDictation?>.value(
      value: dictation,
      child: MaterialApp(
        localizationsDelegates: V2Localizations.localizationsDelegates,
        supportedLocales: V2Localizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: still),
          child: Scaffold(
            body: Center(
              child: Row(
                children: [
                  Expanded(child: TextField(controller: controller)),
                  ValueListenableBuilder<bool>(
                    valueListenable: enabled ?? ValueNotifier(true),
                    builder: (context, on, _) => ComposerVoiceButton(
                      key: key,
                      text: controller,
                      enabled: on,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return controller;
}

Future<void> _clearMessages(WidgetTester tester) async {
  tester
      .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
      .clearSnackBars();
  await tester.pumpAndSettle();
}

String _tooltip(WidgetTester tester) =>
    tester.widget<IconButton>(_mic).tooltip!;

void main() {
  late V2Localizations l10n;
  setUpAll(() async {
    l10n = await V2Localizations.delegate.load(const Locale('en'));
  });

  testWidgets('a platform without a recognizer keeps the mic off', (
    tester,
  ) async {
    await _pump(tester, FakeDictation(supported: false));
    expect(tester.widget<IconButton>(_mic).onPressed, isNull);
    expect(_tooltip(tester), l10n.composerVoiceUnavailable);
    await _pump(tester, null);
    expect(tester.widget<IconButton>(_mic).onPressed, isNull);
  });

  testWidgets('a tap dictates at the cursor and a second tap stops', (
    tester,
  ) async {
    final dictation = FakeDictation();
    final text = await _pump(tester, dictation, text: 'Fix thetests');
    text.selection = const TextSelection.collapsed(offset: 7);
    expect(_tooltip(tester), l10n.composerVoice);
    expect(_ball, findsNothing);
    await tester.tap(_mic);
    await tester.pump();
    expect(dictation.starts, 1);
    expect(_ball, findsOneWidget);
    expect(_tooltip(tester), l10n.composerVoiceStop);
    // Each result takes the previous one's place, spaced from its sides.
    dictation.words!('in', false);
    await tester.pump();
    expect(text.text, 'Fix the in tests');
    dictation.words!('in all', false);
    await tester.pump();
    expect(text.text, 'Fix the in all tests');
    expect(text.selection, const TextSelection.collapsed(offset: 14));
    await tester.tap(_mic);
    await tester.pump();
    expect(dictation.stops, 1);
    // Stopping: the ball holds still and the mic waits for the final words,
    // no longer offering to stop.
    expect(tester.widget<IconButton>(_mic).onPressed, isNull);
    expect(_tooltip(tester), l10n.composerVoice);
    final held = _scales(tester);
    await tester.pump(ComposerVoiceButton.breath ~/ 2);
    expect(_scales(tester), held);
    dictation.words!('in all of', true);
    dictation.end!(SpeechDictationEnd.finished);
    await tester.pump();
    expect(text.text, 'Fix the in all of tests');
    expect(_ball, findsNothing);
    expect(_tooltip(tester), l10n.composerVoice);
    // Words after the end never land.
    dictation.words!('late', true);
    await tester.pump();
    expect(text.text, 'Fix the in all of tests');
  });

  testWidgets('while listening the mic turns white and filled on red', (
    tester,
  ) async {
    final dictation = FakeDictation();
    await _pump(tester, dictation);
    final scheme = Theme.of(tester.element(_mic)).colorScheme;
    Icon icon() => tester.widget<Icon>(
      find.descendant(of: _mic, matching: find.byType(Icon)),
    );
    expect(icon().fill, isNot(1));
    expect(icon().color, isNot(scheme.onError));
    await tester.tap(_mic);
    await tester.pump();
    expect(icon().fill, 1);
    expect(icon().color, scheme.onError);
    final ball = tester.widgetList<DecoratedBox>(
      find.descendant(of: _ball, matching: find.byType(DecoratedBox)),
    );
    expect([
      for (final box in ball) (box.decoration as BoxDecoration).color,
    ], contains(scheme.error));
    dictation.end!(SpeechDictationEnd.finished);
    await tester.pump();
    expect(icon().fill, isNot(1));
  });

  testWidgets('a paused mic still names itself and a pause ends a dictation', (
    tester,
  ) async {
    final dictation = FakeDictation();
    final enabled = ValueNotifier(true);
    addTearDown(enabled.dispose);
    final text = await _pump(tester, dictation, enabled: enabled);
    await tester.tap(_mic);
    await tester.pump();
    dictation.words!('half', false);
    await tester.pump();
    // A send or the server going offline locks the field.
    enabled.value = false;
    await tester.pump();
    expect(dictation.cancels, 1);
    expect(_ball, findsNothing);
    expect(tester.widget<IconButton>(_mic).onPressed, isNull);
    expect(_tooltip(tester), l10n.composerVoice);
    dictation.words!('half done', true);
    await tester.pump();
    expect(text.text, 'half');
  });

  testWidgets('a composer cancels before it reads the field to send', (
    tester,
  ) async {
    final dictation = FakeDictation();
    final key = GlobalKey<ComposerVoiceButtonState>();
    final text = await _pump(tester, dictation, key: key);
    await tester.tap(_mic);
    await tester.pump();
    dictation.words!('send this', false);
    key.currentState!.cancel();
    dictation.words!('send this and more', true);
    await tester.pump();
    expect(text.text, 'send this');
    expect(_ball, findsNothing);
  });

  testWidgets('a level that is not a number moves nothing', (tester) async {
    final dictation = FakeDictation();
    await _pump(tester, dictation);
    await tester.tap(_mic);
    await tester.pump();
    dictation.level!(double.negativeInfinity);
    dictation.level!(double.nan);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(_scales(tester).every((scale) => scale.isFinite), isTrue);
    dictation.end!(SpeechDictationEnd.finished);
    await tester.pump();
  });

  testWidgets('the ball breathes in silence and swells with the voice', (
    tester,
  ) async {
    final dictation = FakeDictation();
    await _pump(tester, dictation);
    await tester.tap(_mic);
    await tester.pump();
    final rest = _scales(tester);
    await tester.pump(ComposerVoiceButton.breath ~/ 2);
    final breath = _scales(tester);
    // A slow breath, no voice: the ball and halo grow a little.
    expect(breath[0], greaterThan(rest[0]));
    expect(breath[1], greaterThan(rest[1]));
    expect(breath[0] - rest[0], lessThan(0.1));
    // A voice well above the room's quiet swells the halo much more.
    dictation.level!(-2);
    dictation.level!(-2);
    dictation.level!(9);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final voiced = _scales(tester);
    expect(voiced[0], greaterThan(breath[0] + 0.2));
    // Silence lets it settle back.
    dictation.level!(-2);
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(_scales(tester)[0], lessThan(voiced[0] - 0.2));
    dictation.end!(SpeechDictationEnd.finished);
    await tester.pump();
  });

  testWidgets('with reduced motion the ball holds still', (tester) async {
    final dictation = FakeDictation();
    await _pump(tester, dictation, still: true);
    await tester.tap(_mic);
    await tester.pump();
    final first = _scales(tester);
    dictation.level!(-2);
    dictation.level!(9);
    await tester.pump(ComposerVoiceButton.breath);
    expect(_scales(tester), first);
    dictation.end!(SpeechDictationEnd.finished);
    await tester.pump();
  });

  testWidgets('typing while listening stops it and keeps the text', (
    tester,
  ) async {
    final dictation = FakeDictation();
    final text = await _pump(tester, dictation);
    await tester.tap(_mic);
    await tester.pump();
    dictation.words!('hello', false);
    await tester.pump();
    text.text = 'hello there';
    await tester.pump();
    expect(dictation.cancels, 1);
    expect(_ball, findsNothing);
    dictation.words!('hello world', true);
    await tester.pump();
    expect(text.text, 'hello there');
  });

  testWidgets('a refusal and a missing recognizer say why', (tester) async {
    final dictation = FakeDictation(startsWith: SpeechDictationEnd.denied);
    await _pump(tester, dictation);
    await tester.tap(_mic);
    await tester.pump();
    expect(find.text(l10n.composerVoiceDenied), findsOneWidget);
    // A refusal may be lifted, so the mic stays on.
    expect(tester.widget<IconButton>(_mic).onPressed, isNotNull);
    await _clearMessages(tester);

    dictation.startsWith = SpeechDictationEnd.failed;
    await tester.tap(_mic);
    await tester.pump();
    expect(find.text(l10n.composerVoiceFailed), findsOneWidget);
    await _clearMessages(tester);

    dictation.startsWith = SpeechDictationEnd.unavailable;
    await tester.tap(_mic);
    await tester.pump();
    expect(find.text(l10n.composerVoiceUnavailable), findsOneWidget);
    // No recognizer will appear: the mic turns off and says why.
    expect(tester.widget<IconButton>(_mic).onPressed, isNull);
    expect(_tooltip(tester), l10n.composerVoiceUnavailable);
    await _clearMessages(tester);
  });

  testWidgets('a dictation goes on while the composer opens', (tester) async {
    final dictation = FakeDictation();
    final text = TextEditingController();
    addTearDown(text.dispose);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      Provider<SpeechDictation?>.value(
        value: dictation,
        child: MaterialApp(
          localizationsDelegates: V2Localizations.localizationsDelegates,
          supportedLocales: V2Localizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: ComposerFrame(
                attachTooltip: 'Attach',
                voiceTooltip: 'Voice',
                voice: ComposerVoiceButton(text: text),
                action: const SizedBox.square(dimension: 42),
                field: (context, open) =>
                    TextField(controller: text, focusNode: focus),
              ),
            ),
          ),
        ),
      ),
    );
    // Closed on a phone, the mic sits in the first row.
    await tester.tap(_mic);
    await tester.pump();
    expect(_ball, findsOneWidget);
    // Opening moves it to the second row; it keeps listening.
    focus.requestFocus();
    await tester.pump();
    expect(_ball, findsOneWidget);
    expect(dictation.cancels, 0);
    dictation.words!('still here', false);
    await tester.pump();
    expect(text.text, 'still here');
    dictation.end!(SpeechDictationEnd.finished);
    await tester.pump();
  });

  testWidgets('a page over the composer ends the dictation', (tester) async {
    final dictation = FakeDictation();
    final text = await _pump(tester, dictation);
    await tester.tap(_mic);
    await tester.pump();
    dictation.words!('before', false);
    await tester.pump();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold())),
    );
    await tester.pumpAndSettle();
    dictation.words!('before and hidden', false);
    await tester.pump();
    expect(dictation.cancels, 1);
    expect(text.text, 'before');
  });

  testWidgets('a sheet on the root navigator over the shell ends it', (
    tester,
  ) async {
    final dictation = FakeDictation();
    final text = TextEditingController();
    addTearDown(text.dispose);
    late BuildContext inner;
    await tester.pumpWidget(
      Provider<SpeechDictation?>.value(
        value: dictation,
        child: MaterialApp(
          localizationsDelegates: V2Localizations.localizationsDelegates,
          supportedLocales: V2Localizations.supportedLocales,
          // A shell navigator inside the root one, as the app's router has.
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (context) {
                inner = context;
                return Scaffold(body: ComposerVoiceButton(text: text));
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(_mic);
    await tester.pump();
    dictation.words!('seen', false);
    await tester.pump();
    expect(text.text, 'seen');
    unawaited(
      showModalBottomSheet<void>(
        context: inner,
        useRootNavigator: true,
        builder: (_) => const SizedBox(height: 200),
      ),
    );
    // The ball keeps breathing behind the sheet, so nothing settles.
    await tester.pump(const Duration(seconds: 1));
    dictation.words!('seen and hidden', false);
    await tester.pump();
    expect(dictation.cancels, 1);
    expect(text.text, 'seen');
  });

  testWidgets('leaving the screen cancels a dictation', (tester) async {
    final dictation = FakeDictation();
    await _pump(tester, dictation);
    await tester.tap(_mic);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(dictation.cancels, 1);
  });
}
