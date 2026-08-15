import 'package:codewalk/core/auth/stt_api_key_storage.dart';
import 'package:codewalk/core/auth/tts_api_key_storage.dart';
import 'package:codewalk/core/di/injection_container.dart' as di;
import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/presentation/pages/settings/sections/speech_settings_section.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:codewalk/presentation/services/moonshine_model_manager.dart';
import 'package:codewalk/presentation/services/parakeet_model_manager.dart';
import 'package:codewalk/presentation/services/read_aloud_service.dart';
import 'package:codewalk/presentation/services/sensevoice_model_manager.dart';
import 'package:codewalk/presentation/services/sherpa_model_manager.dart';
import 'package:codewalk/presentation/services/sound_service.dart';
import 'package:codewalk/presentation/services/tts/tts_backend.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';
import '../support/pump_localized_app.dart';

class _FakeTtsBackend implements TtsBackend {
  @override
  ReadAloudProvider get provider => ReadAloudProvider.edgeExperimental;

  @override
  TtsPlaybackMode get playbackMode => TtsPlaybackMode.generatedAudio;

  @override
  Future<bool> get isAvailable async => true;

  @override
  Future<List<TtsVoiceOption>> getVoices() async {
    return const <TtsVoiceOption>[
      TtsVoiceOption(
        id: 'pt-BR-AntonioNeural',
        label: 'Microsoft Antonio Online (Natural) - Portuguese (Brazil)',
        locale: 'pt-BR',
      ),
      TtsVoiceOption(
        id: 'pt-BR-FranciscaNeural',
        label: 'Microsoft Francisca Online (Natural) - Portuguese (Brazil)',
        locale: 'pt-BR',
      ),
      TtsVoiceOption(
        id: 'en-US-EmmaMultilingualNeural',
        label: 'Microsoft Emma Multilingual Online (Natural) - English (US)',
        locale: 'en-US',
      ),
    ];
  }

  @override
  Future<List<String>> getLanguages() async => const <String>[];

  @override
  Future<TtsSynthesisResult> speakOrSynthesize(
    TtsSynthesisRequest request,
    TtsBackendCallbacks callbacks,
  ) async {
    return GeneratedTtsAudio(
      bytes: Uint8List(0),
      mimeType: 'audio/mpeg',
    );
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> pause() async {}

  @override
  void dispose() {}
}

class _SttStorageBackend implements SttApiKeyStorageBackend {
  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<String?> read({required String key}) async => null;

  @override
  Future<void> write({required String key, required String value}) async {}
}

class _TtsStorageBackend implements TtsApiKeyStorageBackend {
  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<String?> read({required String key}) async => null;

  @override
  Future<void> write({required String key, required String value}) async {}
}

Future<SettingsProvider> _buildProvider() async {
  final provider = SettingsProvider(
    localDataSource: InMemoryAppLocalDataSource(),
    dioClient: DioClient(),
    soundService: SoundService(),
  );
  await provider.initialize();
  await provider.setReadAloudProvider(ReadAloudProvider.edgeExperimental);
  return provider;
}

Future<void> _pumpSection(
  WidgetTester tester,
  SettingsProvider provider,
) async {
  tester.view.physicalSize = const Size(800, 1000);
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
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('Edge voice picker opens a searchable sheet and filters',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await di.sl.reset();
    addTearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await di.sl.reset();
    });
    di.sl.registerSingleton<SherpaModelManager>(SherpaModelManager());
    di.sl.registerSingleton<MoonshineModelManager>(MoonshineModelManager());
    di.sl.registerSingleton<ParakeetModelManager>(ParakeetModelManager());
    di.sl.registerSingleton<SenseVoiceModelManager>(SenseVoiceModelManager());
    di.sl.registerSingleton<SttApiKeyStorage>(
      SttApiKeyStorage(backend: _SttStorageBackend()),
    );
    di.sl.registerSingleton<TtsApiKeyStorage>(
      TtsApiKeyStorage(backend: _TtsStorageBackend()),
    );
    di.sl.registerSingleton<ReadAloudService>(
      ReadAloudService(backends: <ReadAloudProvider, TtsBackend>{
        ReadAloudProvider.edgeExperimental: _FakeTtsBackend(),
      }),
    );
    final provider = await _buildProvider();

    await _pumpSection(tester, provider);

    await tester.scrollUntilVisible(
      find.text('Edge voice'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Edge voice'), findsOneWidget);

    await tester.tap(
      find.text('Edge voice'),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 300));

    Finder inSheet(Finder finder) =>
        find.descendant(of: find.byType(BottomSheet), matching: finder);

    expect(find.byType(TextField), findsOneWidget);
    expect(inSheet(find.text('Microsoft Antonio Online (Natural) - Portuguese (Brazil)')),
        findsOneWidget);
    expect(inSheet(find.text('Microsoft Emma Multilingual Online (Natural) - English (US)')),
        findsOneWidget);

    await tester.enterText(find.byType(TextField), 'antonio');
    await tester.pump(const Duration(milliseconds: 100));

    expect(inSheet(find.text('Microsoft Antonio Online (Natural) - Portuguese (Brazil)')),
        findsOneWidget);
    expect(inSheet(find.text('Microsoft Francisca Online (Natural) - Portuguese (Brazil)')),
        findsNothing);
    expect(inSheet(find.text('Microsoft Emma Multilingual Online (Natural) - English (US)')),
        findsNothing);

    await tester.tap(inSheet(find.text('Microsoft Antonio Online (Natural) - Portuguese (Brazil)')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(provider.readAloudVoiceId, 'pt-BR-AntonioNeural');
    expect(provider.readAloudVoiceLocale, 'pt-BR');
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
}
