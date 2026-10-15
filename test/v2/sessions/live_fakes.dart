import 'dart:async';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';

class LiveHandle implements SessionLiveHandle {
  LiveHandle(this.session);
  @override
  final SessionRef session;
  final _controller = StreamController<SessionLiveView>.broadcast();
  late SessionLiveView _current = SessionLiveView(
    session: session,
    phase: SessionLivePhase.connecting,
  );
  int closes = 0;
  @override
  SessionLiveView get current => _current;
  @override
  Stream<SessionLiveView> get updates => Stream.multi((listener) {
    listener.add(_current);
    final subscription = _controller.stream.listen(listener.add);
    listener.onCancel = subscription.cancel;
  });
  void emit(SessionLiveView view) {
    _current = view;
    _controller.add(view);
  }

  @override
  void close() => closes++;
}

class LiveDirectory implements SessionLiveDirectory {
  final opens = <Completer<SessionLiveHandle>>[];
  final credentials = <EndpointCredential>[];
  final handles = <LiveHandle>[];
  int closes = 0;
  @override
  Future<SessionLiveHandle> open({
    required EndpointProfile profile,
    required EndpointCredential credential,
    required SessionRef session,
  }) {
    credentials.add(credential);
    final completer = Completer<SessionLiveHandle>();
    opens.add(completer);
    return completer.future;
  }

  LiveHandle grant(SessionRef session) {
    final handle = LiveHandle(session);
    handles.add(handle);
    opens.last.complete(handle);
    return handle;
  }

  void fail(SessionLiveFailure failure) =>
      opens.last.completeError(SessionLiveException(failure));
  @override
  Future<void> close() async => closes++;
}

final _now = DateTime.utc(2026, 10, 15);

SnapshotBoundary _boundary(SessionRef ref) => SnapshotBoundary(
  owner: SessionOwner(ref),
  hydrationGeneration: 'live',
  readStart: StreamPosition(id: 'stream', epoch: 'e', seq: BigInt.one),
  readStartedAt: _now,
  authority: const OpenValue.known(SnapshotAuthority.authoritative),
);

ItemMeta liveMeta(SessionRef ref, String id) => ItemMeta(
  id: ItemId(id),
  generation: 'live',
  status: const OpenValue.known(ItemStatus.completed),
  source: SourceProvenance(
    harness: ref.harnessRef,
    version: '2.0.22',
    nativeType: 'live',
  ),
);

/// A hydrated canonical state, built through the Core reducer like the
/// native stream owner does.
SessionState liveState(
  SessionRef ref, {
  List<TimelineItem> items = const [],
  ExecutionState? execution,
  List<InteractionRequest> interactions = const [],
  bool hasMore = false,
}) {
  final start = beginHydration(
    SessionState(
      ref,
      streamPosition: StreamPosition(
        id: 'stream',
        epoch: 'e',
        seq: BigInt.zero,
      ),
    ),
    generation: 'live',
    readStart: StreamPosition(id: 'stream', epoch: 'e', seq: BigInt.one),
  );
  return hydrate(
    start,
    SessionSnapshot(
      ref: ref,
      hydrationGeneration: 'live',
      execution: execution == null
          ? null
          : SnapshotValue(value: execution, boundary: _boundary(ref)),
      timeline: SnapshotCollection(values: items, boundary: _boundary(ref)),
      interactions: SnapshotCollection(
        values: interactions,
        boundary: _boundary(ref),
      ),
      hasMoreHistory: hasMore,
    ),
  ).state;
}
