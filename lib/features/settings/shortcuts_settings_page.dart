import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/app_keyboard_shortcuts.dart';
import '../../app/app_preferences_controller.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/shortcuts/shortcut_action.dart';
import '../../shared/shortcuts/shortcut_binding_codec.dart';

class ShortcutsSettingsPage extends StatefulWidget {
  const ShortcutsSettingsPage({super.key});

  @override
  State<ShortcutsSettingsPage> createState() => _ShortcutsSettingsPageState();
}

class _ShortcutsSettingsPageState extends State<ShortcutsSettingsPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppPreferencesController>();
    final l = context.v2L10n;
    final query = _search.text.trim().toLowerCase();
    final groups = <String, List<ShortcutAction>>{};
    for (final action in ShortcutAction.values) {
      final binding = p.shortcutIsInvalid(action)
          ? ''
          : p.shortcutBindingFor(action);
      final label =
          action == ShortcutAction.escape &&
              KeyboardActionScope.isAvailable(context, action)
          ? l.settingsBack
          : action.label(l);
      final searchable =
          '$label ${action.description(l)} '
                  '${action.group(l)} $binding ${ShortcutBindingCodec.display(binding)}'
              .toLowerCase();
      if (searchable.contains(query)) {
        groups.putIfAbsent(action.group(l), () => []).add(action);
      }
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l.shortcutsKeyboardShortcuts,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(l.shortcutsSearchEditBindings),
            const SizedBox(height: 8),
            Text(
              l.settingsProvenanceCodeWalkLocal,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(l.shortcutsTheseBindingsStored),
            if (p.hasPersistenceError)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.settingsStorageError),
                      TextButton(
                        onPressed: p.retryPersistence,
                        child: Text(l.chatRetry),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('settings_shortcuts_search'),
              controller: _search,
              decoration: InputDecoration(
                labelText: l.settingsShortcutsSearch,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                key: const ValueKey('settings_shortcuts_reset'),
                onPressed: p.resetAllShortcuts,
                child: Text(l.shortcutsReset),
              ),
            ),
            if (groups.isEmpty) Text(l.settingsNavigationNoResults),
            for (final group in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Text(
                  group.key,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              for (final action in group.value) _tile(context, p, action),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    AppPreferencesController p,
    ShortcutAction action,
  ) {
    final l = context.v2L10n;
    final available = KeyboardActionScope.isAvailable(context, action);
    final binding = p.shortcutBindingFor(action);
    final invalid = p.shortcutIsInvalid(action);
    final conflict = p.shortcutConflict(action, binding);
    final label = available && action == ShortcutAction.escape
        ? l.settingsBack
        : action.label(l);
    return Card(
      key: ValueKey('settings_shortcut_${action.key}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            if (available && action == ShortcutAction.escape)
              Text(l.settingsBack)
            else
              Text(action.description(l)),
            if (!available) Text(l.shortcutsUnavailable),
            Text(
              invalid
                  ? l.shortcutsErrorInvalid
                  : binding.isEmpty
                  ? l.shortcutsUnassigned
                  : ShortcutBindingCodec.display(binding),
            ),
            if (conflict != null)
              Text(
                l.shortcutsConflictConflict(conflict.label(l)),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            Wrap(
              spacing: 8,
              children: [
                IconButton(
                  key: ValueKey('shortcut_edit_${action.key}'),
                  tooltip: l.settingsShortcutsEdit,
                  onPressed: () => _edit(p, action),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  key: ValueKey('shortcut_unassign_${action.key}'),
                  tooltip: l.shortcutsUnassign,
                  onPressed: binding.isEmpty && !invalid
                      ? null
                      : () => p.setShortcutBinding(action, ''),
                  icon: const Icon(Icons.block),
                ),
                IconButton(
                  key: ValueKey('shortcut_reset_${action.key}'),
                  tooltip: l.settingsShortcutsReset,
                  onPressed: () => p.setShortcutBinding(action, null),
                  icon: const Icon(Icons.restart_alt),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(AppPreferencesController p, ShortcutAction action) async {
    final binding = await showDialog<String>(
      context: context,
      builder: (_) => _ShortcutCaptureDialog(preferences: p, action: action),
    );
    if (!mounted || p.isDisposed || binding == null) return;
    final conflict = p.shortcutConflict(action, binding);
    if (conflict != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.v2L10n.shortcutsErrorConflict(
              conflict.label(context.v2L10n),
            ),
          ),
        ),
      );
      return;
    }
    p.setShortcutBinding(action, binding);
  }
}

class _ShortcutCaptureDialog extends StatefulWidget {
  const _ShortcutCaptureDialog({
    required this.preferences,
    required this.action,
  });
  final AppPreferencesController preferences;
  final ShortcutAction action;

  @override
  State<_ShortcutCaptureDialog> createState() => _ShortcutCaptureDialogState();
}

class _ShortcutCaptureDialogState extends State<_ShortcutCaptureDialog> {
  String? _binding;

  KeyEventResult _capture(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || event.synthesized) {
      return KeyEventResult.ignored;
    }
    final binding = ShortcutBindingCodec.capture(event);
    if (binding == null) return KeyEventResult.ignored;
    setState(() => _binding = binding);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.preferences,
    builder: (context, child) {
      final l = context.v2L10n;
      final binding = _binding;
      final conflict = binding == null
          ? null
          : widget.preferences.shortcutConflict(widget.action, binding);
      return Focus(
        autofocus: true,
        onKeyEvent: _capture,
        child: AlertDialog(
          title: Text(l.shortcutsSetShortcutWidget(widget.action.label(l))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.shortcutsPressKeyCombination),
              if (binding != null) Text(ShortcutBindingCodec.display(binding)),
              if (conflict != null)
                Text(
                  l.shortcutsErrorConflict(conflict.label(l)),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.commonCancel),
            ),
            FilledButton(
              key: const ValueKey('shortcut_capture_apply'),
              onPressed: binding == null || conflict != null
                  ? null
                  : () => Navigator.pop(context, binding),
              child: Text(l.shortcutsApply),
            ),
          ],
        ),
      );
    },
  );
}
