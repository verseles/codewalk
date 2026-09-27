import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../core/logging/app_logger.dart';
import '../../domain/entities/project.dart';
import '../services/project_icon_discovery_service_base.dart';
import '../services/project_icon_models.dart';
import '../services/project_icon_palette.dart';
import '../services/project_icon_store_base.dart';

class ProjectIconProvider extends ChangeNotifier {
  ProjectIconProvider({
    required ProjectIconStore store,
    required ProjectIconDiscoveryService discoveryService,
    Future<Color?> Function(ProjectIconData)? extractColor,
  }) : _store = store,
       _discoveryService = discoveryService,
       _extractColor = extractColor ?? extractProjectIconColor;

  final ProjectIconStore _store;
  final ProjectIconDiscoveryService _discoveryService;
  final Future<Color?> Function(ProjectIconData) _extractColor;
  final _iconDigests = <String, String>{};
  final _revisions = <String, int>{};
  final _colors = <String, Color?>{};
  final _colorFutures = <String, Future<void>>{};
  Future<void> _colorQueue = Future<void>.value();
  bool _disposed = false;
  final Map<String, ProjectIconData> _iconsByKey = <String, ProjectIconData>{};
  final Map<String, Future<ProjectIconData?>> _loadFuturesByKey =
      <String, Future<ProjectIconData?>>{};
  final Set<String> _loadedKeys = <String>{};
  final Set<String> _loadingKeys = <String>{};
  final Set<String> _discoveringKeys = <String>{};
  final Set<String> _autoDiscoveryAttemptedKeys = <String>{};

  bool get discoverySupported => _discoveryService.isSupported;

  ProjectIconData? iconFor(Project project) {
    return _iconsByKey[projectIconKeyFor(project)];
  }

  Color? colorFor(Project project) =>
      _colors[_iconDigests[projectIconKeyFor(project)]];

  /// Lazy, shared by identical artwork, and serialized to limit decoder memory.
  Future<void> ensureColor(Project project) {
    if (_disposed) return Future<void>.value();
    final key = projectIconKeyFor(project);
    final icon = _iconsByKey[key];
    final digest = _iconDigests[key];
    if (icon == null || digest == null) return Future<void>.value();
    if (_colors.containsKey(digest)) {
      final color = _colors.remove(digest);
      _colors[digest] = color;
      return Future<void>.value();
    }
    final pending = _colorFutures[digest];
    if (pending != null) return pending;
    final future = _colorQueue
        .then((_) async {
          if (_disposed || !_iconDigests.containsValue(digest)) return;
          Color? color;
          try {
            color = await _extractColor(icon);
          } catch (_) {
            // Cache failures as well: malformed artwork must not retry each build.
          }
          if (_disposed) return;
          _colors[digest] = color;
          _pruneColors();
          if (_iconDigests.containsValue(digest)) _notify();
        })
        .whenComplete(() {
          _colorFutures.remove(digest);
        });
    _colorFutures[digest] = future;
    _colorQueue = future;
    return future;
  }

  void _setIcon(String key, ProjectIconData icon) {
    _iconsByKey[key] = icon;
    _iconDigests[key] =
        '${icon.metadata.storedFormat.name}:${sha256.convert(icon.bytes)}';
    _pruneColors();
  }

  void _pruneColors() {
    while (_colors.length > 64) {
      final unused = _colors.keys.where(
        (key) => !_iconDigests.containsValue(key),
      );
      if (unused.isEmpty) break;
      _colors.remove(unused.first);
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  bool isLoading(Project project) {
    return _loadingKeys.contains(projectIconKeyFor(project));
  }

  bool isDiscovering(Project project) {
    return _discoveringKeys.contains(projectIconKeyFor(project));
  }

  Future<ProjectIconData?> loadStoredIcon(Project project) async {
    if (_disposed) return null;
    final key = projectIconKeyFor(project);
    final icon = _iconsByKey[key];
    if (icon != null || _loadedKeys.contains(key)) {
      return icon;
    }
    final existing = _loadFuturesByKey[key];
    if (existing != null) {
      return existing;
    }
    final future = _loadStoredIcon(key);
    _loadFuturesByKey[key] = future;
    return future.whenComplete(() => _loadFuturesByKey.remove(key));
  }

  Future<ProjectIconData?> _loadStoredIcon(String key) async {
    if (!_loadingKeys.add(key)) {
      return _iconsByKey[key];
    }
    final revision = _revisions[key] ?? 0;
    try {
      final icon = await _store.readIcon(key);
      if (_disposed || revision != (_revisions[key] ?? 0)) {
        return _iconsByKey[key];
      }
      if (icon != null) _setIcon(key, icon);
      return icon;
    } catch (error) {
      AppLogger.warn('Project icon load failed', error: error);
      return null;
    } finally {
      if (!_disposed && revision == (_revisions[key] ?? 0)) {
        _loadedKeys.add(key);
      }
      _loadingKeys.remove(key);
      _notify();
    }
  }

  Future<void> autoDiscoverIcon(Project project) async {
    if (_disposed || !_discoveryService.isSupported) {
      return;
    }
    final key = projectIconKeyFor(project);
    if (!_autoDiscoveryAttemptedKeys.add(key)) {
      return;
    }
    await loadStoredIcon(project);
    await discoverIcon(project);
  }

  Future<ProjectIconDiscoveryResult> discoverIcon(Project project) async {
    if (_disposed) {
      return const ProjectIconDiscoveryResult(
        status: ProjectIconDiscoveryStatus.error,
      );
    }
    final key = projectIconKeyFor(project);
    if (!_discoveringKeys.add(key)) {
      return const ProjectIconDiscoveryResult(
        status: ProjectIconDiscoveryStatus.error,
        message: 'Project icon discovery is already running.',
      );
    }
    _revisions[key] = (_revisions[key] ?? 0) + 1;
    _notify();
    try {
      final result = await _discoveryService.discover(project);
      if (_disposed) return result;
      final candidate = result.candidate;
      if (result.found && candidate != null) {
        final icon = await _store.saveIcon(
          project: project,
          key: key,
          candidate: candidate,
        );
        if (_disposed) return result;
        _revisions[key] = (_revisions[key] ?? 0) + 1;
        _setIcon(key, icon);
        _loadedKeys.add(key);
      } else if (result.status == ProjectIconDiscoveryStatus.notFound ||
          result.status == ProjectIconDiscoveryStatus.oversized ||
          result.status == ProjectIconDiscoveryStatus.unsupported) {
        await _store.deleteIcon(key);
        if (_disposed) return result;
        _revisions[key] = (_revisions[key] ?? 0) + 1;
        _iconsByKey.remove(key);
        _iconDigests.remove(key);
        _pruneColors();
        _loadedKeys.add(key);
      }
      return result;
    } catch (error) {
      AppLogger.warn('Project icon discovery failed', error: error);
      return ProjectIconDiscoveryResult(
        status: ProjectIconDiscoveryStatus.error,
        message: error.toString(),
      );
    } finally {
      _discoveringKeys.remove(key);
      _notify();
    }
  }
}
