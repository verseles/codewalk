import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Enter or NumpadEnter runs a dialog's one safe primary action (#171,
/// ADR-024). Only for a non-destructive dialog with a single clear primary
/// action: never a delete, a trust or Unrestricted change, a shortcut
/// capture, multiline editing or a picker.
///
/// Enter activates, as everywhere: a focused control that activates itself,
/// such as Cancel or a list row, keeps it; only otherwise does the dialog's
/// primary action run.
class ModalPrimaryActionShortcuts extends StatelessWidget {
  const ModalPrimaryActionShortcuts({
    super.key,
    required this.onPrimaryAction,
    required this.child,
    this.enabled = true,
  });

  final VoidCallback onPrimaryAction;
  final Widget child;

  /// Whether the primary action can run now, as its button would.
  final bool enabled;

  // A focused control's own activation comes first. Only Enter confirms:
  // Space, which also activates, never reaches the primary action.
  static const _confirm = PrioritizedIntents(
    orderedIntents: [ActivateIntent(), _ConfirmIntent()],
  );

  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.enter): _confirm,
      SingleActivator(LogicalKeyboardKey.numpadEnter): _confirm,
    },
    child: Actions(
      actions: {
        _ConfirmIntent: CallbackAction<_ConfirmIntent>(
          onInvoke: (_) {
            if (enabled) onPrimaryAction();
            return null;
          },
        ),
      },
      // Holds the dialog's first focus, so Enter reaches it before any
      // field is focused; Tab still starts at the dialog's own controls.
      child: Focus(autofocus: true, skipTraversal: true, child: child),
    ),
  );
}

/// Enter's confirmation of the dialog's primary action.
class _ConfirmIntent extends Intent {
  const _ConfirmIntent();
}
