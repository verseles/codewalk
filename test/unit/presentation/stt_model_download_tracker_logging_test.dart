import 'package:codewalk/core/logging/app_logger.dart';
import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/presentation/services/stt_model_download_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('handled model download errors appear in enabled app logs', () async {
    AppLogger.setLoggingEnabled(true);
    AppLogger.clearEntries();
    addTearDown(() => AppLogger.setLoggingEnabled(false));
    final tracker = SttModelDownloadTracker.instance;
    await expectLater(
      tracker.run(
        engine: SpeechToTextEngine.parakeet,
        modelId: 'test-model',
        download: (_) async => throw StateError('archive extraction failed'),
      ),
      throwsStateError,
    );
    expect(tracker.lastFinished?.failed, isTrue);
    expect(tracker.active, isNull);
    expect(
      AppLogger.entries.value.any(
        (entry) =>
            entry.message == 'Speech model download failed' &&
            (entry.error?.contains('archive extraction failed') ?? false),
      ),
      isTrue,
    );
  });
}
