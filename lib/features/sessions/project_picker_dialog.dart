import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/layout/window_size_class.dart';
import '../../shared/sessions/server_path.dart';
import 'project_context_list.dart';
import 'project_contexts_controller.dart';
import 'project_picker_controller.dart';
import 'sessions_controller.dart';

/// Opens the project picker of the selected server: full screen on a
/// compact window, a centered dialog otherwise. It closes itself once a
/// project opens or the server changes.
Future<void> showProjectPicker(
  BuildContext context, {
  required SessionsController catalog,
  required ProjectContextsController contexts,
}) {
  final compact = WindowSizeClass.fromWidth(
    MediaQuery.sizeOf(context).width,
  ).isCompact;
  return showDialog<void>(
    context: context,
    builder: (context) {
      final picker = ProjectPickerDialog(catalog: catalog, contexts: contexts);
      if (compact) return Dialog.fullscreen(child: picker);
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
          child: picker,
        ),
      );
    },
  );
}

/// The picker's content: one search field over the known projects and the
/// server's folders, a directory browser in the same dialog and an explicit
/// Open folder action for any absolute path.
class ProjectPickerDialog extends StatefulWidget {
  const ProjectPickerDialog({
    super.key,
    required this.catalog,
    required this.contexts,
  });

  final SessionsController catalog;
  final ProjectContextsController contexts;

  @override
  State<ProjectPickerDialog> createState() => _ProjectPickerDialogState();
}

class _ProjectPickerDialogState extends State<ProjectPickerDialog> {
  late final ProjectPickerController _picker;
  final _field = TextEditingController();
  final _focus = FocusNode(debugLabel: 'project-picker');
  final _highlighted = GlobalKey(debugLabel: 'project-picker-highlight');
  final _scroll = ScrollController();
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _picker = ProjectPickerController(
      catalog: widget.catalog,
      contexts: widget.contexts,
    )..addListener(_changed);
    _picker.start();
  }

  void _changed() {
    if (_picker.dismissed) _close();
  }

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _picker
      ..removeListener(_changed)
      ..dispose();
    _field.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _open(ProjectPickerEntry entry) async {
    if (await _picker.open(entry)) _close();
  }

  Future<void> _openPath(String path, {bool typed = false}) async {
    if (await _picker.openPath(path, typed: typed)) _close();
  }

  /// A new query highlights its first result, so the list shows its top.
  void _queryChanged(String value) {
    _picker.setQuery(value);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// Moves the highlight and keeps the highlighted result in view.
  void _move(int delta) {
    final before = _picker.highlight;
    _picker.moveHighlight(delta);
    // A wrap moves the other way than the key: follow the movement.
    final down = _picker.highlight > before;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _highlighted.currentContext;
      if (target == null || !mounted) return;
      Scrollable.ensureVisible(
        target,
        alignmentPolicy: down
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  /// Enter or the keyboard's Go opens the highlighted result, or the typed
  /// absolute path when nothing matches it. An unfinished IME composition
  /// never submits.
  void _submit() {
    if (_field.value.composing.isValid) return;
    final results = _picker.results;
    if (results.isNotEmpty) {
      unawaited(_open(results[_picker.highlight.clamp(0, results.length - 1)]));
    } else if (_picker.canOpenPath) {
      unawaited(_openPath(_picker.query, typed: true));
    }
  }

  /// Tab completes the field to the highlighted result's full path.
  void _complete() {
    final path = _picker.completion();
    if (path == null) return;
    _field.value = TextEditingValue(
      text: path,
      selection: TextSelection.collapsed(offset: path.length),
    );
    _queryChanged(path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([_picker, widget.contexts]),
      builder: (context, _) {
        final failure = switch (_picker.failure) {
          ProjectPickerFailure.none => null,
          ProjectPickerFailure.search ||
          ProjectPickerFailure.browse => l10n.chatFailedToLoadDirectories,
          ProjectPickerFailure.open => l10n.workspaceFailedToOpenProjectContext(
            _picker.query.trim(),
          ),
        };
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): _close,
            const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
            const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
            const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
                _move(1),
            const SingleActivator(LogicalKeyboardKey.keyP, control: true): () =>
                _move(-1),
            const SingleActivator(LogicalKeyboardKey.tab): _complete,
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.chatChooseDirectory,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('project-picker-close'),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: _close,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('project-picker-field'),
                  controller: _field,
                  focusNode: _focus,
                  autofocus: true,
                  textInputAction: TextInputAction.go,
                  onChanged: _queryChanged,
                  // The default completion would commit an unfinished IME
                  // composition before the submit could see it.
                  onEditingComplete: () {},
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: l10n.workspaceProjectHint,
                    labelText: l10n.workspaceFilterDirs,
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_picker.browsing)
                      TextButton.icon(
                        key: const ValueKey('project-picker-search'),
                        onPressed: _picker.stopBrowsing,
                        icon: const Icon(Icons.arrow_back),
                        label: Text(l10n.workspaceFilterDirs),
                      )
                    else
                      TextButton.icon(
                        key: const ValueKey('project-picker-browse'),
                        onPressed: _picker.startBrowsing,
                        icon: const Icon(Icons.folder_open),
                        label: Text(l10n.workspaceBrowseDirs),
                      ),
                    FilledButton.tonal(
                      key: const ValueKey('project-picker-open-folder'),
                      onPressed: !_picker.opening && _picker.canOpenPath
                          ? () => _openPath(_picker.query, typed: true)
                          : null,
                      child: Text(l10n.workspaceOpenFolder),
                    ),
                  ],
                ),
                if (_picker.searching ||
                    _picker.opening ||
                    _picker.browseLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
                if (failure != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      failure,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: _picker.browsing ? _browser(context) : _list(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _list(BuildContext context) {
    final l10n = context.v2L10n;
    final results = _picker.results;
    if (results.isEmpty) {
      return Center(child: Text(l10n.chatChooseFolderOpen));
    }
    final active = widget.contexts.active;
    // The results are bounded, so every row is built (a lazy list would
    // not build a far row) and the highlighted one can always be revealed.
    return SingleChildScrollView(
      controller: _scroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, entry) in results.indexed)
            _result(context, entry, index == _picker.highlight, active),
        ],
      ),
    );
  }

  Widget _result(
    BuildContext context,
    ProjectPickerEntry entry,
    bool highlighted,
    String? active,
  ) {
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    return KeyedSubtree(
      key: highlighted ? _highlighted : null,
      child: AccentedRow(
        selected: highlighted,
        child: ListTile(
          key: ValueKey('project-picker-${entry.directory}'),
          dense: true,
          selected: entry.directory == active,
          leading: Icon(switch (entry.source) {
            ProjectPickerSource.open => Icons.folder_special_outlined,
            ProjectPickerSource.closed => Icons.history,
            ProjectPickerSource.server => Icons.folder_outlined,
            ProjectPickerSource.found => Icons.search,
          }),
          title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: StartEllipsisPath(
            entry.directory,
            style: theme.textTheme.bodySmall,
          ),
          trailing: entry.source == ProjectPickerSource.closed
              ? IconButton(
                  key: ValueKey('project-picker-forget-${entry.directory}'),
                  tooltip: l10n.workspaceRemoveFromHistory(entry.name),
                  onPressed: _picker.opening
                      ? null
                      : () => _picker.forget(entry.directory),
                  icon: const Icon(Icons.close),
                )
              : null,
          onTap: _picker.opening ? null : () => _open(entry),
        ),
      ),
    );
  }

  Widget _browser(BuildContext context) {
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    final directory = _picker.browseDirectory;
    final parent = directory == null ? null : serverPathParent(directory);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (directory != null) ...[
          Text(
            l10n.workspaceCurrentDirectory(directory),
            textDirection: TextDirection.ltr,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const ValueKey('project-picker-open-browsed'),
              onPressed: _picker.opening ? null : () => _openPath(directory),
              child: Text(l10n.workspaceOpenFolder),
            ),
          ),
        ],
        Expanded(
          child: ListView(
            children: [
              if (parent != null)
                ListTile(
                  key: const ValueKey('project-picker-up'),
                  dense: true,
                  leading: const Icon(Icons.arrow_upward),
                  title: const Text('..', textDirection: TextDirection.ltr),
                  onTap: _picker.browseUp,
                ),
              for (final folder in _picker.browseEntries)
                ListTile(
                  key: ValueKey('project-picker-folder-$folder'),
                  dense: true,
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(
                    serverPathName(folder),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _picker.browse(folder),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
