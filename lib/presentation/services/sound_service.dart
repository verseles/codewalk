import 'package:flutter/services.dart';

import '../../core/logging/app_logger.dart';
import '../../domain/entities/experience_settings.dart';

class SoundService {
  Future<bool> play(SoundOption option) async {
    if (option == SoundOption.off) {
      return true;
    }

    try {
      final type = option == SoundOption.click
          ? SystemSoundType.click
          : SystemSoundType.alert;
      await SystemSound.play(type);
      return true;
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Sound unavailable on this platform',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
