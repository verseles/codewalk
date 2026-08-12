import '../../core/i18n/l10n_context.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../domain/entities/chat_realtime.dart';

class PermissionRequestCard extends StatelessWidget {
  const PermissionRequestCard({
    super.key,
    required this.request,
    required this.busy,
    required this.onDecide,
    this.originBadgeLabel,
  });

  final ChatPermissionRequest request;
  final bool busy;
  final ValueChanged<String> onDecide;
  final String? originBadgeLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final normalizedOriginLabel = originBadgeLabel?.trim();
    final originLabel =
        normalizedOriginLabel == null || normalizedOriginLabel.isEmpty
        ? null
        : normalizedOriginLabel;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.verified_user, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.permissionRequestTitle(request.permission),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (originLabel != null)
                Container(
                  key: ValueKey<String>(
                    'permission_request_origin_badge_${request.id}',
                  ),
                  constraints: const BoxConstraints(maxWidth: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer.withValues(
                      alpha: 0.7,
                    ),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Symbols.support_agent_rounded,
                        size: 12,
                        color: colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          originLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (request.patterns.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: request.patterns
                  .map(
                    (pattern) => Chip(
                      visualDensity: Theme.of(context).visualDensity,
                      label: Text(pattern),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: busy ? null : () => onDecide('reject'),
                child: Text(context.l10n.permissionReject),
              ),
              OutlinedButton(
                onPressed: busy ? null : () => onDecide('always'),
                child: Text(context.l10n.permissionAlways),
              ),
              FilledButton(
                onPressed: busy ? null : () => onDecide('once'),
                child: Text(context.l10n.permissionAllowOnce),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
