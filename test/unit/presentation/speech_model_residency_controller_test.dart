import 'dart:async';

import 'package:codewalk/presentation/services/speech_model_residency_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _Backend extends Fake with ResidentSpeechInputService {
  _Backend(this.residency, this.path);
  @override
  final SpeechModelResidencyController residency;
  final String path;
  bool loaded = false;
  int constructions = 0;
  int frees = 0;
  int stops = 0;
  Completer<void>? startup;
  Completer<void>? finalization;
  void Function(String)? status;
  void Function()? fail;
  @override
  bool isListening = false;
  @override
  String? get residentModelPath => loaded ? path : null;
  @override
  Future<bool> initializeBackend() async => true;
  @override
  void releaseResidentModel() {
    expect(isListening, isFalse);
    if (loaded) frees++;
    loaded = false;
  }

  @override
  Future<void> startBackend({
    required void Function(String, bool) onResult,
    required void Function(String) onStatus,
    required void Function() onError,
    Duration? pauseFor,
    String? localeId,
  }) async {
    if (!loaded) constructions++;
    loaded = true;
    await startup?.future;
    isListening = true;
    status = onStatus;
    fail = onError;
    onStatus('listening');
  }

  @override
  Future<void> stopBackend() async {
    stops++;
    await finalization?.future;
    isListening = false;
  }
}

Future<void> _start(_Backend backend) => backend.startListening(
  onResult: (_, _) {},
  onStatus: (_) {},
  onError: () {},
);

void main() {
  late SpeechModelResidencyController controller;
  late _Backend first;
  setUp(() {
    controller = SpeechModelResidencyController();
    first = _Backend(controller, '/first');
  });
  tearDown(() => controller.dispose());

  test(
    'warm sessions reuse weights; disabled sessions release each time',
    () async {
      for (var i = 0; i < 10; i++) {
        await _start(first);
        await first.stopListening();
      }
      expect(first.constructions, 1);
      expect(first.frees, 0);
      controller.setKeepInMemory(false);
      await controller.stop(null);
      expect(first.frees, 1);
      for (var i = 0; i < 3; i++) {
        await _start(first);
        await first.stopListening();
      }
      expect(first.constructions, 4);
      expect(first.frees, 4);
    },
  );

  test('pressure and opt-out wait for startup and final decoding', () async {
    first.startup = Completer<void>();
    final starting = _start(first);
    await Future<void>.delayed(Duration.zero);
    controller.didHaveMemoryPressure();
    controller.setKeepInMemory(false);
    expect(first.frees, 0);
    first.startup!.complete();
    await starting;
    expect(first.frees, 0);
    first.finalization = Completer<void>();
    final stopping = first.stopListening();
    await Future<void>.delayed(Duration.zero);
    expect(first.frees, 0);
    first.finalization!.complete();
    await stopping;
    expect(first.frees, 1);
  });

  test(
    'switch leaves one owner and stale stop cannot stop new session',
    () async {
      await _start(first);
      final old = first.sessionToken;
      final second = _Backend(controller, '/second');
      await _start(second);
      expect(first.loaded, isFalse);
      expect(second.loaded, isTrue);
      await controller.stop(old);
      expect(second.isListening, isTrue);
      await _start(second);
      final current = second.sessionToken;
      await controller.stop(old);
      expect(second.sessionToken, same(current));
      expect(second.isListening, isTrue);
    },
  );

  test(
    'mutation waits for finalization and prevents concurrent acquisition',
    () async {
      await _start(first);
      first.finalization = Completer<void>();
      final mutationDone = Completer<void>();
      var mutating = false;
      final mutation = controller.mutateModel('/first', () async {
        expect(first.loaded, isFalse);
        mutating = true;
        await mutationDone.future;
      });
      final starting = _start(first);
      await Future<void>.delayed(Duration.zero);
      expect(mutating, isFalse);
      first.finalization!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(mutating, isTrue);
      expect(first.constructions, 1);
      mutationDone.complete();
      await mutation;
      await starting;
      expect(first.constructions, 2);
    },
  );

  test(
    'unrelated mutation preserves active owner and failure permits retry',
    () async {
      await _start(first);
      await expectLater(
        controller.mutateModel('/other', () async {
          throw StateError('disk');
        }),
        throwsStateError,
      );
      expect(first.isListening, isTrue);
      expect(first.frees, 0);
      await first.stopListening();
      await _start(first);
      expect(first.constructions, 1);
    },
  );

  test(
    'natural finish and decode failure clean up without deadlocking',
    () async {
      await _start(first);
      first.status!('done');
      await controller.stop(null);
      expect(first.stops, 1);
      expect(first.loaded, isTrue);
      await _start(first);
      first.fail!();
      await controller.stop(null);
      expect(first.loaded, isFalse);
    },
  );
}
