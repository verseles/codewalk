import 'dart:convert';
import 'dart:io';

/// Finite, observed exchanges; this is not an implementation of native state.
final class FixtureExchange {
  FixtureExchange.fromCapture(Map<String, Object?> call, this.source)
    : method = call['method'] as String,
      target = Uri.parse(call['path'] as String),
      request = freezeJson(call['request']),
      status = call['status'] as int,
      response = freezeJson(call['response']);

  final String source;
  final String method;
  final Uri target;
  final Object? request;
  final int status;
  final Object? response;

  bool matches(String actualMethod, Uri uri, Object? body, bool hasBody) =>
      method == actualMethod &&
      target.path == uri.path &&
      sameJson(target.queryParametersAll, uri.queryParametersAll) &&
      hasBody == (request != null) &&
      sameJson(request, body);
}

final class FixtureStream {
  FixtureStream(this.source, Iterable<String> frames)
    : frames = List.unmodifiable(frames) {
    if (this.frames.any((frame) => !frame.endsWith('\n\n'))) {
      throw StateError('Fixture SSE frames must have a complete boundary.');
    }
  }

  final String source;
  final List<String> frames;
}

final class FixtureScenario {
  FixtureScenario(
    this.name, {
    Iterable<FixtureExchange> exchanges = const [],
    Iterable<FixtureStream> streams = const [],
  }) : exchanges = List.unmodifiable(exchanges),
       streams = List.unmodifiable(streams);

  final String name;
  final List<FixtureExchange> exchanges;
  final List<FixtureStream> streams;
}

/// Loads only accepted 2.0.22 captures; never contacts a native service.
final class OpenCodeFixtures {
  OpenCodeFixtures({Directory? root}) : root = root ?? _findRoot();

  final Directory root;

  Map<String, Object?> get info => _object('info.json');

  Map<String, Object?> _object(String path) =>
      jsonDecode(File('${root.path}/$path').readAsStringSync())
          as Map<String, Object?>;

  List<FixtureExchange> _calls(String path) {
    final calls = _object(path)['calls'] as List<Object?>;
    return [
      for (var index = 0; index < calls.length; index++)
        FixtureExchange.fromCapture(
          calls[index] as Map<String, Object?>,
          '$path#calls[$index]',
        ),
    ];
  }

  FixtureStream get observedAStream {
    final text = File('${root.path}/events.sse').readAsStringSync();
    final parts = text.split('\n\n');
    if (parts.removeLast().isNotEmpty || parts.any((part) => part.isEmpty)) {
      throw StateError('Unexpected accepted A SSE serialization.');
    }
    return FixtureStream('events.sse (reserialized)', [
      for (final part in parts) '$part\n\n',
    ]);
  }

  FixtureScenario observedA() =>
      FixtureScenario('A/events', streams: [observedAStream]);

  FixtureScenario admission() {
    final creates = _calls('b/create-matrix.json');
    final prompts = _calls('b/prompt-matrix.json');
    final session = (creates.first.response as Map)['data'] as Map;
    if (prompts.first.target.path != '/api/session/${session['id']}/prompt') {
      throw StateError('B admission captures no longer share their session.');
    }
    return FixtureScenario(
      'B/admission',
      exchanges: [...creates.take(3), ...prompts.take(10)],
    );
  }

  FixtureScenario lostCreate() => FixtureScenario(
    'B/admitted-create',
    exchanges: _calls('b/create-matrix.json').sublist(5, 8),
  );

  FixtureScenario reconnect() {
    const path = 'b/disconnect-reconnect.json';
    final capture = _object(path);
    FixtureStream stream(String key) {
      final frames = (capture[key] as Map)['frames'] as List;
      return FixtureStream('$path#$key.frames', [
        for (final frame in frames) '${(frame as List).join('\n')}\n\n',
      ]);
    }

    return FixtureScenario(
      'B/disconnect-reconnect',
      exchanges: _calls(path),
      streams: [stream('partialStream'), stream('reconnectedStream')],
    );
  }

  FixtureScenario permissionOnce() => _interaction(
    'permission-once',
    [3, 5, 6, 7, 8],
    ['POST', 'POST', 'GET', 'POST', 'GET'],
    'permission',
  );

  FixtureScenario formReply() => _interaction(
    'form-reply',
    [42, 43, 44, 45, 46, 47],
    ['POST', 'POST', 'GET', 'POST', 'GET', 'GET'],
    'form',
  );

  FixtureScenario formDismiss() => _interaction(
    'form-dismiss',
    [48, 49, 50, 51, 52, 53],
    ['POST', 'POST', 'GET', 'DELETE', 'GET', 'GET'],
    'form',
  );

  FixtureScenario _interaction(
    String name,
    List<int> indices,
    List<String> methods,
    String resource,
  ) {
    const path = 'c/native-interactions.json';
    final calls = _calls(path);
    final selected = [for (final index in indices) calls[index]];
    final session = ((selected.first.response as Map)['data'] as Map)['id'];
    for (var index = 0; index < selected.length; index++) {
      final exchange = selected[index];
      final expectedPrefix = index == 0
          ? '/api/session'
          : '/api/session/$session/$resource';
      if (exchange.method != methods[index] ||
          !(exchange.target.path == expectedPrefix ||
              exchange.target.path.startsWith('$expectedPrefix/'))) {
        throw StateError('Accepted C scenario selector changed: $name.');
      }
    }
    final interactionID = ((selected[1].response as Map)['data'] as Map)['id'];
    final events = _object(path)['events'] as List;
    final matchingEvents = events.where((event) {
      final data = (event as Map)['data'] as Map;
      final form = data['form'];
      return data['id'] == interactionID ||
          data['requestID'] == interactionID ||
          (form is Map && form['id'] == interactionID);
    });
    return FixtureScenario(
      'C/$name',
      exchanges: selected,
      streams: [
        FixtureStream('$path#events ($name)', [
          for (final event in matchingEvents) 'data: ${jsonEncode(event)}\n\n',
        ]),
      ],
    );
  }

  static Directory _findRoot() {
    var directory = Directory.current.absolute;
    while (true) {
      final candidate = Directory(
        '${directory.path}/test/contract/fixtures/opencode/2.0.22',
      );
      if (candidate.existsSync()) return candidate;
      final parent = directory.parent;
      if (parent.path == directory.path) {
        throw StateError('Accepted OpenCode 2.0.22 fixtures not found.');
      }
      directory = parent;
    }
  }
}

Object? freezeJson(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable({
      for (final entry in value.entries)
        entry.key as String: freezeJson(entry.value),
    });
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(freezeJson));
  return value;
}

bool sameJson(Object? first, Object? second) {
  if (first is Map && second is Map) {
    return first.length == second.length &&
        first.keys.every(
          (key) => second.containsKey(key) && sameJson(first[key], second[key]),
        );
  }
  if (first is List && second is List) {
    return first.length == second.length &&
        Iterable<int>.generate(
          first.length,
        ).every((index) => sameJson(first[index], second[index]));
  }
  if (first is num && second is num) {
    return first.runtimeType == second.runtimeType && first == second;
  }
  return first == second;
}
