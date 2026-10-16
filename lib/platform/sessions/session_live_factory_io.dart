import 'dart:async';
import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net_io.dart';
import 'package:harness_opencode/harness_opencode.dart';
import '../../shared/sessions/prompt_outbox.dart';
import '../../shared/sessions/session_live_source.dart';
import '../../shared/sessions/session_stop.dart';
import '../storage/payload_store.dart';
import '../storage/storage_support.dart';
import 'prompt_outbox_store.dart';

SessionLiveDirectory? createSessionLiveDirectory({
  DateTime Function()? now,
  PayloadStore? payloads,
}) => _NativeLiveDirectory(now ?? DateTime.now, payloads);

/// One event stream per endpoint profile, shared by every open handle; the
/// last handle of a session unwatches it and the last of a profile closes the
/// stream. Mutations require an explicit outbox action or Stop on a handle.
final class _NativeLiveDirectory implements SessionLiveDirectory {
  _NativeLiveDirectory(this._now, this._payloads);
  final DateTime Function() _now;
  final PayloadStore? _payloads;
  // Outlive slot generations: a replaced slot's outbox and its successor
  // write the same ledgers in turn, and minted ids keep rising per server.
  final _queue = KeySerialExecutor();
  final _ids = <String, OpenCodeMessageIds>{};
  final _slots = <String, _ProfileSlot>{};
  // Includes terminal slots detached from [_slots] while screens still hold
  // them, so closing the directory reaches every open stream.
  final _owned = <_ProfileSlot>{};
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
    final current = slot ?? _createSlot(key, profile, credential, session);
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

  _ProfileSlot _createSlot(
    String key,
    EndpointProfile profile,
    EndpointCredential credential,
    SessionRef session,
  ) {
    late final _ProfileSlot slot;
    slot = _ProfileSlot(
      profile,
      credential,
      session.harnessRef,
      _now,
      () {
        if (identical(_slots[key], slot)) _slots.remove(key);
      },
      payloads: _payloads,
      queue: _queue,
      ids: _ids.putIfAbsent(key, OpenCodeMessageIds.new),
    );
    _owned
      ..removeWhere((owned) => owned.isClosed)
      ..add(slot);
    return _slots[key] = slot;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final slots = _owned.toList();
    _slots.clear();
    _owned.clear();
    await Future.wait([for (final slot in slots) slot.close()]);
  }
}

final class _ProfileSlot {
  _ProfileSlot(
    EndpointProfile profile,
    this.credential,
    this.harness,
    this._now,
    this._release, {
    required this.payloads,
    required this.queue,
    required this.ids,
  }) : _transport = IoEndpointHttpTransport(
         endpoint: profile.endpoint,
         headers: basicEndpointHeaders(
           endpoint: profile.endpoint,
           username: 'opencode',
           secret: () => credential.secret,
         ),
       ) {
    _reader = OpenCodeSessionReader(
      _transport,
      harness: harness,
      maxHistoryItems: 500,
    );
  }

  final EndpointCredential credential;
  final HarnessRef harness;
  final DateTime Function() _now;
  final void Function() _release;
  final PayloadStore? payloads;
  final KeySerialExecutor queue;
  final OpenCodeMessageIds ids;
  PromptOutbox? outbox;
  OpenCodeInterruptClient? _interrupt;
  final _stops = <SessionRef, _StopRequest>{};
  final IoEndpointHttpTransport _transport;
  late final OpenCodeSessionReader _reader;
  final _store = SessionStore(maxSessions: 8);
  IoSseRecovery? _connection;
  OpenCodeStreamOwner? _owner;
  StreamSubscription<OpenCodeStreamUpdate>? _subscription;
  Future<void>? _ready;
  Future<void>? _closing;
  String? version;
  SessionLivePhase _phase = SessionLivePhase.probing;
  final handles = <_LiveHandle>{};
  final _views = <SessionRef, SessionLiveView>{};

  Future<void> ready() => _ready ??= _probe();

  Future<void> _probe() async {
    final assessment = await OpenCodeEndpointProbe(_transport).detect();
    if (_closing != null) {
      throw const SessionLiveException(SessionLiveFailure.cancelled);
    }
    switch (assessment.status) {
      case EndpointStatus.authenticationRequired:
        throw const SessionLiveException(
          SessionLiveFailure.authenticationRequired,
        );
      case EndpointStatus.unreachable:
        throw const SessionLiveException(SessionLiveFailure.timeout);
      case EndpointStatus.cancelled:
        throw const SessionLiveException(SessionLiveFailure.cancelled);
      default:
        break;
    }
    final observed = assessment.version;
    if (!assessment.canUse || observed == null) {
      throw const SessionLiveException(SessionLiveFailure.unavailable);
    }
    // The stream reader is verified against 2.0.22 only; fail closed before
    // opening the stream instead of hydrating an unverified version.
    if (OpenCodeCompatibility.parse(observed)?.toString() != '2.0.22') {
      throw const SessionLiveException(SessionLiveFailure.incompatibleResponse);
    }
    version = observed;
    _interrupt = OpenCodeInterruptClient(
      _transport,
      harness: harness,
      connectedVersion: observed,
    );
    if (payloads case final store?) {
      outbox = OpenCodePromptOutbox(
        store: store,
        client: OpenCodePromptClient(
          _transport,
          harness: harness,
          connectedVersion: observed,
        ),
        reader: _reader,
        ids: ids,
        now: _now,
        queue: queue,
      );
    }
    final connection = IoSseRecovery(
      _transport,
      'api/event',
      connectedWhen: openCodeServerConnected,
    );
    final owner = OpenCodeStreamOwner(
      connection: connection,
      reader: _reader,
      store: _store,
      harness: harness,
      sourceVersion: observed,
    );
    _connection = connection;
    _owner = owner;
    _phase = SessionLivePhase.connecting;
    _subscription = owner.updates.listen(_onUpdate);
    owner.start();
  }

  _LiveHandle lease(SessionRef session) {
    final owner = _owner;
    if (owner == null || _closing != null) {
      throw const SessionLiveException(SessionLiveFailure.cancelled);
    }
    final previous = _views[session];
    // A retry re-hydrates a session set aside; its other screens follow.
    if (previous?.phase == SessionLivePhase.degraded) owner.unwatch(session);
    if (!owner.watch(session)) {
      throw const SessionLiveException(SessionLiveFailure.capacity);
    }
    if (previous == null || previous.phase == SessionLivePhase.degraded) {
      final state = _store.peek(session);
      _publish(
        session,
        SessionLiveView(
          session: session,
          // A session added to a live stream hydrates on its own first.
          phase: _phase == SessionLivePhase.live && !_isLive(state)
              ? SessionLivePhase.hydrating
              : _phase,
          version: version,
          lastSyncedAt: previous?.lastSyncedAt,
          stale: previous?.lastSyncedAt != null,
          // Other screens keep the last content while it re-hydrates.
          state: previous?.state ?? state,
        ),
      );
    }
    final handle = _LiveHandle(this, session);
    handles.add(handle);
    return handle;
  }

  static bool _isLive(SessionState? state) =>
      state?.connection.kind.known == ConnectionKind.live;

  SessionLiveView view(SessionRef session) =>
      _views[session] ??
      SessionLiveView(session: session, phase: SessionLivePhase.closed);

  void _publish(SessionRef session, SessionLiveView view) {
    final stop = _stops[session];
    final execution = view.state?.execution;
    if (stop != null &&
        execution != null &&
        view.phase == SessionLivePhase.live &&
        !view.stale) {
      if (execution.kind.known != ExecutionKind.running) {
        stop.settled = true;
      }
    }
    // Hydration reconstructs lastOutcome objects even for the same running
    // execution. Only an observed non-running state proves settlement. Latch
    // it if it beats HTTP, and clear an uncertain wait too when it arrives late.
    if (stop != null &&
        stop.settled &&
        !stop.inFlight &&
        (stop.state.phase == SessionStopPhase.requested ||
            stop.state.phase == SessionStopPhase.unconfirmed)) {
      stop.timer?.cancel();
      stop.state = const SessionStopState();
    }
    _views[session] = view;
    for (final handle in handles.toList()) {
      if (handle.session == session) handle.emit(view);
    }
  }

  SessionStopState stopState(SessionRef ref) =>
      _stops[ref]?.state ?? const SessionStopState();

  bool canStop(SessionRef ref) {
    final current = view(ref);
    return !isClosed &&
        _interrupt != null &&
        !stopState(ref).busy &&
        _stops[ref]?.inFlight != true &&
        current.phase == SessionLivePhase.live &&
        !current.stale &&
        current.state?.execution?.kind.known == ExecutionKind.running;
  }

  Future<void> stop(SessionRef ref, CommandId id) async {
    final client = _interrupt;
    if (client == null || !canStop(ref)) return;
    _stops[ref]?.dispose();
    final request = _StopRequest();
    _stops[ref] = request;
    _publish(ref, view(ref));
    final attempt = await client.interrupt(
      session: ref,
      id: id,
      cancellation: request.cancellation,
    );
    if (isClosed || !identical(_stops[ref], request)) return;
    request.inFlight = false;
    final receipt = attempt.receipt;
    final phase = switch (receipt.state.known) {
      ReceiptState.accepted when attempt.interrupted == false =>
        SessionStopPhase.idle,
      ReceiptState.accepted when request.settled => SessionStopPhase.ready,
      ReceiptState.accepted => SessionStopPhase.requested,
      ReceiptState.rejected ||
      ReceiptState.unavailable => SessionStopPhase.refused,
      _ => SessionStopPhase.unconfirmed,
    };
    request.state = SessionStopState(phase: phase, receipt: receipt);
    if (phase == SessionStopPhase.requested) {
      // The request was accepted, not settled. Bound the local waiting state
      // without inferring success or automatically repeating the mutation.
      request.timer = Timer(const Duration(seconds: 30), () {
        if (isClosed || !identical(_stops[ref], request)) return;
        request.state = SessionStopState(
          phase: SessionStopPhase.unconfirmed,
          receipt: receipt,
        );
        _publish(ref, view(ref));
      });
    }
    _publish(ref, view(ref));
  }

  void _onUpdate(OpenCodeStreamUpdate update) {
    switch (update) {
      case OpenCodeSessionUpdated(:final ref, :final state):
        final previous = _views[ref];
        if (previous == null) return;
        _observe(ref, state);
        // A disconnect snapshot arrives before the reconnecting update.
        final live = _phase == SessionLivePhase.live && _isLive(state);
        _publish(
          ref,
          SessionLiveView(
            session: ref,
            phase: previous.phase == SessionLivePhase.degraded
                ? SessionLivePhase.degraded
                : _phase == SessionLivePhase.live && !live
                ? SessionLivePhase.hydrating
                : _phase,
            failure: previous.failure,
            version: version,
            lastSyncedAt: live ? _now() : previous.lastSyncedAt,
            // Stale means it was current once; a first hydration is not.
            stale: !live && previous.lastSyncedAt != null,
            state: state,
          ),
        );
      case OpenCodeSessionEvicted(:final ref):
        if (!_views.containsKey(ref)) return;
        _publish(
          ref,
          SessionLiveView(
            session: ref,
            phase: SessionLivePhase.evicted,
            failure: SessionLiveFailure.notFound,
            version: version,
          ),
        );
      case OpenCodeConnectionUpdated(:final kind, :final session):
        final phase = switch (kind) {
          ConnectionKind.hydrating => SessionLivePhase.hydrating,
          ConnectionKind.live => SessionLivePhase.live,
          ConnectionKind.reconnecting => SessionLivePhase.reconnecting,
          ConnectionKind.degraded => SessionLivePhase.degraded,
          ConnectionKind.authRequired => SessionLivePhase.authRequired,
          ConnectionKind.incompatible => SessionLivePhase.incompatible,
          _ => SessionLivePhase.connecting,
        };
        final failure = switch (phase) {
          SessionLivePhase.degraded => SessionLiveFailure.unavailable,
          SessionLivePhase.authRequired =>
            SessionLiveFailure.authenticationRequired,
          SessionLivePhase.incompatible =>
            SessionLiveFailure.incompatibleResponse,
          _ => null,
        };
        if (session == null) {
          _phase = phase;
          // A terminal stream never recovers; new leases get a fresh slot
          // while open screens keep showing this one until they retry.
          if (phase == SessionLivePhase.authRequired ||
              phase == SessionLivePhase.incompatible) {
            _release();
          }
        }
        for (final MapEntry(key: ref, value: previous)
            in _views.entries.toList()) {
          if (session != null && session != ref) continue;
          // A session set aside stays aside until a new generation hydrates.
          final keep =
              session == null &&
              previous.phase == SessionLivePhase.degraded &&
              phase == SessionLivePhase.live;
          if (previous.phase == SessionLivePhase.evicted) continue;
          final live = phase == SessionLivePhase.live && !keep;
          _publish(
            ref,
            SessionLiveView(
              session: ref,
              phase: keep ? SessionLivePhase.degraded : phase,
              failure: keep ? previous.failure : failure,
              version: version,
              lastSyncedAt: live && previous.state != null
                  ? _now()
                  : previous.lastSyncedAt,
              stale: !live && previous.lastSyncedAt != null,
              state: previous.state,
            ),
          );
        }
    }
  }

  /// Minted ids must sort after the server's: ids rise, so the pending rows
  /// and the newest items carry the floor.
  void _observe(SessionRef ref, SessionState state) {
    final timeline = state.timeline;
    for (final id in [
      for (final entry in state.pending) entry.id,
      for (final item in timeline.skip(max(0, timeline.length - 16))) item.id,
    ]) {
      if (openCodeMessageIdOf(id, ref) case final message?) {
        ids.observe(message);
      }
    }
  }

  void release(_LiveHandle handle) {
    if (!handles.remove(handle)) return;
    if (!handles.any((h) => h.session == handle.session)) {
      _owner?.unwatch(handle.session);
      _views.remove(handle.session);
      _stops.remove(handle.session)?.dispose();
    }
    if (handles.isEmpty) {
      _release();
      unawaited(close());
    }
  }

  bool get isClosed => _closing != null;

  Future<void> close() => _closing ??= _shutdown();

  Future<void> _shutdown() async {
    for (final stop in _stops.values) {
      stop.dispose();
    }
    _stops.clear();
    for (final handle in handles.toList()) {
      handle.detach();
    }
    handles.clear();
    await _subscription?.cancel();
    await _owner?.close();
    await _connection?.close();
    _reader.dispose();
    _transport.close();
    _store.clear();
  }
}

final class _StopRequest {
  final cancellation = RequestCancellation();
  bool inFlight = true;
  bool settled = false;
  Timer? timer;
  SessionStopState state = const SessionStopState(
    phase: SessionStopPhase.requesting,
  );
  void dispose() {
    timer?.cancel();
    cancellation.cancel();
  }
}

final class _LiveHandle implements SessionLiveHandle {
  _LiveHandle(this._slot, this.session);
  final _ProfileSlot _slot;
  @override
  final SessionRef session;
  final _controller = StreamController<SessionLiveView>.broadcast();
  bool _closed = false;

  @override
  SessionLiveView get current => _closed
      ? SessionLiveView(session: session, phase: SessionLivePhase.closed)
      : _slot.view(session);

  @override
  Stream<SessionLiveView> get updates => Stream.multi((listener) {
    listener.add(current);
    final subscription = _controller.stream.listen(
      listener.add,
      onDone: listener.close,
    );
    listener.onCancel = subscription.cancel;
  });

  @override
  PromptOutbox? get outbox => _closed ? null : _slot.outbox;

  @override
  SessionStopState get stopState =>
      _closed ? const SessionStopState() : _slot.stopState(session);

  @override
  bool get canStop => !_closed && _slot.canStop(session);

  @override
  Future<void> stop({required CommandId id}) async {
    if (!_closed) await _slot.stop(session, id);
  }

  @override
  String? nativeMessageOf(ItemId id) => openCodeMessageIdOf(id, session);

  void emit(SessionLiveView view) {
    if (!_closed) _controller.add(view);
  }

  void detach() {
    if (_closed) return;
    _controller.add(
      SessionLiveView(session: session, phase: SessionLivePhase.closed),
    );
    _closed = true;
    unawaited(_controller.close());
  }

  @override
  void close() {
    if (_closed) return;
    _slot.release(this);
    detach();
  }
}
