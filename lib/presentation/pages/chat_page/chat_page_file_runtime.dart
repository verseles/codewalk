part of '../chat_page.dart';

extension _ChatPageFileRuntime on _ChatPageState {
  // Delegate to shared path_utils to avoid duplicating normalization logic.
  String _normalizeFilePath(String value) => normalizeFilePath(value);

  String _fileBasename(String path) => fileBasename(path);

  String _resolveFileRootDirectory({
    required ProjectProvider projectProvider,
    required AppProvider appProvider,
  }) {
    final directory = projectProvider.currentDirectory;
    if (directory != null && directory.trim().isNotEmpty) {
      return _normalizeFilePath(directory);
    }
    final appPath = appProvider.appInfo?.path.data;
    if (appPath != null && appPath.trim().isNotEmpty) {
      return _normalizeFilePath(appPath);
    }
    return '/';
  }

  void _ensureFileRootLoaded({
    required _FileExplorerContextState state,
    required ProjectProvider projectProvider,
  }) {
    if (state.rootLoadScheduled) {
      return;
    }
    if (state.loadingDirectories.contains(_ChatPageState._rootTreeCacheKey)) {
      return;
    }
    if (state.directoryChildren.containsKey(_ChatPageState._rootTreeCacheKey)) {
      return;
    }
    state.rootLoadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      state.rootLoadScheduled = false;
      if (!mounted) {
        return;
      }
      if (state.loadingDirectories.contains(_ChatPageState._rootTreeCacheKey)) {
        return;
      }
      if (state.directoryChildren.containsKey(
        _ChatPageState._rootTreeCacheKey,
      )) {
        return;
      }
      unawaited(
        _loadRootDirectoryNodes(state: state, projectProvider: projectProvider),
      );
    });
  }

  Future<void> _ensureFileOperationCapabilities({
    required _FileExplorerContextState state,
    required ProjectProvider projectProvider,
  }) {
    if (state.fileOperationCapabilities != null) {
      return Future<void>.value();
    }
    if (state.fileOperationCapabilitiesLoading) {
      return state.fileOperationCapabilitiesLoad ?? Future<void>.value();
    }
    if (projectProvider.currentDirectory == null ||
        state.rootDirectory == '/' ||
        state.rootDirectory.trim().isEmpty) {
      state.fileOperationCapabilities = WorkspaceFileOperationsCapabilities(
        shellFileOpsSupported: false,
        message: context.l10n.filesActiveProjectRequired,
      );
      return Future<void>.value();
    }
    if (!di.sl.isRegistered<WorkspaceFileOperationsService>()) {
      state.fileOperationCapabilities = WorkspaceFileOperationsCapabilities(
        shellFileOpsSupported: false,
        message: context.l10n.filesOperationUnavailable,
      );
      return Future<void>.value();
    }
    final rootDirectory = state.rootDirectory;
    state.fileOperationCapabilitiesLoading = true;
    late final Future<void> load;
    load = di
        .sl<WorkspaceFileOperationsService>()
        .getCapabilities(
          serverScopeKey: projectProvider.contextKey,
          directory: rootDirectory,
        )
        .then<void>((capabilities) {
          if (!mounted || state.rootDirectory != rootDirectory) {
            return;
          }
          _setState(() {
            state.fileOperationCapabilities = capabilities;
            state.fileOperationCapabilitiesLoading = false;
          });
        })
        .catchError((_) {
          if (!mounted || state.rootDirectory != rootDirectory) {
            return;
          }
          _setState(() {
            state.fileOperationCapabilities =
                WorkspaceFileOperationsCapabilities(
                  shellFileOpsSupported: false,
                  message: context.l10n.filesOperationUnavailable,
                );
            state.fileOperationCapabilitiesLoading = false;
          });
        })
        .whenComplete(() {
          if (state.fileOperationCapabilitiesLoad == load) {
            state.fileOperationCapabilitiesLoad = null;
          }
        });
    state.fileOperationCapabilitiesLoad = load;
    return load;
  }

  void _reconcileFileContextWithSessionDiff({
    required String contextKey,
    required _FileExplorerContextState fileState,
    required ChatProvider chatProvider,
    required ProjectProvider projectProvider,
  }) {
    final diffFiles =
        chatProvider.currentSessionDiff
            .map((item) => item.file.trim())
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    final signature = diffFiles.join('|');
    if (_fileDiffSignaturesByContext[contextKey] == signature) {
      return;
    }
    _fileDiffSignaturesByContext[contextKey] = signature;
    if (signature.isEmpty) {
      return;
    }

    final staleDirectoryKeys = fileState.directoryChildren.keys
        .where((key) {
          if (key == _ChatPageState._rootTreeCacheKey) {
            return false;
          }
          final normalizedDirectory = _normalizeFilePath(key);
          return diffFiles.any((diffFile) {
            return _fileTreeDirectoryContainsDiff(
              directory: normalizedDirectory,
              diffFile: diffFile,
              rootDirectory: projectProvider.currentDirectory,
            );
          });
        })
        .toList(growable: false);
    for (final key in staleDirectoryKeys) {
      fileState.directoryChildren.remove(key);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      for (final tabPath in fileState.tabSelection.openPaths) {
        if (_diffMatchesPath(
          tabPath: tabPath,
          diffFiles: diffFiles,
          rootDirectory: projectProvider.currentDirectory,
        )) {
          unawaited(
            _reloadFileTab(
              fileState: fileState,
              projectProvider: projectProvider,
              path: tabPath,
              silent: true,
            ),
          );
        }
      }

      unawaited(
        _loadRootDirectoryNodes(
          state: fileState,
          projectProvider: projectProvider,
          force: true,
          showLoader: false,
        ),
      );
    });
  }

  bool _diffMatchesPath({
    required String tabPath,
    required List<String> diffFiles,
    required String? rootDirectory,
  }) {
    final normalizedTabPath = _normalizeFilePath(tabPath);
    for (final diffFile in diffFiles) {
      final normalizedDiff = _normalizeFilePath(diffFile);
      if (normalizedDiff.isEmpty) {
        continue;
      }
      if (normalizedTabPath == normalizedDiff ||
          normalizedTabPath.endsWith('/$normalizedDiff')) {
        return true;
      }
      final absoluteDiff = _resolveDiffAbsolutePath(
        diffFile: diffFile,
        rootDirectory: rootDirectory,
      );
      if (absoluteDiff != null && normalizedTabPath == absoluteDiff) {
        return true;
      }
    }
    return false;
  }

  bool _fileTreeDirectoryContainsDiff({
    required String directory,
    required String diffFile,
    required String? rootDirectory,
  }) {
    final normalizedDirectory = _normalizeFilePath(directory);
    final normalizedDiff = _normalizeFilePath(diffFile);
    if (_pathEqualsOrIsChild(normalizedDiff, normalizedDirectory)) {
      return true;
    }
    final absoluteDiff = _resolveDiffAbsolutePath(
      diffFile: diffFile,
      rootDirectory: rootDirectory,
    );
    if (absoluteDiff == null) {
      return false;
    }
    if (_pathEqualsOrIsChild(absoluteDiff, normalizedDirectory)) {
      return true;
    }
    final absoluteDirectory = _resolveDiffAbsolutePath(
      diffFile: normalizedDirectory,
      rootDirectory: rootDirectory,
    );
    return absoluteDirectory != null &&
        _pathEqualsOrIsChild(absoluteDiff, absoluteDirectory);
  }

  String? _resolveDiffAbsolutePath({
    required String diffFile,
    required String? rootDirectory,
  }) {
    final normalizedDiff = _normalizeFilePath(diffFile);
    if (normalizedDiff.isEmpty) {
      return null;
    }
    if (normalizedDiff.startsWith('/')) {
      return normalizedDiff;
    }
    final normalizedRoot = _normalizeFilePath(rootDirectory ?? '');
    if (normalizedRoot.isEmpty || normalizedRoot == '/') {
      return _normalizeFilePath('/$normalizedDiff');
    }
    return _normalizeFilePath('$normalizedRoot/$normalizedDiff');
  }

  Future<void> _loadRootDirectoryNodes({
    required _FileExplorerContextState state,
    required ProjectProvider projectProvider,
    bool force = false,
    bool showLoader = true,
  }) async {
    final contextDirectory = projectProvider.currentDirectory?.trim();
    final requestPath =
        (contextDirectory != null && contextDirectory.isNotEmpty)
        ? '.'
        : state.rootDirectory;
    await _loadDirectoryNodes(
      state: state,
      projectProvider: projectProvider,
      cacheKey: _ChatPageState._rootTreeCacheKey,
      requestPath: requestPath,
      force: force,
      showLoader: showLoader,
    );
  }

  Future<List<FileNode>?> _listFilesWithFallback({
    required ProjectProvider projectProvider,
    required String requestPath,
  }) async {
    final candidates = _listPathCandidates(
      requestPath: requestPath,
      contextDirectory: projectProvider.currentDirectory,
    );
    List<FileNode>? emptyFallback;
    for (final candidate in candidates) {
      final listed = await projectProvider.listFiles(path: candidate);
      if (listed != null) {
        if (listed.isNotEmpty) {
          return listed;
        }
        emptyFallback ??= listed;
      }
    }
    return emptyFallback;
  }

  List<String> _listPathCandidates({
    required String requestPath,
    required String? contextDirectory,
  }) {
    final normalizedPath = _normalizeFilePath(requestPath);
    final normalizedContext = contextDirectory == null
        ? ''
        : _normalizeFilePath(contextDirectory);
    final candidates = <String>{};

    if (normalizedPath.isEmpty || normalizedPath == '.') {
      candidates.add('.');
    } else {
      candidates.add(normalizedPath);
    }

    if (normalizedContext.isNotEmpty && normalizedPath.isNotEmpty) {
      if (normalizedPath == normalizedContext) {
        candidates.add('.');
      }
      final contextPrefix = '$normalizedContext/';
      if (normalizedPath.startsWith(contextPrefix)) {
        final relative = normalizedPath.substring(contextPrefix.length);
        if (relative.isNotEmpty) {
          candidates.add(relative);
          candidates.add('./$relative');
        }
      }
    }

    return candidates.toList(growable: false);
  }

  List<String> _contentPathCandidates({
    required String path,
    required String? contextDirectory,
  }) {
    final normalizedPath = _normalizeFilePath(path);
    final normalizedContext = contextDirectory == null
        ? ''
        : _normalizeFilePath(contextDirectory);
    final candidates = <String>{normalizedPath};
    if (normalizedContext.isNotEmpty) {
      final contextPrefix = '$normalizedContext/';
      if (normalizedPath.startsWith(contextPrefix)) {
        final relative = normalizedPath.substring(contextPrefix.length);
        if (relative.isNotEmpty) {
          candidates.add(relative);
          candidates.add('./$relative');
        }
      }
    }
    return candidates.toList(growable: false);
  }

  Future<FileContent?> _readFileContentWithFallback({
    required ProjectProvider projectProvider,
    required String path,
  }) async {
    final candidates = _contentPathCandidates(
      path: path,
      contextDirectory: projectProvider.currentDirectory,
    );
    FileContent? emptyFallback;
    for (final candidate in candidates) {
      final content = await projectProvider.readFileContent(path: candidate);
      if (content != null) {
        if (content.isBinary || content.content.isNotEmpty) {
          return content;
        }
        emptyFallback ??= content;
      }
    }
    return emptyFallback;
  }

  Future<void> _openFileAndFocusDialog({
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    required String path,
    required bool dialogFullscreen,
    VoidCallback? onUpdated,
  }) async {
    final normalizedPath = _normalizeFilePath(path);
    final cached = fileState.tabsByPath[normalizedPath];
    final revalidateInDialog =
        cached != null &&
        cached.status != _FileTabLoadStatus.error &&
        cached.status != _FileTabLoadStatus.loading;
    await _openFileInTab(
      fileState: fileState,
      projectProvider: projectProvider,
      path: normalizedPath,
      revalidateCached: !revalidateInDialog,
      onUpdated: onUpdated,
    );
    if (!mounted) {
      return;
    }
    await _openOpenFilesDialog(
      fileState: fileState,
      projectProvider: projectProvider,
      fullscreen: dialogFullscreen,
      revalidatePath: revalidateInDialog ? normalizedPath : null,
    );
  }

  /// Handle a file path tap from chat messages.
  /// Opens the file in the viewer and optionally scrolls to a specific line.
  /// Shows a snackbar if the file cannot be loaded.
  Future<void> _onFilePathTap(String path, int? line, int? col) async {
    if (!mounted) return;
    final projectProvider = context.read<ProjectProvider>();
    final appProvider = context.read<AppProvider>();
    final fileState = _resolveFileContextState(
      projectProvider: projectProvider,
      appProvider: appProvider,
    );
    // Resolve relative paths against the project root directory.
    final rootDir = _resolveFileRootDirectory(
      projectProvider: projectProvider,
      appProvider: appProvider,
    );
    final resolvedPath = path.startsWith('/')
        ? _normalizeFilePath(path)
        : _normalizeFilePath('$rootDir/$path');

    // Set pending scroll target so the viewer scrolls after content loads.
    if (line != null && line > 0) {
      fileState.pendingScrollToLine = line;
    }

    final isCompact = context.windowSizeClass.isCompact;
    await _openFileAndFocusDialog(
      fileState: fileState,
      projectProvider: projectProvider,
      path: resolvedPath,
      dialogFullscreen: isCompact,
      onUpdated: () => _setState(() {}),
    );

    // Show feedback if the file failed to load.
    if (!mounted) return;
    final tabState = fileState.tabsByPath[_normalizeFilePath(resolvedPath)];
    if (tabState != null && tabState.status == _FileTabLoadStatus.error) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(context.l10n.msgFilePathNotFound(resolvedPath)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _activateFileTab({
    required _FileExplorerContextState fileState,
    required String path,
    VoidCallback? onUpdated,
  }) {
    _setState(() {
      fileState.tabSelection = activateFileTab(fileState.tabSelection, path);
    });
    onUpdated?.call();
  }

  /// Saves a dirty tab and only then closes it, used when autosave is on.
  Future<void> _saveAndCloseFileTab({
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    required String path,
    VoidCallback? onUpdated,
  }) async {
    await _saveFileEditorDraft(
      fileState: fileState,
      projectProvider: projectProvider,
      path: path,
      onUpdated: onUpdated,
    );
    if (!mounted) {
      return;
    }
    var draft = fileState.editorDraftsByPath[_normalizeFilePath(path)];
    if (draft != null &&
        draft.isDirty &&
        draft.activeSave == null &&
        draft.saveErrorMessage == null) {
      await _saveFileEditorDraft(
        fileState: fileState,
        projectProvider: projectProvider,
        path: path,
        onUpdated: onUpdated,
      );
      if (!mounted) {
        return;
      }
      draft = fileState.editorDraftsByPath[_normalizeFilePath(path)];
    }
    if (draft != null && draft.isDirty) {
      // The save failed; keep the tab open so the error stays visible.
      onUpdated?.call();
      return;
    }
    _closeFileTab(fileState: fileState, path: path, onUpdated: onUpdated);
  }

  void _closeFileTab({
    required _FileExplorerContextState fileState,
    required String path,
    ProjectProvider? projectProvider,
    VoidCallback? onUpdated,
  }) {
    final normalizedPath = _normalizeFilePath(path);
    if (!fileState.tabSelection.openPaths.contains(normalizedPath)) {
      // Already closed (for example an overlapping autosave close won the
      // race); stay idempotent instead of emitting a spurious update that
      // could dismiss the dialog a second time.
      return;
    }
    final draft = fileState.editorDraftsByPath[normalizedPath];
    if (draft != null &&
        draft.isDirty &&
        projectProvider != null &&
        context.read<SettingsProvider>().editorAutosaveEnabled) {
      // With autosave on, closing is an implicit save: blocking here would
      // contradict the promise that work is never lost.
      draft.cancelAutosave();
      unawaited(
        _saveAndCloseFileTab(
          fileState: fileState,
          projectProvider: projectProvider,
          path: normalizedPath,
          onUpdated: onUpdated,
        ),
      );
      return;
    }
    if (draft != null && draft.isDirty) {
      _setState(() {
        draft.saveErrorMessage = _dirtyCloseBlockedMessage;
      });
      onUpdated?.call();
      _showFileOperationSnackBar(_dirtyCloseBlockedMessage);
      return;
    }
    _setState(() {
      fileState.fileReloadGenerations[normalizedPath] =
          ++fileState.nextFileReloadGeneration;
      fileState.tabSelection = closeFileTab(fileState.tabSelection, path);
      // Clean up line selection state for the closed tab.
      fileState.selectedLinesByPath.remove(normalizedPath);
      fileState.lastSelectedLineByPath.remove(normalizedPath);
      fileState.removeEditorDraft(normalizedPath);
    });
    onUpdated?.call();
  }

  Future<void> _reloadFileTab({
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    required String path,
    bool silent = false,
    bool background = false,
    VoidCallback? onUpdated,
  }) async {
    final normalizedPath = _normalizeFilePath(path);
    final dirtyDraft = fileState.editorDraftsByPath[normalizedPath];
    if (dirtyDraft != null && dirtyDraft.isDirty) {
      // A background revalidation the user did not ask for must stay invisible
      // when there are unsaved changes: the draft is protected (ADR-043) but
      // reporting it as an error would be noise.
      if (background) {
        return;
      }
      final message = context.l10n.filesReloadSkippedUnsavedChanges;
      _setState(() {
        dirtyDraft.saveErrorMessage = message;
      });
      onUpdated?.call();
      if (!silent) {
        _showFileOperationSnackBar(message);
      }
      return;
    }
    final requestGeneration = ++fileState.nextFileReloadGeneration;
    fileState.fileReloadGenerations[normalizedPath] = requestGeneration;
    if (!silent && mounted) {
      _setState(() {
        fileState.tabsByPath[normalizedPath] = const _FileTabViewState(
          status: _FileTabLoadStatus.loading,
          content: '',
        );
      });
      onUpdated?.call();
    }

    final content = await _readFileContentWithFallback(
      projectProvider: projectProvider,
      path: normalizedPath,
    );
    if (!mounted ||
        fileState.fileReloadGenerations[normalizedPath] != requestGeneration) {
      return;
    }
    final latestDraft = fileState.editorDraftsByPath[normalizedPath];
    if (latestDraft != null && latestDraft.isDirty) {
      return;
    }
    if (content == null && background) {
      return;
    }
    _setState(() {
      if (content == null) {
        fileState.removeEditorDraft(normalizedPath);
        fileState.tabsByPath[normalizedPath] = _FileTabViewState(
          status: _FileTabLoadStatus.error,
          content: '',
          errorMessage:
              projectProvider.error ?? context.l10n.filesFailedToLoadContent,
        );
        return;
      }
      if (content.isBinary) {
        fileState.removeEditorDraft(normalizedPath);
        fileState.tabsByPath[normalizedPath] = _FileTabViewState(
          status: _FileTabLoadStatus.binary,
          content: '',
          mimeType: content.mimeType,
        );
        return;
      }
      final text = content.content;
      fileState.tabsByPath[normalizedPath] = _FileTabViewState(
        status: _FileTabLoadStatus.ready,
        content: text,
        mimeType: content.mimeType,
      );
    });
    onUpdated?.call();
  }

  Future<void> _openOpenFilesDialog({
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    required bool fullscreen,
    String? revalidatePath,
  }) async {
    if (!fileState.tabSelection.hasOpenTabs || !mounted) {
      return;
    }
    final mediaQuery = MediaQuery.of(context);
    final dialogWidth = (mediaQuery.size.width * 0.7).clamp(560.0, 1200.0);
    final dialogHeight = (mediaQuery.size.height * 0.7).clamp(420.0, 900.0);
    var capabilityRefreshAttached = false;
    var revalidationScheduled = false;
    var autoDismissed = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            if (!revalidationScheduled && revalidatePath != null) {
              revalidationScheduled = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !dialogContext.mounted) {
                  return;
                }
                unawaited(
                  _reloadFileTab(
                    fileState: fileState,
                    projectProvider: projectProvider,
                    path: revalidatePath,
                    silent: true,
                    background: true,
                    onUpdated: () {
                      if (dialogContext.mounted) {
                        setDialogState(() {});
                      }
                    },
                  ),
                );
              });
            }
            if (!capabilityRefreshAttached &&
                fileState.fileOperationCapabilitiesLoading) {
              capabilityRefreshAttached = true;
              final capabilitiesLoad = fileState.fileOperationCapabilitiesLoad;
              if (capabilitiesLoad != null) {
                unawaited(
                  capabilitiesLoad.whenComplete(() {
                    if (!mounted || !dialogContext.mounted) {
                      return;
                    }
                    setDialogState(() {});
                  }),
                );
              }
            }
            // Refreshes the dialog after tab switches, saves and closes. When
            // the last tab is gone the dialog dismisses itself instead of
            // lingering on an empty panel (issue #167). autoDismissed lives
            // in the outer dialog scope so rebuilds cannot reset it.
            void refreshDialog() {
              if (!dialogContext.mounted || !mounted || autoDismissed) {
                return;
              }
              if (!fileState.tabSelection.hasOpenTabs) {
                autoDismissed = true;
                // The route stays mounted during its reverse transition, so a
                // second overlapping callback must not pop the page beneath.
                if (ModalRoute.of(dialogContext)?.isCurrent ?? true) {
                  Navigator.of(dialogContext).pop();
                }
                return;
              }
              setDialogState(() {});
            }

            // Dialog close shared by both variants: same row as the tab
            // strip (right side) instead of a header of its own (issue #167).
            // Single builder so the two branches cannot diverge.
            Widget buildDialogCloseButton() {
              return IconButton(
                tooltip: context.l10n.chatClose,
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: IconButton.styleFrom(
                  minimumSize: const Size(40, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Symbols.close),
              );
            }

            if (fullscreen) {
              return Dialog.fullscreen(
                key: const ValueKey<String>('open_files_dialog_fullscreen'),
                child: Scaffold(
                  // No AppBar: the dialog close shares the tab-strip row
                  // (right side) instead of owning a header bar (issue #167).
                  body: SafeArea(
                    top: true,
                    bottom: false,
                    child: _buildFileViewerPanel(
                      fileState: fileState,
                      projectProvider: projectProvider,
                      height: double.infinity,
                      margin: const EdgeInsets.fromLTRB(4, 10, 4, 10),
                      onStateChanged: refreshDialog,
                      headerTrailing: buildDialogCloseButton(),
                      onContextAdded: () {
                      // Pop the viewer. A second pop only happens when the
                      // mobile Files dialog is genuinely underneath (issue
                      // #167): direct entries (chat links, quick-open, tree)
                      // sit straight above chat, so an unconditional second
                      // pop would eject the ChatPage route.
                      final navigator = Navigator.of(dialogContext);
                      navigator.pop();
                      if (navigator.canPop()) {
                        navigator.pop();
                      }
                      _inputFocusNode.requestFocus();
                    },
                  ),
                ),
              ),
            );
            }
            return Dialog(
              key: const ValueKey<String>('open_files_dialog_centered'),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 24,
              ),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: dialogWidth.toDouble(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: 300,
                    maxHeight: dialogHeight.toDouble(),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildFileViewerPanel(
                          fileState: fileState,
                          projectProvider: projectProvider,
                          height: double.infinity,
                          margin: const EdgeInsets.fromLTRB(4, 10, 4, 10),
                          onStateChanged: refreshDialog,
                          // Dialog close shares the tab-strip row (right
                          // side); no header row of its own (issue #167).
                          headerTrailing: buildDialogCloseButton(),
                          onContextAdded: () {
                            Navigator.of(dialogContext).pop();
                            _inputFocusNode.requestFocus();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  bool _fileMutationsSupported(_FileExplorerContextState fileState) {
    return fileState.fileOperationCapabilities?.shellFileOpsSupported == true;
  }

  List<FileTreeContextMenuAction> _fileTreeActionsForNode({
    required _FileExplorerContextState fileState,
    required FileNode node,
  }) {
    final actions = <FileTreeContextMenuAction>[];
    if (_fileMutationsSupported(fileState)) {
      if (node.isDirectory) {
        actions
          ..add(_fileTreeAction(FileTreeContextMenuActionType.newFile))
          ..add(_fileTreeAction(FileTreeContextMenuActionType.newFolder));
      }
      actions.add(_fileTreeAction(FileTreeContextMenuActionType.rename));
      if (!node.isDirectory) {
        actions.add(_fileTreeAction(FileTreeContextMenuActionType.duplicate));
      }
      actions.add(_fileTreeAction(FileTreeContextMenuActionType.delete));
    }
    actions
      ..add(_fileTreeAction(FileTreeContextMenuActionType.copyPath))
      ..add(_fileTreeAction(FileTreeContextMenuActionType.refresh));
    return actions;
  }

  FileTreeContextMenuAction _fileTreeAction(
    FileTreeContextMenuActionType type,
  ) {
    return FileTreeContextMenuAction(
      type: type,
      label: _fileTreeActionLabel(type),
      icon: fileTreeActionIcon(type),
      destructive: type == FileTreeContextMenuActionType.delete,
    );
  }

  String _fileTreeActionLabel(FileTreeContextMenuActionType type) {
    switch (type) {
      case FileTreeContextMenuActionType.newFile:
        return context.l10n.filesNewFile;
      case FileTreeContextMenuActionType.newFolder:
        return context.l10n.filesNewFolder;
      case FileTreeContextMenuActionType.rename:
        return context.l10n.filesRename;
      case FileTreeContextMenuActionType.duplicate:
        return context.l10n.filesDuplicate;
      case FileTreeContextMenuActionType.delete:
        return context.l10n.filesDelete;
      case FileTreeContextMenuActionType.copyPath:
        return context.l10n.filesCopyPath;
      case FileTreeContextMenuActionType.refresh:
        return context.l10n.filesRefresh;
    }
  }

  Future<void> _handleRootFileTreeAction({
    required FileTreeContextMenuActionType action,
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    VoidCallback? onUpdated,
  }) async {
    switch (action) {
      case FileTreeContextMenuActionType.newFile:
        await _createFileTreeEntry(
          fileState: fileState,
          projectProvider: projectProvider,
          parentDirectory: fileState.rootDirectory,
          createFolder: false,
          onUpdated: onUpdated,
        );
        return;
      case FileTreeContextMenuActionType.newFolder:
        await _createFileTreeEntry(
          fileState: fileState,
          projectProvider: projectProvider,
          parentDirectory: fileState.rootDirectory,
          createFolder: true,
          onUpdated: onUpdated,
        );
        return;
      case FileTreeContextMenuActionType.rename:
      case FileTreeContextMenuActionType.duplicate:
      case FileTreeContextMenuActionType.delete:
      case FileTreeContextMenuActionType.copyPath:
      case FileTreeContextMenuActionType.refresh:
        return;
    }
  }

  Future<void> _handleFileTreeAction({
    required FileTreeContextMenuActionType action,
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    required FileNode node,
    required String parentCacheKey,
    VoidCallback? onUpdated,
  }) async {
    final nodePath = _absoluteFileTreePath(fileState, node.path);
    final parentDirectory = node.isDirectory
        ? nodePath
        : _parentDirectoryForFilePath(nodePath);
    switch (action) {
      case FileTreeContextMenuActionType.newFile:
        await _createFileTreeEntry(
          fileState: fileState,
          projectProvider: projectProvider,
          parentDirectory: parentDirectory,
          createFolder: false,
          refreshCacheKey: node.path,
          refreshRequestPath: node.path,
          onUpdated: onUpdated,
        );
        return;
      case FileTreeContextMenuActionType.newFolder:
        await _createFileTreeEntry(
          fileState: fileState,
          projectProvider: projectProvider,
          parentDirectory: parentDirectory,
          createFolder: true,
          refreshCacheKey: node.path,
          refreshRequestPath: node.path,
          onUpdated: onUpdated,
        );
        return;
      case FileTreeContextMenuActionType.rename:
        await _renameFileTreeNode(
          fileState: fileState,
          projectProvider: projectProvider,
          node: node,
          parentCacheKey: parentCacheKey,
          onUpdated: onUpdated,
        );
        return;
      case FileTreeContextMenuActionType.duplicate:
        await _duplicateFileTreeNode(
          fileState: fileState,
          projectProvider: projectProvider,
          node: node,
          parentCacheKey: parentCacheKey,
          onUpdated: onUpdated,
        );
        return;
      case FileTreeContextMenuActionType.delete:
        await _deleteFileTreeNode(
          fileState: fileState,
          projectProvider: projectProvider,
          node: node,
          parentCacheKey: parentCacheKey,
          onUpdated: onUpdated,
        );
        return;
      case FileTreeContextMenuActionType.copyPath:
        final copiedMessage = context.l10n.filesPathCopied;
        await Clipboard.setData(ClipboardData(text: nodePath));
        if (!mounted) {
          return;
        }
        _showFileOperationSnackBar(copiedMessage);
        return;
      case FileTreeContextMenuActionType.refresh:
        await _refreshFileTreeDirectory(
          fileState: fileState,
          projectProvider: projectProvider,
          directory: parentDirectory,
          cacheKey: node.isDirectory ? node.path : parentCacheKey,
          requestPath: node.isDirectory
              ? node.path
              : _requestPathForFileTreeCacheKey(
                  fileState: fileState,
                  cacheKey: parentCacheKey,
                  fallbackDirectory: parentDirectory,
                ),
          onUpdated: onUpdated,
        );
        return;
    }
  }

  Future<void> _createFileTreeEntry({
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    required String parentDirectory,
    required bool createFolder,
    String? refreshCacheKey,
    String? refreshRequestPath,
    VoidCallback? onUpdated,
  }) async {
    final successMessage = createFolder
        ? context.l10n.filesFolderCreated
        : context.l10n.filesFileCreated;
    if (_isInsidePendingFileTreeMutation(
      fileState,
      _fileTreePathAliases(fileState, parentDirectory),
    )) {
      _showFileOperationSnackBar(_pathMutationInProgressMessage);
      return;
    }
    final name = await _showFileNameDialog(
      title: createFolder
          ? context.l10n.filesCreateFolderTitle
          : context.l10n.filesCreateFileTitle,
      actionLabel: createFolder
          ? context.l10n.filesNewFolder
          : context.l10n.filesNewFile,
    );
    if (name == null || !mounted) {
      return;
    }
    final targetPath = _joinFilePath(parentDirectory, name);
    if (_hasPendingFileTreeMutation(
      fileState,
      _fileTreePathAliases(fileState, targetPath),
    )) {
      _showFileOperationSnackBar(_pathMutationInProgressMessage);
      return;
    }
    final service = di.sl<WorkspaceFileOperationsService>();
    final result = createFolder
        ? await service.createFolder(
            serverScopeKey: projectProvider.contextKey,
            rootDirectory: fileState.rootDirectory,
            parentDirectory: parentDirectory,
            name: name,
          )
        : await service.createFile(
            serverScopeKey: projectProvider.contextKey,
            rootDirectory: fileState.rootDirectory,
            parentDirectory: parentDirectory,
            name: name,
          );
    if (!mounted) {
      return;
    }
    if (!result.ok) {
      _showFileOperationSnackBar(
        _fileOperationErrorLabel(result.code, message: result.message),
      );
      return;
    }
    await _refreshFileTreeDirectory(
      fileState: fileState,
      projectProvider: projectProvider,
      directory: parentDirectory,
      cacheKey: refreshCacheKey,
      requestPath: refreshRequestPath,
      onUpdated: onUpdated,
    );
    _showFileOperationSnackBar(successMessage);
  }

  Future<void> _renameFileTreeNode({
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    required FileNode node,
    required String parentCacheKey,
    VoidCallback? onUpdated,
  }) async {
    final successMessage = context.l10n.filesRenamed;
    final originalNodePath = _normalizeFilePath(node.path);
    final nodePath = _absoluteFileTreePath(fileState, node.path);
    if (_blockPathMutationForActiveEditorDrafts(
      fileState: fileState,
      path: nodePath,
      alternatePath: originalNodePath,
      onUpdated: onUpdated,
    )) {
      return;
    }
    final parentDirectory = _parentDirectoryForFilePath(nodePath);
    final nextName = await _showFileNameDialog(
      title: context.l10n.filesRenameTitle(node.name),
      actionLabel: context.l10n.filesRename,
      initialName: node.name,
    );
    if (nextName == null || !mounted || nextName == node.name) {
      return;
    }
    final result = await di.sl<WorkspaceFileOperationsService>().rename(
      serverScopeKey: projectProvider.contextKey,
      rootDirectory: fileState.rootDirectory,
      parentDirectory: parentDirectory,
      oldName: node.name,
      newName: nextName,
    );
    if (!mounted) {
      return;
    }
    if (!result.ok) {
      _showFileOperationSnackBar(
        _fileOperationErrorLabel(result.code, message: result.message),
      );
      return;
    }
    final oldPath = _normalizeFilePath(result.path ?? nodePath);
    final newPath = _normalizeFilePath(
      result.newPath ?? _joinFilePath(parentDirectory, nextName),
    );
    _reconcileRenamedFileTreePath(
      fileState: fileState,
      oldPath: oldPath,
      newPath: newPath,
    );
    if (originalNodePath != oldPath) {
      _reconcileRenamedFileTreePath(
        fileState: fileState,
        oldPath: originalNodePath,
        newPath: _siblingFileTreePath(originalNodePath, nextName),
      );
    }
    await _refreshFileTreeDirectory(
      fileState: fileState,
      projectProvider: projectProvider,
      directory: parentDirectory,
      cacheKey: parentCacheKey,
      requestPath: _requestPathForFileTreeCacheKey(
        fileState: fileState,
        cacheKey: parentCacheKey,
        fallbackDirectory: parentDirectory,
      ),
      onUpdated: onUpdated,
    );
    _showFileOperationSnackBar(successMessage);
  }

  Future<void> _duplicateFileTreeNode({
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    required FileNode node,
    required String parentCacheKey,
    VoidCallback? onUpdated,
  }) async {
    final successMessage = context.l10n.filesDuplicated;
    final nodePath = _absoluteFileTreePath(fileState, node.path);
    final parentDirectory = _parentDirectoryForFilePath(nodePath);

    final siblings = fileState.directoryChildren[parentCacheKey] ?? const [];
    final existingNames = siblings.map((child) => child.name).toSet();
    final copyName = duplicateFileName(node.name, existingNames);

    final result = await di.sl<WorkspaceFileOperationsService>().duplicateFile(
      serverScopeKey: projectProvider.contextKey,
      rootDirectory: fileState.rootDirectory,
      parentDirectory: parentDirectory,
      sourceName: node.name,
      destinationName: copyName,
    );
    if (!mounted) {
      return;
    }
    if (!result.ok) {
      _showFileOperationSnackBar(
        _fileOperationErrorLabel(result.code, message: result.message),
      );
      return;
    }

    await _refreshFileTreeDirectory(
      fileState: fileState,
      projectProvider: projectProvider,
      directory: parentDirectory,
      cacheKey: parentCacheKey,
      requestPath: _requestPathForFileTreeCacheKey(
        fileState: fileState,
        cacheKey: parentCacheKey,
        fallbackDirectory: parentDirectory,
      ),
      onUpdated: onUpdated,
    );
    _showFileOperationSnackBar(successMessage);
  }

  Future<void> _deleteFileTreeNode({
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    required FileNode node,
    required String parentCacheKey,
    VoidCallback? onUpdated,
  }) async {
    final successMessage = context.l10n.filesDeleted;
    final nodePathAliases = _fileTreePathAliases(fileState, node.path);
    final nodePath = _absoluteFileTreePath(fileState, node.path);
    if (_blockPathMutationForActiveEditorDrafts(
      fileState: fileState,
      path: nodePath,
      alternatePath: node.path,
      onUpdated: onUpdated,
    )) {
      return;
    }
    final confirmed = await _confirmDeleteFileTreeNode(node);
    if (!confirmed || !mounted) {
      return;
    }
    final parentDirectory = _parentDirectoryForFilePath(nodePath);
    _setState(() {
      fileState.pendingMutationPaths.addAll(nodePathAliases);
    });
    onUpdated?.call();
    final result = await di.sl<WorkspaceFileOperationsService>().delete(
      serverScopeKey: projectProvider.contextKey,
      rootDirectory: fileState.rootDirectory,
      parentDirectory: parentDirectory,
      name: node.name,
    );
    if (!mounted) {
      fileState.pendingMutationPaths.removeAll(nodePathAliases);
      return;
    }
    _setState(() {
      fileState.pendingMutationPaths.removeAll(nodePathAliases);
    });
    onUpdated?.call();
    if (!result.ok) {
      _showFileOperationSnackBar(
        _fileOperationErrorLabel(result.code, message: result.message),
      );
      return;
    }
    for (final path in nodePathAliases) {
      _reconcileDeletedFileTreePath(fileState: fileState, path: path);
    }
    await _refreshFileTreeDirectory(
      fileState: fileState,
      projectProvider: projectProvider,
      directory: parentDirectory,
      cacheKey: parentCacheKey,
      requestPath: _requestPathForFileTreeCacheKey(
        fileState: fileState,
        cacheKey: parentCacheKey,
        fallbackDirectory: parentDirectory,
      ),
      onUpdated: onUpdated,
    );
    if (!mounted) {
      return;
    }
    for (final path in nodePathAliases) {
      _reconcileDeletedFileTreePath(fileState: fileState, path: path);
    }
    onUpdated?.call();
    _showFileOperationSnackBar(successMessage);
  }

  bool _blockPathMutationForActiveEditorDrafts({
    required _FileExplorerContextState fileState,
    required String path,
    String? alternatePath,
    VoidCallback? onUpdated,
  }) {
    final normalizedPaths = <String>{};
    for (final candidate in <String?>[path, alternatePath]) {
      if (candidate != null) {
        normalizedPaths.addAll(_fileTreePathAliases(fileState, candidate));
      }
    }
    if (_hasPendingFileTreeMutation(fileState, normalizedPaths)) {
      _showFileOperationSnackBar(_pathMutationInProgressMessage);
      return true;
    }
    final blockedDrafts = fileState.editorDraftsByPath.entries
        .where(
          (entry) =>
              normalizedPaths.any(
                (path) => _pathEqualsOrIsChild(entry.key, path),
              ) &&
              (entry.value.isDirty || entry.value.isSaving),
        )
        .map((entry) => entry.value)
        .toList(growable: false);
    if (blockedDrafts.isEmpty) {
      return false;
    }
    final message = blockedDrafts.any((draft) => draft.isSaving)
        ? _savingPathMutationBlockedMessage
        : _dirtyPathMutationBlockedMessage;
    _setState(() {
      for (final draft in blockedDrafts) {
        draft.saveErrorMessage = message;
      }
    });
    onUpdated?.call();
    _showFileOperationSnackBar(message);
    return true;
  }

  Future<String?> _showFileNameDialog({
    required String title,
    required String actionLabel,
    String initialName = '',
  }) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => _FileNameDialog(
        title: title,
        actionLabel: actionLabel,
        initialName: initialName,
      ),
    );
  }

  Future<bool> _confirmDeleteFileTreeNode(FileNode node) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.filesDeleteTitle(node.name)),
        content: Text(context.l10n.filesDeleteConfirm(node.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _refreshFileTreeDirectory({
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    required String directory,
    String? cacheKey,
    String? requestPath,
    VoidCallback? onUpdated,
  }) async {
    final normalized = _normalizeFilePath(directory);
    final normalizedRequestPath = _normalizeFilePath(requestPath ?? directory);
    final normalizedCacheKey = cacheKey == null
        ? _directoryCacheKey(fileState, normalized)
        : cacheKey == _ChatPageState._rootTreeCacheKey
        ? _ChatPageState._rootTreeCacheKey
        : _normalizeFilePath(cacheKey);
    await _loadDirectoryNodes(
      state: fileState,
      projectProvider: projectProvider,
      cacheKey: normalizedCacheKey,
      requestPath: normalizedRequestPath,
      force: true,
    );
    onUpdated?.call();
  }

  Future<void> _saveFileEditorDraft({
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    required String path,
    bool allowInactiveContext = false,
    bool silent = false,
    VoidCallback? onUpdated,
  }) async {
    final normalizedPath = _normalizeFilePath(path);
    final draft = fileState.editorDraftsByPath[normalizedPath];
    if (draft == null) {
      return;
    }
    final activeSave = draft.activeSave;
    if (activeSave != null) {
      await activeSave;
      return;
    }
    if (!draft.isDirty ||
        _appProvider?.activeServerId != fileState.serverId ||
        (!allowInactiveContext &&
            projectProvider.contextKey != fileState.contextKey)) {
      return;
    }
    late final Future<void> save;
    save = _performFileEditorDraftSave(
      fileState: fileState,
      projectProvider: projectProvider,
      path: normalizedPath,
      draft: draft,
      allowInactiveContext: allowInactiveContext,
      silent: silent,
      onUpdated: onUpdated,
    );
    draft.activeSave = save;
    try {
      await save;
    } finally {
      if (identical(draft.activeSave, save)) {
        draft.activeSave = null;
      }
      final pendingFlushContent = draft.pendingLifecycleFlushContent;
      final pendingFlushAllowsInactiveContext =
          draft.pendingLifecycleFlushAllowsInactiveContext;
      draft.pendingLifecycleFlushContent = null;
      draft.pendingLifecycleFlushAllowsInactiveContext = false;
      if (pendingFlushContent != null &&
          pendingFlushContent != draft.savedContent &&
          _settingsProvider?.editorAutosaveEnabled == true &&
          _appProvider?.activeServerId == fileState.serverId) {
        if (mounted && fileState.editorDraftsByPath[normalizedPath] == draft) {
          unawaited(
            _saveFileEditorDraft(
              fileState: fileState,
              projectProvider: projectProvider,
              path: normalizedPath,
              allowInactiveContext: pendingFlushAllowsInactiveContext,
              silent: true,
            ),
          );
        } else {
          unawaited(
            _writeFileEditorSnapshot(
              fileState: fileState,
              path: normalizedPath,
              content: pendingFlushContent,
            ),
          );
        }
      }
    }
  }

  Future<void> _writeFileEditorSnapshot({
    required _FileExplorerContextState fileState,
    required String path,
    required String content,
  }) async {
    if (!di.sl.isRegistered<WorkspaceFileOperationsService>()) {
      return;
    }
    await di.sl<WorkspaceFileOperationsService>().writeFile(
      serverScopeKey: fileState.contextKey,
      rootDirectory: fileState.rootDirectory,
      path: path,
      content: content,
    );
  }

  Future<void> _performFileEditorDraftSave({
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    required String path,
    required _FileEditorDraftState draft,
    required bool allowInactiveContext,
    required bool silent,
    VoidCallback? onUpdated,
  }) async {
    final normalizedPath = _normalizeFilePath(path);
    if (_hasPendingFileTreeMutation(
      fileState,
      _fileTreePathAliases(fileState, normalizedPath),
    )) {
      final message = _pathMutationInProgressMessage;
      _setState(() {
        draft.saveErrorMessage = message;
      });
      onUpdated?.call();
      if (!silent) {
        _showFileOperationSnackBar(message);
      }
      return;
    }
    if (!di.sl.isRegistered<WorkspaceFileOperationsService>() ||
        !_fileMutationsSupported(fileState)) {
      final message = context.l10n.filesOperationUnavailable;
      _setState(() {
        draft.saveErrorMessage = message;
      });
      onUpdated?.call();
      if (!silent) {
        _showFileOperationSnackBar(message);
      }
      return;
    }

    final contentToSave = draft.controller.text;
    if (utf8.encode(contentToSave).length >
        _ChatPageFileViewer._maxEditableFileLength) {
      _setState(() {
        draft.saveErrorMessage = _draftTooLargeSaveMessage;
      });
      onUpdated?.call();
      if (!silent) {
        _showFileOperationSnackBar(_draftTooLargeSaveMessage);
      }
      return;
    }
    draft.cancelAutosave();
    _setState(() {
      draft.isSaving = true;
      draft.saveErrorMessage = null;
    });
    onUpdated?.call();

    final result = await di.sl<WorkspaceFileOperationsService>().writeFile(
      serverScopeKey: fileState.contextKey,
      rootDirectory: fileState.rootDirectory,
      path: normalizedPath,
      content: contentToSave,
    );
    if (!mounted || fileState.editorDraftsByPath[normalizedPath] != draft) {
      return;
    }

    if (!result.ok) {
      final message = _fileOperationErrorLabel(
        result.code,
        message: result.message,
      );
      _setState(() {
        draft.isSaving = false;
        draft.saveErrorMessage = message;
      });
      onUpdated?.call();
      if (!silent && projectProvider.contextKey == fileState.contextKey) {
        _showFileOperationSnackBar(message);
      }
      return;
    }

    final previousTab = fileState.tabsByPath[normalizedPath];
    _setState(() {
      fileState.fileReloadGenerations[normalizedPath] =
          ++fileState.nextFileReloadGeneration;
      draft.isSaving = false;
      draft.markSavedContent(contentToSave);
      fileState.tabsByPath[normalizedPath] = _FileTabViewState(
        status: _FileTabLoadStatus.ready,
        content: contentToSave,
        mimeType: previousTab?.mimeType,
      );
    });
    onUpdated?.call();
    if (draft.isDirty &&
        context.read<SettingsProvider>().editorAutosaveEnabled &&
        (allowInactiveContext ||
            projectProvider.contextKey == fileState.contextKey)) {
      _scheduleEditorAutosave(
        draft: draft,
        onSave: () => unawaited(
          _saveFileEditorDraft(
            fileState: fileState,
            projectProvider: projectProvider,
            path: normalizedPath,
            allowInactiveContext: allowInactiveContext,
            silent: silent,
            onUpdated: onUpdated,
          ),
        ),
      );
    }
    if (!silent &&
        !allowInactiveContext &&
        projectProvider.contextKey == fileState.contextKey) {
      _showFileOperationSnackBar(context.l10n.filesFileSaved);
    }
  }

  String _directoryCacheKey(
    _FileExplorerContextState fileState,
    String directory,
  ) {
    final normalized = _normalizeFilePath(directory);
    return normalized == _normalizeFilePath(fileState.rootDirectory)
        ? _ChatPageState._rootTreeCacheKey
        : normalized;
  }

  String _parentDirectoryForFilePath(String path) {
    final normalized = _normalizeFilePath(path);
    if (normalized.isEmpty || normalized == '/') {
      return '/';
    }
    final index = normalized.lastIndexOf('/');
    if (index <= 0) {
      return '/';
    }
    return normalized.substring(0, index);
  }

  String _absoluteFileTreePath(
    _FileExplorerContextState fileState,
    String path,
  ) {
    final normalized = _normalizeFilePath(path);
    if (normalized.startsWith('/')) {
      return normalized;
    }
    final root = _normalizeFilePath(fileState.rootDirectory);
    if (root.isEmpty || root == '/') {
      return _normalizeFilePath('/$normalized');
    }
    return _normalizeFilePath('$root/$normalized');
  }

  Set<String> _fileTreePathAliases(
    _FileExplorerContextState fileState,
    String path,
  ) {
    final normalized = _normalizeFilePath(path);
    final absolute = _absoluteFileTreePath(fileState, normalized);
    final root = _normalizeFilePath(fileState.rootDirectory);
    return <String>{
      normalized,
      absolute,
      if (root.isNotEmpty && root != '/' && absolute.startsWith('$root/'))
        absolute.substring(root.length + 1),
    };
  }

  bool _hasPendingFileTreeMutation(
    _FileExplorerContextState fileState,
    Iterable<String> paths,
  ) {
    return paths.any(
      (path) => fileState.pendingMutationPaths.any(
        (pendingPath) =>
            _pathEqualsOrIsChild(path, pendingPath) ||
            _pathEqualsOrIsChild(pendingPath, path),
      ),
    );
  }

  bool _isInsidePendingFileTreeMutation(
    _FileExplorerContextState fileState,
    Iterable<String> paths,
  ) {
    return paths.any(
      (path) => fileState.pendingMutationPaths.any(
        (pendingPath) => _pathEqualsOrIsChild(path, pendingPath),
      ),
    );
  }

  String _joinFilePath(String parentDirectory, String name) {
    final parent = _normalizeFilePath(parentDirectory);
    if (parent == '/') {
      return _normalizeFilePath('/$name');
    }
    return _normalizeFilePath('$parent/$name');
  }

  String _requestPathForFileTreeCacheKey({
    required _FileExplorerContextState fileState,
    required String cacheKey,
    required String fallbackDirectory,
  }) {
    if (cacheKey == _ChatPageState._rootTreeCacheKey) {
      return fileState.rootDirectory;
    }
    final normalized = _normalizeFilePath(cacheKey);
    return normalized.isEmpty
        ? _normalizeFilePath(fallbackDirectory)
        : normalized;
  }

  String _siblingFileTreePath(String path, String name) {
    final normalized = _normalizeFilePath(path);
    final separator = normalized.lastIndexOf('/');
    if (separator < 0) {
      return _normalizeFilePath(name);
    }
    if (separator == 0 && normalized.startsWith('/')) {
      return _normalizeFilePath('/$name');
    }
    return _normalizeFilePath('${normalized.substring(0, separator)}/$name');
  }

  void _reconcileRenamedFileTreePath({
    required _FileExplorerContextState fileState,
    required String oldPath,
    required String newPath,
  }) {
    _setState(() {
      for (final path in fileState.fileReloadGenerations.keys.toList()) {
        if (_pathEqualsOrIsChild(path, oldPath) ||
            _pathEqualsOrIsChild(path, newPath)) {
          fileState.fileReloadGenerations[path] =
              ++fileState.nextFileReloadGeneration;
        }
      }
      final renamedTabs = <String, _FileTabViewState>{};
      for (final entry in fileState.tabsByPath.entries) {
        renamedTabs[_replacePathPrefix(entry.key, oldPath, newPath)] =
            entry.value;
      }
      fileState.tabsByPath
        ..clear()
        ..addAll(renamedTabs);
      final renamedDrafts = <String, _FileEditorDraftState>{};
      for (final entry in fileState.editorDraftsByPath.entries) {
        renamedDrafts[_replacePathPrefix(entry.key, oldPath, newPath)] =
            entry.value;
      }
      fileState.editorDraftsByPath
        ..clear()
        ..addAll(renamedDrafts);
      fileState.tabSelection = FileTabSelectionState(
        openPaths: fileState.tabSelection.openPaths
            .map((path) => _replacePathPrefix(path, oldPath, newPath))
            .toList(growable: false),
        activePath: fileState.tabSelection.activePath == null
            ? null
            : _replacePathPrefix(
                fileState.tabSelection.activePath!,
                oldPath,
                newPath,
              ),
      );
      _renamePathKeyedSetMap(fileState.selectedLinesByPath, oldPath, newPath);
      _renamePathKeyedValueMap(
        fileState.lastSelectedLineByPath,
        oldPath,
        newPath,
      );
      _removeDirectorySubtree(fileState, oldPath);
    });
  }

  void _reconcileDeletedFileTreePath({
    required _FileExplorerContextState fileState,
    required String path,
  }) {
    final normalized = _normalizeFilePath(path);
    _setState(() {
      for (final path in fileState.fileReloadGenerations.keys.toList()) {
        if (_pathEqualsOrIsChild(path, normalized)) {
          fileState.fileReloadGenerations[path] =
              ++fileState.nextFileReloadGeneration;
        }
      }
      for (final cacheKey in fileState.directoryChildren.keys.toList()) {
        final children = fileState.directoryChildren[cacheKey]!;
        final remaining = children
            .where(
              (node) => !_pathEqualsOrIsChild(
                _normalizeFilePath(node.path),
                normalized,
              ),
            )
            .toList(growable: false);
        if (remaining.length != children.length) {
          fileState.directoryChildren[cacheKey] = remaining;
        }
      }
      fileState.tabsByPath.removeWhere(
        (path, _) => _pathEqualsOrIsChild(path, normalized),
      );
      final removedDraftPaths = fileState.editorDraftsByPath.keys
          .where((path) => _pathEqualsOrIsChild(path, normalized))
          .toList(growable: false);
      for (final path in removedDraftPaths) {
        fileState.removeEditorDraft(path);
      }
      final nextOpenPaths = fileState.tabSelection.openPaths
          .where((path) => !_pathEqualsOrIsChild(path, normalized))
          .toList(growable: false);
      final currentActive = fileState.tabSelection.activePath;
      fileState.tabSelection = FileTabSelectionState(
        openPaths: nextOpenPaths,
        activePath:
            currentActive != null &&
                !_pathEqualsOrIsChild(currentActive, normalized)
            ? currentActive
            : nextOpenPaths.lastOrNull,
      );
      fileState.selectedLinesByPath.removeWhere(
        (path, _) => _pathEqualsOrIsChild(path, normalized),
      );
      fileState.lastSelectedLineByPath.removeWhere(
        (path, _) => _pathEqualsOrIsChild(path, normalized),
      );
      if (currentActive != fileState.tabSelection.activePath) {
        fileState.pendingScrollToLine = null;
      }
      _removeDirectorySubtree(fileState, normalized);
    });
  }

  String _replacePathPrefix(String path, String oldPath, String newPath) {
    final normalized = _normalizeFilePath(path);
    final oldNormalized = _normalizeFilePath(oldPath);
    final newNormalized = _normalizeFilePath(newPath);
    if (normalized == oldNormalized) {
      return newNormalized;
    }
    if (normalized.startsWith('$oldNormalized/')) {
      return _normalizeFilePath(
        '$newNormalized/${normalized.substring(oldNormalized.length + 1)}',
      );
    }
    return normalized;
  }

  bool _pathEqualsOrIsChild(String path, String parent) {
    final normalizedPath = _normalizeFilePath(path);
    final normalizedParent = _normalizeFilePath(parent);
    return normalizedPath == normalizedParent ||
        normalizedPath.startsWith('$normalizedParent/');
  }

  void _renamePathKeyedSetMap(
    Map<String, Set<int>> map,
    String oldPath,
    String newPath,
  ) {
    final entries = Map<String, Set<int>>.from(map);
    map.clear();
    for (final entry in entries.entries) {
      map[_replacePathPrefix(entry.key, oldPath, newPath)] = entry.value;
    }
  }

  void _renamePathKeyedValueMap(
    Map<String, int> map,
    String oldPath,
    String newPath,
  ) {
    final entries = Map<String, int>.from(map);
    map.clear();
    for (final entry in entries.entries) {
      map[_replacePathPrefix(entry.key, oldPath, newPath)] = entry.value;
    }
  }

  void _removeDirectorySubtree(
    _FileExplorerContextState fileState,
    String path,
  ) {
    final normalized = _normalizeFilePath(path);
    fileState.directoryChildren.removeWhere(
      (key, _) =>
          key != _ChatPageState._rootTreeCacheKey &&
          _pathEqualsOrIsChild(key, normalized),
    );
    fileState.directoryErrors.removeWhere(
      (key, _) => _pathEqualsOrIsChild(key, normalized),
    );
    fileState.loadingDirectories.removeWhere(
      (key) => _pathEqualsOrIsChild(key, normalized),
    );
    fileState.expandedDirectories.removeWhere(
      (key) => _pathEqualsOrIsChild(key, normalized),
    );
  }

  String _fileOperationErrorLabel(
    WorkspaceFileOperationCode code, {
    String? message,
  }) {
    final detailedMessage = message?.trim();
    if ((code == WorkspaceFileOperationCode.failed ||
            code == WorkspaceFileOperationCode.malformedResponse) &&
        detailedMessage != null &&
        detailedMessage.isNotEmpty &&
        detailedMessage != _defaultFileOperationErrorMessage(code)) {
      return detailedMessage;
    }
    switch (code) {
      case WorkspaceFileOperationCode.invalidName:
        return context.l10n.filesInvalidName;
      case WorkspaceFileOperationCode.outsideRoot:
        return context.l10n.filesOutsideRoot;
      case WorkspaceFileOperationCode.rootDeleteBlocked:
        return context.l10n.filesRootDeleteBlocked;
      case WorkspaceFileOperationCode.missing:
        return context.l10n.filesPathMissing;
      case WorkspaceFileOperationCode.alreadyExists:
        return context.l10n.filesAlreadyExists;
      case WorkspaceFileOperationCode.permissionDenied:
        return context.l10n.filesPermissionDenied;
      case WorkspaceFileOperationCode.unavailable:
        return context.l10n.filesOperationUnavailable;
      case WorkspaceFileOperationCode.notDirectory:
      case WorkspaceFileOperationCode.failed:
      case WorkspaceFileOperationCode.malformedResponse:
      case WorkspaceFileOperationCode.ok:
        return context.l10n.filesOperationFailed;
    }
  }

  String _defaultFileOperationErrorMessage(WorkspaceFileOperationCode code) {
    switch (code) {
      case WorkspaceFileOperationCode.failed:
        return 'File operation failed.';
      case WorkspaceFileOperationCode.malformedResponse:
        return 'File operation returned an invalid response.';
      case WorkspaceFileOperationCode.ok:
      case WorkspaceFileOperationCode.unavailable:
      case WorkspaceFileOperationCode.invalidName:
      case WorkspaceFileOperationCode.outsideRoot:
      case WorkspaceFileOperationCode.rootDeleteBlocked:
      case WorkspaceFileOperationCode.missing:
      case WorkspaceFileOperationCode.alreadyExists:
      case WorkspaceFileOperationCode.permissionDenied:
      case WorkspaceFileOperationCode.notDirectory:
        return '';
    }
  }

  void _showFileOperationSnackBar(String message) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  List<Widget> _buildFileTreeChildren({
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    required bool dialogFullscreen,
    VoidCallback? onStateChanged,
    required String parentCacheKey,
    required int depth,
  }) {
    final nodes =
        fileState.directoryChildren[parentCacheKey] ?? const <FileNode>[];
    final rows = <Widget>[];
    for (final node in nodes) {
      final isExpanded = fileState.expandedDirectories.contains(node.path);
      final isLoading = fileState.loadingDirectories.contains(node.path);
      final errorMessage = fileState.directoryErrors[node.path];
      final isActiveFile = fileState.tabSelection.activePath == node.path;
      rows.add(
        FileTreeContextMenuRegion(
          actions: _fileTreeActionsForNode(fileState: fileState, node: node),
          onSelected: (action) {
            unawaited(
              _handleFileTreeAction(
                action: action,
                fileState: fileState,
                projectProvider: projectProvider,
                node: node,
                parentCacheKey: parentCacheKey,
                onUpdated: onStateChanged,
              ),
            );
          },
          child: InkWell(
            key: ValueKey<String>(
              'file_tree_item_${_normalizeFilePath(node.path)}',
            ),
            onTap: () {
              if (node.isDirectory) {
                if (isExpanded) {
                  _setState(() {
                    fileState.expandedDirectories.remove(node.path);
                  });
                  return;
                }
                _setState(() {
                  fileState.expandedDirectories.add(node.path);
                });
                unawaited(
                  _loadDirectoryNodes(
                    state: fileState,
                    projectProvider: projectProvider,
                    cacheKey: node.path,
                    requestPath: node.path,
                  ),
                );
                return;
              }
              unawaited(
                _openFileAndFocusDialog(
                  fileState: fileState,
                  projectProvider: projectProvider,
                  path: node.path,
                  dialogFullscreen: dialogFullscreen,
                  onUpdated: onStateChanged,
                ),
              );
            },
            child: Container(
              color: isActiveFile
                  ? Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.12)
                  : null,
              padding: EdgeInsets.fromLTRB(8 + (depth * 14), 6, 8, 6),
              child: Row(
                children: [
                  if (node.isDirectory)
                    Icon(
                      isExpanded ? Symbols.expand_more : Symbols.chevron_right,
                      size: 16,
                    )
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 2),
                  Icon(
                    _fileIconForNode(node),
                    size: 16,
                    color: node.isDirectory
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      node.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (isLoading)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.6),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      if (node.isDirectory && isExpanded) {
        if (isLoading) {
          rows.addAll(
            _buildFileTreeLoadingRows(
              depth: depth + 1,
              cacheKey: node.path,
              rowCount: 2,
            ),
          );
        } else {
          if (errorMessage != null) {
            rows.add(
              _buildFileTreeErrorRow(
                fileState: fileState,
                projectProvider: projectProvider,
                cacheKey: node.path,
                requestPath: node.path,
                message: errorMessage,
                depth: depth + 1,
              ),
            );
          }
          rows.addAll(
            _buildFileTreeChildren(
              fileState: fileState,
              projectProvider: projectProvider,
              dialogFullscreen: dialogFullscreen,
              onStateChanged: onStateChanged,
              parentCacheKey: node.path,
              depth: depth + 1,
            ),
          );
        }
      }
    }
    return rows;
  }

  List<Widget> _buildFileTreeLoadingRows({
    required int depth,
    required String cacheKey,
    required int rowCount,
  }) {
    return <Widget>[
      Padding(
        key: ValueKey<String>('file_tree_loading_$cacheKey'),
        padding: EdgeInsetsDirectional.only(
          start: 8 + (depth * 14),
          end: 8,
          top: 4,
          bottom: 2,
        ),
        child: const LinearProgressIndicator(minHeight: 2),
      ),
      for (var index = 0; index < rowCount; index += 1)
        _buildFileTreeSkeletonRow(
          depth: depth,
          cacheKey: cacheKey,
          index: index,
        ),
    ];
  }

  Widget _buildFileTreeSkeletonRow({
    required int depth,
    required String cacheKey,
    required int index,
  }) {
    final density = _settingsProvider?.appDensity ?? AppDensity.normal;
    final gap = AppDensitySpacing.itemGap(density);
    final smallGap = AppDensitySpacing.smallGap(density) + 2;
    final lineHeight = density == AppDensity.extraDense ? 7.0 : 8.0;
    final color = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.18);

    return Padding(
      key: ValueKey<String>('file_tree_skeleton_${cacheKey}_$index'),
      padding: EdgeInsetsDirectional.only(
        start: 8 + (depth * 14),
        end: 8,
        top: smallGap + 2,
        bottom: smallGap + 2,
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(width: gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: index.isEven ? 0.74 : 0.58,
                  child: Container(
                    height: lineHeight,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(lineHeight),
                    ),
                  ),
                ),
                SizedBox(height: smallGap + 2),
                FractionallySizedBox(
                  widthFactor: index.isEven ? 0.42 : 0.34,
                  child: Container(
                    height: lineHeight,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(lineHeight),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileTreeErrorRow({
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    required String cacheKey,
    required String requestPath,
    required String message,
    required int depth,
  }) {
    final density = _settingsProvider?.appDensity ?? AppDensity.normal;
    final gap = AppDensitySpacing.itemGap(density);

    return Padding(
      key: ValueKey<String>('file_tree_error_$cacheKey'),
      padding: EdgeInsetsDirectional.only(
        start: 8 + (depth * 14),
        end: 8,
        top: gap,
        bottom: gap,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Symbols.error,
            size: 16,
            color: Theme.of(context).colorScheme.error,
          ),
          SizedBox(width: gap),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            key: ValueKey<String>('file_tree_retry_$cacheKey'),
            style: TextButton.styleFrom(
              visualDensity: Theme.of(context).visualDensity,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              if (cacheKey == _ChatPageState._rootTreeCacheKey) {
                unawaited(
                  _loadRootDirectoryNodes(
                    state: fileState,
                    projectProvider: projectProvider,
                    force: true,
                  ),
                );
                return;
              }
              unawaited(
                _loadDirectoryNodes(
                  state: fileState,
                  projectProvider: projectProvider,
                  cacheKey: cacheKey,
                  requestPath: requestPath,
                  force: true,
                ),
              );
            },
            child: Text(context.l10n.chatRetry),
          ),
        ],
      ),
    );
  }

  IconData _fileIconForNode(FileNode node) {
    if (node.isDirectory) {
      return _directoryIconForPath(node.path);
    }
    return _fileIconForPath(node.path);
  }

  IconData _directoryIconForPath(String path) {
    final normalizedPath = _normalizeFilePath(path).toLowerCase();
    if (normalizedPath.endsWith('/.github/workflows')) {
      return SimpleIcons.githubactions;
    }
    final folderName = fileBasename(normalizedPath);
    switch (folderName) {
      case '.github':
        return SimpleIcons.github;
      case '.vscode':
        return SimpleIcons.vscodium;
      case '.idea':
        return SimpleIcons.jetbrains;
      case '.dart_tool':
        return SimpleIcons.dart;
      case '.vite':
        return SimpleIcons.vite;
      case '.husky':
        return SimpleIcons.git;
      case 'android':
        return SimpleIcons.android;
      case 'ios':
        return SimpleIcons.ios;
      case 'macos':
        return SimpleIcons.macos;
      case 'linux':
        return SimpleIcons.linux;
      case '.git':
        return SimpleIcons.git;
      case '.gradle':
        return SimpleIcons.gradle;
      case '.firebase':
        return SimpleIcons.firebase;
      case 'node_modules':
        return SimpleIcons.nodedotjs;
      case 'docker':
        return SimpleIcons.docker;
      case 'scripts':
        return SimpleIcons.iterm2;
      case 'k8s':
      case 'kubernetes':
        return SimpleIcons.kubernetes;
      case 'infra':
      case 'infrastructure':
      case 'terraform':
      case '.terraform':
        return SimpleIcons.terraform;
      case '.next':
        return SimpleIcons.nextdotjs;
      case 'venv':
      case '.venv':
        return SimpleIcons.python;
      default:
        return Symbols.folder;
    }
  }

  IconData _fileIconForPath(String path) {
    final normalizedPath = path.trim().replaceAll('\\', '/').toLowerCase();
    final fileName = fileBasename(normalizedPath);
    final extension = _fileExtension(fileName);

    // Prefer filename-based mappings for canonical config/build files.
    switch (fileName) {
      case 'package.json':
      case 'package-lock.json':
      case 'npm-shrinkwrap.json':
      case '.npmrc':
        return SimpleIcons.npm;
      case 'pnpm-lock.yaml':
      case 'pnpm-lock.yml':
      case '.pnpmfile.cjs':
        return SimpleIcons.pnpm;
      case 'yarn.lock':
      case '.yarnrc':
      case '.yarnrc.yml':
        return SimpleIcons.yarn;
      case 'bun.lockb':
      case 'bunfig.toml':
        return SimpleIcons.bun;
      case 'dockerfile':
      case '.dockerignore':
      case 'docker-compose.yml':
      case 'docker-compose.yaml':
      case 'compose.yml':
      case 'compose.yaml':
        return SimpleIcons.docker;
      case '.gitignore':
      case '.gitattributes':
      case '.gitmodules':
        return SimpleIcons.git;
      case 'readme.md':
      case 'changelog.md':
      case 'contributing.md':
      case 'license':
      case 'license.md':
        return SimpleIcons.markdown;
      case 'pubspec.yaml':
      case 'pubspec.lock':
      case 'analysis_options.yaml':
        return SimpleIcons.flutter;
      case 'tsconfig.json':
      case 'tsconfig.base.json':
        return SimpleIcons.typescript;
      case 'vite.config.ts':
      case 'vite.config.js':
      case 'vite.config.mjs':
      case 'vite.config.cjs':
      case 'vite.config.mts':
      case 'vite.config.cts':
      case 'vite-env.d.ts':
      case 'vite.svg':
      case 'vitest.config.ts':
      case 'vitest.config.js':
      case 'vitest.config.mjs':
      case 'vitest.config.cjs':
      case 'vitest.config.mts':
      case 'vitest.config.cts':
        return SimpleIcons.vite;
      case 'next.config.ts':
      case 'next.config.js':
      case 'next.config.mjs':
      case 'next.config.cjs':
        return SimpleIcons.nextdotjs;
      case 'webpack.config.ts':
      case 'webpack.config.js':
      case 'webpack.config.mjs':
      case 'webpack.config.cjs':
        return SimpleIcons.webpack;
      case 'rollup.config.ts':
      case 'rollup.config.js':
      case 'rollup.config.mjs':
      case 'rollup.config.cjs':
        return SimpleIcons.rollupdotjs;
      case '.eslintrc':
      case '.eslintrc.js':
      case '.eslintrc.cjs':
      case '.eslintrc.json':
      case '.eslintrc.yml':
      case '.eslintrc.yaml':
      case 'eslint.config.js':
      case 'eslint.config.mjs':
      case 'eslint.config.cjs':
      case 'eslint.config.ts':
        return SimpleIcons.eslint;
      case '.prettierrc':
      case '.prettierrc.js':
      case '.prettierrc.cjs':
      case '.prettierrc.json':
      case '.prettierrc.yml':
      case '.prettierrc.yaml':
      case 'prettier.config.js':
      case 'prettier.config.mjs':
      case 'prettier.config.cjs':
      case 'prettier.config.ts':
        return SimpleIcons.prettier;
      case 'tailwind.config.js':
      case 'tailwind.config.mjs':
      case 'tailwind.config.cjs':
      case 'tailwind.config.ts':
        return SimpleIcons.tailwindcss;
      case 'firebase.json':
      case '.firebaserc':
        return SimpleIcons.firebase;
      case 'go.mod':
      case 'go.sum':
        return SimpleIcons.go;
      case 'cargo.toml':
      case 'cargo.lock':
        return SimpleIcons.rust;
      case 'composer.json':
      case 'composer.lock':
        return SimpleIcons.php;
      case 'requirements.txt':
      case 'pyproject.toml':
        return SimpleIcons.python;
      case 'gemfile':
      case 'gemfile.lock':
        return SimpleIcons.ruby;
      case '.nvmrc':
      case 'nodemon.json':
        return SimpleIcons.nodedotjs;
      case 'jenkinsfile':
      case 'jenkins.yaml':
      case 'jenkins.yml':
        return SimpleIcons.jenkins;
      case 'makefile':
        return Symbols.build;
      case '.bashrc':
      case '.bash_profile':
      case '.bash_aliases':
      case '.zshrc':
      case '.zprofile':
      case '.zshenv':
      case '.profile':
        return SimpleIcons.iterm2;
      case 'id_rsa':
      case 'id_rsa.pub':
      case 'id_dsa':
      case 'id_dsa.pub':
      case 'id_ecdsa':
      case 'id_ecdsa.pub':
      case 'id_ed25519':
      case 'id_ed25519.pub':
        return SimpleIcons.passbolt;
      case '.env':
      case '.env.local':
      case '.env.development':
      case '.env.production':
        return SimpleIcons.dotenv;
    }

    // Then apply extension-based mappings.
    switch (extension) {
      case 'dart':
        return SimpleIcons.dart;
      case 'ts':
      case 'mts':
      case 'cts':
        return SimpleIcons.typescript;
      case 'tsx':
      case 'jsx':
        return SimpleIcons.react;
      case 'js':
      case 'mjs':
      case 'cjs':
        return SimpleIcons.javascript;
      case 'vue':
        return SimpleIcons.vuedotjs;
      case 'html':
      case 'htm':
        return SimpleIcons.html5;
      case 'css':
        return SimpleIcons.css;
      case 'scss':
      case 'sass':
        return SimpleIcons.sass;
      case 'less':
        return SimpleIcons.less;
      case 'styl':
      case 'stylus':
        return SimpleIcons.stylus;
      case 'md':
      case 'mdx':
      case 'rst':
        return SimpleIcons.markdown;
      case 'txt':
        return Symbols.article;
      case 'json':
        return SimpleIcons.json;
      case 'yaml':
      case 'yml':
        return SimpleIcons.yaml;
      case 'toml':
        return SimpleIcons.toml;
      case 'py':
        return SimpleIcons.python;
      case 'go':
        return SimpleIcons.go;
      case 'rs':
        return SimpleIcons.rust;
      case 'java':
        return SimpleIcons.openjdk;
      case 'kt':
      case 'kts':
        return SimpleIcons.kotlin;
      case 'swift':
        return SimpleIcons.swift;
      case 'php':
        return SimpleIcons.php;
      case 'rb':
        return SimpleIcons.ruby;
      case 'lua':
        return SimpleIcons.lua;
      case 'sh':
      case 'ash':
      case 'bash':
      case 'zsh':
        return SimpleIcons.iterm2;
      case 'csv':
        return Symbols.table_chart;
      case 'tsv':
        return Symbols.table_rows;
      case 'sql':
        return SimpleIcons.postgresql;
      case 'pem':
      case 'key':
      case 'crt':
      case 'cer':
      case 'p12':
      case 'pfx':
        return SimpleIcons.passbolt;
      case 'sqlite':
      case 'db':
        return SimpleIcons.sqlite;
      case 'mysql':
        return SimpleIcons.mysql;
      case 'redis':
        return SimpleIcons.redis;
      case 'xml':
      case 'ini':
      case 'cfg':
      case 'conf':
      case 'properties':
        return Symbols.data_object_rounded;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'webp':
      case 'bmp':
      case 'tif':
      case 'tiff':
      case 'avif':
      case 'ico':
        return SimpleIcons.googlephotos;
      case 'svg':
        return SimpleIcons.svg;
      case 'svgz':
        return SimpleIcons.inkscape;
      case 'pdf':
        return Symbols.picture_as_pdf;
      default:
        return Symbols.insert_drive_file;
    }
  }

  String _fileExtension(String fileName) {
    final separator = fileName.lastIndexOf('.');
    if (separator <= 0 || separator == fileName.length - 1) {
      return '';
    }
    return fileName.substring(separator + 1);
  }
}

class _FileNameDialog extends StatefulWidget {
  const _FileNameDialog({
    required this.title,
    required this.actionLabel,
    this.initialName = '',
  });

  final String title;
  final String actionLabel;
  final String initialName;

  @override
  State<_FileNameDialog> createState() => _FileNameDialogState();
}

class _FileNameDialogState extends State<_FileNameDialog> {
  late final TextEditingController _controller;
  var _submitted = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (_submitted || value.isEmpty) {
      return;
    }
    _submitted = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return ModalPrimaryActionShortcuts(
      onPrimaryAction: _submit,
      child: AlertDialog(
        title: Text(widget.title),
        content: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: context.l10n.filesNameHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(onPressed: _submit, child: Text(widget.actionLabel)),
        ],
      ),
    );
  }
}
