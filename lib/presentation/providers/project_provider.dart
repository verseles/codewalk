import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/errors/failures.dart';
import '../../core/i18n/l10n_bridge.dart';
import '../../core/logging/app_logger.dart';
import '../../core/utils/path_utils.dart';
import '../../data/datasources/app_local_datasource.dart';
import '../../domain/entities/file_node.dart';
import '../../domain/entities/project.dart';
import '../../domain/entities/worktree.dart';
import '../../domain/repositories/project_repository.dart';

enum ProjectStatus { initial, loading, loaded, error }

class _ProjectStatePersistenceSnapshot {
  const _ProjectStatePersistenceSnapshot({
    required this.serverId,
    required this.currentProjectId,
    required this.openProjectIdsJson,
    required this.archivedProjectIdsJson,
    required this.hiddenProjectPathsJson,
  });

  final String serverId;
  final String? currentProjectId;
  final String openProjectIdsJson;
  final String archivedProjectIdsJson;
  final String hiddenProjectPathsJson;
}

class ProjectProvider extends ChangeNotifier {
  ProjectProvider({
    required ProjectRepository projectRepository,
    required AppLocalDataSource localDataSource,
  }) : _projectRepository = projectRepository,
       _localDataSource = localDataSource;

  final ProjectRepository _projectRepository;
  final AppLocalDataSource _localDataSource;

  ProjectStatus _status = ProjectStatus.initial;
  List<Project> _projects = <Project>[];
  Project? _currentProject;
  List<String> _openProjectIds = <String>[];
  List<String> _archivedProjectIds = <String>[];
  List<String> _hiddenProjectPaths = <String>[];
  List<Worktree> _worktrees = <Worktree>[];
  int _projectContextGeneration = 0;
  int _worktreesRequestId = 0;
  bool _worktreeSupported = false;
  String _activeServerId = 'legacy';
  String? _error;
  Future<void> _projectStatePersistenceQueue = Future<void>.value();
  Timer? _projectStateDebounce;
  int _projectStateDebounceGeneration = 0;
  bool _hasPendingProjectPersist = false;

  ProjectStatus get status => _status;
  List<Project> get projects => List<Project>.unmodifiable(_projects);
  Project? get currentProject => _currentProject;
  String? get error => _error;
  String get currentProjectId => _currentProject?.id ?? 'default';
  String get activeServerId => _activeServerId;
  List<String> get openProjectIds => List<String>.unmodifiable(_openProjectIds);
  List<String> get archivedProjectIds =>
      List<String>.unmodifiable(_archivedProjectIds);
  List<String> get hiddenProjectPaths =>
      List<String>.unmodifiable(_hiddenProjectPaths);
  List<Worktree> get worktrees => List<Worktree>.unmodifiable(_worktrees);
  bool get worktreeSupported => _worktreeSupported;

  String? get currentDirectory {
    final path = normalizeOptionalFilePath(_currentProject?.path);
    if (path == null || path == '/') {
      return null;
    }
    return path;
  }

  String get currentScopeId => currentDirectory ?? currentProjectId;

  String get contextKey => '$_activeServerId::$currentScopeId';

  List<Project> get openProjects {
    final byId = <String, Project>{for (final item in _projects) item.id: item};
    return _openProjectIds
        .map((id) => byId[id])
        .whereType<Project>()
        .toList(growable: false);
  }

  List<Project> get closedProjects {
    final openSet = _openProjectIds.toSet();
    return _projects
        .where((item) => !openSet.contains(item.id))
        .where((item) => !_isProjectHidden(item))
        .toList(growable: false);
  }

  Future<void> initializeProject({
    bool forceReload = false,
    bool preserveOpenContexts = true,
  }) async {
    if (!forceReload &&
        _status == ProjectStatus.loaded &&
        _currentProject != null) {
      return;
    }

    // Flush any pending debounced project state for the current server
    // before switching server or reloading, otherwise the timer could
    // capture the new server's (or partially cleared) state under the
    // wrong key (issue #161).
    if (_hasPendingProjectPersist) {
      await flushProjectStatePersistence();
    }

    _setStatus(ProjectStatus.loading);

    try {
      _activeServerId = await _resolveServerId();
      if (!preserveOpenContexts) {
        _projectContextGeneration += 1;
        _projects = <Project>[];
        _currentProject = null;
        _openProjectIds = <String>[];
        _archivedProjectIds = <String>[];
        _hiddenProjectPaths = <String>[];
        _worktrees = <Worktree>[];
        _worktreesRequestId += 1;
        _worktreeSupported = false;
      }
      await _loadProjects(
        silent: true,
        preserveOpenContexts: preserveOpenContexts,
      );
      await _restoreHiddenProjectPaths();

      final savedProjectId = await _localDataSource.getCurrentProjectId(
        serverId: _activeServerId,
      );
      if (savedProjectId != null &&
          savedProjectId.trim().isNotEmpty &&
          !_isPlaceholderRootId(savedProjectId)) {
        _rehydrateSyntheticProjects(<String>[savedProjectId]);
        _currentProject = _projects
            .where((p) => p.id == savedProjectId)
            .firstOrNull;
      }

      if (_currentProject == null) {
        await _hydrateCurrentProjectFromServer();
      }

      if (_currentProject != null &&
          _isPlaceholderRootProject(_currentProject!) &&
          _projects.any((item) => !_isPlaceholderRootProject(item))) {
        _currentProject = _projects
            .where((item) => !_isPlaceholderRootProject(item))
            .firstOrNull;
      }

      if (_currentProject != null && _isProjectHidden(_currentProject!)) {
        _currentProject = _firstVisibleProject;
      }

      _currentProject ??= _firstVisibleProject ?? _projects.firstOrNull;
      if (_currentProject == null) {
        _setError(
          L10nBridge.current?.projectProviderErrorNoProjectContext ??
              'No project context available from server',
        );
        return;
      }

      await _restoreOpenProjects();
      _ensureOpenProject(_currentProject!.id);
      await _persistProjectState();
      await loadWorktrees(silent: true);

      _setStatus(ProjectStatus.loaded);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to initialize project context',
        error: e,
        stackTrace: stackTrace,
      );
      _setError(
        L10nBridge.current?.projectProviderErrorInitializeFailed(
              '$e',
            ) ??
            'Failed to initialize project context: $e',
      );
    }
  }

  Future<void> onServerScopeChanged() async {
    await initializeProject(forceReload: true, preserveOpenContexts: false);
  }

  Future<void> loadProjects() async {
    _setStatus(ProjectStatus.loading);
    await _loadProjects(silent: false);
    if (_status != ProjectStatus.error) {
      _setStatus(ProjectStatus.loaded);
    }
  }

  Future<bool> switchProject(String projectId) async {
    final previousProjectId = _currentProject?.id;
    return AppLogger.runPerformanceTask<bool>(
      'project_switch',
      () async {
        final target = _projects
            .where((item) => item.id == projectId)
            .firstOrNull;
        if (target == null) {
          _setError(
            L10nBridge.current?.projectProviderErrorSwitchProjectNotFound ??
                'Failed to switch project: project not found',
          );
          return false;
        }
        if (_currentProject?.id == projectId) {
          return false;
        }

        _currentProject = target;
        _ensureOpenProject(projectId);
        notifyListeners();
        unawaited(_enqueueProjectStatePersistence());
        _refreshWorktreesForCurrentContext();
        return true;
      },
      tags: const <String>{'project:switch'},
      contextBuilder: () => <String, Object?>{
        'fromProjectHash': AppLogger.safeContextId(previousProjectId),
        'toProjectHash': AppLogger.safeContextId(projectId),
      },
    );
  }

  Future<bool> switchToDirectoryContext(String directory) async {
    final previousPath = _currentProject?.path;
    return AppLogger.runPerformanceTask<bool>(
      'directory_switch',
      () async {
        final normalized = normalizeOptionalFilePath(directory);
        if (normalized == null) {
          _setError(
            L10nBridge.current?.projectProviderErrorSwitchDirectoryEmpty ??
                'Failed to switch project: directory is empty',
          );
          return false;
        }
        if (areEquivalentFilePaths(_currentProject?.path, normalized)) {
          return false;
        }

        var project = _projects
            .where((item) => areEquivalentFilePaths(item.path, normalized))
            .firstOrNull;
        if (project == null) {
          await _loadProjects(silent: true);
          project = _projects
              .where((item) => areEquivalentFilePaths(item.path, normalized))
              .firstOrNull;
        }

        if (project == null) {
          final fetched = await _projectRepository.getCurrentProject(
            directory: normalized,
          );
          fetched.fold(
            (failure) {
              AppLogger.warn(
                'Failed to fetch project for directory=$normalized',
                error: failure,
              );
            },
            (item) {
              final fetchedPath = item.path;
              if (areEquivalentFilePaths(fetchedPath, normalized)) {
                project = item;
                final existingIndex = _projects.indexWhere(
                  (p) => p.id == item.id,
                );
                if (existingIndex >= 0) {
                  _projects[existingIndex] = item;
                } else {
                  _projects = <Project>[item, ..._projects];
                }
                return;
              }
              AppLogger.info(
                'Ignoring current project response during directory switch: requested=$normalized fetched=$fetchedPath id=${item.id}',
              );
            },
          );
        }

        if (project == null) {
          final synthetic = _buildSyntheticDirectoryProject(normalized);
          final existingSyntheticIndex = _projects.indexWhere(
            (item) => item.id == synthetic.id,
          );
          if (existingSyntheticIndex >= 0) {
            _projects[existingSyntheticIndex] = synthetic;
          } else {
            _projects = <Project>[synthetic, ..._projects];
          }
          project = synthetic;
          AppLogger.info(
            'Created local directory context fallback: $normalized',
          );
        }

        final selectedProject = project!;
        if (_currentProject?.id == selectedProject.id &&
            areEquivalentFilePaths(
              _currentProject?.path,
              selectedProject.path,
            )) {
          return false;
        }

        _currentProject = selectedProject;
        _ensureOpenProject(selectedProject.id);
        notifyListeners();
        unawaited(_enqueueProjectStatePersistence());
        _refreshWorktreesForCurrentContext();
        return true;
      },
      tags: const <String>{'project:directory'},
      contextBuilder: () => <String, Object?>{
        'fromPathHash': AppLogger.safeContextId(previousPath),
        'toPathHash': AppLogger.safeContextId(directory),
      },
    );
  }

  Future<bool> closeProject(String projectId) async {
    if (!_openProjectIds.contains(projectId)) {
      return false;
    }

    if (_openProjectIds.length <= 1 && _currentProject?.id == projectId) {
      _setError(
        L10nBridge.current?.projectProviderErrorAtLeastOneContext ??
            'At least one context must remain open',
      );
      return false;
    }

    _openProjectIds = _openProjectIds
        .where((item) => item != projectId)
        .toList(growable: false);

    if (_currentProject?.id == projectId) {
      Project? fallback;
      for (final openId in _openProjectIds) {
        fallback = _projects.where((item) => item.id == openId).firstOrNull;
        if (fallback != null) {
          break;
        }
      }
      fallback ??= _projects.firstOrNull;
      _currentProject = fallback;
      if (_currentProject != null) {
        _ensureOpenProject(_currentProject!.id);
        _refreshWorktreesForCurrentContext();
      }
    }

    notifyListeners();
    unawaited(_enqueueProjectStatePersistence());
    return true;
  }

  bool canCloseProject(String projectId) {
    if (!_openProjectIds.contains(projectId)) return false;
    if (_openProjectIds.length <= 1 && _currentProject?.id == projectId) {
      return false;
    }
    return true;
  }

  Future<bool> reopenProject(String projectId, {bool makeActive = true}) async {
    final project = _projects.where((item) => item.id == projectId).firstOrNull;
    if (project == null) {
      _setError(
        L10nBridge.current?.projectProviderErrorReopenProjectNotFound ??
            'Failed to reopen project: project not found',
      );
      return false;
    }

    _ensureOpenProject(projectId);
    if (makeActive) {
      _currentProject = project;
      _refreshWorktreesForCurrentContext();
    }

    notifyListeners();
    unawaited(_enqueueProjectStatePersistence());
    return true;
  }

  void _refreshWorktreesForCurrentContext() {
    final expectedContextKey = contextKey;
    unawaited(_refreshWorktreesForContext(expectedContextKey));
  }

  Future<void> _refreshWorktreesForContext(String expectedContextKey) async {
    await loadWorktrees(silent: true);
    if (contextKey != expectedContextKey) {
      return;
    }
    notifyListeners();
  }

  Future<bool> archiveClosedProject(String projectId) async {
    if (_openProjectIds.contains(projectId)) {
      _setError(
        L10nBridge.current?.projectProviderErrorOnlyClosedArchivable ??
            'Only closed projects can be archived',
      );
      return false;
    }
    final project = _projects.where((item) => item.id == projectId).firstOrNull;
    if (project == null) {
      _setError(
        L10nBridge.current?.projectProviderErrorArchiveProjectNotFound ??
            'Failed to archive project: project not found',
      );
      return false;
    }
    if (_isProjectHidden(project)) {
      return false;
    }
    final hiddenPath = normalizeOptionalFilePath(project.path);
    if (hiddenPath == null) {
      _setError(
        L10nBridge.current?.projectProviderErrorArchiveProjectPathInvalid ??
            'Failed to archive project: project path is invalid',
      );
      return false;
    }
    _hiddenProjectPaths = _appendUniqueSortedPath(
      _hiddenProjectPaths,
      hiddenPath,
    );
    _syncArchivedProjectIdsFromHiddenPaths();
    await _persistProjectState();
    notifyListeners();
    return true;
  }

  Future<void> loadWorktrees({bool silent = false}) async {
    final requestId = ++_worktreesRequestId;
    final directory = currentDirectory;
    if (directory == null || directory.trim().isEmpty) {
      if (requestId != _worktreesRequestId) {
        return;
      }
      _worktrees = <Worktree>[];
      _worktreeSupported = false;
      if (!silent) {
        notifyListeners();
      }
      return;
    }

    final result = await _projectRepository.getWorktrees(directory: directory);
    if (requestId != _worktreesRequestId) {
      return;
    }
    result.fold(
      (failure) {
        if (failure is NetworkFailure && failure.code == 404) {
          _worktrees = <Worktree>[];
          _worktreeSupported = false;
          if (!silent) {
            notifyListeners();
          }
          return;
        }
        AppLogger.warn('Failed to load worktrees', error: failure);
        if (!silent) {
          _setError(
            L10nBridge.current?.projectProviderErrorLoadWorkspaces(
                  failure.message,
                ) ??
                'Failed to load workspaces: ${failure.message}',
          );
        }
      },
      (worktrees) {
        _worktrees = worktrees;
        _worktreeSupported = true;
        if (!silent) {
          notifyListeners();
        }
      },
    );
  }

  Future<Worktree?> createWorktree(
    String name, {
    bool switchToCreated = true,
    String? directory,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      _setError(
        L10nBridge.current?.projectProviderErrorWorkspaceNameEmpty ??
            'Workspace name cannot be empty',
      );
      return null;
    }

    final targetDirectory = directory?.trim();
    final requestDirectory =
        (targetDirectory == null || targetDirectory.isEmpty)
        ? currentDirectory
        : targetDirectory;
    AppLogger.info(
      'Workspace create start name=$trimmed directory=${requestDirectory ?? "-"}',
    );

    final result = await _projectRepository.createWorktree(
      trimmed,
      directory: requestDirectory,
    );

    return result.fold(
      (failure) {
        if (failure is NetworkFailure && failure.code == 404) {
          AppLogger.warn(
            'Workspace create unsupported by server (404) directory=${requestDirectory ?? "-"}',
            error: failure,
          );
          _worktreeSupported = false;
          notifyListeners();
          return null;
        }
        AppLogger.warn(
          'Workspace create failed name=$trimmed directory=${requestDirectory ?? "-"}',
          error: failure,
        );
        _setError(
          L10nBridge.current?.projectProviderErrorCreateWorkspace(
                failure.message,
              ) ??
              'Failed to create workspace: ${failure.message}',
        );
        return null;
      },
      (worktree) async {
        AppLogger.info(
          'Workspace created id=${worktree.id} directory=${worktree.directory}',
        );
        _worktreeSupported = true;
        await _loadProjects(silent: true);
        await loadWorktrees(silent: true);

        if (switchToCreated) {
          final switched = await switchToDirectoryContext(worktree.directory);
          if (!switched && _currentProject?.path.trim() != worktree.directory) {
            AppLogger.warn(
              'Workspace created but context switch did not apply directory=${worktree.directory}',
            );
          }
        }

        notifyListeners();
        return worktree;
      },
    );
  }

  Future<bool> resetWorktree(String worktreeId) async {
    AppLogger.info(
      'Workspace reset start id=$worktreeId directory=${currentDirectory ?? "-"}',
    );
    final result = await _projectRepository.resetWorktree(
      worktreeId,
      directory: currentDirectory,
    );
    return result.fold(
      (failure) {
        if (failure is NetworkFailure && failure.code == 404) {
          AppLogger.warn(
            'Workspace reset unsupported by server (404) id=$worktreeId',
            error: failure,
          );
          _worktreeSupported = false;
          notifyListeners();
          return false;
        }
        AppLogger.warn('Workspace reset failed id=$worktreeId', error: failure);
        _setError(
          L10nBridge.current?.projectProviderErrorResetWorkspace(
                failure.message,
              ) ??
              'Failed to reset workspace: ${failure.message}',
        );
        return false;
      },
      (_) {
        AppLogger.info('Workspace reset succeeded id=$worktreeId');
        unawaited(loadWorktrees(silent: true));
        return true;
      },
    );
  }

  Future<bool> deleteWorktree(String worktreeId) async {
    AppLogger.info(
      'Workspace delete start id=$worktreeId directory=${currentDirectory ?? "-"}',
    );
    final removed = _worktrees
        .where((item) => item.id == worktreeId)
        .firstOrNull;
    final result = await _projectRepository.deleteWorktree(
      worktreeId,
      directory: currentDirectory,
    );

    return result.fold(
      (failure) {
        if (failure is NetworkFailure && failure.code == 404) {
          AppLogger.warn(
            'Workspace delete unsupported by server (404) id=$worktreeId',
            error: failure,
          );
          _worktreeSupported = false;
          notifyListeners();
          return false;
        }
        AppLogger.warn(
          'Workspace delete failed id=$worktreeId',
          error: failure,
        );
        _setError(
          L10nBridge.current?.projectProviderErrorDeleteWorkspace(
                failure.message,
              ) ??
              'Failed to delete workspace: ${failure.message}',
        );
        return false;
      },
      (_) async {
        AppLogger.info('Workspace delete succeeded id=$worktreeId');
        var projectStateChanged = false;
        if (removed != null) {
          final removedProjectIds = _projects
              .where((item) => item.path == removed.directory)
              .map((item) => item.id)
              .toSet();
          if (removedProjectIds.isNotEmpty) {
            _projects = _projects
                .where((item) => !removedProjectIds.contains(item.id))
                .toList(growable: false);
            _openProjectIds = _openProjectIds
                .where((id) => !removedProjectIds.contains(id))
                .toList(growable: false);

            if (_currentProject != null &&
                removedProjectIds.contains(_currentProject!.id)) {
              Project? fallback;
              for (final openId in _openProjectIds) {
                fallback = _projects
                    .where((item) => item.id == openId)
                    .firstOrNull;
                if (fallback != null) {
                  break;
                }
              }
              fallback ??= _projects.firstOrNull;
              _currentProject = fallback;
            }
            if (_currentProject != null) {
              _ensureOpenProject(_currentProject!.id);
            }
            projectStateChanged = true;
          }
        }
        if (projectStateChanged) {
          await _persistProjectState();
        }
        await loadWorktrees(silent: true);
        notifyListeners();
        return true;
      },
    );
  }

  Future<List<String>?> listDirectories(String directory) async {
    final normalized = directory.trim();
    if (normalized.isEmpty) {
      _setError(
        L10nBridge.current?.projectProviderErrorDirectoryEmpty ??
            'Directory cannot be empty',
      );
      return null;
    }
    AppLogger.info('Directory list start directory=$normalized');
    final result = await _projectRepository.listDirectories(normalized);
    return result.fold(
      (failure) {
        AppLogger.warn(
          'Directory list failed directory=$normalized',
          error: failure,
        );
        _setError(
          L10nBridge.current?.projectProviderErrorListDirectories(
                failure.message,
              ) ??
              'Failed to list directories: ${failure.message}',
        );
        return null;
      },
      (directories) {
        final unique =
            directories
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .toSet()
                .toList(growable: false)
              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        AppLogger.info(
          'Directory list succeeded directory=$normalized count=${unique.length}',
        );
        return unique;
      },
    );
  }

  Future<bool?> isGitDirectory(String directory) async {
    final normalized = directory.trim();
    if (normalized.isEmpty) {
      _setError(
        L10nBridge.current?.projectProviderErrorDirectoryEmpty ??
            'Directory cannot be empty',
      );
      return null;
    }
    AppLogger.info('Directory git check start directory=$normalized');
    final result = await _projectRepository.isGitDirectory(normalized);
    return result.fold(
      (failure) {
        AppLogger.warn(
          'Directory git check failed directory=$normalized',
          error: failure,
        );
        _setError(
          L10nBridge.current?.projectProviderErrorValidateDirectory(
                failure.message,
              ) ??
              'Failed to validate directory: ${failure.message}',
        );
        return null;
      },
      (isGit) {
        AppLogger.info(
          'Directory git check result directory=$normalized git=$isGit',
        );
        return isGit;
      },
    );
  }

  Future<List<FileNode>?> listFiles({
    required String path,
    String? directory,
  }) async {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) {
      _setError(
        L10nBridge.current?.projectProviderErrorPathEmpty ??
            'Path cannot be empty',
      );
      return null;
    }
    final requestDirectory = directory?.trim();
    final targetDirectory = requestDirectory == null || requestDirectory.isEmpty
        ? currentDirectory
        : requestDirectory;
    final result = await _projectRepository.listFiles(
      directory: targetDirectory,
      path: normalizedPath,
    );
    return result.fold(
      (failure) {
        AppLogger.warn(
          'File list failed path=$normalizedPath directory=${targetDirectory ?? "-"}',
          error: failure,
        );
        _setError(
          L10nBridge.current?.projectProviderErrorListFiles(failure.message) ??
              'Failed to list files: ${failure.message}',
        );
        return null;
      },
      (nodes) {
        final sorted = List<FileNode>.from(nodes)
          ..sort((a, b) {
            if (a.isDirectory != b.isDirectory) {
              return a.isDirectory ? -1 : 1;
            }
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
        return sorted;
      },
    );
  }

  Future<List<FileNode>?> findFiles({
    required String query,
    String? directory,
    int limit = 50,
    String? type,
    bool updateProviderError = true,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const <FileNode>[];
    }
    final requestDirectory = directory?.trim();
    final targetDirectory = requestDirectory == null || requestDirectory.isEmpty
        ? currentDirectory
        : requestDirectory;
    final result = await _projectRepository.findFiles(
      directory: targetDirectory,
      query: normalizedQuery,
      limit: limit,
      type: type,
    );
    return result.fold((failure) {
      AppLogger.warn(
        'File search failed query=$normalizedQuery directory=${targetDirectory ?? "-"} type=${type ?? "-"}',
        error: failure,
      );
      if (updateProviderError) {
        _setError(
          L10nBridge.current?.projectProviderErrorSearchFiles(
                failure.message,
              ) ??
              'Failed to search files: ${failure.message}',
        );
      }
      return null;
    }, (nodes) => nodes);
  }

  Future<List<FileSearchMatch>?> searchFileContents({
    required String pattern,
    String? directory,
    int limit = 50,
    bool updateProviderError = true,
  }) async {
    final normalizedPattern = pattern.trim();
    if (normalizedPattern.isEmpty) {
      return const <FileSearchMatch>[];
    }
    final requestDirectory = directory?.trim();
    final targetDirectory = requestDirectory == null || requestDirectory.isEmpty
        ? currentDirectory
        : requestDirectory;
    final result = await _projectRepository.searchFileContents(
      directory: targetDirectory,
      pattern: normalizedPattern,
      limit: limit,
    );
    return result.fold((failure) {
      AppLogger.warn(
        'File content search failed pattern=$normalizedPattern directory=${targetDirectory ?? "-"}',
        error: failure,
      );
      if (updateProviderError) {
        _setError(
          L10nBridge.current?.projectProviderErrorContentSearchUnavailable(
                failure.message,
              ) ??
              'Content search not available: ${failure.message}',
        );
      }
      return null;
    }, (matches) => matches);
  }

  Future<List<WorkspaceSymbol>?> findSymbols({
    required String query,
    String? directory,
    int limit = 10,
    bool updateProviderError = false,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const <WorkspaceSymbol>[];
    }
    final requestDirectory = directory?.trim();
    final targetDirectory = requestDirectory == null || requestDirectory.isEmpty
        ? currentDirectory
        : requestDirectory;
    final result = await _projectRepository.findSymbols(
      directory: targetDirectory,
      query: normalizedQuery,
      limit: limit,
    );
    return result.fold((failure) {
      AppLogger.warn(
        'Workspace symbol search failed query=$normalizedQuery directory=${targetDirectory ?? "-"}',
        error: failure,
      );
      if (updateProviderError) {
        _setError(
          L10nBridge.current?.projectProviderErrorSearchSymbols(
                failure.message,
              ) ??
              'Failed to search symbols: ${failure.message}',
        );
      }
      return null;
    }, (symbols) => symbols);
  }

  Future<FileContent?> readFileContent({
    required String path,
    String? directory,
  }) async {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) {
      _setError(
        L10nBridge.current?.projectProviderErrorPathEmpty ??
            'Path cannot be empty',
      );
      return null;
    }
    final requestDirectory = directory?.trim();
    final targetDirectory = requestDirectory == null || requestDirectory.isEmpty
        ? currentDirectory
        : requestDirectory;
    final result = await _projectRepository.readFileContent(
      directory: targetDirectory,
      path: normalizedPath,
    );
    return result.fold((failure) {
      AppLogger.warn(
        'File read failed path=$normalizedPath directory=${targetDirectory ?? "-"}',
        error: failure,
      );
      _setError(
        L10nBridge.current?.projectProviderErrorReadFile(failure.message) ??
            'Failed to read file: ${failure.message}',
      );
      return null;
    }, (content) => content);
  }

  void clearError() {
    _error = null;
    if (_status == ProjectStatus.error) {
      _status = ProjectStatus.initial;
    }
    notifyListeners();
  }

  Future<void> _hydrateCurrentProjectFromServer() async {
    final requestGeneration = _projectContextGeneration;
    final result = await _projectRepository.getCurrentProject();
    if (requestGeneration != _projectContextGeneration) {
      return;
    }
    result.fold(
      (failure) {
        AppLogger.warn(
          'Failed to get current project from server',
          error: failure,
        );
      },
      (project) {
        final ignoreSyntheticRoot =
            _isPlaceholderRootProject(project) &&
            _projects.any((item) => !_isPlaceholderRootProject(item));
        if (ignoreSyntheticRoot) {
          return;
        }
        _currentProject = project;
        if (!_projects.any((item) => item.id == project.id)) {
          _projects = <Project>[project, ..._projects];
        }
      },
    );
  }

  Future<void> _loadProjects({
    required bool silent,
    bool preserveOpenContexts = true,
  }) async {
    final requestGeneration = _projectContextGeneration;
    final projectsToPreserve = preserveOpenContexts
        ? _projectsToPreserveDuringRefresh()
        : const <Project>[];
    final result = await _projectRepository.getProjects();
    if (requestGeneration != _projectContextGeneration) {
      return;
    }
    result.fold(
      (failure) {
        if (!silent) {
          _setError(
            L10nBridge.current?.projectProviderErrorLoadProjectList(
                  failure.message,
                ) ??
                'Failed to load project list: ${failure.message}',
          );
        }
      },
      (projects) {
        _projects = _sanitizeProjects(projects);
        _mergePreservedProjects(projectsToPreserve);
        _syncArchivedProjectIdsFromHiddenPaths();
        _openProjectIds = _openProjectIds
            .where((id) {
              final project = _projects
                  .where((item) => item.id == id)
                  .firstOrNull;
              return project != null && !_isProjectHidden(project);
            })
            .toList(growable: false);
        if (_currentProject != null) {
          final refreshed = _projects
              .where((item) => item.id == _currentProject!.id)
              .firstOrNull;
          if (refreshed != null && !_isProjectHidden(refreshed)) {
            _currentProject = refreshed;
          } else if (refreshed != null) {
            _currentProject = null;
          }
        }
      },
    );
  }

  Future<String> _resolveServerId() async {
    final stored = await _localDataSource.getActiveServerId();
    if (stored == null || stored.trim().isEmpty) {
      return 'legacy';
    }
    return stored.trim();
  }

  Future<void> _restoreOpenProjects() async {
    _openProjectIds = <String>[];
    final raw = await _localDataSource.getOpenProjectIdsJson(
      serverId: _activeServerId,
    );
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final savedIds = decoded.whereType<String>().toList(growable: false);
          _rehydrateSyntheticProjects(savedIds);
          _openProjectIds = savedIds
              .where((id) {
                if (_isPlaceholderRootId(id)) return false;
                final project = _projects
                    .where((candidate) => candidate.id == id)
                    .firstOrNull;
                return project != null && !_isProjectHidden(project);
              })
              .toList(growable: false);
          _syncArchivedProjectIdsFromHiddenPaths();
        }
      } catch (e, stackTrace) {
        AppLogger.warn(
          'Failed to restore open project contexts',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    if (_currentProject != null && !_isProjectHidden(_currentProject!)) {
      _ensureOpenProject(_currentProject!.id);
    }

    final firstVisibleProject = _firstVisibleProject;
    if (_openProjectIds.isEmpty && firstVisibleProject != null) {
      _openProjectIds = <String>[firstVisibleProject.id];
    }
  }

  Future<void> _restoreHiddenProjectPaths() async {
    final hiddenPaths = <String>{};

    final raw = await _localDataSource.getHiddenProjectPathsJson(
      serverId: _activeServerId,
    );
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final path in decoded.whereType<String>()) {
            final normalized = normalizeOptionalFilePath(path);
            if (normalized != null) {
              hiddenPaths.add(normalized);
            }
          }
        }
      } catch (e, stackTrace) {
        AppLogger.warn(
          'Failed to restore hidden project paths',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    try {
      final legacyRaw = await _localDataSource.getArchivedProjectIdsJson(
        serverId: _activeServerId,
      );
      if (legacyRaw != null && legacyRaw.trim().isNotEmpty) {
        final decoded = jsonDecode(legacyRaw);
        if (decoded is List) {
          for (final projectId in decoded.whereType<String>()) {
            final legacyPath = _projectPathForProjectId(projectId);
            if (legacyPath != null) {
              hiddenPaths.add(legacyPath);
            }
          }
        }
      }
    } catch (e, stackTrace) {
      AppLogger.warn(
        'Failed to restore archived project contexts',
        error: e,
        stackTrace: stackTrace,
      );
    }

    _hiddenProjectPaths = hiddenPaths.toList(growable: false)..sort();
    _syncArchivedProjectIdsFromHiddenPaths();
  }

  void _ensureOpenProject(String projectId) {
    _unhideProject(projectId);
    if (_openProjectIds.contains(projectId)) {
      return;
    }
    _openProjectIds = <String>[..._openProjectIds, projectId];
  }

  void _unhideProject(String projectId) {
    final hiddenPath = _projectPathForProjectId(projectId);
    if (hiddenPath == null) {
      return;
    }
    _hiddenProjectPaths = _hiddenProjectPaths
        .where((path) => path != hiddenPath)
        .toList(growable: false);
    _syncArchivedProjectIdsFromHiddenPaths();
  }

  _ProjectStatePersistenceSnapshot _captureProjectStatePersistenceSnapshot() {
    // Never persist the placeholder root ("Global") as the last project:
    // once saved it would restore itself forever. A null current id keeps
    // the previously persisted value instead.
    final current = _currentProject;
    final currentId = current != null && !_isPlaceholderRootProject(current)
        ? current.id
        : null;
    return _ProjectStatePersistenceSnapshot(
      serverId: _activeServerId,
      currentProjectId: currentId,
      openProjectIdsJson: jsonEncode(
        _openProjectIds.where((id) => !_isPlaceholderRootId(id)).toList(),
      ),
      archivedProjectIdsJson: jsonEncode(_archivedProjectIds),
      hiddenProjectPathsJson: jsonEncode(_hiddenProjectPaths),
    );
  }

  Future<void> _persistProjectStateSnapshot(
    _ProjectStatePersistenceSnapshot snapshot,
  ) async {
    final currentProjectId = snapshot.currentProjectId;
    if (currentProjectId != null) {
      await _localDataSource.saveCurrentProjectId(
        currentProjectId,
        serverId: snapshot.serverId,
      );
    }

    await _localDataSource.saveOpenProjectIdsJson(
      snapshot.openProjectIdsJson,
      serverId: snapshot.serverId,
    );
    await _localDataSource.saveArchivedProjectIdsJson(
      snapshot.archivedProjectIdsJson,
      serverId: snapshot.serverId,
    );
    await _localDataSource.saveHiddenProjectPathsJson(
      snapshot.hiddenProjectPathsJson,
      serverId: snapshot.serverId,
    );
  }

  Future<void> _persistProjectState() {
    final snapshot = _captureProjectStatePersistenceSnapshot();
    final previous = _projectStatePersistenceQueue;
    final operation = previous
        .catchError((Object error, StackTrace stackTrace) {
          AppLogger.warn(
            'Previous project state persistence failed',
            error: error,
            stackTrace: stackTrace,
          );
        })
        .then((_) => _persistProjectStateSnapshot(snapshot));
    _projectStatePersistenceQueue = operation.catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      AppLogger.warn(
        'Failed to persist project state in background',
        error: error,
        stackTrace: stackTrace,
      );
    });
    return operation;
  }

  Future<void> _enqueueProjectStatePersistence() {
    if (_localDataSource is! AppLocalDataSourceImpl) {
      final snapshot = _captureProjectStatePersistenceSnapshot();
      final previous = _projectStatePersistenceQueue;
      final operation = previous
          .catchError((Object error, StackTrace stackTrace) {
            AppLogger.warn(
              'Previous project state persistence failed',
              error: error,
              stackTrace: stackTrace,
            );
          })
          .then((_) => _persistProjectStateSnapshot(snapshot));
      _projectStatePersistenceQueue = operation.catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        AppLogger.warn(
          'Failed to persist project state in background',
          error: error,
          stackTrace: stackTrace,
        );
      });
      unawaited(_projectStatePersistenceQueue);
      return _projectStatePersistenceQueue;
    }
    _hasPendingProjectPersist = true;
    _projectStateDebounceGeneration++;
    final generation = _projectStateDebounceGeneration;
    _projectStateDebounce?.cancel();
    _projectStateDebounce = Timer(
      const Duration(milliseconds: 200),
      () {
        _projectStateDebounce = null;
        if (generation != _projectStateDebounceGeneration) return;
        if (!_hasPendingProjectPersist) return;
        _hasPendingProjectPersist = false;
        final snapshot = _captureProjectStatePersistenceSnapshot();
        final previous = _projectStatePersistenceQueue;
        final operation = previous
            .catchError((Object error, StackTrace stackTrace) {
              AppLogger.warn(
                'Previous project state persistence failed',
                error: error,
                stackTrace: stackTrace,
              );
            })
            .then((_) => _persistProjectStateSnapshot(snapshot));
        _projectStatePersistenceQueue = operation.catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          AppLogger.warn(
            'Failed to persist project state in background',
            error: error,
            stackTrace: stackTrace,
          );
        });
        unawaited(_projectStatePersistenceQueue);
      },
    );
    // Return a future that completes after debounced write for callers that
    // unawait it; for immediate correctness, callers that need durability
    // should use _persistProjectState directly.
    return Future<void>.value();
  }

  Future<void> flushProjectStatePersistence() async {
    _projectStateDebounce?.cancel();
    _projectStateDebounce = null;
    if (_hasPendingProjectPersist) {
      _hasPendingProjectPersist = false;
      final snapshot = _captureProjectStatePersistenceSnapshot();
      final previous = _projectStatePersistenceQueue;
      final operation = previous
          .catchError((Object error, StackTrace stackTrace) {
            AppLogger.warn(
              'Previous project state persistence failed',
              error: error,
              stackTrace: stackTrace,
            );
          })
          .then((_) => _persistProjectStateSnapshot(snapshot));
      _projectStatePersistenceQueue = operation.catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        AppLogger.warn(
          'Failed to persist project state in background',
          error: error,
          stackTrace: stackTrace,
        );
      });
      await _projectStatePersistenceQueue;
    } else {
      await _projectStatePersistenceQueue;
    }
  }

  @visibleForTesting
  Future<void> debugWaitForProjectStatePersistence() {
    return flushProjectStatePersistence();
  }

  @override
  void dispose() {
    _projectStateDebounce?.cancel();
    _projectStateDebounce = null;
    if (_hasPendingProjectPersist) {
      _hasPendingProjectPersist = false;
      final snapshot = _captureProjectStatePersistenceSnapshot();
      final previous = _projectStatePersistenceQueue;
      final operation = previous
          .catchError((Object error, StackTrace stackTrace) {
            AppLogger.warn(
              'Previous project state persistence failed',
              error: error,
              stackTrace: stackTrace,
            );
          })
          .then((_) => _persistProjectStateSnapshot(snapshot));
      _projectStatePersistenceQueue = operation.catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        AppLogger.warn(
          'Failed to persist project state in background',
          error: error,
          stackTrace: stackTrace,
        );
      });
      // Best-effort drain without awaiting in dispose.
    }
    super.dispose();
  }

  void _setStatus(ProjectStatus status) {
    _status = status;
    if (status != ProjectStatus.error) {
      _error = null;
    }
    notifyListeners();
  }

  void _setError(String error) {
    AppLogger.warn(error);
    _error = error;
    _status = ProjectStatus.error;
    notifyListeners();
  }

  bool _isPlaceholderRootProject(Project project) {
    final id = project.id.trim();
    final name = project.name.trim();
    final path = project.path.trim();
    if (path != '/') {
      return false;
    }
    final normalizedName = name.toLowerCase();
    final idLooksSynthetic =
        id.isEmpty || id == '/' || id == path || id == 'global';
    final nameLooksSynthetic =
        name.isEmpty ||
        name == '/' ||
        name == path ||
        normalizedName == 'global';
    return idLooksSynthetic && nameLooksSynthetic;
  }

  /// Bare placeholder-root identifiers as persisted. A stale `global`
  /// current/open id must never be treated as a real last project.
  bool _isPlaceholderRootId(String id) {
    final normalized = id.trim();
    return normalized.isEmpty || normalized == '/' || normalized == 'global';
  }

  List<Project> _sanitizeProjects(List<Project> projects) {
    var sanitized = List<Project>.from(projects);
    if (sanitized.length <= 1) {
      return sanitized;
    }
    sanitized = sanitized
        .where((item) => !_isPlaceholderRootProject(item))
        .toList(growable: false);
    return sanitized.isEmpty ? projects : sanitized;
  }

  List<Project> _projectsToPreserveDuringRefresh() {
    final preserveIds = <String>{..._openProjectIds};
    final currentProjectId = _currentProject?.id.trim();
    if (currentProjectId != null && currentProjectId.isNotEmpty) {
      preserveIds.add(currentProjectId);
    }
    final byId = <String, Project>{for (final item in _projects) item.id: item};
    return preserveIds
        .map((id) => byId[id] ?? _syntheticProjectFromId(id))
        .whereType<Project>()
        .where((project) => !_isProjectHidden(project))
        .toList(growable: false);
  }

  void _mergePreservedProjects(Iterable<Project> projects) {
    for (final preserved in projects) {
      if (_isProjectHidden(preserved)) {
        continue;
      }
      final existingPathIndex = _projects.indexWhere(
        (item) => areEquivalentFilePaths(item.path, preserved.path),
      );
      if (existingPathIndex >= 0) {
        continue;
      }
      final existingIdIndex = _projects.indexWhere(
        (item) => item.id == preserved.id,
      );
      if (existingIdIndex >= 0) {
        _projects[existingIdIndex] = preserved;
      } else {
        _projects = <Project>[preserved, ..._projects];
      }
    }
  }

  void _rehydrateSyntheticProjects(Iterable<String> projectIds) {
    for (final id in projectIds) {
      final synthetic = _syntheticProjectFromId(id);
      if (synthetic == null) {
        continue;
      }
      final existingIndex = _projects.indexWhere(
        (item) => item.id == synthetic.id,
      );
      if (existingIndex >= 0) {
        _projects[existingIndex] = synthetic;
      } else {
        _projects = <Project>[synthetic, ..._projects];
      }
    }
  }

  Project? _syntheticProjectFromId(String? projectId) {
    final normalizedId = projectId?.trim();
    if (normalizedId == null || !normalizedId.startsWith('dir::')) {
      return null;
    }
    final directory = normalizeOptionalFilePath(normalizedId.substring(5));
    if (directory == null || directory == '/') {
      return null;
    }
    return _buildSyntheticDirectoryProject(directory);
  }

  Project _buildSyntheticDirectoryProject(String directory) {
    final normalized = normalizeFilePath(directory);
    final normalizedPath = normalized.replaceAll('\\', '/');
    final segments = normalizedPath
        .split('/')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final name = segments.isEmpty ? normalized : segments.last;
    final now = DateTime.now();
    return Project(
      id: 'dir::$normalized',
      name: name,
      path: normalized,
      createdAt: now,
      updatedAt: now,
    );
  }

  Project? get _firstVisibleProject {
    return _projects.where((item) => !_isProjectHidden(item)).firstOrNull;
  }

  bool _isProjectHidden(Project project) {
    final normalizedPath = normalizeOptionalFilePath(project.path);
    if (normalizedPath == null) {
      return false;
    }
    return _hiddenProjectPaths.contains(normalizedPath);
  }

  String? _projectPathForProjectId(String projectId) {
    final project = _projects.where((item) => item.id == projectId).firstOrNull;
    if (project != null) {
      return normalizeOptionalFilePath(project.path);
    }
    final synthetic = _syntheticProjectFromId(projectId);
    return normalizeOptionalFilePath(synthetic?.path);
  }

  void _syncArchivedProjectIdsFromHiddenPaths() {
    final hiddenPathSet = _hiddenProjectPaths.toSet();
    _archivedProjectIds = _projects
        .where(
          (item) =>
              hiddenPathSet.contains(normalizeOptionalFilePath(item.path)),
        )
        .map((item) => item.id)
        .toList(growable: false);
  }

  List<String> _appendUniqueSortedPath(List<String> paths, String path) {
    final merged = <String>{...paths, path}.toList(growable: false)..sort();
    return merged;
  }
}
