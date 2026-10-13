import 'dart:async';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';
import '../../shared/sessions/session_history_source.dart';
import '../hosts/hosts_controller.dart';

/// Owns only this auxiliary read-only view, not the live session lifecycle.
class SessionHistoryController extends ChangeNotifier {
  SessionHistoryController({
    required this.hosts,
    required this.profile,
    required this.summary,
    required this.sourceFactory,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    hosts.addListener(_hostsChanged);
  }
  final HostsController hosts;
  final EndpointProfile profile;
  final SessionSummary summary;
  final SessionHistoryFactory sourceFactory;
  final DateTime Function() _now;
  SessionRef get session => summary.info.ref;
  EndpointCredential? _credential;
  SessionHistorySource? _source;
  SessionHistoryTask? _task;
  Timer? _expiry;
  bool _disposed = false;
  int _generation = 0;
  int _pages = 0;
  String? _cursor;
  String? version;
  final _cursors = <String>{};
  List<TimelineItem> items = const [];
  SessionHistoryFailure? failure;
  bool loading = false;
  bool loaded = false;
  bool stale = false;
  bool limited = false;
  bool get hasMore => _cursor != null && !limited && !stale;

  EndpointCredential? _currentCredential() {
    if (_disposed || hosts.loading || hosts.storageError) return null;
    for (final current in hosts.profiles) {
      if (current.id == profile.id &&
          current.endpoint == profile.endpoint &&
          !hosts.credentialUnreadable(current)) {
        final credential = hosts.credentialFor(current);
        if (credential != null &&
            (credential.expiresAt == null ||
                _now().toUtc().isBefore(credential.expiresAt!))) {
          return credential;
        }
      }
    }
    return null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _invalidate() {
    _generation++;
    _task?.cancel();
    _task = null;
    _source?.close();
    _source = null;
    _expiry?.cancel();
    _expiry = null;
    loading = false;
    _cursor = null;
    _cursors.clear();
    _pages = 0;
  }

  void _clear() {
    items = const [];
    version = null;
    loaded = stale = limited = false;
  }

  void _hostsChanged() {
    if (_disposed) return;
    final credential = _currentCredential();
    if (credential == null || _credential?.matches(credential) != true) {
      _invalidate();
      _clear();
      failure = hosts.loading || hosts.storageError
          ? SessionHistoryFailure.unavailable
          : SessionHistoryFailure.authenticationRequired;
      _notify();
    }
  }

  Future<void> refresh() async {
    if (_disposed) return;
    final credential = _currentCredential();
    _invalidate();
    if (credential == null) {
      _clear();
      failure = hosts.loading || hosts.storageError
          ? SessionHistoryFailure.unavailable
          : SessionHistoryFailure.authenticationRequired;
      _notify();
      return;
    }
    _credential = credential;
    stale = loaded;
    limited = false;
    failure = null;
    try {
      _source = sourceFactory(profile, credential, session);
      if (_source!.session != session) {
        throw const SessionHistoryException(
          SessionHistoryFailure.incompatibleResponse,
        );
      }
      if (credential.expiresAt case final deadline?) {
        _expiry = Timer(deadline.difference(_now().toUtc()), _hostsChanged);
      }
    } on Object catch (error) {
      _source?.close();
      _source = null;
      failure = error is SessionHistoryException
          ? error.failure
          : SessionHistoryFailure.connection;
      _notify();
      return;
    }
    await _read(refresh: true);
  }

  Future<void> loadMore() async {
    if (_disposed || loading || !hasMore || _source == null) return;
    if (_credential?.matches(_currentCredential()) != true) {
      _hostsChanged();
      return;
    }
    await _read(refresh: false);
  }

  Future<void> _read({required bool refresh}) async {
    final generation = _generation;
    final source = _source!;
    SessionHistoryTask? task;
    bool current() =>
        !_disposed && generation == _generation && identical(source, _source);
    loading = true;
    failure = null;
    _notify();
    try {
      task = source.read(cursor: refresh ? null : _cursor);
      _task = task;
      final result = await task.result;
      if (!current()) return;
      if (_credential?.matches(_currentCredential()) != true) {
        _hostsChanged();
        return;
      }
      final page = result.page;
      final ids = <ItemId>{};
      if (result.session != session ||
          result.version.isEmpty ||
          (!refresh && result.version != version) ||
          page.items.length > 500 ||
          page.items.any(
            (i) =>
                i.source.harness != session.harnessRef ||
                i.source.version != result.version ||
                !ids.add(i.id),
          )) {
        throw const SessionHistoryException(
          SessionHistoryFailure.incompatibleResponse,
        );
      }
      if (page.nextCursor != null &&
          (_cursors.contains(page.nextCursor) || page.nextCursor!.isEmpty)) {
        throw const SessionHistoryException(
          SessionHistoryFailure.invalidCursor,
        );
      }
      final merged = refresh ? <TimelineItem>[] : items.toList();
      final existing = merged.map((i) => i.id).toSet();
      var omitted = false;
      for (final item in page.items) {
        if (existing.add(item.id)) {
          if (merged.length < 500) {
            merged.add(item);
          } else {
            omitted = true;
          }
        }
      }
      items = List.unmodifiable(merged);
      version = result.version;
      _pages++;
      if (page.nextCursor case final next?) _cursors.add(next);
      _cursor = page.nextCursor;
      limited =
          omitted || (_cursor != null && (items.length >= 500 || _pages >= 10));
      loaded = true;
      stale = false;
    } on Object catch (error) {
      if (!current()) return;
      failure = error is SessionHistoryException
          ? error.failure
          : SessionHistoryFailure.connection;
      if ({
        SessionHistoryFailure.authenticationRequired,
        SessionHistoryFailure.notFound,
        SessionHistoryFailure.sourceChanged,
      }.contains(failure)) {
        _invalidate();
        _clear();
        _notify();
      } else if (failure == SessionHistoryFailure.invalidCursor) {
        _cursor = null;
      }
    } finally {
      if (current()) {
        _task = null;
        loading = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    hosts.removeListener(_hostsChanged);
    _invalidate();
    super.dispose();
  }
}
