import 'package:flutter/foundation.dart';

// Centralized platform support for speech-to-text engines.
//
// On Windows, CodeWalk avoids both native crash surfaces that affected issue
// #43: `speech_to_text_windows` and `record_windows`. Native STT is disabled on
// Windows; on-device engines use the runner-owned WASAPI microphone bridge.
//
// See ADR-038/ADR-039 for the historical mitigation and ADR-044 for the final
// WASAPI backend decision.
class SpeechEnginePlatformSupport {
  const SpeechEnginePlatformSupport._();

  // Web: true (browser speech via speech_to_text). Linux/Windows: false — both
  // default to on-device engines instead of native speech plugins.
  static bool get isNativeSupported {
    if (kIsWeb) {
      return true;
    }
    return defaultTargetPlatform != TargetPlatform.linux &&
        defaultTargetPlatform != TargetPlatform.windows;
  }

  // Web has no sherpa runtime. Android keeps the runtime in the APK and
  // downloads model files on demand.
  static bool get isSherpaSupported => !kIsWeb;

  static bool get _supportsDownloadableOnDeviceStt {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  static bool get isMoonshineSupported => _supportsDownloadableOnDeviceStt;

  static bool get isParakeetSupported => _supportsDownloadableOnDeviceStt;

  static bool get isSenseVoiceSupported => _supportsDownloadableOnDeviceStt;

  static bool get isNemotronSupported => _supportsDownloadableOnDeviceStt;

  // Cloud API keys must not be exposed in browser builds. Native mobile and
  // desktop apps can call a configured OpenAI-compatible endpoint directly.
  static bool get isApiSupported => !kIsWeb;

  // True when at least one on-device engine (Sherpa/Moonshine/Parakeet/
  // SenseVoice) is supported. Used to decide whether to show the on-device
  // STT disabled info card on Windows.
  static bool get hasAnyOnDeviceEngine {
    return isSherpaSupported ||
        isMoonshineSupported ||
        isParakeetSupported ||
        isSenseVoiceSupported ||
        isNemotronSupported;
  }
}
