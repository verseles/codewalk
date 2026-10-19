import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';
import '../../shared/sessions/command_ids.dart';
import '../../shared/sessions/permission_mode.dart';
import '../../shared/sessions/session_catalog_changes.dart';
import '../../shared/sessions/session_live_source.dart';
import '../../shared/sessions/session_unrestricted.dart';
import '../storage/payload_store.dart';
import '../storage/storage_support.dart';
import 'opencode_profile_slot.dart';

SessionLiveDirectory? createSessionLiveDirectory({
  DateTime Function()? now,
  PayloadStore? payloads,
  PermissionModePolicy? permissionModes,
  UnrestrictedOwnershipLedger? unrestrictedOwnership,
  CommandId Function()? commandIds,
}) => _NativeLiveDirectory(
  now ?? DateTime.now,
  payloads,
  permissionModes,
  unrestrictedOwnership,
  commandIds ?? mintCommandId,
);

/// One event stream per endpoint profile, shared by every open handle; the
/// last handle of a session unwatches it and the last of a profile closes the
/// stream. Mutations require an explicit outbox action, Stop or permission
/// reply on a handle.
final class _NativeLiveDirectory implements SessionLiveDirectory {
  _NativeLiveDirectory(
    this._now,
    this._payloads,
    this._permissionModes,
    this._unrestrictedOwnership,
    this._commandIds,
  ) {
    _permissionModes?.addListener(_policyChanged);
  }
  final DateTime Function() _now;
  final PayloadStore? _payloads;
  final PermissionModePolicy? _permissionModes;
  final UnrestrictedOwnershipLedger? _unrestrictedOwnership;
  final CommandId Function() _commandIds;
  // Outlive slot generations: a replaced slot's outbox and its successor
  // write the same ledgers in turn, and minted ids keep rising per server.
  final _queue = KeySerialExecutor();
  final _ids = <String, OpenCodeMessageIds>{};
  // Outlive slot generations, like [_ids]: a request answered before the last
  // screen closed stays answered when the same profile reopens in a new slot.
  final _answered = <String, Set<String>>{};
  final _slots = <String, OpenCodeProfileSlot>{};
  // Includes terminal slots detached from [_slots] while screens still hold
  // them, so closing the directory reaches every open stream.
  final _owned = <OpenCodeProfileSlot>{};
  bool _closed = false;

  @override
  Future<SessionLiveHandle> open({
    required EndpointProfile profile,
    required EndpointCredential credential,
    required SessionRef session,
  }) async {
    if (_closed) throw const SessionLiveException(SessionLiveFailure.cancelled);
    if (session.harnessRef !=
        HarnessRef(HostId(profile.id), HarnessInstanceId(profile.id))) {
      throw const SessionLiveException(SessionLiveFailure.incompatibleResponse);
    }
    final key = '${profile.id}|${profile.endpoint}';
    var slot = _slots[key];
    if (slot != null && !slot.credential.matches(credential)) {
      // Never multiplex two secrets over one stream.
      if (slot.handles.isNotEmpty) {
        throw const SessionLiveException(
          SessionLiveFailure.authenticationRequired,
        );
      }
      _slots.remove(key);
      unawaited(slot.close());
      slot = null;
    }
    final current =
        slot ?? _createSlot(key, profile, credential, session.harnessRef);
    try {
      await current.ready();
      return current.lease(session);
    } on Object {
      if (current.handles.isEmpty && identical(_slots[key], current)) {
        _slots.remove(key);
        unawaited(current.close());
      }
      rethrow;
    }
  }

  OpenCodeProfileSlot _createSlot(
    String key,
    EndpointProfile profile,
    EndpointCredential credential,
    HarnessRef harness,
  ) {
    late final OpenCodeProfileSlot slot;
    slot = OpenCodeProfileSlot(
      profile,
      credential,
      harness,
      _now,
      () {
        if (identical(_slots[key], slot)) _slots.remove(key);
      },
      payloads: _payloads,
      queue: _queue,
      ids: _ids.putIfAbsent(key, OpenCodeMessageIds.new),
      answered: _answered.putIfAbsent(key, () => <String>{}),
      permissionModes: _permissionModes,
      unrestrictedOwnership: _unrestrictedOwnership,
      commandIds: _commandIds,
    );
    _owned
      ..removeWhere((owned) => owned.isClosed)
      ..add(slot);
    return _slots[key] = slot;
  }

  /// The catalog's feed of the session lifecycle of one profile.
  ///
  /// The feed shares the endpoint's single event stream: it holds the same
  /// profile the live sessions use, so the endpoint never carries a second
  /// subscription.
  @override
  Future<SessionCatalogChanges> catalogChanges({
    required EndpointProfile profile,
    required EndpointCredential credential,
  }) async {
    if (_closed) throw const SessionLiveException(SessionLiveFailure.cancelled);
    final key = '${profile.id}|${profile.endpoint}';
    var slot = _slots[key];
    if (slot != null && !slot.credential.matches(credential)) {
      // Never multiplex two secrets over one stream.
      if (slot.handles.isNotEmpty || slot.catalogLeases > 0) {
        throw const SessionLiveException(
          SessionLiveFailure.authenticationRequired,
        );
      }
      _slots.remove(key);
      unawaited(slot.close());
      slot = null;
    }
    final current =
        slot ??
        _createSlot(
          key,
          profile,
          credential,
          HarnessRef(HostId(profile.id), HarnessInstanceId(profile.id)),
        );
    try {
      await current.ready();
      return current.catalogLease();
    } on Object {
      if (current.handles.isEmpty &&
          current.catalogLeases == 0 &&
          identical(_slots[key], current)) {
        _slots.remove(key);
        unawaited(current.close());
      }
      rethrow;
    }
  }

  /// A policy change is the user's decision: re-evaluate resident requests
  /// now, so switching to Allow all does not wait for another frame. Every
  /// gate in [OpenCodeProfileSlot._canAutoApprove] still applies.
  void _policyChanged() {
    if (_closed) return;
    for (final slot in _owned.toList()) {
      slot.considerAutoApproval();
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _permissionModes?.removeListener(_policyChanged);
    final slots = _owned.toList();
    _slots.clear();
    _owned.clear();
    await Future.wait([for (final slot in slots) slot.close()]);
    _answered.clear();
  }
}
