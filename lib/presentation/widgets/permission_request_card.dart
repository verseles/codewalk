import 'package:flutter/material.dart';

import '../../domain/entities/chat_realtime.dart';

class PermissionRequestCard extends StatelessWidget {
  const PermissionRequestCard({
    super.key,
    required this.request,
    required this.busy,
    required this.onDecide,
  });

  final ChatPermissionRequest request;
  final bool busy;
  final ValueChanged<String> onDecide;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
              Icon(Icons.verified_user_outlined, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Permission request: ${request.permission}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
                      visualDensity: VisualDensity.compact,
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
                child: const Text('Reject'),
              ),
              OutlinedButton(
                onPressed: busy ? null : () => onDecide('always'),
                child: const Text('Always'),
              ),
              FilledButton(
                onPressed: busy ? null : () => onDecide('once'),
                child: const Text('Allow Once'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
