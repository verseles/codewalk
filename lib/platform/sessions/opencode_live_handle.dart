import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';
import '../../shared/sessions/prompt_outbox.dart';
import '../../shared/sessions/session_live_source.dart';
import '../../shared/sessions/session_permission_reply.dart';
import '../../shared/sessions/session_selection.dart';
import '../../shared/sessions/session_stop.dart';
import '../../shared/sessions/session_unrestricted.dart';
import 'opencode_profile_slot.dart';

/// One live session's lease on an [OpenCodeProfileSlot]. It only delegates to
/// the slot, and lives in its own file so the slot stays below the
/// architecture guard's file-size limit.
final class OpenCodeLiveHandle implements SessionLiveHandle {
  OpenCodeLiveHandle(this._slot, this.session);
  final OpenCodeProfileSlot _slot;
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
  SessionOlderHistoryState get olderHistory =>
      _closed ? const SessionOlderHistoryState() : _slot.olderHistory(session);

  @override
  bool get canLoadOlderHistory =>
      !_closed && _slot.canLoadOlderHistory(session);

  @override
  Future<void> loadOlderHistory() async {
    if (!_closed) await _slot.loadOlderHistory(session);
  }

  @override
  bool get supportsUnrestricted => !_closed && _slot.supportsUnrestricted;

  @override
  SessionUnrestrictedState get unrestrictedState => _closed
      ? const SessionUnrestrictedState()
      : _slot.unrestrictedState(session);

  @override
  bool get canEnableUnrestricted =>
      !_closed && _slot.canEnableUnrestricted(session);

  @override
  bool get canDisableUnrestricted =>
      !_closed && _slot.canDisableUnrestricted(session);

  @override
  bool get canRefreshUnrestricted =>
      !_closed && _slot.canRefreshUnrestricted(session);

  @override
  Future<void> enableUnrestricted({required CommandId id}) async {
    if (!_closed) await _slot.enableUnrestricted(session, id);
  }

  @override
  Future<void> disableUnrestricted({required CommandId id}) async {
    if (!_closed) await _slot.disableUnrestricted(session, id);
  }

  @override
  Future<void> refreshUnrestricted() async {
    if (!_closed && _slot.canRefreshUnrestricted(session)) {
      await _slot.refreshUnrestricted(session);
    }
  }

  @override
  bool get supportsSelection => !_closed && _slot.selection != null;

  @override
  SessionSelectionState get selectionState => _closed
      ? const SessionSelectionState()
      : _slot.selection?.state(session) ??
            SessionSelectionState(selection: current.state?.selection);

  @override
  bool get canChangeSelection =>
      !_closed && (_slot.selection?.canChange(session) ?? false);

  @override
  Future<void> selectModel({
    required String modelId,
    required String providerId,
    String? variant,
    required CommandId id,
  }) async {
    if (_closed) return;
    await _slot.selection?.selectModel(
      session,
      modelId: modelId,
      providerId: providerId,
      variant: variant,
      id: id,
    );
  }

  @override
  Future<void> selectAgent({
    required String agentId,
    required CommandId id,
  }) async {
    if (_closed) return;
    await _slot.selection?.selectAgent(session, agentId: agentId, id: id);
  }

  @override
  Future<void> refreshSelection() async {
    if (!_closed) await _slot.selection?.refresh(session);
  }

  @override
  bool get supportsReplies => !_closed && _slot.supportsReplies;

  @override
  SessionPermissionReplyState replyState(
    InteractionId id, {
    SessionRef? owner,
  }) => _closed
      ? const SessionPermissionReplyState()
      : _slot.replyState(session, id, owner: owner);

  @override
  bool canReply(InteractionRequest request) =>
      !_closed && _slot.canReply(session, request);

  @override
  Future<void> reply({
    required InteractionRequest request,
    required ApprovalResponse response,
    required CommandId id,
  }) async {
    if (!_closed) {
      await _slot.reply(
        ref: session,
        request: request,
        response: response,
        id: id,
      );
    }
  }

  @override
  bool canReplyForm(InteractionRequest request) =>
      !_closed && _slot.canReplyForm(session, request);

  @override
  Future<void> replyForm({
    required InteractionRequest request,
    required FormResponse response,
    required CommandId id,
  }) async {
    if (!_closed) {
      await _slot.replyForm(
        ref: session,
        request: request,
        response: response,
        id: id,
      );
    }
  }

  @override
  Future<void> dismissForm({
    required InteractionRequest request,
    required CommandId id,
  }) async {
    if (!_closed) {
      await _slot.dismissForm(ref: session, request: request, id: id);
    }
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
