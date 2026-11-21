import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:material_symbols_icons/symbols.dart';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/theme/app_surface_tokens.dart';
import '../../shared/widgets/app_indeterminate_progress.dart';
import 'session_live_controller.dart';

const _unknownDash = '—';

/// Resolves the ring accent color for [usagePercent] using theme tokens only.
Color contextUsageColor(
  BuildContext context, {
  required int? usagePercent,
  required bool available,
}) {
  final scheme = Theme.of(context).colorScheme;
  if (!available || usagePercent == null) {
    return scheme.onSurface.withValues(alpha: 0.38);
  }
  if (usagePercent >= 85) return scheme.error;
  if (usagePercent >= 65) return scheme.tertiary;
  return scheme.primary;
}

/// Formats a finite count using the active locale's grouping separator.
String formatUsageCount(num value, Locale locale) {
  final rounded = value.round();
  try {
    return NumberFormat.decimalPattern(locale.toLanguageTag()).format(rounded);
  } on ArgumentError {
    return NumberFormat.decimalPattern('en').format(rounded);
  }
}

/// Formats a canonical [Cost] without inventing currency symbols.
String formatUsageCost(Cost cost, Locale locale, V2Localizations l10n) {
  final amount = cost.amount;
  if (amount == null || !amount.isFinite) return _unknownDash;
  final value = amount.toDouble();
  final digits = value < 1 && value != 0 ? 4 : 2;
  String number;
  try {
    number = NumberFormat.decimalPatternDigits(
      locale: locale.toLanguageTag(),
      decimalDigits: digits,
    ).format(value);
  } on ArgumentError {
    number = value.toStringAsFixed(digits);
  }
  final currency = cost.currency;
  if (currency == null || currency.isEmpty) {
    return '$number (${l10n.contextUsageUnknownCurrency})';
  }
  if (currency == 'USD') return '\$$number';
  return '$currency $number';
}

/// Toolbar circular context-usage knob.
///
/// Opens an anchored popover on wide layouts (`>= 600 dp`) and a modal bottom
/// sheet on compact layouts (`< 600 dp`).
class ContextUsageButton extends StatefulWidget {
  const ContextUsageButton({
    super.key,
    required this.live,
    required this.compact,
  });

  final SessionLiveController live;
  final bool compact;

  @override
  State<ContextUsageButton> createState() => _ContextUsageButtonState();
}

class _ContextUsageButtonState extends State<ContextUsageButton> {
  final MenuController _menuController = MenuController();

  @override
  void didUpdateWidget(covariant ContextUsageButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.live, widget.live) ||
        oldWidget.compact != widget.compact) {
      if (_menuController.isOpen) _menuController.close();
    }
  }

  @override
  void dispose() {
    if (_menuController.isOpen) _menuController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.live;
    return ListenableBuilder(
      listenable: Listenable.merge([live, live.turn]),
      builder: (context, _) {
        final l10n = context.v2L10n;
        final view = live.usageView;
        final compacting = live.turn.compacting;
        final percent = view.usagePercent;
        final tooltip = compacting
            ? l10n.contextUsageCompacting
            : percent != null
            ? '${l10n.contextUsageTitle}: $percent%'
            : l10n.contextUsageUnavailable;
        final ring = _ContextUsageRing(
          usagePercent: percent,
          available: view.supportsContext && percent != null,
          compacting: compacting,
          compactingLabel: l10n.contextUsageCompacting,
        );

        final useSheet =
            widget.compact || MediaQuery.sizeOf(context).width < 600;
        if (useSheet) {
          return IconButton(
            tooltip: tooltip,
            onPressed: () => unawaited(showContextUsageSheet(context, live)),
            icon: ring,
          );
        }

        final hostContext = context;
        return MenuAnchor(
          controller: _menuController,
          style: MenuStyle(
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: Theme.of(context).surfaceTokens.panelRadius,
              ),
            ),
          ),
          menuChildren: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: ContextUsagePanel(
                  key: const ValueKey('context-usage-popover'),
                  live: live,
                  actionContext: hostContext,
                  onDismiss: () {
                    if (_menuController.isOpen) _menuController.close();
                  },
                ),
              ),
            ),
          ],
          builder: (context, controller, _) => IconButton(
            tooltip: tooltip,
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            icon: ring,
          ),
        );
      },
    );
  }
}

/// Opens the context-usage details from the 3-dots overflow menu: a modal
/// bottom sheet on compact layouts, or a bounded dialog on wide layouts.
Future<void> showContextUsageFromOverflow(
  BuildContext context,
  SessionLiveController live, {
  required bool compact,
}) {
  final useSheet = compact || MediaQuery.sizeOf(context).width < 600;
  return useSheet
      ? showContextUsageSheet(context, live)
      : showContextUsageDialog(context, live);
}

/// Compact modal bottom sheet hosting [ContextUsagePanel].
Future<void> showContextUsageSheet(
  BuildContext context,
  SessionLiveController live,
) {
  final hostContext = context;
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
        ),
        child: SingleChildScrollView(
          primary: false,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: ContextUsagePanel(
            key: const ValueKey('context-usage-sheet'),
            live: live,
            actionContext: hostContext,
            onDismiss: () => Navigator.of(sheetContext).pop(),
          ),
        ),
      ),
    ),
  );
}

/// Wide overflow dialog hosting [ContextUsagePanel].
Future<void> showContextUsageDialog(
  BuildContext context,
  SessionLiveController live,
) {
  final hostContext = context;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final l10n = dialogContext.v2L10n;
      final tokens = Theme.of(dialogContext).surfaceTokens;
      return Dialog(
        key: const ValueKey('context-usage-dialog'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: tokens.dialogRadius),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.8,
          ),
          child: SingleChildScrollView(
            primary: false,
            padding: const EdgeInsets.all(16),
            child: ContextUsagePanel(
              live: live,
              actionContext: hostContext,
              onDismiss: () => Navigator.of(dialogContext).pop(),
              trailingHeader: IconButton(
                key: const ValueKey('context-usage-dialog-close'),
                icon: const Icon(Symbols.close),
                tooltip: l10n.chatClose,
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Shared session context-usage details panel (grid, token breakdown,
/// compaction explanation, full-width Compact now row, and quota footer).
class ContextUsagePanel extends StatelessWidget {
  const ContextUsagePanel({
    super.key,
    required this.live,
    required this.actionContext,
    required this.onDismiss,
    this.trailingHeader,
  });

  final SessionLiveController live;
  final BuildContext actionContext;
  final VoidCallback onDismiss;
  final Widget? trailingHeader;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([live, live.turn]),
      builder: (context, _) {
        final l10n = context.v2L10n;
        final locale = Localizations.localeOf(context);
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final textTheme = theme.textTheme;
        final view = live.usageView;
        final compacting = live.turn.compacting;
        final canCompact = !compacting && live.turn.canCompact;

        final usageText = view.usagePercent != null
            ? '${view.usagePercent}%'
            : _unknownDash;
        final tokensText = view.contextUsed != null
            ? formatUsageCount(view.contextUsed!, locale)
            : _unknownDash;
        final costText = view.cost?.amount != null
            ? formatUsageCost(view.cost!, locale, l10n)
            : _unknownDash;
        final limitText = view.contextLimit != null
            ? formatUsageCount(view.contextLimit!, locale)
            : _unknownDash;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.contextUsageTitle,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ?trailingHeader,
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    key: const ValueKey('context-usage-metric-usage'),
                    label: l10n.contextUsageUsage,
                    value: usageText,
                    subtitle: view.contextEstimated && view.usagePercent != null
                        ? l10n.contextUsageEstimated
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    key: const ValueKey('context-usage-metric-tokens'),
                    label: l10n.contextUsageTokens,
                    value: tokensText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    key: const ValueKey('context-usage-metric-cost'),
                    label: l10n.contextUsageCost,
                    value: costText,
                    subtitle:
                        view.cost?.estimated == true &&
                            view.cost?.amount != null
                        ? l10n.contextUsageEstimated
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    key: const ValueKey('context-usage-metric-limit'),
                    label: l10n.contextUsageLimit,
                    value: limitText,
                  ),
                ),
              ],
            ),
            if (view.supportsTokens && view.contextTokens != null) ...[
              const SizedBox(height: 10),
              _TokenBreakdownList(
                tokens: view.contextTokens!,
                locale: locale,
                l10n: l10n,
              ),
            ],
            const SizedBox(height: 10),
            Text(
              compacting
                  ? l10n.turnUnavailableCompacting
                  : l10n.contextUsageAutoCompactionNote,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Divider(color: scheme.outlineVariant, height: 1),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: InkWell(
                key: const ValueKey('context-usage-compact-now'),
                borderRadius: BorderRadius.circular(10),
                onTap: canCompact
                    ? () {
                        onDismiss();
                        if (!live.disposed && actionContext.mounted) {
                          unawaited(live.turn.compact(context: actionContext));
                        }
                      }
                    : null,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Symbols.compress,
                          size: 18,
                          color: canCompact
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            compacting
                                ? l10n.contextUsageCompacting
                                : l10n.contextUsageCompactNow,
                            style: textTheme.labelLarge?.copyWith(
                              color: canCompact
                                  ? scheme.onSurface
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Divider(color: scheme.outlineVariant, height: 1),
            const SizedBox(height: 8),
            _QuotaFooter(view: view, locale: locale, l10n: l10n),
          ],
        );
      },
    );
  }
}

class _ContextUsageRing extends StatelessWidget {
  const _ContextUsageRing({
    required this.usagePercent,
    required this.available,
    required this.compacting,
    required this.compactingLabel,
  });

  final int? usagePercent;
  final bool available;
  final bool compacting;
  final String compactingLabel;

  @override
  Widget build(BuildContext context) {
    final percent = usagePercent;
    final color = contextUsageColor(
      context,
      usagePercent: percent,
      available: available,
    );
    final progress = percent == null ? 0.0 : (percent / 100).clamp(0.0, 1.0);
    final label = percent == null
        ? _unknownDash
        : percent > 999
        ? '999+'
        : '$percent';
    final fontSize = percent == null
        ? 9.5
        : percent > 999
        ? 7.5
        : percent >= 100
        ? 8.5
        : 9.5;
    final textColor = available && percent != null
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38);

    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: 1,
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              color.withValues(alpha: 0.22),
            ),
          ),
          if (compacting)
            AppIndeterminateRing(
              size: 20,
              strokeWidth: 1.5,
              color: color,
              semanticsLabel: compactingLabel,
            )
          else if (percent != null)
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          if (!compacting)
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  height: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
  });

  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = theme.surfaceTokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.cardSurface,
        borderRadius: tokens.controlRadius,
        border: Border.all(color: tokens.separator),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TokenBreakdownList extends StatelessWidget {
  const _TokenBreakdownList({
    required this.tokens,
    required this.locale,
    required this.l10n,
  });

  final TokenBreakdown tokens;
  final Locale locale;
  final V2Localizations l10n;

  String _fmt(num? value) =>
      value == null ? _unknownDash : formatUsageCount(value, locale);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rows = <(String, String)>[
      (l10n.contextUsageInput, _fmt(tokens.input)),
      (l10n.contextUsageOutput, _fmt(tokens.output)),
      (l10n.contextUsageReasoning, _fmt(tokens.reasoning)),
      (l10n.contextUsageCacheRead, _fmt(tokens.cacheRead)),
      (l10n.contextUsageCacheWrite, _fmt(tokens.cacheWrite)),
    ];
    return Column(
      key: const ValueKey('context-usage-breakdown'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(value, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _QuotaFooter extends StatelessWidget {
  const _QuotaFooter({
    required this.view,
    required this.locale,
    required this.l10n,
  });

  final SessionUsageView view;
  final Locale locale;
  final V2Localizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (!view.supportsQuota) {
      return Text(
        l10n.contextUsageQuotaNotExposed,
        key: const ValueKey('context-usage-quota-footer'),
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    if (view.quotas.isEmpty) {
      return Text(
        l10n.contextUsageQuotaNone,
        key: const ValueKey('context-usage-quota-footer'),
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    return Column(
      key: const ValueKey('context-usage-quota-footer'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final window in view.quotas)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    window.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    window.usedPercent == null
                        ? _unknownDash
                        : '${window.usedPercent!.round()}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
