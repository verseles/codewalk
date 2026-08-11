import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/i18n/l10n_context.dart';
import '../../domain/entities/project.dart';
import '../services/session_tab_icon_presets.dart';
import 'project_icon.dart';

class SessionTabIconSelection {
  const SessionTabIconSelection(this.presetId);

  final String? presetId;
}

Future<SessionTabIconSelection?> showSessionTabIconPicker(
  BuildContext context, {
  required String? currentPresetId,
  required Project? project,
}) {
  return showDialog<SessionTabIconSelection>(
    context: context,
    builder: (dialogContext) {
      final content = _SessionTabIconPickerContent(
        currentPresetId: currentPresetId,
        project: project,
      );
      final availableSize = MediaQuery.sizeOf(dialogContext);
      if (availableSize.width < 600 || availableSize.height < 620) {
        return Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: MaterialLocalizations.of(
                  dialogContext,
                ).closeButtonTooltip,
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Symbols.close),
              ),
              title: Text(dialogContext.l10n.sessionTabIconPickerTitle),
            ),
            body: SafeArea(child: content),
          ),
        );
      }
      return AlertDialog(
        title: Text(dialogContext.l10n.sessionTabIconPickerTitle),
        content: SizedBox(width: 520, height: 430, child: content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
        ],
      );
    },
  );
}

class _SessionTabIconPickerContent extends StatelessWidget {
  const _SessionTabIconPickerContent({
    required this.currentPresetId,
    required this.project,
  });

  final String? currentPresetId;
  final Project? project;

  @override
  Widget build(BuildContext context) {
    final selectedPreset = SessionTabIconPreset.fromId(currentPresetId);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SizedBox(
            key: const ValueKey<String>('session_tab_icon_picker_preview'),
            width: 56,
            height: 56,
            child: selectedPreset == null
                ? _projectIcon(context, size: 36)
                : Icon(selectedPreset.icon, size: 36),
          ),
        ),
        Expanded(
          child: GridView.extent(
            key: const ValueKey<String>('session_tab_icon_picker_grid'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            maxCrossAxisExtent: 150,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.25,
            children: [
              _tile(
                context,
                key: 'project',
                label: context.l10n.sessionTabIconUseProjectIcon,
                selected: selectedPreset == null,
                icon: _projectIcon(context, size: 24),
                presetId: null,
              ),
              for (final preset in SessionTabIconPreset.values)
                _tile(
                  context,
                  key: preset.id,
                  label: sessionTabIconPresetLabel(context.l10n, preset),
                  selected: selectedPreset == preset,
                  icon: Icon(preset.icon, size: 24),
                  presetId: preset.id,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _projectIcon(BuildContext context, {required double size}) {
    final value = project;
    if (value == null) return Icon(Symbols.folder_open, size: size);
    return ProjectIcon(project: value, size: size, autoDiscover: false);
  }

  Widget _tile(
    BuildContext context, {
    required String key,
    required String label,
    required bool selected,
    required Widget icon,
    required String? presetId,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    void select() =>
        Navigator.of(context).pop(SessionTabIconSelection(presetId));
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: select,
      child: Tooltip(
        message: label,
        child: Material(
          color: selected
              ? colorScheme.secondaryContainer
              : colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            key: ValueKey<String>('session_tab_icon_option_$key'),
            borderRadius: BorderRadius.circular(16),
            onTap: select,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ExcludeSemantics(child: icon),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    const PositionedDirectional(
                      top: 0,
                      end: 0,
                      child: Icon(Symbols.check_circle, size: 18),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
