import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Enter or NumpadEnter runs a dialog's one safe primary action (#171,
/// ADR-024). Only for a non-destructive dialog with a single clear primary
/// action: never a delete, a trust or Unrestricted change, a shortcut
/// capture, multiline editing or a picker. A control that handles Enter
/// itself, such as a focused button, keeps it.
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

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: enabled
        ? {
            const SingleActivator(LogicalKeyboardKey.enter): onPrimaryAction,
            const SingleActivator(LogicalKeyboardKey.numpadEnter):
                onPrimaryAction,
          }
        : const {},
    // Holds the dialog's first focus, so Enter reaches it before any field
    // is focused; Tab still starts at the dialog's own controls.
    child: Focus(autofocus: true, skipTraversal: true, child: child),
  );
}
