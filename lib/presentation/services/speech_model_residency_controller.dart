import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/logging/app_logger.dart';
import 'speech_input_service.dart';

/// Serializes native model ownership, including startup and final decoding.
/// A session token belongs to its caller, not to the singleton backend.
class SpeechModelResidencyController with WidgetsBindingObserver {
  static final instance = SpeechModelResidencyController();

  Future<void> _tail = Future<void>.value();
  ResidentSpeechInputService? _resident;
  Object? _session;
  bool _keepInMemory = true;
  bool _evictPending = false;
  bool _observing = false;

  bool get keepInMemory => _keepInMemory;

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void observeMemoryPressure() {
    if (_observing) return;
    WidgetsBinding.instance.addObserver(this);
    _observing = true;
  }

  Future<void> dispose() async {
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    _observing = false;
    await _exclusive(() async {
      await _finish();
      _release();
    });
  }

  void setKeepInMemory(bool value) {
    _keepInMemory = value;
    if (!value) evictWhenIdle();
  }

  @override
  void didHaveMemoryPressure() => evictWhenIdle();

  void evictWhenIdle() {
    _evictPending = true;
    _background(
      _exclusive(() async {
        if (_session == null) _release();
      }),
    );
  }

  void _background(Future<void> future) {
    unawaited(
      future.catchError((Object error, StackTrace stack) {
        AppLogger.error(
          'Speech model cleanup failed',
          error: error,
          stackTrace: stack,
        );
      }),
    );
  }

  void _release() {
    final resident = _resident;
    _resident = null;
    _evictPending = false;
    resident?.releaseResidentModel();
  }

  Future<void> _finish() async {
    final resident = _resident;
    if (_session == null || resident == null) return;
    try {
      await resident.stopBackend();
    } catch (_) {
      _evictPending = true;
      rethrow;
    } finally {
      _session = null;
      if (!_keepInMemory || _evictPending) _release();
    }
  }

  Future<bool> initialize(ResidentSpeechInputService backend) =>
      _exclusive(() async {
        await _finish();
        if (!identical(_resident, backend)) _release();
        _resident = backend;
        return backend.initializeBackend();
      });

  Future<void> start(
    ResidentSpeechInputService backend,
    Object token, {
    required void Function(String, bool) onResult,
    required void Function(String) onStatus,
    required void Function() onError,
    Duration? pauseFor,
    String? localeId,
  }) => _exclusive(() async {
    await _finish();
    if (!identical(_resident, backend)) _release();
    _resident = backend;
    _session = token;
    var failed = false;
    void finishLater({bool failed = false}) {
      if (!identical(_session, token)) return;
      if (failed) _evictPending = true;
      _background(stop(token));
    }

    try {
      // Re-resolve files inside the same lease as construction. A queued model
      // deletion may have run since the composer's availability check.
      await backend.initializeBackend();
      await backend.startBackend(
        onResult: (text, finalResult) {
          if (identical(_session, token)) onResult(text, finalResult);
        },
        onStatus: (status) {
          if (!identical(_session, token)) return;
          if (status == 'done' || status == 'model_required') finishLater();
          onStatus(status);
        },
        onError: () {
          if (!identical(_session, token)) return;
          failed = true;
          finishLater(failed: true);
          onError();
        },
        pauseFor: pauseFor,
        localeId: localeId,
      );
      if (failed || !backend.isListening) await _finish();
    } catch (_) {
      _evictPending = true;
      await _finish();
      rethrow;
    }
  });

  Future<void> stop(Object? token) => _exclusive(() async {
    if (token != null && identical(_session, token)) await _finish();
  });

  /// Prevents acquisition while model files are replaced or deleted. A matching
  /// active session is finalized before freeing weights and mutating its files.
  Future<T> mutateModel<T>(String path, Future<T> Function() mutation) =>
      _exclusive(() async {
        if (_resident?.residentModelPath == path) {
          await _finish();
          _release();
        }
        return mutation();
      });
}

/// Optional capability for the five local backends; native/API stay unchanged.
mixin ResidentSpeechInputService implements SpeechInputService {
  SpeechModelResidencyController get residency =>
      SpeechModelResidencyController.instance;
  Object? sessionToken;
  String? get residentModelPath;
  void releaseResidentModel();
  Future<bool> initializeBackend();
  Future<void> stopBackend();
  Future<void> startBackend({
    required void Function(String, bool) onResult,
    required void Function(String) onStatus,
    required void Function() onError,
    Duration? pauseFor,
    String? localeId,
  });

  @override
  Future<bool> initialize() => residency.initialize(this);

  @override
  Future<void> startListening({
    required void Function(String, bool) onResult,
    required void Function(String) onStatus,
    required void Function() onError,
    Duration? pauseFor,
    String? localeId,
  }) {
    final token = Object();
    sessionToken = token;
    return residency.start(
      this,
      token,
      onResult: onResult,
      onStatus: onStatus,
      onError: onError,
      pauseFor: pauseFor,
      localeId: localeId,
    );
  }

  @override
  Future<void> stopListening() => residency.stop(sessionToken);
}
