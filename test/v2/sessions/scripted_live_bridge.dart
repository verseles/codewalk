import 'dart:async';

import 'package:codewalk/shared/sessions/prompt_outbox.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/sessions/session_permission_reply.dart';
import 'package:codewalk/shared/sessions/session_stop.dart';
import 'package:codewalk/shared/sessions/session_unrestricted.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';

import '../../../packages/codewalk_core/test/support/scripted_harness_adapter.dart';
import '../../../packages/codewalk_core/test/support/scripted_harness_scenarios.dart';

/// Test-only bridge: serves a real `SessionLiveDirectory`/`SessionLiveHandle`
/// from a synthetic `ScriptedHarnessAdapter` plus the real `SessionStore`, so
/// the shared session screens drive the exact same lease contract as the
/// native transport, without any harness code reaching `lib/`.
///
/// Choreography is declarative and FIFO, mirroring the adapter's authored
/// outcomes: [sendIds], [respondIds] and [interruptIds] are consumed in order,
/// and the UI's own minted `CommandId`s are ignored in favor of the authored
/// ids. Hydration replays one explicit client read cycle per generation in
/// [hydrations], exactly like the accepted reducer consumer does.
final class ScriptedLiveBridge implements SessionLiveDirectory {
  ScriptedLiveBridge(
    this.scenario, {
    this.intent = OpenIntent.attachLive,
    this.hydrations = const [],
    this.sendIds = const [],
    this.respondIds = const [],
    this.interruptIds = const [],
    this.readLimit = 50,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    if (readLimit <= 0 || readLimit > 500) {
      throw ArgumentError('Read limit must be bounded');
    }
  }

  final ScriptedScenario scenario;
  final OpenIntent intent;

  /// One client-initiated read per generation, in the authored read order.
  final List<String> hydrations;
  final List<CommandId> sendIds;
  final List<CommandId> respondIds;
  final List<CommandId> interruptIds;
  final int readLimit;
  final DateTime Function() _now;

  final SessionStore store = SessionStore(maxSessions: 4);
  ScriptedLiveHandle? handle;
  int closes = 0;

  ScriptedHarnessAdapter get adapter => scenario.adapter;
  SessionRef get ref => scenario.ref;

  @override
  Future<SessionLiveHandle> open({
    required EndpointProfile profile,
    required EndpointCredential credential,
    required SessionRef session,
  }) async {
    if (session != ref) {
      throw const SessionLiveException(SessionLiveFailure.incompatibleResponse);
    }
    final native = await adapter.open(ref, intent);
    final opened = ScriptedLiveHandle(this, native);
    handle = opened;
    return opened;
  }

  @override
  Future<void> close() async => closes++;
}

/// One lease over the scripted adapter. It applies every observation through
/// the real reducer, tracks the observer phase locally (the reducer state's
/// connection is an input, not this lease's phase) and never sends on its own.
final class ScriptedLiveHandle implements SessionLiveHandle {
  ScriptedLiveHandle(this.bridge, this._native) {
    bridge.store.open(session);
    _eventSubscription = _native.events.listen(_onEvent);
    _connectionSubscription = bridge.adapter.connection.listen(_onConnection);
    for (final generation in bridge.hydrations) {
      bridge.store.startHydration(
        session,
        generation: generation,
        readStart: bridge.adapter.position(session),
      );
      unawaited(
        _native
            .snapshot(limit: bridge.readLimit)
            .then(_onSnapshot)
            .catchError((Object _) {}),
      );
    }
    _phase = bridge.hydrations.isEmpty
        ? SessionLivePhase.connecting
        : SessionLivePhase.hydrating;
  }

  final ScriptedLiveBridge bridge;
  final SessionHandle _native;
  late final StreamSubscription<SessionEvent> _eventSubscription;
  late final StreamSubscription<ConnectionState> _connectionSubscription;
  final _controller = StreamController<SessionLiveView>.broadcast();
  SessionLivePhase _phase = SessionLivePhase.connecting;
  DateTime? _lastSyncedAt;
  int _closes = 0;
  bool _stopping = false;
  int _nextRespond = 0;
  int _nextInterrupt = 0;
  late SessionLiveView _current = SessionLiveView(
    session: session,
    phase: _phase,
  );

  @override
  SessionRef get session => _native.ref;

  bool get _repliesEnabled =>
      bridge.intent == OpenIntent.attachLive &&
      bridge.adapter.interactions != null &&
      _closes == 0;

  bool get _stale =>
      _phase != SessionLivePhase.live && _lastSyncedAt != null;

  @override
  SessionLiveView get current => _current;

  @override
  Stream<SessionLiveView> get updates => Stream.multi((listener) {
    listener.add(_current);
    final subscription = _controller.stream.listen(listener.add);
    listener.onCancel = subscription.cancel;
  });

  @override
  PromptOutbox? get outbox =>
      bridge.sendIds.isEmpty || bridge.intent != OpenIntent.attachLive
      ? null
      : _outbox ??= ScriptedPromptOutbox(this);

  ScriptedPromptOutbox? _outbox;

  @override
  String? nativeMessageOf(ItemId id) => openCodeMessageIdOf(id, session);

  @override
  void close() {
    if (_closes++ > 0) return;
    unawaited(_eventSubscription.cancel());
    unawaited(_connectionSubscription.cancel());
    unawaited(_native.detach());
  }

  int get closes => _closes;

  void _onEvent(SessionEvent event) {
    if (_closes > 0) return;
    bridge.store.apply(session, event);
    _emit();
  }

  void _onConnection(ConnectionState state) {
    if (_closes > 0) return;
    switch (state.kind.known) {
      case ConnectionKind.reconnecting:
        bridge.store.disconnected(session);
        _phase = SessionLivePhase.reconnecting;
      case ConnectionKind.live:
        _phase = SessionLivePhase.live;
      default:
        return;
    }
    _emit();
  }

  void _onSnapshot(SessionSnapshot snapshot) {
    if (_closes > 0) return;
    final state = bridge.store.peek(session);
    // A generation the client already superseded is ignored by the reducer
    // itself; the observer phase follows.
    if (state?.hydrationGeneration != snapshot.hydrationGeneration) return;
    bridge.store.applySnapshot(session, snapshot);
    _phase = SessionLivePhase.live;
    _lastSyncedAt = bridge._now();
    _emit();
  }

  void _emit() {
    if (_closes > 0) return;
    _current = SessionLiveView(
      session: session,
      phase: _phase,
      lastSyncedAt: _lastSyncedAt,
      stale: _stale,
      state: bridge.store.peek(session),
    );
    _controller.add(_current);
  }

  @override
  SessionStopState stopState = const SessionStopState();

  @override
  bool get canStop =>
      bridge.intent == OpenIntent.attachLive &&
      _closes == 0 &&
      !_stopping &&
      _phase == SessionLivePhase.live &&
      !_stale &&
      _nextInterrupt < bridge.interruptIds.length &&
      bridge.store.peek(session)?.execution?.kind.known ==
          ExecutionKind.running;

  @override
  Future<void> stop({required CommandId id}) async {
    if (!canStop) return;
    final authored = bridge.interruptIds[_nextInterrupt++];
    _stopping = true;
    stopState = const SessionStopState(phase: SessionStopPhase.requesting);
    _emit();
    final receipt = await _native.interrupt(scriptedInterrupt, id: authored);
    if (_closes > 0) return;
    _stopping = false;
    stopState = SessionStopState(
      phase: switch (receipt.state.known) {
        ReceiptState.accepted => SessionStopPhase.requested,
        ReceiptState.uncertain => SessionStopPhase.unconfirmed,
        _ => SessionStopPhase.refused,
      },
      receipt: receipt,
    );
    _emit();
  }

  final _replyStates = <String, SessionPermissionReplyState>{};

  String _replyKey(InteractionId id, SessionRef? owner) =>
      owner != null ? '${owner.nativeId}/${id.value}' : id.value;

  @override
  bool get supportsReplies => _repliesEnabled;

  @override
  SessionPermissionReplyState replyState(
    InteractionId id, {
    SessionRef? owner,
  }) =>
      _replyStates[_replyKey(id, owner)] ??
      const SessionPermissionReplyState();

  @override
  bool canReply(InteractionRequest request) {
    final owner = request.owner;
    final child = owner is SessionOwner && owner.session != session
        ? owner.session
        : null;
    return _repliesEnabled &&
        request.kind.known == InteractionKind.permission &&
        owner is SessionOwner &&
        (owner.session == session || owner.origin == session) &&
        _phase == SessionLivePhase.live &&
        !_stale &&
        (bridge.store
                .peek(session)
                ?.interactions
                .any(
                  (r) => r.id == request.id && r.owner.hasSameScope(owner),
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
    final authored = _nextRespond < bridge.respondIds.length
        ? bridge.respondIds[_nextRespond++]
        : null;
    _replyStates[key] = const SessionPermissionReplyState(
      phase: SessionPermissionReplyPhase.requesting,
    );
    _emit();
    final receipt = authored == null
        ? CommandReceipt.unavailable(
            id: id,
            owner: owner,
            unavailable: CapabilityUnavailable(
              'approval.interactive',
              reason: 'notScripted',
            ),
          )
        : await bridge.adapter.interactions!.respond(
            owner,
            request.id,
            response,
            id: authored,
          );
    if (_closes > 0) return;
    _replyStates[key] = SessionPermissionReplyState(
      phase: switch (receipt.state.known) {
        ReceiptState.accepted => SessionPermissionReplyPhase.requested,
        ReceiptState.uncertain => SessionPermissionReplyPhase.unconfirmed,
        _ => SessionPermissionReplyPhase.refused,
      },
      receipt: receipt,
    );
    _emit();
  }

  @override
  bool canReplyForm(InteractionRequest request) => false;

  @override
  Future<void> replyForm({
    required InteractionRequest request,
    required FormResponse response,
    required CommandId id,
  }) async {}

  @override
  Future<void> dismissForm({
    required InteractionRequest request,
    required CommandId id,
  }) async {}

  @override
  bool get supportsUnrestricted => false;

  @override
  SessionUnrestrictedState get unrestrictedState =>
      const SessionUnrestrictedState();

  @override
  bool get canEnableUnrestricted => false;

  @override
  bool get canDisableUnrestricted => false;

  @override
  bool get canRefreshUnrestricted => false;

  @override
  Future<void> enableUnrestricted({required CommandId id}) async {}

  @override
  Future<void> disableUnrestricted({required CommandId id}) async {}

  @override
  Future<void> refreshUnrestricted() async {}
}

/// Ledger for a bridged lease. UI sends are recorded with the UI's own
/// command id, but the wire call posts under the authored id with the authored
/// payload (`scriptedDraft` shape) so the adapter's finite outcomes match.
final class ScriptedPromptOutbox implements PromptOutbox {
  ScriptedPromptOutbox(this.handle);
  final ScriptedLiveHandle handle;
  final _entries = <OutboxEntry>[];
  int _next = 0;

  @override
  Future<OutboxSubmission> submit({
    required SessionRef session,
    required CommandId commandId,
    required PromptDraft draft,
    required Delivery delivery,
  }) async {
    if (_next >= handle.bridge.sendIds.length) {
      return const OutboxSubmission.refused('notScripted');
    }
    final authored = handle.bridge.sendIds[_next++];
    final receipt = await handle._native.send(
      scriptedDraftFor(draft.text),
      id: authored,
    );
    final now = handle.bridge._now();
    final entry = OutboxEntry(
      session: session,
      commandId: commandId,
      messageId: 'message-${commandId.value}',
      text: draft.text,
      delivery: delivery,
      state: switch (receipt.state.known) {
        ReceiptState.accepted => SubmissionKind.admitted,
        ReceiptState.uncertain => SubmissionKind.uncertain,
        ReceiptState.unknown => SubmissionKind.unknown,
        _ => SubmissionKind.rejected,
      },
      createdAt: now,
      updatedAt: now,
      reason: receipt.error?.rawType ?? receipt.unavailable?.reason,
    );
    if (handle._closes == 0) _entries.add(entry);
    return OutboxSubmission.recorded(entry, sent: true);
  }

  @override
  Future<List<OutboxEntry>> entries(SessionRef session) async => List.of(
    _entries.where((entry) => entry.session == session),
  );

  @override
  Future<bool> dismiss(SessionRef session, CommandId commandId) async {
    final before = _entries.length;
    _entries.removeWhere(
      (entry) =>
          entry.session == session &&
          entry.commandId == commandId &&
          entry.state != SubmissionKind.sending,
    );
    return _entries.length != before;
  }

  @override
  Future<OutboxReconciliation> reconcile(
    SessionRef session,
    CommandId commandId,
  ) async => const OutboxReconciliation.refused('notScripted');

  @override
  Future<OutboxMutation> cancel(
    SessionRef session,
    CommandId commandId,
  ) async => const OutboxMutation.refused('notScripted');

  @override
  Future<OutboxMutation> switchDelivery(
    SessionRef session,
    CommandId commandId,
    Delivery delivery,
  ) async => const OutboxMutation.refused('notScripted');
}

/// The authored `scriptedDraft` payload with the composer's text, so a UI send
/// still matches the scenario's `promptIntent(scriptedDraft())` outcome.
PromptDraft scriptedDraftFor(String text) => PromptDraft(
  text: text,
  selection: const Selection(modelId: 'model-alpha'),
  metadata: CanonicalValue({'synthetic': true}),
  attachments: [
    AttachmentRef(
      id: 'picture',
      mimeType: 'image/png',
      name: 'synthetic.png',
      content: OutputRef(
        id: 'opaque-picture',
        mimeType: 'image/png',
        sizeBytes: 3,
      ),
    ),
  ],
  mentions: [
    MentionRef(
      id: 'mention',
      kind: const OpenValue.known(MentionKind.file),
      label: 'synthetic file',
      target: 'opaque-file',
    ),
  ],
);
