import 'package:flutter/material.dart';

import '../../shared/l10n/l10n_context.dart';

/// The explicit per-session confirmation Unrestricted requires (ADR-059 §§2,
/// 7). Cancel is the default; dismissing the dialog also cancels.
Future<bool> confirmSessionUnrestricted(BuildContext context) async {
  final l10n = context.v2L10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        key: const ValueKey('live-unrestricted-dialog'),
        icon: Icon(Icons.lock_open, color: scheme.error),
        title: Text(l10n.liveUnrestrictedTitle),
        scrollable: true,
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.liveUnrestrictedOverride),
              const SizedBox(height: 12),
              Text(l10n.liveUnrestrictedChildren),
              const SizedBox(height: 12),
              Text(l10n.liveUnrestrictedOthers),
            ],
          ),
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const ValueKey('live-unrestricted-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.liveUnrestrictedConfirm),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
