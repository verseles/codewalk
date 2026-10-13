import 'dart:async';
import 'package:codewalk/shared/sessions/session_history_source.dart';
import 'package:codewalk_core/codewalk_core.dart';

class HistoryTask implements SessionHistoryTask {
  final completion = Completer<SessionHistoryPageResult>();
  bool cancelled = false;
  @override
  Future<SessionHistoryPageResult> get result => completion.future;
  @override
  void cancel() => cancelled = true;
}

class HistorySource implements SessionHistorySource {
  HistorySource(this.session);
  @override
  final SessionRef session;
  final tasks = <HistoryTask>[];
  final cursors = <String?>[];
  int closes = 0;
  @override
  HistoryTask read({String? cursor}) {
    cursors.add(cursor);
    final task = HistoryTask();
    tasks.add(task);
    return task;
  }

  void respond(
    List<TimelineItem> items, {
    String? next,
    String version = '2.0.22',
  }) => tasks.last.completion.complete(
    SessionHistoryPageResult(
      session,
      version,
      Page(items: items, nextCursor: next),
    ),
  );
  void fail(SessionHistoryFailure failure) =>
      tasks.last.completion.completeError(SessionHistoryException(failure));
  AssistantText item(
    int id, {
    String text = 'Read only',
    String version = '2.0.22',
  }) => AssistantText(
    meta: meta(id, version: version),
    text: text,
    complete: false,
  );
  ItemMeta meta(int id, {String version = '2.0.22'}) => ItemMeta(
    id: ItemId('${session.storageKey}/$id'),
    generation: 'history',
    status: OpenValue.unknown('completionUnverified'),
    source: SourceProvenance(
      harness: session.harnessRef,
      version: version,
      nativeType: 'assistant',
    ),
  );
  @override
  void close() => closes++;
}
