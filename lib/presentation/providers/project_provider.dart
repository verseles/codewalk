import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/project.dart';
import '../../domain/repositories/project_repository.dart';
import '../../core/errors/failures.dart';

/// Technical comment translated to English.
enum ProjectStatus { initial, loading, loaded, error }

/// Technical comment translated to English.
class ProjectProvider extends ChangeNotifier {
  final ProjectRepository _projectRepository;

  ProjectProvider({required ProjectRepository projectRepository})
    : _projectRepository = projectRepository;

  ProjectStatus _status = ProjectStatus.initial;
  List<Project> _projects = [];
  Project? _currentProject;
  String? _error;

  // Getters
  ProjectStatus get status => _status;
  List<Project> get projects => _projects;
  Project? get currentProject => _currentProject;
  String? get error => _error;
  String get currentProjectId => _currentProject?.id ?? 'default';

  /// Technical comment translated to English.
  Future<void> initializeProject() async {
    _setStatus(ProjectStatus.loading);

    try {
      // Technical comment translated to English.
      final prefs = await SharedPreferences.getInstance();
      final savedProjectId = prefs.getString('current_project_id');

      if (savedProjectId != null) {
        // Technical comment translated to English.
        final result = await _projectRepository.getProject(savedProjectId);
        result.fold(
          (failure) async {
            // Technical comment translated to English.
            await _getCurrentProject();
          },
          (project) {
            _currentProject = project;
            _setStatus(ProjectStatus.loaded);
          },
        );
      } else {
        // Technical comment translated to English.
        await _loadProjects();

        if (_projects.isNotEmpty) {
          // Technical comment translated to English.
          _currentProject = _projects.first;
          await _saveCurrentProjectId(_currentProject!.id);
          _setStatus(ProjectStatus.loaded);
        } else {
          // Technical comment translated to English.
          await _getCurrentProject();
        }
      }
    } catch (e) {
      _setError('Failed to initialize project: $e');
    }
  }

  /// Technical comment translated to English.
  Future<void> loadProjects() async {
    _setStatus(ProjectStatus.loading);
    await _loadProjects();
  }

  /// Technical comment translated to English.
  Future<void> _loadProjects() async {
    try {
      final result = await _projectRepository.getProjects();
      result.fold(
        (failure) {
          _setError('Failed to load project list: ${failure.toString()}');
        },
        (projects) {
          _projects = projects;
          if (_status == ProjectStatus.loading) {
            _setStatus(ProjectStatus.loaded);
          }
        },
      );
    } catch (e) {
      _setError('Exception while loading project list: $e');
    }
  }

  /// Technical comment translated to English.
  Future<void> _getCurrentProject() async {
    try {
      final result = await _projectRepository.getCurrentProject();
      result.fold(
        (failure) {
          // Technical comment translated to English.
          if (failure is NetworkFailure) {
            _setError(
              'Network connection failed. Please check network settings',
            );
          } else if (failure is ServerFailure) {
            // Technical comment translated to English.
            _setError(
              'Unable to load project info right now. Please try again later',
            );
          } else {
            _setError(
              'Failed to load project info. Please check server connection',
            );
          }
        },
        (project) async {
          _currentProject = project;
          // Technical comment translated to English.
          if (!_projects.any((p) => p.id == project.id)) {
            _projects = [project, ..._projects];
          }
          await _saveCurrentProjectId(project.id);
          _setStatus(ProjectStatus.loaded);
        },
      );
    } catch (e) {
      _setError('Exception while loading project info. Please retry');
    }
  }

  /// Technical comment translated to English.
  Future<void> switchProject(String projectId) async {
    try {
      final project = _projects.firstWhere((p) => p.id == projectId);
      _currentProject = project;
      await _saveCurrentProjectId(projectId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to switch project: $e');
    }
  }

  /// Technical comment translated to English.
  Future<void> _saveCurrentProjectId(String projectId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_project_id', projectId);
    } catch (e) {
      print('Failed to save project ID: $e');
    }
  }

  /// Technical comment translated to English.
  void _setStatus(ProjectStatus status) {
    _status = status;
    if (status != ProjectStatus.error) {
      _error = null;
    }
    notifyListeners();
  }

  /// Technical comment translated to English.
  void _setError(String error) {
    _error = error;
    _status = ProjectStatus.error;
    notifyListeners();
  }

  /// Technical comment translated to English.
  void clearError() {
    _error = null;
    if (_status == ProjectStatus.error) {
      _status = ProjectStatus.initial;
    }
    notifyListeners();
  }
}
