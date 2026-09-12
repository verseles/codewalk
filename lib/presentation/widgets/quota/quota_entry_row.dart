import 'package:flutter/material.dart';

import '../../../core/i18n/l10n_context.dart';
import '../../../domain/entities/quota.dart';
import '../../theme/app_semantic_colors.dart';
import '../../utils/quota_pace_utils.dart';
import 'pace_label.dart';

class QuotaEntryRow extends StatelessWidget {
  const QuotaEntryRow({super.key, required this.entry, this.dense = false});

  final QuotaEntry entry;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveUsedPercent = entry.effectiveUsedPercent;
    final tone = resolveUsageTone(effectiveUsedPercent);
    final colorScheme = theme.colorScheme;
    final barColor = switch (tone) {
      'critical' => colorScheme.error,
      'warn' => colorScheme.tertiary,
      _ => AppSemanticColors.success(context),
    };
    final displayedValue = entry.valueLabel ?? formatPercent(entry.usedPercent);
    final progress = ((effectiveUsedPercent ?? 0) / 100).clamp(0.0, 1.0);

    return Padding(
      padding: EdgeInsets.only(top: dense ? 6 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium,
                ),
              ),
              const SizedBox(width: 8),
              if (entry.paceInfo != null) ...[
                PaceLabel(paceInfo: entry.paceInfo!),
                const SizedBox(width: 8),
              ],
              Text(
                displayedValue,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 3,
              value: effectiveUsedPercent == null ? null : progress,
              backgroundColor: colorScheme.outlineVariant,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          if (entry.resetAfterSeconds != null) ...[
            const SizedBox(height: 4),
            Text(
              context.l10n.quotaResetsIn(
                formatRemainingTime(entry.resetAfterSeconds!.toDouble()),
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
