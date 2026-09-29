import 'package:flutter/material.dart';

import '../../core/i18n/l10n_context.dart';
import '../services/release_history_service.dart';

class ReleaseAnnouncementsDialog extends StatefulWidget {
  const ReleaseAnnouncementsDialog({super.key, required this.entries});

  final List<ReleaseHistoryEntry> entries;

  @override
  State<ReleaseAnnouncementsDialog> createState() =>
      _ReleaseAnnouncementsDialogState();
}

class _ReleaseAnnouncementsDialogState
    extends State<ReleaseAnnouncementsDialog> {
  bool _doNotShowAgain = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('release_announcements_dialog'),
      scrollable: true,
      title: Text(context.l10n.releaseAnnouncementsTitle),
      content: SizedBox(
        width: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in widget.entries) ...[
              Text(
                'v${entry.version}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              SelectableText(entry.announcement ?? ''),
              const SizedBox(height: 20),
            ],
            CheckboxListTile(
              key: const ValueKey('release_announcements_suppress'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(context.l10n.releaseAnnouncementsDoNotShowAgain),
              value: _doNotShowAgain,
              onChanged: (value) =>
                  setState(() => _doNotShowAgain = value ?? true),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          key: const ValueKey('release_announcements_close'),
          onPressed: () => Navigator.of(context).pop(_doNotShowAgain),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}
