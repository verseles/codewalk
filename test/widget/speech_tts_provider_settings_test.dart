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
  _FakeTtsBackend(this._provider);

  final ReadAloudProvider _provider;

  @override
  ReadAloudProvider get provider => _provider;

  @override
  TtsPlaybackMode get playbackMode => TtsPlaybackMode.generatedAudio;

  @override
  Future<bool> get isAvailable async => true;

  @override
  Future<List<TtsVoiceOption>> getVoices({
    String? apiKey,
    String? baseUrl,
    String? model,
  }) async {
    return const <TtsVoiceOption>[
      TtsVoiceOption(id: 'voice-a', label: 'Voice A', locale: 'pt-BR'),
      TtsVoiceOption(id: 'voice-b', label: 'Voice B', locale: 'en-US'),
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
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

void _registerDi(_TtsStorageBackend ttsBackend) {
  di.sl.registerSingleton<SherpaModelManager>(SherpaModelManager());
  di.sl.registerSingleton<MoonshineModelManager>(MoonshineModelManager());
  di.sl.registerSingleton<ParakeetModelManager>(ParakeetModelManager());
  di.sl.registerSingleton<SenseVoiceModelManager>(SenseVoiceModelManager());
  di.sl.registerSingleton<SttApiKeyStorage>(
    SttApiKeyStorage(backend: _SttStorageBackend()),
  );
  di.sl.registerSingleton<TtsApiKeyStorage>(
    TtsApiKeyStorage(backend: ttsBackend),
  );
  di.sl.registerSingleton<ReadAloudService>(
    ReadAloudService(backends: <ReadAloudProvider, TtsBackend>{
      ReadAloudProvider.native: _FakeTtsBackend(ReadAloudProvider.native),
      ReadAloudProvider.edgeExperimental: _FakeTtsBackend(
        ReadAloudProvider.edgeExperimental,
      ),
      ReadAloudProvider.elevenLabs: _FakeTtsBackend(
        ReadAloudProvider.elevenLabs,
      ),
      ReadAloudProvider.nim: _FakeTtsBackend(ReadAloudProvider.nim),
    }),
  );
}

Future<SettingsProvider> _buildProvider() async {
  final provider = SettingsProvider(
    localDataSource: InMemoryAppLocalDataSource(),
    dioClient: DioClient(),
    soundService: SoundService(),
  );
  await provider.initialize();
  return provider;
}

Future<void> _pumpSection(
  WidgetTester tester,
  SettingsProvider provider, {
  Size size = const Size(800, 1000),
}) async {
  tester.view.physicalSize = size;
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

Future<void> _scrollToReadAloud(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Text to speech'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  for (final platform in <TargetPlatform>[
    TargetPlatform.android,
    TargetPlatform.linux,
  ]) {
    testWidgets(
      'new TTS providers appear in the provider dropdown ($platform)',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        await di.sl.reset();
        addTearDown(() async {
          debugDefaultTargetPlatformOverride = null;
          await di.sl.reset();
        });
        _registerDi(_TtsStorageBackend());
        final provider = await _buildProvider();

        await _pumpSection(tester, provider);
        await _scrollToReadAloud(tester);

        final dropdown = find.byType(DropdownButtonFormField<ReadAloudProvider>);
        await tester.tap(dropdown, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('ElevenLabs'), findsOneWidget);
        expect(find.text('NVIDIA NIM'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        debugDefaultTargetPlatformOverride = null;
        provider.dispose();
      },
    );
  }

  testWidgets('ElevenLabs provider renders its fields and voice picker',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await di.sl.reset();
    addTearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await di.sl.reset();
    });
    final ttsBackend = _TtsStorageBackend();
    _registerDi(ttsBackend);
    final provider = await _buildProvider();
    await provider.setReadAloudProvider(ReadAloudProvider.elevenLabs);

    await _pumpSection(tester, provider);
    await _scrollToReadAloud(tester);

    expect(provider.readAloudBaseUrl, kDefaultElevenLabsTtsBaseUrl);
    expect(provider.readAloudModel, kDefaultElevenLabsTtsModel);
    expect(find.text('ElevenLabs'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Loaded from the provider voices.'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Loaded from the provider voices.'), findsOneWidget);

    await tester.tap(
      find.text('Loaded from the provider voices.'),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 300));

    Finder inSheet(Finder finder) =>
        find.descendant(of: find.byType(BottomSheet), matching: finder);

    expect(inSheet(find.text('Voice A')), findsOneWidget);
    expect(inSheet(find.text('Voice B')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
    provider.dispose();
  });

  testWidgets('NVIDIA NIM provider hides the speed slider', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await di.sl.reset();
    addTearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await di.sl.reset();
    });
    _registerDi(_TtsStorageBackend());
    final provider = await _buildProvider();
    await provider.setReadAloudProvider(ReadAloudProvider.nim);

    await _pumpSection(tester, provider);
    await _scrollToReadAloud(tester);

    expect(find.text('NVIDIA NIM'), findsWidgets);
    expect(provider.readAloudBaseUrl, kDefaultNimTtsBaseUrl);
    expect(provider.readAloudModel, kDefaultNimTtsModel);
    final speedSlider = find.byWidgetPredicate(
      (widget) =>
          widget is Slider && widget.min == 0.0 && widget.max == 1.0,
    );
    expect(speedSlider, findsNothing);
    expect(find.textContaining('not supported by NVIDIA NIM'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
    provider.dispose();
  });
}