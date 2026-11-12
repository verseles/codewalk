import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../shared/l10n/l10n_context.dart';
import 'session_timeline_search.dart';

/// The bar of the search in the open conversation (#462), above the
/// timeline: the field, where the current match stands, older and newer
/// matches, and close. Enter and F3 go to the next older match, Shift with
/// either to the next newer one, and Escape closes.
class SessionSearchBar extends StatefulWidget {
  const SessionSearchBar({
    super.key,
    required this.search,
    required this.items,
    this.reasoning = true,
    this.held = const {},
    this.onClose,
  });

  /// Its height, which grows with large text and which the page reserves
  /// above the composer's budget.
  static double heightOf(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(48).clamp(48, 112).toDouble();

  final SessionTimelineSearch search;

  /// The items the timeline shows, in the server's order.
  final List<TimelineItem> items;

  /// Whether reasoning is shown, and so searched.
  final bool reasoning;

  /// The answers and reasoning the Block render mode does not show yet.
  final Set<ItemId> held;

  /// Called after the bar closes, to give the focus back.
  final VoidCallback? onClose;

  @override
  State<SessionSearchBar> createState() => _SessionSearchBarState();
}

class _SessionSearchBarState extends State<SessionSearchBar> {
  late final _text = TextEditingController(text: widget.search.query);
  final _focus = FocusNode();
  int _focuses = -1;

  @override
  void initState() {
    super.initState();
    _takeFocus();
  }

  @override
  void didUpdateWidget(covariant SessionSearchBar old) {
    super.didUpdateWidget(old);
    _takeFocus();
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Ctrl+F again while the bar is open takes the focus back to the field,
  /// with its text selected, as a browser's find does.
  void _takeFocus() {
    if (_focuses == widget.search.focuses) return;
    _focuses = widget.search.focuses;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      _text.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _text.text.length,
      );
    });
  }

  void _step({required bool older}) => widget.search.step(
    widget.items,
    older: older,
    reasoning: widget.reasoning,
    held: widget.held,
  );

  void _close() {
    widget.search.close();
    widget.onClose?.call();
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final shift = HardwareKeyboard.instance.isShiftPressed;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        _close();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter:
        _step(older: !shift);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    final search = widget.search;
    final found = search.matches(
      widget.items,
      reasoning: widget.reasoning,
      held: widget.held,
    );
    final at = search.current == null ? -1 : found.indexOf(search.current!);
    final label = search.query.trim().isEmpty
        ? null
        : found.isEmpty
        ? l10n.liveSearchNone
        : l10n.liveSearchCount(at < 0 ? 0 : at + 1, found.length);
    return Material(
      key: const ValueKey('live-search'),
      color: theme.colorScheme.surfaceContainerHigh,
      child: Container(
        height: SessionSearchBar.heightOf(context),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 4, 0),
        child: Row(
          children: [
            Icon(Symbols.search, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Focus(
                onKeyEvent: _key,
                child: TextField(
                  key: const ValueKey('live-search-field'),
                  controller: _text,
                  focusNode: _focus,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l10n.liveSearch,
                    border: InputBorder.none,
                  ),
                  onChanged: (query) => search.search(
                    query,
                    widget.items,
                    reasoning: widget.reasoning,
                    held: widget.held,
                  ),
                  // The keyboard's search key steps like Enter, keeping the
                  // field focused.
                  onSubmitted: (_) {
                    _step(older: true);
                    _focus.requestFocus();
                  },
                  onEditingComplete: () {},
                ),
              ),
            ),
            if (label != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  label,
                  key: const ValueKey('live-search-count'),
                  style: theme.textTheme.labelMedium,
                ),
              ),
            IconButton(
              key: const ValueKey('live-search-older'),
              icon: const Icon(Symbols.keyboard_arrow_up),
              tooltip: l10n.liveSearchOlder,
              onPressed: found.isEmpty ? null : () => _step(older: true),
            ),
            IconButton(
              key: const ValueKey('live-search-newer'),
              icon: const Icon(Symbols.keyboard_arrow_down),
              tooltip: l10n.liveSearchNewer,
              onPressed: found.isEmpty ? null : () => _step(older: false),
            ),
            IconButton(
              key: const ValueKey('live-search-close'),
              icon: const Icon(Symbols.close),
              tooltip: l10n.liveSearchClose,
              onPressed: _close,
            ),
          ],
        ),
      ),
    );
  }
}
