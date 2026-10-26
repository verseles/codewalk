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
  final _retirements = <OpenCodeProfileSlot, Future<void>>{};
  final _profiles = <String, EndpointProfile>{};
  final _credentials = <String, EndpointCredential>{};
  final _observed = <String, EndpointProfile>{};
  bool _managed = false;
  bool _available = true;
  String? _changingProfile;
  bool _closed = false;

  static String _key(EndpointProfile profile) =>
      '${profile.id}|${profile.endpoint}|${profile.bindingRevision}';

  bool _current(EndpointProfile profile, EndpointCredential credential) {
    if (_closed || !_available || _changingProfile == profile.id) return false;
    if (!_managed) {
      return _observed[profile.id]?.sameBinding(profile) ?? false;
    }
    return _profiles[profile.id]?.sameBinding(profile) == true &&
        credential.matches(_credentials[profile.id]);
  }

  void _retire(OpenCodeProfileSlot slot) {
    if (_retirements.containsKey(slot)) return;
    final key = _key(slot.profile);
    if (identical(_slots[key], slot)) _slots.remove(key);
    final retirement = slot.close();
    _retirements[slot] = retirement;
    unawaited(
      retirement.then<void>(
        (_) {
          _owned.remove(slot);
          _retirements.remove(slot);
        },
        // Keep failed teardown authoritative: a replacement cannot overlap it.
        onError: (Object _, StackTrace _) {},
      ),
    );
  }

  @override
  void reconcileProfiles({
    required List<EndpointProfile> profiles,
    required Map<String, EndpointCredential> credentials,
    required bool available,
    String? changingProfile,
  }) {
    if (_closed) return;
    _managed = true;
    _available = available;
    _changingProfile = changingProfile;
    if (available) {
      _profiles
        ..clear()
        ..addEntries(profiles.map((profile) => MapEntry(profile.id, profile)));
      _credentials
        ..clear()
        ..addAll(credentials);
    }
    for (final slot in _owned.toList()) {
      if (!available) slot.suspendUnrestricted();
      if (slot.profile.id == changingProfile ||
          (available && !_current(slot.profile, slot.credential))) {
        _retire(slot);
      }
    }
  }

  Future<void> _prepareBinding(
    EndpointProfile profile,
    EndpointCredential credential,
  ) async {
    if (!_managed) {
      final previous = _observed[profile.id];
      if (previous != null &&
          (previous.bindingRevision > profile.bindingRevision ||
              (previous.bindingRevision == profile.bindingRevision &&
                  !previous.sameBinding(profile)))) {
        throw const SessionLiveException(SessionLiveFailure.sourceChanged);
      }
      _observed[profile.id] = profile;
    }
    if (!_current(profile, credential)) {
      throw const SessionLiveException(SessionLiveFailure.sourceChanged);
    }
    for (final slot in _owned.toList()) {
      if (slot.profile.id == profile.id &&
          (!slot.profile.sameBinding(profile) ||
              slot.isClosed ||
              (_managed && !slot.credential.matches(credential)))) {
        _retire(slot);
      }
    }
    try {
      await Future.wait([
        for (final entry in _retirements.entries)
          if (entry.key.profile.id == profile.id) entry.value,
      ]);
    } on Object {
      throw const SessionLiveException(SessionLiveFailure.connection);
    }
    if (!_current(profile, credential)) {
      throw const SessionLiveException(SessionLiveFailure.sourceChanged);
    }
  }

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
    await _prepareBinding(profile, credential);
    final key = _key(profile);
    var slot = _slots[key];
    if (slot != null && !slot.credential.matches(credential)) {
      // Never multiplex two secrets over one stream: a live session or a
      // catalog lease still holds the profile.
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
        slot ?? _createSlot(key, profile, credential, session.harnessRef);
    try {
      await current.ready();
      if (!_current(profile, credential) ||
          !identical(_slots[key], current) ||
          current.isClosed) {
        throw const SessionLiveException(SessionLiveFailure.sourceChanged);
      }
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
      isCurrentBinding: () =>
          _current(profile, credential) && identical(_slots[key], slot),
    );
    _owned.add(slot);
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
    await _prepareBinding(profile, credential);
    final key = _key(profile);
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
      if (!_current(profile, credential) ||
          !identical(_slots[key], current) ||
          current.isClosed) {
        throw const SessionLiveException(SessionLiveFailure.sourceChanged);
      }
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

  /// Terminal slots are left out: they were released from [_slots], and
  /// waking one would restart a stream stopped for authentication or
  /// compatibility.
  @override
  void wake() {
    if (_closed) return;
    for (final slot in _slots.values.toList()) {
      slot.wake();
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
