import 'dart:async';

import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/presentation/services/stt_model_download_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final tracker = SttModelDownloadTracker.instance;

  test(
    'keeps a download and its progress after a view stops listening',
    () async {
      final finish = Completer<void>();
      late void Function(double) report;
      var notifications = 0;
      void listener() => notifications++;
      tracker.addListener(listener);

      final download = tracker.run(
        engine: SpeechToTextEngine.parakeet,
        modelId: 'parakeet-v3',
        download: (progress) {
          report = progress;
          return finish.future;
        },
      );
      expect(
        tracker.isDownloading(SpeechToTextEngine.parakeet, 'parakeet-v3'),
        isTrue,
      );
      report(0.45);
      expect(tracker.active?.progress, 0.45);
      expect(notifications, greaterThan(1));

      tracker.removeListener(listener); // The Settings route was disposed.
      finish.complete();
      await download;

      expect(tracker.active, isNull);
      expect(tracker.lastFinished?.modelId, 'parakeet-v3');
      expect(tracker.lastFinished?.failed, isFalse);
    },
  );

  test('reports failure and releases the active operation', () async {
    await expectLater(
      tracker.run(
        engine: SpeechToTextEngine.nemotron,
        modelId: 'nemotron',
        download: (_) async => throw StateError('offline'),
      ),
      throwsStateError,
    );
    expect(tracker.active, isNull);
    expect(tracker.lastFinished?.failed, isTrue);
  });

  test('keeps the first model visible when a second starts', () async {
    final finish = Completer<void>();
    final first = tracker.run(
      engine: SpeechToTextEngine.moonshine,
      modelId: 'moonshine-base',
      download: (_) => finish.future,
    );

    await expectLater(
      tracker.run(
        engine: SpeechToTextEngine.parakeet,
        modelId: 'parakeet-v3',
        download: (_) async {},
      ),
      throwsStateError,
    );
    expect(tracker.active?.modelId, 'moonshine-base');
    expect(tracker.isDownloading(SpeechToTextEngine.moonshine, 'moonshine-base'), isTrue);
    finish.complete();
    await first;
    expect(tracker.lastFinished?.modelId, 'moonshine-base');
  });
}
