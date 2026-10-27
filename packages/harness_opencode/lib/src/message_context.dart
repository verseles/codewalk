import 'package:codewalk_core/codewalk_core.dart';

/// The message context a live part carries.
///
/// The running step's facts apply when the part belongs to its message; what
/// the resident item already knew (for example a completion a step end
/// recorded) is kept unless the step reports a newer value.
MessageContext liveMessageContext(
  SessionState current,
  ItemId id,
  String messageId,
) {
  final message = MessageRef(messageId);
  final step = current.currentStep;
  final fresh = step == null || step.message != message
      ? MessageContext(message: message)
      : MessageContext(
          message: message,
          created: step.startedAt,
          modelId: step.modelId,
          modelProviderId: step.modelProviderId,
          modelVariant: step.modelVariant,
          agentId: step.agentId,
        );
  for (final item in current.timeline) {
    if (item.id != id) continue;
    final resident = item.meta.message;
    return resident != null && resident.message == message
        ? resident.merge(fresh)
        : fresh;
  }
  return fresh;
}
