part of '../chat_page.dart';

enum _QuickOpenSearchMode { names, contents }

class _QuickOpenResult {
  const _QuickOpenResult({
    required this.path,
    required this.title,
    required this.subtitle,
    this.lineNumber,
  });

  final String path;
  final String title;
  final String subtitle;
  final int? lineNumber;
}

const _fileExplorerMinimumLoaderDuration = Duration(milliseconds: 120);

extension _ChatPageFileExplorerController on _ChatPageState {
  Widget _buildDesktopFilePane({VoidCallback? onCollapseRequested}) {
    return Selector<ChatProvider, _FilePaneBuildKey>(
      selector: (_, p) => _filePaneBuildKey(p),
      builder: (context, _, _) {
        final chatProvider = context.read<ChatProvider>();
        return Consumer2<ProjectProvider, AppProvider>(
          builder: (context, projectProvider, appProvider, child) {
            final fileState = _resolveFileContextState(
              projectProvider: projectProvider,
              appProvider: appProvider,
            );
            _reconcileFileContextWithSessionDiff(
              contextKey: projectProvider.contextKey,
              fileState: fileState,
              chatProvider: chatProvider,
              projectProvider: projectProvider,
            );
            return SafeArea(
              child: _buildFileExplorerPanel(
                fileState: fileState,
                projectProvider: projectProvider,
                isMobileLayout: false,
                onCollapseRequested: onCollapseRequested,
              ),
            );
          },
        );
      },
    );
  }

  _FileExplorerContextState _resolveFileContextState({
    required ProjectProvider projectProvider,
    required AppProvider appProvider,
  }) {
    final contextKey = projectProvider.contextKey;
    final rootDirectory = _resolveFileRootDirectory(
      projectProvider: projectProvider,
      appProvider: appProvider,
    );
    final state = _fileContextStates.putIfAbsent(
      contextKey,
      () => _FileExplorerContextState(
        contextKey: contextKey,
        serverId: projectProvider.activeServerId,
        rootDirectory: rootDirectory,
      ),
    );
    if (state.rootDirectory != rootDirectory) {
      if (state.hasUnsavedDrafts) {
        return state;
      }
      state.resetForRoot(rootDirectory);
    }
    _ensureFileRootLoaded(state: state, projectProvider: projectProvider);
    unawaited(
      _ensureFileOperationCapabilities(
        state: state,
        projectProvider: projectProvider,
      ),
    );
    return state;
  }

  Future<void> _loadDirectoryNodes({
    required _FileExplorerContextState state,
    required ProjectProvider projectProvider,
    required String cacheKey,
    required String requestPath,
    bool force = false,
    bool showLoader = true,
  }) async {
    if (state.loadingDirectories.contains(cacheKey)) {
      if (!force) {
        return;
      }
      while (mounted && state.loadingDirectories.contains(cacheKey)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (!mounted) {
        return;
      }
    }
    if (!force && state.directoryChildren.containsKey(cacheKey)) {
      return;
    }

    final loadStartedAt = DateTime.now();
    if (mounted) {
      _setState(() {
        state.loadingDirectories.add(cacheKey);
        state.directoryErrors.remove(cacheKey);
        if (cacheKey == _ChatPageState._rootTreeCacheKey) {
          state.treeError = null;
        }
      });
    }

    final listed = await _listFilesWithFallback(
      projectProvider: projectProvider,
      requestPath: requestPath,
    );
    final elapsed = DateTime.now().difference(loadStartedAt);
    if (elapsed < _fileExplorerMinimumLoaderDuration) {
      await Future<void>.delayed(_fileExplorerMinimumLoaderDuration - elapsed);
    }
    if (!mounted) {
      return;
    }

    _setState(() {
      state.loadingDirectories.remove(cacheKey);
      if (listed == null) {
        final message = projectProvider.error ?? context.l10n.filesFailedToLoad;
        if (cacheKey == _ChatPageState._rootTreeCacheKey) {
          state.treeError = message;
        } else {
          state.directoryErrors[cacheKey] = message;
        }
        return;
      }
      state.directoryErrors.remove(cacheKey);
      state.directoryChildren[cacheKey] = listed;
      if (cacheKey == _ChatPageState._rootTreeCacheKey) {
        state.treeError = null;
      }
      if (showLoader) {
        state.lastLoadedAt = DateTime.now();
      }
    });
  }

  Future<void> _openQuickFileDialogFromCurrentContext() async {
    if (!mounted) {
      return;
    }
    final projectProvider = context.read<ProjectProvider>();
    final appProvider = context.read<AppProvider>();
    final fileState = _resolveFileContextState(
      projectProvider: projectProvider,
      appProvider: appProvider,
    );
    await _openQuickFileDialog(
      fileState: fileState,
      projectProvider: projectProvider,
      openInDialogAfterSelect: true,
      dialogFullscreen: context.windowSizeClass.isCompact,
    );
  }

  Future<void> _openQuickFileDialog({
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    VoidCallback? onFileOpened,
    required bool openInDialogAfterSelect,
    required bool dialogFullscreen,
  }) async {
    final queryController = TextEditingController();
    var loading = false;
    var errorMessage = '';
    var resultNodes = <_QuickOpenResult>[];
    var searchMode = _QuickOpenSearchMode.names;
    var searchRequestId = 0;
    var dialogActive = true;
    var openingSelection = false;

    Future<void> openQuickOpenResult(
      BuildContext dialogContext,
      String path,
    ) async {
      final normalizedPath = _normalizeFilePath(path);
      if (normalizedPath.isEmpty) {
        return;
      }

      dialogActive = false;
      Navigator.of(dialogContext).pop();
      if (openInDialogAfterSelect) {
        await _openFileAndFocusDialog(
          fileState: fileState,
          projectProvider: projectProvider,
          path: normalizedPath,
          dialogFullscreen: dialogFullscreen,
          onUpdated: onFileOpened,
        );
      } else {
        await _openFileInTab(
          fileState: fileState,
          projectProvider: projectProvider,
          path: normalizedPath,
          onUpdated: onFileOpened,
        );
        onFileOpened?.call();
      }
    }

    Future<void> openFirstQuickOpenResult(BuildContext dialogContext) async {
      if (openingSelection || resultNodes.isEmpty) {
        return;
      }
      openingSelection = true;
      try {
        await openQuickOpenResult(dialogContext, resultNodes.first.path);
      } finally {
        openingSelection = false;
      }
    }

    resultNodes = fileState.tabSelection.openPaths
        .map(
          (path) => _QuickOpenResult(
            path: path,
            title: _fileBasename(path),
            subtitle: _normalizeFilePath(path),
          ),
        )
        .toList(growable: false);

    Future<void> runSearch(StateSetter setModalState, String query) async {
      final normalized = query.trim();
      final requestId = ++searchRequestId;

      if (normalized.isEmpty) {
        final recent = fileState.tabSelection.openPaths
            .map(
              (path) => _QuickOpenResult(
                path: path,
                title: _fileBasename(path),
                subtitle: _normalizeFilePath(path),
              ),
            )
            .toList(growable: false);
        if (!dialogActive) {
          return;
        }
        setModalState(() {
          loading = false;
          errorMessage = '';
          resultNodes = recent;
        });
        return;
      }

      if (!dialogActive) {
        return;
      }
      setModalState(() {
        loading = true;
        errorMessage = '';
      });

      final found = searchMode == _QuickOpenSearchMode.names
          ? await projectProvider.findFiles(query: normalized, limit: 120)
          : null;
      final contentMatches = searchMode == _QuickOpenSearchMode.contents
          ? await projectProvider.searchFileContents(
              pattern: normalized,
              limit: 50,
            )
          : null;
      if (!mounted || requestId != searchRequestId || !dialogActive) {
        return;
      }
      if (found == null && contentMatches == null) {
        setModalState(() {
          loading = false;
          resultNodes = <_QuickOpenResult>[];
          errorMessage =
              projectProvider.error ?? context.l10n.filesFailedToSearch;
        });
        return;
      }

      if (contentMatches != null) {
        setModalState(() {
          loading = false;
          errorMessage = '';
          resultNodes = contentMatches
              .map(
                (match) => _QuickOpenResult(
                  path: match.path,
                  title: _fileBasename(match.path),
                  subtitle:
                      '${_normalizeFilePath(match.path)}:${match.lineNumber}  ${match.lineContent}',
                  lineNumber: match.lineNumber,
                ),
              )
              .toList(growable: false);
        });
        return;
      }

      final byPath = <String, FileNode>{
        for (final node in found ?? const <FileNode>[])
          if (node.path.trim().isNotEmpty) _normalizeFilePath(node.path): node,
      };
      final rankedPaths = rankQuickOpenPaths(
        byPath.keys,
        normalized,
        limit: 40,
      );
      setModalState(() {
        loading = false;
        errorMessage = '';
        resultNodes = rankedPaths
            .map((path) {
              final node = byPath[path];
              if (node != null) {
                return _QuickOpenResult(
                  path: node.path,
                  title: node.name,
                  subtitle: _normalizeFilePath(node.path),
                );
              }
              return _QuickOpenResult(
                path: path,
                title: _fileBasename(path),
                subtitle: path,
              );
            })
            .toList(growable: false);
      });
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setModalState) {
            return CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                const SingleActivator(LogicalKeyboardKey.enter): () =>
                    unawaited(openFirstQuickOpenResult(dialogContext)),
                const SingleActivator(LogicalKeyboardKey.numpadEnter): () =>
                    unawaited(openFirstQuickOpenResult(dialogContext)),
              },
              child: AlertDialog(
                title: Text(context.l10n.filesQuickOpenFile),
                content: SizedBox(
                  width: 520,
                  height: 420,
                  child: Column(
                    children: [
                      TextField(
                        key: const ValueKey<String>('quick_open_input'),
                        controller: queryController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: context.l10n.filesSearchHint,
                          prefixIcon: const Icon(Symbols.search),
                        ),
                        onChanged: (value) {
                          unawaited(runSearch(setModalState, value));
                        },
                        onSubmitted: (value) async {
                          await openFirstQuickOpenResult(dialogContext);
                        },
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<_QuickOpenSearchMode>(
                        segments: <ButtonSegment<_QuickOpenSearchMode>>[
                          ButtonSegment<_QuickOpenSearchMode>(
                            value: _QuickOpenSearchMode.names,
                            label: Text(context.l10n.filesNames),
                            icon: const Icon(Symbols.description),
                          ),
                          ButtonSegment<_QuickOpenSearchMode>(
                            value: _QuickOpenSearchMode.contents,
                            label: Text(context.l10n.filesContents),
                            icon: const Icon(Symbols.manage_search),
                          ),
                        ],
                        selected: <_QuickOpenSearchMode>{searchMode},
                        onSelectionChanged: (selected) {
                          setModalState(() {
                            searchMode = selected.single;
                          });
                          unawaited(
                            runSearch(setModalState, queryController.text),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: loading
                            ? const Center(child: CircularProgressIndicator())
                            : errorMessage.isNotEmpty
                            ? Center(
                                child: Text(
                                  errorMessage,
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : resultNodes.isEmpty
                            ? Center(
                                child: Text(
                                  queryController.text.trim().isEmpty
                                      ? context.l10n.filesNoOpenFilesHint
                                      : searchMode == _QuickOpenSearchMode.names
                                      ? context.l10n.filesFilesFound
                                      : context.l10n.filesNoContentMatches,
                                ),
                              )
                            : ListView.builder(
                                itemCount: resultNodes.length,
                                itemBuilder: (context, index) {
                                  final node = resultNodes[index];
                                  final normalizedPath = _normalizeFilePath(
                                    node.path,
                                  );
                                  return ListTile(
                                    key: ValueKey<String>(
                                      'quick_open_result_$normalizedPath',
                                    ),
                                    dense: _useDenseListTiles(context),
                                    leading: Icon(
                                      node.lineNumber == null
                                          ? Symbols.description
                                          : Symbols.manage_search,
                                      size: 18,
                                    ),
                                    title: Text(
                                      node.title,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      node.subtitle,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () async {
                                      await openQuickOpenResult(
                                        dialogContext,
                                        normalizedPath,
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      dialogActive = false;
                      Navigator.of(dialogContext).pop();
                    },
                    child: Text(context.l10n.chatClose),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    dialogActive = false;
  }

  Future<void> _openFileInTab({
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    required String path,
    bool revalidateCached = true,
    VoidCallback? onUpdated,
  }) async {
    final normalizedPath = _normalizeFilePath(path);
    if (normalizedPath.isEmpty) {
      return;
    }
    if (mounted) {
      _setState(() {
        fileState.tabSelection = openFileTab(
          fileState.tabSelection,
          normalizedPath,
        );
      });
      onUpdated?.call();
    }

    final cached = fileState.tabsByPath[normalizedPath];
    if (cached != null &&
        cached.status != _FileTabLoadStatus.error &&
        cached.status != _FileTabLoadStatus.loading) {
      onUpdated?.call();
      // Cache-first, stale-while-revalidate (ADR-020, applied to the file
      // domain of ADR-008): the cached content is shown immediately, and a
      // fresh read runs in the background so edits made outside the editor —
      // by the agent or another client — appear when the file is reopened.
      // Silent, so the editor is never covered by a spinner, and background,
      // so a dirty draft is left alone without reporting an error.
      if (revalidateCached) {
        unawaited(
          _reloadFileTab(
            fileState: fileState,
            projectProvider: projectProvider,
            path: normalizedPath,
            silent: true,
            background: true,
            onUpdated: onUpdated,
          ),
        );
      }
      return;
    }

    await _reloadFileTab(
      fileState: fileState,
      projectProvider: projectProvider,
      path: normalizedPath,
      onUpdated: onUpdated,
    );
  }

  Widget _buildFileExplorerPanel({
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    required bool isMobileLayout,
    VoidCallback? onStateChanged,
    VoidCallback? onCollapseRequested,
  }) {
    final rootNodes =
        fileState.directoryChildren[_ChatPageState._rootTreeCacheKey];
    final rootLoading = fileState.loadingDirectories.contains(
      _ChatPageState._rootTreeCacheKey,
    );
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            // Single inset layer: the pane padding above already provides the
            // horizontal edge, so only the header spacing remains.
            padding: const EdgeInsetsDirectional.only(end: 4, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.filesTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (fileState.tabSelection.hasOpenTabs)
                  Flexible(
                    child: IconButton(
                      key: const ValueKey<String>(
                        'file_tree_open_files_button',
                      ),
                      tooltip: context.l10n.chatOpenFiles,
                      visualDensity: Theme.of(context).visualDensity,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      onPressed: () {
                        unawaited(
                          _openOpenFilesDialog(
                            fileState: fileState,
                            projectProvider: projectProvider,
                            fullscreen: isMobileLayout,
                          ),
                        );
                      },
                      icon: const Icon(Symbols.folder_open),
                    ),
                  ),
                IconButton(
                  key: const ValueKey<String>('file_tree_quick_open_button'),
                  tooltip: context.l10n.filesQuickOpen,
                  visualDensity: Theme.of(context).visualDensity,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  onPressed: () {
                    unawaited(
                      _openQuickFileDialog(
                        fileState: fileState,
                        projectProvider: projectProvider,
                        onFileOpened: onStateChanged,
                        openInDialogAfterSelect: true,
                        dialogFullscreen: isMobileLayout,
                      ),
                    );
                  },
                  icon: const Icon(Symbols.search),
                ),
                if (_fileMutationsSupported(fileState))
                  PopupMenuButton<FileTreeContextMenuActionType>(
                    key: const ValueKey<String>('file_tree_new_button'),
                    tooltip: context.l10n.filesNew,
                    icon: const Icon(Symbols.add),
                    itemBuilder: (context) => [
                      PopupMenuItem<FileTreeContextMenuActionType>(
                        key: const ValueKey<String>('file_tree_menu_new_file'),
                        value: FileTreeContextMenuActionType.newFile,
                        child: Row(
                          children: [
                            Icon(
                              fileTreeActionIcon(
                                FileTreeContextMenuActionType.newFile,
                              ),
                              size: 18,
                            ),
                            const SizedBox(width: 12),
                            Text(context.l10n.filesNewFile),
                          ],
                        ),
                      ),
                      PopupMenuItem<FileTreeContextMenuActionType>(
                        key: const ValueKey<String>(
                          'file_tree_menu_new_folder',
                        ),
                        value: FileTreeContextMenuActionType.newFolder,
                        child: Row(
                          children: [
                            Icon(
                              fileTreeActionIcon(
                                FileTreeContextMenuActionType.newFolder,
                              ),
                              size: 18,
                            ),
                            const SizedBox(width: 12),
                            Text(context.l10n.filesNewFolder),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (action) {
                      unawaited(
                        _handleRootFileTreeAction(
                          action: action,
                          fileState: fileState,
                          projectProvider: projectProvider,
                          onUpdated: onStateChanged,
                        ),
                      );
                    },
                  ),
                IconButton(
                  key: const ValueKey<String>('file_tree_refresh_button'),
                  tooltip: context.l10n.filesRefresh,
                  visualDensity: Theme.of(context).visualDensity,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  onPressed: () {
                    unawaited(
                      _loadRootDirectoryNodes(
                        state: fileState,
                        projectProvider: projectProvider,
                        force: true,
                      ),
                    );
                  },
                  icon: const Icon(Symbols.refresh_rounded),
                ),
                if (onCollapseRequested != null)
                  IconButton(
                    key: const ValueKey<String>('hide_files_sidebar_button'),
                    tooltip: context.l10n.filesHideSidebar,
                    visualDensity: Theme.of(context).visualDensity,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    onPressed: onCollapseRequested,
                    icon: const Icon(Symbols.left_panel_close_rounded),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(
              _directoryLabel(projectProvider.currentDirectory),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Builder(
              builder: (_) {
                if (rootLoading && (rootNodes == null || rootNodes.isEmpty)) {
                  return ListView(
                    key: const ValueKey<String>('file_tree_loading_skeleton'),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: _buildFileTreeLoadingRows(
                      depth: 0,
                      cacheKey: _ChatPageState._rootTreeCacheKey,
                      rowCount: 5,
                    ),
                  );
                }
                if (fileState.treeError != null &&
                    (rootNodes == null || rootNodes.isEmpty)) {
                  return ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _buildFileTreeErrorRow(
                        fileState: fileState,
                        projectProvider: projectProvider,
                        cacheKey: _ChatPageState._rootTreeCacheKey,
                        requestPath: '.',
                        message: fileState.treeError!,
                        depth: 0,
                      ),
                    ],
                  );
                }
                if (rootNodes == null || rootNodes.isEmpty) {
                  return Center(child: Text(context.l10n.filesFilesFound));
                }
                return ListView(
                  key: const ValueKey<String>('file_tree_list'),
                  children: [
                    if (fileState.treeError != null)
                      _buildFileTreeErrorRow(
                        fileState: fileState,
                        projectProvider: projectProvider,
                        cacheKey: _ChatPageState._rootTreeCacheKey,
                        requestPath: '.',
                        message: fileState.treeError!,
                        depth: 0,
                      ),
                    ..._buildFileTreeChildren(
                      fileState: fileState,
                      projectProvider: projectProvider,
                      dialogFullscreen: isMobileLayout,
                      onStateChanged: onStateChanged,
                      parentCacheKey: _ChatPageState._rootTreeCacheKey,
                      depth: 0,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
