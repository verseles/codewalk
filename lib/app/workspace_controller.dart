import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';

import '../features/sessions/session_tabs_controller.dart';
import '../features/sessions/sessions_controller.dart';
import '../platform/sessions/workspace_store.dart';

/// Brings the workspace back where it was left: the server it used and the
/// last real project of that server.
///
/// The server is chosen only after the saved servers and their credentials
/// have loaded, so no session read starts before them. The server of the
/// launch tab wins, then the server used last, then the first saved one, so
/// a single saved server is never asked for. When the server in use is
/// removed, another one is chosen the same way. It owns [store].
class WorkspaceController extends ChangeNotifier {
  WorkspaceController({
    required SessionsController catalog,
    required WorkspaceStore store,
    SessionTabsController? tabs,
  }) : _catalog = catalog,
       _store = store,
       _tabs = tabs {
    _catalog.addListener(_catalogChanged);
    _catalog.hosts.addListener(_hostsChanged);
    _store.addListener(_retry);
    _tabs?.addListener(_retry);
  }

  final SessionsController _catalog;
  final WorkspaceStore _store;
  final SessionTabsController? _tabs;
  bool _disposed = false;
  bool _wanted = false;
  String? _profile;

  /// The server whose last project was already restored, for this selection.
  String? _restored;

  Future<void> initialize() => _store.initialize();

  /// Selects a server for the workspace when none is selected yet. It waits
  /// for what it needs and tries again as that arrives.
  void restoreServer() {
    if (_disposed) return;
    _wanted = true;
    // The saved servers are read once, whoever asks first.
    unawaited(_catalog.initialize());
    _retry();
  }

  void _retry() {
    if (_disposed || !_wanted) return;
    if (_catalog.selectedProfile != null) {
      _wanted = false;
      return;
    }
    final hosts = _catalog.hosts;
    if (!_store.loaded) {
      unawaited(_store.initialize());
      return;
    }
    if (hosts.loading || !hosts.loaded || hosts.storageError) return;
    final tabs = _tabs;
    if (tabs != null && !tabs.loaded) return;
    final profiles = hosts.profiles;
    if (profiles.isEmpty) return;
    final ids = {for (final profile in profiles) profile.id};
    final launch = tabs?.launchTab?.host.value;
    final saved = _store.activeProfile;
    final id = ids.contains(launch)
        ? launch!
        : ids.contains(saved)
        ? saved!
        : profiles.first.id;
    _wanted = false;
    unawaited(_catalog.selectProfile(id));
  }

  void _hostsChanged() {
    if (_disposed) return;
    final hosts = _catalog.hosts;
    if (!hosts.loading && hosts.loaded && !hosts.storageError) {
      final ids = {for (final profile in hosts.profiles) profile.id};
      final saved = _store.activeProfile;
      if (saved != null && !ids.contains(saved)) {
        unawaited(_store.forget(saved));
      }
    }
    _retry();
  }

  void _catalogChanged() {
    if (_disposed) return;
    final profile = _catalog.selectedProfile?.id;
    if (profile != _profile) {
      final lost = _profile != null && profile == null;
      _profile = profile;
      _restored = null;
      if (profile != null) unawaited(_store.setActiveProfile(profile));
      // The server in use was removed: the workspace moves to another one.
      if (lost) restoreServer();
    }
    if (profile == null || !_catalog.loaded) return;
    if (_restored != profile) {
      // Once per selection: a project that only shows up later, after the
      // user moved on, does not take the list back.
      _restored = profile;
      if (!_catalog.projectChosen) _restoreProject(profile);
      return;
    }
    if (!_catalog.selectedProjectWasChosen) return;
    final project = _catalog.selectedProject?.project;
    if (project != null && isRealProject(project)) {
      unawaited(_store.setLastProject(profile, project.storageKey));
    }
  }

  void _restoreProject(String profile) {
    final saved = _store.lastProject(profile);
    if (saved == null) return;
    for (final row in _catalog.sessions) {
      final project = row.info.project;
      if (project != null &&
          isRealProject(project) &&
          project.storageKey == saved) {
        _catalog.selectProject(project);
        return;
      }
    }
  }

  /// The placeholder root is never a project the workspace returns to.
  static bool isRealProject(ProjectRef project) =>
      project.canonicalDirectory != '/';

  @override
  void dispose() {
    _disposed = true;
    _catalog.removeListener(_catalogChanged);
    _catalog.hosts.removeListener(_hostsChanged);
    _store.removeListener(_retry);
    _tabs?.removeListener(_retry);
    _store.dispose();
    super.dispose();
  }
}
