import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';

import '../features/hosts/endpoint_health_controller.dart';
import '../features/sessions/session_live_controller.dart';
import '../features/sessions/session_tabs_controller.dart';
import '../features/sessions/sessions_controller.dart';
import '../shared/sessions/session_activity.dart';
import '../shared/sessions/session_live_source.dart';

enum WorkspaceBadgeKind {
  none,
  serverAlert,
  syncAlert,
  error,
  needsInput,
  unread,
  syncing,
}

final class WorkspaceBadge {
  const WorkspaceBadge(this.kind, {this.session, this.title = ''});
  final WorkspaceBadgeKind kind;
  final SessionRef? session;
  final String title;
}

/// One reason drives both the hamburger and its drawer notice. Health never
/// borrows the stream's reconnecting state to claim an endpoint is offline.
final class WorkspaceChromeController extends ChangeNotifier {
  WorkspaceChromeController({
    required this.health,
    required this.catalog,
    required this.tabs,
  }) {
    health.addListener(_changed);
    catalog.addListener(_changed);
    tabs.addListener(_changed);
  }

  final EndpointHealthController health;
  final SessionsController catalog;
  final SessionTabsController tabs;
  final _observed = <SessionLiveController>{};
  Timer? _timer;
  String _location = '';
  String? _profile;
  DateTime? _resume;
  DateTime? _offlineSince;
  DateTime? _syncSince;
  bool _wasForeground = false;
  bool _resuming = false;
  bool _sawResumeRecovery = false;
  bool _warned = false;
  bool _pendingWarning = false;
  bool _disposed = false;
  int _warning = 0;
  int get warningRevision => _warning;

  bool get _workspace =>
      _location == '/' ||
      _location == '/sessions' ||
      _location.startsWith('/s/');
  SessionRef? get currentSession {
    final parts = Uri.tryParse(_location)?.pathSegments;
    if (parts == null || parts.length != 3 || parts.first != 's') return null;
    return SessionRef(HostId(parts[1]), HarnessInstanceId(parts[1]), parts[2]);
  }

  SessionLiveController? get _live => tabs.warmViews
      .where(
        (live) =>
            live.session == currentSession &&
            live.session.host.value == catalog.selectedProfile?.id &&
            !live.disposed,
      )
      .firstOrNull;
  SessionLiveController? get activeLive => _live;
  bool get _recovering {
    final live = _live;
    return live != null &&
        (const {
              SessionLivePhase.connecting,
              SessionLivePhase.hydrating,
              SessionLivePhase.reconnecting,
              SessionLivePhase.degraded,
            }.contains(live.phase) ||
            (live.phase == SessionLivePhase.live &&
                (live.view?.stale ?? false)));
  }

  DateTime get _graceEnd =>
      (health.resumedAt ?? health.now).add(const Duration(seconds: 5));
  bool get _offline =>
      catalog.selectedProfile != null &&
      health.view(catalog.selectedProfile!).status ==
          EndpointHealthStatus.offline;

  WorkspaceBadge get badge {
    if (!health.foreground || !_workspace) {
      return const WorkspaceBadge(WorkspaceBadgeKind.none);
    }
    final now = health.now;
    final syncEscalated =
        _syncSince != null &&
        !now.isBefore(_syncSince!.add(const Duration(seconds: 10)));
    if (!now.isBefore(_graceEnd)) {
      if (_offline) {
        return const WorkspaceBadge(WorkspaceBadgeKind.serverAlert);
      }
      if (syncEscalated) {
        return WorkspaceBadge(
          WorkspaceBadgeKind.syncAlert,
          session: currentSession,
        );
      }
    }
    final project = catalog.selectedProject?.project;
    WorkspaceBadge? attention;
    for (final row in catalog.sessions) {
      if (row.info.ref == currentSession ||
          row.info.ref.host.value != catalog.selectedProfile?.id ||
          row.info.project != project) {
        continue;
      }
      final warm = _observed
          .where((live) => live.session == row.info.ref)
          .firstOrNull;
      final execution = warm?.state?.execution ?? row.execution;
      final marks = catalog.activityMarks(row);
      if (execution?.lastOutcome?.kind.known == ExecutionOutcomeKind.failed) {
        return WorkspaceBadge(
          WorkspaceBadgeKind.error,
          session: row.info.ref,
          title: row.info.title,
        );
      }
      if (marks.contains(SessionActivityMark.needsYou) ||
          const {
            ExecutionKind.waitingForApproval,
            ExecutionKind.waitingForInput,
          }.contains(execution?.kind.known)) {
        attention = WorkspaceBadge(
          WorkspaceBadgeKind.needsInput,
          session: row.info.ref,
          title: row.info.title,
        );
      } else if (attention == null &&
          marks.contains(SessionActivityMark.unread)) {
        attention = WorkspaceBadge(
          WorkspaceBadgeKind.unread,
          session: row.info.ref,
          title: row.info.title,
        );
      }
    }
    if (attention != null) return attention;
    if (_resuming && _recovering) {
      return const WorkspaceBadge(WorkspaceBadgeKind.syncing);
    }
    return const WorkspaceBadge(WorkspaceBadgeKind.none);
  }

  void locationChanged(String location) {
    if (_disposed || _location == location) return;
    _location = location;
    _pendingWarning = false;
    _warned = false;
    _offlineSince = null;
    _changed();
  }

  EndpointProfile? takeWarning() {
    if (!_pendingWarning) return null;
    _pendingWarning = false;
    return health.foreground && _workspace && _offline
        ? catalog.selectedProfile
        : null;
  }

  void _changed() {
    if (_disposed) return;
    final warm = tabs.warmViews.where((live) => !live.disposed).toSet();
    for (final live in _observed.difference(warm)) {
      live.removeListener(_changed);
    }
    for (final live in warm.difference(_observed)) {
      live.addListener(_changed);
    }
    _observed
      ..clear()
      ..addAll(warm);
    final now = health.now;
    final profile = catalog.selectedProfile?.id;
    final resumed = _resume != health.resumedAt;
    if (profile != _profile || resumed || !health.foreground || !_workspace) {
      _offlineSince = null;
      _syncSince = null;
      _warned = false;
      _pendingWarning = false;
    }
    if (health.foreground && !_wasForeground && _resume != null) {
      _resuming = true;
      _sawResumeRecovery = false;
    }
    _wasForeground = health.foreground;
    _resume = health.resumedAt;
    _profile = profile;
    if (!_recovering || !health.foreground || !_workspace) {
      _syncSince = null;
      if (!health.foreground ||
          !_workspace ||
          _sawResumeRecovery ||
          !now.isBefore(_graceEnd)) {
        _resuming = false;
      }
    } else {
      _syncSince ??= now;
      if (_resuming) _sawResumeRecovery = true;
    }
    if (!_offline || !health.foreground || !_workspace) {
      _offlineSince = null;
      _warned = false;
      _pendingWarning = false;
    } else {
      _offlineSince ??= now;
    }
    _timer?.cancel();
    final deadlines = <DateTime>[];
    if (health.foreground && _workspace) {
      if ((_offline || _recovering || _resuming) && now.isBefore(_graceEnd)) {
        deadlines.add(_graceEnd);
      }
      if (_syncSince case final since?) {
        final deadline = since.add(const Duration(seconds: 10));
        if (deadline.isAfter(now)) deadlines.add(deadline);
      }
      if (!_warned && _offlineSince != null) {
        final since = _offlineSince!;
        final start = since.isAfter(_graceEnd) ? since : _graceEnd;
        final deadline = start.add(const Duration(seconds: 5));
        if (deadline.isAfter(now)) {
          deadlines.add(deadline);
        } else {
          _warned = true;
          _pendingWarning = true;
          _warning++;
        }
      }
    }
    deadlines.sort();
    _timer = deadlines.isEmpty
        ? null
        : Timer(deadlines.first.difference(now), _changed);
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    health.removeListener(_changed);
    catalog.removeListener(_changed);
    tabs.removeListener(_changed);
    for (final live in _observed) {
      live.removeListener(_changed);
    }
    _observed.clear();
    super.dispose();
  }
}
