import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../../core/auth/tts_api_key_storage.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/i18n/l10n_context.dart';
import '../../../../domain/entities/experience_settings.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/read_aloud_service.dart';
import '../../../services/tts/openai_compatible_tts_backend.dart';
import '../../../widgets/searchable_dropdown_form_field.dart';
import '../widgets/settings_section_layout.dart';

const String kCustomModelKey = '__codewalk_custom_model__';

class TextToSpeechSettingsSection extends StatefulWidget {
  const TextToSpeechSettingsSection({super.key});

  @override
  State<TextToSpeechSettingsSection> createState() =>
      _TextToSpeechSettingsSectionState();
}

class _TextToSpeechSettingsSectionState
    extends State<TextToSpeechSettingsSection> {
  final TextEditingController _readAloudApiKeyController =
      TextEditingController();
  bool _loadingReadAloudApiKey = false;
  bool _hasReadAloudApiKey = false;
  String? _readAloudApiKeyStatus;
  int _readAloudApiKeyGeneration = 0;
  ReadAloudProvider? _lastSeenReadAloudProvider;
  String? _remoteVoicePendingKey;
  final Map<String, Future<List<Map<String, String>>>>
  _remoteReadAloudVoicesCache =
      <String, Future<List<Map<String, String>>>>{};
  String? _remoteModelsPendingKey;
  final Map<String, Future<List<Map<String, String>>>> _remoteModelsCache =
      <String, Future<List<Map<String, String>>>>{};
  bool _editingCustomModel = false;
  Future<List<Map<String, String>>>? _edgeReadAloudVoicesFuture;

  @override
  void initState() {
    super.initState();
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
    final provider = context.read<SettingsProvider>().readAloudProvider;
    final generation = ++_readAloudApiKeyGeneration;
    setState(() {
      _loadingReadAloudApiKey = true;
      _readAloudApiKeyStatus = null;
    });
    try {
      final key = await di.sl<TtsApiKeyStorage>().read(provider);
      if (!mounted || generation != _readAloudApiKeyGeneration) return;
      setState(() {
        _hasReadAloudApiKey = key != null && key.isNotEmpty;
        _loadingReadAloudApiKey = false;
      });
    } catch (_) {
      if (!mounted || generation != _readAloudApiKeyGeneration) return;
      setState(() {
        _loadingReadAloudApiKey = false;
        _readAloudApiKeyStatus = context.l10n.speechApiKeyStorageUnavailable;
      });
    }
  }

  Future<void> _saveReadAloudApiKey() async {
    if (!di.sl.isRegistered<TtsApiKeyStorage>()) {
      setState(() {
        _readAloudApiKeyStatus = context.l10n.speechApiKeyStorageUnavailable;
      });
      return;
    }
    final settingsProvider = context.read<SettingsProvider>();
    final provider = settingsProvider.readAloudProvider;
    final value = _readAloudApiKeyController.text;
    final generation = ++_readAloudApiKeyGeneration;
    final savedCacheKey = _remoteVoiceCacheKey(settingsProvider);
    final savedModelsCacheKey = _remoteModelsCacheKey(settingsProvider);
    setState(() {
      _loadingReadAloudApiKey = true;
      _readAloudApiKeyStatus = null;
    });
    try {
      await di.sl<TtsApiKeyStorage>().write(provider, value);
      _readAloudApiKeyController.clear();
      // Only invalidate the discovery state captured at save start. If the
      // provider or base URL changed while the key was being written, that
      // other path owns the pending/cache state and clearing it here would
      // drop a freshly armed reload.
      if (_remoteVoiceCacheKey(settingsProvider) == savedCacheKey) {
        _remoteReadAloudVoicesCache.clear();
        _remoteVoicePendingKey = savedCacheKey;
      }
      if (_remoteModelsCacheKey(settingsProvider) == savedModelsCacheKey) {
        _remoteModelsCache.clear();
        _remoteModelsPendingKey = savedModelsCacheKey;
        _editingCustomModel = false;
      }
      if (!mounted || generation != _readAloudApiKeyGeneration) return;
      setState(() {
        _hasReadAloudApiKey = value.trim().isNotEmpty;
        _loadingReadAloudApiKey = false;
        _readAloudApiKeyStatus = value.trim().isEmpty
            ? context.l10n.speechApiKeyRemoved
            : context.l10n.speechApiKeySaved;
      });
    } catch (_) {
      if (!mounted || generation != _readAloudApiKeyGeneration) return;
      setState(() {
        _loadingReadAloudApiKey = false;
        _readAloudApiKeyStatus = context.l10n.speechApiKeyStorageUnavailable;
      });
    }
  }

  Future<List<Map<String, String>>> _remoteReadAloudVoices({
    required ReadAloudProvider provider,
    required SettingsProvider settingsProvider,
  }) async {
    if (!di.sl.isRegistered<ReadAloudService>()) {
      return const <Map<String, String>>[];
    }
    final baseUrl = settingsProvider.readAloudBaseUrl;
    final parsedBaseUrl = Uri.tryParse(baseUrl);
    if (parsedBaseUrl == null ||
        !parsedBaseUrl.hasScheme ||
        !parsedBaseUrl.hasAuthority ||
        !(parsedBaseUrl.scheme == 'http' || parsedBaseUrl.scheme == 'https')) {
      return const <Map<String, String>>[];
    }
    String? apiKey;
    if (di.sl.isRegistered<TtsApiKeyStorage>()) {
      try {
        apiKey = await di.sl<TtsApiKeyStorage>().read(provider);
      } catch (_) {
        apiKey = null;
      }
    }
    return di.sl<ReadAloudService>().getVoicesForProvider(
      provider,
      apiKey: apiKey,
      baseUrl: baseUrl,
      model: settingsProvider.readAloudModel,
    );
  }

  Future<List<Map<String, String>>> _remoteReadAloudModels({
    required ReadAloudProvider provider,
    required SettingsProvider settingsProvider,
  }) async {
    if (!di.sl.isRegistered<ReadAloudService>()) {
      return const <Map<String, String>>[];
    }
    // NVIDIA NIM exposes a static curated list (no listing endpoint), so it
    // does not require a reachable base URL or a saved key.
    if (provider == ReadAloudProvider.nim) {
      return di.sl<ReadAloudService>().getModelsForProvider(provider);
    }
    final baseUrl = settingsProvider.readAloudBaseUrl;
    final parsedBaseUrl = Uri.tryParse(baseUrl);
    if (parsedBaseUrl == null ||
        !parsedBaseUrl.hasScheme ||
        !parsedBaseUrl.hasAuthority ||
        !(parsedBaseUrl.scheme == 'http' || parsedBaseUrl.scheme == 'https')) {
      return const <Map<String, String>>[];
    }
    String? apiKey;
    if (di.sl.isRegistered<TtsApiKeyStorage>()) {
      try {
        apiKey = await di.sl<TtsApiKeyStorage>().read(provider);
      } catch (_) {
        apiKey = null;
      }
    }
    return di.sl<ReadAloudService>().getModelsForProvider(
      provider,
      apiKey: apiKey,
      baseUrl: baseUrl,
      model: settingsProvider.readAloudModel,
    );
  }

  String _resolvedTestText(SettingsProvider settingsProvider) {
    final custom = settingsProvider.readAloudTestText.trim();
    return custom.isEmpty ? context.l10n.speechReadAloudTestText : custom;
  }

  Future<void> _testReadAloudVoice(SettingsProvider settingsProvider) async {
    if (!di.sl.isRegistered<ReadAloudService>()) {
      return;
    }
    final service = di.sl<ReadAloudService>();
    await service.speak(
      messageId: 'settings_read_aloud_test',
      text: _resolvedTestText(settingsProvider),
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

  /// Selection generation guard so a slow persistence operation cannot play a
  /// test for a model/voice the user already moved away from.
  int _selectionGeneration = 0;

  Future<void> _selectVoiceAndTest(
    SettingsProvider settingsProvider, {
    required String? id,
    String? locale,
  }) async {
    final generation = ++_selectionGeneration;
    await settingsProvider.setReadAloudVoiceSelection(id: id, locale: locale);
    if (!mounted || generation != _selectionGeneration) return;
    await _testReadAloudVoice(settingsProvider);
  }

  Future<void> _selectModelAndTest(
    SettingsProvider settingsProvider,
    String value,
  ) async {
    final generation = ++_selectionGeneration;
    await settingsProvider.setReadAloudModel(value);
    _requestRemoteVoiceReload();
    if (!mounted || generation != _selectionGeneration) return;
    await _testReadAloudVoice(settingsProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        final readAloudProvider = settingsProvider.readAloudProvider;
        if (readAloudProvider != _lastSeenReadAloudProvider) {
          _lastSeenReadAloudProvider = readAloudProvider;
          _readAloudApiKeyController.clear();
          _readAloudApiKeyStatus = null;
          _edgeReadAloudVoicesFuture = null;
          _remoteReadAloudVoicesCache.clear();
          _remoteVoicePendingKey = _remoteVoiceCacheKey(settingsProvider);
          _remoteModelsCache.clear();
          _remoteModelsPendingKey = _remoteModelsCacheKey(settingsProvider);
          _editingCustomModel = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _loadReadAloudApiKeyState();
            }
          });
        }
        return ListView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          children: [
            SettingsSectionIntro(
              title: context.l10n.settingsReadAloudSectionTitle,
              description: context.l10n.settingsReadAloudSectionDescription,
            ),
            const SizedBox(height: 16),
            _buildReadAloudCard(settingsProvider),
          ],
        );
      },
    );
  }

  Widget _buildReadAloudProviderSelector(SettingsProvider settingsProvider) {
    return DropdownButtonFormField<ReadAloudProvider>(
      initialValue: settingsProvider.readAloudProvider,
      decoration: InputDecoration(
        labelText: context.l10n.speechTextToSpeechProvider,
        border: const OutlineInputBorder(),
      ),
      items: <DropdownMenuItem<ReadAloudProvider>>[
        DropdownMenuItem(
          value: ReadAloudProvider.native,
          child: Text(context.l10n.speechProviderSystemNative),
        ),
        DropdownMenuItem(
          value: ReadAloudProvider.edgeExperimental,
          child: Text(context.l10n.speechProviderEdgeExperimental),
        ),
        DropdownMenuItem(
          value: ReadAloudProvider.openAiCompatible,
          child: Text(context.l10n.speechProviderOpenAiCompatible),
        ),
        DropdownMenuItem(
          value: ReadAloudProvider.elevenLabs,
          child: Text(context.l10n.speechProviderElevenLabs),
        ),
        DropdownMenuItem(
          value: ReadAloudProvider.nim,
          child: Text(context.l10n.speechProviderNvidiaNim),
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
        return SearchableDropdownFormField<String>(
          value: selected,
          decoration: InputDecoration(
            labelText: context.l10n.settingsReadAloudVoice,
            helperText: context.l10n.settingsReadAloudVoiceHint,
            border: const OutlineInputBorder(),
          ),
          isExpanded: true,
          searchTermsBuilder: (value) {
            for (final voice in voices) {
              if (voice['name'] == value) {
                return <String>[
                  value,
                  voice['locale'] ?? '',
                  voice['label'] ?? '',
                ];
              }
            }
            return <String>[value];
          },
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
            if (value == null) return;
            final selectedVoice = voices.firstWhere(
              (voice) => voice['name'] == value,
              orElse: () => const <String, String>{},
            );
            unawaited(
              _selectVoiceAndTest(
                settingsProvider,
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Symbols.experiment),
      title: Text(context.l10n.speechEdgeExperimentalTitle),
      subtitle: Text(context.l10n.speechEdgeExperimentalDescription),
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
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.speechEdgeVoice),
            subtitle: Text(context.l10n.speechEdgeVoiceListUnavailable),
          );
        }
        final savedVoiceId = settingsProvider.readAloudVoiceId;
        final voiceMissing =
            savedVoiceId != null &&
            savedVoiceId.trim().isNotEmpty &&
            !voices.any((voice) => voice['name'] == savedVoiceId);
        final selected = voices.any(
          (voice) => voice['name'] == savedVoiceId,
        )
            ? savedVoiceId
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (voiceMissing) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Symbols.warning_amber_rounded),
                title: Text(context.l10n.speechEdgeVoiceUnavailable),
                trailing: TextButton(
                  onPressed: () {
                    unawaited(
                      _selectVoiceAndTest(
                        settingsProvider,
                        id: null,
                        locale: null,
                      ),
                    );
                  },
                  child: Text(context.l10n.commonReset),
                ),
              ),
            ],
            SearchableDropdownFormField<String>(
              value: selected,
              decoration: InputDecoration(
                labelText: context.l10n.speechEdgeVoice,
                helperText: context.l10n.speechEdgeVoicesLoaded,
                border: const OutlineInputBorder(),
              ),
              isExpanded: true,
              searchTermsBuilder: (value) {
                for (final voice in voices) {
                  if (voice['name'] == value) {
                    return <String>[
                      value,
                      voice['locale'] ?? '',
                      voice['label'] ?? '',
                    ];
                  }
                }
                return <String>[value];
              },
              items: voices.map((voice) {
                final id = voice['name'] ?? '';
                final locale = voice['locale'] ?? '';
                final label = voice['label']?.isNotEmpty == true
                    ? voice['label']!
                    : locale.isNotEmpty
                    ? '$id ($locale)'
                    : id;
                return DropdownMenuItem<String>(
                  value: id,
                  child: Text(label),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                final selectedVoice = voices.firstWhere(
                  (voice) => voice['name'] == value,
                  orElse: () => const <String, String>{},
                );
                unawaited(
                  _selectVoiceAndTest(
                    settingsProvider,
                    id: value,
                    locale: selectedVoice['locale'],
                  ),
                );
              },
            ),
          ],
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
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.speechCloudTtsPrivacy),
          subtitle: Text(context.l10n.speechCloudTtsPrivacyDescription),
        ),
        TextFormField(
          key: ValueKey(
            'read-aloud-base-url-${settingsProvider.readAloudProvider.name}',
          ),
          initialValue: settingsProvider.readAloudBaseUrl,
          decoration: InputDecoration(
            labelText: context.l10n.speechBaseUrl,
            helperText: context.l10n.speechBaseUrlExample(
              'https://api.openai.com/v1',
            ),
          ),
          keyboardType: TextInputType.url,
          onChanged: (value) =>
              unawaited(settingsProvider.setReadAloudBaseUrl(value)),
        ),
        _buildReadAloudApiKeyField(),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey(
            'read-aloud-model-${settingsProvider.readAloudProvider.name}',
          ),
          initialValue: settingsProvider.readAloudModel,
          decoration: InputDecoration(
            labelText: context.l10n.speechModel,
            helperText: context.l10n.speechModelDefaultHelper(
              kDefaultOpenAiCompatibleTtsModel,
            ),
          ),
          onChanged: (value) =>
              unawaited(settingsProvider.setReadAloudModel(value)),
          onFieldSubmitted: (value) => unawaited(
            _selectModelAndTest(settingsProvider, value),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: selectedVoice,
          decoration: InputDecoration(
            labelText: context.l10n.settingsReadAloudVoice,
          ),
          items: kOpenAiCompatibleVoiceIds
              .map(
                (voice) =>
                    DropdownMenuItem<String>(value: voice, child: Text(voice)),
              )
              .toList(),
          onChanged: (value) {
            unawaited(
              _selectVoiceAndTest(
                settingsProvider,
                id: value,
                locale: null,
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.speechPitchNotSupported,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildReadAloudApiKeyField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        TextFormField(
          key: const ValueKey('read-aloud-api-key'),
          controller: _readAloudApiKeyController,
          decoration: InputDecoration(
            labelText: context.l10n.speechApiKey,
            helperText: _hasReadAloudApiKey
                ? context.l10n.speechApiKeySavedHelper
                : context.l10n.speechNoApiKeySaved,
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
                    tooltip: context.l10n.speechSaveApiKey,
                    icon: const Icon(Symbols.save),
                    onPressed: () => unawaited(_saveReadAloudApiKey()),
                  ),
          ),
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          onFieldSubmitted: (_) => unawaited(_saveReadAloudApiKey()),
        ),
        if (_readAloudApiKeyStatus != null) ...[
          const SizedBox(height: 8),
          Text(
            _readAloudApiKeyStatus!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  String _remoteVoiceCacheKey(SettingsProvider settingsProvider) {
    return '${settingsProvider.readAloudProvider}|'
        '${settingsProvider.readAloudBaseUrl}|'
        '${settingsProvider.readAloudModel}';
  }

  void _requestRemoteVoiceReload() {
    _remoteVoicePendingKey = _remoteVoiceCacheKey(
      context.read<SettingsProvider>(),
    );
    setState(() {});
  }

  Widget _buildRemoteVoicePicker(
    ReadAloudProvider provider,
    SettingsProvider settingsProvider,
  ) {
    if (!di.sl.isRegistered<ReadAloudService>()) {
      return const SizedBox.shrink();
    }
    final cacheKey =
        '$provider|${settingsProvider.readAloudBaseUrl}|'
        '${settingsProvider.readAloudModel}';
    final Future<List<Map<String, String>>>? future;
    if (_remoteVoicePendingKey == cacheKey) {
      future = _remoteReadAloudVoicesCache[cacheKey] ??=
          _remoteReadAloudVoices(
            provider: provider,
            settingsProvider: settingsProvider,
          );
      final request = future;
      request.whenComplete(() {
        if (mounted &&
            _remoteVoicePendingKey == cacheKey &&
            identical(_remoteReadAloudVoicesCache[cacheKey], request)) {
          setState(() {
            _remoteVoicePendingKey = null;
          });
        }
      });
    } else {
      future = _remoteReadAloudVoicesCache[cacheKey] ??
          Future<List<Map<String, String>>>.value(
            const <Map<String, String>>[],
          );
    }
    return FutureBuilder<List<Map<String, String>>>(
      future: future,
      builder: (context, snapshot) {
        final voices = snapshot.data ?? const <Map<String, String>>[];
        if (voices.isEmpty) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.speechRemoteVoice),
            subtitle: Text(context.l10n.speechRemoteVoiceListUnavailable),
          );
        }
        final savedVoiceId = settingsProvider.readAloudVoiceId;
        final voiceMissing =
            savedVoiceId != null &&
            savedVoiceId.trim().isNotEmpty &&
            !voices.any((voice) => voice['name'] == savedVoiceId);
        final selected = voices.any(
          (voice) => voice['name'] == savedVoiceId,
        )
            ? savedVoiceId
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (voiceMissing) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Symbols.warning_amber_rounded),
                title: Text(context.l10n.speechRemoteVoiceUnavailable),
                trailing: TextButton(
                  onPressed: () {
                    unawaited(
                      _selectVoiceAndTest(
                        settingsProvider,
                        id: null,
                        locale: null,
                      ),
                    );
                  },
                  child: Text(context.l10n.commonReset),
                ),
              ),
            ],
            SearchableDropdownFormField<String>(
              value: selected,
              decoration: InputDecoration(
                labelText: context.l10n.speechRemoteVoice,
                helperText: context.l10n.speechRemoteVoicesLoaded,
                border: const OutlineInputBorder(),
              ),
              isExpanded: true,
              searchTermsBuilder: (value) {
                for (final voice in voices) {
                  if (voice['name'] == value) {
                    return <String>[
                      value,
                      voice['locale'] ?? '',
                      voice['label'] ?? '',
                    ];
                  }
                }
                return <String>[value];
              },
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
                if (value == null) return;
                final selectedVoice = voices.firstWhere(
                  (voice) => voice['name'] == value,
                  orElse: () => const <String, String>{},
                );
                unawaited(
                  _selectVoiceAndTest(
                    settingsProvider,
                    id: value,
                    locale: selectedVoice['locale'],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  String _remoteModelsCacheKey(SettingsProvider settingsProvider) {
    // The model list is independent of the currently selected model, so only
    // the provider and base URL invalidate the cache.
    return '${settingsProvider.readAloudProvider}|'
        '${settingsProvider.readAloudBaseUrl}';
  }

  void _requestRemoteModelsReload() {
    _remoteModelsPendingKey = _remoteModelsCacheKey(
      context.read<SettingsProvider>(),
    );
    setState(() {});
  }

  Widget _buildRemoteModelPicker(
    ReadAloudProvider provider,
    SettingsProvider settingsProvider,
  ) {
    if (!di.sl.isRegistered<ReadAloudService>()) {
      return const SizedBox.shrink();
    }
    final cacheKey = _remoteModelsCacheKey(settingsProvider);
    final Future<List<Map<String, String>>>? future;
    if (_remoteModelsPendingKey == cacheKey) {
      future = _remoteModelsCache[cacheKey] ??=
          _remoteReadAloudModels(
            provider: provider,
            settingsProvider: settingsProvider,
          );
      final request = future;
      request.whenComplete(() {
        if (mounted &&
            _remoteModelsPendingKey == cacheKey &&
            identical(_remoteModelsCache[cacheKey], request)) {
          setState(() {
            _remoteModelsPendingKey = null;
          });
        }
      });
    } else {
      future = _remoteModelsCache[cacheKey] ??
          Future<List<Map<String, String>>>.value(
            const <Map<String, String>>[],
          );
    }
    return FutureBuilder<List<Map<String, String>>>(
      future: future,
      builder: (context, snapshot) {
        final models = snapshot.data ?? const <Map<String, String>>[];
        if (models.isEmpty) {
          // Discovery unavailable (no saved key, unreachable base URL, or a
          // failed fetch): keep the free-text custom model field so users can
          // still configure a model, matching the message below.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.speechRemoteModel),
                subtitle: Text(context.l10n.speechRemoteModelListUnavailable),
              ),
              const SizedBox(height: 12),
              _buildCustomModelField(
                provider,
                settingsProvider,
                initialValue: settingsProvider.readAloudModel.trim(),
              ),
            ],
          );
        }
        final defaultModel = provider == ReadAloudProvider.nim
            ? kDefaultNimTtsModel
            : kDefaultElevenLabsTtsModel;
        final saved = settingsProvider.readAloudModel.trim();
        final known = models.any((model) => model['name'] == saved);
        final modelMissing = saved.isNotEmpty && !known;
        final customMode = _editingCustomModel || modelMissing;
        final effective = saved.isNotEmpty ? saved : defaultModel;
        final selected = known
            ? saved
            : customMode
            ? kCustomModelKey
            : models.any((model) => model['name'] == effective)
            ? effective
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (modelMissing) ...[
              ListTile(
                key: ValueKey('read-aloud-model-unavailable-${provider.name}'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Symbols.warning_amber_rounded),
                title: Text(context.l10n.speechRemoteModelUnavailable),
              ),
            ],
            SearchableDropdownFormField<String>(
              value: selected,
              decoration: InputDecoration(
                labelText: context.l10n.speechRemoteModel,
                helperText: context.l10n.speechRemoteModelsLoaded,
                border: const OutlineInputBorder(),
              ),
              isExpanded: true,
              searchTermsBuilder: (value) {
                if (value == kCustomModelKey) {
                  return <String>[context.l10n.speechCustomModel];
                }
                final labels = models
                    .where((model) => model['name'] == value)
                    .map((model) => model['label'] ?? '');
                return <String>[value, ...labels];
              },
              items: <DropdownMenuItem<String>>[
                for (final model in models)
                  DropdownMenuItem<String>(
                    value: model['name'],
                    child: Text(
                      model['label']?.isNotEmpty == true
                          ? model['label']!
                          : (model['name'] ?? ''),
                    ),
                  ),
                DropdownMenuItem<String>(
                  value: kCustomModelKey,
                  child: Text(context.l10n.speechCustomModel),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                if (value == kCustomModelKey) {
                  setState(() {
                    _editingCustomModel = true;
                  });
                  return;
                }
                setState(() {
                  _editingCustomModel = false;
                });
                unawaited(_selectModelAndTest(settingsProvider, value));
              },
            ),
            if (customMode) ...[
              const SizedBox(height: 12),
              _buildCustomModelField(
                provider,
                settingsProvider,
                initialValue: !known ? saved : '',
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCustomModelField(
    ReadAloudProvider provider,
    SettingsProvider settingsProvider, {
    required String initialValue,
  }) {
    final defaultModel = provider == ReadAloudProvider.nim
        ? kDefaultNimTtsModel
        : kDefaultElevenLabsTtsModel;
    return TextFormField(
      key: ValueKey('read-aloud-custom-model-${provider.name}'),
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: context.l10n.speechModel,
        helperText: context.l10n.speechModelDefaultHelper(defaultModel),
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) =>
          unawaited(settingsProvider.setReadAloudModel(value)),
      onFieldSubmitted: (value) => unawaited(
        _selectModelAndTest(settingsProvider, value),
      ),
    );
  }

  Widget _buildElevenLabsReadAloudFields(
    SettingsProvider settingsProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.speechCloudTtsPrivacy),
          subtitle: Text(context.l10n.speechCloudTtsPrivacyDescription),
        ),
        TextFormField(
          key: const ValueKey('read-aloud-base-url-elevenlabs'),
          initialValue: settingsProvider.readAloudBaseUrl,
          decoration: InputDecoration(
            labelText: context.l10n.speechBaseUrl,
            helperText: context.l10n.speechBaseUrlExample(
              kDefaultElevenLabsTtsBaseUrl,
            ),
          ),
          keyboardType: TextInputType.url,
          onChanged: (value) =>
              unawaited(settingsProvider.setReadAloudBaseUrl(value)),
          onFieldSubmitted: (_) {
            _requestRemoteVoiceReload();
            _requestRemoteModelsReload();
          },
        ),
        _buildReadAloudApiKeyField(),
        const SizedBox(height: 12),
        _buildRemoteModelPicker(ReadAloudProvider.elevenLabs, settingsProvider),
        const SizedBox(height: 12),
        _buildRemoteVoicePicker(
          ReadAloudProvider.elevenLabs,
          settingsProvider,
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.speechPitchHiddenForProvider,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildNimReadAloudFields(SettingsProvider settingsProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.speechCloudTtsPrivacy),
          subtitle: Text(context.l10n.speechCloudTtsPrivacyDescription),
        ),
        TextFormField(
          key: const ValueKey('read-aloud-base-url-nim'),
          initialValue: settingsProvider.readAloudBaseUrl,
          decoration: InputDecoration(
            labelText: context.l10n.speechBaseUrl,
            helperText: context.l10n.speechNimBaseUrlRequired,
          ),
          keyboardType: TextInputType.url,
          onChanged: (value) =>
              unawaited(settingsProvider.setReadAloudBaseUrl(value)),
          onFieldSubmitted: (_) {
            _requestRemoteVoiceReload();
            _requestRemoteModelsReload();
          },
        ),
        _buildReadAloudApiKeyField(),
        const SizedBox(height: 12),
        _buildRemoteModelPicker(ReadAloudProvider.nim, settingsProvider),
        const SizedBox(height: 12),
        _buildRemoteVoicePicker(ReadAloudProvider.nim, settingsProvider),
        const SizedBox(height: 8),
        Text(
          context.l10n.speechNimSpeedNotSupported,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildTestPhraseField(SettingsProvider settingsProvider) {
    return TextFormField(
      key: const ValueKey('read-aloud-test-phrase'),
      initialValue: settingsProvider.readAloudTestText,
      decoration: InputDecoration(
        labelText: context.l10n.speechReadAloudTestPhraseLabel,
        helperText: context.l10n.speechReadAloudTestPhraseHint,
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) =>
          unawaited(settingsProvider.setReadAloudTestText(value)),
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
            if (readAloudProvider == ReadAloudProvider.elevenLabs) ...[
              const Divider(height: 1),
              _buildElevenLabsReadAloudFields(settingsProvider),
            ],
            if (readAloudProvider == ReadAloudProvider.nim) ...[
              const Divider(height: 1),
              _buildNimReadAloudFields(settingsProvider),
            ],
            const Divider(height: 1),
            _buildTestPhraseField(settingsProvider),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Symbols.play_arrow),
                label: Text(context.l10n.speechTestVoice),
                onPressed: () =>
                    unawaited(_testReadAloudVoice(settingsProvider)),
              ),
            ),
            const Divider(height: 1),
            if (readAloudProvider == ReadAloudProvider.nim) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.settingsReadAloudSpeed),
                subtitle: Text(context.l10n.speechNimSpeedNotSupported),
              ),
            ] else ...[
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
            ],
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
