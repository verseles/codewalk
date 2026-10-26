import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/widgets.dart';

import '../../platform/sessions/project_workspace_store.dart';
import '../../platform/sessions/session_tabs_store.dart';
import '../../shared/sessions/session_catalog_source.dart';
import 'session_live_controller.dart';
import 'session_tab_reconciler.dart';
import 'sessions_controller.dart';

/// What opening a session did to its tab.
enum SessionTabOpen { opened, focused, full, unsaved }

/// The open session tabs of the workspace.
///
/// Every tab is keyed by its full [SessionRef], so two servers with the same
/// session id never share a tab. The tabs of the selected server follow its
/// recent sessions (see [reconcileSessionTabs]); the pins of [workspace]
/// keep theirs. The live view of a tab stays open while the user visits
/// others, up to [maxWarm] of them; a restored tab opens its view only when
/// shown.
class SessionTabsController extends ChangeNotifier {
  SessionTabsController({
    required SessionTabsStore store,
    SessionsController? catalog,
    ProjectWorkspaceStore? workspace,
    DateTime Function()? now,
  }) : _store = store,
       _catalog = catalog,
       _workspace = workspace,
       _now = now ?? DateTime.now {
    _store
      ..addListener(_notify)
      ..addListener(_scheduleReconcile);
    _catalog?.addListener(_validate);
    _catalog?.addListener(_scheduleReconcile);
    // A removed server clears the list before it is noticed there.
    _catalog?.hosts.addListener(_validate);
    _workspace?.addListener(_scheduleReconcile);
  }

  /// The live views kept open beside the shown one.
  static const maxWarm = 8;

  final SessionTabsStore _store;
  final SessionsController? _catalog;
  final ProjectWorkspaceStore? _workspace;
  final DateTime Function() _now;

  /// The live views, least recently shown first.
  final _warm = <SessionRef, SessionLiveController>{};
  final _checked = <SessionRef>{};
  final _reads = <SessionRef, SessionReadTask>{};
  final _bindings = <String, EndpointProfile>{};
  final _removed = <String>[];

  /// The sessions their server said no longer exist.
  final _deleted = <SessionRef>{};

  /// The tabs a close or an undo is changing, left alone meanwhile.
  final _frozen = <SessionRef>{};

  /// The projects just opened, by server, that get one tab if they hold none.
  final _fallbacks = <(String, String)>{};
  Timer? _expiry;
  bool _reconcileScheduled = false;
  bool _disposed = false;
  bool _launched = false;

  Future<void> initialize() => _store.initialize();

  bool get loaded => _store.loaded;

  /// The saved tabs could not be read; they are kept as they were and no
  /// tab is saved.
  bool get unreadable => _store.unreadable;
  bool get hasPersistenceError => _store.hasPersistenceError;

  List<SessionTab> get tabs => _store.state.tabs;

  SessionRef? selectedFor(HostId host) => _store.state.selected[host];

  /// The tabs of [project] on [host], in visual order.
  List<SessionTab> visible(HostId host, ProjectRef? project) => [
    for (final tab in tabs)
      if (tab.ref.host == host && tab.project == project) tab,
  ];

  /// The tabs of [host], the selected one first and then the most recently
  /// opened; ties keep the visual order.
  List<SessionTab> recent(HostId host) {
    final candidates = [
      for (final tab in tabs)
        if (tab.ref.host == host) tab,
    ];
    final selected = selectedFor(host);
    final current = candidates.where((tab) => tab.ref == selected).firstOrNull;
    final rest = [
      for (final tab in candidates)
        if (tab.ref != selected) tab,
    ];
    final order = {for (final (i, tab) in candidates.indexed) tab.ref: i};
    rest.sort((a, b) {
      final recency = b.lastOpenedAtMs.compareTo(a.lastOpenedAtMs);
      return recency != 0 ? recency : order[a.ref]!.compareTo(order[b.ref]!);
    });
    return [?current, ...rest];
  }

  /// The tab to show when the app opens on the workspace home: the selected
  /// tab of the server whose tab was opened last. Only the first call of a
  /// launch gets it, so returning to the home later stays there.
  SessionRef? takeLaunchTab() {
    final tab = launchTab;
    _launched = true;
    return tab;
  }

  /// The tab [takeLaunchTab] would return, without spending it.
  SessionRef? get launchTab {
    if (_launched) return null;
    final latest = tabs.fold<SessionTab?>(
      null,
      (latest, tab) =>
          latest == null || tab.lastOpenedAtMs > latest.lastOpenedAtMs
          ? tab
          : latest,
    );
    return latest == null ? null : selectedFor(latest.ref.host);
  }

  /// Whether the tab of [ref] left because its server said the session no
  /// longer exists; a tab closed or expired here did not.
  bool deleted(SessionRef ref) => _deleted.contains(ref);

  /// The titles of the tabs dropped because their session no longer exists,
  /// once each, for one notice.
  List<String> takeRemoved() {
    final removed = List<String>.of(_removed);
    _removed.clear();
    return removed;
  }

  /// Adds the tab of [summary], or focuses it when it is open already, and
  /// makes it the selected tab of its server.
  Future<SessionTabOpen> open(SessionSummary summary) async {
    if (_disposed) return SessionTabOpen.unsaved;
    final ref = summary.info.ref;
    var result = SessionTabOpen.unsaved;
    final saved = await _store.update((state) {
      final index = state.tabs.indexWhere((tab) => tab.ref == ref);
      if (index < 0 && state.tabs.length >= SessionTabsStore.maxTabs) {
        result = SessionTabOpen.full;
        return null;
      }
      final project = summary.info.project;
      final tab = SessionTab(
        ref: ref,
        // A project of another server never groups this tab.
        project: project?.host == ref.host ? project : null,
        title: SessionTabsStore.boundTitle(summary.info.title),
        lastOpenedAtMs: _nextOpened(state),
        updatedAtMs: _latest(
          index < 0 ? null : state.tabs[index].updatedAtMs,
          summary.updatedAt?.millisecondsSinceEpoch,
        ),
      );
      final next = [...state.tabs];
      if (index < 0) {
        next.add(tab);
      } else {
        next[index] = tab;
      }
      result = index < 0 ? SessionTabOpen.opened : SessionTabOpen.focused;
      // Opening a closed session ends its close.
      return state
          .unsuppressing(ref)
          .copyWith(tabs: next, selected: {...state.selected, ref.host: ref});
    });
    if (!saved && result != SessionTabOpen.full) return SessionTabOpen.unsaved;
    if (result == SessionTabOpen.opened) {
      _checked.remove(ref);
      _deleted.remove(ref);
    }
    return result;
  }

  static int? _latest(int? a, int? b) =>
      a == null || (b != null && b > a) ? b : a;

  /// A strictly later time than every tab, so the most recent order never
  /// ties on a coarse or rewound clock.
  int _nextOpened(SessionTabsState state) {
    final latest = state.tabs.fold<int>(
      0,
      (latest, tab) =>
          tab.lastOpenedAtMs > latest ? tab.lastOpenedAtMs : latest,
    );
    final now = _now().millisecondsSinceEpoch;
    return now > latest ? now : latest + 1;
  }

  /// Closes the tab of [ref] and its live view; the session stays on the
  /// server and its tab stays closed until it is opened again or updated.
  /// A pinned tab is unpinned first, and [unpinned] says so. [removed] is
  /// false when this call removed nothing: the tab was gone already, another
  /// close or undo of it was running, or a change was not saved, in which
  /// case its pin is put back. When the tab was the selected tab of its
  /// server, the next tab of its project is selected, else the previous
  /// one, and returned as [next].
  Future<({bool removed, SessionRef? next, bool unpinned})> close(
    SessionRef ref,
  ) async {
    const none = (removed: false, next: null, unpinned: false);
    final tab = tabs.where((tab) => tab.ref == ref).firstOrNull;
    if (_disposed || tab == null || !_frozen.add(ref)) return none;
    try {
      final pin = _pinOf(tab);
      var unpinned = false;
      if (pin != null) {
        final result = await _setPin(pin, ref, pinned: false);
        if (result == null) return none;
        unpinned = result;
      }
      final closedAt = _now().millisecondsSinceEpoch;
      final row = _catalog?.findSession(ref);
      final (:removed, :selectedAfter) = await _remove(
        {ref},
        suppress: (tab) => SessionTabSuppression(
          ref: tab.ref,
          project: tab.project,
          closedAtMs: closedAt,
          updatedAtMs: _latest(
            tab.updatedAtMs,
            row?.updatedAt?.millisecondsSinceEpoch,
          ),
        ),
      );
      if (removed.isEmpty) {
        // The pin goes back once; a failure there is reported by the store.
        if (unpinned) await _setPin(pin!, ref, pinned: true);
        return none;
      }
      return (removed: true, next: selectedAfter[ref], unpinned: unpinned);
    } finally {
      _frozen.remove(ref);
      _scheduleReconcile();
    }
  }

  /// The server and directory of [tab] when it is pinned there.
  ({String profile, String directory})? _pinOf(SessionTab tab) {
    final project = tab.project;
    final workspace = _workspace;
    if (project == null || workspace == null) return null;
    final profile = tab.ref.host.value;
    final directory = project.canonicalDirectory;
    return workspace.workspace(profile).isPinned(directory, tab.ref.storageKey)
        ? (profile: profile, directory: directory)
        : null;
  }

  /// Pins or unpins [ref] at [pin]: true when this call changed it, false
  /// when it was so already, null when it could not be saved.
  Future<bool?> _setPin(
    ({String profile, String directory}) pin,
    SessionRef ref, {
    required bool pinned,
  }) async {
    final result = await _workspace?.setPinned(
      pin.profile,
      pin.directory,
      ref.storageKey,
      pinned: pinned,
    );
    return switch (result) {
      ProjectStoreResult.saved => true,
      ProjectStoreResult.unchanged => false,
      _ => null,
    };
  }

  /// Closes every tab of the project context at [directory] of server
  /// [host], and their live views; the sessions stay on the server. The
  /// tabs are chosen at the store's turn, so a tab opened meanwhile closes
  /// too.
  Future<bool> closeContext(String host, String directory) async {
    if (_disposed) return false;
    var matched = false;
    bool inContext(SessionRef ref, ProjectRef? project) =>
        ref.host.value == host && project?.canonicalDirectory == directory;
    _fallbacks.remove((host, directory));
    final (:removed, selectedAfter: _) = await _remove(
      const {},
      where: (tab) {
        final closes = inContext(tab.ref, tab.project);
        matched |= closes;
        return closes;
      },
      // A project opened again starts afresh.
      forget: (entry) => inContext(entry.ref, entry.project),
    );
    // Unreadable tabs are neither known nor closed.
    if (_store.unreadable) return false;
    // Nothing of the project was open, or every tab of it closed.
    return !matched || removed.isNotEmpty;
  }

  /// Puts the closed [tab] back at [index] of the strip; [select] makes it
  /// the selected tab of its server again, and [pin] pins it again first.
  /// False when it is open again already, the tabs are full, another close
  /// or undo of it is running or nothing was saved; a pin put back for it
  /// is then taken back.
  Future<bool> reopen(
    SessionTab tab, {
    required int index,
    required bool select,
    bool pin = false,
  }) async {
    final project = tab.project;
    if (_disposed || !_frozen.add(tab.ref)) return false;
    try {
      final at = pin && project != null
          ? (profile: tab.ref.host.value, directory: project.canonicalDirectory)
          : null;
      var pinned = false;
      if (at != null) {
        final result = await _setPin(at, tab.ref, pinned: true);
        if (result == null) return false;
        pinned = result;
      }
      final saved = await _store.update((state) {
        if (state.tabs.any((other) => other.ref == tab.ref)) return null;
        if (state.tabs.length >= SessionTabsStore.maxTabs) return null;
        final next = [...state.tabs];
        next.insert(index.clamp(0, next.length), tab);
        return state
            .unsuppressing(tab.ref)
            .copyWith(
              tabs: next,
              selected: select
                  ? {...state.selected, tab.ref.host: tab.ref}
                  : state.selected,
            );
      });
      if (!saved) {
        if (pinned) await _setPin(at!, tab.ref, pinned: false);
        return false;
      }
      // A tab back in the strip is checked against its server again, now:
      // an answer that came while it was closed dropped nothing.
      _checked.remove(tab.ref);
      _deleted.remove(tab.ref);
      _validate();
      return true;
    } finally {
      _frozen.remove(tab.ref);
      _scheduleReconcile();
    }
  }

  /// The tab a server selects after its selected tab [ref] closed: the next
  /// tab of the same project, else the previous one.
  static SessionRef? _neighbour(SessionTabsState state, SessionRef ref) {
    final closed = state.tabs.where((tab) => tab.ref == ref).firstOrNull;
    if (closed == null) return null;
    final set = [
      for (final tab in state.tabs)
        if (tab.ref.host == ref.host && tab.project == closed.project) tab,
    ];
    final at = set.indexWhere((tab) => tab.ref == ref);
    if (at + 1 < set.length) return set[at + 1].ref;
    if (at > 0) return set[at - 1].ref;
    return null;
  }

  /// Removes the tabs of [refs], or the tabs [where] picks, at the store's
  /// turn, recording each as closed when [suppress] is given; the closed
  /// records [forget] picks are dropped in the same write. A removed
  /// selected tab hands its selection to its neighbour. The removed tabs,
  /// empty when nothing was saved, and the tab each removed selected tab
  /// handed its selection to.
  Future<
    ({List<SessionTab> removed, Map<SessionRef, SessionRef?> selectedAfter})
  >
  _remove(
    Set<SessionRef> refs, {
    bool Function()? isCurrent,
    bool Function(SessionTab tab)? where,
    SessionTabSuppression Function(SessionTab tab)? suppress,
    bool Function(SessionTabSuppression entry)? forget,
  }) async {
    var removed = <SessionTab>[];
    final selectedAfter = <SessionRef, SessionRef?>{};
    final saved = await _store.update((state) {
      if (isCurrent?.call() == false) return null;
      removed = [
        for (final tab in state.tabs)
          if (where?.call(tab) ?? refs.contains(tab.ref)) tab,
      ];
      final kept = [
        for (final entry in state.suppressed)
          if (forget?.call(entry) != true) entry,
      ];
      if (removed.isEmpty && kept.length == state.suppressed.length) {
        return null;
      }
      selectedAfter.clear();
      var current = state.copyWith(suppressed: kept);
      for (final tab in removed) {
        final ref = tab.ref;
        final selected = {...current.selected};
        if (selected[ref.host] == ref) {
          final next = _neighbour(current, ref);
          selectedAfter[ref] = next;
          if (next == null) {
            selected.remove(ref.host);
          } else {
            selected[ref.host] = next;
          }
        }
        current = current.copyWith(
          tabs: [
            for (final other in current.tabs)
              if (other.ref != ref) other,
          ],
          selected: selected,
        );
        if (suppress != null) current = current.suppressing(suppress(tab));
      }
      return current;
    });
    if (!saved) {
      return (
        removed: const <SessionTab>[],
        selectedAfter: const <SessionRef, SessionRef?>{},
      );
    }
    for (final tab in removed) {
      _release(_warm.remove(tab.ref));
    }
    return (removed: removed, selectedAfter: selectedAfter);
  }

  /// The live view of [ref], kept open while other tabs are shown. [create]
  /// makes it the first time. Opening a tab of another server closes the
  /// views of the previous one; beyond [maxWarm], the least recently shown
  /// view is closed and its tab reopens it when shown again.
  SessionLiveController live(
    SessionRef ref,
    SessionLiveController Function() create,
  ) {
    var existing = _warm.remove(ref);
    final hosts = _catalog?.hosts;
    final saved = hosts?.profiles
        .where((profile) => profile.id == ref.host.value)
        .firstOrNull;
    if (existing != null &&
        (existing.disposed ||
            hosts?.pendingBindingChange == ref.host.value ||
            (hosts?.loaded == true &&
                hosts?.loading == false &&
                (saved == null || !saved.sameBinding(existing.profile))))) {
      _release(existing);
      existing = null;
    }
    final live = existing ?? create();
    for (final other in _warm.keys.toList()) {
      if (other.host != ref.host) _release(_warm.remove(other));
    }
    while (_warm.length >= maxWarm) {
      _release(_warm.remove(_warm.keys.first));
    }
    _warm[ref] = live;
    if (existing == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
    }
    return live;
  }

  /// Whether the live view of [ref] is open.
  bool isWarm(SessionRef ref) => _warm.containsKey(ref);

  /// Observing these views never opens a lease or changes their warm order.
  List<SessionLiveController> get warmViews => List.unmodifiable(_warm.values);

  /// Disposes a view after the frame, once the page that showed it is gone.
  void _release(SessionLiveController? live) {
    if (live == null) return;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        live.dispose();
        _notify();
      })
      // An idle app draws no frame on its own; the lease closes now.
      ..ensureVisualUpdate();
  }

  /// Checks the tabs of the server the list shows. A tab whose session is not
  /// in the loaded rows is read once; only a server that answers that the
  /// session does not exist drops it. Rows the list did not load, hid or
  /// could not read prove nothing.
  void _validate() {
    final catalog = _catalog;
    if (_disposed || catalog == null || !_store.loaded || _store.unreadable) {
      return;
    }
    final hosts = catalog.hosts;
    final retired = <String>{?hosts.pendingBindingChange};
    if (hosts.loaded && !hosts.loading && !hosts.storageError) {
      final current = {
        for (final profile in hosts.profiles) profile.id: profile,
      };
      for (final entry in _bindings.entries) {
        if (current[entry.key]?.sameBinding(entry.value) != true) {
          retired.add(entry.key);
        }
      }
      _bindings
        ..clear()
        ..addAll(current);
      // A removed server's tabs can never be shown or closed again.
      final saved = {for (final p in hosts.profiles) HostId(p.id)};
      final orphans = {
        for (final tab in tabs)
          if (!saved.contains(tab.ref.host)) tab.ref,
      };
      bool orphaned(SessionTabSuppression entry) =>
          !saved.contains(entry.ref.host);
      if (orphans.isNotEmpty || _store.state.suppressed.any(orphaned)) {
        unawaited(_remove(orphans, forget: orphaned));
      }
      _fallbacks.removeWhere((entry) => !saved.contains(HostId(entry.$1)));
    }
    for (final ref in _reads.keys.toList()) {
      if (retired.contains(ref.host.value)) _reads.remove(ref)?.cancel();
    }
    _checked.removeWhere((ref) => retired.contains(ref.host.value));
    for (final ref in _warm.keys.toList()) {
      if (retired.contains(ref.host.value)) _release(_warm.remove(ref));
    }
    if (hosts.loading || hosts.storageError) return;
    final profile = catalog.selectedProfile;
    if (profile == null ||
        hosts.pendingBindingChange == profile.id ||
        !catalog.loaded ||
        catalog.failure != null) {
      return;
    }
    final host = HostId(profile.id);
    final rows = {for (final row in catalog.sessions) row.info.ref: row};
    // A listed tab takes its row's newer title and project, without
    // counting as opened.
    final stale = {
      for (final tab in tabs)
        if (rows[tab.ref] case final row? when _snapshot(tab, row) != tab)
          tab.ref: _snapshot(tab, row),
    };
    if (stale.isNotEmpty) {
      unawaited(
        _store.update(
          (state) => !_currentBinding(profile)
              ? null
              : state.copyWith(
                  tabs: [for (final tab in state.tabs) stale[tab.ref] ?? tab],
                ),
        ),
      );
    }
    for (final tab in tabs) {
      if (tab.ref.host != host || rows.containsKey(tab.ref)) continue;
      // A read still in flight answers for a tab closed and reopened since.
      if (_reads.containsKey(tab.ref)) continue;
      if (!_checked.add(tab.ref)) continue;
      final task = catalog.read(tab.ref);
      if (task == null) {
        _checked.remove(tab.ref);
        continue;
      }
      _reads[tab.ref] = task;
      // Only the read still registered for its tab may settle it.
      bool settle() {
        if (!identical(_reads[tab.ref], task)) return false;
        _reads.remove(tab.ref);
        if (!_currentBinding(profile)) {
          _checked.remove(tab.ref);
          return false;
        }
        return true;
      }

      task.result.then(
        (_) {
          settle();
        },
        onError: (Object error) {
          if (!settle() || _disposed) return;
          if (error case SessionCatalogException(
            failure: SessionCatalogFailure.notFound,
          )) {
            _drop(tab.ref, profile);
          }
        },
      );
    }
  }

  /// [tab] with the title, project and update of its [row].
  static SessionTab _snapshot(SessionTab tab, SessionSummary row) {
    final project = row.info.project;
    return SessionTab(
      ref: tab.ref,
      project: project?.host == tab.ref.host ? project : null,
      title: SessionTabsStore.boundTitle(row.info.title),
      lastOpenedAtMs: tab.lastOpenedAtMs,
      updatedAtMs: _latest(
        tab.updatedAtMs,
        row.updatedAt?.millisecondsSinceEpoch,
      ),
    );
  }

  bool _currentBinding(EndpointProfile profile) {
    final hosts = _catalog?.hosts;
    return hosts != null &&
        !hosts.loading &&
        !hosts.storageError &&
        hosts.pendingBindingChange != profile.id &&
        hosts.isCurrentProfile(profile);
  }

  Future<void> _drop(SessionRef ref, EndpointProfile profile) async {
    final (:removed, selectedAfter: _) = await _remove(
      {ref},
      isCurrent: () => _currentBinding(profile),
      forget: (entry) => entry.ref == ref,
    );
    if (removed.isNotEmpty && !_disposed) {
      _deleted.add(ref);
      _removed.add(removed.single.title);
      _notify();
    }
  }

  /// Gives the project at [directory] of server [profile], just opened, one
  /// tab once its sessions are read: its most recent visible session, when
  /// no tab of it stays.
  void requestFallback(String profile, String directory) {
    if (_disposed) return;
    _fallbacks.add((profile, directory));
    _scheduleReconcile();
  }

  /// Reconciles once after the current changes settle.
  void _scheduleReconcile() {
    if (_disposed || _reconcileScheduled) return;
    _reconcileScheduled = true;
    scheduleMicrotask(_reconcile);
  }

  /// Brings the tabs of the selected server in line with its loaded
  /// sessions, its pins and the time. It runs only while the tabs, the
  /// pins and the server's binding are known, and never opens a view or
  /// navigates.
  void _reconcile() {
    _reconcileScheduled = false;
    final catalog = _catalog;
    final workspace = _workspace;
    final profile = catalog?.selectedProfile;
    if (_disposed ||
        catalog == null ||
        workspace == null ||
        profile == null ||
        !_store.loaded ||
        _store.unreadable ||
        !workspace.loaded ||
        workspace.unreadable ||
        !_currentBinding(profile)) {
      return;
    }
    final host = HostId(profile.id);
    final contexts = workspace.workspace(profile.id);
    final candidates = <SessionRef, SessionTabCandidate>{};
    final known = <String>{};
    for (final directory in contexts.open) {
      final rows = catalog.contextRows(directory);
      if (rows == null) continue;
      known.add(directory);
      final hidden = catalog.hiddenIn(rows);
      for (final row in rows) {
        final ref = row.info.ref;
        if (ref.host != host) continue;
        candidates.putIfAbsent(
          ref,
          () => SessionTabCandidate(
            row: row,
            hidden: hidden.contains(ref),
            pinned: contexts.isPinned(directory, ref.storageKey),
            busy: catalog.busy(row),
          ),
        );
      }
    }
    final fallbacks = {
      for (final (server, directory) in _fallbacks)
        if (server == profile.id) directory,
    };
    final now = _now().millisecondsSinceEpoch;
    SessionTabReconciliation? result;
    unawaited(
      _store
          .update((state) {
            if (!_currentBinding(profile)) return null;
            result = reconcileSessionTabs(
              state: state,
              host: host,
              nowMs: now,
              candidates: candidates,
              fallbacks: fallbacks,
              knownDirectories: known,
              frozen: {..._frozen},
            );
            return result!.state;
          })
          .then((_) {
            final settled = result;
            if (_disposed || settled == null) return;
            for (final directory in settled.consumed) {
              _fallbacks.remove((profile.id, directory));
            }
            _expiry?.cancel();
            final next = settled.nextExpiryMs;
            _expiry = next == null
                ? null
                : Timer(
                    Duration(
                      milliseconds: next - _now().millisecondsSinceEpoch,
                    ),
                    _scheduleReconcile,
                  );
          }),
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _expiry?.cancel();
    _store
      ..removeListener(_notify)
      ..removeListener(_scheduleReconcile);
    _catalog?.removeListener(_validate);
    _catalog?.removeListener(_scheduleReconcile);
    _catalog?.hosts.removeListener(_validate);
    _workspace?.removeListener(_scheduleReconcile);
    for (final task in _reads.values) {
      task.cancel();
    }
    _reads.clear();
    for (final live in _warm.values) {
      live.dispose();
    }
    _warm.clear();
    super.dispose();
  }
}
