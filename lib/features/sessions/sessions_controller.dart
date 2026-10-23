import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';
import '../../shared/sessions/session_actions.dart';
import '../../shared/sessions/session_activity.dart';
import '../../shared/sessions/session_catalog_changes.dart';
import '../../shared/sessions/session_catalog_source.dart';
import '../hosts/hosts_controller.dart';
import 'session_ownership.dart';

class SessionsController extends ChangeNotifier {
  SessionsController({
    required this.hosts,
    required this.sourceFactory,
    this.changesFactory,
    this.actionFactory,
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

  /// The factory of the session actions of the selected profile: the
  /// endpoint's own commands and the local hide.
  final SessionActionFactory? actionFactory;

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
  // The activity the endpoint last reported: which sessions run and which of
  // the open project group wait for the user. It is read after the rows and
  // on the feed's activity signal, one read at a time.
  SessionActivity _activity = const SessionActivity();
  bool _activityPending = false;
  bool _activityReading = false;
  bool _activityAgain = false;
  // The session the live pane shows in the foreground, and the last idle
  // transition sent as viewed for it.
  SessionRef? _showing;
  (SessionRef, DateTime)? _viewSent;
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
  // The session actions: the endpoint's own commands, the local hide and the
  // commands that are in flight.
  SessionActionSource? _actions;
  SessionActionSupport _actionSupport = const SessionActionSupport(
    SessionActionReason.versionUnverified,
  );
  final _pendingActions = <SessionRef>{};

  /// The outcome of the last command that did not go through, so the list can
  /// say so instead of closing the interaction silently.
  SessionActionOutcome? _actionFailure;

  /// A command whose answer was lost is waiting for its reconciliation.
  bool _actionPending = false;

  /// A create is in flight.
  bool _creating = false;
  SessionActionFilter _filter = SessionActionFilter.active;
  final _received = <String>{};
  final _requested = <String>{};
  List<SessionSummary> _sessions = const [];
  SessionSummary? _selectedSession;
  EndpointProfile? get selectedProfile => _profile;
  List<SessionSummary> get sessions {
    final source = _actions;
    if (source == null || _filter == SessionActionFilter.all) return _sessions;
    return _sessions
        .where((row) {
          final hidden = source.isHidden(row);
          return _filter == SessionActionFilter.hidden ? hidden : !hidden;
        })
        .toList(growable: false);
  }

  /// Which sessions the catalog shows.
  SessionActionFilter get filter => _filter;

  /// Shows the active, the hidden or every session.
  void setFilter(SessionActionFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    _notify();
  }

  /// The endpoint's support for the session actions.
  SessionActionSupport get actionSupport => _actionSupport;

  /// The outcome of the last command that did not go through.
  SessionActionOutcome? get actionFailure => _actionFailure;

  /// A command whose answer was lost is waiting for the re-read that
  /// reconciles it.
  bool get actionUncertain => _actionPending;

  /// A change is waiting for its re-read, so the loaded rows may be
  /// outdated and no action is offered.
  bool get reconciling => _livePending;

  /// Whether a command for this row is in flight.
  bool actionPending(SessionRef ref) => _pendingActions.contains(ref);

  /// Whether a create is in flight.
  bool get creating => _creating;

  /// Why the create is not offered, in the plan's precedence: the create in
  /// flight, then the endpoint's support, then the currency of the rows.
  SessionActionReason get createReason {
    if (_creating) return SessionActionReason.commandInFlight;
    final support = _actionSupport.reason;
    if (support != SessionActionReason.none) return support;
    if (!loaded || stale || behind) {
      return SessionActionReason.listNotCurrent;
    }
    return SessionActionReason.none;
  }

  /// The canonical directories the endpoint reported, in the order the server
  /// first showed them. They are the projects the user can start a session in.
  List<String> get knownDirectories {
    final seen = <String>{};
    final directories = <String>[];
    for (final row in _sessions) {
      final directory = row.info.project?.canonicalDirectory;
      if (directory == null || !seen.add(directory)) continue;
      directories.add(directory);
    }
    return directories;
  }

  /// The unread marker of a row, from the endpoint's own epochs.
  SessionViewState viewState(SessionSummary row) =>
      _actions?.viewState(row) ?? SessionViewState.unknown;

  /// The marks of a row, each from its own observed source: the pending
  /// lists of the row's own location, the endpoint's active map and its
  /// unread marker. A part that was not observed adds no mark, and a list
  /// that is not the endpoint's current answer claims no activity.
  List<SessionActivityMark> activityMarks(SessionSummary row) {
    final ref = row.info.ref;
    final current = !stale && !behind;
    final directory = row.info.project?.canonicalDirectory;
    return [
      if (current &&
          directory != null &&
          directory == _activity.directory &&
          (_activity.waiting?.contains(ref) ?? false))
        SessionActivityMark.needsYou,
      if (current && (_activity.running?.contains(ref) ?? false))
        SessionActivityMark.running,
      if (viewState(row) == SessionViewState.unread) SessionActivityMark.unread,
    ];
  }

  /// The live pane shows [ref] while the app is in the foreground: its
  /// unread mark is cleared through the endpoint's own view command.
  void showing(SessionRef ref) {
    if (_disposed || _showing == ref) return;
    _showing = ref;
    _viewShown();
  }

  /// The live pane no longer shows [ref].
  void leave(SessionRef ref) {
    if (_showing == ref) _showing = null;
  }

  /// Marks the shown session's idle transition as viewed when the endpoint
  /// reports it unread, once per transition. The user did not ask for it, so
  /// a refusal leaves the mark and the list says nothing; the row action
  /// stays the way to retry.
  void _viewShown() {
    final ref = _showing;
    if (_disposed || ref == null) return;
    SessionSummary? row;
    for (final candidate in _sessions) {
      if (candidate.info.ref == ref) row = candidate;
    }
    final idle = row?.view?.idleAt;
    if (row == null ||
        idle == null ||
        viewState(row) != SessionViewState.unread ||
        _viewSent == (ref, idle) ||
        _actionSupport.reason != SessionActionReason.none ||
        _pendingActions.contains(ref) ||
        stale ||
        behind ||
        _livePending) {
      return;
    }
    final shown = row;
    unawaited(
      _run(shown, (source) {
        _viewSent = (ref, idle);
        return source.markViewed(shown);
      }, quiet: true),
    );
  }

  /// Whether the local hide can be read and written.
  bool get hideAvailable => _actions?.hideAvailable ?? false;

  /// Whether the local hide state could not be read.
  bool get hideUnreadable => _actions?.hideUnreadable ?? false;

  /// Whether the row is hidden in CodeWalk.
  bool isHidden(SessionSummary row) => _actions?.isHidden(row) ?? false;
  SessionSummary? get selectedSession => _selectedSession;

  /// The project group the user chose, held as a record so the group of the
  /// sessions the server attributed to no project can be chosen too. It
  /// lasts until the list is cleared.
  ({ProjectRef? project})? _chosenProject;

  /// The project group whose sessions the list shows: the chosen one while
  /// the shown rows still hold it, otherwise the first group the server
  /// returned. Null when no row is shown.
  ({ProjectRef? project})? get selectedProject {
    final rows = sessions;
    final chosen = _chosenProject;
    if (chosen != null &&
        rows.any((row) => row.info.project == chosen.project)) {
      return chosen;
    }
    return rows.isEmpty ? null : (project: rows.first.info.project);
  }

  /// Shows the sessions of [project]. Choosing the shown fallback records it,
  /// so a chosen group that returns later does not take its place again.
  void selectProject(ProjectRef? project) {
    if (_disposed || _chosenProject == (project: project)) return;
    _chosenProject = (project: project);
    _notify();
    // The pending lists belong to the shown group's location.
    unawaited(_syncActivity());
  }

  /// Reads one session of the selected server directly, for a link to a
  /// session outside the loaded rows. Null while that server has no source.
  SessionReadTask? read(SessionRef ref) {
    final source = _source;
    if (_disposed || source == null || ref.harnessRef != source.harness) {
      return null;
    }
    return source.read(ref);
  }

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

  /// The feed's state, for device evidence: whether a feed is held, the
  /// failed automatic re-reads in a row and whether they stopped.
  @visibleForTesting
  ({bool feed, int failures, bool suspended}) get liveDiagnostics => (
    feed: _changes != null,
    failures: _liveFailures,
    suspended: _liveSuspended,
  );
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
      _actions?.close();
      _actions = null;
      // The new endpoint has not been observed yet.
      _actionSupport = const SessionActionSupport(
        SessionActionReason.versionUnverified,
      );
      _closeChanges();
      _activity = const SessionActivity();
      _activityPending = false;
      // Only a request of the new endpoint outlives a read of this one.
      _activityAgain = false;
      _viewSent = null;
    }
  }

  void _clear() {
    _actionFailure = null;
    _actionPending = false;
    _ownershipTimer?.cancel();
    _ownershipTimer = null;
    _sessions = const [];
    _activity = const SessionActivity();
    _selectedSession = null;
    _chosenProject = null;
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
      if (createSource) {
        _source ??= sourceFactory(current, credential!);
        _actions ??= actionFactory?.call(current, credential!);
        if (_actions != null) unawaited(_probeActions());
      }
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
      // The read reconciled whatever the last command left uncertain, and it
      // observes the endpoint's support again when the last observation was
      // not definitive.
      _actionPending = false;
      unawaited(_probeActions());
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
            unawaited(_syncActivity());
          }
          unawaited(_ensureChanges());
          _viewShown();
        }
        if (_livePending && failure == null) {
          // A change that arrived during the read becomes one final read.
          _markLiveChange();
        } else if (_activityPending && failure == null) {
          _markLiveChange(rows: false);
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
    _activityPending = false;
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
      case SessionActivityChanged():
        _markLiveChange(rows: false);
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

  Future<void> _probeActions() async {
    final source = _actions;
    if (source == null) return;
    final support = await source.support();
    if (_disposed || !identical(source, _actions)) return;
    _actionSupport = support;
    _notify();
    _viewShown();
  }

  /// Creates a session at the given canonical directory.
  ///
  /// The receipt is an admission: the new session reaches the list with the
  /// next authoritative read, and an uncertain create is reconciled there and
  /// never resent.
  Future<SessionActionOutcome> create({
    required String directory,
    String? title,
  }) async {
    final source = _actions;
    if (source == null) return SessionActionOutcome.unavailable;
    if (_creating) return SessionActionOutcome.unavailable;
    if (!_ready(createSource: false) ||
        _actionSupport.reason != SessionActionReason.none ||
        !loaded ||
        stale ||
        behind ||
        _livePending) {
      // Nothing was sent, so the list keeps no failure notice: the dialog
      // says why the create was refused and the user retries.
      return SessionActionOutcome.unavailable;
    }
    _creating = true;
    _actionFailure = null;
    _notify();
    try {
      final outcome = await source.create(directory: directory, title: title);
      if (!identical(source, _actions)) {
        // The profile changed while the create was in flight.
        return outcome;
      }
      if (outcome == SessionActionOutcome.accepted ||
          outcome == SessionActionOutcome.uncertain) {
        // The effect is observed by the authoritative re-read. An uncertain
        // create is reconciled there and never sent again.
        _markLiveChange();
        if (outcome == SessionActionOutcome.uncertain) {
          _actionPending = true;
        }
      } else {
        _actionFailure = outcome;
      }
      return outcome;
    } finally {
      _creating = false;
      _notify();
    }
  }

  /// Renames the row. The effect is observed by the authoritative re-read.
  Future<SessionActionOutcome> rename(SessionSummary row, String title) =>
      _run(row, (source) => source.rename(row, title));

  /// Deletes the row and its children.
  Future<SessionActionOutcome> delete(SessionSummary row) =>
      _run(row, (source) => source.delete(row));

  /// Copies the row's history into a new root session.
  Future<SessionActionOutcome> fork(SessionSummary row) =>
      _run(row, (source) => source.fork(row));

  /// Marks the row's idle transition as viewed.
  Future<SessionActionOutcome> markViewed(SessionSummary row) =>
      _run(row, (source) => source.markViewed(row));

  /// The direct children of the row, for the cascade warning. Null when the
  /// count could not be read.
  Future<int?> childCount(SessionSummary row) async =>
      _actions?.childCount(row);

  /// Hides the row in CodeWalk, or shows it again.
  Future<bool> setHidden(SessionSummary row, {required bool hidden}) async {
    final source = _actions;
    if (source == null) return false;
    final written = await source.setHidden(row, hidden: hidden);
    if (!identical(source, _actions)) {
      // The profile changed while the local hide was in flight.
      return written;
    }
    if (written) {
      _actionFailure = null;
    } else {
      _actionFailure = SessionActionOutcome.unavailable;
    }
    _notify();
    return written;
  }

  /// Runs one command for a row.
  ///
  /// The row is never patched: the effect is observed by the quiet
  /// authoritative re-read, and a refused or uncertain command leaves the
  /// rows exactly as the endpoint last answered.
  /// Runs one command on [row]. A [quiet] command was not asked for by the
  /// user, so a refusal or a failure leaves no notice.
  Future<SessionActionOutcome> _run(
    SessionSummary row,
    Future<SessionActionOutcome> Function(SessionActionSource source) command, {
    bool quiet = false,
  }) async {
    final source = _actions;
    if (source == null) return SessionActionOutcome.unavailable;
    if (_pendingActions.contains(row.info.ref)) {
      return SessionActionOutcome.unavailable;
    }
    // The intent is validated again right before the send: the profile, the
    // credential, the endpoint's support, the currency of the rows and the
    // row's own membership can all have changed while a dialog was open.
    if (!_ready(createSource: false) ||
        _actionSupport.reason != SessionActionReason.none ||
        stale ||
        behind ||
        _livePending ||
        !_sessions.any((current) => current.info.ref == row.info.ref)) {
      // The intent is no longer authorized, and the user asked for it: the
      // list says so instead of closing the interaction silently.
      if (!quiet) {
        _actionFailure = SessionActionOutcome.unavailable;
        _notify();
      }
      return SessionActionOutcome.unavailable;
    }
    _pendingActions.add(row.info.ref);
    if (!quiet) _actionFailure = null;
    _notify();
    try {
      final outcome = await command(source);
      if (!identical(source, _actions)) {
        // The profile changed while the command was in flight: the result
        // belongs to the old profile and must not touch the new one.
        return outcome;
      }
      if (outcome == SessionActionOutcome.accepted ||
          outcome == SessionActionOutcome.uncertain) {
        // The effect is observed by the authoritative re-read. An uncertain
        // command is reconciled there, never replayed.
        _markLiveChange();
      }
      if (quiet) return outcome;
      if (outcome == SessionActionOutcome.rejected ||
          outcome == SessionActionOutcome.unavailable) {
        _actionFailure = outcome;
      } else if (outcome == SessionActionOutcome.uncertain) {
        // The command may already have been applied: the re-read reconciles
        // it, and the list waits instead of calling it a failure.
        _actionPending = true;
      }
      return outcome;
    } on ArgumentError {
      // A local refusal, such as a title over the bound.
      if (!quiet) _actionFailure = SessionActionOutcome.unavailable;
      return SessionActionOutcome.unavailable;
    } finally {
      _pendingActions.remove(row.info.ref);
      _notify();
    }
  }

  /// Arms the automatic re-read.
  ///
  /// The debounce is not reset by a later change: a burst collapses into one
  /// read, and the pending latch keeps at most one more.
  ///
  /// A change of the list re-reads the rows and then the activity; a change
  /// of the activity alone re-reads only the activity.
  void _markLiveChange({bool rows = true}) {
    if (_disposed || _liveSuspended) return;
    if (rows) {
      _livePending = true;
    } else {
      _activityPending = true;
    }
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
      if (!_activityPending) _livePending = true;
      _liveTimer = Timer(earliest.difference(now), _runLive);
      return;
    }
    if (_livePending) {
      // The rows re-read reads the activity after them.
      _livePending = false;
      _activityPending = false;
      await _syncLive();
      return;
    }
    if (!_activityPending) return;
    _activityPending = false;
    _liveEarliestStart = now.add(liveMinInterval);
    await _syncActivity();
    if (!_disposed && (_livePending || _activityPending)) {
      _markLiveChange(rows: _livePending);
    }
  }

  /// Reads the activity of the selected profile: the running sessions and
  /// the sessions of the shown project group that wait for the user. One read
  /// runs at a time; a request during it becomes one more read. A read of a
  /// profile that was left is dropped, a request the new profile made during
  /// it still runs, and a failure leaves its part unknown without touching
  /// the rows.
  Future<void> _syncActivity() async {
    final source = _source;
    if (_disposed || source == null) return;
    if (_activityReading) {
      _activityAgain = true;
      return;
    }
    _activityReading = true;
    try {
      do {
        _activityAgain = false;
        final directory = selectedProject?.project?.canonicalDirectory;
        final activity = await source.activity(directory: directory);
        if (_disposed || !identical(source, _source)) return;
        _activity = activity;
        _notify();
      } while (_activityAgain);
    } finally {
      _activityReading = false;
      if (_activityAgain && !identical(source, _source)) {
        _activityAgain = false;
        unawaited(_syncActivity());
      }
    }
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
      // The re-read reconciled whatever the last command left uncertain, and
      // it observes the endpoint's support again when the last observation
      // was not definitive.
      _actionPending = false;
      unawaited(_probeActions());
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
      _viewShown();
      // The activity is read after the rows it marks, which are shown
      // without waiting for it.
      unawaited(_syncActivity());
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
        } else if (_activityPending) {
          _markLiveChange(rows: false);
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
        throw const SessionCatalogException(
          SessionCatalogFailure.invalidCursor,
        );
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
