import 'package:codewalk/core/di/injection_container.dart' as di;
import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/presentation/pages/settings/sections/speech_settings_section.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:codewalk/presentation/services/moonshine_model_manager.dart';
import 'package:codewalk/presentation/services/parakeet_model_manager.dart';
import 'package:codewalk/presentation/services/sensevoice_model_manager.dart';
import 'package:codewalk/presentation/services/sherpa_model_manager.dart';
import 'package:codewalk/presentation/services/sound_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';
import '../support/pump_localized_app.dart';

void main() {
  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.linux,
    TargetPlatform.iOS,
  ]) {
    testWidgets('retention switch supports $platform layout and persists', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      await di.sl.reset();
      di.sl.registerSingleton<SherpaModelManager>(SherpaModelManager());
      di.sl.registerSingleton<MoonshineModelManager>(MoonshineModelManager());
      di.sl.registerSingleton<ParakeetModelManager>(ParakeetModelManager());
      di.sl.registerSingleton<SenseVoiceModelManager>(SenseVoiceModelManager());
      final local = InMemoryAppLocalDataSource();
      final provider = SettingsProvider(
        localDataSource: local,
        dioClient: DioClient(),
        soundService: SoundService(),
      );
      await provider.initialize();
      tester.view.physicalSize = platform == TargetPlatform.linux
          ? const Size(1200, 900)
          : const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() async {
        debugDefaultTargetPlatformOverride = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await di.sl.reset();
      });
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: localizedMaterialApp(
            home: const Scaffold(body: SpeechSettingsSection()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('On-device speech recognition with downloadable models.'), findsOneWidget);
      expect(find.textContaining('Sherpa is experimental'), findsNothing);
      final toggle = find.byKey(
        const ValueKey('settings_speech_keep_model_in_memory'),
      );
      // Sherpa also provides local fallback on iOS.
      expect(toggle, findsOneWidget);
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(provider.speechKeepModelInMemory, isFalse);
      expect(
        local.experienceSettingsJson,
        contains('"speechKeepModelInMemory":false'),
      );
      expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        provider.dispose();
        debugDefaultTargetPlatformOverride = null;
    });
  }
}
