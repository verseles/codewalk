import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';
import '../../shared/sessions/session_catalog_source.dart';
import '../hosts/hosts_controller.dart';

class SessionsController extends ChangeNotifier {
  SessionsController({
    required this.hosts,
    required this.sourceFactory,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    hosts.addListener(_hostsChanged);
  }
  final HostsController hosts;
  final SessionCatalogFactory sourceFactory;
  final DateTime Function() _now;
  EndpointProfile? _profile;
  EndpointCredential? _credential;
  SessionCatalogSource? _source;
  SessionCatalogTask? _task;
  Future<void>? _initialization;
  Future<void>? _readFuture;
  bool _refreshing = false;
  bool _disposed = false;
  bool _hostLoading = false;
  int _generation = 0;
  int _pages = 0;
  String? _cursor;
  final _received = <String>{};
  final _requested = <String>{};
  List<SessionSummary> _sessions = const [];
  SessionSummary? _selectedSession;
  EndpointProfile? get selectedProfile => _profile;
  List<SessionSummary> get sessions => _sessions;
  SessionSummary? get selectedSession => _selectedSession;
  SessionCatalogFailure? failure;
  bool loading = false;
  bool hasMore = false;
  bool limited = false;
  bool stale = false;
  bool loaded = false;
  bool get refreshing => loading && _refreshing;
  Future<void> initialize() => _initialization ??= hosts.load();
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _invalidate({bool closeSource = false}) {
    _generation++;
    _task?.cancel();
    _task = null;
    _readFuture = null;
    _refreshing = false;
    loading = false;
    if (closeSource) {
      _source?.close();
      _source = null;
    }
  }

  void _clear() {
    _sessions = const [];
    _selectedSession = null;
    _cursor = null;
    _received.clear();
    _requested.clear();
    _pages = 0;
    loaded = stale = limited = hasMore = false;
    failure = null;
  }

  EndpointProfile? _find(String id) {
    for (final profile in hosts.profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  void _hostsChanged() {
    if (_disposed) return;
    if (hosts.loading) {
      if (!_hostLoading) {
        _hostLoading = true;
        _invalidate();
        stale = loaded || _sessions.isNotEmpty;
      }
      _notify();
      return;
    }
    _hostLoading = false;
    final old = _profile;
    if (old != null) {
      final current = _find(old.id);
      final credential = current == null ? null : hosts.credentialFor(current);
      if (hosts.storageError ||
          current == null ||
          current.endpoint != old.endpoint ||
          !_credentialMatches(credential) ||
          hosts.credentialUnreadable(current)) {
        _invalidate(closeSource: true);
        _clear();
        _profile = hosts.storageError ? null : current;
        _credential = credential;
        if (current != null && !hosts.storageError && !_usable(credential)) {
          failure = SessionCatalogFailure.authenticationRequired;
        }
      } else {
        _profile = current;
      }
    }
    _notify();
  }

  bool _credentialMatches(EndpointCredential? credential) =>
      _credential?.matches(credential) == true;
  bool _usable(EndpointCredential? credential) =>
      credential != null &&
      (credential.expiresAt == null ||
          _now().toUtc().isBefore(credential.expiresAt!));

  Future<void> selectProfile(String id) async {
    if (_disposed || hosts.loading || hosts.storageError) return;
    final profile = _find(id);
    _invalidate(closeSource: true);
    _clear();
    _profile = profile;
    _credential = profile == null ? null : hosts.credentialFor(profile);
    _notify();
    if (profile != null) await refresh();
  }

  bool _ready({bool createSource = true}) {
    if (_disposed || hosts.loading || hosts.storageError || _profile == null) {
      return false;
    }
    final current = _find(_profile!.id);
    final credential = current == null ? null : hosts.credentialFor(current);
    if (current == null ||
        current.endpoint != _profile!.endpoint ||
        !_credentialMatches(credential)) {
      _hostsChanged();
      return false;
    }
    if (hosts.credentialUnreadable(current) || !_usable(credential)) {
      _invalidate(closeSource: true);
      _clear();
      failure = SessionCatalogFailure.authenticationRequired;
      _notify();
      return false;
    }
    try {
      if (createSource) _source ??= sourceFactory(current, credential!);
      return true;
    } on SessionCatalogException catch (error) {
      failure = error.failure;
    } on Object {
      failure = SessionCatalogFailure.connection;
    }
    _notify();
    return false;
  }

  Future<void> refresh() {
    if (_disposed) return Future.value();
    if (!_ready()) return Future.value();
    if (_refreshing && loading) return _readFuture ?? Future.value();
    _invalidate();
    _cursor = null;
    _received.clear();
    _requested.clear();
    _pages = 0;
    hasMore = limited = false;
    stale = loaded || _sessions.isNotEmpty;
    return _start(refresh: true);
  }

  Future<void> loadMore() {
    if (!_ready(createSource: false) ||
        loading ||
        !hasMore ||
        limited ||
        stale ||
        !_ready()) {
      return Future.value();
    }
    return _start(refresh: false);
  }

  Future<void> _start({required bool refresh}) {
    final source = _source!;
    final generation = _generation;
    final cursor = refresh ? null : _cursor;
    loading = true;
    _refreshing = refresh;
    failure = null;
    if (cursor != null) _requested.add(cursor);
    final future = _read(source, generation, cursor, refresh);
    _readFuture = future;
    _notify();
    return future;
  }

  Future<void> _read(
    SessionCatalogSource source,
    int generation,
    String? cursor,
    bool refresh,
  ) async {
    SessionCatalogTask? task;
    bool current() =>
        !_disposed &&
        generation == _generation &&
        identical(source, _source) &&
        identical(task, _task);
    try {
      task = source.list(SessionQuery(limit: 50, cursor: cursor));
      _task = task;
      final page = await task.result;
      if (!current()) return;
      final refs = <SessionRef>{};
      if (page.items.length > 50 ||
          page.items.any(
            (row) =>
                row.info.ref.harnessRef != source.harness ||
                !refs.add(row.info.ref),
          )) {
        throw const SessionCatalogException(
          SessionCatalogFailure.incompatibleResponse,
        );
      }
      final next = page.nextCursor;
      if (next != null &&
          (_received.contains(next) || _requested.contains(next))) {
        throw const SessionCatalogException(
          SessionCatalogFailure.invalidCursor,
        );
      }
      final merged = refresh ? <SessionSummary>[] : _sessions.toList();
      final existing = merged.map((row) => row.info.ref).toSet();
      var omitted = false;
      for (final row in page.items) {
        if (existing.add(row.info.ref)) {
          if (merged.length < 200) {
            merged.add(row);
          } else {
            omitted = true;
          }
        }
      }
      _sessions = List.unmodifiable(merged);
      if (refresh) _selectedSession = null;
      _pages++;
      if (next != null) _received.add(next);
      _cursor = next;
      limited =
          omitted || (next != null && (merged.length >= 200 || _pages >= 10));
      hasMore = next != null && !limited;
      stale = false;
      loaded = true;
    } on Object catch (error) {
      if (!current()) return;
      failure = error is SessionCatalogException
          ? error.failure
          : SessionCatalogFailure.connection;
      if (failure == SessionCatalogFailure.authenticationRequired) {
        _clear();
        failure = SessionCatalogFailure.authenticationRequired;
      } else if (failure == SessionCatalogFailure.invalidCursor) {
        hasMore = false;
        _cursor = null;
      }
    } finally {
      if (current()) {
        _task = null;
        loading = false;
        _refreshing = false;
        _readFuture = null;
        if (failure == SessionCatalogFailure.authenticationRequired) {
          source.close();
          _source = null;
        }
        _notify();
      }
    }
  }

  void inspect(SessionRef ref) {
    if (_disposed) return;
    if (_selectedSession?.info.ref == ref) {
      _selectedSession = null;
    } else {
      _selectedSession = null;
      for (final row in _sessions) {
        if (row.info.ref == ref) {
          _selectedSession = row;
          break;
        }
      }
    }
    _notify();
  }

  void close() => dispose();
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    hosts.removeListener(_hostsChanged);
    _invalidate(closeSource: true);
    super.dispose();
  }
}
