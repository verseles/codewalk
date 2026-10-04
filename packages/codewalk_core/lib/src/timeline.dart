import 'errors.dart';
import 'identity.dart';
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
  }) : generation = requireText(generation, 'generation') {
    requireText(id.value, 'id');
    if (turnId != null) requireText(turnId!.value, 'turnId');
    if (ordinal != null && ordinal! < 0) {
      throw ArgumentError.value(ordinal, 'ordinal', 'Must be nonnegative');
    }
  }

  final ItemId id;
  final TurnId? turnId;
  final String generation;
  final OpenValue<ItemStatus> status;
  final SourceProvenance source;
  final int? ordinal;
}

sealed class TimelineItem {
  const TimelineItem({required this.meta});

  final ItemMeta meta;

  ItemId get id => meta.id;
  TurnId? get turnId => meta.turnId;
  String get generation => meta.generation;
  OpenValue<ItemStatus> get status => meta.status;
  SourceProvenance get source => meta.source;
}

final class UserInput extends TimelineItem {
  UserInput({
    required super.meta,
    required this.text,
    required this.delivery,
    Iterable<AttachmentRef> attachments = const [],
    Iterable<MentionRef> mentions = const [],
    this.commandId,
  }) : attachments = immutableList(attachments),
       mentions = immutableList(mentions);

  final String text;
  final List<AttachmentRef> attachments;
  final List<MentionRef> mentions;
  final CommandId? commandId;
  final OpenValue<DeliveryState> delivery;
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

final class ToolCall extends TimelineItem {
  const ToolCall({
    required super.meta,
    required this.kind,
    required this.rawName,
    this.input,
    this.output,
    this.outputRef,
    this.child,
    this.error,
  });

  final OpenValue<ToolKind> kind;
  final String rawName;

  /// Bounded, canonical values; the adapter does not retain wire DTOs here.
  final CanonicalValue? input;
  final CanonicalValue? output;
  final OutputRef? outputRef;
  final SessionRef? child;
  final ErrorInfo? error;
}

final class ShellRun extends TimelineItem {
  const ShellRun({
    required super.meta,
    required this.command,
    this.exitCode,
    this.output,
  });

  final String command;
  final int? exitCode;
  final OutputRef? output;
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
