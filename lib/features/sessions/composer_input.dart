/// What a live session's composer and a new chat's share, like the retained
/// reference's composer: a rounded bubble around the field, the platform's
/// spell check unless the reader turned it off (#88), and a physical Enter
/// that sends (#174).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../shared/theme/app_surface_tokens.dart';
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

/// Whether the composer always shows its open layout (#484): everywhere but
/// a touch-first platform, where it opens while the field has focus.
bool get composerAlwaysOpen => !const {
  TargetPlatform.android,
  TargetPlatform.iOS,
  TargetPlatform.fuchsia,
}.contains(defaultTargetPlatform);

/// The rounded bubble the field and its controls sit in, without an outline.
class ComposerBubble extends StatelessWidget {
  const ComposerBubble({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).surfaceTokens;
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
          // 4 keeps the open composer (two rows) at 98 dp, so a phone with
          // its keyboard open still has room for the `/` picker (#278).
          child: Padding(padding: const EdgeInsets.all(4), child: child),
        ),
      ),
    );
  }
}

/// The composer (#484), one bubble for the field and every control. Closed
/// it is one line: Attach, the field, Voice and [action]. Open, the field
/// sits on top and one row below holds Attach, [chip], Voice and [action].
/// It opens while anything inside it has focus on a phone, so Tab can reach
/// the chip, and stays open elsewhere.
/// Attach and Voice name what is coming and stay disabled until it does.
class ComposerFrame extends StatefulWidget {
  const ComposerFrame({
    super.key,
    required this.field,
    required this.action,
    required this.attachTooltip,
    required this.voiceTooltip,
    this.chip,
  });

  /// The field, given whether the composer is open.
  final Widget Function(BuildContext context, bool open) field;
  final Widget action;
  final String attachTooltip;
  final String voiceTooltip;
  final Widget? chip;

  @override
  State<ComposerFrame> createState() => _ComposerFrameState();
}

class _ComposerFrameState extends State<ComposerFrame> {
  /// Holds the focus of everything inside the frame, never its own.
  final _frame = FocusNode(
    debugLabel: 'composer frame',
    canRequestFocus: false,
    skipTraversal: true,
  );

  @override
  void initState() {
    super.initState();
    _frame.addListener(_changed);
    // A field that already had focus when the frame was built (a draft that
    // focuses itself) gives the frame no focus change to hear, so the frame
    // looks once more after its first layout. A closed field is one line,
    // and a one-line field drops line breaks from what is typed into it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _changed());
  }

  @override
  void dispose() {
    _frame
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Widget _soon(String key, IconData icon, String tooltip) => SizedBox.square(
    key: ValueKey(key),
    dimension: composerActionSize,
    child: IconButton(
      tooltip: tooltip,
      onPressed: null,
      padding: EdgeInsets.zero,
      icon: Icon(icon, size: 22),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final open = composerAlwaysOpen || _frame.hasFocus;
    final attach = _soon('composer-attach', Symbols.add, widget.attachTooltip);
    final voice = _soon('composer-voice', Symbols.mic, widget.voiceTooltip);
    // The field keeps its place in the first row whether the composer is
    // open or not, so opening never rebuilds it and never drops its focus.
    final field = Expanded(
      key: const ValueKey('composer-field'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: widget.field(context, open),
      ),
    );
    final chip = widget.chip;
    const gap = SizedBox(width: 4);
    // The controls are part of the field's region, so pressing one keeps a
    // desktop field's focus (#174).
    return Focus(
      focusNode: _frame,
      child: TextFieldTapRegion(
        child: ComposerBubble(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (!open) attach,
                  field,
                  if (!open) ...[voice, gap, widget.action],
                ],
              ),
              // The second row stays in the tree, hidden, while the composer
              // is closed: a pick opened from the chip moves the focus away,
              // and the chip must outlive that to apply the pick.
              Visibility(
                visible: open,
                maintainState: true,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      if (open) ...[attach, gap],
                      // The chip may use the whole gap; what it leaves stays
                      // after it, so the mic and Send keep to the end.
                      Expanded(
                        key: const ValueKey('composer-chip'),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: chip ?? const SizedBox.shrink(),
                        ),
                      ),
                      if (open) ...[voice, gap, widget.action],
                    ],
                  ),
                ),
              ),
            ],
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
    this.onChoose,
    // An upward arrow, not v1's plane (owner, beta.21).
    this.icon = Symbols.arrow_upward,
  });

  /// The key of the button itself, so its state can be read.
  final Key? buttonKey;
  final String tooltip;
  final VoidCallback? onPressed;

  /// A double tap while the button has nothing to send (#82).
  final VoidCallback? onDoubleTap;

  /// Opens the delivery choice (#470) on a hold, enabled or not, and on a
  /// right click. Touch then no longer opens the tooltip; a mouse still shows
  /// it on hover.
  final VoidCallback? onChoose;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    Widget button = SizedBox.square(
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
        icon: Icon(icon, size: 24),
      ),
    );
    final choose = onChoose;
    if (choose != null) {
      button = TooltipTheme(
        data: TooltipTheme.of(
          context,
        ).copyWith(triggerMode: TooltipTriggerMode.manual),
        child: button,
      );
    }
    // A click on Send is part of the field's region, so a desktop field
    // keeps its focus for the next prompt (#174).
    return TextFieldTapRegion(
      child: onDoubleTap == null && choose == null
          ? button
          : GestureDetector(
              onDoubleTap: onDoubleTap,
              onLongPress: choose,
              onSecondaryTapUp: choose == null ? null : (_) => choose(),
              child: button,
            ),
    );
  }
}
