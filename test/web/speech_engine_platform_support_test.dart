@TestOn('browser')
library;

import 'package:codewalk/presentation/utils/speech_engine_platform_support.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'browser enables native speech but excludes device engines and API keys',
    () {
      expect(kIsWeb, isTrue);
      expect(SpeechEnginePlatformSupport.isNativeSupported, isTrue);
      expect(SpeechEnginePlatformSupport.isSherpaSupported, isFalse);
      expect(SpeechEnginePlatformSupport.isMoonshineSupported, isFalse);
      expect(SpeechEnginePlatformSupport.isParakeetSupported, isFalse);
      expect(SpeechEnginePlatformSupport.isSenseVoiceSupported, isFalse);
      expect(SpeechEnginePlatformSupport.isNemotronSupported, isFalse);
      expect(SpeechEnginePlatformSupport.hasAnyOnDeviceEngine, isFalse);
      expect(SpeechEnginePlatformSupport.isApiSupported, isFalse);
    },
  );
}
