import 'errors.dart';
import 'identity.dart';
import 'usage.dart';
import 'values.dart';

enum ItemStatus { pending, streaming, completed, failed, interrupted }

/// Admission and input delivery are independent of execution completion.
enum DeliveryState {
  draft,
  submitting,
  accepted,
  queued,
  delivered,
  rejected,
  uncertain,
  cancelRequested,
  cancelSubmitting,
  cancelUncertain,
  cancelled,
}

enum ToolKind {
  shell,
  read,
  edit,
  write,
  search,
  fetch,
  webSearch,
  mcp,
  subagent,
  question,
  skill,
  other,
}

enum NoticeKind {
  selectionChanged,
  continuation,
  compaction,
  system,
  workCompletion,
}

enum OutcomeKind { succeeded, failed, interrupted }

/// The lifecycle a harness reports for a shell command run in a session.
enum ShellStatus { running, exited, timeout, killed }

enum MentionKind { file, agent, skill, session, item }

/// Opaque reference to adapter-managed content, not an executable native path.
/// Payload loading and transport authorization remain outside the core.
final class OutputRef {
  OutputRef({
    required String id,
    this.mimeType,
    this.sizeBytes,
    this.truncated = false,
  }) : id = requireText(id, 'id') {
    if (mimeType != null) requireText(mimeType!, 'mimeType');
    if (sizeBytes != null && sizeBytes! < 0) {
      throw ArgumentError.value(sizeBytes, 'sizeBytes', 'Must be nonnegative');
    }
  }

  final String id;
  final String? mimeType;
  final int? sizeBytes;
  final bool truncated;
}

final class AttachmentRef {
  AttachmentRef({
    required String id,
    required String mimeType,
    required this.content,
    this.name,
  }) : id = requireText(id, 'id'),
       mimeType = requireText(mimeType, 'mimeType');

  final String id;
  final String mimeType;
  final OutputRef content;
  final String? name;
}

/// The adapter resolves an opaque target; core does not rewrite it as a path.
final class MentionRef {
  MentionRef({
    required String id,
    required this.kind,
    required this.label,
    required String target,
  }) : id = requireText(id, 'id'),
       target = requireText(target, 'target');

  final String id;
  final OpenValue<MentionKind> kind;
  final String label;
  final String target;
}

/// Opaque, adapter-scoped identity of the harness message an item belongs to.
final class MessageRef {
  MessageRef(String value) : value = requireText(value, 'value');

  final String value;

  @override
  bool operator ==(Object other) => other is MessageRef && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Message identity and ordering supplied by the adapter, within one session.
/// Consumers compare anchors; the opaque key is never a native ID parser or
/// evidence that a local/pending input has been confirmed by the harness.
final class MessageAnchor implements Comparable<MessageAnchor> {
  MessageAnchor({required this.message, required String orderKey})
    : orderKey = requireText(orderKey, 'orderKey');

  final MessageRef message;
  final String orderKey;

  @override
  int compareTo(MessageAnchor other) => orderKey.compareTo(other.orderKey);

  @override
  bool operator ==(Object other) =>
      other is MessageAnchor &&
      other.message == message &&
      other.orderKey == orderKey;

  @override
  int get hashCode => Object.hash(message, orderKey);
}

/// What the harness reported about the message an item belongs to.
///
/// Every field but [message] is optional: an absent value is unknown, never
/// zero. Times are the harness's own, not local observation times.
final class MessageContext {
  const MessageContext({
    required this.message,
    this.created,
    this.completed,
    this.modelId,
    this.modelProviderId,
    this.modelVariant,
    this.agentId,
    this.tokens,
    this.cost,
    this.finish,
  });

  final MessageRef message;
  final DateTime? created;
  final DateTime? completed;
  final String? modelId;
  final String? modelProviderId;
  final String? modelVariant;
  final String? agentId;
  final TokenBreakdown? tokens;
  final Cost? cost;

  /// The harness's finish reason, as reported.
  final String? finish;

  /// This context with every value [other] knows taking precedence.
  MessageContext merge(MessageContext other) => MessageContext(
    message: message,
    created: other.created ?? created,
    completed: other.completed ?? completed,
    modelId: other.modelId ?? modelId,
    modelProviderId: other.modelProviderId ?? modelProviderId,
    modelVariant: other.modelVariant ?? modelVariant,
    agentId: other.agentId ?? agentId,
    tokens: other.tokens ?? tokens,
    cost: other.cost ?? cost,
    finish: other.finish ?? finish,
  );
}

/// Stable identity and stream generation are assigned at the adapter boundary.
///
/// [ordinal] retains a source block's ordinal. Text and reasoning may both have
/// ordinal zero; their stable IDs must still be distinct. Core does not combine
/// those ordinal spaces or derive item identity from display order.
final class ItemMeta {
  ItemMeta({
    required this.id,
    required String generation,
    required this.status,
    required this.source,
    this.turnId,
    this.ordinal,
    this.message,
    this.anchor,
  }) : generation = requireText(generation, 'generation') {
    requireText(id.value, 'id');
    if (turnId != null) requireText(turnId!.value, 'turnId');
    if (ordinal != null && ordinal! < 0) {
      throw ArgumentError.value(ordinal, 'ordinal', 'Must be nonnegative');
    }
    if (anchor != null &&
        message != null &&
        anchor!.message != message!.message) {
      throw ArgumentError('Message context and anchor must agree');
    }
  }

  final ItemId id;
  final TurnId? turnId;
  final String generation;
  final OpenValue<ItemStatus> status;
  final SourceProvenance source;
  final int? ordinal;

  /// The harness message this item belongs to, when the harness reports one.
  final MessageContext? message;

  /// Stable identity/order, independent of assistant presentation metadata.
  final MessageAnchor? anchor;

  /// This metadata with [message] replaced.
  ItemMeta withMessage(MessageContext? message) => ItemMeta(
    id: id,
    generation: generation,
    status: status,
    source: source,
    turnId: turnId,
    ordinal: ordinal,
    message: message,
    anchor: anchor,
  );
}

sealed class TimelineItem {
  const TimelineItem({required this.meta});

  final ItemMeta meta;

  ItemId get id => meta.id;
  TurnId? get turnId => meta.turnId;
  String get generation => meta.generation;
  OpenValue<ItemStatus> get status => meta.status;
  SourceProvenance get source => meta.source;

  /// This item with [meta] replaced and every other field kept.
  TimelineItem withMeta(ItemMeta meta) => switch (this) {
    final UserInput item => UserInput(
      meta: meta,
      text: item.text,
      delivery: item.delivery,
      attachments: item.attachments,
      mentions: item.mentions,
      commandId: item.commandId,
      confirmed: item.confirmed,
    ),
    final AssistantText item => AssistantText(
      meta: meta,
      text: item.text,
      complete: item.complete,
      prefixMissing: item.prefixMissing,
    ),
    final Reasoning item => Reasoning(
      meta: meta,
      text: item.text,
      complete: item.complete,
      prefixMissing: item.prefixMissing,
    ),
    final ToolCall item => ToolCall(
      meta: meta,
      kind: item.kind,
      rawName: item.rawName,
      input: item.input,
      output: item.output,
      outputRef: item.outputRef,
      child: item.child,
      childEvidence: item.childEvidence,
      error: item.error,
    ),
    final ShellRun item => ShellRun(
      meta: meta,
      command: item.command,
      exitCode: item.exitCode,
      exitToken: item.exitToken,
      output: item.output,
      shellStatus: item.shellStatus,
      outputText: item.outputText,
    ),
    final Notice item => Notice(
      meta: meta,
      kind: item.kind,
      text: item.text,
      relatedSession: item.relatedSession,
    ),
    final TurnOutcome item => TurnOutcome(
      meta: meta,
      kind: item.kind,
      error: item.error,
      reason: item.reason,
    ),
    final UnknownItem item => UnknownItem(
      meta: meta,
      rawType: item.rawType,
      raw: item.raw,
      fallbackText: item.fallbackText,
    ),
  };
}

final class UserInput extends TimelineItem {
  UserInput({
    required super.meta,
    required this.text,
    required this.delivery,
    Iterable<AttachmentRef> attachments = const [],
    Iterable<MentionRef> mentions = const [],
    this.commandId,
    this.confirmed = false,
  }) : attachments = immutableList(attachments),
       mentions = immutableList(mentions);

  final String text;
  final List<AttachmentRef> attachments;
  final List<MentionRef> mentions;
  final CommandId? commandId;
  final OpenValue<DeliveryState> delivery;

  /// A persisted harness user message, rather than a local or queued echo.
  /// This does not establish execution completion or exclude pending input.
  final bool confirmed;
}

final class AssistantText extends TimelineItem {
  const AssistantText({
    required super.meta,
    required this.text,
    required this.complete,
    this.prefixMissing = false,
  });

  final String text;
  final bool complete;

  /// A live stream resumed without an authoritative complete prefix.
  final bool prefixMissing;
}

/// Only reasoning exposed by the connected harness is represented.
final class Reasoning extends TimelineItem {
  const Reasoning({
    required super.meta,
    required this.text,
    required this.complete,
    this.prefixMissing = false,
  });

  final String text;
  final bool complete;
  final bool prefixMissing;
}

/// Whether a tool call's child session was observed or refused.
enum ToolChildEvidenceKind { observed, rejected }

/// The observation behind a [ToolCall.child], kept apart from the row's own
/// source: an ephemeral observation never claims the row's durability.
final class ToolChildEvidence {
  ToolChildEvidence({
    required this.kind,
    required this.origin,
    required String generation,
  }) : generation = requireText(generation, 'generation');

  final ToolChildEvidenceKind kind;
  final SourceProvenance origin;

  /// The item generation the observation belongs to.
  final String generation;
}

final class ToolCall extends TimelineItem {
  const ToolCall({
    required super.meta,
    required this.kind,
    required this.rawName,
    this.input,
    this.output,
    this.outputRef,
    this.child,
    this.childEvidence,
    this.error,
  });

  final OpenValue<ToolKind> kind;
  final String rawName;

  /// Bounded, canonical values; the adapter does not retain wire DTOs here.
  final CanonicalValue? input;
  final CanonicalValue? output;
  final OutputRef? outputRef;

  /// The session this call runs. Without [childEvidence] it is unproven and
  /// must still be verified before it is opened.
  final SessionRef? child;

  /// Where [child] came from, or that an explicit child was refused.
  final ToolChildEvidence? childEvidence;
  final ErrorInfo? error;

  /// Whether [childEvidence] fits this call: an observation names a child of
  /// this call's harness and generation, and a refusal names none.
  bool get childEvidenceValid {
    final evidence = childEvidence;
    if (evidence == null) return true;
    if (evidence.generation != generation ||
        evidence.origin.harness != source.harness) {
      return false;
    }
    return switch (evidence.kind) {
      ToolChildEvidenceKind.observed =>
        child != null && child!.harnessRef == source.harness,
      ToolChildEvidenceKind.rejected => child == null,
    };
  }
}

final class ShellRun extends TimelineItem {
  const ShellRun({
    required super.meta,
    required this.command,
    this.exitCode,
    this.exitToken,
    this.output,
    this.shellStatus,
    this.outputText,
  });

  final String command;

  /// A finite integral exit; null when none was reported or it was not one.
  final int? exitCode;

  /// A reported exit that is not a finite number, kept exactly: `Infinity`,
  /// `-Infinity` or `NaN`. Never coerced into [exitCode].
  final String? exitToken;

  /// The captured output's identity, size and completeness, when reported.
  final OutputRef? output;

  final OpenValue<ShellStatus>? shellStatus;

  /// A bounded, redacted prefix of the captured output; the adapter never
  /// stores more than its own bound here.
  final String? outputText;
}

/// A related child's notice belongs to this item's owner, not that child.
/// It does not establish the child's own execution outcome.
final class Notice extends TimelineItem {
  const Notice({
    required super.meta,
    required this.kind,
    required this.text,
    this.relatedSession,
  });

  final OpenValue<NoticeKind> kind;
  final String text;
  final SessionRef? relatedSession;
}

final class TurnOutcome extends TimelineItem {
  const TurnOutcome({
    required super.meta,
    required this.kind,
    this.error,
    this.reason,
  });

  final OpenValue<OutcomeKind> kind;
  final ErrorInfo? error;
  final String? reason;
}

/// A neutral, typed unknown; it must not become invented assistant text.
/// Raw content must already be bounded and sanitized by the adapter.
final class UnknownItem extends TimelineItem {
  const UnknownItem({
    required super.meta,
    required this.rawType,
    required this.raw,
    this.fallbackText,
  });

  final String rawType;
  final CanonicalValue raw;
  final String? fallbackText;
}
