import 'package:codewalk/core/auth/stt_api_key_storage.dart';
import 'package:codewalk/core/auth/tts_api_key_storage.dart';
import 'package:codewalk/core/di/injection_container.dart' as di;
import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/domain/entities/experience_settings.dart';
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

class _SttStorageBackend implements SttApiKeyStorageBackend {
  final values = <String, String>{};

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

class _TtsStorageBackend implements TtsApiKeyStorageBackend {
  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<String?> read({required String key}) async => null;

  @override
  Future<void> write({required String key, required String value}) async {}
}

void main() {
  testWidgets('API speech settings work at mobile width', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await di.sl.reset();
    addTearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await di.sl.reset();
    });
    di.sl.registerSingleton<SherpaModelManager>(SherpaModelManager());
    di.sl.registerSingleton<MoonshineModelManager>(MoonshineModelManager());
    di.sl.registerSingleton<ParakeetModelManager>(ParakeetModelManager());
    di.sl.registerSingleton<SenseVoiceModelManager>(SenseVoiceModelManager());
    final sttBackend = _SttStorageBackend();
    di.sl.registerSingleton<SttApiKeyStorage>(
      SttApiKeyStorage(backend: sttBackend),
    );
    di.sl.registerSingleton<TtsApiKeyStorage>(
      TtsApiKeyStorage(backend: _TtsStorageBackend()),
    );
    final provider = SettingsProvider(
      localDataSource: InMemoryAppLocalDataSource(),
      dioClient: DioClient(),
      soundService: SoundService(),
    );
    await provider.initialize();
    await provider.setSpeechToTextEngine(SpeechToTextEngine.api);

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: provider,
        child: localizedMaterialApp(
          home: const Scaffold(body: SpeechSettingsSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('speech-api-settings-card')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('speech-api-settings-card')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('speech-api-base-url-openai')),
          )
          .enabled,
      isFalse,
    );

    await tester.tap(find.byKey(const ValueKey('speech-api-provider-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom OpenAI-compatible').last);
    await tester.pumpAndSettle();

    expect(provider.speechApiProvider, SpeechApiProvider.custom);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('speech-api-base-url-custom')),
          )
          .enabled,
      isTrue,
    );
    final keyField = tester.widget<TextField>(
      find.byKey(const ValueKey('speech-api-key-custom')),
    );
    expect(keyField.obscureText, isTrue);
    await tester.enterText(
      find.byKey(const ValueKey('speech-api-key-custom')),
      'secret',
    );
    await tester.tap(find.byKey(const ValueKey('speech-api-save-key')));
    await tester.pumpAndSettle();

    expect(sttBackend.values.values, contains('secret'));
    expect(find.text('secret'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
}
