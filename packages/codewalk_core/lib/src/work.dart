import 'errors.dart';
import 'identity.dart';
import 'timeline.dart';
import 'values.dart';

enum WorkStatus {
  queued,
  running,
  waiting,
  completed,
  failed,
  cancelled,
  unknown,
}

/// The scope of the observation, not a promise about another owner's execution.
enum CompletionScope { work, child, session, sessionTree, notice, unknown }

/// A child or background job can remain active while its parent is idle.
///
/// A parent completion notice can arrive before the child's own terminal event.
/// [status] describes this observation's [completionScope]; consumers must not
/// promote a [CompletionScope.notice] into a terminal child/session outcome.
final class WorkItem {
  const WorkItem({
    required this.id,
    required this.owner,
    required this.status,
    required this.completionScope,
    this.child,
    this.parent,
    this.title,
    this.error,
    this.source,
  });

  final WorkId id;
  final DomainOwner owner;
  final SessionRef? child;
  final SessionRef? parent;
  final OpenValue<WorkStatus> status;
  final OpenValue<CompletionScope> completionScope;
  final String? title;
  final ErrorInfo? error;
  final SourceProvenance? source;
}

enum PlanStatus { pending, inProgress, completed, cancelled, unknown }

/// A structured native plan entry. Text is never parsed to invent a plan.
final class PlanEntry {
  PlanEntry({
    required this.id,
    required this.title,
    required this.status,
    this.metadata,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty');
    }
  }

  final String id;
  final String title;
  final OpenValue<PlanStatus> status;
  final CanonicalValue? metadata;

  @override
  bool operator ==(Object other) =>
      other is PlanEntry &&
      id == other.id &&
      title == other.title &&
      status == other.status &&
      metadata == other.metadata;

  @override
  int get hashCode => Object.hash(id, title, status, metadata);
}

/// A complete structured level-set; replacing it does not merge old entries.
final class PlanSnapshot {
  PlanSnapshot({
    required this.owner,
    required Iterable<PlanEntry> entries,
    this.source,
    this.anchor,
  }) : entries = immutableList(entries);

  final DomainOwner owner;
  final List<PlanEntry> entries;
  final SourceProvenance? source;

  /// The harness message that produced this level-set, when known.
  ///
  /// Adapters that want turn- and revert-scoped visibility set [anchor]. A null
  /// anchor stays visible until the next [PlanChanged] (unless hidden by a
  /// staged revert cut).
  final MessageAnchor? anchor;

  @override
  bool operator ==(Object other) =>
      other is PlanSnapshot &&
      owner == other.owner &&
      anchor == other.anchor &&
      entries.length == other.entries.length &&
      Iterable<int>.generate(
        entries.length,
      ).every((i) => entries[i] == other.entries[i]);

  @override
  int get hashCode => Object.hash(owner, anchor, Object.hashAll(entries));
}

/// One harness-observed shell command owned by a session, kept isolated from
/// subagent [WorkItem] rows so child snapshots and deletions never erase it.
///
/// Host-private fields such as capture file paths, working directories, and OS
/// process IDs are never represented in the canonical model.
final class ShellWork {
  ShellWork({
    required String id,
    required this.owner,
    required this.command,
    required this.status,
    this.startedAt,
    this.completedAt,
    this.exitCode,
    this.exitToken,
    this.signal,
    this.source,
  }) : id = requireText(id, 'id') {
    if (startedAt != null &&
        completedAt != null &&
        completedAt!.isBefore(startedAt!)) {
      throw ArgumentError('ShellWork completedAt precedes startedAt');
    }
  }

  final String id;
  final DomainOwner owner;
  final String command;
  final OpenValue<ShellStatus> status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? exitCode;
  final String? exitToken;
  final String? signal;
  final SourceProvenance? source;

  bool get isRunning => status.known == ShellStatus.running;

  @override
  bool operator ==(Object other) =>
      other is ShellWork &&
      id == other.id &&
      owner.scopeKey == other.owner.scopeKey &&
      command == other.command &&
      status == other.status &&
      startedAt == other.startedAt &&
      completedAt == other.completedAt &&
      exitCode == other.exitCode &&
      exitToken == other.exitToken &&
      signal == other.signal;

  @override
  int get hashCode => Object.hash(
    id,
    owner.scopeKey,
    command,
    status,
    startedAt,
    completedAt,
    exitCode,
    exitToken,
    signal,
  );
}

/// One cursor-paged slice of combined output captured for a [ShellWork].
final class ShellOutputPage {
  ShellOutputPage({
    required this.output,
    required this.cursor,
    required this.size,
    required this.truncated,
  }) {
    if (cursor < 0 || size < 0) {
      throw ArgumentError(
        'ShellOutputPage cursor and size must be nonnegative',
      );
    }
  }

  final String output;
  final int cursor;
  final int size;
  final bool truncated;

  /// True while the server reports more bytes beyond [cursor].
  bool get hasMore => cursor < size;

  @override
  bool operator ==(Object other) =>
      other is ShellOutputPage &&
      output == other.output &&
      cursor == other.cursor &&
      size == other.size &&
      truncated == other.truncated;

  @override
  int get hashCode => Object.hash(output, cursor, size, truncated);
}
