import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';

import '../../platform/sessions/project_workspace_store.dart';
import '../../platform/sessions/workspace_store.dart';
import '../../shared/sessions/server_path.dart';
import '../../shared/sessions/session_actions.dart';
import 'session_tabs_controller.dart';
import 'sessions_controller.dart';
import 'workspace_draft_controller.dart';

/// Why a project change did not go through, for the drawer to say.
enum ProjectContextNotice {
  none,

  /// The only open project stays open.
  soleContext,

  /// The open projects or the pins reached their bound.
  capacity,

  /// The projects could not be read or saved.
  unavailable,
}

/// The project contexts of the selected server: the open ones, the one the
/// list shows, the closed history, the pinned sessions and what the list
/// shows.
///
/// The contexts are CodeWalk's own state: opening, closing or pinning never
/// creates, archives, aborts or deletes a session on the server. A server
/// with no context yet starts in the project of its most recent session, or
/// in its default location when it holds none. It owns its store.
class ProjectContextsController extends ChangeNotifier {
  ProjectContextsController({
    required this.catalog,
    required ProjectWorkspaceStore store,
    WorkspaceStore? workspace,
    SessionTabsController? tabs,
    WorkspaceDraftController? drafts,
  }) : _store = store,
       _workspace = workspace,
       _tabs = tabs,
       _drafts = drafts {
    catalog.addListener(_sync);
    _store.addListener(_storeChanged);
  }

  final SessionsController catalog;
  final ProjectWorkspaceStore _store;

  /// The last project each server used before contexts existed; it only
  /// chooses where a server without contexts starts.
  final WorkspaceStore? _workspace;
  final SessionTabsController? _tabs;
  final WorkspaceDraftController? _drafts;

  String? _profile;
  bool _disposed = false;
  bool _syncing = false;
  bool _starting = false;
  bool _startFailed = false;
  int _startToken = 0;
  bool _busy = false;
  bool _filterApplied = false;
  ProjectContextNotice _notice = ProjectContextNotice.none;

  /// The query being typed, ahead of its saved copy.
  String? _query;
  Timer? _queryWrite;

  /// How long typing waits before the query is saved.
  static const queryWriteDelay = Duration(milliseconds: 400);

  /// The session last shown in each context of the selected server.
  final _views = <String, SessionRef>{};

  /// The empty contexts that already opened their draft once.
  final _drafted = <String>{};

  Future<void> initialize() => _store.initialize();

  /// Whether the contexts can be read and changed.
  bool get available =>
      _store.loaded && !_store.unreadable && catalog.selectedProfile != null;

  /// Whether the saved contexts could not be read; the list then reads every
  /// session of the server.
  bool get unreadable => _store.unreadable;

  /// A context change is in flight; another waits for it.
  bool get busy => _busy;

  ProjectContextNotice get notice => _notice;

  ProjectWorkspace get workspace {
    final profile = catalog.selectedProfile?.id;
    return profile == null || !available
        ? ProjectWorkspace.empty
        : _store.workspace(profile);
  }

  List<String> get open => workspace.open;
  String? get active => workspace.active;
  List<String> get closed => workspace.closed;

  /// What the list shows: the latest change asked for ahead of its saved
  /// copy, so overlapping changes never undo one another.
  SessionListPreferences get preferences =>
      _requested ?? _store.listPreferences;
  SessionListPreferences? _requested;

  /// The preference writes still in flight; the store closes after them.
  final _writes = <Future<Object?>>{};

  Future<ProjectStoreResult> _write(SessionListPreferences next) {
    final write = _store.setListPreferences(next);
    _writes.add(write);
    write.whenComplete(() => _writes.remove(write)).ignore();
    return write;
  }

  /// The search query of the list: what is typed, at once.
  String get query => _query ?? preferences.query;

  /// Whether [row] is pinned in its context.
  bool isPinned(SessionSummary row) {
    final directory = row.info.project?.canonicalDirectory;
    return directory != null &&
        workspace.isPinned(directory, row.info.ref.storageKey);
  }

  /// The session last shown in [directory], or null for its list or draft.
  SessionRef? viewOf(String directory) => _views[directory];

  /// Clears a notice the drawer has shown.
  void clearNotice() {
    if (_notice == ProjectContextNotice.none) return;
    _notice = ProjectContextNotice.none;
    _notify();
  }

  /// Opens [directory], or reopens it from the history, and shows it. A
  /// project that was not open gets a tab once its sessions are read.
  Future<bool> openContext(String directory) => _transition((profile) async {
    final opening = !_store.workspace(profile).open.contains(directory);
    final result = await _store.open(profile, directory);
    if (opening && result == ProjectStoreResult.saved) {
      _tabs?.requestFallback(profile, directory);
    }
    return result;
  });

  /// Shows the open context at [directory].
  Future<bool> activate(String directory) =>
      _transition((profile) => _store.activate(profile, directory));

  /// Closes [directory]: its pins leave with it in the same write, and its
  /// tabs, rows and remembered view are dropped locally. The server keeps
  /// every session.
  Future<bool> close(String directory) => _transition((profile) async {
    final result = await _store.close(profile, directory);
    if (result == ProjectStoreResult.saved) {
      // Another server's view and draft guard stay with that server.
      if (catalog.selectedProfile?.id == profile) {
        _views.remove(directory);
        _drafted.remove(directory);
      }
      // The project is closed either way; tabs that could not be closed
      // would come back with it, so the close says it did not go through.
      if (await _tabs?.closeContext(profile, directory) == false) {
        return ProjectStoreResult.failed;
      }
    }
    return result;
  });

  /// Forgets [directory] in the closed history until it is opened again.
  Future<bool> forgetClosed(String directory) =>
      _transition((profile) => _store.forgetClosed(profile, directory));

  /// Pins or unpins [row] in its context.
  Future<bool> setPinned(SessionSummary row, {required bool pinned}) async {
    final profile = catalog.selectedProfile?.id;
    final directory = row.info.project?.canonicalDirectory;
    if (_disposed || profile == null || directory == null || !available) {
      return false;
    }
    final result = await _store.setPinned(
      profile,
      directory,
      row.info.ref.storageKey,
      pinned: pinned,
    );
    if (_disposed || catalog.selectedProfile?.id != profile) return false;
    return _report(result);
  }

  /// Saves what the list shows; the filter applies at once.
  Future<bool> setPreferences(SessionListPreferences next) async {
    if (_disposed) return false;
    catalog.setFilter(next.filter);
    if (!_store.loaded || _store.unreadable) return false;
    _requested = next;
    final profile = catalog.selectedProfile?.id;
    final result = await _write(next);
    if (identical(_requested, next)) _requested = null;
    if (_disposed || catalog.selectedProfile?.id != profile) {
      return result == ProjectStoreResult.saved ||
          result == ProjectStoreResult.unchanged;
    }
    return _report(result);
  }

  /// Filters the list by [value] at once; the query is saved once the
  /// typing pauses.
  void setQuery(String value) {
    if (_disposed || value == query) return;
    _query = value;
    _queryWrite?.cancel();
    _queryWrite = Timer(queryWriteDelay, _saveQuery);
    _notify();
  }

  void _saveQuery() {
    final value = _query;
    if (_disposed || value == null) return;
    unawaited(
      setPreferences(
        SessionListPreferences(
          query: value,
          filter: preferences.filter,
          sort: preferences.sort,
        ),
      ).whenComplete(() {
        // The saved copy takes over once it holds what was typed.
        if (_query == value && preferences.query == value) _query = null;
      }),
    );
  }

  Future<bool> setFilter(SessionActionFilter filter) => setPreferences(
    SessionListPreferences(
      query: query,
      filter: filter,
      sort: preferences.sort,
    ),
  );

  Future<bool> setSort(SessionListSort sort) => setPreferences(
    SessionListPreferences(
      query: query,
      filter: preferences.filter,
      sort: sort,
    ),
  );

  /// The route shows [summary]: it becomes the view of its context, and the
  /// context it belongs to becomes the shown one.
  void recordView(SessionSummary summary) {
    final profile = catalog.selectedProfile?.id;
    final directory = summary.info.project?.canonicalDirectory;
    if (_disposed ||
        profile == null ||
        directory == null ||
        summary.info.ref.host.value != profile ||
        !available) {
      return;
    }
    if (active != directory) {
      if (_busy) return;
      unawaited(openContext(directory));
    }
    _views[directory] = summary.info.ref;
  }

  /// The drawer shows the list or the draft of the active context.
  void recordHome() {
    final directory = active;
    if (directory != null) _views.remove(directory);
  }

  /// One context transition at a time: a second waits for nothing and is
  /// dropped, as rapid repeated taps must not overlap.
  Future<bool> _transition(
    Future<ProjectStoreResult> Function(String profile) change,
  ) async {
    final profile = catalog.selectedProfile?.id;
    if (_disposed || _busy || profile == null || !available) return false;
    _busy = true;
    _startToken++;
    _starting = false;
    _notify();
    try {
      final result = await change(profile);
      if (_disposed || catalog.selectedProfile?.id != profile) return false;
      return _report(result);
    } finally {
      _busy = false;
      if (!_disposed) {
        _sync();
        _notify();
      }
    }
  }

  bool _report(ProjectStoreResult result) {
    final notice = switch (result) {
      ProjectStoreResult.saved ||
      ProjectStoreResult.unchanged ||
      ProjectStoreResult.notOpen => ProjectContextNotice.none,
      ProjectStoreResult.soleContext => ProjectContextNotice.soleContext,
      ProjectStoreResult.capacity => ProjectContextNotice.capacity,
      ProjectStoreResult.unavailable ||
      ProjectStoreResult.failed => ProjectContextNotice.unavailable,
    };
    if (notice != _notice) {
      _notice = notice;
      _notify();
    }
    return result == ProjectStoreResult.saved ||
        result == ProjectStoreResult.unchanged;
  }

  void _storeChanged() {
    _sync();
    _notify();
  }

  /// Applies the saved contexts of the selected server to the list.
  void _sync() {
    if (_disposed || _syncing) return;
    _syncing = true;
    try {
      _apply();
    } finally {
      _syncing = false;
    }
  }

  void _apply() {
    final profile = catalog.selectedProfile?.id;
    if (profile != _profile) {
      _profile = profile;
      _views.clear();
      _drafted.clear();
      _startToken++;
      _starting = false;
      _startFailed = false;
      _notice = ProjectContextNotice.none;
    }
    if (profile == null) return;
    if (!_store.loaded) {
      unawaited(_store.initialize());
      return;
    }
    // Unreadable contexts are never overwritten: the list reads the whole
    // server until they can be read.
    if (_store.unreadable) {
      catalog.setOpenDirectories(const []);
      if (catalog.directory != null) catalog.setDirectory(null);
      return;
    }
    if (!_filterApplied) {
      _filterApplied = true;
      catalog.setFilter(_store.listPreferences.filter);
    }
    final saved = _store.workspace(profile);
    final active = saved.active;
    if (active == null) return _start(profile);
    catalog.setOpenDirectories(saved.open);
    if (catalog.directory != active) catalog.setDirectory(active);
    _draftEmpty(active);
  }

  /// A server without contexts starts in the project the user left, else in
  /// the project of its most recent session, else in its default location.
  void _start(String profile) {
    // An explicit change in flight decides the context instead.
    if (_starting ||
        _busy ||
        _startFailed ||
        catalog.directory != null ||
        !catalog.loaded ||
        catalog.loading ||
        catalog.stale ||
        catalog.failure != null) {
      return;
    }
    String? hinted;
    final hint = _workspace?.lastProject(profile);
    if (hint != null) {
      try {
        hinted = ProjectRef.fromStorageKey(hint).canonicalDirectory;
      } on Object {
        hinted = null;
      }
    }
    // The rows come newest first; the saved filter does not choose.
    final recent = [
      for (final row in catalog.loadedSessions)
        if (row.info.project?.canonicalDirectory case final directory?
            when directory != '/')
          directory,
    ].firstOrNull;
    final choice = hinted != null && isAbsoluteServerPath(hinted)
        ? hinted
        : recent;
    if (choice != null) return _startIn(profile, Future.value(choice));
    final source = catalog.directorySource;
    if (source == null) return;
    _startIn(
      profile,
      source.location().result.then((location) => location.canonicalDirectory),
    );
  }

  void _startIn(String profile, Future<String> directory) {
    final token = _startToken;
    _starting = true;
    unawaited(() async {
      ProjectStoreResult result;
      try {
        final chosen = await directory;
        // A left server, or a context the user opened or is opening
        // meanwhile, wins.
        if (_disposed || token != _startToken) return;
        if (_busy || _store.workspace(profile).active != null) {
          _starting = false;
          return;
        }
        final opening = !_store.workspace(profile).open.contains(chosen);
        result = await _store.open(profile, chosen);
        if (opening && result == ProjectStoreResult.saved) {
          _tabs?.requestFallback(profile, chosen);
        }
      } on Object {
        result = ProjectStoreResult.unavailable;
      }
      if (_disposed || token != _startToken) return;
      _starting = false;
      if (result != ProjectStoreResult.saved &&
          result != ProjectStoreResult.unchanged) {
        _startFailed = true;
      }
      _report(result);
      _sync();
    }());
  }

  /// An empty project opens its draft once its read proves it holds no
  /// session; the draft never replaces a session or a draft in place, and
  /// nothing is created on the server until the first send.
  void _draftEmpty(String directory) {
    final drafts = _drafts;
    if (drafts == null ||
        _drafted.contains(directory) ||
        _views.containsKey(directory) ||
        catalog.directory != directory ||
        !catalog.contextComplete(directory) ||
        (catalog.contextRows(directory)?.isNotEmpty ?? true) ||
        drafts.isDraftActive) {
      return;
    }
    _drafted.add(directory);
    unawaited(drafts.openDraft(directory: directory));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    catalog.removeListener(_sync);
    _store.removeListener(_storeChanged);
    final pending = _queryWrite?.isActive ?? false;
    _queryWrite?.cancel();
    final query = _query;
    if (pending && query != null && _store.loaded && !_store.unreadable) {
      // The last query typed is saved before the store closes.
      final current = preferences;
      _write(
        SessionListPreferences(
          query: query,
          filter: current.filter,
          sort: current.sort,
        ),
      ).ignore();
    }
    // Every write still in flight lands before the store closes, a refusal
    // answered at once included.
    unawaited(
      Future.wait(
        _writes.map((write) => write.then<void>((_) {}, onError: (_) {})),
      ).whenComplete(_store.dispose),
    );
    super.dispose();
  }
}
