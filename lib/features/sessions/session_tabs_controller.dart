import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/widgets.dart';

import '../../platform/sessions/session_tabs_store.dart';
import '../../shared/sessions/session_catalog_source.dart';
import 'session_live_controller.dart';
import 'sessions_controller.dart';

/// What opening a session did to its tab.
enum SessionTabOpen { opened, focused, full, unsaved }

/// The open session tabs of the workspace.
///
/// Every tab is keyed by its full [SessionRef], so two servers with the same
/// session id never share a tab. A server shows the tabs of one project at a
/// time. The live view of a tab stays open while the user visits others, up
/// to [maxWarm] of them; a restored tab opens its view only when shown.
class SessionTabsController extends ChangeNotifier {
  SessionTabsController({
    required SessionTabsStore store,
    SessionsController? catalog,
    DateTime Function()? now,
  }) : _store = store,
       _catalog = catalog,
       _now = now ?? DateTime.now {
    _store.addListener(_notify);
    _catalog?.addListener(_validate);
    // A removed server clears the list before it is noticed there.
    _catalog?.hosts.addListener(_validate);
  }

  /// The live views kept open beside the shown one.
  static const maxWarm = 8;

  final SessionTabsStore _store;
  final SessionsController? _catalog;
  final DateTime Function() _now;

  /// The live views, least recently shown first.
  final _warm = <SessionRef, SessionLiveController>{};
  final _checked = <SessionRef>{};
  final _reads = <SessionRef, SessionReadTask>{};
  final _removed = <String>[];
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

  /// The tab to show when the app opens on the list: the selected tab of the
  /// server whose tab was opened last. Only the first call of a launch gets
  /// it, so returning to the list later stays there.
  SessionRef? takeLaunchTab() {
    if (_launched) return null;
    _launched = true;
    final latest = tabs.fold<SessionTab?>(
      null,
      (latest, tab) =>
          latest == null || tab.lastOpenedAtMs > latest.lastOpenedAtMs
          ? tab
          : latest,
    );
    return latest == null ? null : selectedFor(latest.ref.host);
  }

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
      );
      final next = [...state.tabs];
      if (index < 0) {
        next.add(tab);
      } else {
        next[index] = tab;
      }
      result = index < 0 ? SessionTabOpen.opened : SessionTabOpen.focused;
      return SessionTabsState(
        tabs: next,
        selected: {...state.selected, ref.host: ref},
      );
    });
    if (!saved && result != SessionTabOpen.full) return SessionTabOpen.unsaved;
    if (result == SessionTabOpen.opened) _checked.remove(ref);
    return result;
  }

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

  /// Closes the tab of [ref] and its live view. [removed] is false when this
  /// call removed nothing, the tab being gone already or the change unsaved.
  /// When the tab was the selected tab of its server, the next tab of its
  /// project is selected, else the previous one, and returned as [next].
  Future<({bool removed, SessionRef? next})> close(SessionRef ref) async {
    if (_disposed) return (removed: false, next: null);
    final (:removed, :selectedAfter) = await _remove({ref});
    return (removed: removed.isNotEmpty, next: selectedAfter[ref]);
  }

  /// Puts the closed [tab] back at [index] of the strip; [select] makes it
  /// the selected tab of its server again. False when it is open again
  /// already, the tabs are full or nothing was saved.
  Future<bool> reopen(
    SessionTab tab, {
    required int index,
    required bool select,
  }) async {
    if (_disposed) return false;
    final saved = await _store.update((state) {
      if (state.tabs.any((other) => other.ref == tab.ref)) return null;
      if (state.tabs.length >= SessionTabsStore.maxTabs) return null;
      final next = [...state.tabs];
      next.insert(index.clamp(0, next.length), tab);
      return SessionTabsState(
        tabs: next,
        selected: select
            ? {...state.selected, tab.ref.host: tab.ref}
            : state.selected,
      );
    });
    // A tab back in the strip is checked against its server again, now: an
    // answer that came while it was closed dropped nothing.
    if (saved) {
      _checked.remove(tab.ref);
      _validate();
    }
    return saved;
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

  /// Removes the tabs of [refs] at the store's turn. A removed selected tab
  /// hands its selection to its neighbour. The removed tabs, empty when
  /// nothing was saved, and the tab each removed selected tab handed its
  /// selection to.
  Future<
    ({List<SessionTab> removed, Map<SessionRef, SessionRef?> selectedAfter})
  >
  _remove(Set<SessionRef> refs) async {
    var removed = <SessionTab>[];
    final selectedAfter = <SessionRef, SessionRef?>{};
    final saved = await _store.update((state) {
      removed = [
        for (final tab in state.tabs)
          if (refs.contains(tab.ref)) tab,
      ];
      if (removed.isEmpty) return null;
      selectedAfter.clear();
      var current = state;
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
        current = SessionTabsState(
          tabs: [
            for (final other in current.tabs)
              if (other.ref != ref) other,
          ],
          selected: selected,
        );
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
    final existing = _warm.remove(ref);
    final live = existing ?? create();
    for (final other in _warm.keys.toList()) {
      if (other.host != ref.host) _release(_warm.remove(other));
    }
    while (_warm.length >= maxWarm) {
      _release(_warm.remove(_warm.keys.first));
    }
    _warm[ref] = live;
    return live;
  }

  /// Whether the live view of [ref] is open.
  bool isWarm(SessionRef ref) => _warm.containsKey(ref);

  /// Disposes a view after the frame, once the page that showed it is gone.
  void _release(SessionLiveController? live) {
    if (live == null) return;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => live.dispose())
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
    if (hosts.loaded && !hosts.loading && !hosts.storageError) {
      // A removed server's tabs can never be shown or closed again.
      final saved = {for (final p in hosts.profiles) HostId(p.id)};
      final orphans = {
        for (final tab in tabs)
          if (!saved.contains(tab.ref.host)) tab.ref,
      };
      if (orphans.isNotEmpty) unawaited(_remove(orphans));
    }
    final profile = catalog.selectedProfile;
    if (profile == null || !catalog.loaded || catalog.failure != null) return;
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
          (state) => SessionTabsState(
            tabs: [for (final tab in state.tabs) stale[tab.ref] ?? tab],
            selected: state.selected,
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
            _drop(tab.ref);
          }
        },
      );
    }
  }

  /// [tab] with the title and project of its [row].
  static SessionTab _snapshot(SessionTab tab, SessionSummary row) {
    final project = row.info.project;
    return SessionTab(
      ref: tab.ref,
      project: project?.host == tab.ref.host ? project : null,
      title: SessionTabsStore.boundTitle(row.info.title),
      lastOpenedAtMs: tab.lastOpenedAtMs,
    );
  }

  Future<void> _drop(SessionRef ref) async {
    final (:removed, selectedAfter: _) = await _remove({ref});
    if (removed.isNotEmpty && !_disposed) {
      _removed.add(removed.single.title);
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _store.removeListener(_notify);
    _catalog?.removeListener(_validate);
    _catalog?.hosts.removeListener(_validate);
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
