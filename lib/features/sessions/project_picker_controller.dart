import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';

import '../../shared/sessions/server_path.dart';
import '../../shared/sessions/session_catalog_source.dart';
import 'project_contexts_controller.dart';
import 'sessions_controller.dart';

/// Where a result of the project picker comes from, in the order equal
/// matches are listed.
enum ProjectPickerSource { open, closed, server, found }

@immutable
final class ProjectPickerEntry {
  const ProjectPickerEntry(this.directory, this.source);
  final String directory;
  final ProjectPickerSource source;
  String get name => serverPathName(directory);
}

/// What the picker could not do, for the dialog to say.
enum ProjectPickerFailure { none, search, browse, open }

/// The project picker of one server: the known projects (open, closed and
/// the server's own) ranked against the query, a bounded directory search
/// on the server, a directory browser and a manual absolute path.
///
/// Every server reply is checked against the request it answers, so a late
/// reply never replaces a newer one. A change of server dismisses the
/// picker. Opening is one action at a time.
class ProjectPickerController extends ChangeNotifier {
  ProjectPickerController({
    required this.catalog,
    required this.contexts,
    this.debounce = const Duration(milliseconds: 250),
    this.maxResults = 50,
  }) : _profile = catalog.selectedProfile?.id {
    catalog.addListener(_catalogChanged);
  }

  final SessionsController catalog;
  final ProjectContextsController contexts;
  final Duration debounce;
  final int maxResults;
  final String? _profile;

  bool _disposed = false;
  bool _dismissed = false;
  String _query = '';
  int _highlight = 0;
  ProjectPickerFailure _failure = ProjectPickerFailure.none;

  List<String> _serverProjects = const [];
  Future<String?>? _base;

  List<String> _found = const [];
  bool _searching = false;
  int _searchToken = 0;
  Timer? _searchTimer;
  SessionCatalogRead<Object?>? _searchRead;

  bool _browsing = false;
  String? _browseDirectory;
  List<String> _browseEntries = const [];
  bool _browseLoading = false;
  int _browseToken = 0;
  SessionCatalogRead<Object?>? _browseRead;

  bool _opening = false;

  /// The server changed: the dialog closes.
  bool get dismissed => _dismissed;
  String get query => _query;
  int get highlight => _highlight;
  ProjectPickerFailure get failure => _failure;
  bool get searching => _searching;
  bool get browsing => _browsing;
  String? get browseDirectory => _browseDirectory;
  List<String> get browseEntries => _browseEntries;
  bool get browseLoading => _browseLoading;
  bool get opening => _opening;

  /// The query is a complete absolute path the server can be asked about.
  bool get canOpenPath => isAbsoluteServerPath(_query.trim());

  /// Reads the server's projects; the known contexts need no read.
  void start() {
    final source = catalog.directorySource;
    if (source == null || _disposed) return;
    final read = source.projects();
    unawaited(
      read.result.then(
        (projects) {
          if (_disposed || _dismissed) return;
          _serverProjects = [
            for (final project in projects) project.canonicalDirectory,
          ];
          _notify();
        },
        // The known contexts and the manual path still work without them.
        onError: (Object _) {},
      ),
    );
  }

  /// The results for the query: everything known while it is empty, else
  /// the matches, exact and prefix ones first, then ordered fuzzy ones.
  List<ProjectPickerEntry> get results {
    final seen = <String>{};
    final known = <ProjectPickerEntry>[
      for (final directory in contexts.open)
        if (seen.add(directory))
          ProjectPickerEntry(directory, ProjectPickerSource.open),
      for (final directory in contexts.closed)
        if (seen.add(directory))
          ProjectPickerEntry(directory, ProjectPickerSource.closed),
      for (final directory in _serverProjects)
        if (seen.add(directory))
          ProjectPickerEntry(directory, ProjectPickerSource.server),
      for (final directory in _found)
        if (seen.add(directory))
          ProjectPickerEntry(directory, ProjectPickerSource.found),
    ];
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return [
        for (final entry in known)
          if (entry.source != ProjectPickerSource.found) entry,
      ].take(maxResults * 2).toList();
    }
    final ranked = <(int, int, ProjectPickerEntry)>[];
    for (final (index, entry) in known.indexed) {
      final score =
          projectMatchScore(entry.directory, query) ??
          // The server matched it by its own rules.
          (entry.source == ProjectPickerSource.found ? 7 : null);
      if (score != null) ranked.add((score, index, entry));
    }
    ranked.sort((a, b) {
      final byScore = a.$1.compareTo(b.$1);
      return byScore != 0 ? byScore : a.$2.compareTo(b.$2);
    });
    return [for (final (_, _, entry) in ranked.take(maxResults)) entry];
  }

  void setQuery(String value) {
    if (_disposed || value == _query) return;
    _query = value;
    _highlight = 0;
    // A failure belongs to the query that caused it.
    _failure = ProjectPickerFailure.none;
    _scheduleSearch();
    _notify();
  }

  /// Moves the highlighted result by [delta], wrapping at the ends.
  void moveHighlight(int delta) {
    final count = results.length;
    if (count == 0) return;
    _highlight = (_highlight + delta) % count;
    if (_highlight < 0) _highlight += count;
    _notify();
  }

  /// The path the query completes to: the highlighted result's.
  String? completion() {
    final list = results;
    if (list.isEmpty) return null;
    return _completed = list[_highlight.clamp(0, list.length - 1)].directory;
  }

  /// The path a completion put in the field: the server's own string,
  /// which a later Open folder must not trim.
  String? _completed;

  void _scheduleSearch() {
    _searchTimer?.cancel();
    _searchRead?.cancel();
    _searchRead = null;
    final token = ++_searchToken;
    final query = _query.trim();
    // Folders found for another query never stay selectable.
    _found = const [];
    if (query.isEmpty || isAbsoluteServerPath(query)) {
      _searching = false;
      return;
    }
    _searching = true;
    _searchTimer = Timer(debounce, () => unawaited(_search(token, query)));
  }

  Future<void> _search(int token, String query) async {
    try {
      final base = await _baseDirectory();
      final source = catalog.directorySource;
      if (!_current(token) || base == null || source == null) {
        if (_current(token)) _searching = false;
        return;
      }
      final read = source.findDirectories(base, query);
      _searchRead = read;
      final entries = await read.result;
      if (!_current(token)) return;
      _found = [
        for (final entry in entries.take(maxResults))
          resolveServerPath(
            entry.ref.project.canonicalDirectory,
            entry.ref.path,
          ),
      ];
      _searching = false;
      _notify();
    } on Object {
      if (!_current(token)) return;
      _found = const [];
      _searching = false;
      _failure = ProjectPickerFailure.search;
      _notify();
    }
  }

  bool _current(int token) =>
      !_disposed && !_dismissed && token == _searchToken;

  /// The directory searches and browsing start from: the shown project, or
  /// the server's default location.
  Future<String?> _baseDirectory() {
    final active = contexts.active;
    if (active != null) return Future.value(active);
    return _base ??= () async {
      final source = catalog.directorySource;
      if (source == null) return null;
      try {
        return (await source.location().result).canonicalDirectory;
      } on Object {
        _base = null;
        return null;
      }
    }();
  }

  /// Switches to the directory browser at the base directory.
  Future<void> startBrowsing() async {
    if (_disposed || _browsing) return;
    _browsing = true;
    _notify();
    final base = await _baseDirectory();
    if (_disposed || !_browsing) return;
    if (base == null) {
      _failure = ProjectPickerFailure.browse;
      _notify();
      return;
    }
    await browse(base);
  }

  void stopBrowsing() {
    if (!_browsing) return;
    _browseToken++;
    _browseRead?.cancel();
    _browsing = false;
    _browseLoading = false;
    _notify();
  }

  /// Lists the folders of [directory]; their paths are resolved against the
  /// location the server answered for.
  Future<void> browse(String directory) async {
    final source = catalog.directorySource;
    final base = await _baseDirectory();
    if (_disposed || !_browsing || source == null || base == null) return;
    final token = ++_browseToken;
    _browseRead?.cancel();
    _browseDirectory = directory;
    _browseLoading = true;
    _failure = ProjectPickerFailure.none;
    _notify();
    try {
      final read = source.listDirectory(base, path: directory);
      _browseRead = read;
      final entries = await read.result;
      if (_disposed || token != _browseToken) return;
      _browseEntries = [
        for (final entry in entries)
          if (entry.kind.known == FileKind.directory)
            resolveServerPath(
              entry.ref.project.canonicalDirectory,
              entry.ref.path,
            ),
      ]..removeWhere((path) => path == directory);
      _browseLoading = false;
      _notify();
    } on Object {
      if (_disposed || token != _browseToken) return;
      _browseEntries = const [];
      _browseLoading = false;
      _failure = ProjectPickerFailure.browse;
      _notify();
    }
  }

  /// Browses the parent of the folder shown.
  Future<void> browseUp() async {
    final parent = _browseDirectory == null
        ? null
        : serverPathParent(_browseDirectory!);
    if (parent != null) await browse(parent);
  }

  /// Opens [entry]: an open project is shown, a closed or known one is
  /// reopened, and a found folder is first resolved by the server.
  Future<bool> open(ProjectPickerEntry entry) => switch (entry.source) {
    ProjectPickerSource.open => _run(() => contexts.activate(entry.directory)),
    ProjectPickerSource.closed || ProjectPickerSource.server => _run(
      () => contexts.openContext(entry.directory),
    ),
    ProjectPickerSource.found => openPath(entry.directory),
  };

  /// Opens the absolute [path] typed or browsed to, as the directory the
  /// server keys it by; any folder works, Git or not. Only a [typed] path
  /// loses its surrounding spaces: a path the server returned is exact.
  Future<bool> openPath(String path, {bool typed = false}) => _run(() async {
    final source = catalog.directorySource;
    final target = typed && path != _completed ? path.trim() : path;
    if (source == null || !isAbsoluteServerPath(target)) return false;
    final location = await source.location(directory: target).result;
    if (_disposed || _dismissed) return false;
    return contexts.openContext(location.canonicalDirectory);
  });

  /// Forgets [directory] in the closed history until it is opened again.
  Future<bool> forget(String directory) =>
      _run(() => contexts.forgetClosed(directory), closes: false);

  Future<bool> _run(
    Future<bool> Function() action, {
    bool closes = true,
  }) async {
    if (_disposed || _dismissed || _opening) return false;
    _opening = true;
    _failure = ProjectPickerFailure.none;
    _notify();
    final submitted = _query;
    var done = false;
    try {
      done = await action();
    } on Object {
      done = false;
    } finally {
      _opening = false;
    }
    if (!_disposed) {
      // A refused change says so through the project notice instead, and a
      // failure is only shown for the query that was submitted.
      if (!done &&
          closes &&
          _query == submitted &&
          contexts.notice == ProjectContextNotice.none) {
        _failure = ProjectPickerFailure.open;
      }
      _notify();
    }
    return done;
  }

  void _catalogChanged() {
    if (_disposed || _dismissed) return;
    if (catalog.selectedProfile?.id != _profile) {
      _dismissed = true;
      _searchToken++;
      _browseToken++;
      _searchRead?.cancel();
      _browseRead?.cancel();
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _searchTimer?.cancel();
    _searchRead?.cancel();
    _browseRead?.cancel();
    catalog.removeListener(_catalogChanged);
    super.dispose();
  }
}

/// How well [directory] matches the lower-case [query]: 0 for an exact name
/// or path, 1–2 for a prefix of the name or path, 3–4 for a substring, 5–6
/// for the query's characters in order, or null for no match.
int? projectMatchScore(String directory, String query) {
  final path = directory.toLowerCase();
  final name = serverPathName(directory).toLowerCase();
  if (name == query || path == query) return 0;
  if (name.startsWith(query)) return 1;
  if (path.startsWith(query)) return 2;
  if (name.contains(query)) return 3;
  if (path.contains(query)) return 4;
  if (_ordered(name, query)) return 5;
  if (_ordered(path, query)) return 6;
  return null;
}

bool _ordered(String text, String query) {
  var at = 0;
  for (final unit in query.codeUnits) {
    at = text.indexOf(String.fromCharCode(unit), at);
    if (at < 0) return false;
    at++;
  }
  return true;
}
