part of '../chat_page.dart';

extension _ChatPageWorkspaceController on _ChatPageState {
  Future<void> _runProjectScopeTransition(
    Future<void> Function() operation,
  ) async {
    // Review R3: flush a still-debounced composer draft before any
    // project/directory scope switch, so the outgoing draft cannot be
    // stranded inside the desktop debounce window (idempotent).
    _flushPendingComposerDraftPersistence();
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
    final projectProvider = context.read<ProjectProvider>();
    final chatProvider = context.read<ChatProvider>();
    // Capture target before transition to avoid stale reads.
    final targetProject = projectProvider.projects.where((p) => p.id == projectId).firstOrNull;
    if (targetProject == null) return;
    if (!projectProvider.openProjectIds.contains(projectId)) return;
    if (!projectProvider.canCloseProject(projectId)) {
      if (mounted) {
        final error = projectProvider.error;
        if (error != null && error.trim().isNotEmpty) {
          _showChatPageMessageSnackBar(error, hideCurrent: false);
        } else {
          _showChatPageMessageSnackBar(
            L10nBridge.current?.projectProviderErrorAtLeastOneContext ?? 'At least one context must remain open',
            hideCurrent: false,
          );
        }
      }
      return;
    }
    final targetServerId = chatProvider.activeServerId;

    await _runProjectScopeTransition(() async {
      final pp = context.read<ProjectProvider>();
      final cp = context.read<ChatProvider>();
      // Re-resolve under lock.
      final currentProject = pp.projects.where((p) => p.id == projectId).firstOrNull;
      if (currentProject == null || !pp.openProjectIds.contains(projectId)) {
        return;
      }
      if (!pp.canCloseProject(projectId)) {
        if (mounted) {
          final error = pp.error;
          if (error != null && error.trim().isNotEmpty) {
            _showChatPageMessageSnackBar(error, hideCurrent: false);
          }
        }
        return;
      }
      final wasActive = pp.currentProject?.id == projectId;
      final trimmedPath = currentProject.path.trim();
      final directory = (trimmedPath.isEmpty || trimmedPath == '/' || trimmedPath == '-')
          ? currentProject.id
          : (normalizeOptionalFilePath(trimmedPath) ?? currentProject.id);
      final serverId = targetServerId;

      // Pre-clean: remove tabs for the target directory before closing, so closing does not leave orphans.
      if (serverId.isNotEmpty) {
        try {
          await cp.removeSessionTabsForDirectory(directory, serverId: serverId);
        } catch (error, stackTrace) {
          AppLogger.warn('Close project pre-cleanup failed for $directory', error: error, stackTrace: stackTrace);
        }
      }

      final changed = await pp.closeProject(projectId);
      if (!changed) {
        if (mounted) {
          final error = pp.error;
          if (error != null && error.trim().isNotEmpty) {
            _showChatPageMessageSnackBar(error, hideCurrent: false);
          }
        }
        return;
      }

      if (wasActive) {
        try {
          await cp.onProjectScopeChanged(waitForRevalidation: false);
        } catch (error, stackTrace) {
          AppLogger.warn('Close project scope refresh failed', error: error, stackTrace: stackTrace);
        }
      }

      // Final sweep: ensure tabs do not reappear via _storeCurrentContextSnapshot race.
      if (serverId.isNotEmpty) {
        try {
          await cp.removeSessionTabsForDirectory(directory, serverId: serverId);
        } catch (error, stackTrace) {
          AppLogger.warn('Close project final cleanup failed for $directory', error: error, stackTrace: stackTrace);
          if (mounted) {
            _showChatPageMessageSnackBar(
              'Failed to clean up tabs for closed project',
              hideCurrent: false,
            );
          }
        }
      }
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
      await chatProvider.removeSessionTabsForDirectory(
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
      L10nBridge.current?.workspaceProjectRemovedFromHistory ??
          'Project removed from history',
      hideCurrent: false,
    );
  }

  Future<void> _createWorkspace() async {
    if (_isProjectSelectorActionInFlight) return;
    final projectProvider = context.read<ProjectProvider>();
    final appProvider = context.read<AppProvider>();
    final serverId = appProvider.activeServerId;
    final defaultDirectory =
        projectProvider.currentDirectory ??
        appProvider.appInfo?.path.data ??
        '/';
    final selectedDirectory = await showDialog<String>(
      context: context,
      builder: (_) => _ProjectOpenDialog(
        initialDirectory: defaultDirectory,
        onCloseProject: _closeProjectFromSelector,
        onArchiveProject: _archiveClosedProjectFromSelector,
        onSearch: (query) async {
          if (appProvider.activeServerId != serverId) return const [];
          final root = _directorySuggestionSearchRoot(query, defaultDirectory);
          final normalized = normalizeFilePath(query);
          if (query.endsWith('/') || query.endsWith('\\')) {
            final directories = await projectProvider.listDirectories(normalized);
            if (directories == null) throw StateError('Directory listing unavailable');
            return directories.map((path) => FileNode(path: path, name: fileBasename(path), type: FileNodeType.directory)).toList();
          }
          final remoteQuery = _directorySuggestionSearchQuery(query);
          if (remoteQuery.length < 2) return const [];
          final matches = await projectProvider.findFiles(query: remoteQuery, directory: root, limit: 50, type: 'directory', updateProviderError: false);
          if (matches == null) throw StateError('Directory search unavailable');
          return matches.where((node) => node.isDirectory).toList();
        },
      ),
    );
    if (!mounted || selectedDirectory == null || appProvider.activeServerId != serverId) {
      return;
    }

    final requestedDirectory = normalizeFilePath(selectedDirectory);
    if (requestedDirectory.isEmpty) {
      return;
    }

    final known = projectProvider.projects.where((project) => areEquivalentFilePaths(project.path, requestedDirectory)).firstOrNull;
    await _runProjectSelectorDialogAction(() async {
      if (known == null) {
        await _switchDirectoryContext(requestedDirectory);
      } else if (projectProvider.openProjectIds.contains(known.id)) {
        await _switchProjectContext(known.id);
      } else {
        await _reopenProjectContext(known.id);
      }
    });
    if (!mounted) {
      return;
    }
    final openedDirectory = projectProvider.currentDirectory;
    if (openedDirectory == requestedDirectory) {
      _showChatPageMessageSnackBar(
        L10nBridge.current?.workspaceProjectContextOpened(
              requestedDirectory,
            ) ??
            'Project context opened: $requestedDirectory',
        hideCurrent: false,
      );
      return;
    }
    _showChatPageMessageSnackBar(
      projectProvider.error ??
          (L10nBridge.current?.workspaceFailedToOpenProjectContext(
                requestedDirectory,
              ) ??
              'Failed to open project context: $requestedDirectory'),
      hideCurrent: false,
    );
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

}
