import 'package:flutter/material.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/session_actions.dart';
import 'sessions_controller.dart';

/// The dialog that chooses the project a new session is created in.
///
/// The projects are the canonical directories the endpoint already reported,
/// in the order the server first showed them. A profile without a session has
/// no project to offer, so a free-form absolute path is always available: the
/// endpoint accepts it and the created session carries its own location, so the
/// next read groups it.
class SessionCreateDialog extends StatefulWidget {
  const SessionCreateDialog({required this.controller, super.key});

  final SessionsController controller;

  @override
  State<SessionCreateDialog> createState() => _SessionCreateDialogState();
}

class _SessionCreateDialogState extends State<SessionCreateDialog> {
  final _directory = TextEditingController();
  String? _selected;
  bool _failed = false;

  @override
  void dispose() {
    _directory.dispose();
    super.dispose();
  }

  /// The last segment of a canonical directory, which is how the list's group
  /// header names it.
  String _name(String directory) {
    final segments = directory
        .split(RegExp(r'[/\\]'))
        .where((segment) => segment.isNotEmpty)
        .toList();
    return segments.isEmpty ? directory : segments.last;
  }

  Future<void> _create() async {
    final typed = _directory.text.trim();
    final directory = _selected ?? (typed.isEmpty ? null : typed);
    if (directory == null) return;
    setState(() => _failed = false);
    final outcome = await widget.controller.create(directory: directory);
    if (!mounted) return;
    if (outcome == SessionActionOutcome.accepted ||
        outcome == SessionActionOutcome.uncertain) {
      Navigator.of(context).pop();
      return;
    }
    // The create did not go through: the dialog says so, because the list's
    // notice sits behind it.
    setState(() => _failed = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final directories = widget.controller.knownDirectories;
    final selected = directories.contains(_selected) ? _selected : null;
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.sessionsCreateTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (directories.isNotEmpty) ...[
            Text(
              l10n.sessionsCreateProject,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final directory in directories)
              ListTile(
                key: ValueKey('sessions-create-project-$directory'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  selected == directory
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(
                  _name(directory),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // The path is always read left-to-right, so the separators do
                // not reorder in a right-to-left locale.
                subtitle: Text(
                  directory,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                ),
                onTap: () => setState(() => _selected = directory),
              ),
          ],
          const SizedBox(height: 8),
          Text(
            l10n.sessionsCreateOtherDirectory,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (_failed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.sessionsActionFailed,
                key: const ValueKey('sessions-create-failed'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          TextField(
            key: const ValueKey('sessions-create-directory'),
            controller: _directory,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: l10n.sessionsCreateDirectoryHint,
            ),
            onChanged: (_) {
              if (_selected != null) setState(() => _selected = null);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('sessions-create-confirm'),
          onPressed: _create,
          child: Text(l10n.sessionsCreateConfirm),
        ),
      ],
    );
  }
}
