import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Why a dictation ended.
enum SpeechDictationEnd {
  /// The recognizer stopped on its own (a pause, its time limit) or was
  /// stopped; the last words are final.
  finished,

  /// The microphone or speech recognition was not allowed.
  denied,

  /// The device offers no speech recognition CodeWalk can use.
  unavailable,

  /// The recognizer failed while listening.
  failed,
}

/// Dictation into the composer through the platform's own speech recognizer
/// (#307, native slice). CodeWalk keeps the audio to the platform's service
/// and sends nothing to a harness, so no capability gates it; the platform
/// itself may recognize on a vendor's servers.
abstract class SpeechDictation {
  /// Whether this platform has a native recognizer CodeWalk uses: Android,
  /// iOS, macOS and Web. Linux has none, and native Windows recognition
  /// stays off as in v1, for stability.
  bool get supported;

  /// Starts listening. [onWords] gets the words heard so far, replacing
  /// the previous call's, with `done` on the final ones; [onLevel] gets the
  /// input level in decibels as the platform reports it; [onEnd] is called
  /// once when the session ends for any reason. Returns false when it could
  /// not start, after calling [onEnd] with the reason.
  Future<bool> start({
    required void Function(String words, bool done) onWords,
    required void Function(double level) onLevel,
    required void Function(SpeechDictationEnd end) onEnd,
  });

  /// Stops listening and keeps what was heard.
  Future<void> stop();

  /// Stops listening without waiting for the final words.
  Future<void> cancel();
}

/// [SpeechDictation] over the `speech_to_text` plugin.
class NativeSpeechDictation implements SpeechDictation {
  NativeSpeechDictation({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  _Session? _session;

  /// How long a stop, or a recognizer that stopped capturing, waits for the
  /// final words (the plugin turns the last partial ones final after two
  /// seconds) before the session ends anyway.
  static const finalGrace = Duration(seconds: 3);

  /// How long a `done` with nothing else pending waits for an error posted
  /// after it. Android and the browser report `notListening` first, whose
  /// longer wait then stands; this one covers a `done` alone, such as the
  /// browser's no-match.
  static const doneGrace = Duration(milliseconds: 500);

  @override
  bool get supported =>
      kIsWeb ||
      const {
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      }.contains(defaultTargetPlatform);

  @override
  Future<bool> start({
    required void Function(String words, bool done) onWords,
    required void Function(double level) onLevel,
    required void Function(SpeechDictationEnd end) onEnd,
  }) async {
    _session?.end(SpeechDictationEnd.finished);
    late final _Session session;
    session = _session = _Session(
      onWords,
      onLevel,
      (end) {
        // An ended session holds nothing here, so late callbacks find none.
        if (identical(_session, session)) _session = null;
        onEnd(end);
      },
      // A session that runs out its grace leaves no recognizer behind,
      // unless a newer session already owns it.
      onExpired: () {
        if (identical(_session, session)) unawaited(_quietly(_speech.cancel));
      },
    );
    if (!supported) {
      session.end(SpeechDictationEnd.unavailable);
      return false;
    }
    final bool ready;
    try {
      // The first call asks for the microphone; a refusal, or no recognizer,
      // leaves it false, and a later tap asks again. Headset routing is not
      // part of this slice, so only the microphone is asked for.
      ready = await _speech.initialize(
        onError: _error,
        onStatus: _status,
        options: [SpeechToText.androidNoBluetooth],
      );
    } on PlatformException catch (error) {
      session.end(
        error.code == 'recognizerNotAvailable'
            ? SpeechDictationEnd.unavailable
            : SpeechDictationEnd.failed,
      );
      return false;
    } on Object {
      session.end(SpeechDictationEnd.failed);
      return false;
    }
    // A stop while the permission was asked ends the session before it
    // listens.
    if (!identical(_session, session) || session.ended) return false;
    if (!ready) {
      session.end(
        await _speech.hasPermission
            ? SpeechDictationEnd.unavailable
            : SpeechDictationEnd.denied,
      );
      return false;
    }
    session.listening = true;
    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          if (!identical(_session, session) || session.ended) return;
          session.onWords(result.recognizedWords, result.finalResult);
          if (result.finalResult) session.end(SpeechDictationEnd.finished);
        },
        onSoundLevelChange: (double level) {
          if (identical(_session, session) && !session.ended) {
            session.onLevel(level);
          }
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
        ),
      );
    } on Object {
      session.end(SpeechDictationEnd.failed);
      return false;
    }
    if (!session.ended) return true;
    // Ended (stopped, cancelled, run out) while listening was being set up:
    // the recognizer it started has no session to report to, unless a newer
    // session already owns it.
    if (_session == null || identical(_session, session)) {
      await _quietly(_speech.cancel);
    }
    return false;
  }

  /// Runs a plugin call whose failure changes nothing here: the session has
  /// already ended or holds its own fallback.
  static Future<void> _quietly(Future<void> Function() call) async {
    try {
      await call();
    } on Object {
      // Nothing more to stop.
    }
  }

  void _status(String status) {
    final session = _session;
    // A stop keeps its own wait for the final words, which Android may send
    // after `done`.
    if (session == null || session.ended || session.stopRequested) return;
    // Each arms a wait only when none is pending, so neither cuts short the
    // other's wait for words the platform still sends.
    if (status == SpeechToText.doneStatus) {
      // `done` follows the final words, or comes with none; an error the
      // platform posts after it still names the reason.
      session.endAfter(doneGrace);
    } else if (status == SpeechToText.notListeningStatus) {
      // Capture ended: the final words or `done` should follow; the session
      // ends anyway if neither does.
      session.endAfter(finalGrace);
    }
  }

  void _error(SpeechRecognitionError error) {
    // A permanent error stops the recognizer itself (`cancelOnError`); after
    // any other, it is stopped here, so it cannot reach the next session.
    // The plugin does not say which session an error belongs to: one that
    // comes while a session lives is that session's.
    final session = _session;
    if (session == null || session.ended) {
      if (!error.permanent) unawaited(_quietly(_speech.cancel));
      return;
    }
    final end = switch (error.errorMsg) {
      // Nothing said, nothing understood, or a stop: a quiet end.
      'error_no_match' ||
      'error_speech_timeout' ||
      'no-speech' ||
      'aborted' => SpeechDictationEnd.finished,
      // Android's and the browser's refusals of the microphone or service.
      'error_permission' ||
      'error_insufficient_permissions' ||
      'not-allowed' ||
      'service-not-allowed' => SpeechDictationEnd.denied,
      // The browser has no Web Speech API.
      'not supported' ||
      'speech_not_supported' => SpeechDictationEnd.unavailable,
      _ => SpeechDictationEnd.failed,
    };
    session.end(end);
    if (!error.permanent) unawaited(_quietly(_speech.cancel));
  }

  @override
  Future<void> stop() async {
    final session = _session;
    if (session == null || session.ended) return;
    session.stopRequested = true;
    if (!session.listening) {
      // Still asking for the microphone: nothing to wait for.
      session.end(SpeechDictationEnd.finished);
      return;
    }
    // The stop owns the full wait, whatever was pending, and arms it first,
    // so a stop the plugin fails still ends.
    session.endAfter(finalGrace, replace: true);
    await _quietly(_speech.stop);
  }

  @override
  Future<void> cancel() async {
    final session = _session;
    _session = null;
    if (session == null || session.ended) return;
    session.end(SpeechDictationEnd.finished);
    if (session.listening) await _quietly(_speech.cancel);
  }
}

class _Session {
  _Session(this.onWords, this.onLevel, this._onEnd, {required this.onExpired});

  final void Function(String words, bool done) onWords;
  final void Function(double level) onLevel;
  final void Function(SpeechDictationEnd end) _onEnd;

  /// Called when a grace runs out, before the session ends.
  final void Function() onExpired;
  bool ended = false;

  /// Whether the user asked it to stop.
  bool stopRequested = false;

  /// Whether listening was asked of the recognizer.
  bool listening = false;
  Timer? _grace;

  /// Ends the session after [delay], unless it ends sooner. A pending wait
  /// stays, unless [replace] drops it.
  void endAfter(Duration delay, {bool replace = false}) {
    if (ended) return;
    if (!replace && (_grace?.isActive ?? false)) return;
    _grace?.cancel();
    _grace = Timer(delay, () {
      onExpired();
      end(SpeechDictationEnd.finished);
    });
  }

  void end(SpeechDictationEnd end) {
    if (ended) return;
    ended = true;
    _grace?.cancel();
    _onEnd(end);
  }
}
