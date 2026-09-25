import 'package:flutter/foundation.dart';

import '../../core/logging/app_logger.dart';
import '../../domain/entities/experience_settings.dart';

/// App-lifetime progress for model downloads, independent of Settings routes.
class SttModelDownloadTracker extends ChangeNotifier {
  SttModelDownloadTracker._();

  static final SttModelDownloadTracker instance = SttModelDownloadTracker._();

  SttModelDownload? _active;
  SttModelDownload? _lastFinished;
  int _transition = 0;

  SttModelDownload? get active => _active;
  SttModelDownload? get lastFinished => _lastFinished;
  int get transition => _transition;
  bool isDownloading(SpeechToTextEngine engine, String modelId) =>
      _active?.engine == engine && _active?.modelId == modelId;

  Future<void> run({
    required SpeechToTextEngine engine,
    required String modelId,
    required Future<void> Function(void Function(double)) download,
    void Function(double)? onProgress,
  }) async {
    if (_active != null) {
      throw StateError('Another model download is already in progress');
    }
    _active = SttModelDownload(engine, modelId, 0);
    _transition++;
    notifyListeners();
    try {
      await download((progress) {
        final next = progress.clamp(0.0, 1.0);
        onProgress?.call(next);
        final previous = _active;
        if (previous != null &&
            (next >= 1 || next - previous.progress >= 0.01)) {
          _active = SttModelDownload(engine, modelId, next);
          notifyListeners();
        }
      });
      _lastFinished = SttModelDownload(engine, modelId, 1);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Speech model download failed',
        error: error,
        stackTrace: stackTrace,
        tags: const {'speech', 'model-download'},
      );
      _lastFinished = SttModelDownload(engine, modelId, 0, failed: true);
      rethrow;
    } finally {
      _active = null;
      _transition++;
      notifyListeners();
    }
  }
}

class SttModelDownload {
  const SttModelDownload(
    this.engine,
    this.modelId,
    this.progress, {
    this.failed = false,
  });

  final SpeechToTextEngine engine;
  final String modelId;
  final double progress;
  final bool failed;
}
