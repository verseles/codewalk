import 'dart:async';
import 'dart:math' as math;

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';
import '../../shared/sessions/session_actions.dart';
import '../../shared/sessions/session_activity.dart';
import '../../shared/sessions/session_catalog_changes.dart';
import '../../shared/sessions/session_catalog_source.dart';
import '../hosts/hosts_controller.dart';
import 'session_context_refresh.dart';
import 'session_list_projection.dart';
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
  // The longest wait between automatic retries: liveMinInterval * 2^6.
  static const _liveMaxBackoff = 6;
  bool _behind = false;
  int _liveFailures = 0;
  // Feeds that ended before they reported a connection: a feed that cannot
  // stay open backs off like a failed re-read instead of looping (#467).
  int _feedEnds = 0;
  DateTime? _feedLiveSince;
  // The last drop already counted its short live period.
  bool _dropCounted = false;
  // A feed that stayed live for one whole longest wait ended normally, so a
  // feed can never cycle faster than the cap.
  Duration get _feedSteady => liveMinInterval * (1 << _liveMaxBackoff);
  // A recovery asked for during a read runs when that read ends.
  bool _recoverAfterRead = false;
  // A failed head read retries by itself after a wait that grows.
  Timer? _readRetry;
  int _readFailures = 0;
  int _liveEpoch = 0;
  bool _quietRefreshing = false;
  // The pagination state the last automatic re-read observed.
  String? _liveCursor;
  Set<String> _liveCursors = const {};
  Set<String> _liveRequested = const {};
  int _livePagesRead = 0;
  bool _liveHasMore = false;
  bool _liveExhausted = false;
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

  /// The project context whose sessions the list reads, or null before one
  /// is chosen, when the list reads every session of the server.
  String? _directory;

  /// The open contexts of the selected server, and the head rows last read
  /// for each one the list does not show.
  Set<String> _openDirectories = const {};
  final _snapshots = <String, SessionContextSnapshot>{};
  late final _contextRefresh = SessionContextRefresh(
    read: _readContext,
    publish: _publishContext,
    now: _now,
  );

  /// The last page read ended the list: the endpoint keeps a next cursor on
  /// a short last page, so a short page ends it too.
  bool _exhausted = false;
  final _received = <String>{};
  final _requested = <String>{};
  List<SessionSummary> _sessions = const [];
  SessionSummary? _selectedSession;
  EndpointProfile? get selectedProfile => _profile;
  List<SessionSummary> get sessions {
    final source = _actions;
    if (source == null || _filter == SessionActionFilter.all) return _sessions;
    // Hiding a parent hides its loaded descendants too.
    return filterSessions(
      _sessions,
      effectivelyHidden(_sessions, source.isHidden),
      _filter,
    );
  }

  /// Every loaded row, before the filter applies: the server's order.
  List<SessionSummary> get loadedSessions => _sessions;

  /// The rows of [rows] hidden in effect: hidden, or under a hidden parent.
  Set<SessionRef> hiddenIn(Iterable<SessionSummary> rows) {
    final source = _actions;
    return source == null ? const {} : effectivelyHidden(rows, source.isHidden);
  }

  /// The project context the list reads, or null while none is chosen.
  String? get directory => _directory;

  /// Shows the sessions of the project context at [directory]: the rows last
  /// read for it at once, marked as previous results while its head is read
  /// again, so a switch never waits for the network. Null reads every session
  /// of the server.
  void setDirectory(String? directory) {
    if (_disposed || _profile == null || directory == _directory) return;
    _stash();
    _invalidate();
    _directory = directory;
    final cached = directory == null ? null : _snapshots.remove(directory);
    _sessions = cached?.rows ?? const [];
    _selectedSession = null;
    _cursor = null;
    _received.clear();
    _requested.clear();
    _pages = 0;
    hasMore = limited = false;
    _exhausted = false;
    loaded = cached != null;
    failure = null;
    // The pending lists belong to the location of the shown context.
    _activity = const SessionActivity();
    _armOwnershipDeadline();
    _trackContexts();
    _notify();
    unawaited(_refreshShown());
  }

  /// Keeps the shown rows as the snapshot of the context the list leaves.
  void _stash() {
    final directory = _directory;
    if (directory == null ||
        !loaded ||
        failure != null ||
        !_openDirectories.contains(directory)) {
      return;
    }
    _snapshots[directory] = SessionContextSnapshot(
      _sessions,
      complete: _exhausted && !limited,
    );
  }

  /// The open contexts of the selected server. A context that is no longer
  /// open forgets its rows; the ones the list does not show keep their head
  /// rows current for their counts and recent sessions.
  void setOpenDirectories(Iterable<String> directories) {
    final next = directories.toSet();
    if (_disposed || setEquals(next, _openDirectories)) return;
    _openDirectories = next;
    _snapshots.removeWhere(
      (directory, _) => !_openDirectories.contains(directory),
    );
    _trackContexts();
    _notify();
  }

  void _trackContexts() {
    if (_source == null) return;
    _contextRefresh.track([
      for (final directory in _openDirectories)
        if (directory != _directory) directory,
    ], known: _snapshots.keys.toSet());
  }

  /// The rows of the open context at [directory]: the shown rows for the
  /// shown context, otherwise its head rows last read, or null when none
  /// were read yet.
  List<SessionSummary>? contextRows(String directory) => directory == _directory
      ? (loaded ? _sessions : null)
      : _snapshots[directory]?.rows;

  /// Whether [contextRows] are every session of the context, as the endpoint
  /// last answered.
  bool contextComplete(String directory) => directory == _directory
      ? loaded && !stale && failure == null && _exhausted && !limited
      : _snapshots[directory]?.complete ?? false;

  /// Whether [ref] is a row of the shown list, the only rows a command can
  /// run on.
  bool lists(SessionRef ref) => _sessions.any((row) => row.info.ref == ref);

  /// The loaded row of [ref], in the shown rows or in another open
  /// context's rows, so a session of another project opens without a read.
  SessionSummary? findSession(SessionRef ref) {
    for (final rows in [_sessions, for (final s in _snapshots.values) s.rows]) {
      for (final row in rows) {
        if (row.info.ref == ref) return row;
      }
    }
    return null;
  }

  SessionCatalogTask _readContext(String directory) {
    final source = _source;
    if (_disposed || source == null || hosts.loading || hosts.storageError) {
      throw const SessionCatalogException(SessionCatalogFailure.cancelled);
    }
    return source.list(_query(source, null, directory));
  }

  void _publishContext(String directory, SessionContextSnapshot snapshot) {
    final source = _source;
    if (_disposed ||
        source == null ||
        directory == _directory ||
        !_openDirectories.contains(directory) ||
        snapshot.rows.any((row) => _foreign(row, source, directory))) {
      return;
    }
    _snapshots[directory] = snapshot;
    _notify();
  }

  /// One page of the list: the server's rows, or one context's.
  SessionQuery _query(
    SessionCatalogSource source,
    String? cursor,
    String? directory,
  ) => SessionQuery(
    limit: 50,
    cursor: cursor,
    project: directory == null
        ? null
        : ProjectRef(source.harness.host, directory),
  );

  /// A row of another server, or of another context than the one read.
  static bool _foreign(
    SessionSummary row,
    SessionCatalogSource source,
    String? directory,
  ) =>
      row.info.ref.harnessRef != source.harness ||
      (directory != null && row.info.project?.canonicalDirectory != directory);

  /// The source of the selected server for the project and directory reads,
  /// or null while it is not ready.
  /// The server's default agent and model for a draft in [directory]; null
  /// while no source is ready, so the caller asks again later.
  Future<DraftDefaults?> draftDefaults(String directory) async {
    final source = directorySource;
    if (source == null) return null;
    return source.draftDefaults(directory: directory);
  }

  SessionCatalogSource? get directorySource {
    if (_disposed ||
        hosts.loading ||
        hosts.storageError ||
        _profile == null ||
        hosts.pendingBindingChange == _profile!.id) {
      return null;
    }
    return _ready() ? _source : null;
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
    if (!loaded || stale || behind || _livePending || _quietRefreshing) {
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

  /// Whether [row] runs or waits for the user, or null while the endpoint's
  /// relevant activity is not known: an unknown activity is not idle.
  bool? busy(SessionSummary row) {
    if (stale ||
        behind ||
        loading ||
        _livePending ||
        _quietRefreshing ||
        _activityPending ||
        _activityReading) {
      return null;
    }
    final ref = row.info.ref;
    final waitingKnown =
        row.info.project?.canonicalDirectory == _activity.directory &&
        _activity.waiting != null;
    if ((_activity.running?.contains(ref) ?? false) ||
        (waitingKnown && _activity.waiting!.contains(ref))) {
      return true;
    }
    return _activity.running != null && waitingKnown ? false : null;
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
    // A chosen context is shown even before it holds a session.
    if (_scopeChoice case final scope?) return scope;
    final rows = sessions;
    final chosen = _chosenProject;
    if (chosen != null &&
        rows.any((row) => row.info.project == chosen.project)) {
      return chosen;
    }
    return rows.isEmpty ? null : (project: rows.first.info.project);
  }

  /// Whether the user chose the shown project group, rather than the list
  /// falling back to the first one.
  bool get projectChosen => chosenProject != null;

  /// The explicit project choice, including a temporarily absent group.
  ({ProjectRef? project})? get chosenProject => _scopeChoice ?? _chosenProject;

  /// Whether the shown group is the explicit choice, rather than a fallback
  /// shown while that choice is absent from the loaded rows.
  bool get selectedProjectWasChosen =>
      chosenProject != null && chosenProject == selectedProject;

  /// The shown project context as a project choice.
  ({ProjectRef? project})? get _scopeChoice {
    final profile = _profile;
    final directory = _directory;
    return profile == null || directory == null
        ? null
        : (project: ProjectRef(HostId(profile.id), directory));
  }

  /// Shows the sessions of [project]. Choosing the shown fallback records it,
  /// so a chosen group that returns later does not take its place again.
  void selectProject(ProjectRef? project) {
    if (_disposed ||
        _directory != null ||
        _chosenProject == (project: project)) {
      return;
    }
    _chosenProject = (project: project);
    _notify();
    // The pending lists belong to the shown group's location.
    unawaited(_syncActivity());
  }

  /// Reads one session of the selected server directly, for a link to a
  /// session outside the loaded rows. Null while that server has no source.
  SessionReadTask? read(SessionRef ref) => sourceFor(ref)?.read(ref);

  /// The selected server's source for reads about [ref], such as its
  /// children; null while that server has none or is changing.
  SessionCatalogSource? sourceFor(SessionRef ref) {
    final source = _source;
    if (_disposed ||
        source == null ||
        hosts.loading ||
        hosts.storageError ||
        hosts.pendingBindingChange == ref.host.value ||
        ref.harnessRef != source.harness) {
      return null;
    }
    return source;
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

  /// A failed head read waits to try again by itself (#467).
  bool get retrying => _readRetry != null;

  /// The injected clock. The list never reads the wall clock on its own.
  DateTime get now => _now();

  /// An automatic re-read is running; it never shows the loading notice.
  bool get quietRefreshing => _quietRefreshing;

  /// The feed's state, for device evidence: whether a feed is held, the
  /// failed automatic re-reads in a row, the feeds that ended before they
  /// connected, and when the next automatic re-read may start.
  @visibleForTesting
  ({bool feed, int failures, int feedEnds, DateTime? nextRead})
  get liveDiagnostics => (
    feed: _changes != null,
    failures: _liveFailures,
    feedEnds: _feedEnds,
    nextRead: _liveEarliestStart,
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
      // The retry streak and a latched recovery belong to this endpoint.
      _readRetry?.cancel();
      _readRetry = null;
      _readFailures = 0;
      _recoverAfterRead = false;
      _source?.close();
      _source = null;
      _actions?.close();
      _actions = null;
      // The new endpoint has not been observed yet.
      _actionSupport = const SessionActionSupport(
        SessionActionReason.versionUnverified,
      );
      _closeChanges();
      _contextRefresh.cancel();
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
    _snapshots.clear();
    _cursor = null;
    _received.clear();
    _requested.clear();
    _pages = 0;
    loaded = stale = limited = hasMore = _exhausted = false;
    failure = null;
  }

  /// Leaves the contexts of the server the list no longer reads.
  void _forgetContexts() {
    _directory = null;
    _openDirectories = const {};
    _contextRefresh.cancel();
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
    // Only the end of a server-list reload resumes what the reload stopped;
    // other host notifications (health checks) must not skip a wait.
    final reloaded = _hostLoading;
    _hostLoading = false;
    final old = _profile;
    if (old != null) {
      final current = _find(old.id);
      final credential = current == null ? null : hosts.credentialFor(current);
      if (hosts.storageError ||
          current == null ||
          !current.sameBinding(old) ||
          !_credentialMatches(credential) ||
          hosts.credentialUnreadable(current)) {
        _invalidate(closeSource: true);
        _clear();
        if (current == null || hosts.storageError) _forgetContexts();
        _profile = hosts.storageError ? null : current;
        _credential = credential;
        if (current != null && !hosts.storageError && !_usable(credential)) {
          failure = SessionCatalogFailure.authenticationRequired;
        } else if (current != null && !hosts.storageError) {
          // A repaired password or a new credential reads the list again;
          // the removed Refresh used to be the way (#467).
          scheduleMicrotask(() {
            if (!_disposed && identical(_profile, current)) {
              unawaited(refresh());
            }
          });
        }
      } else {
        _profile = current;
        // A server-list reload interrupted the head retry or the automatic
        // re-read; the list resumes them now that it can read again.
        if (reloaded && !loading) {
          // The reload cancelled any read and marked the rows previous; with
          // no Refresh left (#467), the list reads again by itself, keeping
          // its retry streak.
          if (failure != SessionCatalogFailure.authenticationRequired &&
              (!loaded || failure != null)) {
            // Nothing current is shown: the head read, at once.
            _readRetry?.cancel();
            _readRetry = null;
            unawaited(_refreshShown());
          } else if (failure == null && (stale || _livePending)) {
            // A loaded list re-reads quietly, like a server change, so
            // opening Servers shows no loading bar.
            _liveTimer?.cancel();
            _liveTimer = null;
            _liveEarliestStart = null;
            _markLiveChange();
          }
        }
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
    // The server already in use keeps its list and its source.
    if (_profile?.id == id && _source != null) return;
    final profile = _find(id);
    _invalidate(closeSource: true);
    _clear();
    if (_profile?.id != id) _forgetContexts();
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
        !current.sameBinding(_profile!) ||
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

  /// Tries now what the list would otherwise try later or not at all: the
  /// app returned, the network changed or the server answers again (#467).
  /// A list that failed to load reads again, and one that fell behind re-reads
  /// without waiting out its retry delay; a rejected credential still needs
  /// the user.
  void recover() {
    if (_disposed || _profile == null) return;
    // The other open projects' passes stop after repeated failures; a
    // recovery restarts them, as the removed Refresh did.
    _contextRefresh.refresh();
    if (loading || _quietRefreshing) {
      // The read in flight decides: if it fails, this recovery runs then.
      _recoverAfterRead = true;
      if (_quietRefreshing) _livePending = true;
      return;
    }
    if (failure != null) {
      if (failure != SessionCatalogFailure.authenticationRequired) {
        _readRetry?.cancel();
        _readRetry = null;
        unawaited(refresh());
      }
      return;
    }
    // A feed that could not open is tried again with the list.
    if (loaded && _changes == null) unawaited(_ensureChanges());
    if (!_behind) return;
    // The wait armed by the last failure is dropped, not added to.
    _liveTimer?.cancel();
    _liveTimer = null;
    _liveEarliestStart = null;
    _markLiveChange();
  }

  /// A failed head read that may pass is tried again after a wait that
  /// doubles from liveMinInterval up to the cap, or at once when a recovery
  /// was asked for during it; a rejected credential never is.
  void _afterFailedRead() {
    final failed = failure;
    final now = _recoverAfterRead;
    _recoverAfterRead = false;
    if (!_passing(failed)) {
      // A recovery asked for during the read still gets its one read.
      if (now && failed != SessionCatalogFailure.authenticationRequired) {
        _recoverLater();
      }
      return;
    }
    _readFailures = failed == SessionCatalogFailure.rateLimited
        ? _liveMaxBackoff
        : math.min(_readFailures + 1, _liveMaxBackoff);
    _armReadRetry(
      now ? Duration.zero : liveMinInterval * (1 << _readFailures),
    );
  }

  /// Closes the feed's current live period: one that lasted a whole longest
  /// wait proves the feed works, so the streak of failing feeds starts over
  /// (its feed's end is then the first of a new streak); a shorter one,
  /// ended by a drop or by the feed's end, counts as a failing feed, once.
  /// Returns whether a short period was counted as a failing feed.
  bool _endLivePeriod() {
    final since = _feedLiveSince;
    _feedLiveSince = null;
    if (since == null) return false;
    if (!_now().isBefore(since.add(_feedSteady))) {
      _feedEnds = 0;
      return false;
    }
    _feedEnds++;
    return true;
  }

  /// Runs a latched recovery after the current read, for this profile only.
  void _recoverLater() {
    final profile = _profile;
    scheduleMicrotask(() {
      if (!_disposed && identical(_profile, profile)) recover();
    });
  }

  static bool _passing(SessionCatalogFailure? failure) => switch (failure) {
    SessionCatalogFailure.connection ||
    SessionCatalogFailure.timeout ||
    SessionCatalogFailure.unavailable ||
    SessionCatalogFailure.rateLimited => true,
    _ => false,
  };

  /// One pending head retry at a time. It reads the head only, keeping the
  /// streak, so the wait keeps growing while the cause lasts.
  void _armReadRetry(Duration wait) {
    _readRetry?.cancel();
    _readRetry = Timer(wait, () {
      _readRetry = null;
      if (_disposed || loading || !_passing(failure)) return;
      // The server list may still be loading; its end re-arms the retry.
      unawaited(_refreshShown());
    });
  }

  /// Reads the list again from its head; the open contexts the list does
  /// not show are read again too, even after their reads stopped failing.
  Future<void> refresh() {
    if (!_disposed) _contextRefresh.refresh();
    return _refreshShown();
  }

  Future<void> _refreshShown() {
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
    final directory = _directory;
    bool current() =>
        !_disposed &&
        generation == _generation &&
        identical(source, _source) &&
        identical(task, _task);
    try {
      task = source.list(_query(source, cursor, directory));
      _task = task;
      final page = await task.result;
      if (!current()) return;
      final refs = <SessionRef>{};
      if (page.items.length > 50 ||
          page.items.any(
            (row) =>
                _foreign(row, source, directory) || !refs.add(row.info.ref),
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
      _exhausted = next == null || page.items.length < 50;
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
          // A successful authoritative read ends the wait between retries,
          // clears the notice and opens the feed.
          _liveFailures = 0;
          _readFailures = 0;
          if (refresh) {
            // A head read reconciles the whole list; a page append does not.
            // A dropped feed still misses changes, so it stays behind.
            if (_changes == null || _liveConnected) _behind = false;
            unawaited(_syncActivity());
            _trackContexts();
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
        if (failure != null && refresh) {
          _afterFailedRead();
        } else if (_recoverAfterRead) {
          // A recovery that arrived during a page or a successful read runs
          // now that the read is over.
          _recoverAfterRead = false;
          _recoverLater();
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
    _readRetry?.cancel();
    _readRetry = null;
    _livePending = false;
    _activityPending = false;
    _liveConnected = false;
    _quietRefreshing = false;
    _liveFailures = 0;
    _feedEnds = 0;
    _feedLiveSince = null;
    _dropCounted = false;
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
    // The next feed has not connected yet: its own report decides.
    _liveConnected = false;
    // A feed that stayed live for a while ended normally; one that dies soon
    // after it connects keeps the streak growing. A short period its drop
    // already counted is not counted again.
    if (!_endLivePeriod() && !_dropCounted) _feedEnds++;
    _dropCounted = false;
    // The next read acquires a new feed; it does not wait for the user.
    _markLiveChange();
    _notify();
  }

  void _onLiveSignal(SessionCatalogSignal signal) {
    if (_disposed) return;
    switch (signal) {
      case SessionCatalogChanged():
        _markLiveChange();
        _contextRefresh.changed();
      case SessionActivityChanged():
        _markLiveChange(rows: false);
      case SessionCatalogConnection(:final connected):
        if (connected == _liveConnected) break;
        _liveConnected = connected;
        // A live period ends at a disconnect; the next one starts over.
        if (connected) {
          _feedLiveSince = _now();
          _dropCounted = false;
        } else {
          _dropCounted = _endLivePeriod();
        }
        if (connected) {
          // A reconnect is not continuity: the list re-reads before it may
          // call itself current.
          _liveEpoch++;
          _markLiveChange();
          _contextRefresh.changed();
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
  Future<SessionCreateResult> create({
    required String directory,
    String? title,
    Selection? initialSelection,
  }) async {
    final source = _actions;
    if (source == null || _creating) {
      return const SessionCreateResult(SessionActionOutcome.unavailable);
    }
    if (!_ready(createSource: false) ||
        _actionSupport.reason != SessionActionReason.none ||
        !loaded ||
        stale ||
        behind ||
        _livePending ||
        _quietRefreshing) {
      // Nothing was sent, so the list keeps no failure notice: the dialog
      // says why the create was refused and the user retries.
      return const SessionCreateResult(SessionActionOutcome.unavailable);
    }
    _creating = true;
    _actionFailure = null;
    _notify();
    try {
      final result = await source.create(
        directory: directory,
        title: title,
        initialSelection: initialSelection,
      );
      final outcome = result.outcome;
      if (!identical(source, _actions)) {
        // The profile changed while the create was in flight.
        return result;
      }
      if (outcome == SessionActionOutcome.accepted ||
          outcome == SessionActionOutcome.uncertain) {
        // The effect is observed by the authoritative re-read. An uncertain
        // create is reconciled there and never sent again.
        _markLiveChange();
        if (outcome == SessionActionOutcome.uncertain) _actionPending = true;
      } else {
        _actionFailure = outcome;
      }
      return result;
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
    if (_disposed) return;
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
    if (_disposed) return;
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
    // Like the rows, the activity is not read while the servers reload; the
    // reload end re-arms it.
    if (hosts.loading) return;
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
    // The change is kept, so the end of a server-list reload re-reads it.
    if (!_ready(createSource: false)) {
      if (hosts.loading) _livePending = true;
      return;
    }
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
      _exhausted = _liveExhausted;
      limited =
          _liveOmitted ||
          (_liveHasMore && (rows.length >= 200 || _livePagesRead >= 10));
      hasMore = _liveHasMore && !limited;
      failure = null;
      stale = false;
      _liveFailures = 0;
      // A dropped feed still misses changes, so the list stays behind until
      // it reconnects.
      if (_changes == null || _liveConnected) _behind = false;
      // A feed that ended is acquired again once the list reads.
      unawaited(_ensureChanges());
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
      if (error is SessionCatalogException &&
          error.failure == SessionCatalogFailure.rateLimited) {
        // The server asked for room: the longest wait, not a stop.
        _liveFailures = math.max(_liveFailures, _liveMaxBackoff);
      }
      // The list tries again by itself after the wait below, which grows
      // with each failure (#467); nothing waits for a manual refresh.
      _livePending = true;
    } finally {
      if (_quietCurrent(generation, epoch, source)) {
        _quietRefreshing = false;
        final streak = math.max(_liveFailures, _feedEnds);
        final backoff = 1 << (streak.clamp(0, _liveMaxBackoff));
        _liveEarliestStart = _recoverAfterRead
            ? null
            : _now().add(liveMinInterval * backoff);
        _recoverAfterRead = false;
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
        // A reconnect superseded it instead: the change it marked runs after
        // the same cooldown a completed read sets, so reconnects that keep
        // superseding reads are still spaced by the streak; a recovery asked
        // for during the read skips that wait, as in the completed branch.
        // A server-list reload superseded it by generation only: its end
        // already chose the wait, which this late read must not undo.
        if (!loading && (_livePending || _activityPending)) {
          if (_recoverAfterRead) {
            _liveEarliestStart = null;
          } else if (epoch != _liveEpoch) {
            final streak = math.max(_liveFailures, _feedEnds);
            _liveEarliestStart = _now().add(
              liveMinInterval * (1 << streak.clamp(0, _liveMaxBackoff)),
            );
          }
          _recoverAfterRead = false;
          _markLiveChange(rows: _livePending);
        }
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
    final directory = _directory;
    for (var page = 0; page < depth; page++) {
      if (cursor != null) requested.add(cursor);
      final task = source.list(_query(source, cursor, directory));
      final result = await task.result;
      if (!_quietCurrent(generation, epoch, source)) return null;
      if (result.items.length > 50) {
        throw const SessionCatalogException(
          SessionCatalogFailure.incompatibleResponse,
        );
      }
      for (final row in result.items) {
        if (_foreign(row, source, directory) || !refs.add(row.info.ref)) {
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
      _liveExhausted = next == null || result.items.length < 50;
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
    _contextRefresh.cancel();
    super.dispose();
  }
}
