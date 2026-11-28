import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/voice/read_aloud.dart';
import '../../shared/widgets/app_indeterminate_progress.dart';
import '../../shared/widgets/app_snack_bar.dart';
import '../../shared/widgets/searchable_picker.dart';
import '../voice/read_aloud_controller.dart';
import '../voice/read_aloud_text.dart';

/// Settings > Read aloud (#541): whether messages offer it, the voice
/// service, its voice, model, address and key, the speed and a test.
class ReadAloudSettingsPage extends StatefulWidget {
  const ReadAloudSettingsPage({super.key});

  @override
  State<ReadAloudSettingsPage> createState() => _ReadAloudSettingsPageState();
}

class _ReadAloudSettingsPageState extends State<ReadAloudSettingsPage> {
  final _model = TextEditingController();
  final _baseUrl = TextEditingController();
  final _key = TextEditingController();
  final _phrase = TextEditingController();
  SpeechProvider? _shown;
  bool _keySaved = false;
  bool _loadingVoices = false;
  int _keyRead = 0;

  @override
  void dispose() {
    _model.dispose();
    _baseUrl.dispose();
    _key.dispose();
    _phrase.dispose();
    super.dispose();
  }

  /// Fills the fields from [settings] when another service is shown.
  void _sync(ReadAloudController controller) {
    final settings = controller.settings;
    if (_shown == settings.provider) return;
    _shown = settings.provider;
    _model.text = settings.model ?? '';
    _baseUrl.text = settings.baseUrl ?? '';
    _phrase.text = settings.testPhrase ?? '';
    _key.clear();
    _keySaved = false;
    final read = ++_keyRead;
    unawaited(
      controller.keys.read(settings.provider).then((key) {
        if (!mounted || read != _keyRead) return;
        setState(() => _keySaved = key != null && key.isNotEmpty);
      }),
    );
  }

  Future<void> _pickVoice(ReadAloudController controller) async {
    final l10n = context.v2L10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final settings = controller.settings;
    setState(() => _loadingVoices = true);
    List<SpeechVoice> voices;
    try {
      voices = await controller.voices();
    } on Object {
      voices = const [];
      showAppSnackBar(messenger, l10n.readAloudVoicesFailed);
    } finally {
      if (mounted) setState(() => _loadingVoices = false);
    }
    if (!mounted) return;
    final options = <String, String>{
      '': l10n.readAloudVoiceDefault,
      for (final voice in voices)
        voice.id: voice.locale == null
            ? voice.label
            : '${voice.label} · ${voice.locale}',
      if (settings.voice case final current?
          when !voices.any((v) => v.id == current))
        current: current,
    };
    final chosen = await showSearchablePicker<String>(
      context,
      title: l10n.readAloudVoice,
      options: options,
      selected: settings.voice ?? '',
    );
    if (chosen == null || !mounted) return;
    await controller.update(
      chosen.isEmpty
          ? settings.copyWith(clearVoice: true)
          : settings.copyWith(voice: chosen),
    );
    if (mounted) await _test(controller);
  }

  Future<void> _test(ReadAloudController controller) async {
    final l10n = context.v2L10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final phrase = _phrase.text.trim().isEmpty
        ? l10n.readAloudTestPhraseDefault
        : _phrase.text.trim();
    final failure = await controller.read(ReadAloudController.testKey, phrase);
    if (failure != null) {
      showAppSnackBar(messenger, readAloudFailureText(l10n, failure));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReadAloudController?>();
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    if (controller == null) {
      return Center(child: Text(l10n.readAloudFailUnavailable));
    }
    _sync(controller);
    final settings = controller.settings;
    final provider = settings.provider;
    final providers = controller.providers;
    Widget card(List<Widget> children) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
    final voiceLabel = settings.voice ?? l10n.readAloudVoiceDefault;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          key: const ValueKey('read_aloud_settings_list'),
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.readAloudTitle, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            card([
              SwitchListTile(
                key: const ValueKey('read_aloud_enabled'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.readAloudEnable),
                subtitle: Text(l10n.readAloudEnableDescription),
                value: settings.enabled,
                onChanged: (value) => unawaited(
                  controller.update(settings.copyWith(enabled: value)),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            card([
              Text(l10n.readAloudProvider, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              RadioGroup<SpeechProvider>(
                groupValue: provider,
                onChanged: (value) {
                  if (value == null) return;
                  unawaited(
                    controller.update(
                      settings.copyWith(
                        provider: value,
                        clearVoice: true,
                        clearModel: true,
                        clearBaseUrl: true,
                      ),
                    ),
                  );
                },
                child: Column(
                  children: [
                    for (final option in providers)
                      RadioListTile<SpeechProvider>(
                        key: ValueKey('read_aloud_provider_${option.name}'),
                        contentPadding: EdgeInsets.zero,
                        value: option,
                        title: Text(readAloudProviderName(l10n, option)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                provider == SpeechProvider.edge
                    ? l10n.readAloudEdgeNotice
                    : l10n.readAloudCloudNotice(
                        readAloudProviderName(l10n, provider),
                      ),
                key: const ValueKey('read_aloud_privacy'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            card([
              ListTile(
                key: const ValueKey('read_aloud_voice'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.readAloudVoice),
                subtitle: Text(voiceLabel),
                trailing: _loadingVoices
                    ? const AppIndeterminateRing(size: 20)
                    : const Icon(Icons.chevron_right),
                onTap: _loadingVoices
                    ? null
                    : () => unawaited(_pickVoice(controller)),
              ),
              if (provider.cloud && provider != SpeechProvider.edge) ...[
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('read_aloud_base_url'),
                  controller: _baseUrl,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l10n.readAloudBaseUrl,
                    helperText: provider == SpeechProvider.nim
                        ? l10n.readAloudBaseUrlRequired
                        : null,
                  ),
                  onSubmitted: (value) => unawaited(
                    controller.update(
                      value.trim().isEmpty
                          ? settings.copyWith(clearBaseUrl: true)
                          : settings.copyWith(baseUrl: value.trim()),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('read_aloud_model'),
                  controller: _model,
                  decoration: InputDecoration(labelText: l10n.readAloudModel),
                  onSubmitted: (value) => unawaited(
                    controller.update(
                      value.trim().isEmpty
                          ? settings.copyWith(clearModel: true)
                          : settings.copyWith(model: value.trim()),
                    ),
                  ),
                ),
              ],
              if (provider.keyed) ...[
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('read_aloud_api_key'),
                  controller: _key,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: l10n.readAloudApiKey,
                    helperText: _keySaved ? l10n.readAloudApiKeySaved : null,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.tonal(
                      key: const ValueKey('read_aloud_api_key_save'),
                      onPressed: () async {
                        final value = _key.text.trim();
                        if (value.isEmpty) return;
                        await controller.keys.write(provider, value);
                        if (!mounted) return;
                        _key.clear();
                        setState(() => _keySaved = true);
                      },
                      child: Text(l10n.readAloudSave),
                    ),
                    if (_keySaved)
                      TextButton(
                        key: const ValueKey('read_aloud_api_key_clear'),
                        onPressed: () async {
                          await controller.keys.write(provider, null);
                          if (!mounted) return;
                          setState(() => _keySaved = false);
                        },
                        child: Text(l10n.readAloudClear),
                      ),
                  ],
                ),
              ],
              if (provider != SpeechProvider.nim) ...[
                const SizedBox(height: 8),
                Text(l10n.readAloudSpeed, style: theme.textTheme.titleSmall),
                Slider(
                  key: const ValueKey('read_aloud_speed'),
                  value: settings.rate,
                  divisions: 10,
                  label: '${(settings.rate * 100).round()}%',
                  onChanged: (value) => unawaited(
                    controller.update(settings.copyWith(rate: value)),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 12),
            card([
              TextField(
                key: const ValueKey('read_aloud_test_phrase'),
                controller: _phrase,
                decoration: InputDecoration(
                  labelText: l10n.readAloudTestPhrase,
                  hintText: l10n.readAloudTestPhraseDefault,
                ),
                onSubmitted: (value) => unawaited(
                  controller.update(
                    value.trim().isEmpty
                        ? settings.copyWith(clearTestPhrase: true)
                        : settings.copyWith(testPhrase: value.trim()),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.icon(
                  key: const ValueKey('read_aloud_test'),
                  onPressed: () => unawaited(_test(controller)),
                  icon: const Icon(Icons.volume_up),
                  label: Text(l10n.readAloudTest),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
