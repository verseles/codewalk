/// What a live session's composer and a new chat's share, like the retained
/// reference's composer: a rounded bubble around the field, the platform's
/// spell check unless the reader turned it off (#88), and a physical Enter
/// that sends (#174).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/theme/app_visual_style_tokens.dart';
import '../../shared/theme/chat_appearance.dart';

/// The size of the round Send and Stop buttons beside the bubble.
const composerActionSize = 42.0;

/// Whether this platform has a physical keyboard by default, where Enter
/// sends and Shift+Enter breaks the line; an on-screen keyboard's Enter
/// always breaks the line.
bool get composerEnterSends =>
    kIsWeb ||
    const {
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.windows,
    }.contains(defaultTargetPlatform);

/// Whether [event] is an Enter that sends what [value] holds: pressed on a
/// physical keyboard, without a modifier, outside an IME composition.
bool isComposerSendKey(KeyEvent event, TextEditingValue value) {
  if (!composerEnterSends || event is! KeyDownEvent) return false;
  if (event.logicalKey != LogicalKeyboardKey.enter &&
      event.logicalKey != LogicalKeyboardKey.numpadEnter) {
    return false;
  }
  final keyboard = HardwareKeyboard.instance;
  return !keyboard.isShiftPressed &&
      !keyboard.isControlPressed &&
      !keyboard.isAltPressed &&
      !keyboard.isMetaPressed &&
      value.composing.isCollapsed;
}

/// The field's spell check: the platform's own when the reader keeps it on
/// and the platform has one; nothing is sent to another service.
SpellCheckConfiguration composerSpellCheckConfiguration(BuildContext context) {
  final enabled = ChatAppearance.maybeOf(context)?.composerSpellCheck ?? true;
  if (!enabled ||
      !WidgetsBinding
          .instance
          .platformDispatcher
          .nativeSpellCheckServiceDefined) {
    return const SpellCheckConfiguration.disabled();
  }
  return const SpellCheckConfiguration();
}

/// Whether the field autocorrects and suggests, as the reader chose.
bool composerSuggests(BuildContext context) =>
    ChatAppearance.maybeOf(context)?.composerSpellCheck ?? true;

/// The rounded bubble the field sits in, without an outline.
class ComposerBubble extends StatelessWidget {
  const ComposerBubble({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).visualStyleTokens;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: composerActionSize),
      child: DecoratedBox(
        key: const ValueKey('composer-bubble'),
        decoration: BoxDecoration(
          color: tokens.composerSurface,
          borderRadius: tokens.cardRadius,
          boxShadow: tokens.composerShadow,
        ),
        child: ClipRRect(
          borderRadius: tokens.cardRadius,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 2, 8, 2),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The field's decoration inside the bubble: the hint and no border.
InputDecoration composerDecoration(BuildContext context, String hint) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  return InputDecoration(
    hintText: hint,
    hintStyle: theme.textTheme.bodyMedium?.copyWith(
      color: theme.brightness == Brightness.dark
          ? scheme.onSurface.withValues(alpha: 0.72)
          : scheme.onSurfaceVariant.withValues(alpha: 0.88),
    ),
    isDense: true,
    filled: false,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    contentPadding: const EdgeInsets.symmetric(vertical: 10),
  );
}

/// The round Send button: filled while there is something to send.
class ComposerSendButton extends StatelessWidget {
  const ComposerSendButton({
    super.key,
    this.buttonKey,
    required this.tooltip,
    required this.onPressed,
    this.onDoubleTap,
    this.icon = Icons.arrow_upward_rounded,
  });

  /// The key of the button itself, so its state can be read.
  final Key? buttonKey;
  final String tooltip;
  final VoidCallback? onPressed;

  /// A double tap while the button has nothing to send (#82).
  final VoidCallback? onDoubleTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final button = SizedBox.square(
      dimension: composerActionSize,
      child: IconButton.filled(
        key: buttonKey,
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          fixedSize: const Size.square(composerActionSize),
          minimumSize: const Size.square(composerActionSize),
          shape: const CircleBorder(),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.surfaceContainerHighest,
          disabledForegroundColor: scheme.onSurfaceVariant,
          elevation: enabled ? 1.5 : 0,
          shadowColor: scheme.primary.withValues(alpha: 0.3),
        ),
        icon: Icon(icon, size: 20),
      ),
    );
    // A click on Send is part of the field's region, so a desktop field
    // keeps its focus for the next prompt (#174).
    return TextFieldTapRegion(
      child: onDoubleTap == null
          ? button
          : GestureDetector(onDoubleTap: onDoubleTap, child: button),
    );
  }
}
