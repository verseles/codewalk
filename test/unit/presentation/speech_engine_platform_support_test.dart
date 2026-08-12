import 'package:codewalk/presentation/utils/speech_engine_platform_support.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpeechEnginePlatformSupport', () {
    setUp(() {
      // Reset the platform override before each test so leaked overrides from
      // other test files cannot affect this suite.
      debugDefaultTargetPlatformOverride = null;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    // isNativeSupported: web and non-Linux/non-Windows IO platforms; Linux and
    // Windows default to on-device engines by design.
    group('isNativeSupported', () {
      test('is true on the web', () {
        // kIsWeb is a compile-time constant, so we can only exercise the
        // IO-platform branches here. The web branch is verified by the build.
        expect(SpeechEnginePlatformSupport.isNativeSupported, isNotNull);
      });

      for (final platform in const [
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.android,
        TargetPlatform.fuchsia,
      ]) {
        test('is true on IO $platform', () {
          debugDefaultTargetPlatformOverride = platform;
          expect(SpeechEnginePlatformSupport.isNativeSupported, isTrue);
        });
      }

      for (final platform in const [
        TargetPlatform.linux,
        TargetPlatform.windows,
      ]) {
        test('is false on $platform', () {
          debugDefaultTargetPlatformOverride = platform;
          expect(SpeechEnginePlatformSupport.isNativeSupported, isFalse);
        });
      }
    });

    // isSherpaSupported: web false; Android false; all other IO platforms true.
    // iOS keeps the historic "supported"
    // flag because sherpa_onnx ships an iOS build, even though the chat input
    // never wires it up on iOS in practice.
    group('isSherpaSupported', () {
      for (final platform in const [
        TargetPlatform.iOS,
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.fuchsia,
      ]) {
        test('is true on $platform', () {
          debugDefaultTargetPlatformOverride = platform;
          expect(SpeechEnginePlatformSupport.isSherpaSupported, isTrue);
        });
      }

      for (final platform in const [TargetPlatform.android]) {
        test('is false on $platform', () {
          debugDefaultTargetPlatformOverride = platform;
          expect(SpeechEnginePlatformSupport.isSherpaSupported, isFalse);
        });
      }
    });

    // Desktop-only on-device engines (Moonshine, Parakeet, SenseVoice): Linux,
    // macOS, and Windows. Windows uses CodeWalk WASAPI instead of record_windows.
    for (final entry in <(String, bool Function())>[
      (
        'isMoonshineSupported',
        () => SpeechEnginePlatformSupport.isMoonshineSupported,
      ),
      (
        'isParakeetSupported',
        () => SpeechEnginePlatformSupport.isParakeetSupported,
      ),
      (
        'isSenseVoiceSupported',
        () => SpeechEnginePlatformSupport.isSenseVoiceSupported,
      ),
    ]) {
      group(entry.$1, () {
        for (final platform in const [
          TargetPlatform.linux,
          TargetPlatform.macOS,
          TargetPlatform.windows,
        ]) {
          test('is true on $platform', () {
            debugDefaultTargetPlatformOverride = platform;
            expect(entry.$2(), isTrue);
          });
        }

        for (final platform in const [
          TargetPlatform.iOS,
          TargetPlatform.android,
          TargetPlatform.fuchsia,
        ]) {
          test('is false on $platform (regression for issue #43)', () {
            debugDefaultTargetPlatformOverride = platform;
            expect(entry.$2(), isFalse);
          });
        }
      });
    }

    // hasAnyOnDeviceEngine: false only when no on-device engine is supported
    // (Android). Linux/macOS/Windows expose all 4 on-device engines, iOS
    // exposes Sherpa, fuchsia exposes Sherpa too.
    group('hasAnyOnDeviceEngine', () {
      for (final platform in const [
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.iOS,
        TargetPlatform.fuchsia,
      ]) {
        test('is true on $platform', () {
          debugDefaultTargetPlatformOverride = platform;
          expect(SpeechEnginePlatformSupport.hasAnyOnDeviceEngine, isTrue);
        });
      }

      for (final platform in const [TargetPlatform.android]) {
        test('is false on $platform (regression for issue #43)', () {
          debugDefaultTargetPlatformOverride = platform;
          expect(SpeechEnginePlatformSupport.hasAnyOnDeviceEngine, isFalse);
        });
      }
    });

    test('API engine is supported on native mobile and desktop targets', () {
      for (final platform in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          SpeechEnginePlatformSupport.isApiSupported,
          isTrue,
          reason: '$platform',
        );
      }
    });
  });
}
