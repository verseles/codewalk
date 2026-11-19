import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';
import 'package:harness_opencode/harness_opencode.dart';

import '../../shared/sessions/session_live_source.dart';
import '../../shared/sessions/session_shells.dart';

/// Per-profile shell observation, output paging, and single-flight stop lane
/// for OpenCode v2 endpoints (`shell.observe`, `shell.stop`).
final class OpenCodeShellLane {
  OpenCodeShellLane({
    required this.client,
    required this.connectedVersion,
    required this.commandIds,
    required this.view,
    required this.publish,
    required this.refreshShells,
    required this.dropLocalShell,
    required this.currentBinding,
    this.shellDirectory,
  }) : _capabilities = openCodeShellCapabilities(connectedVersion);

  final OpenCodeShellClient client;
  final String connectedVersion;
  final CommandId Function() commandIds;
  final SessionLiveView Function(SessionRef) view;
  final void Function(SessionRef) publish;
  final Future<void> Function(SessionRef) refreshShells;
  final void Function(SessionRef, String shellId) dropLocalShell;
  final bool Function() currentBinding;
  final String? Function(String shellId)? shellDirectory;
  final Map<String, Capability> _capabilities;

  final _stopping = <(SessionRef, String), RequestCancellation>{};
  final _reads = <SessionRef, Set<RequestCancellation>>{};
  bool _closed = false;

  bool get canObserve =>
      !_closed &&
      currentBinding() &&
      (_capabilities[ShellCapabilities.observe]?.isAvailable ?? false);

  bool get canStop =>
      !_closed &&
      currentBinding() &&
      (_capabilities[ShellCapabilities.stop]?.isAvailable ?? false);

  SessionShellPort port(SessionRef ref, bool Function() leaseCurrent) =>
      _OpenCodeShellPort(this, ref, leaseCurrent);

  bool isStopping(SessionRef ref, String shellId) =>
      _stopping.containsKey((ref, shellId));

  bool _sessionLive(SessionRef ref, bool Function() leaseCurrent) {
    if (_closed || !currentBinding() || !leaseCurrent()) return false;
    final current = view(ref);
    return current.phase == SessionLivePhase.live && !current.stale;
  }

  String? _directoryFor(SessionRef ref, String shellId) =>
      shellDirectory?.call(shellId) ??
      view(ref).state?.info?.project?.canonicalDirectory;

  /// Ensures [shellId] is verified as owned by [ref] before calling location-
  /// scoped output or DELETE routes. Resident `state.shells` entries were
  /// already verified via `metadata.sessionID == ref.nativeId`; unknown IDs
  /// must pass a scoped `GET /api/shell/:id` ownership check first.
  Future<bool> _verifyOwnership(
    SessionRef ref,
    String shellId,
    String? directory,
    RequestCancellation cancellation,
  ) async {
    final resident = view(ref).state?.shells;
    if (resident != null && resident.any((s) => s.id == shellId)) {
      return true;
    }
    try {
      final verified = await client.getShell(
        session: ref,
        shellId: shellId,
        directory: directory,
        cancellation: cancellation,
      );
      return verified != null && verified.id == shellId;
    } on OpenCodeSessionReadException catch (error) {
      if (error.failure == OpenCodeSessionReadFailure.notFound ||
          error.failure == OpenCodeSessionReadFailure.invalidRequest ||
          error.failure == OpenCodeSessionReadFailure.invalidScope) {
        return false;
      }
      rethrow;
    }
  }

  Future<void> refresh(SessionRef ref, bool Function() leaseCurrent) async {
    if (!canObserve || !leaseCurrent()) return;
    await refreshShells(ref);
  }

  Future<ShellOutputPage?> readOutput(
    SessionRef ref,
    String shellId, {
    required bool Function() leaseCurrent,
    int? cursor,
    int limit = 16 * 1024,
    SessionShellCancellation? cancellation,
  }) async {
    if (!canObserve || !_sessionLive(ref, leaseCurrent)) return null;
    if (cancellation?.isCancelled ?? false) return null;
    final netCancel = RequestCancellation();
    cancellation?.onCancel(netCancel.cancel);
    final active = _reads.putIfAbsent(ref, () => <RequestCancellation>{});
    active.add(netCancel);
    try {
      final dir = _directoryFor(ref, shellId);
      if (!await _verifyOwnership(ref, shellId, dir, netCancel)) {
        return null;
      }
      if (netCancel.isCancelled || !_sessionLive(ref, leaseCurrent)) {
        return null;
      }
      return await client.readOutput(
        session: ref,
        shellId: shellId,
        directory: dir,
        cursor: cursor,
        limit: limit,
        cancellation: netCancel,
      );
    } on OpenCodeSessionReadException catch (error) {
      if (error.failure == OpenCodeSessionReadFailure.notFound ||
          error.failure == OpenCodeSessionReadFailure.cancelled) {
        return null;
      }
      rethrow;
    } finally {
      active.remove(netCancel);
      if (active.isEmpty) _reads.remove(ref);
    }
  }

  Future<SessionShellStopOutcome> stop(
    SessionRef ref,
    String shellId, {
    required bool Function() leaseCurrent,
    CommandId? id,
  }) async {
    if (!canStop || !_sessionLive(ref, leaseCurrent)) {
      return SessionShellStopOutcome.unavailable;
    }
    final key = (ref, shellId);
    // Single-flight fence: ignore duplicate clicks while a stop is in flight.
    if (_stopping.containsKey(key)) {
      return SessionShellStopOutcome.unavailable;
    }
    final token = RequestCancellation();
    _stopping[key] = token;
    publish(ref);
    try {
      final dir = _directoryFor(ref, shellId);
      final bool owned;
      try {
        owned = await _verifyOwnership(ref, shellId, dir, token);
      } on OpenCodeSessionReadException {
        return SessionShellStopOutcome.uncertain;
      }
      if (!owned) {
        return SessionShellStopOutcome.unavailable;
      }
      if (_closed || !currentBinding() || !leaseCurrent()) {
        return SessionShellStopOutcome.unavailable;
      }
      final attempt = await client.stop(
        session: ref,
        shellId: shellId,
        id: id ?? commandIds(),
        directory: dir,
        cancellation: token,
      );
      if (_closed || !currentBinding()) {
        return SessionShellStopOutcome.unavailable;
      }
      if (attempt.notFound) {
        dropLocalShell(ref, shellId);
        return SessionShellStopOutcome.notFound;
      }
      switch (attempt.receipt.state.known) {
        case ReceiptState.accepted:
          dropLocalShell(ref, shellId);
          return SessionShellStopOutcome.accepted;
        case ReceiptState.rejected:
          return SessionShellStopOutcome.rejected;
        case ReceiptState.unavailable:
          return SessionShellStopOutcome.unavailable;
        default:
          return SessionShellStopOutcome.uncertain;
      }
    } finally {
      if (identical(_stopping[key], token)) {
        _stopping.remove(key);
        if (!_closed && currentBinding()) publish(ref);
      }
    }
  }

  void release(SessionRef ref) {
    final activeReads = _reads.remove(ref);
    if (activeReads != null) {
      for (final token in activeReads) {
        token.cancel();
      }
    }
    _stopping.removeWhere((key, token) {
      if (key.$1 != ref) return false;
      token.cancel();
      return true;
    });
  }

  void close() {
    _closed = true;
    for (final set in _reads.values) {
      for (final token in set) {
        token.cancel();
      }
    }
    _reads.clear();
    for (final token in _stopping.values) {
      token.cancel();
    }
    _stopping.clear();
  }
}

final class _OpenCodeShellPort implements SessionShellPort {
  const _OpenCodeShellPort(this._lane, this._ref, this._leaseCurrent);

  final OpenCodeShellLane _lane;
  final SessionRef _ref;
  final bool Function() _leaseCurrent;

  @override
  bool get canObserve => _lane.canObserve && _leaseCurrent();

  @override
  bool get canStop => _lane.canStop && _leaseCurrent();

  @override
  bool isStopping(String shellId) => _lane.isStopping(_ref, shellId);

  @override
  Future<void> refresh() => _lane.refresh(_ref, _leaseCurrent);

  @override
  Future<ShellOutputPage?> readOutput(
    String shellId, {
    int? cursor,
    int limit = 16 * 1024,
    SessionShellCancellation? cancellation,
  }) => _lane.readOutput(
    _ref,
    shellId,
    leaseCurrent: _leaseCurrent,
    cursor: cursor,
    limit: limit,
    cancellation: cancellation,
  );

  @override
  Future<SessionShellStopOutcome> stop(String shellId, {CommandId? id}) =>
      _lane.stop(_ref, shellId, leaseCurrent: _leaseCurrent, id: id);
}
