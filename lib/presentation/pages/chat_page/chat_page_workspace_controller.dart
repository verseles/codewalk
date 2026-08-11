part of '../chat_page.dart';

extension _ChatPageWorkspaceController on _ChatPageState {
  Future<void> _runProjectScopeTransition(
    Future<void> Function() operation,
  ) async {
    while (true) {
      final inFlight = _projectScopeTransitionTask;
      if (inFlight == null) {
        break;
      }
      await inFlight;
    }
    if (!mounted) {
      return;
    }

    final permissionContextGeneration =
        ++_backgroundPermissionContextGeneration;
    final permissionMutationGeneration =
        ++_backgroundPermissionContextMutationGeneration;
    _backgroundPermissionContextClearPendingGeneration =
        permissionContextGeneration;
    _backgroundPermissionAutoApproveContextSignature = null;
    Future<void>? permissionContextClear;

    final completion = Completer<void>();
    _projectScopeTransitionTask = completion.future;
    final transitionGeneration = ++_projectScopeTransitionGeneration;
    _projectScopeLoadingOverlayTimer?.cancel();

    Object? pendingError;
    StackTrace? pendingStackTrace;

    _setState(() {
      _isProjectScopeTransitioning = true;
      _showProjectScopeLoadingOverlay = false;
    });
    final overlayTimer = Timer(
      _ChatPageState._projectScopeLoadingOverlayDelay,
      () {
        if (!mounted ||
            transitionGeneration != _projectScopeTransitionGeneration) {
          return;
        }
        _setState(() {
          if (_isProjectScopeTransitioning &&
              transitionGeneration == _projectScopeTransitionGeneration) {
            _showProjectScopeLoadingOverlay = true;
          }
        });
      },
    );
    _projectScopeLoadingOverlayTimer = overlayTimer;

    try {
      await _disableBackgroundPermissionAutoApproveContext(
        reason: 'project-scope-transition',
        generation: permissionContextGeneration,
        mutationGeneration: permissionMutationGeneration,
      );
      permissionContextClear = _enqueueBackgroundPermissionContextClear(
        reason: 'project-scope-transition',
        expectedGeneration: permissionContextGeneration,
        expectedMutationGeneration: permissionMutationGeneration,
      );
      await operation();
    } catch (error, stackTrace) {
      pendingError = error;
      pendingStackTrace = stackTrace;
    } finally {
      overlayTimer.cancel();
      if (identical(_projectScopeLoadingOverlayTimer, overlayTimer)) {
        _projectScopeLoadingOverlayTimer = null;
      }
      if (_projectScopeTransitionGeneration == transitionGeneration) {
        _projectScopeTransitionGeneration += 1;
      }
      if (mounted) {
        _setState(() {
          _isProjectScopeTransitioning = false;
          _showProjectScopeLoadingOverlay = false;
        });
      }
      if (!completion.isCompleted) {
        completion.complete();
      }
      if (identical(_projectScopeTransitionTask, completion.future)) {
        _projectScopeTransitionTask = null;
      }
    }

    if (permissionContextClear != null) {
      _finishBackgroundPermissionContextTransition(
        generation: permissionContextGeneration,
        mutationGeneration: permissionMutationGeneration,
        clear: permissionContextClear,
        allowRetry: true,
      );
    } else if (permissionContextGeneration ==
        _backgroundPermissionContextGeneration) {
      _backgroundPermissionContextClearPendingGeneration = null;
    }

    if (pendingError != null && pendingStackTrace != null) {
      Error.throwWithStackTrace(pendingError, pendingStackTrace);
    }
  }

  void _finishBackgroundPermissionContextTransition({
    required int generation,
    required int mutationGeneration,
    required Future<void> clear,
    required bool allowRetry,
  }) {
    final completion = clear.then((_) async {
      if (!mounted || generation != _backgroundPermissionContextGeneration) {
        return;
      }
      _backgroundPermissionContextClearPendingGeneration = null;
      if (mutationGeneration !=
          _backgroundPermissionContextMutationGeneration) {
        return;
      }
      await _syncBackgroundPermissionAutoApproveContext(
        reason: allowRetry
            ? 'project-scope-transition-complete'
            : 'project-scope-transition-retry-complete',
      );
    });
    final queued = completion.catchError((Object error, StackTrace stackTrace) {
      if (generation == _backgroundPermissionContextGeneration) {
        if (mutationGeneration !=
            _backgroundPermissionContextMutationGeneration) {
          _backgroundPermissionContextClearPendingGeneration = null;
        } else {
          _backgroundPermissionAutoApproveContextSignature = null;
          if (allowRetry && mounted) {
            _finishBackgroundPermissionContextTransition(
              generation: generation,
              mutationGeneration: mutationGeneration,
              clear: _enqueueBackgroundPermissionContextClear(
                reason: 'project-scope-transition-retry',
                expectedGeneration: generation,
                expectedMutationGeneration: mutationGeneration,
              ),
              allowRetry: false,
            );
          } else if (!allowRetry) {
            _backgroundPermissionContextClearPendingGeneration = null;
          }
        }
      }
      AppLogger.warn(
        allowRetry
            ? 'Retrying background auto-approve context transition'
            : 'Project transition kept background auto-approve fail-closed',
        error: error,
        stackTrace: stackTrace,
      );
    });
    unawaited(queued);
  }

  Future<void> _switchProjectContext(String projectId) async {
    final projectProvider = context.read<ProjectProvider>();
    if (projectProvider.currentProject?.id == projectId) {
      return;
    }
    final chatProvider = context.read<ChatProvider>();
    await _runProjectScopeTransition(() async {
      final wasOpen = projectProvider.openProjectIds.contains(projectId);
      final changed = await projectProvider.switchProject(projectId);
      if (!changed) {
        return;
      }
      await chatProvider.onProjectScopeChanged(
        waitForRevalidation: false,
        newlyOpenedDirectory: wasOpen ? null : projectProvider.currentDirectory,
      );
    });
  }

  Future<void> _switchDirectoryContext(String directory) async {
    final projectProvider = context.read<ProjectProvider>();
    final normalized = directory.trim();
    if (normalized.isEmpty || projectProvider.currentDirectory == normalized) {
      return;
    }
    final task = AppLogger.beginTask(
      'directory_switch',
      tags: const <String>{'project:switch'},
      context: <String, Object?>{
        if (projectProvider.currentDirectory != null)
          'fromHash': AppLogger.safeContextId(projectProvider.currentDirectory),
        'toHash': AppLogger.safeContextId(normalized),
      },
    );
    final chatProvider = context.read<ChatProvider>();
    try {
      await _runProjectScopeTransition(() async {
        final wasOpen = projectProvider.projects.any(
          (project) =>
              projectProvider.openProjectIds.contains(project.id) &&
              areEquivalentFilePaths(project.path, normalized),
        );
        final switched = await projectProvider.switchToDirectoryContext(
          normalized,
        );
        if (!switched) {
          return;
        }
        await chatProvider.onProjectScopeChanged(
          waitForRevalidation: false,
          newlyOpenedDirectory: wasOpen
              ? null
              : projectProvider.currentDirectory,
        );
      });
      task.end();
    } catch (error, stackTrace) {
      task.end(status: 'error', error: error, stackTrace: stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _closeProjectContext(String projectId) async {
    final chatProvider = context.read<ChatProvider>();
    await _runProjectScopeTransition(() async {
      final projectProvider = context.read<ProjectProvider>();
      final wasActiveProject = projectProvider.currentProject?.id == projectId;
      final changed = await projectProvider.closeProject(projectId);
      if (!changed || !wasActiveProject) {
        return;
      }
      await chatProvider.onProjectScopeChanged(waitForRevalidation: false);
    });
  }

  Future<void> _reopenProjectContext(String projectId) async {
    final projectProvider = context.read<ProjectProvider>();
    final chatProvider = context.read<ChatProvider>();
    await _runProjectScopeTransition(() async {
      final wasOpen = projectProvider.openProjectIds.contains(projectId);
      final changed = await projectProvider.reopenProject(
        projectId,
        makeActive: true,
      );
      if (!changed) {
        return;
      }
      await chatProvider.onProjectScopeChanged(
        waitForRevalidation: false,
        newlyOpenedDirectory: wasOpen ? null : projectProvider.currentDirectory,
      );
    });
  }

  Future<void> _archiveClosedProjectContext(String projectId) async {
    final projectProvider = context.read<ProjectProvider>();
    final chatProvider = context.read<ChatProvider>();
    final project = projectProvider.projects
        .where((candidate) => candidate.id == projectId)
        .firstOrNull;
    final serverId = chatProvider.activeServerId;
    final ok = await projectProvider.archiveClosedProject(projectId);
    if (ok && project != null) {
      await chatProvider.removeSessionTabsForProjectHistory(
        project.path,
        serverId: serverId,
      );
    }
    if (!mounted) {
      return;
    }
    if (!ok) {
      final error = projectProvider.error;
      if (error != null && error.trim().isNotEmpty) {
        _showChatPageMessageSnackBar(error, hideCurrent: false);
      }
      return;
    }
    _showChatPageMessageSnackBar(
      'Project removed from history',
      hideCurrent: false,
    );
  }

  Future<void> _createWorkspace() async {
    final projectProvider = context.read<ProjectProvider>();
    final appProvider = context.read<AppProvider>();
    final defaultDirectory =
        projectProvider.currentDirectory ??
        appProvider.appInfo?.path.data ??
        '/';
    final baseDirectoryController = TextEditingController(
      text: defaultDirectory,
    );
    Timer? suggestionDebounce;
    var suggestionRequestId = 0;
    var loadingSuggestions = false;
    List<FileNode> directorySuggestions = const <FileNode>[];

    final selectedDirectory = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            void scheduleDirectorySuggestions() {
              final rawInput = baseDirectoryController.text.trim();
              suggestionDebounce?.cancel();
              final requestId = ++suggestionRequestId;
              if (rawInput.isEmpty) {
                setDialogState(() {
                  loadingSuggestions = false;
                  directorySuggestions = const <FileNode>[];
                });
                return;
              }

              setDialogState(() {
                loadingSuggestions = true;
                directorySuggestions = const <FileNode>[];
              });

              suggestionDebounce = Timer(
                const Duration(milliseconds: 250),
                () async {
                  final knownSuggestions = _knownProjectDirectorySuggestions(
                    projectProvider: projectProvider,
                    query: rawInput,
                  );
                  final remoteQuery = _directorySuggestionSearchQuery(rawInput);
                  List<FileNode> remoteSuggestions = const <FileNode>[];
                  if (remoteQuery.length >= 2) {
                    final remoteMatches = await projectProvider.findFiles(
                      query: remoteQuery,
                      directory: _directorySuggestionSearchRoot(
                        rawInput,
                        defaultDirectory,
                      ),
                      limit: 10,
                      type: 'directory',
                      updateProviderError: false,
                    );
                    remoteSuggestions =
                        remoteMatches
                            ?.where((item) => item.isDirectory)
                            .toList(growable: false) ??
                        const <FileNode>[];
                  }

                  if (!dialogContext.mounted ||
                      requestId != suggestionRequestId) {
                    return;
                  }

                  setDialogState(() {
                    loadingSuggestions = false;
                    directorySuggestions = _mergeDirectorySuggestions(
                      query: rawInput,
                      knownSuggestions: knownSuggestions,
                      remoteSuggestions: remoteSuggestions,
                    );
                  });
                },
              );
            }

            String selectedDirectoryPreview() {
              final typed = baseDirectoryController.text.trim();
              return typed.isEmpty ? defaultDirectory : typed;
            }

            void setDirectoryText(String value) {
              baseDirectoryController.value = TextEditingValue(
                text: value,
                selection: TextSelection.collapsed(offset: value.length),
              );
            }

            Future<void> browseDirectories() async {
              final picked = await _openDirectoryPicker(
                initialDirectory: selectedDirectoryPreview(),
              );
              if (!dialogContext.mounted || picked == null) {
                return;
              }
              setDirectoryText(picked);
              scheduleDirectorySuggestions();
            }

            void submitSelectedDirectory() {
              final selectedDirectory = selectedDirectoryPreview().trim();
              if (!dialogContext.mounted || selectedDirectory.isEmpty) {
                return;
              }
              Navigator.of(dialogContext).pop(selectedDirectory);
            }

            return ModalPrimaryActionShortcuts(
              onPrimaryAction: submitSelectedDirectory,
              child: AlertDialog(
                title: Text(context.l10n.workspaceOpenProjectFolder),
                content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: const ValueKey<String>(
                              'workspace_open_directory_picker_button',
                            ),
                            onPressed: browseDirectories,
                            icon: const Icon(Symbols.folder_open),
                            label: Text(context.l10n.workspaceBrowseDirs),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          key: const ValueKey<String>(
                            'workspace_selected_directory_preview',
                          ),
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              dialogContext,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.workspaceProjectDirectory,
                                style: Theme.of(
                                  dialogContext,
                                ).textTheme.labelMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                selectedDirectoryPreview(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const ValueKey<String>(
                            'workspace_base_directory_input',
                          ),
                          controller: baseDirectoryController,
                          autofocus: true,
                          onChanged: (_) => scheduleDirectorySuggestions(),
                          decoration: InputDecoration(
                            labelText: context.l10n.workspaceProjectDirectory,
                            hintText: context.l10n.workspaceProjectHint,
                            helperText: context.l10n.workspaceChooseFolderOpen,
                          ),
                        ),
                        if (loadingSuggestions) ...[
                          const SizedBox(height: 8),
                          const LinearProgressIndicator(
                            key: ValueKey<String>(
                              'workspace_directory_suggestions_loading',
                            ),
                          ),
                        ],
                        if (directorySuggestions.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            context.l10n.workspaceSuggestions,
                            style: Theme.of(dialogContext).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 220),
                            child: Material(
                              key: const ValueKey<String>(
                                'workspace_directory_suggestions',
                              ),
                              color: Theme.of(
                                dialogContext,
                              ).colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: directorySuggestions.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final suggestion =
                                      directorySuggestions[index];
                                  return ListTile(
                                    key: ValueKey<String>(
                                      'workspace_directory_suggestion_${suggestion.path}',
                                    ),
                                    dense: true,
                                    leading: const Icon(Symbols.folder),
                                    title: Text(fileBasename(suggestion.path)),
                                    subtitle: Text(
                                      suggestion.path,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () {
                                      setDirectoryText(suggestion.path);
                                      setDialogState(() {
                                        directorySuggestions =
                                            const <FileNode>[];
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(context.l10n.commonCancel),
                  ),
                  FilledButton(
                    onPressed: submitSelectedDirectory,
                    child: Text(context.l10n.workspaceOpenFolder),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    suggestionDebounce?.cancel();
    if (!mounted || selectedDirectory == null) {
      return;
    }

    final requestedDirectory = selectedDirectory.trim();
    if (requestedDirectory.isEmpty) {
      return;
    }

    await _switchDirectoryContext(requestedDirectory);
    if (!mounted) {
      return;
    }
    final openedDirectory = projectProvider.currentDirectory;
    if (openedDirectory == requestedDirectory) {
      _showChatPageMessageSnackBar(
        'Project context opened: $requestedDirectory',
        hideCurrent: false,
      );
      return;
    }
    _showChatPageMessageSnackBar(
      projectProvider.error ??
          'Failed to open project context: $requestedDirectory',
      hideCurrent: false,
    );
  }

  Future<String?> _openDirectoryPicker({
    required String initialDirectory,
  }) async {
    final appProvider = context.read<AppProvider>();
    final startDirectory = initialDirectory.trim().isNotEmpty
        ? initialDirectory.trim()
        : (appProvider.appInfo?.path.data.trim().isNotEmpty ?? false)
        ? appProvider.appInfo!.path.data.trim()
        : '/';

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _DirectoryPickerSheet(initialDirectory: startDirectory),
    );
  }

  List<FileNode> _knownProjectDirectorySuggestions({
    required ProjectProvider projectProvider,
    required String query,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return const <FileNode>[];
    }

    final seenPaths = <String>{};
    final matches =
        projectProvider.projects
            .map((project) {
              final normalizedPath = normalizeFilePath(project.path);
              return FileNode(
                path: normalizedPath,
                name: project.name,
                type: FileNodeType.directory,
              );
            })
            .where((item) {
              final pathLower = item.path.toLowerCase();
              final baseLower = fileBasename(item.path).toLowerCase();
              final nameLower = item.name.toLowerCase();
              return pathLower.contains(normalizedQuery) ||
                  baseLower.contains(normalizedQuery) ||
                  nameLower.contains(normalizedQuery);
            })
            .where((item) => seenPaths.add(item.path))
            .toList(growable: false)
          ..sort((left, right) {
            final byScore = _directorySuggestionScore(
              left,
              normalizedQuery,
            ).compareTo(_directorySuggestionScore(right, normalizedQuery));
            if (byScore != 0) {
              return byScore;
            }
            return left.path.toLowerCase().compareTo(right.path.toLowerCase());
          });

    return matches.take(6).toList(growable: false);
  }

  String _directorySuggestionSearchQuery(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (!trimmed.contains('/')) {
      return trimmed;
    }
    final normalizedPath = normalizeOptionalFilePath(trimmed);
    if (normalizedPath == null) {
      return trimmed;
    }
    final basename = fileBasename(normalizedPath);
    return basename == '/' ? '' : basename;
  }

  String _directorySuggestionSearchRoot(String rawInput, String fallback) {
    final normalizedFallback = normalizeOptionalFilePath(fallback) ?? '/';
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty || !trimmed.contains('/')) {
      return normalizedFallback;
    }
    final normalizedPath = normalizeOptionalFilePath(trimmed);
    if (normalizedPath == null || normalizedPath == '/') {
      return normalizedFallback;
    }
    final separator = normalizedPath.lastIndexOf('/');
    if (separator <= 0) {
      return '/';
    }
    return normalizedPath.substring(0, separator);
  }

  List<FileNode> _mergeDirectorySuggestions({
    required String query,
    required List<FileNode> knownSuggestions,
    required List<FileNode> remoteSuggestions,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final mergedByPath = <String, FileNode>{};

    for (final suggestion in <FileNode>[
      ...knownSuggestions,
      ...remoteSuggestions.where((item) => item.isDirectory),
    ]) {
      final normalizedPath = normalizeFilePath(suggestion.path);
      mergedByPath.putIfAbsent(
        normalizedPath,
        () => FileNode(
          path: normalizedPath,
          name: suggestion.name,
          type: FileNodeType.directory,
        ),
      );
    }

    final merged = mergedByPath.values.toList(growable: false)
      ..sort((left, right) {
        final byScore = _directorySuggestionScore(
          left,
          normalizedQuery,
        ).compareTo(_directorySuggestionScore(right, normalizedQuery));
        if (byScore != 0) {
          return byScore;
        }
        return left.path.toLowerCase().compareTo(right.path.toLowerCase());
      });

    return merged.take(12).toList(growable: false);
  }

  int _directorySuggestionScore(FileNode node, String normalizedQuery) {
    final pathLower = node.path.toLowerCase();
    final baseLower = fileBasename(node.path).toLowerCase();
    final nameLower = node.name.toLowerCase();
    if (baseLower == normalizedQuery || pathLower == normalizedQuery) {
      return 0;
    }
    if (baseLower.startsWith(normalizedQuery) ||
        nameLower.startsWith(normalizedQuery)) {
      return 1;
    }
    if (pathLower.contains(normalizedQuery) ||
        nameLower.contains(normalizedQuery)) {
      return 2;
    }
    return 3;
  }
}
