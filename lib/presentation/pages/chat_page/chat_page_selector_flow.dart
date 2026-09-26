part of '../chat_page.dart';

extension _ChatPageSelectorFlow on _ChatPageState {
  Widget _buildProjectSelectorTitle({
    required bool isMobile,
    required bool isLargeDesktop,
  }) {
    return Consumer<ProjectProvider>(
      builder: (context, projectProvider, child) {
        final directory = _directoryLabel(projectProvider.currentDirectory);
        return Align(
          alignment: Alignment.centerLeft,
          child: Tooltip(
            message: context.l10n.chatChooseDirectory,
            child: InkWell(
              onTap: () => unawaited(_openProjectSelectorDialog()),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                key: const ValueKey<String>('project_selector_button'),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 2 : 4,
                  vertical: 2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isMobile
                              ? 100
                              : (isLargeDesktop ? 400 : 300),
                        ),
                        child: Text(
                          isMobile ? _directoryBasename(directory) : directory,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 1),
                    const Icon(Symbols.arrow_drop_down, size: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openProjectSelectorDialog() => _createWorkspace();
}

/// One route owns search, known projects, and optional directory browsing.
class _ProjectOpenDialog extends StatefulWidget {
  const _ProjectOpenDialog({
    required this.initialDirectory,
    required this.onSearch,
    required this.onCloseProject,
    required this.onArchiveProject,
  });

  final String initialDirectory;
  final Future<List<FileNode>> Function(String query) onSearch;
  final Future<void> Function(String id) onCloseProject;
  final Future<void> Function(String id) onArchiveProject;

  @override
  State<_ProjectOpenDialog> createState() => _ProjectOpenDialogState();
}

class _ProjectOpenDialogState extends State<_ProjectOpenDialog> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  Timer? _debounce;
  int _generation = 0;
  int _active = 0;
  bool _loading = false;
  bool _browsing = false;
  bool _busy = false;
  String? _error;
  List<FileNode> _remote = const [];
  late final AppProvider _app = context.read<AppProvider>();
  late final String? _serverId;

  @override
  void initState() {
    super.initState();
    _serverId = _app.activeServerId;
    _app.addListener(_checkServer);
  }

  void _checkServer() {
    if (_app.activeServerId == _serverId) return;
    _generation++;
    _debounce?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _app.removeListener(_checkServer);
    _debounce?.cancel();
    _query.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    final generation = ++_generation;
    setState(() {
      _active = 0;
      _remote = const [];
      _error = null;
      _loading = value.trim().isNotEmpty;
    });
    if (!_loading) return;
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final results = await widget.onSearch(value.trim());
        if (!mounted ||
            generation != _generation ||
            _app.activeServerId != _serverId)
          return;
        setState(() {
          _remote = results;
          _loading = false;
        });
      } catch (_) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _loading = false;
          _error = context.l10n.chatFailedToLoadDirectories;
        });
      }
    });
  }

  void _complete(String path) {
    final value = path.endsWith('/') ? path : '$path/';
    _query.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _search(value);
    _focus.requestFocus();
  }

  void _select(String path) {
    if (_busy || _app.activeServerId != _serverId) return;
    Navigator.of(context).pop(path);
  }

  Future<void> _manage(Future<void> Function() action) async {
    if (_busy || _app.activeServerId != _serverId) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = WindowSizeClass.fromWidth(
          constraints.maxWidth,
        ).isCompact;
        return DirectConsumer<ProjectProvider>(
          builder: (context, projects, _) {
            final query = _query.text.trim();
            final byPath =
                <String, ({FileNode node, Project? project, bool open})>{};
            for (final project in [
              ...projects.openProjects,
              ...projects.closedProjects,
            ]) {
              final path = normalizeFilePath(project.path);
              byPath.putIfAbsent(
                path,
                () => (
                  node: FileNode(
                    path: path,
                    name: project.name,
                    type: FileNodeType.directory,
                  ),
                  project: project,
                  open: projects.openProjectIds.contains(project.id),
                ),
              );
            }
            for (final node in _remote) {
              byPath.putIfAbsent(
                normalizeFilePath(node.path),
                () => (node: node, project: null, open: false),
              );
            }
            int? score(FileNode node) {
              final name = projectDirectoryMatchScore(node.name, query);
              final path = projectDirectoryMatchScore(
                normalizeFilePath(node.path),
                query.replaceAll('\\', '/'),
              );
              return name == null
                  ? path
                  : path == null
                  ? name
                  : min(name, path);
            }

            final rows =
                byPath.values.where((row) => score(row.node) != null).toList()
                  ..sort((a, b) {
                    if (query.isEmpty && a.open != b.open)
                      return a.open ? -1 : 1;
                    final rank = score(a.node)!.compareTo(score(b.node)!);
                    return rank != 0
                        ? rank
                        : a.node.path.compareTo(b.node.path);
                  });
            final selected = rows.isEmpty
                ? null
                : rows[min(_active, rows.length - 1)];
            final rawPath = query.isEmpty ? widget.initialDirectory : query;
            final canOpenPath =
                query.isEmpty ||
                query.startsWith('/') ||
                RegExp(r'^[A-Za-z]:[/\\]').hasMatch(query);
            void submit() {
              final composing = _query.value.composing;
              if (composing.isValid && !composing.isCollapsed) return;
              if (selected != null) {
                _select(selected.node.path);
              } else if (canOpenPath) {
                _select(rawPath);
              }
            }
            final content = Material(
              key: const ValueKey<String>('project_selector_dialog_content'),
              child: _browsing
                  ? Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).backButtonTooltip,
                            icon: const Icon(Symbols.arrow_back),
                            onPressed: () => setState(() => _browsing = false),
                          ),
                        ),
                        Expanded(
                          child: _DirectoryPickerSheet(
                            initialDirectory: canOpenPath
                                ? rawPath
                                : widget.initialDirectory,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  context.l10n.chatProjectContext2,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              IconButton(
                                tooltip: context.l10n.chatClose,
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Symbols.close),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              context.l10n.workspaceCurrentDirectory(
                                widget.initialDirectory == '/'
                                    ? context.l10n.composerCannedScopeGlobal
                                    : widget.initialDirectory,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Focus(
                            onKeyEvent: (_, event) {
                              if (event is! KeyDownEvent &&
                                  event is! KeyRepeatEvent)
                                return KeyEventResult.ignored;
                              if (_query.value.composing.isValid &&
                                  !_query.value.composing.isCollapsed)
                                return KeyEventResult.ignored;
                              final key = event.logicalKey;
                              final keys = HardwareKeyboard.instance;
                              final ctrlNavigation =
                                  keys.isControlPressed &&
                                  !keys.isAltPressed &&
                                  !keys.isMetaPressed &&
                                  !keys.isShiftPressed;
                              final down =
                                  key == LogicalKeyboardKey.arrowDown ||
                                  (ctrlNavigation &&
                                      key == LogicalKeyboardKey.keyN);
                              final up =
                                  key == LogicalKeyboardKey.arrowUp ||
                                  (ctrlNavigation &&
                                      key == LogicalKeyboardKey.keyP);
                              if ((down || up) &&
                                  !keys.isAltPressed &&
                                  !keys.isMetaPressed &&
                                  rows.isNotEmpty) {
                                setState(
                                  () => _active =
                                      (_active + (down ? 1 : -1)) % rows.length,
                                );
                                if (_scroll.hasClients)
                                  _scroll.jumpTo(
                                    (_active * 72.0).clamp(
                                      0.0,
                                      _scroll.position.maxScrollExtent,
                                    ),
                                  );
                                return KeyEventResult.handled;
                              }
                              if (key == LogicalKeyboardKey.tab &&
                                  !keys.isShiftPressed &&
                                  selected != null) {
                                _complete(selected.node.path);
                                return KeyEventResult.handled;
                              }
                          if (key == LogicalKeyboardKey.enter) {
                            submit();
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            },
                            child: TextField(
                              key: const ValueKey<String>(
                                'workspace_base_directory_input',
                              ),
                              controller: _query,
                              focusNode: _focus,
                          autofocus: true,
                          textInputAction: TextInputAction.go,
                          onSubmitted: (_) => submit(),
                          onChanged: _search,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Symbols.search),
                                hintText: context.l10n.chatFilterDirectories,
                              ),
                            ),
                          ),
                        ),
                        if (_loading) const AppIndeterminateBar(),
                        if (_error != null) Text(_error!),
                        Expanded(
                          child: ListView.builder(
                            key: const ValueKey<String>(
                              'workspace_directory_suggestions',
                            ),
                            controller: _scroll,
                            itemCount: rows.length,
                            itemExtent: 72,
                            itemBuilder: (context, index) {
                              final row = rows[index];
                              final project = row.project;
                              return ListTile(
                                key: ValueKey<String>(
                                  'workspace_directory_suggestion_${row.node.path}',
                                ),
                                selected:
                                    index == min(_active, rows.length - 1),
                                leading: project == null
                                    ? const Icon(Symbols.folder)
                                    : ProjectIcon(project: project, size: 20),
                                title: Text(
                                  row.node.name.isEmpty
                                      ? fileBasename(row.node.path)
                                      : row.node.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  row.node.path,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: _busy
                                    ? null
                                    : () => _select(row.node.path),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: context.l10n.workspaceBrowseDirs,
                                      icon: const Icon(Symbols.chevron_right),
                                      onPressed: () => _complete(row.node.path),
                                    ),
                                    if (project != null)
                                      IconButton(
                                        tooltip: row.open
                                            ? context.l10n
                                                  .workspaceCloseProject(
                                                    project.name,
                                                  )
                                            : context.l10n
                                                  .chatRemoveDisplayNameHistory(
                                                    project.name,
                                                  ),
                                        icon: Icon(
                                          row.open
                                              ? Symbols.close
                                              : Symbols.delete_outline_rounded,
                                        ),
                                        onPressed:
                                            _busy ||
                                                (row.open &&
                                                    !projects.canCloseProject(
                                                      project.id,
                                                    ))
                                            ? null
                                            : () => _manage(
                                                () => row.open
                                                    ? widget.onCloseProject(
                                                        project.id,
                                                      )
                                                    : widget.onArchiveProject(
                                                        project.id,
                                                      ),
                                              ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              TextButton.icon(
                                key: const ValueKey<String>(
                                  'workspace_open_directory_picker_button',
                                ),
                                onPressed: () =>
                                    setState(() => _browsing = true),
                                icon: const Icon(Symbols.folder_open),
                                label: Text(context.l10n.workspaceBrowseDirs),
                              ),
                              if (canOpenPath)
                                FilledButton(
                                  key: const ValueKey<String>(
                                    'workspace_open_path_button',
                                  ),
                                  onPressed: _busy
                                      ? null
                                      : () => _select(rawPath),
                                  child: Text(
                                    '${context.l10n.workspaceOpenFolder}: $rawPath',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
            );
            if (compact)
              return Dialog.fullscreen(
                key: const ValueKey<String>(
                  'project_selector_dialog_fullscreen',
                ),
                child: SafeArea(child: content),
              );
            return Dialog(
              key: const ValueKey<String>('project_selector_dialog_centered'),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(width: 760, height: 600, child: content),
            );
          },
        );
      },
    );
  }
}
