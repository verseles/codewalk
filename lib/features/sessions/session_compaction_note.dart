import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/rendering/canonical_message_body.dart';
import '../../shared/theme/chat_appearance.dart';
import '../../shared/widgets/app_indeterminate_progress.dart';
import 'session_context_usage.dart';
import 'session_timeline_projection.dart';

/// Centered timeline divider for a [NoticeKind.compaction] notice (#520).
///
/// Renders running, completed, interrupted, and failed context compactions
/// with a stable centered hairline row (no generic "Details" card), and
/// expands the Markdown summary or redacted error message on tap.
class SessionCompactionNote extends StatefulWidget {
  const SessionCompactionNote({
    super.key,
    required this.item,
    this.highlighted = false,
    this.onTapLink,
    this.onTapFilePath,
    this.onCopyCode,
    this.onCopyInlineCode,
  });

  final Notice item;
  final bool highlighted;
  final void Function(String text, String href, String? title)? onTapLink;
  final void Function(String path, int? line, int? col)? onTapFilePath;
  final ValueChanged<String>? onCopyCode;
  final ValueChanged<String>? onCopyInlineCode;

  @override
  State<SessionCompactionNote> createState() => _SessionCompactionNoteState();
}

class _SessionCompactionNoteState extends State<SessionCompactionNote> {
  bool _open = false;
  bool _restored = false;

  String get _storageKey => 'compaction-${widget.item.id.value}';

  void _saveOpen(bool value) {
    PageStorage.maybeOf(
      context,
    )?.writeState(context, value, identifier: _storageKey);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_restored) {
      _restored = true;
      final saved = PageStorage.maybeOf(
        context,
      )?.readState(context, identifier: _storageKey);
      _open = (saved is bool ? saved : false) || widget.highlighted;
      if (_open && saved != true) _saveOpen(true);
    }
  }

  @override
  void didUpdateWidget(covariant SessionCompactionNote oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.id != oldWidget.item.id) {
      final saved = PageStorage.maybeOf(
        context,
      )?.readState(context, identifier: _storageKey);
      _open = (saved is bool ? saved : false) || widget.highlighted;
      if (_open && saved != true) _saveOpen(true);
    } else if (widget.highlighted && !oldWidget.highlighted && !_open) {
      _open = true;
      _saveOpen(true);
    }
  }

  void _toggle() {
    SessionTimelineScope.maybeOf(context)?.onReaderToggle();
    setState(() {
      _open = !_open;
      _saveOpen(_open);
    });
  }

  static String _formatDecimal(double value, Locale locale) {
    try {
      return NumberFormat.decimalPatternDigits(
        locale: locale.toLanguageTag(),
        decimalDigits: 1,
      ).format(value);
    } on ArgumentError {
      return value.toStringAsFixed(1);
    }
  }

  static String _formatCount(num value, Locale locale) {
    if (value >= 1000000) {
      return '${_formatDecimal(value / 1000000, locale)}M';
    }
    if (value >= 1000) {
      return '${_formatDecimal(value / 1000, locale)}k';
    }
    return formatUsageCount(value, locale);
  }

  static String? _usageSummary(BuildContext context, TokenBreakdown? usage) {
    if (usage == null || usage.input == null || usage.output == null) {
      return null;
    }
    final input =
        usage.input! + (usage.cacheRead ?? 0) + (usage.cacheWrite ?? 0);
    final output = usage.output! + (usage.reasoning ?? 0);
    if (!input.isFinite || !output.isFinite || input + output <= 0) {
      return null;
    }
    final locale = Localizations.localeOf(context);
    return context.v2L10n.liveCompactionUsage(
      _formatCount(input, locale),
      _formatCount(output, locale),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = widget.item.status.known;
    final isRunning =
        status == ItemStatus.streaming || status == ItemStatus.pending;
    final isFailed = status == ItemStatus.failed;
    final isInterrupted = status == ItemStatus.interrupted;
    final rawText = widget.item.text;
    final body = rawText.trim();
    final usageText = _usageSummary(context, widget.item.compaction?.usage);
    final triggerLabel = switch (widget.item.compaction?.trigger?.known) {
      CompactionTrigger.automatic => l10n.liveCompactionTriggerAuto,
      CompactionTrigger.requested => l10n.liveCompactionTriggerManual,
      null => null,
    };
    final hasDetails = !isRunning && (body.isNotEmpty || usageText != null);
    final expanded = hasDetails && _open;

    final muted = scheme.onSurfaceVariant;
    final accent = isFailed ? scheme.error : muted;
    final hairline = isFailed
        ? scheme.error.withValues(alpha: 0.35)
        : scheme.outlineVariant;
    final label = isRunning
        ? l10n.liveCompactionRunning
        : isFailed
        ? l10n.liveCompactionFailed
        : isInterrupted
        ? l10n.liveCompactionInterrupted
        : l10n.liveCompactionCompleted;

    final leading = isRunning
        ? AppIndeterminateRing(size: 13, strokeWidth: 1.6, color: muted)
        : Icon(
            isFailed ? Symbols.error_outline : Symbols.compress,
            size: 16,
            color: accent,
          );

    final pill = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(color: accent),
            ),
          ),
          if (hasDetails) ...[
            const SizedBox(width: 2),
            Icon(
              expanded ? Symbols.expand_less : Symbols.expand_more,
              size: 16,
              color: accent,
            ),
          ],
        ],
      ),
    );

    final Widget centerControl = hasDetails
        ? Semantics(
            button: true,
            expanded: expanded,
            child: InkWell(
              key: ValueKey(
                'timeline-compaction-toggle-${widget.item.id.value}',
              ),
              borderRadius: BorderRadius.circular(12),
              onTap: _toggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Center(widthFactor: 1, child: pill),
              ),
            ),
          )
        : Semantics(
            liveRegion: isRunning,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Center(widthFactor: 1, child: pill),
            ),
          );

    final metaParts = [?triggerLabel, ?usageText];

    return ConversationTextScale(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final pillCap = constraints.hasBoundedWidth
                    ? max(0.0, constraints.maxWidth - 48)
                    : double.infinity;
                return Row(
                  children: [
                    Expanded(
                      child: Divider(height: 1, thickness: 1, color: hairline),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: pillCap),
                      child: centerControl,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Divider(height: 1, thickness: 1, color: hairline),
                    ),
                  ],
                );
              },
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: DecoratedBox(
                    key: ValueKey(
                      'timeline-compaction-body-${widget.item.id.value}',
                    ),
                    decoration: BoxDecoration(
                      color: isFailed
                          ? scheme.errorContainer.withValues(alpha: 0.35)
                          : scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (metaParts.isNotEmpty) ...[
                            Text(
                              metaParts.join(' · '),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isFailed
                                    ? scheme.onErrorContainer
                                    : muted,
                              ),
                            ),
                            if (body.isNotEmpty) const SizedBox(height: 8),
                          ],
                          if (body.isNotEmpty)
                            SelectionArea(
                              child: isFailed
                                  ? Text(
                                      body,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: scheme.onErrorContainer,
                                          ),
                                    )
                                  : CanonicalMessageBody(
                                      source: rawText,
                                      complete: true,
                                      allowBasicHtml: false,
                                      bodyStyle: theme.textTheme.bodySmall
                                          ?.copyWith(color: muted),
                                      onTapLink: widget.onTapLink,
                                      onTapFilePath: widget.onTapFilePath,
                                      onCopyCode: widget.onCopyCode,
                                      onCopyInlineCode: widget.onCopyInlineCode,
                                    ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
