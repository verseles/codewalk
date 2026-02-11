import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../domain/entities/experience_settings.dart';
import '../../../providers/settings_provider.dart';
import '../../../utils/shortcut_binding_codec.dart';

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
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        final query = _searchController.text.trim().toLowerCase();
        final visible = kShortcutDefinitions
            .where((definition) {
              if (query.isEmpty) {
                return true;
              }
              final raw =
                  '${definition.group} ${definition.label} ${definition.description} ${settingsProvider.bindingFor(definition.action)}'
                      .toLowerCase();
              return raw.contains(query);
            })
            .toList(growable: false);

        return ListView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          children: [
            Text(
              'Keyboard shortcuts',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Search, edit bindings, and resolve conflicts before saving.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search shortcuts',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => settingsProvider.resetAllShortcuts(),
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset all'),
              ),
            ),
            const SizedBox(height: 4),
            ...visible.map(
              (definition) => _ShortcutTile(
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
            ),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(definition.label),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(definition.description),
            const SizedBox(height: 2),
            Text(
              '${definition.group} • ${ShortcutBindingCodec.formatForDisplay(binding)}',
            ),
            if (conflict != null)
              Text(
                'Conflict with $conflict',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: 'Edit shortcut',
              onPressed: onEdit,
              icon: const Icon(Icons.keyboard_rounded),
            ),
            IconButton(
              tooltip: 'Reset shortcut',
              onPressed: onReset,
              icon: const Icon(Icons.undo_rounded),
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
      title: Text('Set shortcut: ${widget.definition.label}'),
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
                  ? 'Press the key combination now'
                  : ShortcutBindingCodec.formatForDisplay(_captured!),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _captured == null
              ? null
              : () => Navigator.of(context).pop(_captured),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
