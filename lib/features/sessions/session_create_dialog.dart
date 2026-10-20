import 'dart:convert';

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
  bool _submitting = false;
  bool _unavailable = false;

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

  /// The path the user typed, trimmed.
  String get _typed => _directory.text.trim();

  /// The reason the typed path cannot be sent, or null when it can.
  ///
  /// The rules mirror the client: a relative path would be resolved against
  /// the endpoint's process directory, and a path over the bound would be
  /// refused there, so both are refused here with a readable reason.
  String? _pathProblem() {
    final l10n = context.v2L10n;
    final value = _typed;
    if (value.isEmpty) return null;
    if (!_absolutePath(value)) return l10n.sessionsCreateDirectoryAbsolute;
    if (!_boundedPath(value)) return l10n.sessionsCreateDirectoryTooLong;
    return null;
  }

  /// The project the user chose, while the endpoint still reports it.
  ///
  /// A live update can drop a project from the catalog. The dialog then
  /// shows no selected project, and it never dispatches a directory it does
  /// not show.
  String? get _selection {
    final selected = _selected;
    if (selected == null) return null;
    return widget.controller.knownDirectories.contains(selected)
        ? selected
        : null;
  }

  /// Whether the dialog can send a create.
  bool get _canSubmit {
    if (_submitting) return false;
    if (_listNotCurrent) return false;
    if (_selection != null) return true;
    return _typed.isNotEmpty && _pathProblem() == null;
  }

  /// Whether the list stopped being the endpoint's current answer.
  ///
  /// The durable states disable the confirm, exactly as the row menu does.
  /// A pending re-read keeps it usable and the dispatch refuses, which the
  /// dialog reports after the attempt.
  bool get _listNotCurrent =>
      widget.controller.createReason == SessionActionReason.listNotCurrent;

  Future<void> _create() async {
    if (_submitting) return;
    final typed = _typed;
    final selection = _selection;
    final directory = selection ?? (typed.isEmpty ? null : typed);
    if (directory == null) return;
    if (selection == null && _pathProblem() != null) {
      // The path is refused locally, so nothing is sent.
      setState(() {});
      return;
    }
    setState(() {
      _failed = false;
      _unavailable = false;
      _submitting = true;
    });
    final outcome = await widget.controller.create(directory: directory);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (outcome == SessionActionOutcome.accepted ||
        outcome == SessionActionOutcome.uncertain) {
      Navigator.of(context).pop();
      return;
    }
    if (outcome == SessionActionOutcome.unavailable &&
        widget.controller.reconciling) {
      // The create was never sent: a pending re-read may have outdated the
      // list, so the user retries instead of believing that a command failed.
      setState(() => _unavailable = true);
      return;
    }
    // The create did not go through: the dialog says so, because the list's
    // notice sits behind it.
    setState(() => _failed = true);
  }

  /// An absolute path: a POSIX root or a Windows drive.
  static bool _absolutePath(String value) =>
      value.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(value);

  /// The client's bound on the path it sends, mirrored so the dialog refuses
  /// it locally instead of letting the client refuse it later.
  static bool _boundedPath(String value) =>
      value.length <= _pathLimit &&
      utf8.encode(value).length <= _pathLimit &&
      utf8.decode(utf8.encode(value)) == value;

  @override
  Widget build(BuildContext context) {
    // The projects follow the controller: a project the endpoint reports
    // while the dialog is open is offered without reopening it.
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => _dialog(context),
    );
  }

  Widget _dialog(BuildContext context) {
    final l10n = context.v2L10n;
    final directories = widget.controller.knownDirectories;
    final selected = _selection;
    final problem = selected == null ? _pathProblem() : null;
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
          if (problem != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                problem,
                key: const ValueKey('sessions-create-invalid'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          if (_listNotCurrent || _unavailable)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.sessionsActionUnavailableList,
                key: const ValueKey('sessions-create-unavailable'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
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
            // The path is machine-typed, so the spell checker never rewrites
            // a segment of it.
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l10n.sessionsCreateDirectoryHint,
            ),
            onChanged: (_) => setState(() {
              if (_selected != null) _selected = null;
            }),
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
          onPressed: _canSubmit ? _create : null,
          child: Text(l10n.sessionsCreateConfirm),
        ),
      ],
    );
  }
}

/// The bound of the path the client sends, the same bound the harness client
/// applies to the create's directory.
const int _pathLimit = 4096;
