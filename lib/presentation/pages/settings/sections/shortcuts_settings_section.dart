import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/config/feature_flags.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../domain/entities/experience_settings.dart';
import '../../../providers/settings_provider.dart';
import '../../../utils/shortcut_binding_codec.dart';
import '../../../utils/shortcut_l10n.dart';
import '../../../widgets/direct_provider.dart';
import '../../../widgets/settings_provenance_chip.dart';
import '../widgets/settings_section_layout.dart';

class ShortcutsSettingsSection extends StatefulWidget {
  const ShortcutsSettingsSection({super.key});

  @override
  State<ShortcutsSettingsSection> createState() =>
      _ShortcutsSettingsSectionState();
}

class _ShortcutsSettingsSectionState extends State<ShortcutsSettingsSection> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DirectConsumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        final query = _searchController.text.trim().toLowerCase();
        final visibleDefinitions = shortcutDefinitionsForRuntime(
          isWeb: kIsWeb,
          targetPlatform: defaultTargetPlatform,
          refreshlessRealtimeEnabled: FeatureFlags.refreshlessRealtime,
        );
        final visible = visibleDefinitions
            .where((definition) {
              if (query.isEmpty) {
                return true;
              }
              final l10n = context.l10n;
              final raw =
                  '${definition.localizedGroup(l10n)} ${definition.localizedLabel(l10n)} ${definition.localizedDescription(l10n)} ${settingsProvider.bindingFor(definition.action)}'
                      .toLowerCase();
              return raw.contains(query);
            })
            .toList(growable: false);
        final grouped = <String, List<ShortcutDefinition>>{};
        for (final definition in visible) {
          grouped
              .putIfAbsent(
                definition.localizedGroup(context.l10n),
                () => <ShortcutDefinition>[],
              )
              .add(definition);
        }

        return ListView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          children: [
            SettingsSectionIntro(
              title: context.l10n.shortcutsKeyboardShortcuts,
              description: context.l10n.shortcutsSearchEditBindings,
            ),
            const SizedBox(height: 12),
            const SettingsProvenanceChip(
              provenance: SettingsProvenance.codewalkLocal,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.shortcutsTheseBindingsStored,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: context.l10n.settingsShortcutsSearch,
                prefixIcon: const Icon(Symbols.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Symbols.clear),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => settingsProvider.resetAllShortcuts(),
                icon: const Icon(Symbols.restart_alt),
                label: Text(context.l10n.shortcutsReset),
              ),
            ),
            const SizedBox(height: 4),
            for (final group in grouped.entries) ...[
              SettingsGroupHeader(title: group.key),
              const SizedBox(height: 8),
              for (final definition in group.value)
                _ShortcutTile(
                  definition: definition,
                  binding: settingsProvider.bindingFor(definition.action),
                  conflict: settingsProvider.findShortcutConflict(
                    definition.action,
                    settingsProvider.bindingFor(definition.action),
                  ),
                  onEdit: () =>
                      _editShortcut(context, settingsProvider, definition),
                  onReset: () =>
                      settingsProvider.clearShortcut(definition.action),
                ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }

  Future<void> _editShortcut(
    BuildContext context,
    SettingsProvider settingsProvider,
    ShortcutDefinition definition,
  ) async {
    final captured = await showDialog<String>(
      context: context,
      builder: (_) => _ShortcutCaptureDialog(definition: definition),
    );
    if (captured == null) {
      return;
    }

    final error = await settingsProvider.updateShortcut(
      definition.action,
      captured,
    );
    if (!context.mounted || error == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.definition,
    required this.binding,
    required this.conflict,
    required this.onEdit,
    required this.onReset,
  });

  final ShortcutDefinition definition;
  final String binding;
  final String? conflict;
  final VoidCallback onEdit;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(definition.localizedLabel(l10n)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(definition.localizedDescription(l10n)),
            const SizedBox(height: 2),
            Text(
              '${definition.localizedGroup(l10n)} • ${ShortcutBindingCodec.formatForDisplay(binding)}',
            ),
            if (conflict != null)
              Text(
                context.l10n.shortcutsConflictConflict(conflict!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: context.l10n.settingsShortcutsEdit,
              onPressed: onEdit,
              icon: const Icon(Symbols.keyboard_rounded),
            ),
            IconButton(
              tooltip: context.l10n.settingsShortcutsReset,
              onPressed: onReset,
              icon: const Icon(Symbols.undo_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutCaptureDialog extends StatefulWidget {
  const _ShortcutCaptureDialog({required this.definition});

  final ShortcutDefinition definition;

  @override
  State<_ShortcutCaptureDialog> createState() => _ShortcutCaptureDialogState();
}

class _ShortcutCaptureDialogState extends State<_ShortcutCaptureDialog> {
  final FocusNode _focusNode = FocusNode();
  String? _captured;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        context.l10n.shortcutsSetShortcutWidget(
          widget.definition.localizedLabel(context.l10n),
        ),
      ),
      content: SizedBox(
        width: 360,
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            final captured = ShortcutBindingCodec.fromKeyEvent(event);
            if (captured == null) {
              return KeyEventResult.ignored;
            }
            setState(() {
              _captured = captured;
            });
            return KeyEventResult.handled;
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _captured == null
                  ? context.l10n.shortcutsPressKeyCombination
                  : ShortcutBindingCodec.formatForDisplay(_captured!),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.serversCancel),
        ),
        FilledButton(
          onPressed: _captured == null
              ? null
              : () => Navigator.of(context).pop(_captured),
          child: Text(context.l10n.shortcutsApply),
        ),
      ],
    );
  }
}
