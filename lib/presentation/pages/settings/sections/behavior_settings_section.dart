import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../widgets/searchable_dropdown_form_field.dart';
import '../../../widgets/settings_provenance_chip.dart';

class BehaviorSettingsSection extends StatefulWidget {
  const BehaviorSettingsSection({super.key});

  @override
  State<BehaviorSettingsSection> createState() =>
      _BehaviorSettingsSectionState();
}

class _BehaviorSettingsSectionState extends State<BehaviorSettingsSection> {
  late final TextEditingController _usernameController;
  late final FocusNode _usernameFocusNode;
  final Map<String, int> _deferredConfigMutationGenerationByKey =
      <String, int>{};

  @override
  void initState() {
    super.initState();
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
    _usernameController.dispose();
    _usernameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        return ListView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          children: [
            Text('Behavior', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Control shared OpenCode defaults and local composer sync behavior.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _buildOpenCodeDefaultsCard(context, settingsProvider),
            const SizedBox(height: 16),
            _buildPermissionParityCard(context),
            const SizedBox(height: 16),
            _buildDataSaverCard(context, settingsProvider),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    key: const ValueKey<String>(
                      'settings_toggle_experimental_multi_device_sync',
                    ),
                    title: const Text('Enable experimental multi-device sync'),
                    subtitle: const Text(
                      'Sync composer selection (agent/model/variant) with the active server config.',
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
                        'Can abort ongoing sessions when working in more than one session at the same time.',
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
                        'OpenCode-backed defaults',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'These values write to `/config` on the active server and match official OpenCode shared config.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh defaults',
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
                decoration: const InputDecoration(
                  labelText: 'Default model',
                  border: OutlineInputBorder(),
                  helperText: 'Shared across OpenCode clients through config.',
                ),
                isExpanded: true,
                searchHintText: 'Search default model',
                emptyText: 'No models found',
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
                decoration: const InputDecoration(
                  labelText: 'Default agent',
                  border: OutlineInputBorder(),
                  helperText:
                      'Primary agent used when no agent is explicitly chosen.',
                ),
                isExpanded: true,
                searchHintText: 'Search default agent',
                emptyText: 'No agents found',
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
                decoration: const InputDecoration(
                  labelText: 'Conversation username',
                  border: OutlineInputBorder(),
                  helperText:
                      'Custom display name shown in conversations instead of the system username.',
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
                  label: const Text('Save username'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                username == null
                    ? 'OpenCode uses the system username because `username` is unset.'
                    : 'Resetting `username` back to the system default still requires editing config outside the app because `/config` patch updates cannot remove keys.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                key: const ValueKey<String>('settings_opencode_snapshot'),
                contentPadding: EdgeInsets.zero,
                title: const Text('OpenCode snapshots'),
                subtitle: const Text(
                  'Keep upstream git-backed snapshots enabled for undo/redo and recovery history.',
                ),
                value: snapshotEnabled,
                onChanged: settingsProvider.openCodeDefaultsLoading
                    ? null
                    : (value) =>
                          unawaited(_applySnapshotEnabled(context, value)),
              ),
              const SizedBox(height: 8),
              Text(
                'This controls OpenCode snapshot storage and undo/redo support, not CodeWalk local cache snapshots.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              SearchableDropdownFormField<String>(
                key: const ValueKey<String>('settings_opencode_small_model'),
                value: _selectedDropdownValue(
                  smallModelKey,
                  modelOptions.map((option) => option.key),
                ),
                hint: const Text('Automatic fallback'),
                decoration: const InputDecoration(
                  labelText: 'Small model',
                  border: OutlineInputBorder(),
                  helperText:
                      'Used for lightweight tasks like title generation.',
                ),
                isExpanded: true,
                searchHintText: 'Search small model',
                emptyText: 'No models found',
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
                    ? 'OpenCode automatic fallback is active because `small_model` is unset.'
                    : 'Resetting `small_model` back to automatic fallback still requires editing config outside the app because `/config` patch updates cannot remove keys.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              SearchableDropdownFormField<OpenCodeAutoupdateMode>(
                key: const ValueKey<String>('settings_opencode_autoupdate'),
                value: autoupdateMode,
                decoration: const InputDecoration(
                  labelText: 'OpenCode auto-update',
                  border: OutlineInputBorder(),
                  helperText:
                      'Controls upstream OpenCode runtime updates, not CodeWalk app update checks.',
                ),
                searchHintText: 'Search auto-update mode',
                searchTermsBuilder: (value) => <String>[
                  _autoupdateModeLabel(value),
                ],
                items: const <DropdownMenuItem<OpenCodeAutoupdateMode>>[
                  DropdownMenuItem<OpenCodeAutoupdateMode>(
                    value: OpenCodeAutoupdateMode.automatic,
                    child: Text('Automatic'),
                  ),
                  DropdownMenuItem<OpenCodeAutoupdateMode>(
                    value: OpenCodeAutoupdateMode.notify,
                    child: Text('Notify only'),
                  ),
                  DropdownMenuItem<OpenCodeAutoupdateMode>(
                    value: OpenCodeAutoupdateMode.disabled,
                    child: Text('Disabled'),
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
                'Use About for CodeWalk release checks. This setting only mirrors the official OpenCode `autoupdate` config.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              SearchableDropdownFormField<OpenCodeShareMode>(
                key: const ValueKey<String>('settings_opencode_share_mode'),
                value: shareMode,
                decoration: const InputDecoration(
                  labelText: 'OpenCode sharing default',
                  border: OutlineInputBorder(),
                  helperText:
                      'Controls the official global `share` config, not the share button for an individual chat.',
                ),
                searchHintText: 'Search sharing mode',
                searchTermsBuilder: (value) => <String>[_shareModeLabel(value)],
                items: const <DropdownMenuItem<OpenCodeShareMode>>[
                  DropdownMenuItem<OpenCodeShareMode>(
                    value: OpenCodeShareMode.manual,
                    child: Text('Manual'),
                  ),
                  DropdownMenuItem<OpenCodeShareMode>(
                    value: OpenCodeShareMode.automatic,
                    child: Text('Automatic'),
                  ),
                  DropdownMenuItem<OpenCodeShareMode>(
                    value: OpenCodeShareMode.disabled,
                    child: Text('Disabled'),
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
                'Use the chat-level share action to publish one session now. This setting only changes OpenCode’s default sharing policy.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Text(
                'Permissions and variant/reasoning parity stay separate until their UI can preserve advanced config safely.',
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
              'Cellular data saver',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Cuts automatic mobile-data usage by stopping background downloads and throttling automatic foreground refreshes to one burst every ${settingsProvider.cellularDataSaverInterval.inSeconds} seconds.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              key: const ValueKey<String>(
                'settings_toggle_cellular_data_saver',
              ),
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable cellular data saver'),
              subtitle: Text(
                saverActive
                    ? 'Active now on mobile data.'
                    : (isCellularActive
                          ? 'Waiting for the next mobile-data sync window.'
                          : 'Only applies when the connection is cellular/mobile.'),
              ),
              value: settingsProvider.dataSaverEnabled,
              onChanged: (value) =>
                  unawaited(settingsProvider.setDataSaverEnabled(value)),
            ),
          ],
        ),
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
              'Permission handling provenance',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Official OpenCode permission policy is configured in `opencode.json` with allow/ask/deny rules per tool. CodeWalk keeps the official permission-request cards and adds one approved ADR-023 exception: the composer auto-approve toggle replies with `Always` when the request supports remembered approval, otherwise `Allow Once`, and keeps the same thread-scoped continuity path active in the Android background worker.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Text(
              'Advanced permission rule editing stays out of Settings for now and is deferred to later parity work.',
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
      OpenCodeAutoupdateMode.automatic => 'Automatic',
      OpenCodeAutoupdateMode.notify => 'Notify only',
      OpenCodeAutoupdateMode.disabled => 'Disabled',
    };
  }

  String _shareModeLabel(OpenCodeShareMode mode) {
    return switch (mode) {
      OpenCodeShareMode.manual => 'Manual',
      OpenCodeShareMode.automatic => 'Automatic',
      OpenCodeShareMode.disabled => 'Disabled',
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
        'Could not update the OpenCode default model.',
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
        'Could not update the OpenCode default agent.',
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
        'Could not update the OpenCode small model.',
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
        'Could not update the OpenCode auto-update mode.',
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
        'Could not update the OpenCode snapshot setting.',
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
            ? 'Enter a username to save a custom OpenCode conversation name.'
            : 'Clearing the OpenCode conversation username still requires editing config outside the app.',
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
        'Could not update the OpenCode conversation username.',
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
        'Could not update the OpenCode sharing default.',
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
      _showFailureSnackBar(
        context,
        'CodeWalk will apply this OpenCode setting after the current response finishes.',
      );
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
      _showFailureSnackBar(
        context,
        'Updated the server setting, but could not refresh chat providers.',
      );
    }
  }

  void _showFailureSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
