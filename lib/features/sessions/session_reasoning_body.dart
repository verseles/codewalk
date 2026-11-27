import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../shared/l10n/l10n_context.dart';
import 'session_composer_status.dart';
import 'session_message_info.dart';
import 'session_timeline_projection.dart';

/// Compact single-line reasoning row (`Thinking…` / `Thinking: <heading>` while
/// streaming; `Thought · <duration>` / `Thought` when complete) that expands
/// its full Markdown body in place on tap without a secondary hidden cutoff.
class SessionReasoningBody extends StatefulWidget {
  const SessionReasoningBody({
    super.key,
    required this.text,
    required this.complete,
    required this.child,
    this.duration,
    this.messageHeader,
    this.autoExpand = false,
    this.storageKey,
  });

  /// The reasoning text; a change to it while it streams is followed when open.
  final String text;

  /// Whether the reasoning stopped streaming.
  final bool complete;

  /// Part-scoped reasoning duration when reported by the harness.
  final Duration? duration;

  /// Message context when this row opens its message.
  final MessageContext? messageHeader;

  /// Automatically expands the body (for example, when highlighted by search).
  final bool autoExpand;

  /// Stable per-item identifier used to persist expanded state in [PageStorage].
  final Object? storageKey;

  /// The rendered reasoning Markdown.
  final Widget child;

  @override
  State<SessionReasoningBody> createState() => _SessionReasoningBodyState();
}

class _SessionReasoningBodyState extends State<SessionReasoningBody> {
  final _scroll = ScrollController();
  bool _open = false;
  bool _restored = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_restored) {
      _restored = true;
      final saved = widget.storageKey == null
          ? null
          : PageStorage.maybeOf(
              context,
            )?.readState(context, identifier: widget.storageKey);
      _open = (saved is bool ? saved : false) || widget.autoExpand;
      if (_open && saved != true) _saveOpen(true);
    }
  }

  @override
  void didUpdateWidget(covariant SessionReasoningBody old) {
    super.didUpdateWidget(old);
    if (widget.autoExpand && !old.autoExpand && !_open) {
      _open = true;
      _saveOpen(true);
    }
    if (_open && old.text != widget.text && !widget.complete) {
      _followBottom();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _saveOpen(bool value) {
    if (widget.storageKey != null) {
      PageStorage.maybeOf(
        context,
      )?.writeState(context, value, identifier: widget.storageKey);
    }
  }

  void _followBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      if (end > 0) _scroll.jumpTo(end);
    });
  }

  void _toggle() {
    SessionTimelineScope.maybeOf(context)?.onReaderToggle();
    final next = !_open;
    setState(() => _open = next);
    _saveOpen(next);
    if (next && !widget.complete) _followBottom();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final heading = widget.complete ? null : reasoningHeading(widget.text);
    final elapsed = widget.complete
        ? formatCompactDuration(widget.duration)
        : null;
    final label = !widget.complete
        ? (heading != null
              ? l10n.chatThinkingHeading(heading)
              : l10n.chatStatusThinking)
        : (elapsed != null
              ? l10n.chatThoughtDuration(elapsed)
              : l10n.chatThought);
    final hasBody = widget.text.trim().isNotEmpty;

    final headerBody = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 8, 6),
        child: Row(
          children: [
            Icon(
              Symbols.psychology,
              size: 16,
              color: !widget.complete
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (hasBody) ...[
              const SizedBox(width: 4),
              Icon(
                _open ? Symbols.expand_less : Symbols.expand_more,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );

    final labeled = Semantics(
      button: hasBody,
      toggled: hasBody ? _open : null,
      label: label,
      excludeSemantics: true,
      child: headerBody,
    );

    final headerTap = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: hasBody
          ? InkWell(
              key: const ValueKey('reasoning-toggle'),
              borderRadius: BorderRadius.circular(10),
              onTap: _toggle,
              child: labeled,
            )
          : labeled,
    );

    final header = widget.messageHeader == null
        ? headerTap
        : Row(
            children: [
              Expanded(child: headerTap),
              MessageElapsedChip(message: widget.messageHeader!),
            ],
          );

    if (!_open || !hasBody) return header;

    final maxHeight = max(120.0, MediaQuery.sizeOf(context).height * 0.4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scroll,
                  primary: false,
                  padding: const EdgeInsets.all(12),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
