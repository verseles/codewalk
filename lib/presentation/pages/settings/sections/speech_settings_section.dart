import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../../core/auth/tts_api_key_storage.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/i18n/l10n_context.dart';
import '../../../../domain/entities/experience_settings.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/moonshine_model_manager.dart';
import '../../../services/parakeet_model_manager.dart';
import '../../../services/read_aloud_service.dart';
import '../../../services/sensevoice_model_manager.dart';
import '../../../services/sherpa_model_manager.dart';
import '../../../services/tts/openai_compatible_tts_backend.dart';
import '../../../utils/speech_engine_platform_support.dart';
import '../../../utils/windows_settings_links.dart';
import '../../../widgets/searchable_dropdown_form_field.dart';
import '../widgets/settings_section_layout.dart';

class _SherpaModelEntry {
  const _SherpaModelEntry({
    required this.code,
    required this.label,
    required this.sizeMb,
  });

  final String code;
  final String label;
  final int sizeMb;
}

class SpeechSettingsSection extends StatefulWidget {
  const SpeechSettingsSection({super.key});

  @override
  State<SpeechSettingsSection> createState() => _SpeechSettingsSectionState();
}

class _SpeechSettingsSectionState extends State<SpeechSettingsSection> {
  final SherpaModelManager _modelManager = di.sl<SherpaModelManager>();
  final MoonshineModelManager _moonshineModelManager = di
      .sl<MoonshineModelManager>();
  final ParakeetModelManager _parakeetModelManager = di
      .sl<ParakeetModelManager>();
  final SenseVoiceModelManager _senseVoiceModelManager = di
      .sl<SenseVoiceModelManager>();

  List<_SherpaModelEntry> _models = const <_SherpaModelEntry>[];
  Map<String, bool> _installedByCode = const <String, bool>{};
  bool _loadingModels = false;
  bool _isMutatingModel = false;
  double _downloadProgress = 0;
  String? _modelError;
  List<_SherpaModelEntry> _moonshineModels = const <_SherpaModelEntry>[];
  Map<String, bool> _moonshineInstalledById = const <String, bool>{};
  bool _loadingMoonshineModels = false;
  bool _isMutatingMoonshineModel = false;
  double _moonshineDownloadProgress = 0;
  String? _moonshineModelError;
  List<_SherpaModelEntry> _parakeetModels = const <_SherpaModelEntry>[];
  Map<String, bool> _parakeetInstalledById = const <String, bool>{};
  bool _loadingParakeetModels = false;
  bool _isMutatingParakeetModel = false;
  double _parakeetDownloadProgress = 0;
  String? _parakeetModelError;
  List<_SherpaModelEntry> _senseVoiceModels = const <_SherpaModelEntry>[];
  Map<String, bool> _senseVoiceInstalledById = const <String, bool>{};
  bool _loadingSenseVoiceModels = false;
  bool _isMutatingSenseVoiceModel = false;
  double _senseVoiceDownloadProgress = 0;
  String? _senseVoiceModelError;
  double? _silenceDraftSeconds;
  final TextEditingController _readAloudApiKeyController =
      TextEditingController();
  bool _loadingReadAloudApiKey = false;
  bool _hasOpenAiCompatibleApiKey = false;
  String? _readAloudApiKeyStatus;
  int _readAloudApiKeyGeneration = 0;
  Future<List<Map<String, String>>>? _edgeReadAloudVoicesFuture;

  bool get _isLinux {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.linux;
  }

  // Platform support is centralized in [SpeechEnginePlatformSupport] so the
  // chat input, settings, and tests all agree on what works where.
  bool get _supportsSherpa => SpeechEnginePlatformSupport.isSherpaSupported;

  bool get _supportsSherpaModelManagement => _isLinux || _isWindows;

  bool get _isWindows {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.windows;
  }

  bool get _supportsMoonshine =>
      SpeechEnginePlatformSupport.isMoonshineSupported;
  bool get _supportsParakeet => SpeechEnginePlatformSupport.isParakeetSupported;
  bool get _supportsSenseVoice =>
      SpeechEnginePlatformSupport.isSenseVoiceSupported;

  @override
  void initState() {
    super.initState();
    if (_supportsSherpaModelManagement) {
      unawaited(_loadModelCatalog());
    }
    if (_supportsMoonshine) {
      unawaited(_loadMoonshineModelCatalog());
    }
    if (_supportsParakeet) {
      unawaited(_loadParakeetModelCatalog());
    }
    if (_supportsSenseVoice) {
      unawaited(_loadSenseVoiceModelCatalog());
    }
    unawaited(_loadReadAloudApiKeyState());
  }

  @override
  void dispose() {
    _readAloudApiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadReadAloudApiKeyState() async {
    if (!di.sl.isRegistered<TtsApiKeyStorage>()) {
      return;
    }
    final generation = ++_readAloudApiKeyGeneration;
    setState(() {
      _loadingReadAloudApiKey = true;
      _readAloudApiKeyStatus = null;
    });
    try {
      final key = await di.sl<TtsApiKeyStorage>().read(
        ReadAloudProvider.openAiCompatible,
      );
      if (!mounted || generation != _readAloudApiKeyGeneration) return;
      setState(() {
        _hasOpenAiCompatibleApiKey = key != null && key.isNotEmpty;
        _loadingReadAloudApiKey = false;
      });
    } catch (_) {
      if (!mounted || generation != _readAloudApiKeyGeneration) return;
      setState(() {
        _loadingReadAloudApiKey = false;
        _readAloudApiKeyStatus = 'Secure API key storage is unavailable.';
      });
    }
  }

  Future<void> _saveOpenAiCompatibleApiKey() async {
    if (!di.sl.isRegistered<TtsApiKeyStorage>()) {
      setState(() {
        _readAloudApiKeyStatus = 'Secure API key storage is unavailable.';
      });
      return;
    }
    final value = _readAloudApiKeyController.text;
    final generation = ++_readAloudApiKeyGeneration;
    setState(() {
      _loadingReadAloudApiKey = true;
      _readAloudApiKeyStatus = null;
    });
    try {
      await di.sl<TtsApiKeyStorage>().write(
        ReadAloudProvider.openAiCompatible,
        value,
      );
      _readAloudApiKeyController.clear();
      if (!mounted || generation != _readAloudApiKeyGeneration) return;
      setState(() {
        _hasOpenAiCompatibleApiKey = value.trim().isNotEmpty;
        _loadingReadAloudApiKey = false;
        _readAloudApiKeyStatus = value.trim().isEmpty
            ? 'API key removed.'
            : 'API key saved securely on this device.';
      });
    } catch (_) {
      if (!mounted || generation != _readAloudApiKeyGeneration) return;
      setState(() {
        _loadingReadAloudApiKey = false;
        _readAloudApiKeyStatus = 'Secure API key storage is unavailable.';
      });
    }
  }

  Future<void> _testReadAloudVoice(SettingsProvider settingsProvider) async {
    if (!di.sl.isRegistered<ReadAloudService>()) {
      return;
    }
    final service = di.sl<ReadAloudService>();
    await service.speak(
      messageId: 'settings_read_aloud_test',
      text: 'This is a CodeWalk text-to-speech test.',
      provider: settingsProvider.readAloudProvider,
      rate: settingsProvider.readAloudRate,
      pitch: settingsProvider.readAloudPitch,
      voice: settingsProvider.readAloudVoice,
      voiceId: settingsProvider.readAloudVoiceId,
      voiceLocale: settingsProvider.readAloudVoiceLocale,
      model: settingsProvider.readAloudModel,
      baseUrl: settingsProvider.readAloudBaseUrl,
      responseFormat: settingsProvider.readAloudResponseFormat,
    );
    final error = service.lastErrorMessage;
    if (!mounted || error == null || error.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error), duration: const Duration(seconds: 4)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        final selectedEngine = settingsProvider.speechToTextEngine;
        final silenceValue =
            _silenceDraftSeconds ??
            settingsProvider.speechSilenceTimeoutSeconds.toDouble();
        final showOfflineModels =
            _supportsSherpaModelManagement &&
                selectedEngine == SpeechToTextEngine.sherpa ||
            _isLinux && selectedEngine == SpeechToTextEngine.native ||
            _supportsMoonshine &&
                selectedEngine == SpeechToTextEngine.moonshine ||
            _supportsParakeet &&
                selectedEngine == SpeechToTextEngine.parakeet ||
            _supportsSenseVoice &&
                selectedEngine == SpeechToTextEngine.sensevoice;
        return ListView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          children: [
            SettingsSectionIntro(
              title: context.l10n.speechSpeechText,
              description: context.l10n.speechChooseRecognitionEngine,
            ),
            const SizedBox(height: 16),
            SettingsGroupHeader(title: context.l10n.settingsGroupVoiceInput),
            const SizedBox(height: 8),
            _buildEngineCard(settingsProvider),
            const SizedBox(height: 12),
            _buildSilenceCard(
              settingsProvider: settingsProvider,
              silenceValue: silenceValue,
            ),
            if (showOfflineModels) ...[
              const SizedBox(height: 20),
              SettingsGroupHeader(
                title: context.l10n.settingsGroupOfflineModels,
              ),
            ],
            if (_supportsSherpaModelManagement &&
                selectedEngine == SpeechToTextEngine.sherpa) ...[
              const SizedBox(height: 8),
              _buildLinuxModelCard(settingsProvider),
            ],
            if (_isLinux && selectedEngine == SpeechToTextEngine.native) ...[
              const SizedBox(height: 8),
              _buildSherpaModelHintCard(),
            ],
            if (_supportsMoonshine &&
                selectedEngine == SpeechToTextEngine.moonshine) ...[
              const SizedBox(height: 8),
              _buildMoonshineModelCard(settingsProvider),
            ],
            if (_supportsParakeet &&
                selectedEngine == SpeechToTextEngine.parakeet) ...[
              const SizedBox(height: 8),
              _buildParakeetModelCard(settingsProvider),
            ],
            if (_supportsSenseVoice &&
                selectedEngine == SpeechToTextEngine.sensevoice) ...[
              const SizedBox(height: 8),
              _buildSenseVoiceModelCard(settingsProvider),
            ],
            const SizedBox(height: 20),
            SettingsGroupHeader(title: context.l10n.settingsGroupReadAloud),
            const SizedBox(height: 8),
            _buildReadAloudCard(settingsProvider),
          ],
        );
      },
    );
  }

  Widget _buildEngineCard(SettingsProvider settingsProvider) {
    final selectedEngine = settingsProvider.speechToTextEngine;
    final sherpaEnabled = _supportsSherpa;
    final moonshineEnabled = _supportsMoonshine;
    final parakeetEnabled = _supportsParakeet;
    final senseVoiceEnabled = _supportsSenseVoice;
    final nativeEnabled = SpeechEnginePlatformSupport.isNativeSupported;
    final nativeUnavailableHint = switch (defaultTargetPlatform) {
      TargetPlatform.windows =>
        'Disabled on Windows for stability. Use Parakeet or another on-device engine through CodeWalk WASAPI capture.',
      TargetPlatform.linux =>
        'Unavailable on Linux. Use Parakeet for speech input.',
      _ => 'Not available on this platform.',
    };
    final sherpaUnavailableHint = switch (defaultTargetPlatform) {
      TargetPlatform.android =>
        'Unavailable on Android builds optimized for small APK size.',
      _ => 'Not available on this platform.',
    };
    final moonshineUnavailableHint = switch (defaultTargetPlatform) {
      _ => 'Available on desktop only. Android stays native-only.',
    };
    final parakeetUnavailableHint = switch (defaultTargetPlatform) {
      _ => 'Available on desktop only. Uses offline multilingual recognition.',
    };
    final senseVoiceUnavailableHint = switch (defaultTargetPlatform) {
      _ =>
        'Available on desktop only. Strongest for Chinese, Cantonese, Japanese, Korean, and English.',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.speechEngine,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.speechNativeStartsFaster,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            RadioGroup<SpeechToTextEngine>(
              groupValue: selectedEngine,
              onChanged: (value) {
                if (value == null) return;
                unawaited(settingsProvider.setSpeechToTextEngine(value));
              },
              child: Column(
                children: [
                  RadioListTile<SpeechToTextEngine>(
                    contentPadding: EdgeInsets.zero,
                    value: SpeechToTextEngine.native,
                    enabled: nativeEnabled,
                    title: Text(context.l10n.speechNative),
                    subtitle: Text(
                      nativeEnabled
                          ? 'Simpler and faster startup.'
                          : nativeUnavailableHint,
                    ),
                  ),
                  if (!nativeEnabled)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Symbols.info,
                            size: 16,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isWindows
                                  ? context.l10n.speechNativeSTTWorks
                                  : context.l10n.speechNativeSTTDisabled,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_isWindows) ...[
                    const SizedBox(height: 4),
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Symbols.info,
                                size: 18,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSecondaryContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  context.l10n.speechWindowsSetupHint,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSecondaryContainer,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Symbols.mic),
                                label: Text(
                                  context.l10n.speechOpenMicrophoneSettings,
                                ),
                                onPressed: () => unawaited(
                                  WindowsSettingsLinks.openMicrophonePrivacy(),
                                ),
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Symbols.speech_to_text),
                                label: Text(
                                  context.l10n.speechOpenSpeechPrivacy,
                                ),
                                onPressed: () => unawaited(
                                  WindowsSettingsLinks.openSpeechPrivacy(),
                                ),
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Symbols.translate),
                                label: Text(
                                  context.l10n.speechOpenSpeechSettings,
                                ),
                                onPressed: () => unawaited(
                                  WindowsSettingsLinks.openSpeech(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Divider(height: 1),
                  RadioListTile<SpeechToTextEngine>(
                    contentPadding: EdgeInsets.zero,
                    value: SpeechToTextEngine.sherpa,
                    enabled: sherpaEnabled,
                    title: Text(context.l10n.speechSherpa),
                    subtitle: Text(
                      sherpaEnabled
                          ? 'Heavier, experimental, and bug-prone. Often more precise with downloaded models.'
                          : sherpaUnavailableHint,
                    ),
                  ),
                  if (sherpaEnabled) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Symbols.warning_amber_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.l10n.speechSherpaExperimentalFail,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Divider(height: 1),
                  RadioListTile<SpeechToTextEngine>(
                    contentPadding: EdgeInsets.zero,
                    value: SpeechToTextEngine.moonshine,
                    enabled: moonshineEnabled,
                    title: Text(context.l10n.speechMoonshine),
                    subtitle: Text(
                      moonshineEnabled
                          ? 'Desktop-only experimental path using sherpa_onnx offline recognition and downloadable models.'
                          : moonshineUnavailableHint,
                    ),
                  ),
                  const Divider(height: 1),
                  RadioListTile<SpeechToTextEngine>(
                    contentPadding: EdgeInsets.zero,
                    value: SpeechToTextEngine.parakeet,
                    enabled: parakeetEnabled,
                    title: Text(context.l10n.speechParakeet),
                    subtitle: Text(
                      parakeetEnabled
                          ? 'Desktop-only offline NeMo transducer path with one multilingual downloadable model.'
                          : parakeetUnavailableHint,
                    ),
                  ),
                  const Divider(height: 1),
                  RadioListTile<SpeechToTextEngine>(
                    contentPadding: EdgeInsets.zero,
                    value: SpeechToTextEngine.sensevoice,
                    enabled: senseVoiceEnabled,
                    title: Text(context.l10n.speechSenseVoice),
                    subtitle: Text(
                      senseVoiceEnabled
                          ? 'Desktop-only offline path tuned for Chinese, Cantonese, Japanese, Korean, and English.'
                          : senseVoiceUnavailableHint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSherpaModelHintCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Symbols.info, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.l10n.speechSelectSherpaAbove,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSilenceCard({
    required SettingsProvider settingsProvider,
    required double silenceValue,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.speechAutoStopSilence,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.speechListeningStopsAutomatically,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Slider.adaptive(
              min: 2,
              max: 10,
              divisions: 8,
              label: '${silenceValue.round()}s',
              value: silenceValue,
              onChanged: (value) {
                setState(() {
                  _silenceDraftSeconds = value;
                });
              },
              onChangeEnd: (value) {
                final seconds = value.round();
                setState(() {
                  _silenceDraftSeconds = null;
                });
                unawaited(
                  settingsProvider.setSpeechSilenceTimeoutSeconds(seconds),
                );
              },
            ),
            Text(
              '${silenceValue.round()} seconds',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoonshineModelCard(SettingsProvider settingsProvider) {
    final selectedId = _normalizeMoonshineSelection(
      settingsProvider.moonshineModelId,
    );
    final installed = _moonshineInstalledById[selectedId] ?? false;
    _SherpaModelEntry? selectedModel;
    for (final model in _moonshineModels) {
      if (model.code == selectedId) {
        selectedModel = model;
        break;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.speechMoonshineModelsDesktop,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.speechMoonshineStaysDownloadable,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (_loadingMoonshineModels)
              const Center(child: CircularProgressIndicator())
            else ...[
              DropdownButtonFormField<String>(
                initialValue: selectedId,
                decoration: const InputDecoration(
                  labelText: 'Moonshine model',
                  border: OutlineInputBorder(),
                ),
                items: _moonshineModels
                    .map(
                      (model) => DropdownMenuItem<String>(
                        value: model.code,
                        child: Text(model.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _isMutatingMoonshineModel
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }
                        _moonshineModelManager.setPreferredModelId(value);
                        unawaited(settingsProvider.setMoonshineModelId(value));
                        setState(() {
                          _moonshineModelError = null;
                        });
                      },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Chip(
                    avatar: Icon(
                      installed ? Symbols.check_circle_outline : Symbols.info,
                      size: 18,
                    ),
                    label: Text(
                      installed
                          ? 'Model installed (${selectedId.toUpperCase()})'
                          : 'Model missing (${selectedId.toUpperCase()})',
                    ),
                  ),
                  const Spacer(),
                  if (selectedModel != null)
                    Text(
                      '~${selectedModel.sizeMb} MB',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _isMutatingMoonshineModel || installed
                        ? null
                        : () => unawaited(_downloadMoonshineModel(selectedId)),
                    icon: const Icon(Symbols.download_rounded),
                    label: Text(context.l10n.speechDownload),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _isMutatingMoonshineModel || !installed
                        ? null
                        : () => unawaited(_deleteMoonshineModel(selectedId)),
                    icon: const Icon(Symbols.delete_outline),
                    label: Text(context.l10n.speechRemove),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: context.l10n.settingsSpeechRefreshStatus,
                    onPressed: _isMutatingMoonshineModel
                        ? null
                        : () => unawaited(_refreshMoonshineModelStatuses()),
                    icon: const Icon(Symbols.refresh_rounded),
                  ),
                ],
              ),
              if (_isMutatingMoonshineModel) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: _moonshineDownloadProgress > 0
                      ? _moonshineDownloadProgress
                      : null,
                ),
              ],
              if (_moonshineModelError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _moonshineModelError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildParakeetModelCard(SettingsProvider settingsProvider) {
    final selectedId = _normalizeParakeetSelection(
      settingsProvider.parakeetModelId,
    );
    final installed = _parakeetInstalledById[selectedId] ?? false;
    _SherpaModelEntry? selectedModel;
    for (final model in _parakeetModels) {
      if (model.code == selectedId) {
        selectedModel = model;
        break;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.speechParakeetModelsDesktop,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.speechParakeetStaysDownloadable,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (_loadingParakeetModels)
              const Center(child: CircularProgressIndicator())
            else ...[
              DropdownButtonFormField<String>(
                initialValue: selectedId,
                decoration: const InputDecoration(
                  labelText: 'Parakeet model',
                  border: OutlineInputBorder(),
                ),
                items: _parakeetModels
                    .map(
                      (model) => DropdownMenuItem<String>(
                        value: model.code,
                        child: Text(model.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _isMutatingParakeetModel
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }
                        _parakeetModelManager.setPreferredModelId(value);
                        unawaited(settingsProvider.setParakeetModelId(value));
                        setState(() {
                          _parakeetModelError = null;
                        });
                      },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Chip(
                    avatar: Icon(
                      installed ? Symbols.check_circle_outline : Symbols.info,
                      size: 18,
                    ),
                    label: Text(
                      installed
                          ? 'Model installed (${selectedId.toUpperCase()})'
                          : 'Model missing (${selectedId.toUpperCase()})',
                    ),
                  ),
                  const Spacer(),
                  if (selectedModel != null)
                    Text(
                      '~${selectedModel.sizeMb} MB',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _isMutatingParakeetModel || installed
                        ? null
                        : () => unawaited(_downloadParakeetModel(selectedId)),
                    icon: const Icon(Symbols.download_rounded),
                    label: Text(context.l10n.speechDownload),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _isMutatingParakeetModel || !installed
                        ? null
                        : () => unawaited(_deleteParakeetModel(selectedId)),
                    icon: const Icon(Symbols.delete_outline),
                    label: Text(context.l10n.speechRemove),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: context.l10n.settingsSpeechRefreshStatus,
                    onPressed: _isMutatingParakeetModel
                        ? null
                        : () => unawaited(_refreshParakeetModelStatuses()),
                    icon: const Icon(Symbols.refresh_rounded),
                  ),
                ],
              ),
              if (_isMutatingParakeetModel) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: _parakeetDownloadProgress > 0
                      ? _parakeetDownloadProgress
                      : null,
                ),
              ],
              if (_parakeetModelError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _parakeetModelError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSenseVoiceModelCard(SettingsProvider settingsProvider) {
    final selectedId = _normalizeSenseVoiceSelection(
      settingsProvider.senseVoiceModelId,
    );
    final installed = _senseVoiceInstalledById[selectedId] ?? false;
    _SherpaModelEntry? selectedModel;
    for (final model in _senseVoiceModels) {
      if (model.code == selectedId) {
        selectedModel = model;
        break;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.speechSenseVoiceModelsDesktop,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.speechSenseVoiceStaysDownloadable,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (_loadingSenseVoiceModels)
              const Center(child: CircularProgressIndicator())
            else ...[
              DropdownButtonFormField<String>(
                initialValue: selectedId,
                decoration: const InputDecoration(
                  labelText: 'SenseVoice model',
                  border: OutlineInputBorder(),
                ),
                items: _senseVoiceModels
                    .map(
                      (model) => DropdownMenuItem<String>(
                        value: model.code,
                        child: Text(model.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _isMutatingSenseVoiceModel
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }
                        _senseVoiceModelManager.setPreferredModelId(value);
                        unawaited(settingsProvider.setSenseVoiceModelId(value));
                        setState(() {
                          _senseVoiceModelError = null;
                        });
                      },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Chip(
                    avatar: Icon(
                      installed ? Symbols.check_circle_outline : Symbols.info,
                      size: 18,
                    ),
                    label: Text(
                      installed
                          ? 'Model installed (${selectedId.toUpperCase()})'
                          : 'Model missing (${selectedId.toUpperCase()})',
                    ),
                  ),
                  const Spacer(),
                  if (selectedModel != null)
                    Text(
                      '~${selectedModel.sizeMb} MB',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _isMutatingSenseVoiceModel || installed
                        ? null
                        : () => unawaited(_downloadSenseVoiceModel(selectedId)),
                    icon: const Icon(Symbols.download_rounded),
                    label: Text(context.l10n.speechDownload),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _isMutatingSenseVoiceModel || !installed
                        ? null
                        : () => unawaited(_deleteSenseVoiceModel(selectedId)),
                    icon: const Icon(Symbols.delete_outline),
                    label: Text(context.l10n.speechRemove),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: context.l10n.settingsSpeechRefreshStatus,
                    onPressed: _isMutatingSenseVoiceModel
                        ? null
                        : () => unawaited(_refreshSenseVoiceModelStatuses()),
                    icon: const Icon(Symbols.refresh_rounded),
                  ),
                ],
              ),
              if (_isMutatingSenseVoiceModel) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: _senseVoiceDownloadProgress > 0
                      ? _senseVoiceDownloadProgress
                      : null,
                ),
              ],
              if (_senseVoiceModelError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _senseVoiceModelError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLinuxModelCard(SettingsProvider settingsProvider) {
    final selectedCode = _normalizeLanguageSelection(
      settingsProvider.sherpaLanguageCode,
    );
    final effectiveCode = _effectiveLanguageCode(selectedCode);
    _SherpaModelEntry? selectedModel;
    for (final model in _models) {
      if (model.code == effectiveCode) {
        selectedModel = model;
        break;
      }
    }
    final installed = _installedByCode[effectiveCode] ?? false;
    final installedLabels = _models
        .where((model) => _installedByCode[model.code] == true)
        .map((model) => model.label)
        .toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.speechSherpaModelsLinux,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.speechPickLanguagePacks,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (_loadingModels)
              const Center(child: CircularProgressIndicator())
            else ...[
              SearchableDropdownFormField<String>(
                value: selectedCode,
                decoration: const InputDecoration(
                  labelText: 'Sherpa language',
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                searchHintText: 'Search Sherpa language',
                emptyText: 'No language packs found',
                searchTermsBuilder: (value) {
                  if (value == kSherpaLanguageSystem) {
                    return <String>[
                      'system default',
                      _modelManager.detectSystemLanguage(),
                    ];
                  }
                  for (final model in _models) {
                    if (model.code == value) {
                      return <String>[model.code, model.label];
                    }
                  }
                  return <String>[value];
                },
                items: [
                  DropdownMenuItem<String>(
                    value: kSherpaLanguageSystem,
                    child: Text(
                      'System default (${_modelManager.detectSystemLanguage().toUpperCase()})',
                    ),
                  ),
                  ..._models.map(
                    (model) => DropdownMenuItem<String>(
                      value: model.code,
                      child: Text(model.label),
                    ),
                  ),
                ],
                onChanged: _isMutatingModel
                    ? null
                    : (value) {
                        if (value == null) return;
                        final nextCode = _effectiveLanguageCode(value);
                        _modelManager.setPreferredLanguage(nextCode);
                        unawaited(
                          settingsProvider.setSherpaLanguageCode(value),
                        );
                        setState(() {
                          _modelError = null;
                        });
                      },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Chip(
                    avatar: Icon(
                      installed ? Symbols.check_circle_outline : Symbols.info,
                      size: 18,
                    ),
                    label: Text(
                      installed
                          ? 'Model installed (${effectiveCode.toUpperCase()})'
                          : 'Model missing (${effectiveCode.toUpperCase()})',
                    ),
                  ),
                  const Spacer(),
                  if (selectedModel != null)
                    Text(
                      '~${selectedModel.sizeMb} MB',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _isMutatingModel || installed
                        ? null
                        : () => unawaited(_downloadModel(effectiveCode)),
                    icon: const Icon(Symbols.download_rounded),
                    label: Text(context.l10n.speechDownload),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _isMutatingModel || !installed
                        ? null
                        : () => unawaited(_deleteModel(effectiveCode)),
                    icon: const Icon(Symbols.delete_outline),
                    label: Text(context.l10n.speechRemove),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: context.l10n.settingsSpeechRefreshStatus,
                    onPressed: _isMutatingModel
                        ? null
                        : () => unawaited(_refreshModelStatuses()),
                    icon: const Icon(Symbols.refresh_rounded),
                  ),
                ],
              ),
              if (_isMutatingModel) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: _downloadProgress > 0 ? _downloadProgress : null,
                ),
              ],
              if (_modelError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _modelError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (installedLabels.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  context.l10n.speechInstalledLanguages,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: installedLabels
                      .map((label) => Chip(label: Text(label)))
                      .toList(growable: false),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _loadModelCatalog() async {
    setState(() {
      _loadingModels = true;
      _modelError = null;
    });
    try {
      final raw = await rootBundle.loadString('assets/sherpa_models.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final entries = (json['models'] as List)
          .map((entry) {
            final map = entry as Map<String, dynamic>;
            return _SherpaModelEntry(
              code: map['code'] as String,
              label: map['label'] as String,
              sizeMb: (map['size_mb'] as num).toInt(),
            );
          })
          .toList(growable: false);
      _models = entries;
      await _refreshModelStatuses();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _modelError = 'Failed to load Sherpa model catalog: $error';
        _loadingModels = false;
      });
    }
  }

  Future<void> _loadMoonshineModelCatalog() async {
    setState(() {
      _loadingMoonshineModels = true;
      _moonshineModelError = null;
    });
    try {
      final raw = await rootBundle.loadString('assets/moonshine_models.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final entries = (json['models'] as List)
          .map((entry) {
            final map = entry as Map<String, dynamic>;
            return _SherpaModelEntry(
              code: map['id'] as String,
              label: map['label'] as String,
              sizeMb: (map['size_mb'] as num).toInt(),
            );
          })
          .toList(growable: false);
      _moonshineModels = entries;
      await _refreshMoonshineModelStatuses();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _moonshineModelError = 'Failed to load Moonshine model catalog: $error';
        _loadingMoonshineModels = false;
      });
    }
  }

  Future<void> _loadParakeetModelCatalog() async {
    setState(() {
      _loadingParakeetModels = true;
      _parakeetModelError = null;
    });
    try {
      final raw = await rootBundle.loadString('assets/parakeet_models.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final entries = (json['models'] as List)
          .map((entry) {
            final map = entry as Map<String, dynamic>;
            return _SherpaModelEntry(
              code: map['id'] as String,
              label: map['label'] as String,
              sizeMb: (map['size_mb'] as num).toInt(),
            );
          })
          .toList(growable: false);
      _parakeetModels = entries;
      await _refreshParakeetModelStatuses();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _parakeetModelError = 'Failed to load Parakeet model catalog: $error';
        _loadingParakeetModels = false;
      });
    }
  }

  Future<void> _loadSenseVoiceModelCatalog() async {
    setState(() {
      _loadingSenseVoiceModels = true;
      _senseVoiceModelError = null;
    });
    try {
      final raw = await rootBundle.loadString('assets/sensevoice_models.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final entries = (json['models'] as List)
          .map((entry) {
            final map = entry as Map<String, dynamic>;
            return _SherpaModelEntry(
              code: map['id'] as String,
              label: map['label'] as String,
              sizeMb: (map['size_mb'] as num).toInt(),
            );
          })
          .toList(growable: false);
      _senseVoiceModels = entries;
      await _refreshSenseVoiceModelStatuses();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _senseVoiceModelError =
            'Failed to load SenseVoice model catalog: $error';
        _loadingSenseVoiceModels = false;
      });
    }
  }

  Future<void> _refreshModelStatuses() async {
    if (_models.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _installedByCode = const <String, bool>{};
        _loadingModels = false;
      });
      return;
    }
    final statuses = <String, bool>{};
    for (final model in _models) {
      statuses[model.code] = await _modelManager.hasModel(model.code);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _installedByCode = statuses;
      _loadingModels = false;
    });
  }

  Future<void> _downloadModel(String code) async {
    setState(() {
      _isMutatingModel = true;
      _downloadProgress = 0;
      _modelError = null;
    });
    try {
      await _modelManager.downloadModel(
        code,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _downloadProgress = progress;
          });
        },
      );
      _modelManager.setPreferredLanguage(code);
      if (!mounted) {
        return;
      }
      final settingsProvider = context.read<SettingsProvider>();
      await settingsProvider.setSherpaLanguageCode(code);
      await _refreshModelStatuses();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _modelError = 'Download failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isMutatingModel = false;
          _downloadProgress = 0;
        });
      }
    }
  }

  Future<void> _refreshMoonshineModelStatuses() async {
    if (_moonshineModels.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _moonshineInstalledById = const <String, bool>{};
        _loadingMoonshineModels = false;
      });
      return;
    }
    final statuses = <String, bool>{};
    for (final model in _moonshineModels) {
      statuses[model.code] = await _moonshineModelManager.hasModel(model.code);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _moonshineInstalledById = statuses;
      _loadingMoonshineModels = false;
    });
  }

  Future<void> _refreshParakeetModelStatuses() async {
    if (_parakeetModels.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _parakeetInstalledById = const <String, bool>{};
        _loadingParakeetModels = false;
      });
      return;
    }
    final statuses = <String, bool>{};
    for (final model in _parakeetModels) {
      statuses[model.code] = await _parakeetModelManager.hasModel(model.code);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _parakeetInstalledById = statuses;
      _loadingParakeetModels = false;
    });
  }

  Future<void> _refreshSenseVoiceModelStatuses() async {
    if (_senseVoiceModels.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _senseVoiceInstalledById = const <String, bool>{};
        _loadingSenseVoiceModels = false;
      });
      return;
    }
    final statuses = <String, bool>{};
    for (final model in _senseVoiceModels) {
      statuses[model.code] = await _senseVoiceModelManager.hasModel(model.code);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _senseVoiceInstalledById = statuses;
      _loadingSenseVoiceModels = false;
    });
  }

  Future<void> _deleteModel(String code) async {
    setState(() {
      _isMutatingModel = true;
      _modelError = null;
    });
    try {
      await _modelManager.deleteModel(code);
      await _refreshModelStatuses();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _modelError = 'Failed to remove model: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isMutatingModel = false;
        });
      }
    }
  }

  Future<void> _downloadMoonshineModel(String modelId) async {
    setState(() {
      _isMutatingMoonshineModel = true;
      _moonshineDownloadProgress = 0;
      _moonshineModelError = null;
    });
    try {
      await _moonshineModelManager.downloadModel(
        modelId,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _moonshineDownloadProgress = progress;
          });
        },
      );
      _moonshineModelManager.setPreferredModelId(modelId);
      if (!mounted) {
        return;
      }
      final settingsProvider = context.read<SettingsProvider>();
      await settingsProvider.setMoonshineModelId(modelId);
      await _refreshMoonshineModelStatuses();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _moonshineModelError = 'Download failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isMutatingMoonshineModel = false;
          _moonshineDownloadProgress = 0;
        });
      }
    }
  }

  Future<void> _deleteMoonshineModel(String modelId) async {
    setState(() {
      _isMutatingMoonshineModel = true;
      _moonshineModelError = null;
    });
    try {
      await _moonshineModelManager.deleteModel(modelId);
      await _refreshMoonshineModelStatuses();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _moonshineModelError = 'Failed to remove model: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isMutatingMoonshineModel = false;
        });
      }
    }
  }

  Future<void> _downloadParakeetModel(String modelId) async {
    setState(() {
      _isMutatingParakeetModel = true;
      _parakeetDownloadProgress = 0;
      _parakeetModelError = null;
    });
    try {
      await _parakeetModelManager.downloadModel(
        modelId,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _parakeetDownloadProgress = progress;
          });
        },
      );
      _parakeetModelManager.setPreferredModelId(modelId);
      if (!mounted) {
        return;
      }
      final settingsProvider = context.read<SettingsProvider>();
      await settingsProvider.setParakeetModelId(modelId);
      await _refreshParakeetModelStatuses();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _parakeetModelError = 'Download failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isMutatingParakeetModel = false;
          _parakeetDownloadProgress = 0;
        });
      }
    }
  }

  Future<void> _deleteParakeetModel(String modelId) async {
    setState(() {
      _isMutatingParakeetModel = true;
      _parakeetModelError = null;
    });
    try {
      await _parakeetModelManager.deleteModel(modelId);
      await _refreshParakeetModelStatuses();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _parakeetModelError = 'Failed to remove model: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isMutatingParakeetModel = false;
        });
      }
    }
  }

  Future<void> _downloadSenseVoiceModel(String modelId) async {
    setState(() {
      _isMutatingSenseVoiceModel = true;
      _senseVoiceDownloadProgress = 0;
      _senseVoiceModelError = null;
    });
    try {
      await _senseVoiceModelManager.downloadModel(
        modelId,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _senseVoiceDownloadProgress = progress;
          });
        },
      );
      _senseVoiceModelManager.setPreferredModelId(modelId);
      if (!mounted) {
        return;
      }
      final settingsProvider = context.read<SettingsProvider>();
      await settingsProvider.setSenseVoiceModelId(modelId);
      await _refreshSenseVoiceModelStatuses();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _senseVoiceModelError = 'Download failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isMutatingSenseVoiceModel = false;
          _senseVoiceDownloadProgress = 0;
        });
      }
    }
  }

  Future<void> _deleteSenseVoiceModel(String modelId) async {
    setState(() {
      _isMutatingSenseVoiceModel = true;
      _senseVoiceModelError = null;
    });
    try {
      await _senseVoiceModelManager.deleteModel(modelId);
      await _refreshSenseVoiceModelStatuses();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _senseVoiceModelError = 'Failed to remove model: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isMutatingSenseVoiceModel = false;
        });
      }
    }
  }

  String _normalizeLanguageSelection(String raw) {
    if (raw == kSherpaLanguageSystem) {
      return kSherpaLanguageSystem;
    }
    final matchesKnownModel = _models.any((model) => model.code == raw);
    if (matchesKnownModel) {
      return raw;
    }
    return kSherpaLanguageSystem;
  }

  String _effectiveLanguageCode(String selectedCode) {
    if (selectedCode == kSherpaLanguageSystem) {
      return _modelManager.detectSystemLanguage();
    }
    return selectedCode;
  }

  String _normalizeMoonshineSelection(String raw) {
    if (_moonshineModels.any((model) => model.code == raw)) {
      return raw;
    }
    return kMoonshineModelTiny;
  }

  String _normalizeParakeetSelection(String raw) {
    if (_parakeetModels.any((model) => model.code == raw)) {
      return raw;
    }
    return kParakeetModelDefault;
  }

  String _normalizeSenseVoiceSelection(String raw) {
    if (_senseVoiceModels.any((model) => model.code == raw)) {
      return raw;
    }
    return kSenseVoiceModelDefault;
  }

  Widget _buildReadAloudProviderSelector(SettingsProvider settingsProvider) {
    return DropdownButtonFormField<ReadAloudProvider>(
      initialValue: settingsProvider.readAloudProvider,
      decoration: const InputDecoration(
        labelText: 'Text-to-speech provider',
        border: OutlineInputBorder(),
      ),
      items: const <DropdownMenuItem<ReadAloudProvider>>[
        DropdownMenuItem(
          value: ReadAloudProvider.native,
          child: Text('System / Native'),
        ),
        DropdownMenuItem(
          value: ReadAloudProvider.edgeExperimental,
          child: Text('Microsoft Edge Speech (experimental)'),
        ),
        DropdownMenuItem(
          value: ReadAloudProvider.openAiCompatible,
          child: Text('OpenAI-compatible'),
        ),
      ],
      onChanged: (value) {
        if (value == null) return;
        unawaited(settingsProvider.setReadAloudProvider(value));
      },
    );
  }

  Widget _buildNativeReadAloudVoicePicker(SettingsProvider settingsProvider) {
    if (!di.sl.isRegistered<ReadAloudService>()) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<List<Map<String, String>>>(
      future: di.sl<ReadAloudService>().getVoicesForProvider(
        ReadAloudProvider.native,
      ),
      builder: (context, snapshot) {
        final voices = snapshot.data ?? const <Map<String, String>>[];
        if (voices.isEmpty) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.settingsReadAloudVoice),
            subtitle: Text(context.l10n.settingsReadAloudVoiceHint),
          );
        }
        final selected =
            voices.any(
              (voice) => voice['name'] == settingsProvider.readAloudVoiceId,
            )
            ? settingsProvider.readAloudVoiceId
            : null;
        return DropdownButtonFormField<String>(
          initialValue: selected,
          decoration: InputDecoration(
            labelText: context.l10n.settingsReadAloudVoice,
            helperText: context.l10n.settingsReadAloudVoiceHint,
          ),
          items: voices.map((voice) {
            final id = voice['name'] ?? '';
            final locale = voice['locale'] ?? '';
            final label = voice['label']?.isNotEmpty == true
                ? voice['label']!
                : locale.isNotEmpty
                ? '$id ($locale)'
                : id;
            return DropdownMenuItem<String>(value: id, child: Text(label));
          }).toList(),
          onChanged: (value) {
            final selectedVoice = voices.firstWhere(
              (voice) => voice['name'] == value,
              orElse: () => const <String, String>{},
            );
            unawaited(
              settingsProvider.setReadAloudVoiceSelection(
                id: value,
                locale: selectedVoice['locale'],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEdgeReadAloudNotice() {
    return const ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Symbols.experiment),
      title: Text('Microsoft Edge Speech is experimental'),
      subtitle: Text(
        'Uses the unofficial Edge Read Aloud service directly from this device. Message text is sent to Microsoft when you use read aloud, and the service may break if Microsoft changes the private protocol.',
      ),
    );
  }

  Widget _buildEdgeReadAloudVoicePicker(SettingsProvider settingsProvider) {
    if (!di.sl.isRegistered<ReadAloudService>()) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<List<Map<String, String>>>(
      future: _edgeReadAloudVoicesFuture ??= di
          .sl<ReadAloudService>()
          .getVoicesForProvider(ReadAloudProvider.edgeExperimental),
      builder: (context, snapshot) {
        final voices = snapshot.data ?? const <Map<String, String>>[];
        if (voices.isEmpty) {
          return const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Edge voice'),
            subtitle: Text(
              'Using the default Edge voice. Voice list could not be loaded right now.',
            ),
          );
        }
        final selected =
            voices.any(
              (voice) => voice['name'] == settingsProvider.readAloudVoiceId,
            )
            ? settingsProvider.readAloudVoiceId
            : null;
        return DropdownButtonFormField<String>(
          initialValue: selected,
          decoration: const InputDecoration(
            labelText: 'Edge voice',
            helperText: 'Loaded from Microsoft Edge Speech voices.',
          ),
          items: voices.map((voice) {
            final id = voice['name'] ?? '';
            final locale = voice['locale'] ?? '';
            final label = voice['label']?.isNotEmpty == true
                ? voice['label']!
                : locale.isNotEmpty
                ? '$id ($locale)'
                : id;
            return DropdownMenuItem<String>(value: id, child: Text(label));
          }).toList(),
          onChanged: (value) {
            final selectedVoice = voices.firstWhere(
              (voice) => voice['name'] == value,
              orElse: () => const <String, String>{},
            );
            unawaited(
              settingsProvider.setReadAloudVoiceSelection(
                id: value,
                locale: selectedVoice['locale'],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOpenAiCompatibleReadAloudFields(
    SettingsProvider settingsProvider,
  ) {
    final selectedVoice =
        kOpenAiCompatibleVoiceIds.contains(settingsProvider.readAloudVoiceId)
        ? settingsProvider.readAloudVoiceId
        : 'alloy';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Cloud TTS privacy'),
          subtitle: Text(
            'Cloud TTS sends the selected assistant message text to the configured provider. API keys are stored in secure storage on this device.',
          ),
        ),
        TextFormField(
          initialValue: settingsProvider.readAloudBaseUrl,
          decoration: const InputDecoration(
            labelText: 'Base URL',
            helperText: 'Example: https://api.openai.com/v1',
          ),
          keyboardType: TextInputType.url,
          onChanged: (value) =>
              unawaited(settingsProvider.setReadAloudBaseUrl(value)),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _readAloudApiKeyController,
          decoration: InputDecoration(
            labelText: 'API key',
            helperText: _hasOpenAiCompatibleApiKey
                ? 'A key is saved. Enter a new value to replace it, or save an empty value to remove it.'
                : 'No API key saved.',
            suffixIcon: _loadingReadAloudApiKey
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: 'Save API key',
                    icon: const Icon(Symbols.save),
                    onPressed: () => unawaited(_saveOpenAiCompatibleApiKey()),
                  ),
          ),
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          onFieldSubmitted: (_) => unawaited(_saveOpenAiCompatibleApiKey()),
        ),
        if (_readAloudApiKeyStatus != null) ...[
          const SizedBox(height: 8),
          Text(
            _readAloudApiKeyStatus!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 12),
        TextFormField(
          initialValue: settingsProvider.readAloudModel,
          decoration: const InputDecoration(
            labelText: 'Model',
            helperText: 'Default: gpt-4o-mini-tts',
          ),
          onChanged: (value) =>
              unawaited(settingsProvider.setReadAloudModel(value)),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: selectedVoice,
          decoration: const InputDecoration(labelText: 'Voice'),
          items: kOpenAiCompatibleVoiceIds
              .map(
                (voice) =>
                    DropdownMenuItem<String>(value: voice, child: Text(voice)),
              )
              .toList(),
          onChanged: (value) {
            unawaited(
              settingsProvider.setReadAloudVoiceSelection(
                id: value,
                locale: null,
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Pitch is not supported by OpenAI-compatible TTS and is hidden for this provider.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildReadAloudCard(SettingsProvider settingsProvider) {
    final readAloudProvider = settingsProvider.readAloudProvider;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.settingsReadAloudSectionTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.settingsReadAloudSectionDescription,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _buildReadAloudProviderSelector(settingsProvider),
            if (readAloudProvider != ReadAloudProvider.native) ...[
              const SizedBox(height: 8),
              Text(
                context.l10n.settingsSessionAttentionThirdPartyTtsWarning,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.settingsReadAloudEnabled),
              subtitle: Text(context.l10n.settingsReadAloudEnabledDescription),
              value: settingsProvider.readAloudEnabled,
              onChanged: (value) =>
                  unawaited(settingsProvider.setReadAloudEnabled(value)),
            ),
            if (readAloudProvider == ReadAloudProvider.native) ...[
              const Divider(height: 1),
              _buildNativeReadAloudVoicePicker(settingsProvider),
            ],
            if (readAloudProvider == ReadAloudProvider.edgeExperimental) ...[
              const Divider(height: 1),
              _buildEdgeReadAloudNotice(),
              _buildEdgeReadAloudVoicePicker(settingsProvider),
            ],
            if (readAloudProvider == ReadAloudProvider.openAiCompatible) ...[
              const Divider(height: 1),
              _buildOpenAiCompatibleReadAloudFields(settingsProvider),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Symbols.play_arrow),
                label: const Text('Test voice'),
                onPressed: () =>
                    unawaited(_testReadAloudVoice(settingsProvider)),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.settingsReadAloudSpeed),
              subtitle: Text(context.l10n.settingsReadAloudSpeedDescription),
              trailing: SizedBox(
                width: 120,
                child: Slider(
                  value: settingsProvider.readAloudRate,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  label: settingsProvider.readAloudRate.toStringAsFixed(1),
                  onChanged: (value) =>
                      unawaited(settingsProvider.setReadAloudRate(value)),
                ),
              ),
            ),
            if (readAloudProvider == ReadAloudProvider.native) ...[
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.settingsReadAloudPitch),
                subtitle: Text(context.l10n.settingsReadAloudPitchDescription),
                trailing: SizedBox(
                  width: 120,
                  child: Slider(
                    value: settingsProvider.readAloudPitch,
                    min: 0.5,
                    max: 2.0,
                    divisions: 6,
                    label: settingsProvider.readAloudPitch.toStringAsFixed(1),
                    onChanged: (value) =>
                        unawaited(settingsProvider.setReadAloudPitch(value)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
