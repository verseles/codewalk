import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/i18n/app_locales.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../domain/entities/experience_settings.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/session_attention/session_attention_host_service.dart';
import '../../../widgets/searchable_dropdown_form_field.dart';
import '../../../widgets/settings_provenance_chip.dart';
import '../widgets/settings_section_layout.dart';

class BehaviorSettingsSection extends StatefulWidget {
  const BehaviorSettingsSection({super.key});

  @override
  State<BehaviorSettingsSection> createState() =>
      _BehaviorSettingsSectionState();
}

class _BehaviorSettingsSectionState extends State<BehaviorSettingsSection>
    with WidgetsBindingObserver {
  late final TextEditingController _usernameController;
  late final FocusNode _usernameFocusNode;
  final Map<String, int> _deferredConfigMutationGenerationByKey =
      <String, int>{};
  bool _sessionAttentionUpdating = false;
  SessionAttentionPresentation? _pendingSessionAttentionPresentation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _usernameController = TextEditingController();
    _usernameFocusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        context.read<SettingsProvider>().refreshOpenCodeBackedDefaults(),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _usernameController.dispose();
    _usernameFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(_resumeSessionAttentionPermissionFlow());
    }
  }

  Future<void> _resumeSessionAttentionPermissionFlow() async {
    final provider = context.read<SettingsProvider>();
    await provider.refreshSessionAttentionHostCapability();
    final pending = _pendingSessionAttentionPresentation;
    if (!mounted ||
        pending == null ||
        !provider.sessionAttentionHostCapability.permissionGranted) {
      return;
    }
    await _setSessionAttentionPresentation(provider, pending);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        return ListView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          children: [
            SettingsSectionIntro(
              title: context.l10n.settingsBehaviorTitle,
              description: context.l10n.settingsBehaviorDescription,
            ),
            const SizedBox(height: 16),
            SettingsGroupHeader(
              title: context.l10n.settingsGroupLanguageAndChat,
            ),
            const SizedBox(height: 8),
            _buildLanguageCard(context),
            const SizedBox(height: 16),
            // Platforms without an attention surface (desktop and web) do not
            // show the control at all instead of showing a dead one.
            if (settingsProvider.sessionAttentionHostCapability.supported) ...[
              _buildSessionAttentionCard(context, settingsProvider),
              const SizedBox(height: 16),
            ],
            _buildChatRenderModeCard(context, settingsProvider),
            const SizedBox(height: 16),
            _buildComposerSpellCheckCard(context, settingsProvider),
            const SizedBox(height: 20),
            SettingsGroupHeader(
              title: context.l10n.settingsGroupOpenCodeDefaults,
            ),
            const SizedBox(height: 8),
            _buildOpenCodeDefaultsCard(context, settingsProvider),
            const SizedBox(height: 16),
            _buildPermissionParityCard(context),
            const SizedBox(height: 20),
            SettingsGroupHeader(title: context.l10n.settingsGroupDataAndSync),
            const SizedBox(height: 8),
            _buildDataSaverCard(context, settingsProvider),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    key: const ValueKey<String>(
                      'settings_toggle_experimental_multi_device_sync',
                    ),
                    title: Text(context.l10n.settingsBehaviorMultiDeviceSync),
                    subtitle: Text(
                      context.l10n.settingsBehaviorMultiDeviceSyncDescription,
                    ),
                    value: settingsProvider.enableExperimentalMultiDeviceSync,
                    onChanged: (value) => unawaited(
                      settingsProvider.setEnableExperimentalMultiDeviceSync(
                        value,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.l10n.settingsBehaviorMultiDeviceSyncWarning,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _sessionAttentionSizeLabel(
    BuildContext context,
    SessionAttentionBubbleSize size,
  ) {
    return switch (size) {
      SessionAttentionBubbleSize.extraSmall =>
        context.l10n.settingsSessionAttentionSizeExtraSmall,
      SessionAttentionBubbleSize.small =>
        context.l10n.settingsSessionAttentionSizeSmall,
      SessionAttentionBubbleSize.standard =>
        context.l10n.settingsSessionAttentionSizeStandard,
      SessionAttentionBubbleSize.large =>
        context.l10n.settingsSessionAttentionSizeLarge,
      SessionAttentionBubbleSize.extraLarge =>
        context.l10n.settingsSessionAttentionSizeExtraLarge,
    };
  }

  Widget _buildSessionAttentionCard(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    final capability = settingsProvider.sessionAttentionHostCapability;
    final enabled = capability.supported && !_sessionAttentionUpdating;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.settingsSessionAttentionTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.settingsSessionAttentionDescription,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SegmentedButton<SessionAttentionPresentation>(
              key: const ValueKey<String>('settings_session_attention_mode'),
              segments: <ButtonSegment<SessionAttentionPresentation>>[
                ButtonSegment<SessionAttentionPresentation>(
                  value: SessionAttentionPresentation.off,
                  label: Text(context.l10n.settingsSessionAttentionOff),
                ),
                ButtonSegment<SessionAttentionPresentation>(
                  value: SessionAttentionPresentation.bubble,
                  label: Text(context.l10n.settingsSessionAttentionBubble),
                ),
                ButtonSegment<SessionAttentionPresentation>(
                  value: SessionAttentionPresentation.panel,
                  label: Text(context.l10n.settingsSessionAttentionPanel),
                ),
              ],
              selected: <SessionAttentionPresentation>{
                settingsProvider.sessionAttentionPresentation,
              },
              onSelectionChanged: enabled
                  ? (selection) => unawaited(
                      _setSessionAttentionPresentation(
                        settingsProvider,
                        selection.single,
                      ),
                    )
                  : null,
            ),
            if (capability.kind == SessionAttentionHostKind.androidExternal &&
                settingsProvider.sessionAttentionPresentation !=
                    SessionAttentionPresentation.off) ...[
              const SizedBox(height: 16),
              Text(
                context.l10n.settingsSessionAttentionSize,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Slider(
                key: const ValueKey<String>('settings_session_attention_size'),
                min: 0,
                max: (SessionAttentionBubbleSize.values.length - 1).toDouble(),
                divisions: SessionAttentionBubbleSize.values.length - 1,
                value: SessionAttentionBubbleSize.values
                    .indexOf(settingsProvider.sessionAttentionBubbleSize)
                    .toDouble(),
                label: _sessionAttentionSizeLabel(
                  context,
                  settingsProvider.sessionAttentionBubbleSize,
                ),
                onChanged: (value) => unawaited(
                  settingsProvider.setSessionAttentionBubbleSize(
                    SessionAttentionBubbleSize.values[value.round()],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              context.l10n.settingsSessionAttentionPrivacy,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (!capability.supported) ...[
              const SizedBox(height: 8),
              Text(
                context.l10n.settingsSessionAttentionUnavailable,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            if (capability.kind == SessionAttentionHostKind.androidExternal &&
                !capability.permissionGranted) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey<String>(
                  'settings_session_attention_permission',
                ),
                onPressed: _sessionAttentionUpdating
                    ? null
                    : () => unawaited(
                        settingsProvider.openSessionAttentionSystemSettings(),
                      ),
                icon: const Icon(Symbols.settings),
                label: Text(context.l10n.settingsSessionAttentionOpenSettings),
              ),
            ],
            if (capability.running) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey<String>('settings_session_attention_stop'),
                onPressed: _sessionAttentionUpdating
                    ? null
                    : () => unawaited(
                        _setSessionAttentionPresentation(
                          settingsProvider,
                          SessionAttentionPresentation.off,
                        ),
                      ),
                icon: const Icon(Symbols.stop),
                label: Text(context.l10n.settingsSessionAttentionStop),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _setSessionAttentionPresentation(
    SettingsProvider settingsProvider,
    SessionAttentionPresentation presentation,
  ) async {
    if (_sessionAttentionUpdating) {
      return;
    }
    if (presentation == SessionAttentionPresentation.off) {
      _pendingSessionAttentionPresentation = null;
    } else {
      _pendingSessionAttentionPresentation = presentation;
    }
    setState(() => _sessionAttentionUpdating = true);
    String? error;
    try {
      error = await settingsProvider.setSessionAttentionPresentation(
        presentation,
      );
    } catch (_) {
      error = context.l10n.settingsSessionAttentionUnavailable;
    } finally {
      if (mounted) {
        setState(() => _sessionAttentionUpdating = false);
      }
    }
    if (!mounted) {
      return;
    }
    if (error == null ||
        settingsProvider.sessionAttentionHostCapability.kind !=
            SessionAttentionHostKind.androidExternal) {
      _pendingSessionAttentionPresentation = null;
    }
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Widget _buildLanguageCard(BuildContext context) {
    const systemLocaleValue = 'system';
    late final LocaleProvider localeProvider;
    try {
      localeProvider = Provider.of<LocaleProvider>(context);
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    final currentValue = localeProvider.localeCode ?? systemLocaleValue;
    final l10n = context.l10n;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settingsLanguageTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.settingsLanguageDescription,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SearchableDropdownFormField<String>(
              key: const ValueKey<String>('settings_language_selector'),
              value: currentValue,
              decoration: InputDecoration(
                labelText: l10n.settingsLanguageFieldLabel,
                border: const OutlineInputBorder(),
                helperText: l10n.settingsLanguageFieldHelper,
              ),
              isExpanded: true,
              searchHintText: l10n.settingsLanguageSearchHint,
              emptyText: l10n.settingsLanguageEmptyText,
              searchTermsBuilder: (value) {
                final info = AppLocales.infoForCode(value);
                if (value == systemLocaleValue || info == null) {
                  return <String>[
                    l10n.settingsLanguageSystemDefault,
                    'system default',
                  ];
                }
                return <String>[info.nativeName, info.englishName, info.code];
              },
              items: [
                DropdownMenuItem<String>(
                  value: systemLocaleValue,
                  child: Text(l10n.settingsLanguageSystemDefault),
                ),
                for (final info in AppLocales.infos)
                  DropdownMenuItem<String>(
                    value: info.code,
                    child: Text(info.displayName),
                  ),
              ],
              onChanged: (value) {
                final code = value == systemLocaleValue ? null : value;
                unawaited(localeProvider.setLocaleCode(code));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpenCodeDefaultsCard(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    final modelOptions = settingsProvider.openCodeDefaultModelOptions;
    final smallModelKey = settingsProvider.openCodeSmallModelKey;
    final agentOptions = settingsProvider.openCodeDefaultAgentOptions;
    final username = settingsProvider.openCodeUsername;
    final snapshotEnabled = settingsProvider.openCodeSnapshotEnabled;
    final autoupdateMode = settingsProvider.openCodeAutoupdateMode;
    final shareMode = settingsProvider.openCodeShareMode;

    if (!_usernameFocusNode.hasFocus) {
      final targetValue = username ?? '';
      if (_usernameController.text != targetValue) {
        _usernameController.value = TextEditingValue(
          text: targetValue,
          selection: TextSelection.collapsed(offset: targetValue.length),
        );
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SettingsProvenanceChip(
                        provenance: SettingsProvenance.opencodeBacked,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.behaviorOpenCodeBackedDefaults,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.l10n.behaviorTheseValuesWrite,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.behaviorRefreshDefaults,
                  onPressed: settingsProvider.openCodeDefaultsLoading
                      ? null
                      : () => unawaited(
                          settingsProvider.refreshOpenCodeBackedDefaults(),
                        ),
                  icon: const Icon(Symbols.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (settingsProvider.openCodeDefaultsLoading &&
                !settingsProvider.openCodeDefaultsLoaded)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (settingsProvider.openCodeDefaultsError != null) ...[
                Text(
                  settingsProvider.openCodeDefaultsError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SearchableDropdownFormField<String>(
                key: const ValueKey<String>('settings_opencode_default_model'),
                value: _selectedDropdownValue(
                  settingsProvider.openCodeDefaultModelKey,
                  modelOptions.map((option) => option.key),
                ),
                decoration: InputDecoration(
                  labelText: context.l10n.settingsDefaultModel,
                  border: const OutlineInputBorder(),
                  helperText: context.l10n.behaviorSharedAcrossOpenCode,
                ),
                isExpanded: true,
                searchHintText: context.l10n.settingsSearchDefaultModel,
                emptyText: context.l10n.modelModelsFound,
                searchTermsBuilder: (value) =>
                    _modelSearchTerms(modelOptions, value),
                items: modelOptions
                    .map(
                      (option) => DropdownMenuItem<String>(
                        value: option.key,
                        child: Text(
                          option.label,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged:
                    modelOptions.isEmpty ||
                        settingsProvider.openCodeDefaultsLoading
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }
                        unawaited(_applyDefaultModel(context, value));
                      },
              ),
              const SizedBox(height: 12),
              SearchableDropdownFormField<String>(
                key: const ValueKey<String>('settings_opencode_default_agent'),
                value: _selectedDropdownValue(
                  settingsProvider.openCodeDefaultAgentName,
                  agentOptions,
                ),
                decoration: InputDecoration(
                  labelText: context.l10n.settingsDefaultAgent,
                  border: const OutlineInputBorder(),
                  helperText: context.l10n.behaviorPrimaryAgentAgent,
                ),
                isExpanded: true,
                searchHintText: context.l10n.settingsSearchDefaultAgent,
                emptyText: context.l10n.settingsNoAgentsFound,
                searchTermsBuilder: (value) => <String>[value],
                items: agentOptions
                    .map(
                      (agentName) => DropdownMenuItem<String>(
                        value: agentName,
                        child: Text(agentName),
                      ),
                    )
                    .toList(growable: false),
                onChanged:
                    agentOptions.isEmpty ||
                        settingsProvider.openCodeDefaultsLoading
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }
                        unawaited(_applyDefaultAgent(context, value));
                      },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey<String>('settings_opencode_username'),
                controller: _usernameController,
                focusNode: _usernameFocusNode,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: context.l10n.settingsConversationUsername,
                  border: const OutlineInputBorder(),
                  helperText: context.l10n.behaviorCustomDisplayName,
                ),
                onFieldSubmitted: (_) => unawaited(_applyUsername(context)),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  key: const ValueKey<String>(
                    'settings_opencode_username_save',
                  ),
                  onPressed: settingsProvider.openCodeDefaultsLoading
                      ? null
                      : () => unawaited(_applyUsername(context)),
                  icon: const Icon(Symbols.save),
                  label: Text(context.l10n.settingsBehaviorSaveUsername),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                username == null
                    ? context.l10n.settingsUsernameUnsetExplanation
                    : context.l10n.settingsUsernameResetExplanation,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                key: const ValueKey<String>('settings_opencode_snapshot'),
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.settingsBehaviorOpenCodeSnapshots),
                subtitle: Text(
                  context.l10n.settingsBehaviorOpenCodeSnapshotsDescription,
                ),
                value: snapshotEnabled,
                onChanged: settingsProvider.openCodeDefaultsLoading
                    ? null
                    : (value) =>
                          unawaited(_applySnapshotEnabled(context, value)),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.settingsBehaviorSnapshotCaveat,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              SearchableDropdownFormField<String>(
                key: const ValueKey<String>('settings_opencode_small_model'),
                value: _selectedDropdownValue(
                  smallModelKey,
                  modelOptions.map((option) => option.key),
                ),
                hint: Text(context.l10n.behaviorAutomaticFallback),
                decoration: InputDecoration(
                  labelText: context.l10n.settingsSmallModel,
                  border: const OutlineInputBorder(),
                  helperText: context.l10n.behaviorLightweightTasksLike,
                ),
                isExpanded: true,
                searchHintText: context.l10n.settingsSearchSmallModel,
                emptyText: context.l10n.modelModelsFound,
                searchTermsBuilder: (value) =>
                    _modelSearchTerms(modelOptions, value),
                items: modelOptions
                    .map(
                      (option) => DropdownMenuItem<String>(
                        value: option.key,
                        child: Text(
                          option.label,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged:
                    modelOptions.isEmpty ||
                        settingsProvider.openCodeDefaultsLoading
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }
                        unawaited(_applySmallModel(context, value));
                      },
              ),
              const SizedBox(height: 8),
              Text(
                smallModelKey == null
                    ? context.l10n.settingsSmallModelUnsetExplanation
                    : context.l10n.settingsSmallModelResetExplanation,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              SearchableDropdownFormField<OpenCodeAutoupdateMode>(
                key: const ValueKey<String>('settings_opencode_autoupdate'),
                value: autoupdateMode,
                decoration: InputDecoration(
                  labelText: context.l10n.settingsOpenCodeAutoUpdate,
                  border: const OutlineInputBorder(),
                  helperText: context.l10n.behaviorControlsUpstreamOpenCode,
                ),
                searchHintText: context.l10n.settingsSearchAutoUpdateMode,
                searchTermsBuilder: (value) => <String>[
                  _autoupdateModeLabel(value),
                ],
                items: <DropdownMenuItem<OpenCodeAutoupdateMode>>[
                  DropdownMenuItem<OpenCodeAutoupdateMode>(
                    value: OpenCodeAutoupdateMode.automatic,
                    child: Text(context.l10n.behaviorAutomatic),
                  ),
                  DropdownMenuItem<OpenCodeAutoupdateMode>(
                    value: OpenCodeAutoupdateMode.notify,
                    child: Text(context.l10n.behaviorNotify),
                  ),
                  DropdownMenuItem<OpenCodeAutoupdateMode>(
                    value: OpenCodeAutoupdateMode.disabled,
                    child: Text(context.l10n.behaviorDisabled),
                  ),
                ],
                onChanged: settingsProvider.openCodeDefaultsLoading
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }
                        unawaited(_applyAutoupdateMode(context, value));
                      },
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.behaviorCodeWalkReleaseChecks,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              SearchableDropdownFormField<OpenCodeShareMode>(
                key: const ValueKey<String>('settings_opencode_share_mode'),
                value: shareMode,
                decoration: InputDecoration(
                  labelText: context.l10n.settingsOpenCodeSharingDefault,
                  border: const OutlineInputBorder(),
                  helperText: context.l10n.behaviorControlsOfficialGlobal,
                ),
                searchHintText: context.l10n.settingsSearchSharingMode,
                searchTermsBuilder: (value) => <String>[_shareModeLabel(value)],
                items: <DropdownMenuItem<OpenCodeShareMode>>[
                  DropdownMenuItem<OpenCodeShareMode>(
                    value: OpenCodeShareMode.manual,
                    child: Text(context.l10n.behaviorManual),
                  ),
                  DropdownMenuItem<OpenCodeShareMode>(
                    value: OpenCodeShareMode.automatic,
                    child: Text(context.l10n.behaviorAutomatic),
                  ),
                  DropdownMenuItem<OpenCodeShareMode>(
                    value: OpenCodeShareMode.disabled,
                    child: Text(context.l10n.behaviorDisabled),
                  ),
                ],
                onChanged: settingsProvider.openCodeDefaultsLoading
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }
                        unawaited(_applyShareMode(context, value));
                      },
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.behaviorChatLevelShare,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.behaviorPermissionsVariantReasoning,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataSaverCard(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    final isCellularActive = settingsProvider.isCellularConnection;
    final saverActive = settingsProvider.isCellularDataSaverActive;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsProvenanceChip(
              provenance: SettingsProvenance.codewalkException,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.behaviorCellularDataSaver,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.behaviorCutsAutomaticMobile(
                settingsProvider.cellularDataSaverInterval.inSeconds,
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<DataSaverLevel>(
                    key: const ValueKey<String>('settings_data_saver_level'),
                    segments: [
                      ButtonSegment<DataSaverLevel>(
                        value: DataSaverLevel.off,
                        label: Text(context.l10n.behaviorDataSaverOff),
                      ),
                      ButtonSegment<DataSaverLevel>(
                        value: DataSaverLevel.standard,
                        label: Text(context.l10n.behaviorDataSaverStandard),
                      ),
                      ButtonSegment<DataSaverLevel>(
                        value: DataSaverLevel.aggressive,
                        label: Text(context.l10n.behaviorDataSaverAggressive),
                      ),
                    ],
                    selected: <DataSaverLevel>{settingsProvider.dataSaverLevel},
                    onSelectionChanged: (selection) {
                      if (selection.isEmpty) {
                        return;
                      }
                      final level = selection.first;
                      unawaited(settingsProvider.setDataSaverLevel(level));
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(switch (settingsProvider.dataSaverLevel) {
              DataSaverLevel.off => context.l10n.behaviorDataSaverOffHint,
              DataSaverLevel.standard =>
                saverActive
                    ? context.l10n.behaviorDataSaverActive
                    : (isCellularActive
                          ? context.l10n.behaviorDataSaverWaiting
                          : context.l10n.behaviorDataSaverCellularOnly),
              DataSaverLevel.aggressive =>
                context.l10n.behaviorDataSaverAggressiveDescription,
            }, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildChatRenderModeCard(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    final selectedMode = settingsProvider.chatRenderMode;
    final description = switch (selectedMode) {
      ChatRenderMode.live =>
        context.l10n.settingsBehaviorChatRenderModeLiveDescription,
      ChatRenderMode.block =>
        context.l10n.settingsBehaviorChatRenderModeBlockDescription,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsProvenanceChip(
              provenance: SettingsProvenance.codewalkLocal,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.settingsBehaviorChatRenderMode,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.settingsBehaviorChatRenderModeDescription,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<ChatRenderMode>(
                    key: const ValueKey<String>('settings_chat_render_mode'),
                    segments: [
                      ButtonSegment<ChatRenderMode>(
                        value: ChatRenderMode.live,
                        icon: const Icon(Symbols.stream_rounded),
                        label: Text(
                          context.l10n.settingsBehaviorChatRenderModeLive,
                        ),
                      ),
                      ButtonSegment<ChatRenderMode>(
                        value: ChatRenderMode.block,
                        icon: const Icon(Symbols.article_rounded),
                        label: Text(
                          context.l10n.settingsBehaviorChatRenderModeBlock,
                        ),
                      ),
                    ],
                    selected: <ChatRenderMode>{selectedMode},
                    onSelectionChanged: (selection) {
                      if (selection.isEmpty) {
                        return;
                      }
                      unawaited(
                        settingsProvider.setChatRenderMode(selection.first),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(description, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildComposerSpellCheckCard(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    return Card(
      child: SwitchListTile.adaptive(
        key: const ValueKey<String>('settings_toggle_composer_spell_check'),
        title: Text(context.l10n.settingsBehaviorComposerSpellCheck),
        subtitle: Text(
          context.l10n.settingsBehaviorComposerSpellCheckDescription,
        ),
        value: settingsProvider.composerSpellCheckEnabled,
        onChanged: (value) =>
            unawaited(settingsProvider.setComposerSpellCheckEnabled(value)),
      ),
    );
  }

  Widget _buildPermissionParityCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SettingsProvenanceChip(
                  provenance: SettingsProvenance.codewalkException,
                ),
                SettingsProvenanceChip(
                  provenance: SettingsProvenance.opencodeBacked,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.behaviorPermissionHandlingProvenance,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.behaviorOfficialOpenCodePermission,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.behaviorAdvancedPermissionRule,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String? _selectedDropdownValue(
    String? currentValue,
    Iterable<String> options,
  ) {
    if (currentValue == null) {
      return null;
    }
    for (final option in options) {
      if (option == currentValue) {
        return currentValue;
      }
    }
    return null;
  }

  List<String> _modelSearchTerms(
    List<OpenCodeDefaultModelOption> modelOptions,
    String modelKey,
  ) {
    for (final option in modelOptions) {
      if (option.key == modelKey) {
        return <String>[option.key, option.label];
      }
    }
    return <String>[modelKey];
  }

  String _autoupdateModeLabel(OpenCodeAutoupdateMode mode) {
    return switch (mode) {
      OpenCodeAutoupdateMode.automatic => context.l10n.behaviorAutomatic,
      OpenCodeAutoupdateMode.notify => context.l10n.behaviorNotify,
      OpenCodeAutoupdateMode.disabled => context.l10n.behaviorDisabled,
    };
  }

  String _shareModeLabel(OpenCodeShareMode mode) {
    return switch (mode) {
      OpenCodeShareMode.manual => context.l10n.behaviorManual,
      OpenCodeShareMode.automatic => context.l10n.behaviorAutomatic,
      OpenCodeShareMode.disabled => context.l10n.behaviorDisabled,
    };
  }

  Future<void> _applyDefaultModel(BuildContext context, String modelKey) async {
    final updated = await _runDeferredConfigMutation(
      context,
      mutationKey: 'default_model',
      mutate: (settingsProvider) =>
          settingsProvider.setOpenCodeDefaultModel(modelKey),
    );
    if (!context.mounted) {
      return;
    }
    if (!updated) {
      _showFailureSnackBar(
        context,
        context.l10n.settingsBehaviorConfigUpdateFailed('default model'),
      );
      return;
    }
    await _refreshChatProviderIfAvailable(context);
  }

  Future<void> _applyDefaultAgent(
    BuildContext context,
    String agentName,
  ) async {
    final updated = await _runDeferredConfigMutation(
      context,
      mutationKey: 'default_agent',
      mutate: (settingsProvider) =>
          settingsProvider.setOpenCodeDefaultAgent(agentName),
    );
    if (!context.mounted) {
      return;
    }
    if (!updated) {
      _showFailureSnackBar(
        context,
        context.l10n.settingsBehaviorConfigUpdateFailed('default agent'),
      );
      return;
    }
    await _refreshChatProviderIfAvailable(context);
  }

  Future<void> _applySmallModel(BuildContext context, String modelKey) async {
    final updated = await _runDeferredConfigMutation(
      context,
      mutationKey: 'small_model',
      mutate: (settingsProvider) =>
          settingsProvider.setOpenCodeSmallModel(modelKey),
    );
    if (!context.mounted) {
      return;
    }
    if (!updated) {
      _showFailureSnackBar(
        context,
        context.l10n.settingsBehaviorConfigUpdateFailed('small model'),
      );
      return;
    }
    await _refreshChatProviderIfAvailable(context);
  }

  Future<void> _applyAutoupdateMode(
    BuildContext context,
    OpenCodeAutoupdateMode mode,
  ) async {
    final updated = await _runDeferredConfigMutation(
      context,
      mutationKey: 'autoupdate',
      mutate: (settingsProvider) =>
          settingsProvider.setOpenCodeAutoupdateMode(mode),
    );
    if (!context.mounted) {
      return;
    }
    if (!updated) {
      _showFailureSnackBar(
        context,
        context.l10n.settingsBehaviorConfigUpdateFailed('auto-update mode'),
      );
    }
  }

  Future<void> _applySnapshotEnabled(BuildContext context, bool enabled) async {
    final updated = await _runDeferredConfigMutation(
      context,
      mutationKey: 'snapshot',
      mutate: (settingsProvider) =>
          settingsProvider.setOpenCodeSnapshotEnabled(enabled),
    );
    if (!context.mounted) {
      return;
    }
    if (!updated) {
      _showFailureSnackBar(
        context,
        context.l10n.settingsBehaviorConfigUpdateFailed('snapshot setting'),
      );
    }
  }

  Future<void> _applyUsername(BuildContext context) async {
    final settingsProvider = context.read<SettingsProvider>();
    final normalizedUsername = _usernameController.text.trim();
    if (normalizedUsername.isEmpty) {
      if (!context.mounted) {
        return;
      }
      _showFailureSnackBar(
        context,
        settingsProvider.openCodeUsername == null
            ? context.l10n.settingsUsernameEnterHint
            : context.l10n.settingsUsernameClearHint,
      );
      return;
    }
    final updated = await _runDeferredConfigMutation(
      context,
      mutationKey: 'username',
      mutate: (settingsProvider) =>
          settingsProvider.setOpenCodeUsername(normalizedUsername),
    );
    if (!context.mounted) {
      return;
    }
    if (!updated) {
      _showFailureSnackBar(
        context,
        context.l10n.settingsBehaviorConfigUpdateFailed(
          'conversation username',
        ),
      );
    }
  }

  Future<void> _applyShareMode(
    BuildContext context,
    OpenCodeShareMode mode,
  ) async {
    final updated = await _runDeferredConfigMutation(
      context,
      mutationKey: 'share',
      mutate: (settingsProvider) => settingsProvider.setOpenCodeShareMode(mode),
    );
    if (!context.mounted) {
      return;
    }
    if (!updated) {
      _showFailureSnackBar(
        context,
        context.l10n.settingsBehaviorConfigUpdateFailed('sharing default'),
      );
    }
  }

  Future<bool> _runDeferredConfigMutation(
    BuildContext context, {
    required String mutationKey,
    required Future<bool> Function(SettingsProvider settingsProvider) mutate,
  }) async {
    final chatProvider = _readChatProviderOrNull(context);
    if (chatProvider != null && chatProvider.shouldDeferConfigMutations) {
      final generation =
          (_deferredConfigMutationGenerationByKey[mutationKey] ?? 0) + 1;
      _deferredConfigMutationGenerationByKey[mutationKey] = generation;
      _showFailureSnackBar(context, context.l10n.settingsConfigUpdateDeferred);
      final becameSafe = await _waitForConfigMutationsToBeSafe(chatProvider);
      if (!becameSafe) {
        return false;
      }
      if (!context.mounted) {
        return false;
      }
      if (_deferredConfigMutationGenerationByKey[mutationKey] != generation) {
        return true;
      }
    }
    return mutate(context.read<SettingsProvider>());
  }

  Future<bool> _waitForConfigMutationsToBeSafe(
    ChatProvider chatProvider,
  ) async {
    if (!chatProvider.shouldDeferConfigMutations) {
      return true;
    }
    final completer = Completer<void>();
    void listener() {
      if (!chatProvider.shouldDeferConfigMutations && !completer.isCompleted) {
        completer.complete();
      }
    }

    chatProvider.addListener(listener);
    try {
      if (!chatProvider.shouldDeferConfigMutations && !completer.isCompleted) {
        completer.complete();
      }
      await completer.future.timeout(const Duration(minutes: 5));
      return true;
    } on TimeoutException {
      return !chatProvider.shouldDeferConfigMutations;
    } finally {
      chatProvider.removeListener(listener);
    }
  }

  ChatProvider? _readChatProviderOrNull(BuildContext context) {
    try {
      return context.read<ChatProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> _refreshChatProviderIfAvailable(BuildContext context) async {
    try {
      final chatProvider = context.read<ChatProvider>();
      await chatProvider.initializeProviders();
    } on ProviderNotFoundException {
      // Settings tests can render this section without a ChatProvider.
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      _showFailureSnackBar(context, context.l10n.settingsConfigRefreshFailed);
    }
  }

  void _showFailureSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
