import 'dart:async';
import 'dart:convert';

import 'package:codewalk/shared/voice/speech_dictation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';

const _channel = MethodChannel('plugin.csdcorp.com/speech_to_text');

/// The platform side of the plugin's channel, answered by the test.
class _Recognizer {
  _Recognizer({this.ready = true, this.permitted = true}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call.method);
          if (call.method == 'stop' && failStop) {
            throw PlatformException(code: 'stopFailed');
          }
          if (call.method == 'listen') await starting?.future;
          if (call.method == 'initialize') {
            await initializing?.future;
            if (initializeError case final code?) {
              throw PlatformException(code: code);
            }
          }
          return switch (call.method) {
            'has_permission' => permitted,
            'initialize' => ready,
            'listen' => true,
            _ => null,
          };
        });
  }

  bool ready;
  bool permitted;

  /// When set, initialize waits for it, as a permission prompt does.
  Completer<void>? initializing;

  /// When set, initialize fails with this platform error code.
  String? initializeError;

  /// When set, listen waits for it.
  Completer<void>? starting;

  /// Whether stop fails on the platform side.
  bool failStop = false;
  final calls = <String>[];

  Future<void> send(String method, Object? arguments) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          _channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall(method, arguments),
          ),
          (_) {},
        );
  }

  Future<void> words(String words, {bool done = false}) => send(
    'textRecognition',
    jsonEncode({
      'alternates': [
        {'recognizedWords': words, 'confidence': 0.9},
      ],
      'finalResult': done,
    }),
  );

  Future<void> error(String message, {bool permanent = true}) => send(
    'notifyError',
    jsonEncode({'errorMsg': message, 'permanent': permanent}),
  );
}

/// What one dictation reported.
class _Heard {
  final words = <(String, bool)>[];
  final levels = <double>[];
  final ends = <SpeechDictationEnd>[];

  Future<bool> start(SpeechDictation dictation) => dictation.start(
    onWords: (words, done) => this.words.add((words, done)),
    onLevel: levels.add,
    onEnd: ends.add,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  NativeSpeechDictation fresh() =>
      NativeSpeechDictation(speech: SpeechToText.withMethodChannel());

  test('Android, iOS, macOS and Web have a recognizer; Linux and Windows '
      'do not', () {
    final dictation = fresh();
    for (final (platform, supported) in [
      (TargetPlatform.android, true),
      (TargetPlatform.iOS, true),
      (TargetPlatform.macOS, true),
      (TargetPlatform.linux, false),
      (TargetPlatform.windows, false),
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(dictation.supported, supported, reason: platform.name);
    }
  });

  test('an unsupported platform ends at once, unavailable', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final recognizer = _Recognizer();
    final heard = _Heard();
    expect(await heard.start(fresh()), isFalse);
    expect(heard.ends, [SpeechDictationEnd.unavailable]);
    expect(recognizer.calls, isEmpty);
  });

  test('words, levels and the final words reach the composer', () async {
    final recognizer = _Recognizer();
    final heard = _Heard();
    expect(await heard.start(fresh()), isTrue);
    expect(recognizer.calls, containsAllInOrder(['initialize', 'listen']));
    // The platform says it listens before it reports levels.
    await recognizer.send('notifyStatus', SpeechToText.listeningStatus);
    await recognizer.send('soundLevelChange', 4.5);
    await recognizer.words('hello');
    await recognizer.words('hello world', done: true);
    expect(heard.levels, [4.5]);
    expect(heard.words, [('hello', false), ('hello world', true)]);
    expect(heard.ends, [SpeechDictationEnd.finished]);
    // The recognizer's own end adds nothing.
    await recognizer.send('notifyStatus', SpeechToText.doneStatus);
    expect(heard.ends, hasLength(1));
  });

  test('a refusal and a missing recognizer are told apart', () async {
    final recognizer = _Recognizer(ready: false, permitted: false);
    final denied = _Heard();
    expect(await denied.start(fresh()), isFalse);
    expect(denied.ends, [SpeechDictationEnd.denied]);
    recognizer.permitted = true;
    final missing = _Heard();
    expect(await missing.start(fresh()), isFalse);
    expect(missing.ends, [SpeechDictationEnd.unavailable]);
  });

  test('silence ends quietly; a lasting failure says so', () async {
    final recognizer = _Recognizer();
    final dictation = fresh();
    final quiet = _Heard();
    await quiet.start(dictation);
    await recognizer.error('error_no_match');
    expect(quiet.ends, [SpeechDictationEnd.finished]);
    final broken = _Heard();
    await broken.start(dictation);
    await recognizer.error('error_audio_error');
    expect(broken.ends, [SpeechDictationEnd.failed]);
    final refused = _Heard();
    await refused.start(dictation);
    await recognizer.error('error_insufficient_permissions');
    expect(refused.ends, [SpeechDictationEnd.denied]);
  });

  test('a device without a recognizer is unavailable', () async {
    final recognizer = _Recognizer()
      ..initializeError = 'recognizerNotAvailable';
    final heard = _Heard();
    expect(await heard.start(fresh()), isFalse);
    expect(heard.ends, [SpeechDictationEnd.unavailable]);
    recognizer.initializeError = 'missingContext';
    final broken = _Heard();
    expect(await broken.start(fresh()), isFalse);
    expect(broken.ends, [SpeechDictationEnd.failed]);
  });

  test('a stop while the microphone is asked for never listens', () async {
    final recognizer = _Recognizer()..initializing = Completer<void>();
    final dictation = fresh();
    final heard = _Heard();
    final started = heard.start(dictation);
    await dictation.stop();
    expect(heard.ends, [SpeechDictationEnd.finished]);
    recognizer.initializing!.complete();
    expect(await started, isFalse);
    expect(recognizer.calls, isNot(contains('listen')));
  });

  test('browser errors: refusal, no API, silence and failures', () async {
    final recognizer = _Recognizer();
    final dictation = fresh();
    for (final (message, end) in [
      ('not-allowed', SpeechDictationEnd.denied),
      ('service-not-allowed', SpeechDictationEnd.denied),
      ('not supported', SpeechDictationEnd.unavailable),
      ('no-speech', SpeechDictationEnd.finished),
      ('network', SpeechDictationEnd.failed),
    ]) {
      final heard = _Heard();
      await heard.start(dictation);
      recognizer.calls.clear();
      await recognizer.error(message, permanent: false);
      expect(heard.ends, [end], reason: message);
      // A passing error leaves the recognizer running; it is stopped here.
      expect(recognizer.calls, contains('cancel'), reason: message);
    }
  });

  testWidgets('done waits for an error posted after it', (tester) async {
    final recognizer = _Recognizer();
    final heard = _Heard();
    await heard.start(fresh());
    await recognizer.send('notifyStatus', SpeechToText.listeningStatus);
    // Android sends the status first and posts the error after it.
    await recognizer.send('notifyStatus', SpeechToText.notListeningStatus);
    await recognizer.send('notifyStatus', 'doneNoResult');
    expect(heard.ends, isEmpty);
    await recognizer.error('error_audio_error');
    expect(heard.ends, [SpeechDictationEnd.failed]);
  });

  testWidgets('a recognizer that only stops capturing still ends', (
    tester,
  ) async {
    final recognizer = _Recognizer();
    final heard = _Heard();
    await heard.start(fresh());
    await recognizer.send('notifyStatus', SpeechToText.listeningStatus);
    await recognizer.words('almost');
    await recognizer.send('notifyStatus', SpeechToText.notListeningStatus);
    await tester.pump(const Duration(seconds: 2));
    expect(heard.ends, isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(heard.ends, [SpeechDictationEnd.finished]);
    expect(heard.words.last, ('almost', false));
  });

  testWidgets('a stop keeps its wait for final words sent after done', (
    tester,
  ) async {
    final recognizer = _Recognizer();
    final dictation = fresh();
    final heard = _Heard();
    await heard.start(dictation);
    await recognizer.send('notifyStatus', SpeechToText.listeningStatus);
    await dictation.stop();
    // Android reports the end before the final words of a stop.
    await recognizer.send('notifyStatus', SpeechToText.notListeningStatus);
    await recognizer.send('notifyStatus', 'doneNoResult');
    await tester.pump(const Duration(seconds: 1));
    expect(heard.ends, isEmpty);
    await recognizer.words('late but kept', done: true);
    expect(heard.words.last, ('late but kept', true));
    expect(heard.ends, [SpeechDictationEnd.finished]);
  });

  testWidgets('a stop after done still owns the full wait', (tester) async {
    final recognizer = _Recognizer();
    final dictation = fresh();
    final heard = _Heard();
    await heard.start(dictation);
    await recognizer.send('notifyStatus', SpeechToText.listeningStatus);
    await recognizer.send('notifyStatus', 'doneNoResult');
    await dictation.stop();
    await tester.pump(const Duration(seconds: 1));
    expect(heard.ends, isEmpty);
    await recognizer.words('kept', done: true);
    expect(heard.ends, [SpeechDictationEnd.finished]);
    expect(heard.words.last, ('kept', true));
  });

  testWidgets('done never cuts short a wait already pending', (tester) async {
    final recognizer = _Recognizer();
    final heard = _Heard();
    await heard.start(fresh());
    await recognizer.send('notifyStatus', SpeechToText.listeningStatus);
    await recognizer.send('notifyStatus', SpeechToText.notListeningStatus);
    await recognizer.send('notifyStatus', 'doneNoResult');
    await tester.pump(const Duration(seconds: 1));
    expect(heard.ends, isEmpty);
    await recognizer.words('still here', done: true);
    expect(heard.words.last, ('still here', true));
    expect(heard.ends, [SpeechDictationEnd.finished]);
    // Nothing reaches an ended session.
    await recognizer.words('after the end', done: true);
    expect(heard.words, hasLength(1));
  });

  testWidgets('a wait that runs out during a pending listen leaves no '
      'recognizer', (tester) async {
    final recognizer = _Recognizer()..starting = Completer<void>();
    final dictation = fresh();
    final heard = _Heard();
    final started = heard.start(dictation);
    await tester.pump();
    expect(recognizer.calls, contains('listen'));
    await dictation.stop();
    await tester.pump(NativeSpeechDictation.finalGrace);
    expect(heard.ends, [SpeechDictationEnd.finished]);
    recognizer.calls.clear();
    recognizer.starting!.complete();
    expect(await started, isFalse);
    expect(recognizer.calls, contains('cancel'));
  });

  testWidgets('a failed platform stop still ends and stops the recognizer', (
    tester,
  ) async {
    final recognizer = _Recognizer()..failStop = true;
    final dictation = fresh();
    final heard = _Heard();
    await heard.start(dictation);
    await dictation.stop();
    expect(heard.ends, isEmpty);
    recognizer.calls.clear();
    await tester.pump(NativeSpeechDictation.finalGrace);
    expect(heard.ends, [SpeechDictationEnd.finished]);
    // The wait ran out: the recognizer is stopped too.
    expect(recognizer.calls, contains('cancel'));
  });

  test(
    'a session cancelled while listening starts leaves no recognizer',
    () async {
      final recognizer = _Recognizer()..starting = Completer<void>();
      final dictation = fresh();
      final heard = _Heard();
      final started = heard.start(dictation);
      await pumpEventQueue();
      expect(recognizer.calls, contains('listen'));
      await dictation.cancel();
      recognizer.starting!.complete();
      expect(await started, isFalse);
      expect(recognizer.calls.where((call) => call == 'cancel'), isNotEmpty);
      expect(heard.ends, [SpeechDictationEnd.finished]);
    },
  );

  test('a passing error after the end still stops the recognizer', () async {
    final recognizer = _Recognizer();
    final dictation = fresh();
    final heard = _Heard();
    await heard.start(dictation);
    await recognizer.words('done', done: true);
    expect(heard.ends, [SpeechDictationEnd.finished]);
    recognizer.calls.clear();
    await recognizer.error('network', permanent: false);
    expect(recognizer.calls, contains('cancel'));
    expect(heard.ends, hasLength(1));
  });

  testWidgets('stop waits for the final words, then ends', (tester) async {
    final recognizer = _Recognizer();
    final dictation = fresh();
    final heard = _Heard();
    await heard.start(dictation);
    await dictation.stop();
    expect(recognizer.calls, contains('stop'));
    expect(heard.ends, isEmpty);
    await tester.pump(const Duration(seconds: 3));
    expect(heard.ends, [SpeechDictationEnd.finished]);
  });

  test('cancel ends at once and drops what follows', () async {
    final recognizer = _Recognizer();
    final dictation = fresh();
    final heard = _Heard();
    await heard.start(dictation);
    await dictation.cancel();
    expect(recognizer.calls, contains('cancel'));
    expect(heard.ends, [SpeechDictationEnd.finished]);
    await recognizer.words('late', done: true);
    expect(heard.words, isEmpty);
    // A new session replaces the old one's callbacks.
    final next = _Heard();
    await next.start(dictation);
    await recognizer.words('next');
    expect(next.words, [('next', false)]);
    expect(heard.words, isEmpty);
  });
}
