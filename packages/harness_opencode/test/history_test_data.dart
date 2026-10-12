import 'package:codewalk_core/codewalk_core.dart';

const historyHarness = HarnessRef(
  HostId('host-a'),
  HarnessInstanceId('native-a'),
);
const historyRef = SessionRef(
  HostId('host-a'),
  HarnessInstanceId('native-a'),
  'ses_a',
);

// Source-shaped edge cases are distinct from the immutable native A/B captures.
Map<String, Object?> message(
  String id,
  String type, [
  Map<String, Object?> fields = const {},
]) => {
  'id': 'msg_$id',
  'type': type,
  'time': {'created': 1000},
  ...fields,
};
Map<String, Object?> assistant(
  String id,
  List<Object?> blocks, {
  bool completed = false,
  bool streamed = false,
  Map<String, Object?> fields = const {},
}) => message(id, 'assistant', {
  'content': blocks,
  'time': {
    'created': 1000,
    if (streamed) 'streamed': 1500,
    if (completed) 'completed': 2000,
  },
  ...fields,
});
Map<String, Object?> textBlock(String text) => {'type': 'text', 'text': text};
Map<String, Object?> toolBlock(
  String id,
  String status, {
  String name = 'read',
  Object? input,
  List<Object?>? content,
  Map<String, Object?>? error,
}) => {
  'type': 'tool',
  'id': id,
  'name': name,
  'time': {'created': 1000},
  'state': {
    'status': status,
    'input':
        input ?? (status == 'streaming' ? '{"path":' : {'path': 'file.txt'}),
    if (status == 'completed')
      'content':
          content ??
          [
            {'type': 'text', 'text': 'result'},
          ],
    if (status == 'error') 'error': error ?? {'type': 'aborted'},
  },
};
Map<String, Object?> historyPage(
  List<Object?> rows, {
  String? next,
  String? previous,
}) => {
  'data': rows,
  'cursor': {'next': ?next, 'previous': ?previous},
};

Map<String, Object?> semanticItem(TimelineItem item) => {
  'id': item.id.value,
  'generation': item.generation,
  'status': item.status.value,
  'ordinal': item.meta.ordinal,
  'turn': item.turnId?.value,
  'source': {
    'version': item.source.version,
    'type': item.source.nativeType,
    'event': item.source.nativeEventId,
    'durability': item.source.durability.value,
    'extra': item.source.extra?.value,
  },
  ...switch (item) {
    UserInput v => {
      'kind': 'user',
      'text': v.text,
      'delivery': v.delivery.value,
    },
    AssistantText v => {'kind': 'text', 'text': v.text, 'complete': v.complete},
    Reasoning v => {
      'kind': 'reasoning',
      'text': v.text,
      'complete': v.complete,
    },
    ToolCall v => {
      'kind': 'tool',
      'name': v.rawName,
      'input': v.input?.value,
      'output': v.output?.value,
      'child': v.child?.storageKey,
      'error': v.error?.rawType,
    },
    Notice v => {'kind': 'notice', 'text': v.text, 'notice': v.kind.value},
    TurnOutcome v => {'kind': 'outcome', 'outcome': v.kind.value},
    UnknownItem v => {
      'kind': 'unknown',
      'rawType': v.rawType,
      'raw': v.raw.value,
    },
    ShellRun v => {'kind': 'shell', 'command': v.command},
  },
};
