import 'dart:async';
import 'package:codewalk/shared/sessions/prompt_outbox.dart';
import 'package:codewalk/shared/sessions/session_catalog_changes.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/sessions/session_permission_reply.dart';
import 'package:codewalk/shared/sessions/session_selection.dart';
import 'package:codewalk/shared/sessions/session_stop.dart';
import 'package:codewalk/shared/sessions/session_unrestricted.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';

import 'fakes.dart';

class LiveHandle implements SessionLiveHandle {
  LiveHandle(this.session, {this.outbox});
  @override
  final SessionRef session;
  @override
  PromptOutbox? outbox;
  bool stopAvailable = false;
  Future<SessionStopState> Function(CommandId)? stopAction;
  final stops = <CommandId>[];
  @override
  SessionStopState stopState = const SessionStopState();
  @override
  bool get canStop =>
      stopAvailable &&
      closes == 0 &&
      !stopState.busy &&
      current.phase == SessionLivePhase.live &&
      !current.stale &&
      switch (current.state?.execution?.kind.known) {
        ExecutionKind.running || ExecutionKind.retrying => true,
        _ => false,
      };
  @override
  Future<void> stop({required CommandId id}) async {
    if (!canStop) return;
    stops.add(id);
    stopState = const SessionStopState(phase: SessionStopPhase.requesting);
    emit(current);
    stopState =
        await (stopAction?.call(id) ??
            Future.value(
              const SessionStopState(phase: SessionStopPhase.requested),
            ));
    if (closes == 0) emit(current);
  }

  /// Older paging: off unless a test supplies [olderAction], which returns
  /// the failure of that read (null on success) and may emit a new view.
  Future<SessionLiveFailure?> Function()? olderAction;
  int olderLoads = 0;
  @override
  SessionOlderHistoryState olderHistory = const SessionOlderHistoryState();
  @override
  bool get canLoadOlderHistory =>
      olderAction != null &&
      closes == 0 &&
      !olderHistory.loading &&
      current.phase == SessionLivePhase.live &&
      !current.stale &&
      current.state?.nextHistoryCursor != null &&
      current.state!.timeline.length < current.state!.limits.maxItems;
  @override
  Future<void> loadOlderHistory() async {
    if (!canLoadOlderHistory) return;
    olderLoads++;
    olderHistory = const SessionOlderHistoryState(loading: true);
    emit(current);
    final failure = await olderAction!();
    olderHistory = SessionOlderHistoryState(failure: failure);
    if (closes == 0) emit(current);
  }

  @override
  String? nativeMessageOf(ItemId id) => openCodeMessageIdOf(id, session);
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

  bool replyAvailable = false;
  @override
  bool get supportsReplies => replyAvailable && closes == 0;
  Future<SessionPermissionReplyState> Function(
    InteractionRequest,
    ApprovalResponse,
  )?
  replyAction;
  final replies = <(InteractionId, String, String?, CommandId)>[];
  final _replyStates = <String, SessionPermissionReplyState>{};

  String _replyKey(InteractionId id, SessionRef? owner) =>
      owner != null ? '${owner.nativeId}/${id.value}' : id.value;

  @override
  SessionPermissionReplyState replyState(
    InteractionId id, {
    SessionRef? owner,
  }) =>
      _replyStates[_replyKey(id, owner)] ?? const SessionPermissionReplyState();

  @override
  bool canReply(InteractionRequest request) {
    final owner = request.owner;
    final child = owner is SessionOwner && owner.session != session
        ? owner.session
        : null;
    return replyAvailable &&
        closes == 0 &&
        request.kind.known == InteractionKind.permission &&
        owner is SessionOwner &&
        (owner.session == session || owner.origin == session) &&
        current.phase == SessionLivePhase.live &&
        !current.stale &&
        (current.state?.interactions.any(
              (r) => r.id.value == request.id.value,
            ) ??
            false) &&
        !replyState(request.id, owner: child).busy;
  }

  @override
  Future<void> reply({
    required InteractionRequest request,
    required ApprovalResponse response,
    required CommandId id,
  }) async {
    if (!canReply(request)) return;
    final owner = request.owner;
    final child = owner is SessionOwner && owner.session != session
        ? owner.session
        : null;
    final key = _replyKey(request.id, child);
    replies.add((request.id, response.choiceId, response.note, id));
    _replyStates[key] = const SessionPermissionReplyState(
      phase: SessionPermissionReplyPhase.requesting,
    );
    emit(current);
    final result =
        await (replyAction?.call(request, response) ??
            Future.value(
              const SessionPermissionReplyState(
                phase: SessionPermissionReplyPhase.requested,
              ),
            ));
    if (closes == 0) {
      _replyStates[key] = result;
      emit(current);
    }
  }

  final formReplies = <(InteractionId, FormResponse, CommandId)>[];
  final formDismissals = <(InteractionId, CommandId)>[];
  Future<SessionPermissionReplyState> Function(
    InteractionRequest,
    FormResponse?,
  )?
  formAction;

  @override
  bool canReplyForm(InteractionRequest request) {
    final owner = request.owner;
    final child = owner is SessionOwner && owner.session != session
        ? owner.session
        : null;
    return replyAvailable &&
        closes == 0 &&
        request.kind.known == InteractionKind.form &&
        (owner is GlobalOwner ||
            (owner is SessionOwner &&
                (owner.session == session || owner.origin == session))) &&
        current.phase == SessionLivePhase.live &&
        !current.stale &&
        (current.state?.interactions.any(
              (r) => r.id.value == request.id.value,
            ) ??
            false) &&
        !replyState(request.id, owner: child).busy;
  }

  @override
  Future<void> replyForm({
    required InteractionRequest request,
    required FormResponse response,
    required CommandId id,
  }) async {
    if (!canReplyForm(request)) return;
    final owner = request.owner;
    final child = owner is SessionOwner && owner.session != session
        ? owner.session
        : null;
    final key = _replyKey(request.id, child);
    formReplies.add((request.id, response, id));
    _replyStates[key] = const SessionPermissionReplyState(
      phase: SessionPermissionReplyPhase.requesting,
    );
    emit(current);
    final result =
        await (formAction?.call(request, response) ??
            Future.value(
              const SessionPermissionReplyState(
                phase: SessionPermissionReplyPhase.requested,
              ),
            ));
    if (closes == 0) {
      _replyStates[key] = result;
      emit(current);
    }
  }

  @override
  Future<void> dismissForm({
    required InteractionRequest request,
    required CommandId id,
  }) async {
    if (!canReplyForm(request)) return;
    final owner = request.owner;
    final child = owner is SessionOwner && owner.session != session
        ? owner.session
        : null;
    final key = _replyKey(request.id, child);
    formDismissals.add((request.id, id));
    _replyStates[key] = const SessionPermissionReplyState(
      phase: SessionPermissionReplyPhase.requesting,
    );
    emit(current);
    final result =
        await (formAction?.call(request, null) ??
            Future.value(
              const SessionPermissionReplyState(
                phase: SessionPermissionReplyPhase.requested,
              ),
            ));
    if (closes == 0) {
      _replyStates[key] = result;
      emit(current);
    }
  }

  bool unrestrictedAvailable = false;
  @override
  SessionUnrestrictedState unrestrictedState = const SessionUnrestrictedState();
  final unrestrictedCalls = <String>[];
  SessionUnrestrictedState Function(String change)? unrestrictedAction;

  bool get _unrestrictedReady =>
      unrestrictedAvailable &&
      closes == 0 &&
      !unrestrictedState.busy &&
      current.phase == SessionLivePhase.live &&
      !current.stale;

  @override
  bool get supportsUnrestricted => unrestrictedAvailable && closes == 0;
  @override
  bool get canEnableUnrestricted =>
      _unrestrictedReady &&
      unrestrictedState.phase == SessionUnrestrictedPhase.off;
  @override
  bool get canDisableUnrestricted =>
      _unrestrictedReady &&
      unrestrictedState.phase == SessionUnrestrictedPhase.on;
  @override
  bool get canRefreshUnrestricted => _unrestrictedReady;

  Future<void> _unrestricted(String change, bool allowed) async {
    if (!allowed) return;
    unrestrictedCalls.add(change);
    final action = unrestrictedAction;
    if (action != null) unrestrictedState = action(change);
    emit(current);
  }

  @override
  Future<void> enableUnrestricted({required CommandId id}) =>
      _unrestricted('enable', canEnableUnrestricted);
  @override
  Future<void> disableUnrestricted({required CommandId id}) =>
      _unrestricted('disable', canDisableUnrestricted);
  @override
  Future<void> refreshUnrestricted() =>
      _unrestricted('refresh', canRefreshUnrestricted);

  /// Selection: off unless a test sets [selectionAvailable]; [selectionAction]
  /// answers each switch or refresh with the state that follows it.
  bool selectionAvailable = false;
  @override
  SessionSelectionState selectionState = const SessionSelectionState();
  final selectionCalls = <String>[];
  final selectionIds = <CommandId>[];
  Future<SessionSelectionState> Function(String change)? selectionAction;

  @override
  bool get supportsSelection => selectionAvailable && closes == 0;

  /// A switch the server took and has not reported yet: like the lane, the
  /// next pick waits for that report.
  bool awaitingEcho = false;
  @override
  bool get canChangeSelection =>
      supportsSelection &&
      !awaitingEcho &&
      selectionState.phase != SessionSelectionPhase.pending &&
      current.phase == SessionLivePhase.live &&
      !current.stale;

  Future<void> _select(String change, CommandId? id, bool allowed) async {
    if (!allowed) return;
    selectionCalls.add(change);
    if (id != null) selectionIds.add(id);
    final action = selectionAction;
    if (action == null) return emit(current);
    selectionState = await action(change);
    if (closes == 0) emit(current);
  }

  @override
  Future<void> selectModel({
    required String modelId,
    required String providerId,
    String? variant,
    required CommandId id,
  }) => _select(
    'model:$providerId/$modelId${variant == null ? '' : ':$variant'}',
    id,
    canChangeSelection,
  );
  @override
  Future<void> selectAgent({required String agentId, required CommandId id}) =>
      _select('agent:$agentId', id, canChangeSelection);
  @override
  Future<void> refreshSelection() =>
      _select('refresh', null, supportsSelection);
}

class LiveDirectory implements SessionLiveDirectory {
  @override
  void reconcileProfiles({
    required List<EndpointProfile> profiles,
    required Map<String, EndpointCredential> credentials,
    required bool available,
    String? changingProfile,
  }) {}

  final opens = <Completer<SessionLiveHandle>>[];
  final credentials = <EndpointCredential>[];
  final handles = <LiveHandle>[];
  final feeds = <LiveCatalogChanges>[];
  int closes = 0;
  int wakes = 0;
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

  LiveHandle grant(SessionRef session, {PromptOutbox? outbox}) {
    final handle = LiveHandle(session, outbox: outbox);
    handles.add(handle);
    opens.last.complete(handle);
    return handle;
  }

  void fail(SessionLiveFailure failure) =>
      opens.last.completeError(SessionLiveException(failure));

  @override
  Future<SessionCatalogChanges> catalogChanges({
    required EndpointProfile profile,
    required EndpointCredential credential,
  }) async {
    final feed = LiveCatalogChanges();
    feeds.add(feed);
    return feed;
  }

  @override
  void wake() => wakes++;

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
  List<PendingInput> pending = const [],
  List<WorkItem> work = const [],
  bool hasMore = false,
  String? cursor,
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
      pending: SnapshotCollection(values: pending, boundary: _boundary(ref)),
      interactions: SnapshotCollection(
        values: interactions,
        boundary: _boundary(ref),
      ),
      work: SnapshotCollection(values: work, boundary: _boundary(ref)),
      nextHistoryCursor: cursor == null ? null : HistoryCursor(cursor),
      hasMoreHistory: hasMore || cursor != null,
    ),
  ).state;
}
