import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';
import '../../shared/sessions/session_catalog_changes.dart';
import '../../shared/sessions/session_catalog_source.dart';
import '../hosts/hosts_controller.dart';
import 'session_ownership.dart';

class SessionsController extends ChangeNotifier {
  SessionsController({
    required this.hosts,
    required this.sourceFactory,
    this.changesFactory,
    DateTime Function()? now,
    this.liveDebounce = const Duration(milliseconds: 300),
    this.liveMinInterval = const Duration(seconds: 2),
  }) : _now = now ?? DateTime.now {
    hosts.addListener(_hostsChanged);
  }
  final HostsController hosts;
  final SessionCatalogFactory sourceFactory;

  /// The endpoint's session lifecycle feed, when the platform has one. It is
  /// the endpoint's single event stream, shared with the live sessions: the
  /// list never opens a second subscription.
  final SessionCatalogChangesFactory? changesFactory;

  /// How long a burst of changes collapses before the re-read starts.
  final Duration liveDebounce;

  /// The shortest interval between two automatic re-reads.
  final Duration liveMinInterval;
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
  // The live catalog: the feed, its signals and the bounded re-read they
  // trigger.
  SessionCatalogChanges? _changes;
  Future<void>? _changesAcquisition;
  int _changesToken = 0;
  // The feed's subscription belongs to the controller: it is cancelled in
  // [_closeChanges], which runs when the profile changes, when the
  // controller is disposed and when a newer feed replaces this one.
  StreamSubscription<SessionCatalogSignal>? _changesSubscription;
  Timer? _liveTimer;
  DateTime? _liveEarliestStart;
  // The display deadline of the loaded rows' ownership proofs: the label of a
  // row stops being shown when its proof goes stale, and the list does not
  // read the clock on its own.
  Timer? _ownershipTimer;
  bool _livePending = false;
  bool _liveConnected = false;
  bool _liveSuspended = false;
  bool _behind = false;
  int _liveFailures = 0;
  int _liveEpoch = 0;
  bool _quietRefreshing = false;
  // The pagination state the last automatic re-read observed.
  String? _liveCursor;
  Set<String> _liveCursors = const {};
  Set<String> _liveRequested = const {};
  int _livePagesRead = 0;
  bool _liveHasMore = false;
  bool _liveOmitted = false;
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

  /// The list may not reflect the endpoint: the last authoritative read did
  /// not succeed, or the feed that would trigger the next one dropped.
  bool get behind => _behind;

  /// The injected clock. The list never reads the wall clock on its own.
  DateTime get now => _now();

  /// An automatic re-read is running; it never shows the loading notice.
  bool get quietRefreshing => _quietRefreshing;
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
      _closeChanges();
    }
  }

  void _clear() {
    _ownershipTimer?.cancel();
    _ownershipTimer = null;
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
    // A manual page supersedes an automatic re-read in flight, so the page
    // the user just loaded is not replaced by an older traversal. A page
    // clicked with no automatic read in flight schedules no re-read.
    if (_quietRefreshing || _livePending) {
      _generation++;
      _livePending = true;
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
      _armOwnershipDeadline();
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
          _closeChanges();
        } else if (failure == null) {
          // A successful authoritative read lifts the suspension, clears the
          // notice and opens the feed.
          _liveFailures = 0;
          _liveSuspended = false;
          if (refresh) {
            // A head read reconciles the whole list; a page append does not.
            _behind = false;
          }
          unawaited(_ensureChanges());
        }
        if (_livePending && failure == null) {
          // A change that arrived during the read becomes one final read.
          _markLiveChange();
        }
        _notify();
      }
    }
  }

  /// Opens the endpoint's catalog feed for the selected profile.
  ///
  /// The feed shares the endpoint's single event stream, so the list never
  /// opens a second subscription. The acquisition is single-flight: two
  /// overlapping calls must not leave an orphan lease holding the endpoint's
  /// stream open after the profile is left. A platform without a feed keeps
  /// the list pull-only, which is not a failure.
  Future<void> _ensureChanges() async {
    final factory = changesFactory;
    final profile = _profile;
    if (factory == null || profile == null || _changes != null) return;
    final pending = _changesAcquisition;
    if (pending != null) return pending;
    final token = _changesToken;
    final acquisition = _acquireChanges(factory, profile, token);
    _changesAcquisition = acquisition;
    try {
      await acquisition;
    } finally {
      if (identical(_changesAcquisition, acquisition)) {
        _changesAcquisition = null;
      }
    }
  }

  Future<void> _acquireChanges(
    SessionCatalogChangesFactory factory,
    EndpointProfile profile,
    int token,
  ) async {
    final credential = _credential;
    if (credential == null) return;
    SessionCatalogChanges feed;
    try {
      feed = await factory(profile, credential);
    } on Object {
      // The endpoint has no live feed: the list stays pull-only.
      return;
    }
    if (_disposed || !identical(_profile, profile) || token != _changesToken) {
      // The profile changed while the feed was opening: the lease is released
      // instead of being kept.
      feed.close();
      return;
    }
    final previous = _changes;
    _changes = feed;
    final subscription = _changesSubscription;
    _changesSubscription = feed.signals.listen(
      _onLiveSignal,
      onDone: () => _onFeedDone(feed),
    );
    if (subscription != null) unawaited(subscription.cancel());
    if (previous != null) previous.close();
    // The feed opened after the list was read, and the server does not
    // replay: one catch-up read reconciles the window.
    _markLiveChange();
  }

  /// Releases the feed and every timer it armed.
  void _closeChanges() {
    // The token retires an acquisition that is still opening: the lease it
    // creates is released instead of being kept for a profile that is gone.
    _changesToken++;
    _changesAcquisition = null;
    _liveTimer?.cancel();
    _liveTimer = null;
    _livePending = false;
    _liveConnected = false;
    _quietRefreshing = false;
    _liveFailures = 0;
    _liveSuspended = false;
    _behind = false;
    _liveEarliestStart = null;
    unawaited(_changesSubscription?.cancel());
    _changesSubscription = null;
    final feed = _changes;
    _changes = null;
    feed?.close();
  }

  /// The feed ended: the list may be stale until the next read re-acquires it.
  void _onFeedDone(SessionCatalogChanges feed) {
    if (_disposed || !identical(_changes, feed)) return;
    _changes = null;
    feed.close();
    _behind = true;
    _notify();
  }

  void _onLiveSignal(SessionCatalogSignal signal) {
    if (_disposed) return;
    switch (signal) {
      case SessionCatalogChanged():
        _markLiveChange();
      case SessionCatalogConnection(:final connected):
        if (connected == _liveConnected) break;
        _liveConnected = connected;
        if (connected) {
          // A reconnect is not continuity: the list re-reads before it may
          // call itself current.
          _liveEpoch++;
          _markLiveChange();
        } else {
          _behind = true;
          _notify();
        }
    }
  }

  /// Arms the automatic re-read.
  ///
  /// The debounce is not reset by a later change: a burst collapses into one
  /// read, and the pending latch keeps at most one more.
  void _markLiveChange() {
    if (_disposed || _liveSuspended) return;
    _livePending = true;
    if (_liveTimer != null) return;
    _liveTimer = Timer(liveDebounce, _runLive);
  }

  /// Whether a quiet read still describes the current profile and feed.
  bool _quietCurrent(int generation, int epoch, SessionCatalogSource source) =>
      !_disposed &&
      generation == _generation &&
      epoch == _liveEpoch &&
      identical(source, _source);

  /// Runs the automatic re-read when the debounce and the cooldown allow it.
  Future<void> _runLive() async {
    _liveTimer = null;
    if (_disposed || _liveSuspended) return;
    if (loading || _quietRefreshing) {
      // A read is in flight: the pending latch becomes one final read.
      return;
    }
    final now = _now();
    final earliest = _liveEarliestStart;
    if (earliest != null && now.isBefore(earliest)) {
      // The cooldown still runs: keep the latch and wait for it.
      _livePending = true;
      _liveTimer = Timer(earliest.difference(now), _runLive);
      return;
    }
    if (!_livePending) return;
    _livePending = false;
    await _syncLive();
  }

  /// The authoritative re-read: from the head to the depth already loaded,
  /// applied all or nothing.
  ///
  /// The event is only a trigger: the rows always come from the server. The
  /// read never sets the loading or the stale flag, so the list neither
  /// flickers nor loses the expanded row while it follows the endpoint.
  Future<void> _syncLive() async {
    final source = _source;
    if (source == null || _profile == null) return;
    // The automatic read obeys the same fence as a manual one: an expired or
    // unreadable credential, a loading host list or a storage failure stops it.
    if (!_ready(createSource: false)) return;
    final generation = _generation;
    final epoch = _liveEpoch;
    // The re-read follows the depth already loaded, inside the existing
    // page and row limits.
    final depth = _pages.clamp(1, 10);
    _quietRefreshing = true;
    _notify();
    try {
      final rows = await _readLivePages(source, generation, epoch, depth);
      if (rows == null) return;
      final selected = _selectedSession;
      _sessions = List.unmodifiable(rows);
      _armOwnershipDeadline();
      // The expanded row survives only while the server still returns that
      // session, and it shows the row the server just returned.
      SessionSummary? fresh;
      if (selected != null) {
        for (final row in rows) {
          if (row.info.ref == selected.info.ref) {
            fresh = row;
            break;
          }
        }
      }
      _selectedSession = fresh;
      _cursor = _liveCursor;
      _received
        ..clear()
        ..addAll(_liveCursors);
      _requested
        ..clear()
        ..addAll(_liveRequested);
      _pages = _livePagesRead;
      limited =
          _liveOmitted ||
          (_liveHasMore && (rows.length >= 200 || _livePagesRead >= 10));
      hasMore = _liveHasMore && !limited;
      failure = null;
      stale = false;
      _liveFailures = 0;
      _behind = false;
    } on Object catch (error) {
      if (!_quietCurrent(generation, epoch, source)) return;
      if (error is SessionCatalogException &&
          error.failure == SessionCatalogFailure.authenticationRequired) {
        // The same path a manual read takes: the list is cleared, the
        // failure is recorded and the feed is released.
        _clear();
        failure = SessionCatalogFailure.authenticationRequired;
        source.close();
        _source = null;
        _closeChanges();
        return;
      }
      // The rows stay: a failed re-read marks the list behind, it never
      // empties it.
      _liveFailures++;
      _behind = true;
      if (_liveFailures >= 3 ||
          (error is SessionCatalogException &&
              error.failure == SessionCatalogFailure.rateLimited)) {
        _liveSuspended = true;
      }
    } finally {
      if (_quietCurrent(generation, epoch, source)) {
        _quietRefreshing = false;
        final backoff = 1 << (_liveFailures.clamp(0, 6));
        _liveEarliestStart = _now().add(liveMinInterval * backoff);
        if (_livePending) {
          // A change that arrived during the read becomes one final read.
          _markLiveChange();
        }
      } else if (identical(source, _source)) {
        // A manual page superseded this read on the same profile: the flag is
        // released, but the cooldown and the latch belong to the next read.
        _quietRefreshing = false;
      }
      _notify();
    }
  }

  /// The pages from the head to [depth], or null when the read was
  /// superseded. The traversal is validated exactly like a manual read.
  Future<List<SessionSummary>?> _readLivePages(
    SessionCatalogSource source,
    int generation,
    int epoch,
    int depth,
  ) async {
    final rows = <SessionSummary>[];
    final refs = <SessionRef>{};
    final cursors = <String>{};
    final requested = <String>{};
    String? cursor;
    var pages = 0;
    var omitted = false;
    for (var page = 0; page < depth; page++) {
      if (cursor != null) requested.add(cursor);
      final task = source.list(SessionQuery(limit: 50, cursor: cursor));
      final result = await task.result;
      if (!_quietCurrent(generation, epoch, source)) return null;
      if (result.items.length > 50) {
        throw const SessionCatalogException(
          SessionCatalogFailure.incompatibleResponse,
        );
      }
      for (final row in result.items) {
        if (row.info.ref.harnessRef != source.harness ||
            !refs.add(row.info.ref)) {
          throw const SessionCatalogException(
            SessionCatalogFailure.incompatibleResponse,
          );
        }
        if (rows.length < 200) {
          rows.add(row);
        } else {
          omitted = true;
        }
      }
      pages++;
      final next = result.nextCursor;
      if (next == null) {
        _liveCursor = null;
        _liveCursors = cursors;
        _liveRequested = requested;
        _livePagesRead = pages;
        _liveHasMore = false;
        _liveOmitted = omitted;
        return rows;
      }
      if (!cursors.add(next)) {
        throw const SessionCatalogException(SessionCatalogFailure.invalidCursor);
      }
      cursor = next;
    }
    _liveCursor = cursor;
    _liveCursors = cursors;
    _liveRequested = requested;
    _livePagesRead = pages;
    _liveHasMore = true;
    _liveOmitted = omitted;
    return rows;
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

  /// Arms the display deadline of the loaded rows' ownership proofs.
  ///
  /// The label of a row shows its ownership only while the proof is fresh,
  /// and the list is rebuilt by the controller's notifications. The timer
  /// wakes the list at the earliest deadline among the loaded rows, without
  /// any server traffic, so a label never outlives its proof.
  void _armOwnershipDeadline() {
    _ownershipTimer?.cancel();
    _ownershipTimer = null;
    Duration? delay;
    for (final session in _sessions) {
      final candidate = ownershipLabelDelay(
        session.info.ownership,
        now: _now(),
      );
      if (candidate == null) continue;
      if (delay == null || candidate < delay) delay = candidate;
    }
    if (delay == null) return;
    _ownershipTimer = Timer(delay, () {
      _ownershipTimer = null;
      if (_disposed) return;
      _notify();
      _armOwnershipDeadline();
    });
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _ownershipTimer?.cancel();
    _ownershipTimer = null;
    hosts.removeListener(_hostsChanged);
    _invalidate(closeSource: true);
    super.dispose();
  }
}
