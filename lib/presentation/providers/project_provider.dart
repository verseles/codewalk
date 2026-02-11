import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/errors/failures.dart';
import '../../core/logging/app_logger.dart';
import '../../data/datasources/app_local_datasource.dart';
import '../../domain/entities/file_node.dart';
import '../../domain/entities/project.dart';
import '../../domain/entities/worktree.dart';
import '../../domain/repositories/project_repository.dart';

enum ProjectStatus { initial, loading, loaded, error }

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
  List<Worktree> _worktrees = <Worktree>[];
  bool _worktreeSupported = false;
  String _activeServerId = 'legacy';
  String? _error;

  ProjectStatus get status => _status;
  List<Project> get projects => List<Project>.unmodifiable(_projects);
  Project? get currentProject => _currentProject;
  String? get error => _error;
  String get currentProjectId => _currentProject?.id ?? 'default';
  String get activeServerId => _activeServerId;
  List<String> get openProjectIds => List<String>.unmodifiable(_openProjectIds);
  List<Worktree> get worktrees => List<Worktree>.unmodifiable(_worktrees);
  bool get worktreeSupported => _worktreeSupported;

  String? get currentDirectory {
    final path = _currentProject?.path.trim();
    if (path == null || path.isEmpty || path == '/' || path == '-') {
      return null;
    }
    return path;
  }

  String get currentScopeId => currentDirectory ?? currentProjectId;

  String get contextKey => '${_activeServerId}::$currentScopeId';

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
        .toList(growable: false);
  }

  Future<void> initializeProject({bool forceReload = false}) async {
    if (!forceReload &&
        _status == ProjectStatus.loaded &&
        _currentProject != null) {
      return;
    }

    _setStatus(ProjectStatus.loading);

    try {
      _activeServerId = await _resolveServerId();
      await _loadProjects(silent: true);

      final savedProjectId = await _localDataSource.getCurrentProjectId(
        serverId: _activeServerId,
      );
      if (savedProjectId != null && savedProjectId.trim().isNotEmpty) {
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

      _currentProject ??= _projects.firstOrNull;
      if (_currentProject == null) {
        _setError('No project context available from server');
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
      _setError('Failed to initialize project context: $e');
    }
  }

  Future<void> onServerScopeChanged() async {
    await initializeProject(forceReload: true);
  }

  Future<void> loadProjects() async {
    _setStatus(ProjectStatus.loading);
    await _loadProjects(silent: false);
    if (_status != ProjectStatus.error) {
      _setStatus(ProjectStatus.loaded);
    }
  }

  Future<bool> switchProject(String projectId) async {
    final target = _projects.where((item) => item.id == projectId).firstOrNull;
    if (target == null) {
      _setError('Failed to switch project: project not found');
      return false;
    }
    if (_currentProject?.id == projectId) {
      return false;
    }

    _currentProject = target;
    _ensureOpenProject(projectId);
    await _persistProjectState();
    await loadWorktrees(silent: true);
    notifyListeners();
    return true;
  }

  Future<bool> switchToDirectoryContext(String directory) async {
    final normalized = directory.trim();
    if (normalized.isEmpty) {
      _setError('Failed to switch project: directory is empty');
      return false;
    }

    Project? project = _projects
        .where((item) => item.path.trim() == normalized)
        .firstOrNull;
    if (project == null) {
      await _loadProjects(silent: true);
      project = _projects
          .where((item) => item.path.trim() == normalized)
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
          project = item;
          final existingIndex = _projects.indexWhere((p) => p.id == item.id);
          if (existingIndex >= 0) {
            _projects[existingIndex] = item;
          } else {
            _projects = <Project>[item, ..._projects];
          }
        },
      );
    }

    if (project == null) {
      _setError('Failed to switch project: directory not found');
      return false;
    }

    final selectedProject = project!;
    if (_currentProject?.id == selectedProject.id) {
      return false;
    }

    _currentProject = selectedProject;
    _ensureOpenProject(selectedProject.id);
    await _persistProjectState();
    await loadWorktrees(silent: true);
    notifyListeners();
    return true;
  }

  Future<bool> closeProject(String projectId) async {
    if (!_openProjectIds.contains(projectId)) {
      return false;
    }

    if (_openProjectIds.length <= 1 && _currentProject?.id == projectId) {
      _setError('At least one context must remain open');
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
      }
      await loadWorktrees(silent: true);
    }

    await _persistProjectState();
    notifyListeners();
    return true;
  }

  Future<bool> reopenProject(String projectId, {bool makeActive = true}) async {
    final project = _projects.where((item) => item.id == projectId).firstOrNull;
    if (project == null) {
      _setError('Failed to reopen project: project not found');
      return false;
    }

    _ensureOpenProject(projectId);
    if (makeActive) {
      _currentProject = project;
      await loadWorktrees(silent: true);
    }

    await _persistProjectState();
    notifyListeners();
    return true;
  }

  Future<void> loadWorktrees({bool silent = false}) async {
    final directory = currentDirectory;
    if (directory == null || directory.trim().isEmpty) {
      _worktrees = <Worktree>[];
      _worktreeSupported = false;
      if (!silent) {
        notifyListeners();
      }
      return;
    }

    final result = await _projectRepository.getWorktrees(directory: directory);
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
          _setError('Failed to load workspaces: ${failure.message}');
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
      _setError('Workspace name cannot be empty');
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
        _setError('Failed to create workspace: ${failure.message}');
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
        _setError('Failed to reset workspace: ${failure.message}');
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
        _setError('Failed to delete workspace: ${failure.message}');
        return false;
      },
      (_) async {
        AppLogger.info('Workspace delete succeeded id=$worktreeId');
        if (removed != null && currentDirectory == removed.directory) {
          final fallback = _projects
              .where((item) => item.path != removed.directory)
              .firstOrNull;
          if (fallback != null) {
            _currentProject = fallback;
            _ensureOpenProject(fallback.id);
            await _persistProjectState();
          }
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
      _setError('Directory cannot be empty');
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
        _setError('Failed to list directories: ${failure.message}');
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
      _setError('Directory cannot be empty');
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
        _setError('Failed to validate directory: ${failure.message}');
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
      _setError('Path cannot be empty');
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
        _setError('Failed to list files: ${failure.message}');
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
    );
    return result.fold((failure) {
      AppLogger.warn(
        'File search failed query=$normalizedQuery directory=${targetDirectory ?? "-"}',
        error: failure,
      );
      _setError('Failed to search files: ${failure.message}');
      return null;
    }, (nodes) => nodes);
  }

  Future<FileContent?> readFileContent({
    required String path,
    String? directory,
  }) async {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) {
      _setError('Path cannot be empty');
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
      _setError('Failed to read file: ${failure.message}');
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
    final result = await _projectRepository.getCurrentProject();
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

  Future<void> _loadProjects({required bool silent}) async {
    final result = await _projectRepository.getProjects();
    result.fold(
      (failure) {
        if (!silent) {
          _setError('Failed to load project list: ${failure.message}');
        }
      },
      (projects) {
        _projects = _sanitizeProjects(projects);
        if (_currentProject != null) {
          final refreshed = _projects
              .where((item) => item.id == _currentProject!.id)
              .firstOrNull;
          if (refreshed != null) {
            _currentProject = refreshed;
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
          _openProjectIds = decoded
              .whereType<String>()
              .where((id) => _projects.any((project) => project.id == id))
              .toList(growable: false);
        }
      } catch (e, stackTrace) {
        AppLogger.warn(
          'Failed to restore open project contexts',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    if (_currentProject != null) {
      _ensureOpenProject(_currentProject!.id);
    }

    if (_openProjectIds.isEmpty && _projects.isNotEmpty) {
      _openProjectIds = <String>[_projects.first.id];
    }
  }

  void _ensureOpenProject(String projectId) {
    if (_openProjectIds.contains(projectId)) {
      return;
    }
    _openProjectIds = <String>[..._openProjectIds, projectId];
  }

  Future<void> _persistProjectState() async {
    final current = _currentProject;
    if (current != null) {
      await _localDataSource.saveCurrentProjectId(
        current.id,
        serverId: _activeServerId,
      );
    }

    await _localDataSource.saveOpenProjectIdsJson(
      jsonEncode(_openProjectIds),
      serverId: _activeServerId,
    );
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
}
